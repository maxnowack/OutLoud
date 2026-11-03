"""Convert Auto-AVSR's visual model to MLX's layout and write reference outputs.

usage: convert.py AUTO_AVSR_DIR CKPT OUT_DIR [CROPS_NPY]
Writes OUT_DIR/encoder.safetensors and OUT_DIR/decoder-en.safetensors (float16, MLX
layout: convolutions channels-last), OUT_DIR/vocabulary-en.json (pieces with their unigram scores, index = token id) and,
given CROPS_NPY (T x 96 x 96 uint8), OUT_DIR/reference.safetensors with the input
and the outputs of each stage, for the Swift port's tests.
"""

import json
import sys

import numpy as np
import sentencepiece
import torch
from safetensors.numpy import save_file

repo, ckpt_path, out = sys.argv[1:4]
sys.path.insert(0, repo)

state = torch.load(ckpt_path, map_location="cpu", weights_only=True)
converted = {}
for key, value in state.items():
    # The CTC head is not used: decoding is attention-only (plans/LIP_READING.md, Phase 0).
    if key.endswith("num_batches_tracked") or key.startswith("ctc."):
        continue
    v = value.float().numpy()
    if v.ndim == 5:  # Conv3d: out, in, d, h, w -> out, d, h, w, in
        v = v.transpose(0, 2, 3, 4, 1)
    elif v.ndim == 4:  # Conv2d: out, in, h, w -> out, h, w, in
        v = v.transpose(0, 2, 3, 1)
    elif v.ndim == 3:  # Conv1d: out, in, k -> out, k, in
        v = v.transpose(0, 2, 1)
    # Sequential's indices become the Swift modules' names.
    key = (key.replace("frontend.frontend3D.0.", "frontend.conv3d.")
           .replace("frontend.frontend3D.1.", "frontend.bn3d.")
           .replace("downsample.0.", "downsample.conv.")
           .replace("downsample.1.", "downsample.bn.")
           .replace("decoder.embed.0.", "decoder.embed."))
    converted[key] = np.ascontiguousarray(v.astype(np.float16))
# One shared encoder, one decoder (with its CTC head) per language.
writes_tokens = ("decoder.",)
save_file({k: v for k, v in converted.items() if not k.startswith(writes_tokens)}, f"{out}/encoder.safetensors")
save_file({k: v for k, v in converted.items() if k.startswith(writes_tokens)}, f"{out}/decoder-en.safetensors")

sp = sentencepiece.SentencePieceProcessor(model_file=f"{repo}/spm/unigram/unigram5000.model")
units = [line.split()[0] for line in open(f"{repo}/spm/unigram/unigram5000_units.txt", encoding="utf8")]
scores = {sp.id_to_piece(i): sp.get_score(i) for i in range(sp.get_piece_size())}
vocabulary = [["<blank>", 0.0]] + [[u, scores.get(u, 0.0)] for u in units] + [["<eos>", 0.0]]
json.dump(vocabulary, open(f"{out}/vocabulary-en.json", "w"), ensure_ascii=False)
print(f"{len(converted)} tensors, {len(vocabulary)} tokens")

if len(sys.argv) > 4:
    from datamodule.transforms import VideoTransform
    from espnet.nets.pytorch_backend.e2e_asr_conformer import E2E
    from espnet.nets.pytorch_backend.transformer.mask import subsequent_mask

    model = E2E(len(vocabulary), "video")
    model.load_state_dict(state)
    model.eval()
    crops = np.load(sys.argv[4])
    video = VideoTransform("test")(torch.tensor(crops).unsqueeze(1).float())
    with torch.no_grad():
        front = model.frontend(video.unsqueeze(0))
        enc, _ = model.encoder(model.proj_encoder(front), None)
        prefix = torch.tensor([[len(vocabulary) - 1, 100, 200, 300]])
        logits, _ = model.decoder(prefix, subsequent_mask(4).unsqueeze(0), enc, None)
    save_file({
        "crops": crops,
        "input": video.squeeze(1).numpy(),
        "frontend": front.numpy(),
        "encoder": enc.numpy(),
        "prefix": prefix.numpy().astype(np.int32),
        "decoder": logits.numpy(),
    }, f"{out}/reference.safetensors")
    print("reference written", front.shape, enc.shape, logits.shape)
