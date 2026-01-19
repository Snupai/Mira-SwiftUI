#!/usr/bin/env python3
"""Generate DMG background image with a nice arrow."""
import math
import struct
import zlib

WIDTH = 660
HEIGHT = 400

def create_png(width, height, pixels):
    """Create a PNG from raw RGBA pixels."""
    def png_chunk(chunk_type, data):
        chunk_len = struct.pack('>I', len(data))
        chunk_crc = struct.pack('>I', zlib.crc32(chunk_type + data) & 0xffffffff)
        return chunk_len + chunk_type + data + chunk_crc
    
    signature = b'\x89PNG\r\n\x1a\n'
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    ihdr = png_chunk(b'IHDR', ihdr_data)
    
    raw_data = b''
    for y in range(height):
        raw_data += b'\x00'
        raw_data += pixels[y * width * 4:(y + 1) * width * 4]
    
    compressed = zlib.compress(raw_data, 9)
    idat = png_chunk(b'IDAT', compressed)
    iend = png_chunk(b'IEND', b'')
    
    return signature + ihdr + idat + iend

def clamp(x):
    return max(0, min(255, int(x)))

def lerp(a, b, t):
    return a + (b - a) * t

# Colors
BG_COLOR = (30, 30, 46)     # #1e1e2e

pixels = bytearray(WIDTH * HEIGHT * 4)

for y in range(HEIGHT):
    for x in range(WIDTH):
        # Base background
        r, g, b = BG_COLOR
        
        idx = (y * WIDTH + x) * 4
        pixels[idx] = int(r)
        pixels[idx+1] = int(g)
        pixels[idx+2] = int(b)
        pixels[idx+3] = 255

png_data = create_png(WIDTH, HEIGHT, bytes(pixels))
with open('background.png', 'wb') as f:
    f.write(png_data)

print("Created background.png")
