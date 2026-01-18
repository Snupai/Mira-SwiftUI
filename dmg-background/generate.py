#!/usr/bin/env python3
"""Generate DMG background image with arrow."""
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
    
    # PNG signature
    signature = b'\x89PNG\r\n\x1a\n'
    
    # IHDR chunk
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    ihdr = png_chunk(b'IHDR', ihdr_data)
    
    # IDAT chunk (image data)
    raw_data = b''
    for y in range(height):
        raw_data += b'\x00'  # Filter type: None
        raw_data += pixels[y * width * 4:(y + 1) * width * 4]
    
    compressed = zlib.compress(raw_data, 9)
    idat = png_chunk(b'IDAT', compressed)
    
    # IEND chunk
    iend = png_chunk(b'IEND', b'')
    
    return signature + ihdr + idat + iend

def lerp(a, b, t):
    return int(a + (b - a) * t)

def blend(bg, fg, alpha):
    return lerp(bg, fg, alpha / 255)

# Catppuccin Mocha colors
BG_TOP = (30, 30, 46)      # #1e1e2e
BG_BOT = (24, 24, 37)      # #181825
GRID = (49, 50, 68)        # #313244
ARROW1 = (203, 166, 247)   # #cba6f7 (mauve)
ARROW2 = (137, 180, 250)   # #89b4fa (blue)
TEXT = (205, 214, 244)     # #cdd6f4
SUBTEXT = (166, 173, 200)  # #a6adc8
OVERLAY = (108, 112, 134)  # #6c7086

# Create pixel buffer
pixels = bytearray(WIDTH * HEIGHT * 4)

for y in range(HEIGHT):
    t = y / HEIGHT
    bg_r = lerp(BG_TOP[0], BG_BOT[0], t)
    bg_g = lerp(BG_TOP[1], BG_BOT[1], t)
    bg_b = lerp(BG_TOP[2], BG_BOT[2], t)
    
    for x in range(WIDTH):
        r, g, b, a = bg_r, bg_g, bg_b, 255
        
        # Subtle grid pattern
        if x % 40 == 0 or y % 40 == 0:
            r = lerp(r, GRID[0], 0.15)
            g = lerp(g, GRID[1], 0.15)
            b = lerp(b, GRID[2], 0.15)
        
        # Arrow (center of image, pointing left)
        arrow_y = 170
        arrow_x1 = 250  # Start (right side, near app)
        arrow_x2 = 410  # End (left side, near Applications)
        
        # Arrow line (horizontal)
        if abs(y - arrow_y) <= 2 and arrow_x1 <= x <= arrow_x2:
            t = (x - arrow_x1) / (arrow_x2 - arrow_x1)
            ar = lerp(ARROW2[0], ARROW1[0], t)
            ag = lerp(ARROW2[1], ARROW1[1], t)
            ab = lerp(ARROW2[2], ARROW1[2], t)
            r, g, b = ar, ag, ab
        
        # Arrow head (triangle pointing left)
        head_x = arrow_x1
        head_size = 15
        if arrow_x1 - head_size <= x <= arrow_x1:
            dy = abs(y - arrow_y)
            dx = arrow_x1 - x
            if dy <= dx:
                r, g, b = ARROW2
        
        idx = (y * WIDTH + x) * 4
        pixels[idx] = r
        pixels[idx + 1] = g
        pixels[idx + 2] = b
        pixels[idx + 3] = a

# Save PNG
png_data = create_png(WIDTH, HEIGHT, bytes(pixels))
with open('background.png', 'wb') as f:
    f.write(png_data)

print("Created background.png")
