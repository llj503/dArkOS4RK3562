const fs = require('fs');
const zlib = require('zlib');
const w = 1024, h = 768;
const raw = fs.readFileSync(process.argv[2]);

function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const t = Buffer.from(type);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([t, data])));
  return Buffer.concat([len, t, data, crc]);
}
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
const row = Buffer.alloc(1 + w * 4);
const lines = [];
for (let y = 0; y < h; y++) {
  row[0] = 0;
  for (let x = 0; x < w; x++) {
    const s = (y * w + x) * 4, d = 1 + x * 4;
    row[d] = raw[s + 2]; row[d + 1] = raw[s + 1]; row[d + 2] = raw[s]; row[d + 3] = 255;
  }
  lines.push(Buffer.from(row));
}
const idat = zlib.deflateSync(Buffer.concat(lines), { level: 6 });
fs.writeFileSync(process.argv[3], Buffer.concat([
  Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
  chunk('IHDR', ihdr), chunk('IDAT', idat), chunk('IEND', Buffer.alloc(0)),
]));
console.log('ok');
