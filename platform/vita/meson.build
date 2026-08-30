# VPK packaging for the PlayStation Vita.
# Entered from the root meson.build after the executable target is defined.

vita_elf_create = find_program('vita-elf-create')
vita_make_fself = find_program('vita-make-fself')
vita_mksfoex = find_program('vita-mksfoex')
make_vpk = find_program(meson.current_source_dir() / 'make-vpk.sh')

vita_title_id = 'RPGP00001'
vita_app_name = 'RPG-Player'

velf = custom_target('velf',
    input: mkxp_exe,
    output: 'mkxp-z.velf',
    command: [vita_elf_create, '@INPUT@', '@OUTPUT@'],
    build_by_default: true)

eboot = custom_target('eboot',
    input: velf,
    output: 'eboot.bin',
    # No '-s': a *safe* fself cannot read vs0:, so the GPU driver's
    # system imports (SceLibc/SceLibm/SceUlt) can never resolve. Every
    # GL homebrew ships unsafe; HENkaku's "unsafe homebrew" toggle
    # exists precisely for this.
    command: [vita_make_fself, '-c', '@INPUT@', '@OUTPUT@'],
    build_by_default: true)

# NOTE: no ATTRIBUTE2=12 (extended memory) for now - the PVR driver
# needs CDRAM for its parameter buffers and extended-memory mode is
# suspected to conflict; revisit with the PRD Q1 measurements.
sfo = custom_target('param_sfo',
    output: 'param.sfo',
    command: [vita_mksfoex,
              '-s', 'TITLE_ID=' + vita_title_id,
              vita_app_name, '@OUTPUT@'],
    build_by_default: true)

# Ruby's pure-ruby stdlib, staged by build-deps.sh; required at runtime
# by Essentials games ("require" of zlib wrappers, forwardable, ...).
fs = import('fs')
vitasdk_root = run_command('sh', '-c', 'echo -n "${VITASDK:-/usr/local/vitasdk}"', check: true).stdout()
ruby_stdlib_dir = vitasdk_root / 'arm-vita-eabi' / 'mkxpz-ruby-stdlib'
if not fs.is_dir(ruby_stdlib_dir)
    error('Ruby stdlib staging dir not found (' + ruby_stdlib_dir + '); run platform/vita/build-deps.sh first')
endif

# The stdlib is NOT bundled into the VPK: VitaShell's installer fails on
# thousand-file packages (observed on hardware: a data abort from
# vita-pack-vpk's layout, then SCE_KERNEL_ERROR_INVALID_ARGUMENT from
# the canonical zip layout). It ships as a separate archive the user
# copies to ux0:data/RPGPlayer/ruby over USB/FTP instead.
vpk = custom_target('vpk',
    input: [eboot, sfo],
    output: 'mkxp-z.vpk',
    command: [make_vpk,
              '@INPUT0@',
              '@INPUT1@',
              meson.current_source_dir() / 'sce_sys' / 'icon0.png',
              '-',
              '@OUTPUT@'],
    build_by_default: true)

make_stdlib_zip = find_program(meson.current_source_dir() / 'make-stdlib-zip.sh')
ruby_stdlib_zip = custom_target('ruby-stdlib-zip',
    output: 'ruby-stdlib.zip',
    command: [make_stdlib_zip, ruby_stdlib_dir, '@OUTPUT@'],
    build_by_default: true)
