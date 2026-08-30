#!/bin/bash
# Pack the staged Ruby stdlib as ruby-stdlib.zip whose single top-level
# folder is "ruby/" - the user extracts it and copies that folder to
# ux0:data/RPGPlayer/ over USB/FTP (it is not bundled in the VPK; see
# make-vpk.sh for why).
#
# Usage: make-stdlib-zip.sh <staged-stdlib-dir> <output.zip>

set -euo pipefail

STDLIB="$1"; OUT="$2"
OUTABS="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/ruby"
cp -r "$STDLIB"/. "$STAGE/ruby/"

rm -f "$OUTABS"
(cd "$STAGE" && zip -qrX "$OUTABS" ruby)
echo "stdlib: $OUTABS ($(du -h "$OUTABS" | cut -f1))"
