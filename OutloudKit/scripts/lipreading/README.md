# Lip-reading model scripts

The one-off steps that make the lip-reading model of `OutloudLipreading` (ADR 0034,
`plans/LIP_READING.md`). Everything else — reading, harvesting, training — runs in Swift through
the `outloud` CLI, built with `xcodebuild` (`OutloudKit/AGENTS.md` §"Toolchain"). Downloads go
into a new, empty folder outside the repository, and the scripts are run with `python -I`.

1. **Environment.** `python3.12 -m venv venv && venv/bin/pip install -r requirements.txt`.
2. **English model.** Clone github.com/mpc001/auto_avsr at
   `182b62837773ab01052d4ac21ef1d2203ea7d267` and download its checkpoint
   `vsr_trlrs2lrs3vox2avsp_base.pth` (MD5 `49f77…`, see its README). Then
   `venv/bin/python -I convert.py AUTO_AVSR CHECKPOINT MODEL [CROPS_NPY]` writes
   `encoder.safetensors`, `decoder-en.safetensors`, `vocabulary-en.json` and, given mouth crops,
   `reference.safetensors` for `outloud lips check`.
3. **Install.** `outloud lips install MODEL` copies the files into
   `Application Support/Outloud/LipReading/Model/` after checking the hashes
   `LipReadingFiles` pins. `OUTLOUD_LIPS=<folder>` points the CLI at a trial folder instead.
4. **German data.** `commons_de.py LIST.json` lists the German videos of Wikimedia Commons
   under CC BY, CC BY-SA or in the public domain, 2 to 60 minutes long.
   `harvest.sh LIST.json WORK TRIAL CLI de` downloads each, cuts it into six-second pieces,
   keeps the pieces that show one speaker in close-up as samples (`outloud lips harvest`,
   labelled by Parakeet) and deletes the video: only mouth crops are kept.
5. **German model.** `german_vocabulary.py TRIAL/Samples MODEL AUTO_AVSR` trains the German
   SentencePiece vocabulary on the samples' transcripts and starts `decoder-de.safetensors`
   from the English decoder; `OUTLOUD_LIPS=TRIAL outloud lips train de decoder` trains it on the
   samples, holding back a tenth to judge it. Pin the hashes of `decoder-de.safetensors` and
   `vocabulary-de.json` in `LipReadingFiles.germanPins`, and list the videos that gave samples in
   `SOURCES.md` beside the model, with their authors and licences.
