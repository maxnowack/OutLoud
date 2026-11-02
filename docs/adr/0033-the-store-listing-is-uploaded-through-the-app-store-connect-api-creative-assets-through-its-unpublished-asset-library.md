# 0033 – The App Store listing, screenshots and creative assets are uploaded by scripts through the App Store Connect API, the creative assets through its unpublished Asset Library

- Status: accepted
- Date: 2026-11-02

## Context

The listing copy, the screenshots and the creative assets live in
`marketing/` (ADR 0032). Each App Store version needs them in App Store
Connect, in two languages: 5 text fields, 6 screenshots, a product page
header and a search results image per locale. The release script already
holds an App Store Connect API key (ADR 0023, `docs/RELEASE.md` §"iOS").

The alternatives:

- **Typing and dragging them into App Store Connect.** Rejected: 24 files
  and 10 text fields per version, by hand, with nothing that says whether
  what is online matches the repository.
- **fastlane `deliver`.** Rejected: a Ruby toolchain for one step, its own
  folder layout to generate from our files, and no creative assets.
- **Leaving the creative assets to the console.** Apple's published
  OpenAPI does not describe the Asset Library. The public API serves it
  all the same, with the requests App Store Connect's web client uses;
  CatchFlights has used them since 2026-10-06 (its ADR 0210).

## Decision

We upload with two Node scripts beside the generator, using the release
script's API key: `marketing/store-screenshots/upload.mjs` sets name,
subtitle, promotional text, description, keywords, marketing URL,
copyright, categories and review notes of the version being prepared,
and replaces its 6.9" iPhone screenshots;
`marketing/store-screenshots/creative-assets.mjs` uploads the header and
the search results image to the app's Asset Library under a name carrying
their hash, and places them on that version's localizations.

Neither script submits anything for review. Price, availability, the
privacy answers, the age rating and the URLs stay in the console.

## Consequences

- What is in App Store Connect can be reproduced from the repository with
  two commands; a change to the listing or the screenshots is uploaded the
  same way.
- The Asset Library calls rest on an API Apple has not published. When
  Apple changes it, `creative-assets.mjs` breaks and the images go up by
  hand until it is fixed.
- On 2026-11-02 Apple placed images that were not yet approved on a
  version in preparation; they are reviewed with it. A version that is
  live or in review takes only approved images (CatchFlights, ADR 0210).
- The API key needs a role that may edit the app's metadata; the release
  key had it on 2026-11-02.
