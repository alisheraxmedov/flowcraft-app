#!/usr/bin/env python3
"""Regenerate FlowCraft's desktop + iOS app icons from the canonical artwork.

Usage (from the repo root):

    python3 tool/generate_icons.py

Requires Python 3 and Pillow (`pip install pillow`); nothing else.

Source of truth is `assets/branding/flowcraft-icon-1024.png` — a 1024x1024
RGBA PNG of the monogram on its cream background. That folder is deliberately
NOT listed under `flutter.assets` in pubspec.yaml: it is build-time input only
and must not be bundled into the app binary. Every output is rendered from a
centred crop of that file (see CROP_FRACTION below) so the monogram fills
~70% of the tile instead of the ~55% it occupies in the source.

Outputs (all overwritten in place, filenames match the existing
Contents.json / CMake / packaging references so nothing else needs editing):

  macOS    macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{16..1024}.png
           Apple's Big Sur+ template: 1024 canvas, 824x824 rounded square
           (100px margin, 185px corner radius) with a soft drop shadow.
           Every size is a LANCZOS downscale of the rendered 1024 master.
  Windows  windows/runner/resources/app_icon.ico
           Frames 16/24/32/48/64/128/256. Rounded square, radius 18% of size,
           no margin, no shadow — Windows icons fill the frame.
  Linux    linux/packaging/icons/flowcraft-{128,256,512}.png
           Same flat rounded-square style as Windows; build_deb.sh installs
           them into /usr/share/icons/hicolor/<size>/apps/flowcraft.png.
  iOS      ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png
           Plain square, opaque RGB (no alpha), no rounded corners — iOS
           applies its own mask.

Android (android/app/src/main/res/mipmap-*) and web (web/favicon.ico,
web/icons/*) are NOT produced here: they are the adaptive-icon / PWA sets
exported by IconKitchen from the same artwork and are checked in as-is.
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter
except ImportError:  # pragma: no cover - guidance for a fresh machine
    sys.exit("Pillow is required: pip install pillow")

REPO = Path(__file__).resolve().parent.parent
SOURCE = REPO / "assets" / "branding" / "flowcraft-icon-1024.png"

MACOS_DIR = REPO / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
WINDOWS_ICO = REPO / "windows" / "runner" / "resources" / "app_icon.ico"
LINUX_DIR = REPO / "linux" / "packaging" / "icons"
IOS_DIR = REPO / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

# Supersampling factor for every anti-aliased mask: draw at SS x, downsample
# with LANCZOS. 4x gives clean sub-pixel corner edges even at 16px.
SS = 4

# --- Centre crop applied to the source before it fills any tile -------------
# The source artwork carries a large built-in cream margin: the monogram's
# bounding box is only ~558x579 px of the 1024 canvas (~55% of the width).
# Used as-is, a 16/32 px icon degrades into an unreadable cream square. So
# every platform renders from a centred square crop of CROP_FRACTION x 1024
# px (= 579 / 0.70 ~= 827 px), which puts the monogram's larger extent at
# ~70% of the tile width while keeping the cream background visible around
# it. The crop is centred on the monogram's measured centre (not the image
# centre, which is ~25 px off) so the margins are equal on all sides.
# `assets/branding/flowcraft-icon-1024.png` itself is never modified.
CROP_FRACTION = 0.81
# Pixels that differ from the cream background by more than this (0-255)
# count as monogram when measuring its centre.
MONOGRAM_THRESHOLD = 60

# --- macOS (Apple Big Sur+ app icon template, in 1024-canvas units) ----------
MAC_CANVAS = 1024
MAC_BODY = 824            # rounded-square side -> 100px margin each side
MAC_RADIUS = 185          # corner radius of the body
MAC_SHADOW_OFFSET = (0, 10)
MAC_SHADOW_BLUR = 10      # Gaussian sigma; == a 20px blur in Sketch/Figma terms
MAC_SHADOW_ALPHA = 0.30
MAC_SIZES = (16, 32, 64, 128, 256, 512, 1024)

# --- Windows / Linux flat tile ------------------------------------------------
TILE_RADIUS_RATIO = 0.18
WINDOWS_SIZES = (16, 24, 32, 48, 64, 128, 256)
LINUX_SIZES = (128, 256, 512)

# --- iOS: (filename, pixel size) — mirrors the checked-in Contents.json -------
IOS_ICONS = (
    ("Icon-App-20x20@1x.png", 20),
    ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-29x29@2x.png", 58),
    ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@1x.png", 40),
    ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120),
    ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180),
    ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152),
    ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
)


def rounded_mask(size: int, radius: int) -> Image.Image:
    """Anti-aliased L-mode rounded-square mask, drawn at SS x then downsampled."""
    big = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (0, 0, size * SS - 1, size * SS - 1), radius=radius * SS, fill=255
    )
    return big.resize((size, size), Image.Resampling.LANCZOS)


def monogram_bbox(src: Image.Image) -> tuple[int, int, int, int]:
    """Bounding box of everything that is not the cream background."""
    rgb = src.convert("RGB")
    w, h = rgb.size
    corners = [rgb.getpixel(p) for p in ((2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3))]
    bg = tuple(round(sum(c[i] for c in corners) / 4) for i in range(3))
    diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, bg)).convert("L")
    bbox = diff.point(lambda v: 255 if v > MONOGRAM_THRESHOLD else 0).getbbox()
    return bbox or (0, 0, w, h)


def crop_to_monogram(src: Image.Image) -> Image.Image:
    """Square crop of CROP_FRACTION x source side, centred on the monogram."""
    w, h = src.size
    side = round(min(w, h) * CROP_FRACTION)
    x0, y0, x1, y1 = monogram_bbox(src)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    left = min(max(round(cx - side / 2), 0), w - side)
    top = min(max(round(cy - side / 2), 0), h - side)
    cropped = src.crop((left, top, left + side, top + side))
    extent = max(x1 - x0, y1 - y0)
    print(
        f"crop: {side}x{side} at ({left},{top}); monogram bbox "
        f"{x1 - x0}x{y1 - y0} -> {extent / side:.1%} of tile width"
    )
    return cropped


def cover(src: Image.Image, size: int) -> Image.Image:
    """Scale `src` to cover a size x size square, centre-cropping any excess."""
    w, h = src.size
    scale = max(size / w, size / h)
    scaled = src.resize(
        (max(size, round(w * scale)), max(size, round(h * scale))),
        Image.Resampling.LANCZOS,
    )
    left = (scaled.width - size) // 2
    top = (scaled.height - size) // 2
    return scaled.crop((left, top, left + size, top + size))


def flat_tile(src: Image.Image, size: int) -> Image.Image:
    """Rounded square filling the whole frame: Windows + Linux style."""
    tile = cover(src, size).convert("RGBA")
    tile.putalpha(rounded_mask(size, round(size * TILE_RADIUS_RATIO)))
    return tile


def macos_master(src: Image.Image) -> Image.Image:
    """1024x1024 transparent canvas with the shadowed rounded-square body."""
    margin = (MAC_CANVAS - MAC_BODY) // 2
    body_mask = rounded_mask(MAC_BODY, MAC_RADIUS)

    # Shadow: the body silhouette, black at 30%, offset and blurred.
    shadow_alpha = Image.new("L", (MAC_CANVAS, MAC_CANVAS), 0)
    shadow_alpha.paste(
        body_mask.point(lambda v: round(v * MAC_SHADOW_ALPHA)),
        (margin + MAC_SHADOW_OFFSET[0], margin + MAC_SHADOW_OFFSET[1]),
    )
    shadow_alpha = shadow_alpha.filter(ImageFilter.GaussianBlur(MAC_SHADOW_BLUR))
    canvas = Image.new("RGBA", (MAC_CANVAS, MAC_CANVAS), (0, 0, 0, 0))
    canvas.putalpha(shadow_alpha)

    # Body: artwork scaled to cover the rounded square.
    body = cover(src, MAC_BODY).convert("RGBA")
    body.putalpha(body_mask)
    canvas.alpha_composite(body, (margin, margin))
    return canvas


def save_png(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, format="PNG", optimize=True)
    print(f"  wrote {path.relative_to(REPO)}  {im.size[0]}x{im.size[1]} {im.mode}")


def generate_macos(src: Image.Image) -> None:
    print("macOS")
    master = macos_master(src)
    for size in MAC_SIZES:
        im = master if size == MAC_CANVAS else master.resize(
            (size, size), Image.Resampling.LANCZOS
        )
        save_png(im, MACOS_DIR / f"app_icon_{size}.png")


def generate_windows(src: Image.Image) -> None:
    print("Windows")
    frames = [flat_tile(src, s) for s in sorted(WINDOWS_SIZES, reverse=True)]
    WINDOWS_ICO.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        WINDOWS_ICO,
        format="ICO",
        sizes=[(s, s) for s in WINDOWS_SIZES],
        append_images=frames[1:],
    )
    print(f"  wrote {WINDOWS_ICO.relative_to(REPO)}  frames={sorted(WINDOWS_SIZES)}")


def generate_linux(src: Image.Image) -> None:
    print("Linux")
    for size in LINUX_SIZES:
        save_png(flat_tile(src, size), LINUX_DIR / f"flowcraft-{size}.png")


def generate_ios(src: Image.Image) -> None:
    print("iOS")
    opaque = cover(src, 1024).convert("RGB")
    for name, size in IOS_ICONS:
        im = opaque if size == 1024 else opaque.resize(
            (size, size), Image.Resampling.LANCZOS
        )
        save_png(im, IOS_DIR / name)


def main() -> int:
    if not SOURCE.is_file():
        print(f"error: source artwork not found: {SOURCE}", file=sys.stderr)
        return 1
    src = Image.open(SOURCE).convert("RGBA")
    if src.size != (1024, 1024):
        print(f"error: expected a 1024x1024 source, got {src.size}", file=sys.stderr)
        return 1
    print(f"source: {SOURCE.relative_to(REPO)}")
    src = crop_to_monogram(src)
    generate_macos(src)
    generate_windows(src)
    generate_linux(src)
    generate_ios(src)
    return 0


if __name__ == "__main__":
    sys.exit(main())
