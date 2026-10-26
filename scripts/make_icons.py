#!/usr/bin/env python3
"""Builds every AppIcon size, and the splash logo, from the brand logo (Design/iSudoku-logo.jpeg).

The icon uses only the emblem (the "i" and the grid), never the wordmark, which is
unreadable at 16-60 px. The emblem is cut out above the wordmark, centred on a square
canvas filled with the logo's own background colour and blended in with a feathered
mask, so no seam shows. Output is opaque RGB: the App Store rejects an alpha channel.

Usage: python3 scripts/make_icons.py   (requires Pillow)
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / "Design" / "iSudoku-logo.jpeg"
ICONSET = ROOT / "iSudoku" / "Assets.xcassets" / "AppIcon.appiconset"
BRAND = ROOT / "iSudoku" / "Assets.xcassets" / "BrandIcon.imageset" / "brand-icon.png"  # splash logo

# Emblem geometry measured on the 2752x1536 logo (bright/colourful pixels above the wordmark).
EMBLEM_CENTER = (1372, 640)
WORDMARK_TOP = 1046          # first row of the "iSudoku" lettering
CANVAS = 900                 # square side in logo pixels: emblem (~651 px) + margin for the iOS mask
FEATHER = 40


def build_master() -> Image.Image:
    logo = Image.open(LOGO).convert("RGB")
    assert logo.size == (2752, 1536), f"unexpected logo size {logo.size}; re-measure the emblem"
    half = CANVAS // 2
    cx, cy = EMBLEM_CENTER
    box = (cx - half, cy - half, cx + half, min(cy + half, WORDMARK_TOP - FEATHER))
    crop = logo.crop(box)

    # Background: average of the crop's border, the logo's own navy.
    border = [crop.getpixel((x, y)) for x in range(0, crop.width, 8) for y in (2, crop.height - 3)]
    background = tuple(sum(c[i] for c in border) // len(border) for i in range(3))
    canvas = Image.new("RGB", (CANVAS, CANVAS), background)

    mask = Image.new("L", crop.size, 0)
    ImageDraw.Draw(mask).rectangle((FEATHER, FEATHER, crop.width - FEATHER, crop.height - FEATHER), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(FEATHER / 2))
    canvas.paste(crop, (0, 0), mask)
    return canvas.resize((1024, 1024), Image.LANCZOS)


def main() -> None:
    master = build_master()
    contents = json.loads((ICONSET / "Contents.json").read_text())
    sizes = {}
    for image in contents["images"]:
        points = float(image["size"].split("x")[0])
        sizes[image["filename"]] = round(points * int(image["scale"].rstrip("x")))
    for filename, pixels in sorted(sizes.items(), key=lambda item: item[1]):
        icon = master if pixels == 1024 else master.resize((pixels, pixels), Image.LANCZOS)
        icon.save(ICONSET / filename, optimize=True)
        print(f"{filename}: {pixels}x{pixels}")
    master.resize((512, 512), Image.LANCZOS).save(BRAND, optimize=True)
    print(f"{BRAND.name}: 512x512")


if __name__ == "__main__":
    main()
