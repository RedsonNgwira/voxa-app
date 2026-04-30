#!/usr/bin/env python3
"""Generate Voxa app icon — 1024x1024 PNG"""
from PIL import Image, ImageDraw, ImageFont
import math, os

SIZE = 1024
BG = (14, 11, 8)          # #0E0B08
EMBER = (232, 98, 42)      # #E8622A
EMBER_DIM = (80, 35, 15)   # dimmed ember for waveform sides

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Rounded rect background
RADIUS = 180
draw.rounded_rectangle([0, 0, SIZE, SIZE], radius=RADIUS, fill=BG + (255,))

# Draw V using two thick polygons (beveled strokes)
STROKE = 56
# Left arm of V: top-left to bottom-center
lx0, ly0 = 190, 160
lx1, ly1 = 512, 760
# Right arm of V: top-right to bottom-center
rx0, ry0 = 834, 160
rx1, ry1 = 512, 760

def thick_line(draw, x0, y0, x1, y1, width, color):
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length
    hw = width / 2
    poly = [
        (x0 + nx * hw, y0 + ny * hw),
        (x0 - nx * hw, y0 - ny * hw),
        (x1 - nx * hw, y1 - ny * hw),
        (x1 + nx * hw, y1 + ny * hw),
    ]
    draw.polygon(poly, fill=color + (255,))

thick_line(draw, lx0, ly0, lx1, ly1, STROKE, EMBER)
thick_line(draw, rx0, ry0, rx1, ry1, STROKE, EMBER)

# Round the bottom tip of V
draw.ellipse([lx1 - STROKE//2, ly1 - STROKE//2, lx1 + STROKE//2, ly1 + STROKE//2], fill=EMBER + (255,))

# Waveform bars beneath V
bar_heights = [18, 32, 52, 76, 96, 76, 52, 32, 18]
n = len(bar_heights)
bar_w = 26
spacing = 44
total_w = n * spacing - (spacing - bar_w)
start_x = (SIZE - total_w) // 2
bar_y_bottom = 900

for i, h in enumerate(bar_heights):
    x = start_x + i * spacing
    color = EMBER if i == n // 2 else EMBER_DIM
    # Rounded bar
    draw.rounded_rectangle(
        [x, bar_y_bottom - h, x + bar_w, bar_y_bottom],
        radius=6, fill=color + (255,)
    )

# Save
out = "assets/icon/app_icon.png"
os.makedirs(os.path.dirname(out), exist_ok=True)
img.save(out, "PNG")
print(f"Icon saved: {out} ({SIZE}x{SIZE})")
