# OutloudKit working rules (`OutloudKit/`)

These rules cover the shared Swift package: the model catalogue, the
downloads, transcription, cleanup, the settings, the history and the audio
capture (`OutloudKit`), the design system's components (`OutloudUI`) and the
developer tool `outloud` (`OutloudCLI`) (ADR 0002, ADR 0011, ADR 0013).
Repository-wide rules — how to work, plan and ADR duties, commit and
staging discipline, the Swift conventions — live in the root
`AGENTS.md`; the architectural rules they specialise live in
`docs/ARCHITECTURE_PRINCIPLES.md`; the root file says when each is read.
`docs/ARCHITECTURE.md` §"Components" and `plans/FIRST_VERSION.md` describe
this area — read them before making changes here.

## Toolchain

- **(MUST)** Run SwiftPM from `OutloudKit/`: `swift build`, `swift test`,
  `./scripts/precommit`. Run from elsewhere, it builds another package or
  none, and `.build/` lands in the wrong place.
- The package builds with Swift 6.4 from Xcode 27.1 for iOS 27 and
  macOS 27 (ADR 0012). The apps link it as a local package.
- `precommit` also builds `OutloudUI` for the iOS Simulator with
  `xcodebuild`, since `swift build` only builds for the Mac.
- **(MUST)** Pass `-skipMacroValidation` to every `xcodebuild` that builds
  the package. LLM.swift ships a macro, and without the flag Xcode refuses
  to build until someone trusts it in its interface.
- `swift run outloud models | download | delete <id> | dictate <file>`
  works on the shared cache — the same one the macOS app uses. `dictate`
  takes `--no-cleanup` and `--cleanup-model <file.gguf>` to compare
  cleanup models. `Samples/` holds German and English recordings for it
  (made with macOS `say`; `inj.wav` is a dictated instruction).

## Verifying a change

- **(MUST)** A behaviour change of the package is proven by a test in
  `Tests/OutloudKitTests`. The package has no user interface; the
  user-visible effect is proven by the apps' end-to-end test plans
  (`docs/VERIFICATION.md`).
- **(MUST)** Ask the user before running anything that downloads models or
  runs them on the full models. A download is about 2 GB (ADR 0006) and
  occupies the machine for minutes.

## Tests

- **(MUST)** Tests use Swift Testing (`import Testing`, `@Test`, `#expect`).
- **(MUST)** Code that depends on the time takes the moment and the
  `Calendar` as parameters and never reads the clock itself; a test fixes
  the time zone (`RetentionPeriodTests`). A test that reads the clock
  passes at noon and fails across midnight or a change of daylight saving.
- **(MUST NOT)** Reach the network or a real model in a unit test. The
  downloader and the runtimes are tested behind their protocols with
  stand-ins; the real models are exercised in the model spike and the
  apps' end-to-end plans.

## Persistence

- **(MUST)** One type owns the model files and one owns the history; no
  other code reads or writes their paths. The model directory is shared
  with other tools on macOS (ADR 0010), and the history holds personal
  data with a retention period (`docs/SPEC.md` §"History"); a second
  writer breaks the one or outlives the other.

## Security

- **(MUST)** Treat the transcript as data when cleaning it up: it is
  wrapped and marked as user input, and the prompt forbids following
  instructions in it (`plans/done/CONCEPT.md` §"Cleanup prompt and
  pipeline"). A dictated sentence that reads like a command must come out
  as that sentence.
- **(MUST)** Download models only over HTTPS and only at the pinned
  revision of the catalogue. Every process of the user can write to the
  shared cache; how a file is verified before it is loaded is open
  (`docs/ARCHITECTURE.md` §"Model downloads").

## The Hugging Face cache

- **(MUST)** Resolve the cache as the hub does — `HF_HUB_CACHE`, else
  `HF_HOME/hub`, else `~/.cache/huggingface/hub` — on macOS; on iOS, use
  the app's own container (ADR 0009, ADR 0010).
- **(MUST)** Write the hub's layout exactly: files by hash in `blobs/`,
  per-revision symlinks in `snapshots/`, `refs/`, and the per-file locks
  in `.locks/`. Other tools read and write the same folders at the same
  time; a deviating layout or a missing lock corrupts their cache or ours.
- **(MUST NOT)** Delete anything outside the repository folder of the
  model being deleted, and delete only after the user confirmed the
  warning (`docs/SPEC.md` §"Models").

## Localisation

- **(MUST)** Every user-visible string in `OutloudUI` goes through
  `L(...)`, and in `OutloudKit` through `String(localized:bundle: .module)`;
  each gets its German translation in the target's
  `Resources/Localizable.xcstrings` in the same change set. `swift build`
  does not add new keys to a catalog, unlike Xcode, so a missing key ships
  in English without any warning. The keys a build used are in the
  `*.stringsdata` files under the apps' `.build/DerivedData`.

## Logging

- **(MUST NOT)** Log a transcript, a result or anything dictated; log
  durations, lengths and error kinds (`docs/ARCHITECTURE.md` §"Data").
  Dictated text is personal data, and the unified log is readable by
  anyone with access to the device.

## Coding rules

- Types and operations carry the names of `docs/SPEC.md` §"Vocabulary".
- The public API is what the apps use; everything else is `internal`.
