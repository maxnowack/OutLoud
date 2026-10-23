# The user chooses or confirms the models at first launch and can dictate afterwards

- Covers: setup window, ModelSetup, PrivacyNotice, menu bar panel before and after setup.
- Build: Debug, `./scripts/precommit`, then the app from `.build/DerivedData/Build/Products/Debug/Outloud.app`.

## Preconditions

A first launch: `defaults delete io.github.maxnowack.outloud` (removes `hasCompletedSetup`).
For the download branch, the models are not in the shared cache
(`swift run outloud delete parakeet-tdt-0.6b-v3` and `… qwen3.5-0.8b-q4_k_m` from
`OutloudKit/`); for the confirm branch, they are (`swift run outloud download`).

## Steps

1. Launch the app. The setup window "Set Up Outloud" opens and comes to the front; the menu bar
   shows the waveform icon.
2. Read the model list. "Transcription: Parakeet v3" is marked required, with 483.1 MB and
   "25 languages, German and English among them"; "Cleanup: Qwen 3.5 0.8B" has a check box,
   532.5 MB, "Multilingual". Only multilingual models are listed.
3. Download branch: the button reads "Download 1 GB" (the missing size). Click it. Each model
   shows a progress bar with "x of y"; "Stop" appears. Click "Stop": the downloads end, the
   button returns. Click "Download …" again and wait: both rows show "Already on this device",
   the button turns into "Continue".
   Confirm branch: both rows show "Already on this device" at once; the button reads "Continue".
4. Untick "Cleanup". The download size drops to the transcription model's; with it installed,
   "Continue" stays.
5. Click "Continue". macOS asks for the microphone once (allow it); the setup window closes.
6. Click the menu bar icon. The panel shows "Ready" and "Hold ⌥ Space to dictate, release it to
   paste."

## Assertions

- After step 5, `defaults read io.github.maxnowack.outloud hasCompletedSetup` is 1.
- The models are in `~/.cache/huggingface/hub/models--FluidInference--parakeet-tdt-0.6b-v3-coreml/`
  and `…/models--unsloth--Qwen3.5-0.8B-GGUF/`, in the hub layout (blobs, snapshots).
- Do not assert download speeds.

## Screen reader pass

With VoiceOver on: each model row is read as one element with name, purpose, size and state
("Already on this device"); the cleanup check box is read as "Use cleanup, On/Off"; the progress
bars have values.
