#!/bin/bash
# Build and install into the VitaSDK sysroot every dependency that mkxp-z
# needs on the Vita and that VitaSDK does not already ship (or ships in an
# unusable configuration).
#
# Run inside an environment with VitaSDK installed ($VITASDK set), e.g. the
# vitasdk/vitasdk Docker image. Idempotent: safe to re-run.
#
# What gets built and why:
#   1. SDL2 (rebuilt)  - VitaSDK's stock SDL2 is compiled with every OpenGL
#                        backend disabled, so SDL_GL_CreateContext() can never
#                        succeed. Rebuild with the PIB backend (GLES2 through
#                        Pigs-in-a-Blanket over the PVR_PSP2/Piglet driver).
#   2. SDL2_sound      - not packaged by VitaSDK. v2.0.4 (the SDL2 branch;
#                        master is SDL3-based).
#   3. uchardet        - not packaged by VitaSDK.
#   4. ruby 2.7        - sinister-kid/ruby2.7-vita, the CRuby port using
#                        SceFiber coroutines. Scaffold interpreter per PRD D4
#                        (scaffold on 2.7, ship on 3.1). Requires a native
#                        ruby and autoconf 2.69 on the build host.

set -euo pipefail

: "${VITASDK:?VITASDK must be set}"
PREFIX="$VITASDK/arm-vita-eabi"
TOOLCHAIN="$VITASDK/share/vita.toolchain.cmake"
JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu)"
WORK="${DEPS_WORKDIR:-/tmp/mkxp-z-vita-deps}"
mkdir -p "$WORK"

msg() { printf '\n==> %s\n' "$*"; }

# ---------------------------------------------------------------- SDL2 + PIB
if [ ! -f "$PREFIX/lib/pkgconfig/sdl2.pc" ] || ! grep -q 'pib' "$PREFIX/lib/pkgconfig/sdl2.pc"; then
    msg "SDL2 2.32.8 with SDL_VIDEO_VITA_PIB (GLES2)"
    cd "$WORK"
    [ -d SDL ] || git clone -q --depth 1 --branch release-2.32.8 https://github.com/libsdl-org/SDL.git
    cd SDL
    cmake -B build-vita \
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DSDL_VIDEO_VITA_PIB=ON
    cmake --build build-vita -j"$JOBS"
    cmake --install build-vita
else
    msg "SDL2 with PIB already installed, skipping"
fi

# --------------------------------------------------------------- SDL2_sound
if [ ! -f "$PREFIX/lib/libSDL2_sound.a" ]; then
    msg "SDL2_sound v2.0.4"
    cd "$WORK"
    [ -d SDL_sound ] || git clone -q --depth 1 --branch v2.0.4 https://github.com/icculus/SDL_sound.git
    cd SDL_sound
    cmake -B build-vita \
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DSDLSOUND_BUILD_SHARED=OFF \
        -DSDLSOUND_BUILD_TEST=OFF
    cmake --build build-vita -j"$JOBS"
    cmake --install build-vita
else
    msg "SDL2_sound already installed, skipping"
fi

# ----------------------------------------------------------------- uchardet
if [ ! -f "$PREFIX/lib/pkgconfig/uchardet.pc" ]; then
    msg "uchardet"
    cd "$WORK"
    [ -d uchardet ] || git clone -q --depth 1 https://gitlab.freedesktop.org/uchardet/uchardet.git
    cd uchardet
    cmake -B build-vita \
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_BINARY=OFF
    cmake --build build-vita -j"$JOBS"
    cmake --install build-vita
else
    msg "uchardet already installed, skipping"
fi

# ----------------------------------------------------------------- ruby 2.7
if ! ls "$PREFIX"/lib/pkgconfig/ruby-2.7*.pc >/dev/null 2>&1; then
    msg "ruby 2.7 (sinister-kid/ruby2.7-vita, SceFiber coroutines)"
    command -v ruby >/dev/null || { echo "A native ruby is required (BASERUBY)"; exit 1; }
    # ruby 2.7's configure.ac needs autoconf 2.69; newer autoconf fails.
    if autoconf --version | head -1 | grep -qv '2\.69'; then
        if [ -x /opt/ac269/bin/autoconf ]; then
            export PATH="/opt/ac269/bin:$PATH"
        else
            echo "autoconf 2.69 required (found $(autoconf --version | head -1))"
            echo "Install to /opt/ac269 or put autoconf 2.69 first in PATH."
            exit 1
        fi
    fi
    cd "$WORK"
    [ -d ruby2.7-vita ] || git clone -q --depth 1 https://github.com/sinister-kid/ruby2.7-vita.git
    cd ruby2.7-vita
    autoreconf -i
    mkdir -p build && cd build
    ../configure-vita
    make -j"$JOBS"
    make install
else
    msg "ruby 2.7 already installed, skipping"
fi

msg "All Vita dependencies installed into $PREFIX"
