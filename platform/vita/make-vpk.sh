#!/bin/bash
# Assemble the VPK as a standard zip.
#
# vita-pack-vpk emits a zip with no directory entries; on a VPK carrying
# the whole Ruby stdlib (~1000 files) that shape crashed VitaShell's
# install_thread with a data abort inside SceLibFios2 (observed on
# hardware, psp2core 1788079058). Plain `zip -rX` produces the canonical
# layout every large repacked VPK uses.
#
# Usage: make-vpk.sh <eboot.bin> <param.sfo> <icon0.png> <ruby-stdlib-dir|-> <output.vpk>

set -euo pipefail

EBOOT="$1"; SFO="$2"; ICON="$3"; STDLIB="$4"; OUT="$5"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/sce_sys"
cp "$EBOOT" "$STAGE/eboot.bin"
cp "$SFO" "$STAGE/sce_sys/param.sfo"
cp "$ICON" "$STAGE/sce_sys/icon0.png"
if [ "$STDLIB" != "-" ]; then
    mkdir -p "$STAGE/ruby"
    cp -r "$STDLIB"/. "$STAGE/ruby/"
fi

OUTABS="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
rm -f "$OUTABS"
(cd "$STAGE" && zip -qrX "$OUTABS" .)
echo "VPK: $OUTABS ($(du -h "$OUTABS" | cut -f1))"
