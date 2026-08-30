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
    command: [vita_make_fself, '-c', '-s', '@INPUT@', '@OUTPUT@'],
    build_by_default: true)

# ATTRIBUTE2=12 requests the extended memory budget; RAM is the binding
# constraint for this port (PRD Q1/Q2), so ask for everything available.
sfo = custom_target('param_sfo',
    output: 'param.sfo',
    command: [vita_mksfoex,
              '-s', 'TITLE_ID=' + vita_title_id,
              '-d', 'ATTRIBUTE2=12',
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

vpk = custom_target('vpk',
    input: [eboot, sfo],
    output: 'mkxp-z.vpk',
    command: [make_vpk,
              '@INPUT0@',
              '@INPUT1@',
              meson.current_source_dir() / 'sce_sys' / 'icon0.png',
              ruby_stdlib_dir,
              '@OUTPUT@'],
    build_by_default: true)
