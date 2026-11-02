// Renders the App Store screenshots and creative assets from the raw captures in
// `source/<locale>/` and the copy in `copy.json` (README.md beside this file).
//
//   node marketing/store-screenshots/generate.mjs [--only <format,…>]
//
// Captures are inlined as data URIs, so the render never touches the network.
// Type is the system font (SF Pro), which Chrome resolves on macOS; the output
// is byte-identical for the same captures on the same macOS.

import { readdir, readFile, mkdir, writeFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import puppeteer from 'puppeteer'
import { PNG } from 'pngjs'

const here = dirname(fileURLToPath(import.meta.url))
const copy = JSON.parse(await readFile(join(here, 'copy.json'), 'utf8'))
const LOCALES = ['en-US', 'de-DE']

// The 6.9" size of the iPhone 17 Pro Max, which `capture.mjs` photographs: the
// captures fill the frame's screen without being scaled to another aspect.
const CAPTURE_ASPECT = 1320 / 2868

// Each format renders at `supersample` times its size and is averaged back
// down, so the UI text inside the shrunken capture stays legible.
const FORMATS = [
  { id: 'ios-6.9', width: 1320, height: 2868, kind: 'portrait', supersample: 2 },
  { id: 'ios-product-page-header', width: 3840, height: 1646, kind: 'wide', supersample: 1 },
  { id: 'ios-search-results', width: 3840, height: 2560, kind: 'wide', supersample: 1 },
]

// App Store creative assets are cropped per device and carry the app's name and
// Get button; only a centred band always shows. Measured from Apple's templates
// (developer.apple.com/app-store/asset-best-practices) as shares of the size.
const SAFE_AREA = {
  'ios-product-page-header': { left: 0.285, right: 0.715, top: 0.301, bottom: 0.701 },
  'ios-search-results': { left: 0.218, right: 0.782, top: 0.298, bottom: 0.702 },
}

// From docs/DESIGN.md §"Colour": `accentFill` #1F7A70 is the icon's colour; the
// backdrop darkens it so white type keeps its contrast, and the accent span
// takes a lighter tint of the dark-mode `accent` #4CC2B2.
const INK = '#FFFFFF'
const ACCENT = '#7FE3D4'
const MUTED = 'rgba(255,255,255,0.74)'

const escapeText = (text) => text.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' })[c])
// `*accented*` in the copy becomes the accent span; everything else is escaped.
const renderHeadline = (text) =>
  escapeText(text).replace(/\*([^*]+)\*/g, (_, a) => `<span class="accent">${a.replace(/ /g, ' ')}</span>`)

const dataUri = async (path) => `data:image/png;base64,${(await readFile(path)).toString('base64')}`

// The icon's two sound arcs, repeated outwards from an origin off the frame.
const arcs = (cx, cy) => `
  <svg class="arcs" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">
    ${[22, 36, 50, 64, 78, 92].map((r, i) => `<path d="M ${cx + r * Math.cos(-0.9)} ${cy + r * Math.sin(-0.9)} A ${r} ${r} 0 0 1 ${cx + r * Math.cos(0.9)} ${cy + r * Math.sin(0.9)}" style="opacity:${0.16 - i * 0.02}" />`).join('')}
  </svg>`

const baseCss = (w, h) => `
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: ${w}px; height: ${h}px; }
  body {
    overflow: hidden; position: relative;
    font-family: system-ui, -apple-system, 'SF Pro Display', sans-serif;
    background: linear-gradient(170deg, #0A2B27 0%, #0F3A35 45%, #17564E 100%);
    -webkit-font-smoothing: antialiased;
  }
  .arcs { position: absolute; inset: 0; width: 100%; height: 100%; fill: none; stroke: #9FF0E3; stroke-width: 1.1; stroke-linecap: round; }
  .glow { position: absolute; inset: 0; background: radial-gradient(70% 45% at 50% 100%, rgba(76,194,178,0.28), rgba(76,194,178,0) 70%); }
  .accent { color: ${ACCENT}; }
  .eyebrow { font-family: ui-monospace, 'SF Mono', monospace; font-weight: 700; color: ${ACCENT}; text-transform: uppercase; }
  h1 { font-weight: 700; color: ${INK}; text-wrap: balance; }
  .subline { color: ${MUTED}; font-weight: 500; text-wrap: pretty; }
  .device { position: absolute; background: #050807; box-shadow: 0 40px 120px rgba(0,0,0,0.45), 0 0 0 2px rgba(255,255,255,0.10) inset; }
  .screen { position: absolute; overflow: hidden; background: #000; }
  .screen img { display: block; width: 100%; height: 100%; }
`

// A phone of the given screen width at (x, y); the bezel and corners scale with it.
const phone = (capture, { x, y, width, rotate = 0 }) => {
  const height = width / CAPTURE_ASPECT
  const bezel = width * 0.035
  const radius = width * 0.135
  return `
  <div class="device" style="left:${x - bezel}px; top:${y - bezel}px; width:${width + 2 * bezel}px; height:${height + 2 * bezel}px; border-radius:${radius + bezel}px; transform: rotate(${rotate}deg);">
    <div class="screen" style="left:${bezel}px; top:${bezel}px; width:${width}px; height:${height}px; border-radius:${radius}px;">
      <img src="${capture}" alt="" />
    </div>
  </div>`
}

const portrait = (w, h, { eyebrow, headline, subline }, capture) => {
  const screenWidth = w * 0.78
  return {
    css: `
      header { position: absolute; top: ${h * 0.058}px; left: ${w * 0.08}px; right: ${w * 0.08}px; text-align: center; }
      .eyebrow { font-size: ${w * 0.03}px; letter-spacing: ${w * 0.005}px; margin-bottom: ${h * 0.012}px; }
      h1 { font-size: ${w * 0.083}px; line-height: 1.06; letter-spacing: ${w * -0.0016}px; }
      .subline { font-size: ${w * 0.04}px; line-height: 1.3; margin-top: ${h * 0.014}px; }`,
    body: `
      ${arcs(8, 74)}<div class="glow"></div>
      <header>
        <p class="eyebrow">${escapeText(eyebrow)}</p>
        <h1>${renderHeadline(headline)}</h1>
        <p class="subline">${escapeText(subline)}</p>
      </header>
      ${phone(capture, { x: (w - screenWidth) / 2, y: h * 0.315, width: screenWidth })}`,
  }
}

// The header and the search image: the headline on the left half of the safe
// band, two phones fanned on the right half, so a crop keeps both.
const wide = (w, h, format, { eyebrow, headline, subline }, captures) => {
  const safe = SAFE_AREA[format]
  const left = w * safe.left
  const right = w * safe.right
  const top = h * safe.top
  const bandHeight = h * (safe.bottom - safe.top)
  const mid = (left + right) / 2
  const screenHeight = bandHeight * 1.18
  const screenWidth = screenHeight * CAPTURE_ASPECT
  const headlineWidth = mid - left - w * 0.01
  const textScale = Math.min(headlineWidth, bandHeight * 1.2)
  const phones = captures.slice(0, 2).map((capture, i) =>
    phone(capture, {
      x: mid + w * 0.012 + i * screenWidth * 0.62,
      y: top + bandHeight / 2 - screenHeight / 2 + (i === 0 ? -bandHeight * 0.06 : bandHeight * 0.1),
      width: screenWidth,
      rotate: i === 0 ? -4 : 5,
    })).reverse()
  return {
    css: `
      header { position: absolute; left: ${left}px; width: ${headlineWidth}px; top: ${top + bandHeight / 2}px; transform: translateY(-50%); }
      .eyebrow { font-size: ${textScale * 0.045}px; letter-spacing: ${textScale * 0.008}px; margin-bottom: ${textScale * 0.03}px; }
      h1 { font-size: ${textScale * 0.12}px; line-height: 1.05; letter-spacing: ${textScale * -0.002}px; }
      .subline { font-size: ${textScale * 0.055}px; line-height: 1.3; margin-top: ${textScale * 0.035}px; }`,
    body: `
      ${arcs(50, 50)}<div class="glow"></div>
      <header>
        <p class="eyebrow">${escapeText(eyebrow)}</p>
        <h1>${renderHeadline(headline)}</h1>
        ${subline ? `<p class="subline">${escapeText(subline)}</p>` : ''}
      </header>
      ${phones.join('')}`,
  }
}

// Averages each `factor × factor` block into one opaque pixel; App Store Connect
// refuses images with an alpha channel, so the output is written as RGB.
const downscale = (shot, width, height, factor) => {
  const big = PNG.sync.read(shot)
  const small = new PNG({ width, height })
  const n = factor * factor
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      let r = 0, g = 0, b = 0
      for (let dy = 0; dy < factor; dy += 1) {
        for (let dx = 0; dx < factor; dx += 1) {
          const from = ((y * factor + dy) * big.width + x * factor + dx) << 2
          r += big.data[from]; g += big.data[from + 1]; b += big.data[from + 2]
        }
      }
      const to = (y * width + x) << 2
      small.data[to] = Math.round(r / n); small.data[to + 1] = Math.round(g / n); small.data[to + 2] = Math.round(b / n); small.data[to + 3] = 255
    }
  }
  return PNG.sync.write(small, { colorType: 2 })
}

const only = process.argv.includes('--only') ? process.argv[process.argv.indexOf('--only') + 1].split(',') : null
const browser = await puppeteer.launch()
const page = await browser.newPage()
const written = []
try {
  for (const format of FORMATS.filter((f) => !only || only.includes(f.id))) {
    for (const locale of LOCALES) {
      const sourceDir = join(here, 'source', locale)
      if (!existsSync(sourceDir)) throw new Error(`No captures in ${sourceDir}; run capture.mjs first.`)
      const captureOf = async (file) => dataUri(join(sourceDir, `${file}.png`))
      const frames = format.kind === 'portrait'
        ? await Promise.all(copy[locale].screens.map(async (s) => ({ name: s.file, ...portrait(format.width, format.height, s, await captureOf(s.file)) })))
        : [{ name: format.id, ...wide(format.width, format.height, format.id, copy[locale].wide, await Promise.all(copy[locale].wide.screens.map(captureOf))) }]
      const outDir = join(here, 'out', format.id, locale)
      await mkdir(outDir, { recursive: true })
      for (const frame of frames) {
        const f = format.supersample
        await page.setViewport({ width: format.width, height: format.height, deviceScaleFactor: f })
        await page.setContent(`<!doctype html><html><head><meta charset="utf-8"><style>${baseCss(format.width, format.height)}${frame.css}</style></head><body>${frame.body}</body></html>`, { waitUntil: 'load' })
        const shot = await page.screenshot({ type: 'png', omitBackground: false })
        const png = f === 1 ? PNG.sync.write(PNG.sync.read(shot), { colorType: 2 }) : downscale(shot, format.width, format.height, f)
        const check = PNG.sync.read(png)
        if (check.width !== format.width || check.height !== format.height) throw new Error(`${frame.name}: ${check.width}×${check.height}, expected ${format.width}×${format.height}`)
        const path = join(outDir, `${frame.name}.png`)
        await writeFile(path, png)
        written.push(path.slice(here.length + 1))
      }
    }
  }
} finally {
  await browser.close()
}
await writeFile(join(here, 'out', 'MANIFEST.txt'), (await listOut()).join('\n') + '\n')
console.log(`${written.length} images written; out/MANIFEST.txt lists them.`)

async function listOut() {
  const files = []
  for (const format of await readdir(join(here, 'out'), { withFileTypes: true })) {
    if (!format.isDirectory()) continue
    for (const locale of await readdir(join(here, 'out', format.name))) {
      for (const file of (await readdir(join(here, 'out', format.name, locale))).sort()) files.push(`${format.name}/${locale}/${file}`)
    }
  }
  return files.sort()
}
