# The user chooses or confirms the models at first launch, with a warning on cellular data

- Covers: setup screen, ModelSetup, PrivacyNotice, the switch to the tabs.
- Build: Debug, on a device or simulator with iOS 27 (`apps/ios/AGENTS.md` §"Toolchain").

## Preconditions

Freshly installed app. For the confirm branch without a download, the hub cache is placed in the
app's container: `cp -c -R ~/.cache/huggingface/hub "<data container>/Library/Application Support/Models/huggingface/"`
(`xcrun simctl get_app_container booted io.github.maxnowack.outloud data`).

## Steps

1. Launch Outloud. "Choose your models" shows "Transcription: Parakeet v3" (required, 483.1 MB,
   25 languages) and "Cleanup: Qwen 3.5 0.8B" (check box, 532.5 MB, multilingual).
2. Download branch, on Wi-Fi: tap "Download 1 GB"; progress bars and "Stop" appear; when both
   show "Already on this device", the button reads "Continue".
3. Cellular branch (device only, Wi-Fi off): the footer reads "You are on cellular data.";
   tapping "Download …" asks "Download over cellular data?" with the size; "Download …" starts
   it, dismissing the dialog does not.
4. Confirm branch: both rows show "Already on this device" at once; tap "Continue".
5. The tabs "Dictate", "History", "Settings" appear.

## Assertions

- Relaunching the app opens the tabs, not the setup.
- Only multilingual models are listed.

## Screen reader pass

Each model row is read with name, purpose, size and state; the check box is read as "Use
cleanup, On".
