// The App Store Connect API for upload.mjs and creative-assets.mjs: the key, the requests, and
// the app's version being prepared.

import { execFileSync } from 'node:child_process'
import { createPrivateKey, sign } from 'node:crypto'
import { readFileSync } from 'node:fs'

const BUNDLE = 'dev.nowack.outloud'

// The API key as docs/RELEASE.md §"iOS" describes it: a .p8 file, or a keychain item.
const key = (() => {
  const { ASC_KEY_ID: keyId, ASC_ISSUER_ID: issuer, ASC_KEY_PATH: path, ASC_KEY_KEYCHAIN_ITEM: item } = process.env
  if (!keyId || !issuer || !(path || item)) throw new Error('Set ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH or ASC_KEY_KEYCHAIN_ITEM.')
  let pem = path
    ? readFileSync(path, 'utf8')
    : execFileSync('security', ['find-generic-password', '-s', item, '-w'], { encoding: 'utf8' }).trim()
  // `security` prints a value with line breaks as hex.
  if (/^([0-9a-f]{2})+$/.test(pem)) pem = Buffer.from(pem, 'hex').toString('utf8')
  if (!pem.includes('BEGIN PRIVATE KEY')) pem = `-----BEGIN PRIVATE KEY-----\n${pem.replace(/\s/g, '')}\n-----END PRIVATE KEY-----\n`
  return { id: keyId, issuer, secret: createPrivateKey(pem) }
})()

// A token lives at most 20 minutes, and Apple's processing of an image can take minutes, so a
// new one is signed every ten.
let signed = { token: '', until: 0 }
const token = () => {
  const now = Math.floor(Date.now() / 1000)
  if (now < signed.until) return signed.token
  const part = (value) => Buffer.from(JSON.stringify(value)).toString('base64url')
  const body = `${part({ alg: 'ES256', kid: key.id, typ: 'JWT' })}.${part({ iss: key.issuer, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1' })}`
  signed = { token: `${body}.${sign('sha256', Buffer.from(body), { key: key.secret, dsaEncoding: 'ieee-p1363' }).toString('base64url')}`, until: now + 600 }
  return signed.token
}

/** A request; `path` is relative to the API or a full `links.next` URL. */
export const api = async (method, path, data) => {
  const response = await fetch(path.startsWith('https://') ? path : `https://api.appstoreconnect.apple.com${path}`, {
    method,
    headers: { Authorization: `Bearer ${token()}`, 'Content-Type': 'application/json' },
    body: data ? JSON.stringify({ data }) : undefined,
  })
  if (response.status === 204) return null
  const json = await response.json()
  if (!response.ok) throw new Error(`${method} ${path}: ${response.status} ${json.errors?.map((e) => e.detail ?? e.title).join('; ')}`)
  return json
}

export const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

/** Sends a file's bytes as the upload operations of a reserved asset prescribe. */
export const uploadParts = async (operations, bytes, name) => {
  for (const op of operations) {
    const response = await fetch(op.url, {
      method: op.method,
      headers: Object.fromEntries((op.requestHeaders ?? []).map((h) => [h.name, h.value])),
      body: bytes.subarray(op.offset, op.offset + op.length),
    })
    if (!response.ok) throw new Error(`upload of ${name}: ${response.status}`)
  }
}

/** The app, and its App Store version and app info that can still be edited. */
export const preparedVersion = async () => {
  const app = (await api('GET', `/v1/apps?filter[bundleId]=${BUNDLE}`)).data[0]
  const editable = (state) => ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED'].includes(state)
  const version = (await api('GET', `/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS`)).data
    .find((v) => editable(v.attributes.appStoreState))
  const info = (await api('GET', `/v1/apps/${app.id}/appInfos`)).data.find((i) => editable(i.attributes.appStoreState ?? i.attributes.state))
  if (!version || !info) throw new Error('No App Store version in preparation; create one in App Store Connect first.')
  return { app, version, info }
}
