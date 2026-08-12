"""One-off script to generate a simple graduation-cap logo PNG for the
app's splash screen (Flutter widget + native android splash), since the
project has no custom branding asset yet. Transparent background so it
composites cleanly over any solid splash background color.
"""

from PIL import Image, ImageDraw

SIZE = 512
PURPLE = (103, 58, 183, 255)  # Colors.deepPurple
WHITE = (255, 255, 255, 255)

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

center = SIZE / 2
radius = SIZE * 0.46
draw.ellipse(
    [center - radius, center - radius, center + radius, center + radius],
    fill=PURPLE,
)

# Graduation cap: diamond-shaped board + square base + tassel.
cx, cy = center, center * 0.92
board_w, board_h = SIZE * 0.42, SIZE * 0.16
diamond = [
    (cx, cy - board_h),
    (cx + board_w, cy),
    (cx, cy + board_h),
    (cx - board_w, cy),
]
draw.polygon(diamond, fill=WHITE)

base_w, base_h = SIZE * 0.22, SIZE * 0.12
base_top = cy + board_h * 0.35
draw.rounded_rectangle(
    [cx - base_w / 2, base_top, cx + base_w / 2, base_top + base_h],
    radius=SIZE * 0.02,
    fill=WHITE,
)

tassel_x = cx + board_w * 0.55
tassel_top_y = cy - board_h * 0.15
draw.line(
    [(tassel_x, tassel_top_y), (tassel_x, tassel_top_y + SIZE * 0.16)],
    fill=WHITE,
    width=int(SIZE * 0.018),
)
knot_r = SIZE * 0.025
draw.ellipse(
    [
        tassel_x - knot_r,
        tassel_top_y + SIZE * 0.16 - knot_r,
        tassel_x + knot_r,
        tassel_top_y + SIZE * 0.16 + knot_r,
    ],
    fill=WHITE,
)

img.save("assets/branding/logo.png")
print("saved assets/branding/logo.png")
