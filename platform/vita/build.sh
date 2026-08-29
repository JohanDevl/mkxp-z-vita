#!/bin/bash
# Configure and build mkxp-z for the PlayStation Vita, producing a VPK.
#
# Prerequisites: VitaSDK ($VITASDK set) with the extra dependencies from
# platform/vita/build-deps.sh installed into its sysroot.
#
# Usage: platform/vita/build.sh [builddir]   (default: build-vita)

set -euo pipefail

: "${VITASDK:?VITASDK must be set}"
export PATH="$VITASDK/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILDDIR="${1:-build-vita}"
[ $# -gt 0 ] && shift

cd "$ROOT"

SETUP_ARGS=()
[ -d "$BUILDDIR" ] && SETUP_ARGS+=(--reconfigure)

# Option rationale (PRD references in parentheses):
#   gfx_backend=gles      - the Vita is a GLES2 platform (Q8)
#   use_miniffi=false     - Essentials v19+ uses no Win32API (Q9/D7)
#   enable-https=false    - keeps binaries cleanly GPLv2+ (PRD 10.3)
#   mri_version=2.7       - scaffold interpreter (D4); 3.1 is the ship target
#   shared_fluid=true     - no dlopen on Vita; link fluidsynth directly
meson setup "$BUILDDIR" "${SETUP_ARGS[@]}" \
    --cross-file platform/vita/vita-cross.txt \
    -Dgfx_backend=gles \
    -Duse_miniffi=false \
    -Denable-https=false \
    -Dmri_version=2.7 \
    -Dshared_fluid=true \
    "$@"

meson compile -C "$BUILDDIR"

echo
echo "VPK: $BUILDDIR/platform/vita/mkxp-z.vpk"
