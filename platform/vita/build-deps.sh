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
#   4. ruby            - MRI_VERSION=3.1 (default): JohanDevl/ruby3.1-vita,
#                        the mkxp-z ruby 3.1.3 fork with the Vita platform
#                        layer (SceFiber coroutines) - what Essentials v20+
#                        games need (PRD Q6/M4b).
#                        MRI_VERSION=2.7: sinister-kid/ruby2.7-vita, the
#                        original scaffold (PRD D4 fallback); needs
#                        autoconf 2.69.
#                        Both need a native ruby (BASERUBY) on the host.

set -euo pipefail

: "${VITASDK:?VITASDK must be set}"
MRI_VERSION="${MRI_VERSION:-3.1}"
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
    [ -d uchardet ] || git clone -q --depth 1 --branch v0.0.8 https://gitlab.freedesktop.org/uchardet/uchardet.git
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

# Append the ext and enc objects into libruby.a when Init_ext is absent
# ("ar r" is idempotent). The in-tree aggregation hooks are unreliable
# outside incremental local builds.
#
# NB: the check must not be "nm | grep -q" — under pipefail, grep -q
# exiting early SIGPIPEs nm on the large symbol list and the pipeline
# reads as a failure even on a match. grep -c consumes the whole stream.
init_ext_count() {
    arm-vita-eabi-nm "$1" 2>/dev/null | grep -c "T Init_ext" || true
}
aggregate_libruby() {
    local archive="$1"
    if [ "$(init_ext_count "$archive")" = "0" ]; then
        # shellcheck disable=SC2046
        arm-vita-eabi-ar r "$archive" \
            $(find ext -name '*.o') \
            enc/encinit.o enc/encdb.o enc/trans/transdb.o
        arm-vita-eabi-ranlib "$archive"
    fi
    if [ "$(init_ext_count "$archive")" = "0" ]; then
        echo "$archive is missing Init_ext (extensions not aggregated)"
        exit 1
    fi
}

# ----------------------------------------------------------------- ruby 3.1
if [ "$MRI_VERSION" = "3.1" ] && ! ls "$PREFIX"/lib/pkgconfig/ruby-3.1*.pc >/dev/null 2>&1; then
    msg "ruby 3.1 (JohanDevl/ruby3.1-vita: mkxp-z ruby + Vita layer, SceFiber)"
    command -v ruby >/dev/null || { echo "A native ruby is required (BASERUBY)"; exit 1; }
    cd "$WORK"
    [ -d ruby3.1-vita ] || git clone -q --depth 1 --single-branch --branch vita \
        https://github.com/JohanDevl/ruby3.1-vita.git
    cd ruby3.1-vita
    [ -f configure ] || autoreconf -i
    mkdir -p build && cd build
    rm -f vita.cache
    ../configure-vita
    make -j"$JOBS"
    make libruby-static.a
    aggregate_libruby libruby-static.a
    # "make install" runs tool/rbinstall.rb under the host ruby; install
    # the pieces the engine needs by hand instead (library, pkg-config
    # file with pthread normalized, headers, and the stdlib staged for
    # VPK packaging).
    cp libruby-static.a "$PREFIX/lib/libruby-static.a"
    # The generated pc needs three repairs: make-syntax LIBRUBYARG left
    # unexpanded by config.status; --compress-debug-sections, which
    # VitaSDK's ld rejects; and the usual -lpthread normalization.
    ./config.status --file=ruby-3.1.pc:../template/ruby.pc.in >/dev/null
    sed -e 's|$(LIBRUBYARG_STATIC)|-lruby-static|g' \
        -e 's|-Wl,--compress-debug-sections=zlib||g' \
        -e 's/-lpthread/-pthread/' \
        ruby-3.1.pc > "$PREFIX/lib/pkgconfig/ruby-3.1.pc"
    mkdir -p "$PREFIX/include/ruby-3.1.0"
    cp -r ../include/* "$PREFIX/include/ruby-3.1.0/"
    cp -r .ext/include/*/ "$PREFIX/include/ruby-3.1.0/"
    # Stage the pure-ruby stdlib (plus the generated rbconfig.rb) so the
    # VPK packaging can ship it at app0:ruby.
    RUBY_STDLIB="$PREFIX/mkxpz-ruby-stdlib"
    rm -rf "$RUBY_STDLIB"
    mkdir -p "$RUBY_STDLIB"
    cp -r ../lib/* "$RUBY_STDLIB/"
    cp rbconfig.rb "$RUBY_STDLIB/"
elif [ "$MRI_VERSION" = "3.1" ]; then
    msg "ruby 3.1 already installed, skipping"
fi

# ----------------------------------------------------------------- ruby 2.7
if [ "$MRI_VERSION" = "2.7" ] && ! ls "$PREFIX"/lib/pkgconfig/ruby-2.7*.pc >/dev/null 2>&1; then
    msg "ruby 2.7 (sinister-kid/ruby2.7-vita, SceFiber coroutines)"
    command -v ruby >/dev/null || { echo "A native ruby is required (BASERUBY)"; exit 1; }
    # ruby 2.7's configure.ac needs autoconf 2.69; newer autoconf fails.
    if ! command -v autoconf >/dev/null || ! autoconf --version | head -1 | grep -q '2\.69'; then
        if [ -x /opt/ac269/bin/autoconf ]; then
            export PATH="/opt/ac269/bin:$PATH"
        else
            echo "autoconf 2.69 required (found: $(autoconf --version 2>/dev/null | head -1 || echo none))"
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
    # This tree's rebuild-static-with-exts hook also refreshes the pc's
    # Libs.private with the ext libs; run it, then aggregate explicitly.
    make rebuild-static-with-exts
    aggregate_libruby libruby.a
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
elif [ "$MRI_VERSION" = "2.7" ]; then
    msg "ruby 2.7 already installed, skipping"
fi

# --------------------------------------------------------- sysroot fixups
# VitaSDK's GCC expands -pthread into "--whole-archive -lpthread
# --no-whole-archive". Any bare -lpthread from a .pc file (libwebp,
# openal, ruby, ...) beside that expansion makes ld load libpthread.a a
# second time and fail with "multiple definition" of every pte_os*
# symbol. Normalizing every .pc to the -pthread flag is safe: the GCC
# driver collapses repeated flags and the spec expands it exactly once.
#
# NOTE: this rewrites pkg-config files across the whole sysroot. That is
# what you want in the throwaway Docker/CI container this script is
# written for; on a personal VitaSDK install, set VITA_PC_PTHREAD_FIXUP=0
# to skip it (the engine link will then fail on any dep whose .pc still
# carries -lpthread, e.g. libwebp).
if [ "${VITA_PC_PTHREAD_FIXUP:-1}" != "0" ]; then
    msg "Normalizing -lpthread to -pthread in sysroot .pc files"
    sed -i 's/-lpthread/-pthread/g' "$PREFIX"/lib/pkgconfig/*.pc
else
    msg "Skipping sysroot -lpthread normalization (VITA_PC_PTHREAD_FIXUP=0)"
fi

msg "All Vita dependencies installed into $PREFIX"
