# The user confirms the transcription model at first launch and can dictate afterwards

- Covers: setup window, ModelSetup, PrivacyNotice, menu bar panel before and after setup.
- Build: Debug, `./scripts/precommit`, then the app from `.build/DerivedData/Build/Products/Debug/Outloud.app`.

## Preconditions

A first launch: `defaults delete dev.nowack.outloud` (removes `hasCompletedSetup`).
For the download branch, the model is not in the shared cache
(`swift run outloud delete parakeet-tdt-0.6b-v3` from `OutloudKit/`); for the confirm branch,
it is (`swift run outloud download`).

## Steps

1. Launch the app. The setup window "Set Up Outloud" opens and comes to the front; the menu bar
   shows the waveform icon.
2. Read the cards. "Speech recognition" shows Parakeet v3 · 483.1 MB, marked required; "Clean
   up text" has a check box and "Uses Apple Intelligence on this device. No download." — with
   Apple Intelligence off, the check box is off and disabled and the note says to switch it on.
3. Download branch: the button reads "Download 483.1 MB". Click it. A progress bar with "x of y"
   and "Stop" appear. Click "Stop": the download ends, the button returns. Click "Download …"
   again and wait: the card shows "Already on this device", the button turns into "Continue".
   Confirm branch: the card shows "Already on this device" at once; the button reads "Continue".
4. Untick "Clean up text": the download size and "Continue" stay as they were.
5. Click "Continue". macOS asks for the microphone once (allow it); the setup window closes.
6. Click the menu bar icon. The panel shows "Ready" and "Hold ⌥ Space to dictate, release it to
   paste." — ⌥ Space, since Accessibility access is not allowed yet; with it, "Hold ⌥ ⌘ …"
   (ADR 0020).

## Assertions

- After step 5, `defaults read dev.nowack.outloud hasCompletedSetup` is 1.
- The model is in `~/.cache/huggingface/hub/models--FluidInference--parakeet-tdt-0.6b-v3-coreml/`,
  in the hub layout (blobs, snapshots).
- Do not assert download speeds.

## Screen reader pass

With VoiceOver on: the model card is read as one element with name, size and state ("Already on
this device"); the cleanup check box is read as "Clean up text, On/Off", followed by its note;
the progress bar has a value.
