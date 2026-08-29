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
#   mri_version=3.1       - what Essentials v20+ ships (Q6); set
#                           MRI_VERSION=2.7 in the environment (and for
#                           build-deps.sh) to fall back to the scaffold
#   shared_fluid=true     - no dlopen on Vita; link fluidsynth directly
meson setup "$BUILDDIR" "${SETUP_ARGS[@]}" \
    --cross-file platform/vita/vita-cross.txt \
    -Dgfx_backend=gles \
    -Duse_miniffi=false \
    -Denable-https=false \
    -Dmri_version="${MRI_VERSION:-3.1}" \
    -Dshared_fluid=true \
    "$@"

meson compile -C "$BUILDDIR"

echo
echo "VPK: $BUILDDIR/platform/vita/mkxp-z.vpk"
