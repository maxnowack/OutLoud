// Captures the raw screenshots of the iOS app for generate.mjs, in a new
// simulator per locale (README.md beside this file):
//
//   node marketing/store-screenshots/capture.mjs [--locale en-US|de-DE] [--keep]
//
// Every capture is the real app. The dictations are the app's own output from
// recordings that macOS's `say` speaks; the history holds what those
// dictations produced, nothing written in by hand. The simulators are deleted
// at the end unless --keep is given.

import { execFileSync } from 'node:child_process'
import { copyFileSync, cpSync, existsSync, mkdirSync, readFileSync, rmSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const repo = join(here, '..', '..')
const iosDir = join(repo, 'apps', 'ios')
const BUNDLE = 'dev.nowack.outloud'
const DEVICE_TYPE = 'com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max'
const SIZE = { width: 1320, height: 2868 }

// The transcription model, copied in from the local Hugging Face cache instead
// of downloaded 483 MB per simulator. Revision from ModelCatalog.swift.
const MODEL_REPO = 'models--FluidInference--parakeet-tdt-0.6b-v3-coreml'
const MODEL_REVISION = '7dd20fe6b1797d35f5e3307e8b1732d9a178edfe'
const MODEL_CACHE = join(homedir(), '.cache', 'huggingface', 'hub', MODEL_REPO, 'snapshots', MODEL_REVISION)

// What is said, oldest first, and the cleaned text; the last one is the result on the first
// screenshot. The simulator has no Apple Intelligence, so the cleaned text is written here and
// handed to the app's stand-in cleaner (`-OutloudCleanupStandIn`); it does what the cleanup does
// (docs/SPEC.md §"Cleanup"): filler words out, punctuation and paragraphs set, nothing else
// changed. German fillers are words the transcription spells correctly ("also", "sozusagen");
// `say` speaks "äh" so that it comes out as invented words.
const LOCALES = {
  'en-US': {
    voice: 'Samantha',
    language: 'en', locale: 'en_US',
    labels: { showText: 'Show text', anyApp: 'Dictate from any app', privacy: 'Privacy', historyEntry: 'shopping list' },
    dictations: [
      {
        say: 'Um, note for the shopping list: oat milk, coffee beans, and, uh, the good bread from the bakery.',
        cleaned: 'Note for the shopping list: oat milk, coffee beans and the good bread from the bakery.',
      },
      {
        say: 'So the main idea of the talk is that, um, privacy should be the default and not a setting you have to find.',
        cleaned: 'The main idea of the talk is that privacy should be the default, not a setting you have to find.',
      },
      {
        say: 'Uh, reminder: call the dentist on Monday morning and, um, move the appointment to next week.',
        cleaned: 'Reminder: call the dentist on Monday morning and move the appointment to next week.',
      },
      {
        say: 'Hey Sarah, um, I am running about ten minutes late. Could you, uh, start the meeting without me? New paragraph. Thanks, and see you soon!',
        cleaned: 'Hey Sarah, I’m running about ten minutes late. Could you start the meeting without me?\n\nThanks, and see you soon!',
      },
    ],
  },
  'de-DE': {
    voice: 'Anna',
    language: 'de', locale: 'de_DE',
    labels: { showText: 'Text anzeigen', anyApp: 'Aus jeder App diktieren', privacy: 'Datenschutz', historyEntry: 'Einkaufsliste' },
    dictations: [
      {
        say: 'Also, für die Einkaufsliste: Hafermilch, Kaffeebohnen und, sozusagen, das gute Brot vom Bäcker.',
        cleaned: 'Für die Einkaufsliste: Hafermilch, Kaffeebohnen und das gute Brot vom Bäcker.',
      },
      {
        say: 'Die Kernidee des Vortrags ist, also, dass Privatsphäre der Standard sein sollte und keine Einstellung, die man erst suchen muss.',
        cleaned: 'Die Kernidee des Vortrags ist, dass Privatsphäre der Standard sein sollte und keine Einstellung, die man erst suchen muss.',
      },
      {
        say: 'Also, Erinnerung: am Montagmorgen beim Zahnarzt anrufen und, sozusagen, den Termin auf nächste Woche verschieben.',
        cleaned: 'Erinnerung: am Montagmorgen beim Zahnarzt anrufen und den Termin auf nächste Woche verschieben.',
      },
      {
        say: 'Hallo Sarah, also, ich bin ungefähr zehn Minuten später da. Kannst du, sozusagen, schon mal ohne mich anfangen? Neuer Absatz. Danke und bis gleich!',
        cleaned: 'Hallo Sarah, ich bin ungefähr zehn Minuten später da. Kannst du schon mal ohne mich anfangen?\n\nDanke und bis gleich!',
      },
    ],
  },
}

const run = (cmd, args, opts = {}) => execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], ...opts })
const simctl = (...args) => run('xcrun', ['simctl', ...args])
const sleep = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms)

// Every wait has a deadline and says what it waited for when it expires.
const waitFor = (what, seconds, check) => {
  const end = Date.now() + seconds * 1000
  while (Date.now() < end) {
    if (check()) return
    sleep(1000)
  }
  throw new Error(`TIMEOUT after ${seconds} s waiting for ${what}`)
}

const runtime = () => {
  const { runtimes } = JSON.parse(simctl('list', 'runtimes', '-j'))
  const ios = runtimes.filter((r) => r.platform === 'iOS' && r.isAvailable && r.version.startsWith('27.'))
  if (!ios.length) throw new Error('No available iOS 27 simulator runtime: install it with `xcodebuild -downloadPlatform iOS`.')
  return ios.sort((a, b) => b.version.localeCompare(a.version, undefined, { numeric: true }))[0].identifier
}

const buildApp = () => {
  run('xcodegen', ['generate'], { cwd: iosDir })
  run('xcodebuild', ['-project', 'Outloud.xcodeproj', '-scheme', 'Outloud', '-configuration', 'Debug',
    '-sdk', 'iphonesimulator', '-destination', 'generic/platform=iOS Simulator',
    '-derivedDataPath', '.build/DerivedData', '-jobs', '4', 'build'], { cwd: iosDir, maxBuffer: 1 << 28 })
  return join(iosDir, '.build/DerivedData/Build/Products/Debug-iphonesimulator/Outloud.app')
}

const capture = (udid, locale, name) => {
  const dir = join(here, 'source', locale)
  mkdirSync(dir, { recursive: true })
  const path = join(dir, `${name}.png`)
  sleep(1500) // animations settle
  simctl('io', udid, 'screenshot', '--type=png', path)
  const header = readFileSync(path)
  const width = header.readUInt32BE(16)
  const height = header.readUInt32BE(20)
  if (width !== SIZE.width || height !== SIZE.height) throw new Error(`${path}: ${width}×${height}, expected ${SIZE.width}×${SIZE.height}`)
  console.log(`  ${locale}/${name}.png`)
}

// axe's first call after a long transcription can time out while it connects to the
// simulator, for a minute or more; it is retried, and every other failure is thrown at once.
const axe = (...args) => {
  for (let attempt = 1; ; attempt++) {
    try {
      return run('axe', args, { maxBuffer: 1 << 26 })
    } catch (error) {
      if (attempt === 8 || !String(error.stderr).includes('remote automation session')) throw error
      sleep(10000)
    }
  }
}
const labels = (udid) => axe('describe-ui', '--udid', udid)
const tap = (udid, label) => axe('tap', '--label', label, '--udid', udid, '--wait-timeout', '20', '--post-delay', '1.5')
// The app shows nothing until it has read its models and history, which takes seconds in a new
// simulator; a capture waits for a text of the screen it is after.
const waitForText = (udid, text, seconds = 60) => waitFor(`"${text}" on screen`, seconds, () => labels(udid).includes(text))

const captureLocale = (localeId, app, runtimeId, keep) => {
  const L = LOCALES[localeId]
  const udid = simctl('create', `Outloud Screenshots ${localeId}`, DEVICE_TYPE, runtimeId).trim()
  console.log(`${localeId}: simulator ${udid}`)
  try {
    simctl('boot', udid)
    simctl('bootstatus', udid, '-b')
    simctl('ui', udid, 'appearance', 'light')
    simctl('status_bar', udid, 'override', '--time', '9:41', '--dataNetwork', 'wifi', '--wifiMode', 'active',
      '--wifiBars', '3', '--cellularMode', 'active', '--cellularBars', '4', '--batteryState', 'charged', '--batteryLevel', '100')
    simctl('install', udid, app)
    simctl('privacy', udid, 'grant', 'microphone', BUNDLE)
    const language = ['-AppleLanguages', `(${L.language})`, '-AppleLocale', L.locale]
    const terminate = () => { try { simctl('terminate', udid, BUNDLE) } catch { /* not running */ } }
    // Every launch makes the cleanup available through the stand-in; a dictation's launch also
    // gives it that dictation's cleaned text.
    const launch = (args = [], cleaned = '') => {
      terminate()
      simctl('launch', udid, BUNDLE, ...language, '-OutloudCleanupStandIn', cleaned, ...args)
    }

    // The first launch, before the model is there: what a new user sees.
    launch()
    sleep(4000)
    capture(udid, localeId, '06-setup')
    terminate()

    const data = simctl('get_app_container', udid, BUNDLE, 'data').trim()
    const support = join(data, 'Library', 'Application Support')
    const snapshot = join(support, 'Models', 'huggingface', 'hub', MODEL_REPO, 'snapshots', MODEL_REVISION)
    mkdirSync(dirname(snapshot), { recursive: true })
    cpSync(MODEL_CACHE, snapshot, { recursive: true, dereference: true })

    // The dictations, one launch each; a launch is done once the history holds its entry.
    const tmp = join(data, 'tmp')
    mkdirSync(tmp, { recursive: true })
    const index = join(support, 'Outloud', 'History', 'index.json')
    // index.json is the array of entries, newest first.
    const entries = () => (existsSync(index) ? JSON.parse(readFileSync(index, 'utf8')).length : 0)
    L.dictations.forEach(({ say, cleaned }, i) => {
      const wav = join(tmp, `dictation-${i}.wav`)
      run('say', ['-v', L.voice, '-o', wav, '--data-format=LEI16@16000', say])
      const before = entries()
      launch(['-hasCompletedSetup', 'YES', '-OutloudSampleAudio', `dictation-${i}.wav`, '-OutloudAutoDictate', 'YES'], cleaned)
      // The first one also verifies the copied model and loads it.
      waitFor(`dictation ${i + 1} in ${index}`, i === 0 ? 600 : 180, () => entries() > before)
      console.log(`  dictation ${i + 1}/${L.dictations.length} kept`)
    })

    // 01: the last dictation's result, opened with "Show text".
    waitForText(udid, L.labels.showText)
    tap(udid, L.labels.showText)
    capture(udid, localeId, '01-result')

    // 03 and 04: the history and the detail of its second entry, the reminder (points, not pixels).
    launch(['-hasCompletedSetup', 'YES', '-OutloudTab', 'history'])
    waitForText(udid, L.labels.historyEntry)
    capture(udid, localeId, '03-history')
    axe('tap', '-x', '220', '-y', '330', '--udid', udid, '--post-delay', '1.5')
    capture(udid, localeId, '04-detail')

    // 02 and 05: the guide to dictating from any app, and the privacy notice. The privacy row sits
    // below the tab bar until the settings are scrolled up.
    launch(['-hasCompletedSetup', 'YES', '-OutloudTab', 'settings'])
    waitForText(udid, L.labels.anyApp)
    tap(udid, L.labels.anyApp)
    capture(udid, localeId, '02-any-app')
    launch(['-hasCompletedSetup', 'YES', '-OutloudTab', 'settings'])
    waitForText(udid, L.labels.anyApp)
    axe('swipe', '--start-x', '220', '--start-y', '700', '--end-x', '220', '--end-y', '250', '--udid', udid, '--post-delay', '1')
    tap(udid, L.labels.privacy)
    capture(udid, localeId, '05-privacy')
    terminate()
  } finally {
    if (keep) console.log(`  kept simulator ${udid}`)
    else {
      try { simctl('shutdown', udid) } catch {}
      simctl('delete', udid)
    }
  }
}

if (!existsSync(MODEL_CACHE)) throw new Error(`No local copy of the model at ${MODEL_CACHE}.`)
const only = process.argv.includes('--locale') ? [process.argv[process.argv.indexOf('--locale') + 1]] : Object.keys(LOCALES)
const keep = process.argv.includes('--keep')
const runtimeId = runtime()
console.log('Building the Debug app …')
const app = buildApp()
for (const locale of only) captureLocale(locale, app, runtimeId, keep)
