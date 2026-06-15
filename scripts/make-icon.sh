#!/usr/bin/env bash
#
# Generate Resources/AppIcon.icns from a source PNG logo.
#
# Crops the artwork out of its background padding, rounds the corners with
# transparency (macOS does not auto-mask app icons), and builds a multi-size
# .icns. Requires Python 3 with Pillow and macOS `iconutil`.
#
# Usage:
#   ./scripts/make-icon.sh <source-image.png>
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:?Usage: make-icon.sh <source-image.png>}"
RES="$ROOT/Resources"
ICONSET="$(mktemp -d)/AppIcon.iconset"
MASTER="$RES/AppIcon-master.png"

mkdir -p "$RES" "$ICONSET"

echo "==> Cropping + rounding master icon…"
python3 - "$SRC" "$MASTER" <<'PY'
import sys
from PIL import Image, ImageDraw

src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
w, h = im.size
px = im.load()

def nonblack(x, y):
    r, g, b = px[x, y]
    return (r + g + b) > 60

cx, cy = w // 2, h // 2
left   = next(x for x in range(w)        if nonblack(x, cy))
right  = next(x for x in range(w - 1, -1, -1) if nonblack(x, cy))
top    = next(y for y in range(h)        if nonblack(cx, y))
bottom = next(y for y in range(h - 1, -1, -1) if nonblack(cx, y))

crop = im.crop((left, top, right + 1, bottom + 1)).convert("RGBA")
side = max(crop.size)
canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
canvas.paste(crop, ((side - crop.width) // 2, (side - crop.height) // 2))

# Rounded-rect alpha mask (~22% radius, Apple-ish squircle approximation).
mask = Image.new("L", (side, side), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, side - 1, side - 1],
                                       radius=int(side * 0.22), fill=255)
canvas.putalpha(mask)

canvas = canvas.resize((1024, 1024), Image.LANCZOS)
canvas.save(out)
print("master:", canvas.size)
PY

echo "==> Generating iconset sizes…"
python3 - "$MASTER" "$ICONSET" <<'PY'
import sys
from PIL import Image

master, iconset = sys.argv[1], sys.argv[2]
im = Image.open(master).convert("RGBA")
specs = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for size, name in specs:
    im.resize((size, size), Image.LANCZOS).save(f"{iconset}/{name}")
print("iconset written")
PY

echo "==> Building AppIcon.icns…"
iconutil -c icns "$ICONSET" -o "$RES/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"
echo "==> Done: $RES/AppIcon.icns"
