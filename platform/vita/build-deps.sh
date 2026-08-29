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
        -DVIDEO_VITA_PIB=ON
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

# ------------------------------------------------------- fluidsynth header
# VitaSDK ships fluidlite, whose pkg-config file is named fluidsynth but
# whose headers live only under fluidsynth/. mkxp includes <fluidsynth.h>
# like the real fluidsynth installs it; provide the classic entry point.
if [ ! -f "$PREFIX/include/fluidsynth.h" ]; then
    msg "fluidsynth.h compatibility header (fluidlite)"
    printf '#include "fluidlite.h"\n' > "$PREFIX/include/fluidsynth.h"
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
    # A cached configure run from an earlier script version would abort
    # on changed CFLAGS; start clean.
    rm -f vita.cache
    # Mirrors upstream's configure-vita, with three additions to the CFLAGS
    # needed by modern GCC (>= 14/15):
    #   -std=gnu17: ruby 2.7 uses K&R declarations ("char *strerror();")
    #     whose meaning changed in C23, GCC 15's default
    #   -Wno-incompatible-pointer-types / -Wno-int-conversion: promoted to
    #     errors in GCC 14, breaks rb_f_notimplement prototype tricks
    RUBY_CFLAGS="-O3 -std=gnu17 -DNO_DEBUG -DMKXPZ_PATCH -Wno-incompatible-pointer-types -Wno-int-conversion"
    export rb_cv_arflags=rcu
    ../configure -C --host=arm-vita-eabi \
        --prefix="$PREFIX" \
        --cache-file=vita.cache \
        --enable-pthread=yes \
        --disable-rubygems \
        --disable-fortify-source \
        --disable-install-doc \
        CC=arm-vita-eabi-gcc \
        CXX=arm-vita-eabi-g++ \
        CFLAGS="$RUBY_CFLAGS"
    make -j"$JOBS"
    # The vita port aggregates core + enc + ext objects (including
    # ext/extinit.o, which defines Init_ext) into libruby.a through the
    # rebuild-static-with-exts post-build hook, and that hook also
    # appends the ext link flags to ruby-2.7.pc. Depending on make
    # scheduling it does not always run as part of "all"; invoke it
    # explicitly and verify the result.
    make rebuild-static-with-exts
    arm-vita-eabi-nm libruby.a | grep -q "T Init_ext" || {
        echo "libruby.a is missing Init_ext (extensions not aggregated)"
        exit 1
    }
    # "make install" runs tool/rbinstall.rb under the host's (newer) ruby,
    # which cannot execute ruby 2.7's installer. Install the three things
    # the engine actually links against by hand: the static library, the
    # pkg-config file, and the headers (source + generated arch config.h).
    cp libruby.a "$PREFIX/lib/libruby.a"
    # VitaSDK's GCC expands -pthread into "--whole-archive -lpthread
    # --no-whole-archive"; a bare -lpthread from this .pc alongside that
    # expansion makes ld load libpthread.a twice (multiple definition of
    # every pte_os* symbol). Normalize to the -pthread flag, which the
    # spec collapses however often it appears.
    sed 's/-lpthread/-pthread/' ruby-2.7.pc > "$PREFIX/lib/pkgconfig/ruby-2.7.pc"
    mkdir -p "$PREFIX/include/ruby-2.7.0"
    cp -r ../include/* "$PREFIX/include/ruby-2.7.0/"
    cp -r .ext/include/arm-vita "$PREFIX/include/ruby-2.7.0/"
else
    msg "ruby 2.7 already installed, skipping"
fi

# --------------------------------------------------------- sysroot fixups
# VitaSDK's GCC expands -pthread into "--whole-archive -lpthread
# --no-whole-archive". Any bare -lpthread from a .pc file (libwebp,
# openal, ruby, ...) beside that expansion makes ld load libpthread.a a
# second time and fail with "multiple definition" of every pte_os*
# symbol. Normalizing every .pc to the -pthread flag is safe: the GCC
# driver collapses repeated flags and the spec expands it exactly once.
msg "Normalizing -lpthread to -pthread in sysroot .pc files"
sed -i 's/-lpthread/-pthread/g' "$PREFIX"/lib/pkgconfig/*.pc

msg "All Vita dependencies installed into $PREFIX"
