#!/bin/sh
# Export logo/logo.svg to man/figures/logo.png and the pkgdown favicons
# (pkgdown/favicon/), all with transparent background.
# Run from the repository root: logo/export.sh
# Needs rsvg-convert (Debian/Ubuntu package librsvg2-bin), ImageMagick
# (convert) and python3.
set -e

# hexagon sticker, width : height = 400 : 462
mkdir -p man/figures
rsvg-convert -w 400 -h 462 -o man/figures/logo.png logo/logo.svg

# square favicons, hexagon centered and as high as the canvas
mkdir -p pkgdown/favicon
square() {
    tmp="pkgdown/favicon/.icon-$1.png"
    rsvg-convert -h "$1" -o "$tmp" logo/logo.svg
    convert "$tmp" -background none -gravity center -extent "${1}x${1}" \
        -strip -define png:exclude-chunk=time "$2"
    rm -f "$tmp"
}
for n in 16 32 48 60 76 120 152 180; do
    square "$n" "pkgdown/favicon/icon-$n.png"
done
for n in 60 76 120 152 180; do
    mv "pkgdown/favicon/icon-$n.png" "pkgdown/favicon/apple-touch-icon-${n}x${n}.png"
done
cp pkgdown/favicon/apple-touch-icon-180x180.png pkgdown/favicon/apple-touch-icon.png
for n in 16 32; do
    mv "pkgdown/favicon/icon-$n.png" "pkgdown/favicon/favicon-${n}x${n}.png"
done

# favicon.ico with 16, 32 and 48 px PNG images
python3 -I - <<'PY'
import struct
sizes = [16, 32, 48]
imgs = []
for n in sizes:
    path = f"pkgdown/favicon/favicon-{n}x{n}.png" if n < 48 else "pkgdown/favicon/icon-48.png"
    imgs.append(open(path, "rb").read())
out = struct.pack("<HHH", 0, 1, len(sizes))
offset = 6 + 16 * len(sizes)
for n, data in zip(sizes, imgs):
    out += struct.pack("<BBBBHHII", n, n, 0, 0, 1, 32, len(data), offset)
    offset += len(data)
out += b"".join(imgs)
open("pkgdown/favicon/favicon.ico", "wb").write(out)
PY
rm -f pkgdown/favicon/icon-48.png
