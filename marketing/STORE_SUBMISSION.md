# Store Submission

**Living document.** It owns everything about publishing Outloud for iPhone
in the App Store that does not depend on the listing language: the field
limits the listings are written against, the App Store Connect settings,
the privacy declarations, the review notes, and the keyword method. The
per-locale copy lives in `marketing/STORE_LISTING_EN.md` and
`marketing/STORE_LISTING_DE.md`; the screenshots and creative assets in
`marketing/store-screenshots/`.

It does not restate:

| Subject | Owner |
| --- | --- |
| What the app does, its rules and acceptance criteria | `docs/SPEC.md` |
| How a build is made and uploaded | `docs/RELEASE.md` §"iOS" |
| Screenshot copy, formats and how they are generated | `marketing/store-screenshots/README.md` |
| What a reviewer would reject, as of the last check | `docs/app-review/` |

The Mac app is not in the App Store; it ships through GitHub and Sparkle
(`docs/RELEASE.md` §"macOS").

## 1. Before submitting

1. **Build with an Xcode App Store Connect accepts.** On 2026-10-30 it
   refused Xcode 27.2 with ITMS-90534; 27.1 was accepted
   (`docs/RELEASE.md` §"iOS").
2. **Test memory on the smallest iPhone that runs iOS 27.** The model needs
   the increased memory limit; a termination during a transcription is a
   crash to the reviewer (Guideline 2.1). A simulator does not show it
   (ADR 0006).
3. **Re-check the live console.** Fields and screenshot slots change; the
   limits below were checked on the date they name.

## 2. Decisions owed to App Store Connect

Not derivable from the repository; the user answers them in the console:

- Price — the recommendation is **free**, matching `README.md` ("no paid
  tier").
- Countries and regions.
- Age rating questionnaire — every answer is "None" or "No": no
  user-generated content, no messaging, no web access, no gambling. The
  result should be **4+**.
- Content rights — Outloud ships no third-party content; the model it
  downloads is CC-BY-4.0 and attributed in Settings › Acknowledgements.

The privacy policy URL and the support URL were entered in App Store
Connect before 2026-11-01 (per the user).

## 3. Field limits

Checked against Apple's documentation, as summarised in
`~/code/CatchFlights/marketing/STORE_SUBMISSION.md` §3 on 2026-08-03.
Re-check before submitting.

- App name: 2–30 characters. Subtitle: 30 characters.
- Promotional text: 170 characters. Description: 4,000 characters.
- Keywords: 100 **bytes**, comma-separated, no spaces needed after
  commas. An umlaut takes two bytes.
- What's New: 4,000 characters; not shown for a first version.
- App Review notes: 4,000 bytes.
- Screenshots: 1–10 per device size and language; the 6.9" iPhone size is
  the one required (1290 × 2796 or 1320 × 2868 portrait).
- Creative assets, optional, one each per localisation: product page
  header 3840 × 1646 and search results image 3840 × 2560, JPEG or PNG
  without alpha, cropped per device to a centred safe band.

## 4. App Store Connect settings

| Setting | Value |
| --- | --- |
| Primary category | **Productivity** |
| Secondary category | **Utilities** |
| Bundle ID | `dev.nowack.outloud` |
| SKU | the one set when the record was created (2026-10-23) |
| Copyright | `2026 Max Nowack` |
| Marketing URL | `https://github.com/maxnowack/OutLoud` (optional) |
| App access | All functionality is available without special access |
| Encryption | Declared in the binary: `ITSAppUsesNonExemptEncryption = NO` |
| Devices | iPhone only (`TARGETED_DEVICE_FAMILY = 1`) |

Productivity over Utilities as the primary category: the competing
dictation apps list there, and the app is about writing, not about the
device.

## 5. App privacy

**Data Not Collected.** Outloud collects nothing that leaves the device:

- Recordings, transcripts and results stay on the iPhone
  (`docs/SPEC.md` §"Transparency and privacy").
- The only network traffic is the model download from Hugging Face
  (`OutloudKit/Sources/OutloudKit/Models/HubCache.swift`), a plain HTTPS
  GET with no identifier of the user. Apple asks only about data the app
  or its partners collect; a file download carries none.
- No analytics, no crash reporting SDK, no advertising, no tracking —
  `NSPrivacyTracking` is false and `NSPrivacyCollectedDataTypes` empty in
  `apps/ios/Resources/PrivacyInfo.xcprivacy`.
- The on-device log of dictation starts and ends (ADR 0031) never leaves
  the device.

If an SDK or a server is ever added, this section and the privacy manifest
change in the same change set.

## 6. App Review notes

Submitted in English for every locale; at most 4,000 bytes.

```text
Outloud is a dictation app. Speech is transcribed on the device and the text is copied to the clipboard. There is no account and no in-app purchase.

First launch: the app downloads its speech recognition model (about 480 MB) from Hugging Face once, after the user confirms. Please allow a few minutes on a slow connection. After that, nothing leaves the device and the app works offline.

Background audio: Outloud declares the "audio" background mode only to record a dictation the user starts from another app. To see it: open Shortcuts, create a shortcut with the action "Start or Stop Dictation with Outloud" followed by "Copy to Clipboard", and run it from any app (or assign it to the Action Button). A Live Activity shows the recording; running the shortcut again stops it and returns the text. Outloud never plays audio. In the app, Settings > "Dictate from any app" explains the setup.

Cleanup: removing filler words and setting punctuation uses Apple Intelligence's on-device model. On a device without Apple Intelligence, the switch in Settings is disabled with an explanation, and dictation works without it.
```

## 7. Keywords

Apple indexes the app name, the subtitle and the keyword field together;
a word in one of them gains nothing from being repeated in another, and
singular and plural count as one. The keyword field therefore holds only
words that are in neither the name nor the subtitle, ordered by how
plainly they describe what a searcher wants.

- No competitor or trademark names (Guideline 2.3.7): not "Wispr",
  "Superwhisper", "Whisper", "Siri".
- No words the app does not deliver: not "translate", "keyboard",
  "meeting", "summary".
- Search volumes were not measured; the choice rests on the words the
  README already uses for the same audience. Revisit once App Store
  Connect shows impressions per search term.
