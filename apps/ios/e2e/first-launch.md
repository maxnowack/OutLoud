# The user chooses or confirms the models at first launch, with a warning on cellular data

- Covers: setup screen, ModelSetup, PrivacyNotice, the switch to the tabs.
- Build: Debug, on a device or simulator with iOS 27 (`apps/ios/AGENTS.md` §"Toolchain").

## Preconditions

Freshly installed app. For the confirm branch without a download, the hub cache is placed in the
app's container: `cp -c -R ~/.cache/huggingface/hub "<data container>/Library/Application Support/Models/huggingface/"`
(`xcrun simctl get_app_container booted dev.nowack.outloud data`).

## Steps

1. Launch Outloud. "Welcome to Outloud" fits the screen without scrolling: a card "Speech
   recognition" (Parakeet v3 · 483.1 MB, marked required) and a card "Clean up text" with a
   check box and "Uses Apple Intelligence on this device. No download." — or, with Apple
   Intelligence off, the check box off and disabled and a note saying to switch it on; "What
   happens with my data?" opens the privacy text in a sheet.
2. Download branch, on Wi-Fi: tap "Download 483.1 MB"; a progress bar and "Stop" appear; when
   it shows "Already on this device", the button reads "Continue".
3. Cellular branch (device only, Wi-Fi off): the footer reads "You are on cellular data.";
   tapping "Download …" asks "Download over cellular data?" with the size; "Download …" starts
   it, dismissing the dialog does not.
4. Confirm branch: the model shows "Already on this device" at once; tap "Continue".
5. The tabs "Dictate", "History", "Settings" appear.

On the device, during the download branch (`plans/BACKGROUND_DICTATION.md` phase 1):

6. Background: switch to another app for a few minutes, then back. The download went on
   while Outloud was in the background, or is complete.
7. Retry: turn on airplane mode while the model downloads, so that it fails; turn it off.
   The card shows the message and "Retry"; tapping it restarts the download.

## Assertions

- Relaunching the app opens the tabs, not the setup.
- Only multilingual models are listed.

## Screen reader pass

Each model row is read with name, purpose, size and state; the check box is read as "Use
cleanup, On".
