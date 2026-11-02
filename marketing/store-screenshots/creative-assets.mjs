// Puts the product page header and the search results image of each locale into the app's
// Asset Library and places them on the App Store version being prepared (README.md beside this
// file):
//
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_KEYCHAIN_ITEM=… node marketing/store-screenshots/creative-assets.mjs
//
// Apple's published API does not describe the Asset Library; the public API serves it all the
// same. The requests are the ones App Store Connect's web client uses, as CatchFlights'
// `app/.scripts/asc-creative-assets.mjs` takes them (its ADR 0210). An image is uploaded under a
// name that carries its hash, so an unchanged rendering is not uploaded again. Nothing is
// submitted for review.

import { createHash } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { api, preparedVersion, sleep, uploadParts } from './asc.mjs'

const here = dirname(fileURLToPath(import.meta.url))
const ASSETS = [
  { placementType: 'PRODUCT_PAGE_HEADER_ASSET', name: 'ios-product-page-header' },
  { placementType: 'APP_STORE_SEARCH_RESULTS_ASSET', name: 'ios-search-results' },
]
const LOCALES = ['en-US', 'de-DE']

const { app, version } = await preparedVersion()
console.log(`${app.attributes.name}, version ${version.attributes.versionString}`)

const library = []
for (let next = `/v1/appAssetLibraries/${app.id}/images?limit=200`; next; ) {
  const page = await api('GET', next)
  library.push(...page.data.filter((image) => image.attributes.category === 'CREATIVE_ASSETS'))
  next = page.links?.next
}

const upload = async (fileName, bytes) => {
  const reserved = (await api('POST', '/v1/appAssetLibraryImages', {
    type: 'appAssetLibraryImages',
    attributes: { fileName, fileSize: bytes.length, category: 'CREATIVE_ASSETS' },
    relationships: { assetLibrary: { data: { type: 'appAssetLibraries', id: app.id } } },
  })).data
  await uploadParts(reserved.attributes.uploadOperations, bytes, fileName)
  await api('PATCH', `/v1/appAssetLibraryImages/${reserved.id}`, { type: 'appAssetLibraryImages', id: reserved.id, attributes: { uploaded: true } })
  // Apple answers a freshly committed image with a server error now and then; it is waited out
  // like the processing.
  const end = Date.now() + 600_000
  while (Date.now() < end) {
    const read = await api('GET', `/v1/appAssetLibraryImages/${reserved.id}`).catch((error) => {
      if (/: 5\d\d /.test(error.message)) return null
      throw error
    })
    if (read?.data.attributes.state === 'FAILED') throw new Error(`${fileName}: Apple refused it, ${JSON.stringify(read.data.attributes.stateDetails)}`)
    if (read?.data.attributes.imageAsset) return read.data
    await sleep(5000)
  }
  throw new Error(`TIMEOUT after 600 s waiting for Apple to process ${fileName}`)
}

const localizations = (await api('GET', `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`)).data
for (const locale of LOCALES) {
  const localization = localizations.find((l) => l.attributes.locale === locale)
  if (!localization) throw new Error(`${locale}: the version has no localization; run upload.mjs first.`)
  const placements = (await api('GET', `/v1/appStoreVersionLocalizations/${localization.id}/placements?include=image`)).data
  for (const asset of ASSETS) {
    const bytes = readFileSync(join(here, 'out', asset.name, locale, `${asset.name}.png`))
    const fileName = `${asset.name}-${locale}-${createHash('sha256').update(bytes).digest('hex').slice(0, 8)}.png`
    let image = library
      .filter((i) => i.attributes.fileName === fileName && i.attributes.state !== 'FAILED')
      .sort((a, b) => b.attributes.createdDate.localeCompare(a.attributes.createdDate))[0]
    if (image) console.log(`${locale}: ${fileName} already in the library (${image.attributes.state})`)
    else {
      image = await upload(fileName, bytes)
      console.log(`${locale}: ${fileName} uploaded (${image.attributes.state})`)
    }

    const occupied = placements.find((p) => p.attributes.placementType === asset.placementType)
    if (occupied?.relationships?.image?.data?.id === image.id) {
      console.log(`${locale}: ${asset.placementType} already placed`)
      continue
    }
    if (occupied) await api('DELETE', `/v1/appAssetLibraryPlacements/${occupied.id}`)
    await api('POST', '/v1/appAssetLibraryPlacements', {
      type: 'appAssetLibraryPlacements',
      attributes: { placementType: asset.placementType, placementGroup: 'DEFAULT_PROFILE' },
      relationships: {
        image: { data: { type: 'appAssetLibraryImages', id: image.id } },
        appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: localization.id } },
      },
    })
    console.log(`${locale}: ${asset.placementType} placed`)
  }
}
console.log('Nothing was submitted for review.')
