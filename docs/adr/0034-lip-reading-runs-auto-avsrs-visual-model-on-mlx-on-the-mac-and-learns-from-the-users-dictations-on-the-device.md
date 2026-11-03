# 0034 – On macOS, lip reading runs Auto-AVSR's visual model on MLX Swift, watches the mouth only while the hotkey is held, and learns from the user's dictations on the device

- Status: accepted
- Date: 2026-11-03

## Context

The user asked for dictation without sound on the Mac, in German and
English, with everything — training included — on an M1 Pro with 32 GB
(`plans/LIP_READING.md`). The licence only has to allow this use; the
download should stay at a few gigabytes and be fine-tuned for the user
from their own voiced dictations.

The base model. No open sentence-level lip-reading model exists for
German. The candidates:

- **Auto-AVSR** (github.com/mpc001/auto_avsr), visual model
  `vsr_trlrs2lrs3vox2avsp_base`: 250 M parameters, 20.3 % word error on
  LRS3, English. Its code is Apache 2.0; its weights carry the terms of
  their training data (LRS2, LRS3 under CC BY-NC-ND 4.0, VoxCeleb2,
  AVSpeech), which allow non-commercial use only. Chosen.
- **LipLearner** (MIT): spots a few user-defined commands by comparing
  embeddings; it cannot dictate free text. Rejected; its on-device
  incremental learning is the pattern the fine-tuning follows.
- **AV-HuBERT** (non-commercial): close in size and accuracy, nothing
  Auto-AVSR lacks. Rejected.
- **VSP-LLM** and other models with a 7B language model behind the lip
  encoder: far beyond the size budget. Rejected.

The runtime. Recognition and the user's fine-tuning must run in the app.

- **MLX Swift** (ml-explore/mlx-swift 0.33.0): runs and trains on the
  Mac's GPU from Swift, reads safetensors. Chosen.
- **Core ML**: on-device training is limited to updatable layers, and the
  conversion is one-way. Rejected.
- **PyTorch on MPS for training with MLX in the app**, or a Python
  `training/` unit as the plan first proposed: two implementations of one
  model drift apart, and the app's fine-tuning needs the Swift one anyway.
  Rejected; the base training runs through the `outloud` CLI on the same
  Swift code. Python remains only for the one-off conversion of the
  checkpoint and for SentencePiece, which has no Swift trainer.

Measured on 2026-11-03 on the M1 Pro (`plans/LIP_READING.md` §"Status"):
the Swift port matches PyTorch to 0.03 in the encoder's output; voiced
English reads at about one second per eight seconds of video after
warm-up; in 16-bit floats it reads the same text in about 500 MB of
memory; training the decoder takes 0.011 s and encoder and decoder
0.030 s of compute per second of video.

The camera. A camera picture of the user's face is more sensitive than
their voice, and the app runs outside the App Sandbox (ADR 0009).

## Decision

We read the lips with Auto-AVSR's visual model, converted once to MLX's
layout in 16-bit floats, and run and train it with MLX Swift in a fourth
package target, `OutloudLipreading`, which only the macOS app and the CLI
link. The core target knows lip reading only through the `LipReading`
protocol, so that the iOS app does not carry MLX. One encoder serves both
languages; each language has its own decoder and SentencePiece vocabulary.
German gets a vocabulary of its own and a decoder started from the English
one, trained on German videos under free licences from Wikimedia Commons,
labelled by Parakeet — the recipe Auto-AVSR used for VoxCeleb2. Every
source and its licence is listed beside the model.

The user's fine-tuning learns low-rank adapters on the attention with the
front end frozen, holds back a tenth of the samples, keeps the epoch that
reads them best, and adopts the result only when it reads them better than
what is installed. GPU work — reading and training — runs one at a time.

The camera runs only while the hotkey is held and, in the settings'
silent practice, between the user's Start and Done. With "Learn from my
dictations" on — off until the user turns it on — it runs with every
recording, also while lip reading is off, so that the user's dictations
train the reader before it is used; training starts on its own only while
nobody uses the Mac, and the app says once when the reader is good
enough to use. Vision finds the face
on the device; only a grey 96 × 96 crop of the mouth is kept, never the
camera's picture. Training samples — mouth frames with their transcript —
are stored in `Application Support/Outloud/LipReading/`, owned by
`LipReadingFiles`, until the user deletes them, and are never sent
anywhere.

The converted model — encoder, both decoders, their vocabularies and
`SOURCES.md` — is published on Hugging Face as
`maxnowack/outloud-lipreading`, with a model card that limits its use to
non-commercial use and names Auto-AVSR and every Commons source: the
user decided on 2026-11-03 that Outloud, free and MIT licensed, may
redistribute the non-commercial weights. It is `ModelCatalog.lipReading`,
pinned to a revision and to each file's hash, and the app downloads it into
the shared Hugging Face cache like the transcription model, only when the
user asks for it in the Lip Reading settings — not at the first launch, as
most users never turn lip reading on. It is not shipped inside the app's
download, which would grow it by 610 MB for everyone. Lip reading is
marked experimental in the settings while it misreads most words.

## Consequences

- The macOS app gains the camera entitlement and usage text, and a camera
  trust boundary (`docs/ARCHITECTURE.md` §"Trust boundaries"); the rule
  "record only while the hotkey is held" (`apps/macos/AGENTS.md`) names
  the practice as its one exception.
- Samples are personal data outside the history's retention period; the
  settings show their count and size and delete them.
- The model files lie where every process of the user can write; they are
  verified when installed, not before every load — the same open question
  as the model cache (`OutloudKit/AGENTS.md` §"Security").
- `OutloudLipreading` and the CLI need `xcodebuild` and Xcode's Metal
  Toolchain to build: SwiftPM does not compile MLX's Metal shaders. Its
  tests that do not touch the GPU run under `swift test`.
- The app cannot install the model itself: a user without the conversion
  folder sees "not installed". Distribution is a decision still open.
- Silent speech is read worse than voiced speech, on which every source
  was trained; the silent practice and the user's own samples are the only
  remedy, and the settings show the measured result.
