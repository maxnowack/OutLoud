// Puts the listing and the screenshots into the App Store version being prepared, through the
// App Store Connect API (README.md beside this file):
//
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_KEYCHAIN_ITEM=… node marketing/store-screenshots/upload.mjs
//
// Per locale it sets name and subtitle, promotional text, description and keywords from
// marketing/STORE_LISTING_*.md and replaces the 6.9" iPhone screenshots with out/ios-6.9/. For
// the version it sets the copyright, the categories and the review notes from
// marketing/STORE_SUBMISSION.md. It submits nothing for review, and leaves price, privacy
// answers, age rating and URLs to App Store Connect.

import { createHash } from 'node:crypto'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { basename, dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { api, preparedVersion, sleep, uploadParts } from './asc.mjs'

const here = dirname(fileURLToPath(import.meta.url))
const marketing = join(here, '..')
const LOCALES = { 'en-US': 'STORE_LISTING_EN.md', 'de-DE': 'STORE_LISTING_DE.md' }
const SCREENSHOT_TYPE = 'APP_IPHONE_67' // App Store Connect's slot for the 6.9" iPhone
const COPYRIGHT = '2026 Max Nowack'
const CATEGORIES = { primaryCategory: 'PRODUCTIVITY', secondaryCategory: 'UTILITIES' }
const MARKETING_URL = 'https://github.com/maxnowack/OutLoud'

// The fields of a listing: each is a "## <name> — …" heading followed by a ```text block.
const fields = (file) => {
  const text = readFileSync(join(marketing, file), 'utf8')
  return Object.fromEntries(
    [...text.matchAll(/^## ([^\n—]+?) —[^\n]*\n+```text\n([\s\S]*?)\n```/gm)].map(([, name, body]) => [name.trim(), body]),
  )
}
const reviewNotes = () => {
  const text = readFileSync(join(marketing, 'STORE_SUBMISSION.md'), 'utf8')
  return text.match(/^## 6\. App Review notes\n[\s\S]*?```text\n([\s\S]*?)\n```/m)[1]
}

const { app, version, info } = await preparedVersion()
console.log(`${app.attributes.name}, version ${version.attributes.versionString}`)

// Creates the localization when it is missing, and sets the attributes either way.
const upsert = async (type, listPath, parent, locale, attributes) => {
  const existing = (await api('GET', listPath)).data.find((l) => l.attributes.locale === locale)
  if (existing) return (await api('PATCH', `/v1/${type}/${existing.id}`, { type, id: existing.id, attributes })).data
  return (await api('POST', `/v1/${type}`, { type, attributes: { locale, ...attributes }, relationships: parent })).data
}

const uploadScreenshot = async (setId, file) => {
  const bytes = readFileSync(file)
  const created = (await api('POST', '/v1/appScreenshots', {
    type: 'appScreenshots',
    attributes: { fileName: basename(file), fileSize: statSync(file).size },
    relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: setId } } },
  })).data
  await uploadParts(created.attributes.uploadOperations, bytes, file)
  const checksum = createHash('md5').update(bytes).digest('hex')
  await api('PATCH', `/v1/appScreenshots/${created.id}`, {
    type: 'appScreenshots', id: created.id, attributes: { uploaded: true, sourceFileChecksum: checksum },
  })
  return { id: created.id, file }
}

// Apple processes an image after its upload, which can take minutes; a refused image shows here,
// not in the upload. All of them are waited for together, at the end.
const waitForProcessing = async (uploads) => {
  const end = Date.now() + 900_000
  let open = uploads
  while (open.length && Date.now() < end) {
    const states = await Promise.all(open.map(async (u) => [u, (await api('GET', `/v1/appScreenshots/${u.id}`)).data.attributes.assetDeliveryState?.state]))
    const failed = states.filter(([, state]) => state === 'FAILED')
    if (failed.length) throw new Error(`Apple refused ${failed.map(([u]) => u.file).join(', ')}`)
    open = states.filter(([, state]) => state !== 'COMPLETE').map(([u]) => u)
    if (open.length) await sleep(10_000)
  }
  if (open.length) throw new Error(`TIMEOUT after 900 s waiting for Apple to process ${open.map((u) => u.file).join(', ')}`)
}

const uploads = []
for (const [locale, file] of Object.entries(LOCALES)) {
  const f = fields(file)
  await upsert('appInfoLocalizations', `/v1/appInfos/${info.id}/appInfoLocalizations`,
    { appInfo: { data: { type: 'appInfos', id: info.id } } }, locale,
    { name: f['App name'], subtitle: f['Subtitle'] })
  const localization = await upsert('appStoreVersionLocalizations', `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`,
    { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } }, locale,
    { promotionalText: f['Promotional text'], description: f['Description'], keywords: f['Keywords'], marketingUrl: MARKETING_URL })
  console.log(`${locale}: text set`)

  const sets = (await api('GET', `/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets`)).data
  let set = sets.find((s) => s.attributes.screenshotDisplayType === SCREENSHOT_TYPE)
  if (set) {
    for (const old of (await api('GET', `/v1/appScreenshotSets/${set.id}/appScreenshots`)).data) await api('DELETE', `/v1/appScreenshots/${old.id}`)
  } else {
    set = (await api('POST', '/v1/appScreenshotSets', {
      type: 'appScreenshotSets', attributes: { screenshotDisplayType: SCREENSHOT_TYPE },
      relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: localization.id } } },
    })).data
  }
  // The file names carry the order (README.md §"Formats").
  const dir = join(here, 'out', 'ios-6.9', locale)
  for (const name of readdirSync(dir).filter((n) => n.endsWith('.png')).sort()) {
    uploads.push(await uploadScreenshot(set.id, join(dir, name)))
    console.log(`${locale}: ${name} uploaded`)
  }
}

await waitForProcessing(uploads)
console.log('Apple has processed every screenshot.')

await api('PATCH', `/v1/appStoreVersions/${version.id}`, { type: 'appStoreVersions', id: version.id, attributes: { copyright: COPYRIGHT } })
await api('PATCH', `/v1/appInfos/${info.id}`, {
  type: 'appInfos', id: info.id,
  relationships: Object.fromEntries(Object.entries(CATEGORIES).map(([k, id]) => [k, { data: { type: 'appCategories', id } }])),
})
const detail = await api('GET', `/v1/appStoreVersions/${version.id}/appStoreReviewDetail`).catch(() => null)
if (detail?.data) {
  await api('PATCH', `/v1/appStoreReviewDetails/${detail.data.id}`, { type: 'appStoreReviewDetails', id: detail.data.id, attributes: { notes: reviewNotes() } })
  console.log('Review notes set.')
} else {
  console.log('Review notes not set: App Store Connect has no review contact yet; enter the contact and the notes from STORE_SUBMISSION.md §6 there.')
}
console.log('Copyright and categories set. Nothing was submitted for review.')
