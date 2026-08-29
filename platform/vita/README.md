# mkxp-z on PlayStation Vita

This directory holds the Vita target for mkxp-z: a Meson cross file, the
dependency bootstrap, VPK packaging, and this note. The port strategy,
tiering, and decision register live in the parent project:
[RPG-Player](https://github.com/JohanDevl/RPG-Player) (PRD §5, §12).

## Layout

| File | Purpose |
|---|---|
| `vita-cross.txt` | Meson cross file for VitaSDK (`arm-vita-eabi`, `-Wl,-q`) |
| `build-deps.sh` | Builds SDL2(+PIB), SDL2_sound, uchardet, ruby into the VitaSDK sysroot |
| `build.sh` | `meson setup` + `meson compile`, produces `mkxp-z.vpk` |
| `meson.build` | VPK packaging (`vita-elf-create` → `vita-make-fself` → `vita-pack-vpk`) |
| `sce_sys/` | LiveArea assets (placeholder icon derived from mkxp-z's icon) |

## Quick start (Docker)

```bash
docker run --rm -v "$PWD:/work" -w /work vitasdk/vitasdk bash -c '
    apt-get update -qq && apt-get install -y -qq ruby-full autoconf bison xxd meson ninja-build
    # ruby 2.7 needs autoconf 2.69
    curl -sL http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz | tar xz -C /tmp
    (cd /tmp/autoconf-2.69 && ./configure --prefix=/opt/ac269 && make && make install)
    platform/vita/build-deps.sh
    platform/vita/build.sh'
```

## Build configuration

The canonical option set (see `build.sh` for the rationale of each):
`gfx_backend=gles`, `use_miniffi=false`, `enable-https=false`,
`mri_version=2.7`, `shared_fluid=true`.

The interpreter is **Ruby 3.1** — the version Essentials v20+ games ship
(PRD Q6/M4b) — built from
[JohanDevl/ruby3.1-vita](https://github.com/JohanDevl/ruby3.1-vita):
mkxp-z's own ruby 3.1.3 fork (their RGSS compatibility patches included)
plus the Vita platform layer, whose SceFiber coroutine approach follows
[sinister-kid/ruby2.7-vita](https://github.com/sinister-kid/ruby2.7-vita)
(PRD D4). Set `MRI_VERSION=2.7` for both scripts to fall back to the
2.7 scaffold. The pure-ruby stdlib is packaged into the VPK at
`app0:ruby`.

**The SceFiber/GC behavior on 3.1 is compile-proven only** — fibers,
stack scanning, and kernel memblock bookkeeping are exactly the things
that only hardware can validate (PRD: feasibility at M0b, proof at M4b).

## Graphics path

GLES2 is provided by **PVR_PSP2 (Piglet)** through the **pib** wrapper
(PRD D6: PVR primary). VitaSDK's stock SDL2 is built with every OpenGL
backend disabled, so `build-deps.sh` rebuilds SDL2 2.32.8 with
`SDL_VIDEO_VITA_PIB=ON`.

At **runtime** the PVR_PSP2 `.suprx` modules (`libGLESv2.suprx`,
`libIMGEGL.suprx`, `libpvrPSP2_WSEGL.suprx`, `libgpu_es4_ext.suprx`, and
`libpib.suprx`) must be present. **They are deliberately not committed to
this tree**: they are a port of Imagination's proprietary driver and
"distributed on GitHub" is not "licensed for redistribution" (PRD D6/§10.4
— the same standard that keeps Sony's `psp2cgc.exe` out). Until provenance
is settled, fetch them yourself from the
[PVR_PSP2 releases](https://github.com/GrapheneCt/PVR_PSP2/releases) and
place them in `ux0:data/RPGPlayer/module/` (or the VPK's `module/`
directory if you build a bundle for personal use).

The fallback backend is vitaGL (PRD D6 revisit clause): far more active,
but hard-caps textures at 4096 px and requires every user to extract
`libshacccg.suprx` from their own console.

## Status

This target currently aims at **M2** of the PRD delivery plan: cross
compile, link, produce a VPK. It is not yet expected to boot a game.
Hardware bring-up (M4: vanilla RMXP project to title screen) is the next
gate, and needs on-device measurements (PRD Q1–Q7) before further work.

## Licensing

GPLv2+ like the rest of mkxp-z. `enable-https=false` keeps mkxp-z's own
HTTPS/OpenSSL dependency out (PRD §10.3), and the Ruby 3.1 build excludes
the openssl extension (`--with-out-ext=openssl` in its `configure-vita`),
so no OpenSSL code reaches the binary. (The legacy 2.7 scaffold path
still links libcrypto through its openssl ext — a reason to prefer 3.1
for distribution too.) No Sony or Imagination proprietary binaries are
in this tree.

Portions of the platform approach are informed by
[LiEnby/mkxp-vita](https://github.com/LiEnby/mkxp-vita) (GPL-2.0), read as
a reference map; and the Ruby scaffold is
[sinister-kid/ruby2.7-vita](https://github.com/sinister-kid/ruby2.7-vita).
