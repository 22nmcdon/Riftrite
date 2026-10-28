// Renders SVG look tests to PNGs beside them, at their own size, in the
// preinstalled Chromium (docs/plans/art/art-style-guide.md; look tests only:
// the game loads SVGs itself).
// Usage: node tools/art/render_svg.js art/look-tests/act2_look_test.svg ...
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const file of process.argv.slice(2)) {
    const svg = fs.readFileSync(file, 'utf8');
    const width = parseInt(svg.match(/width="(\d+)"/)[1], 10);
    const height = parseInt(svg.match(/height="(\d+)"/)[1], 10);
    await page.setViewportSize({ width, height });
    await page.setContent(`<html><body style="margin:0">${svg}</body></html>`);
    const out = file.replace(/\.svg$/, '.png');
    await page.screenshot({ path: out, clip: { x: 0, y: 0, width, height } });
    console.log(path.basename(out));
  }
  await browser.close();
})();
