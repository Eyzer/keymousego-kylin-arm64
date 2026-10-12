# -*- coding: utf-8 -*-
"""解码 Mondrian.png（32x32 PNG），输出 ASCII 色块图 + 调色板，用于重建矢量图标。"""
import zlib
import struct
import collections

path = r'C:\Users\Administrator\WorkBuddy\2026-10-12-17-09-29\keymousego_src\Mondrian.png'
data = open(path, 'rb').read()
assert data[:8] == b'\x89PNG\r\n\x1a\n'

pos = 8
idat = b''
w = h = bitdepth = colortype = None
while pos < len(data):
    ln = struct.unpack('>I', data[pos:pos + 4])[0]
    typ = data[pos + 4:pos + 8]
    chunk = data[pos + 8:pos + 8 + ln]
    if typ == b'IHDR':
        w, h, bitdepth, colortype = struct.unpack('>IIBB', chunk[:10])
        print('IHDR %dx%d depth=%d colortype=%d' % (w, h, bitdepth, colortype))
    elif typ == b'IDAT':
        idat += chunk
    elif typ == b'PLTE':
        print('PLTE entries=%d' % (ln // 3))
    pos += 12 + ln

raw = zlib.decompress(idat)

# 依 colortype 决定通道数
ch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[colortype]
stride = w * ch
out = bytearray()
prev = bytearray(stride)
p = 0
for y in range(h):
    f = raw[p]
    p += 1
    line = bytearray(raw[p:p + stride])
    p += stride
    for i in range(stride):
        a = line[i - ch] if i >= ch else 0
        b = prev[i]
        c = prev[i - ch] if i >= ch else 0
        x = line[i]
        if f == 0:
            v = x
        elif f == 1:
            v = x + a
        elif f == 2:
            v = x + b
        elif f == 3:
            v = x + ((a + b) >> 1)
        elif f == 4:
            pp = a + b - c
            pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
            pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
            v = x + pr
        else:
            raise ValueError('filter %d' % f)
        line[i] = v & 0xFF
    out += line
    prev = line

palette = collections.Counter()
grid = []
for y in range(h):
    row = []
    for x in range(w):
        i = y * stride + x * ch
        px = tuple(out[i:i + ch])
        row.append(px)
        palette[px] += 1
    grid.append(row)

def name(px):
    r, g, b = px[0], px[1], px[2]
    if (r, g, b) == (255, 255, 255):
        return '.'
    if (r, g, b) == (0, 0, 0):
        return 'K'
    if r > 150 and g < 120 and b < 120:
        return 'R'
    if b > 120 and r < 120:
        return 'B'
    if r > 150 and g > 150 and b < 120:
        return 'Y'
    if g > 100 and r < 120:
        return 'G'
    return '?'

print('\n--- 色块图 (R红 B蓝 Y黄 G绿 K黑 .白) ---')
for y in range(h):
    print(''.join(name(px) for px in grid[y]))

print('\n--- 调色板 (前 12) ---')
for px, n in palette.most_common(12):
    print('  #%02X%02X%02X  x%d' % (px[0], px[1], px[2], n))
