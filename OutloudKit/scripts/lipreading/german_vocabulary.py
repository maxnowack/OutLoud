"""A German vocabulary and the decoder it starts from (plans/LIP_READING.md, Phase 3).

usage: german_vocabulary.py SAMPLES_DIR MODEL_DIR AUTO_AVSR_DIR [SIZE]
Trains a SentencePiece unigram vocabulary on the transcripts of the training samples (the
held-back tenth left out, as the Swift training holds it back) and writes MODEL_DIR/vocabulary-de.json
and MODEL_DIR/decoder-de.safetensors: the English decoder, whose embedding and output rows are carried
over for pieces both vocabularies share and averaged from the English pieces of the others.
"""
import glob, json, os, re, sys, tempfile
import numpy as np
import sentencepiece
from safetensors.numpy import load_file, save_file

samples, model, repo = sys.argv[1:4]
size = int(sys.argv[4]) if len(sys.argv) > 4 else 1000

def normalise(text):  # as Vocabulary.normalise in Swift
    return " ".join(re.sub(r"[^\w']|_", " ", text.upper()).split())

texts = []
for path in glob.glob(f"{samples}/*.json"):
    s = json.load(open(path))
    if s["language"] == "de" and int(s["id"][:2], 16) % 10 != 0:
        texts.append(normalise(s["text"]))
print(len(texts), "transcripts,", sum(len(t.split()) for t in texts), "words")
with tempfile.TemporaryDirectory() as tmp:
    open(f"{tmp}/text.txt", "w").write("\n".join(texts))
    sentencepiece.SentencePieceTrainer.train(
        input=f"{tmp}/text.txt", model_prefix=f"{tmp}/de", vocab_size=size, model_type="unigram",
        character_coverage=1.0, bos_id=-1, eos_id=-1, unk_id=0, pad_id=-1, minloglevel=2)
    sp = sentencepiece.SentencePieceProcessor(model_file=f"{tmp}/de.model")
german = [["<blank>", 0.0]] + [[sp.id_to_piece(i), sp.get_score(i)] for i in range(sp.get_piece_size())] + [["<eos>", 0.0]]

english = [p for p, _ in json.load(open(f"{model}/vocabulary-en.json"))]
index = {p: i for i, p in enumerate(english)}
en_sp = sentencepiece.SentencePieceProcessor(model_file=f"{repo}/spm/unigram/unigram5000.model")
decoder = load_file(f"{model}/decoder-en.safetensors")
plain = str.maketrans({"Ä": "A", "Ö": "O", "Ü": "U"})

def rows(piece):
    """The English rows a German piece starts from."""
    if piece in index:
        return [index[piece]]
    if piece == "<blank>": return [0]
    if piece == "<unk>": return [index["<unk>"]]
    if piece == "<eos>": return [len(english) - 1]
    text = piece.replace("▁", " ").translate(plain)
    ids = [index[p] for p in en_sp.encode(text, out_type=str) if p in index]
    return ids or [index["<unk>"]]

shared = 0
out = dict(decoder)
for name in ("decoder.embed.weight", "decoder.output_layer.weight", "decoder.output_layer.bias"):
    source = decoder[name].astype(np.float32)
    target = []
    for piece, _ in german:
        r = rows(piece)
        target.append(source[r].mean(axis=0))
    out[name] = np.stack(target).astype(np.float16)
shared = sum(1 for p, _ in german if p in index)
save_file(out, f"{model}/decoder-de.safetensors")
json.dump(german, open(f"{model}/vocabulary-de.json", "w"), ensure_ascii=False)
print(len(german), "tokens,", shared, "shared with English")
