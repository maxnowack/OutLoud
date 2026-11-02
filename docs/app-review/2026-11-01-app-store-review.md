# App Store Review Simulation — Outloud (iOS) 0.1.0 (6)

**Date:** 2026-11-01 · **Commit:** 1e5750e · **Checked:** Release build
(`iphoneos`, unsigned, and `iphonesimulator`), built with Xcode 27.2 (SDK
iOS 27.2). **No dynamic test was run:** Xcode 27.2 has no usable iOS 27
simulator runtime on this Mac (see *Not checked*).

## Verdict

**Likely to pass.** The binary and the code have nothing Apple would reject
outright. There are no private APIs, the privacy manifest matches the code,
and the only permission (microphone) is asked for in context and handled
when refused. The privacy policy and support URLs are already in App Store
Connect. The remaining risk is the upload toolchain (build with Xcode 27.1)
and what the reviewer cannot find without help (the background audio mode,
the model download, the cleanup without Apple Intelligence). The review
notes below cover those three. None of the dynamic scenarios has been run;
the user deferred them on 2026-11-01.

## Findings

### [HIGH] Upload with Xcode 27.2 is refused — ITMS-90534

- **What Apple would write:** "ITMS-90534: Invalid Toolchain — Your app was
  built with an unsupported SDK or version of Xcode."
- **Evidence:** `xcode-select -p` → `/Applications/Xcode.app` (27.2).
  `docs/RELEASE.md:106` records that App Store Connect refused a 27.2 build
  on 2026-10-30, and that 0.1.0 (6) went up from Xcode 27.1.
- **Fix:** build the submission with
  `DEVELOPER_DIR=/Applications/Xcode-27.1.0.app/Contents/Developer`, as
  `docs/RELEASE.md` says, until App Store Connect lists 27.2.

### [MEDIUM] Background mode `audio` must be findable by the reviewer — Guideline 2.5.4

- **What Apple would write:** "Your app declares support for audio in the
  UIBackgroundModes key in your Info.plist but we were unable to play any
  audible content when the app was running in the background."
- **Evidence:** `apps/ios/project.yml:57` declares `UIBackgroundModes:
  [audio]`. It is used for recording in the background:
  `ToggleDictationIntent` is an `AudioRecordingIntent` with a Live Activity
  (`apps/ios/Shared/ToggleDictationIntent.swift:9`,
  `apps/ios/Sources/BackgroundDictation.swift:44`). That use is legitimate.
  The reviewer only reaches it through the Shortcuts app or the Action
  Button, though, and not from the app's own interface.
- **Fix:** explain it in the review notes, with steps (see below).

### [MEDIUM] Core function needs a 483 MB download from a third-party host — Guideline 4.2.3(iii), 2.1

- **Evidence:** the transcription model (Parakeet v3, 483 MB, summed from
  `OutloudKit/Sources/OutloudKit/Models/ModelCatalog.swift:56`) is
  downloaded from huggingface.co at first launch
  (`OutloudKit/Sources/OutloudKit/Models/HubCache.swift:73`). The size is
  shown and needs consent, with an extra warning on cellular
  (`OutloudKit/Sources/OutloudUI/ModelSetup.swift:70`), so 4.2.3(iii) is
  met. Two risks remain: a slow review network, and Hugging Face being
  unavailable during the review. The download host `us.aws.cdn.hf.co` is
  IPv4-only, which works through Apple's DNS64/NAT64, because the app uses
  host names and not IP literals.
- **Fix:** mention the download and its size in the review notes.

### [MEDIUM] Cleanup needs Apple Intelligence — Guideline 2.1

- **Evidence:** without Apple Intelligence the cleanup switch is disabled
  and an availability note is shown
  (`apps/ios/Sources/Views/Screens.swift:59`), and `CleanUpTextIntent`
  throws `cleanupUnavailable` (`apps/ios/Sources/Intents.swift:22`). This
  handling is correct. A reviewer on a device without Apple Intelligence
  could still read it as "feature does not work".
- **Fix:** one sentence in the review notes.

### [HINT] Memory on the smallest supported iPhone is unverified — Guideline 2.1

- **Evidence:** the app needs `com.apple.developer.kernel.increased-memory-limit`
  (`apps/ios/Generated/Outloud.entitlements`) for the model. A jetsam
  termination during transcription looks like a crash to the reviewer.
- **Fix:** test on the iPhone with the least memory that runs iOS 27, before
  submitting. A simulator does not show this (ADR 0006).

### [HINT] iPhone-only app may be reviewed on an iPad — Guideline 2.4.1

- **Evidence:** `TARGETED_DEVICE_FAMILY: "1"` (`apps/ios/project.yml:66`).
  Apple may run an iPhone app on an iPad in compatibility mode.
- **Fix:** none required. Run through it once on an iPad (simulator) when
  the runtime is available.

## Checklist

| Check | Result |
| --- | --- |
| Background modes vs. code (2.5.4) | ⚠️ `audio` legitimate, needs review notes |
| `BGTaskSchedulerPermittedIdentifiers` | ➖ none declared, none used; background URLSession needs no entry |
| Usage descriptions vs. APIs (5.1.1) | ✅ only microphone used, only microphone declared |
| Usage description wording and localisation | ✅ concrete, en + de (`Resources/InfoPlist.xcstrings`) |
| Permission timing and refusal | ✅ asked on first recording (`OutloudKit/Sources/OutloudKit/Audio/AudioRecorder.swift:242`); refusal shows "Open Settings" via `openSettingsURLString` (`apps/ios/Sources/Views/DictateScreen.swift:73`) |
| Privacy manifest present and bundled | ✅ `Outloud.app/PrivacyInfo.xcprivacy` |
| Required-reason APIs vs. manifest | ✅ UserDefaults, file timestamps, disk space match; SystemBootTime declared (harmless) |
| Widget extension needs own manifest | ✅ no required-reason API in `Widgets/` or `Shared/` |
| Third-party SDKs on Apple's list | ✅ FluidAudio 0.17.7 is not on the list; no required-reason APIs in it |
| Tracking / ATT (5.1.2) | ✅ no tracking, no IDFA, `NSPrivacyTracking = false` |
| Entitlements vs. use | ✅ only `increased-memory-limit`, needed for the model |
| Associated domains | ➖ none |
| Private APIs in source (2.5.1) | ✅ grep clean (own code and FluidAudio) |
| Private frameworks linked | ✅ `otool -L`: none |
| Undefined symbols vs. public SDK `.tbd` | ✅ all in public SDK stubs (app and widget) |
| Underscore Objective-C selectors | ✅ only the app's own `@Observable` storage |
| Suspicious strings in binary | ✅ none |
| Downloaded executable code (2.5.2) | ✅ Core ML model weights only, no scripts |
| Placeholders, debug UI, staging hosts (2.1, 2.3) | ✅ none; test hooks under `#if DEBUG` (`apps/ios/Sources/AppModel.swift:56`) |
| Mentions of other platforms (2.3.10) | ✅ none |
| IPv4 literals / IPv6 | ✅ none; download works via DNS64 |
| App icon 1024, opaque | ✅ `assetutil`: 1024, `Opaque: true` |
| Launch screen | ✅ `UILaunchScreen` |
| `ITSAppUsesNonExemptEncryption` | ✅ `false`, HTTPS only |
| ATS exceptions | ✅ none |
| Accounts, deletion, Sign in with Apple (5.1.1(v), 4.8) | ➖ no accounts |
| In-app purchases (3.1) | ➖ none |
| UGC (1.2), Kids (1.3) | ➖ not applicable |
| In-app privacy information (5.1.1(i)) | ✅ Settings › Privacy |
| Privacy policy URL / support URL (5.1.1(i), 1.5) | ✅ set in App Store Connect (per the user, 2026-11-01; not reachable from the repository) |
| Upload toolchain | ❌ [finding](#high-upload-with-xcode-272-is-refused--itms-90534) |
| Release build succeeds | ✅ device and simulator |
| First launch, all allowed | ❔ no iOS 27 simulator runtime |
| First launch, all refused | ❔ same |
| Background dictation via shortcut | ❔ same, and needs a device |
| Dark mode, largest text size, smallest iPhone | ❔ same |
| iPad compatibility mode | ❔ same |

## Suggested App Review notes

> Outloud is a dictation app. Speech is transcribed on the device; the text
> is copied to the clipboard.
>
> **First launch:** the app downloads its speech recognition model (about
> 480 MB) from Hugging Face once, after the user confirms. Please allow a few
> minutes on a slow connection. After that, nothing leaves the device.
>
> **Background audio:** Outloud declares the `audio` background mode only to
> record a dictation the user starts from another app. To see it: open
> Shortcuts, create a shortcut with "Start or Stop Dictation with Outloud"
> followed by "Copy to Clipboard", and run it from any app (or assign it to
> the Action Button). A Live Activity shows the recording; running the
> shortcut again stops it and returns the text. Outloud never plays audio.
>
> **Cleanup:** removing filler words uses Apple Intelligence's on-device
> model. On a device without Apple Intelligence, the switch in Settings is
> disabled with an explanation, and dictation works without it.
>
> No account and no in-app purchases.

## Not checked

- **Every dynamic scenario (phase 3).** `xcrun simctl list runtimes` under
  Xcode 27.2 and 27.1 shows only iOS 18.5 and 26.5. The installed iOS 27.0
  and 27.1 images report "runtime profile not found", and the app requires
  iOS 27. Fix: install the iOS 27.2 simulator runtime
  (`xcodebuild -downloadPlatform iOS`, several GB), then repeat phase 3.
- **A real device:** memory headroom on the smallest supported iPhone,
  background dictation through the Action Button, microphone quality.
- **App Store Connect:** the privacy labels (should say "Data Not
  Collected"), age rating, screenshots, description. The support and
  privacy URLs are set there, but whether they load was not checked.
- **`altool --validate-app`:** not run (needs App Store Connect
  credentials and your consent).
