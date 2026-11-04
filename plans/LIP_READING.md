# Dictate without sound on the Mac by reading the lips, in German and English

## Status

In progress (2026-11-03): everything that runs without the user in front of the camera is
built — the `OutloudLipreading` target, the settings tab and the silent practice, sample storage,
on-device training and the German decoder — and checked by unit tests and by the CLI on recorded
video; what needs the user's face and approval is open (below). The user asked for it on
2026-11-03 and settled that the licence only has to allow our use, that German and English are
both required, that everything — training included — runs on this Mac (an M1 Pro with 32 GB of
memory and about 180 GB free), and that the camera records with every dictation while the
feature is tested, so that the user's own dictations train the model.

Measured on 2026-11-03 on the M1 Pro (ADR 0034):

- Phase 0: the Swift port of `vsr_trlrs2lrs3vox2avsp_base` matches PyTorch to 0.03 in the
  encoder's output; it reads about eight seconds of video per second after warm-up, in about
  500 MB of memory in 16-bit floats; training costs 0.011 s (decoder) and 0.030 s (encoder and
  decoder) of compute per second of video. The silent WER and its go/no-go threshold are not
  measured: they need the user's 30 silent sentences.
- Phase 4, on 15 minutes of one speaker's voiced video (168 samples, 16 held out): word error
  41.2 % before, 33.6 % after the best of 6 epochs, adopted, in 147 s. A learning rate of 5e-4
  doubled the error (41.2 → 83.6 %); 1e-4 is the default, and the best epoch on the held-out
  tenth is kept, not the last (`Judgement`, unit-tested).
- Phase 3, German: 1,852 samples from 38 Wikimedia Commons videos (CC BY, CC BY-SA, public
  domain; `SOURCES.md` beside the model), a 500-piece vocabulary of which 125 pieces match
  English. Training the decoder for 15 epochs at 3e-4 on 1,672 samples, judged on 180, took
  58 minutes: word error 100.7 % before, 77.1 % at the best epoch (12), adopted. The loss still
  fell after epoch 2 while the error stayed between 77 and 81 %: more German video, not more
  epochs, is what would lower it. German is readable only in its frequent words.

Deviations from the plan, each decided while building it:

- No `training/` unit: data preparation and training run in the Swift CLI (`outloud lips
  harvest | train`), the one-off conversion and the vocabulary in `OutloudKit/scripts/lipreading/`.
- The model is published on Hugging Face and downloaded by a button in the settings (Phase 7,
  2026-11-03), not installed with `outloud lips install`, which is gone.
- One encoder with a decoder per language instead of a joint German–English model; the CTC head
  is dropped (attention decoding only).
- German data comes from Commons instead of MuAViC; held-out samples come from the same videos
  and speakers as the training samples, so the German WER is optimistic.
- The "no sound" decision is Parakeet's empty result; it has no unit test, since that needs a
  transcriber seam in the engines, and is covered by `apps/macos/e2e/lip-reading.md` steps 3–4.

Phase 6 is built (2026-11-03): learning with the mode *Off*, off by default; training after
10 minutes without input on mains power, stopped by the next input; the accuracy against the
70 % it takes (30 % misread), the last and the next learning in the settings, and one
notification. The watching rule, the idle rule and the one
notification have unit tests; stopping a run is checked only in the running app. The language
is taken from each dictated transcript (95 % sure, else no sample) and the idle training covers
every language, with unit tests; not yet run against the camera. Phase 7 is built
(2026-11-03): lip reading is labelled experimental, and its model is published on Hugging Face
and downloaded by a button in the tab; the download is not yet observed in the running app.

Open, needing the user: the 30 silent sentences and the Phase 0 threshold; the end-to-end plan
`apps/macos/e2e/lip-reading.md` in the running app with the camera (Phases 1, 2); the fan and
battery behaviour during training (Phase 4); the idle training and its stop in the running
app (Phase 6); the silent WER before and after the practice
(Phase 5). The English and German model are installed in the app's location on this Mac
(2026-11-03, at the pinned hashes).

Addendum 2026-11-04, memory and time of a reading: measuring the user's 52 samples one by
one held 24 GB after 23 minutes and, run again, brought the 32 GB Mac down. The beam search
ran up to one token per frame (712 on a 28-second dictation), each step recomputed the
decoder's keys and values of the whole recording for every hypothesis, and MLX's buffer cache
— by default as large as its memory limit — kept the buffers of every step's new shapes. The
decoder now computes the recording's keys and values once (`TransformerDecoder.sources`), a
reading stops at one token per two frames (`BeamSearch.maximumLength`), MLX keeps at most
256 MB of freed buffers, and a reading or a training stops with `LipReader.TooMuchMemory`
past 6 GB. The same code ran in 0.6.0's training and silent reading. After the change, one
3.7-second silent English sample read with and without the adapter in 0.39 s, at a peak
footprint of 2.8 GB with both readers loaded in 32 bits (Release CLI, under a watchdog at
6 GB). All of the user's samples then read in 7.5 minutes (44 German, all voiced) and 13 s
(40 English, all silent) at a peak footprint of 6.2 GB: under 1.5 s for each up to 8 s, but
84 s for 53 s and 183 s for 81 s, where the decoder's self-attention still recomputes the
whole prefix at every token. Word error, base → adapter: German 95 % → 95 % (93 → 91 % up to
8 s, 95 → 96 % above; held out 92 → 89 %), English silent 98 → 53 % on the samples it was
trained on and 129 → 90 % on the held-out ones. Length does not explain the German error.
With each layer's self-attention keys and values kept per hypothesis
(`TransformerDecoder.step`), a step costs one token's work: the 44 German samples read in 81 s
instead of 450 s, 81 s of video in 15 s instead of 183 s, 53 s in 9 s instead of 84 s, with
the same word errors on every sample, at the same peak footprint of 6.2 GB with both readers in
32 bits. Training the German adapter on a copy of the 45 samples (an 81-second one among
them) took 72 s at a peak footprint of 6.25 GB, under the budget, which counts MLX's memory
only; the largest batch, not the number of samples, sets that peak. `outloud lips measure` reads
with the app's reader (`LipReader.forReading`, 16 bits), one reader at a time.

## Problem

Outloud needs sound. Where the user cannot speak aloud — an open-plan office, a library, a
sleeping child next door — it cannot be used at all. The Mac has a camera in front of the user
during every dictation, and the lips carry much of what is said.

The ground the plan stands on, as researched on 2026-11-03:

- No open sentence-level lip-reading model or dataset exists for German. The largest German
  resource, GLips (Hessian parliament, arXiv 2202.13403), is word-level; a 2025 study
  (arXiv 2504.15792) states that no large German datasets exist.
- The strongest open model is Auto-AVSR (github.com/mpc001/auto_avsr, arXiv 2303.14307):
  English, about 20 % word error rate (WER) on LRS3, trained on LRS2/LRS3 and on VoxCeleb2 and
  AVSpeech labelled automatically by a speech recogniser. Its README restricts it to
  non-commercial use, as LRS2/LRS3 are.
- Every such model is trained on voiced speech. Mouthing words silently moves the lips
  differently, so the WER without sound is expected to be markedly worse than 20 %.
- Outloud's own advantage: during a voiced dictation it has the sound, the picture and
  Parakeet's transcript at once — a labelled lip-reading sample of this very user, for free.
  That is the recipe Auto-AVSR was trained with, applied to one person.

## Goal

On the Mac, with lip reading switched on, a dictation the user only mouths, in German or in
English, is pasted as text into the field they were in. The WER on the user's own held-out
silent sentences is measured and stated in the settings' explanation; the model improves from
the user's voiced dictations without any data leaving the Mac.

## Approach

**Modes.** A setting "Lip reading" with three values:

- *Off* — as today; the camera is never used.
- *When there is no sound* — the camera runs with every dictation; when the recording holds no
  speech (Parakeet returns nothing, or the level never rises above the noise floor), the lip
  reader's text is used instead. When there is speech, Parakeet's text is used and the pair
  (mouth frames, transcript) becomes a training sample.
- *Silent* — the lip reader's text is always used.

A second switch, "Learn from my dictations" (on by default while the feature is tested, per the
user's decision), keeps the training samples. A dictation that is partly voiced and partly
silent is decided as a whole in the first version (see *Open questions*).

**Capture.** The camera runs only while the hotkey is held, as the microphone does. Apple's
Vision (`VNDetectFaceLandmarksRequest`) finds the lips on the device; only a grey 88 × 88 crop of
the mouth at 25 frames a second is kept, never the full frame. One implementation of this crop
exists — in OutloudKit, also reachable through the `outloud` CLI — and the training pipeline
calls the CLI, so that training and the app see the same pixels.

**Model.** Auto-AVSR's visual model as the base, converted once to MLX. Its English vocabulary is
replaced by a joint German–English SentencePiece vocabulary (umlauts and ß included); the
encoder keeps its weights, the decoder's embedding and output layers start fresh.

Rejected as the base: LipLearner (arXiv 2302.05907, github.com/rkmtlab/LipLearner, MIT) — it
spots a few user-defined commands by comparing embeddings and cannot dictate free text; its
on-device incremental learning is the pattern Phase 4 follows. AV-HuBERT (Meta, non-commercial)
is close in size and accuracy but adds nothing Auto-AVSR lacks; models that put a 7B language
model behind the lip encoder (VSP-LLM) are far beyond the size budget.

**Size.** Auto-AVSR's visual model has about 250 M parameters: about 1 GB in 32-bit floats, about
500 MB in 16-bit — the download, beside Parakeet's 483 MB. The user's personal adapter (LoRA) is a
few megabytes. A training sample is a 88 × 88 grey mouth crop at 25 frames a second, about 190 KB
a second uncompressed; a thousand ten-second dictations are about 1.9 GB raw, and the cached
front-end features (512 values in 16 bits per frame, about 25 KB a second) about 250 MB. Training
with the front end frozen and LoRA needs a few GB of memory; Phase 0 measures the peak.

**Framework.** MLX for both sides: MLX (Python) for the base training on this Mac, MLX Swift in
OutloudKit for recognition *and* for the user's fine-tuning in the app. One weights format
(safetensors), one model definition per language, no conversion step between training and
shipping. Rejected: Core ML — on-device training is limited to updatable layers and its
conversion is one-way; PyTorch on MPS for the base training with MLX in the app — two
implementations of one model drift apart.

**Training on an M1 Pro.** Training from scratch is out of reach (Auto-AVSR used about 3,400
hours on many GPUs). What fits: freezing the visual front end (the 3D convolution and ResNet),
computing its features once per sample and storing them, and training only the conformer and the
decoder on those features; for the user's fine-tuning, low-rank adapters (LoRA) on top of that.
Phase 0 measures whether this is fast enough.

**German data.** In order of weight: the user's own dictations (the main source), the German part
of MuAViC (TEDx, CC BY-NC 4.0 — to be confirmed before download), GLips for the front end's
German visemes (word-level; licence to be confirmed). Each source's licence is checked before it
is downloaded and recorded in the ADR; downloads land in their own empty folder outside the
repository, and only mouth crops are kept, never the videos.

**A personal model is adopted only when it is better.** Fine-tuning holds back a tenth of the
user's samples; the new adapter replaces the current one only if its WER on them is lower.

ADRs this plan needs before its phases count as done: the camera as a new trust boundary and the
storage of mouth crops; Auto-AVSR as the base and its non-commercial licence; MLX for recognition
and training; the training pipeline as a unit of its own (`training/`, with its own `AGENTS.md`
and `CLAUDE.md`, per `AGENTS.md` §"Repository layout").

## Phases

### Phase 0 — Feasibility on this Mac (nothing in the app)

Set up MLX in a scratch environment, convert Auto-AVSR's visual model, and record the user reading
30 English sentences aloud and the same 30 silently, cropped by a first version of the mouth crop.

**Definition of Done:** in this section's addendum, measured on the M1 Pro: the WER voiced and
silent; the time to recognise a 10-second dictation; the training throughput (seconds of compute
per hour of samples) with the front end frozen. A go/no-go on a threshold the user agreed before
the measurement (proposal: silent WER under 50 % for the English base, since fine-tuning is
expected to bring it down further).

### Phase 1 — The camera records with the dictation

The mode setting and "Learn from my dictations" in the settings; the camera's permission with its
explanation; the mouth crop in OutloudKit and the `outloud` CLI; training samples stored in the
app's container, listed with their size, deletable as a whole.

**Definition of Done:** `docs/SPEC.md` (settings, privacy), `docs/ARCHITECTURE.md` (§"Trust
boundaries": camera) and `docs/DESIGN.md` updated; the camera ADR written; the camera's light is
on only while the hotkey is held (checked in the running app); a refused permission leaves
dictation with sound working; an end-to-end plan under `apps/macos/e2e/`; German strings;
`./scripts/precommit` passes in `OutloudKit/` and `apps/macos/`.

### Phase 2 — Reading the lips in the app, English base

The MLX Swift model in OutloudKit, downloaded through `ModelLibrary` at pinned hashes; the modes
*When there is no sound* and *Silent* paste the lip reader's text, cleaned up as any dictation.

**Definition of Done:** a silently mouthed English sentence is pasted into a text field in the
running app; the "no sound" decision has unit tests for silence, noise and speech; the model ADR
and the MLX ADR written; precommit passes.

### Phase 3 — The German–English base on this Mac

The `training/` unit: data preparation through the CLI's crop, the joint vocabulary, feature
caching, training of conformer and decoder.

**Definition of Done:** a joint model whose WER on a held-out German and a held-out English set is
recorded here; every data source's licence recorded in the ADR; the whole run reproducible from
`training/` with one command; the model in the catalogue in place of the English base.

### Phase 4 — Learning from the user's dictations

Fine-tuning with LoRA in the app, in the background, only on mains power and when the Mac is idle;
the adapter adopted only when it beats the current one on the held-back samples; the settings show
how many samples exist and the current WER.

**Definition of Done:** after a set number of the user's voiced dictations (Phase 0 sets it), a
fine-tuning run finishes on this Mac, its before/after WER is recorded here, a worse adapter is
provably not adopted (unit test), and the fan and battery behaviour while it runs is checked.

### Phase 5 — Silent practice sentences

Voiced samples do not teach silent lip movements. A short practice the user starts in the
settings: Outloud shows a sentence, the user mouths it, the sentence is the label.

**Definition of Done:** the silent WER on the user's held-out silent sentences before and after
the practice is recorded here; the plan's `## Status` states what is true and the plan moves to
`plans/done/`.

### Phase 6 — Learning on its own until it is good enough

Asked by the user on 2026-11-03: lip reading learns by itself from what the user dictates aloud
anyway, trains while the Mac is idle, and says once when it reads well enough to be used. The
user decided: "Learn from my dictations" runs the camera with every dictation even with the mode
*Off* (the mode only decides what is pasted), it is off until the user turns it on, "good enough"
is under 30 % words misread on the held-out tenth of the user's samples, and the app says so once
with a macOS notification and in the settings.

- Watching: the camera runs while the hotkey is held when the mode is not *Off* or learning is on;
  with the mode *Off* the transcript is pasted and the frames are kept with it.
- Training: when new samples came in since the last run, the Mac is on mains power and nobody
  touched mouse or keyboard for 10 minutes; the first input stops it between two steps, and
  nothing of the stopped run is adopted.
- Readiness: the error of the reader in use after each run is kept per language; the first time it
  is under 30 %, one notification, and the settings show the error against the threshold.
- Language (asked by the user on 2026-11-03: the language is detected from the dictated text):
  each transcript from sound sets the lip-reading language when Apple's language recogniser is at
  least 95 % sure of German or English, and its sample is kept in that language; below that
  (a single "Okay." scores 93 % English) no sample is kept, since a sample in the wrong language
  teaches wrong words. The idle training goes over every language with 10 new samples. A silent
  dictation is read in the language last dictated aloud; the picker stays so the user can switch
  before mouthing the other one — reading with both models and taking the better reading was not
  chosen: twice the time, and the two decoders' scores are not measured to be comparable.

**Definition of Done:** unit tests for the watching rule, the idle rule, the one notification, the language taken
from the transcript and the training per language;
`docs/SPEC.md`, `docs/DESIGN.md`, ADR 0034's camera rule (amended in place:
it is not committed yet) and
`apps/macos/e2e/lip-reading.md` updated; German strings; precommit passes in `OutloudKit/` and
`apps/macos/`; the idle training observed in the running app.

### Phase 7 — Distribution as an experimental feature

Asked by the user on 2026-11-03, before the 0.6.0 release: lip reading is declared experimental,
and its model is installed by the app. The user decided: an "Experimental" label with a note in
the Lip Reading tab, the tab stays visible; the model is published on Hugging Face (they decided
that the non-commercial weights may be redistributed); it is downloaded by a button in the tab,
not when lip reading is turned on.

- `maxnowack/outloud-lipreading` at revision `b8b95a0325451ad7eaffd9814949e58dce023ffd`: encoder,
  both decoders and vocabularies, `SOURCES.md`, and a model card limiting use to non-commercial.
- `ModelCatalog.lipReading`, pinned like Parakeet, downloaded by the `ModelStore` and shown with
  `ModelRow` in the tab; not among the transcription models.
- `LipReadingFiles` reads the model from its snapshot folder; `outloud lips install` is gone, and a
  trained decoder lands beside the samples, to be published as the next revision.

**Definition of Done:** the repository public with every hash matching the pins; unit tests that
the catalogue pins the model, does not offer it for transcription, and that the reader finds
each language in the folder; the label, the note and the row with German strings; ADR 0034,
`docs/SPEC.md`, `docs/DESIGN.md`, `docs/ARCHITECTURE.md` and the e2e plan updated; precommit
passes in `OutloudKit/` and `apps/macos/`; the download observed once in the running app.

## Risks

- **Accuracy.** Lip reading is ambiguous by nature (p/b/m look alike); even the best English model
  misses one word in five aloud. Mitigation: Phase 0's go/no-go, the cleanup model correcting
  obvious errors, and the WER stated honestly in the settings.
- **Silent speech.** The gap between voiced and silent lips may be large. Mitigation: Phase 5,
  measured from Phase 0 on.
- **Training time on an M1 Pro.** Mitigation: frozen front end with cached features, LoRA, training
  only on mains power; Phase 0 measures it before anything is built.
- **Privacy.** Face pictures are more sensitive than sound. Mitigation: only mouth crops, only on
  the device, only while the hotkey is held, deletable; nothing is uploaded.
- **Licence.** Auto-AVSR and the datasets allow non-commercial use. Outloud is free and MIT
  licensed; whether shipping the weights in the public Mac download is covered is recorded in the
  model ADR before Phase 2 ships.
- **Disk space.** About 180 GB are free. Mitigation: no raw videos are kept, only crops.

## Open questions

- A dictation that is partly voiced and partly silent: decided as a whole in the first version, or
  per segment (Parakeet's timestamps against the frames)? Per segment is more parts; proposal: as a
  whole until the user asks otherwise.
- The threshold for Phase 0's go/no-go.
- How long training samples are kept (proposal: until the user deletes them, with the size shown).
