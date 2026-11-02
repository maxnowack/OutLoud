# Store screenshots

The App Store screenshots and creative assets of Outloud for iPhone, in
English and German, generated from captures of the real app (ADR 0032).
Nothing is retouched; the one stand-in is the cleanup's text (below).
Every headline is true of the screen beneath it or of `docs/SPEC.md`.

## Layout

```
source/<locale>/<screen>.png   raw 1320 × 2868 captures (iPhone 17 Pro Max)
copy.json                      eyebrow, headline, subline per screen and locale
capture.mjs                    the simulator run that takes the captures
generate.mjs                   the renderer
check-listing.mjs              checks the listing copy against the field limits
out/<format>/<locale>/*.png    the deliverables
out/MANIFEST.txt               what the last run produced
```

## Formats

| Folder | Size | Where it goes |
| --- | --- | --- |
| `ios-6.9` | 1320 × 2868 | App Store Connect, iPhone 6.9" — the one size required |
| `ios-product-page-header` | 3840 × 1646 | App Store Connect › creative assets, product page header (optional) |
| `ios-search-results` | 3840 × 2560 | App Store Connect › creative assets, search results image (optional) |

Screens, in upload order (the file name carries it): 01 result, 02 dictating
from any app, 03 history, 04 a result's detail, 05 privacy, 06 first
launch. The creative assets keep their headline and both phones inside the
centred band Apple guarantees to show (`SAFE_AREA` in `generate.mjs`); check
a new composition against it before uploading.

## Running

From `marketing/`, once: `npm ci`, then
`npx puppeteer browsers install chrome` (the install script is not run by
`npm ci` when scripts are not allowed).

```bash
node store-screenshots/capture.mjs
```

needs the iOS 27 simulator runtime (`xcodebuild -downloadPlatform iOS`),
`xcodegen`, `axe` (`brew install cameroncooke/axe/axe`) and the
transcription model in `~/.cache/huggingface/hub` (the Mac app or
`outloud` puts it there). It builds the Debug app into
`apps/ios/.build/DerivedData`, and per locale creates a simulator, takes
the captures and deletes the simulator again (`--keep` keeps it,
`--locale de-DE` runs one). A run takes about ten minutes, most of it the
first transcription.

```bash
node store-screenshots/generate.mjs [--only ios-6.9]
```

renders `out/` from `source/` and `copy.json` in about a minute.

```bash
node store-screenshots/check-listing.mjs
```

counts every field of `marketing/STORE_LISTING_*.md` against its limit.

## What is real in these screenshots, and what is not

| On screen | Where it comes from |
| --- | --- |
| The transcripts | The app's own transcription of recordings `say` speaks (`LOCALES` in `capture.mjs`) |
| The cleaned texts | Written in `LOCALES`, as the cleanup produces them, and returned by the Debug-only stand-in cleaner (`-OutloudCleanupStandIn`), since the simulator has no Apple Intelligence |
| The history | The entries those dictations left |
| Every other screen | The app as it launches, in a new simulator |
| Status bar (9:41, full battery) | `simctl status_bar override` |

The cleanup runs on Apple's on-device model, which the iOS 27 simulator
does not offer: the app reports it as not ready even with Apple
Intelligence on the Mac. When the cleanup changes what it does, check the
cleaned texts in `LOCALES` against it.

The iOS 27 runtimes that Xcode 27.2 installs are cryptex mounts, which
the simulator never registers (`xcrun simctl list runtimes` lacks them).
Installed as a plain disk image instead, the runtime works:

1. `xcodebuild -downloadPlatform iOS -exportPath <dir>` writes the
   runtime's `.dmg` under `<dir>/*.exportedBundle/Restore/`.
2. `xcrun simctl runtime scan-and-mount`, then `xcrun simctl runtime
   delete <id>` for the cryptex entry of the same build
   (`xcrun simctl runtime list`). The first delete leaves its asset
   behind; after the scan, the second one removes it.
3. `xcrun simctl runtime add <the .dmg>`: it mounts as "Disk Image
   Mount", "Verified", and shows in `xcrun simctl list runtimes`.

## Design

The backdrop is the icon's teal (`accentFill` #1F7A70, `docs/DESIGN.md`
§"Colour"), darkened so white type keeps its contrast, with the icon's
sound arcs repeated outwards. The accent span is a light tint of the
dark-mode `accent`. Type is the system font, as in the app.
