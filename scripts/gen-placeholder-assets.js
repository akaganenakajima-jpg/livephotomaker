/**
 * Generates minimal solid-color PNG placeholder assets for Expo prebuild.
 * No external dependencies — uses only Node.js built-in `zlib` and `fs`.
 *
 * Output:
 *   assets/icon.png           1024x1024  dark purple  (#1C1B2E)
 *   assets/splash.png         1284x2778  white        (#FFFFFF)
 *   assets/adaptive-icon.png  1024x1024  dark purple  (#1C1B2E)
 *   assets/favicon.png          48x48   dark purple  (#1C1B2E)
 */

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

/** Write a 4-byte big-endian uint32 into a buffer at offset */
function writeUInt32BE(buf, value, offset) {
  buf[offset] = (value >>> 24) & 0xff;
  buf[offset + 1] = (value >>> 16) & 0xff;
  buf[offset + 2] = (value >>> 8) & 0xff;
  buf[offset + 3] = value & 0xff;
}

/** CRC-32 table */
const crcTable = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c;
  }
  return table;
})();

function crc32(buf) {
  let crc = 0xffffffff;
  for (let i = 0; i < buf.length; i++) crc = crcTable[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function makeChunk(type, data) {
  const typeBytes = Buffer.from(type, 'ascii');
  const len = Buffer.alloc(4);
  writeUInt32BE(len, data.length, 0);
  const crcInput = Buffer.concat([typeBytes, data]);
  const crcBuf = Buffer.alloc(4);
  writeUInt32BE(crcBuf, crc32(crcInput), 0);
  return Buffer.concat([len, typeBytes, data, crcBuf]);
}

/**
 * Create a solid-color RGBA PNG (color type 2 = RGB, no alpha).
 * @param {number} width
 * @param {number} height
 * @param {number} r
 * @param {number} g
 * @param {number} b
 */
function makePNG(width, height, r, g, b) {
  // PNG signature
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR
  const ihdr = Buffer.alloc(13);
  writeUInt32BE(ihdr, width, 0);
  writeUInt32BE(ihdr, height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // color type: RGB
  ihdr[10] = 0; // compression
  ihdr[11] = 0; // filter
  ihdr[12] = 0; // interlace

  // Raw image data: each row = filter byte (0) + width*3 bytes
  const rowSize = 1 + width * 3;
  const raw = Buffer.alloc(height * rowSize);
  for (let y = 0; y < height; y++) {
    const rowStart = y * rowSize;
    raw[rowStart] = 0; // filter none
    for (let x = 0; x < width; x++) {
      const px = rowStart + 1 + x * 3;
      raw[px] = r;
      raw[px + 1] = g;
      raw[px + 2] = b;
    }
  }

  const compressed = zlib.deflateSync(raw, { level: 1 });

  return Buffer.concat([
    sig,
    makeChunk('IHDR', ihdr),
    makeChunk('IDAT', compressed),
    makeChunk('IEND', Buffer.alloc(0)),
  ]);
}

const assetsDir = path.resolve(__dirname, '../assets');
fs.mkdirSync(assetsDir, { recursive: true });

const files = [
  { name: 'icon.png', w: 1024, h: 1024, r: 0x1c, g: 0x1b, b: 0x2e },
  { name: 'splash.png', w: 1284, h: 2778, r: 0xff, g: 0xff, b: 0xff },
  { name: 'adaptive-icon.png', w: 1024, h: 1024, r: 0x1c, g: 0x1b, b: 0x2e },
  { name: 'favicon.png', w: 48, h: 48, r: 0x1c, g: 0x1b, b: 0x2e },
];

for (const f of files) {
  const outPath = path.join(assetsDir, f.name);
  fs.writeFileSync(outPath, makePNG(f.w, f.h, f.r, f.g, f.b));
  console.log(`Created ${outPath} (${f.w}x${f.h})`);
}
