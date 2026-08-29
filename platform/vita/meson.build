# VPK packaging for the PlayStation Vita.
# Entered from the root meson.build after the executable target is defined.

vita_elf_create = find_program('vita-elf-create')
vita_make_fself = find_program('vita-make-fself')
vita_mksfoex = find_program('vita-mksfoex')
vita_pack_vpk = find_program('vita-pack-vpk')

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

vpk = custom_target('vpk',
    input: [eboot, sfo],
    output: 'mkxp-z.vpk',
    command: [vita_pack_vpk,
              '-b', '@INPUT0@',
              '-s', '@INPUT1@',
              '--add', meson.current_source_dir() / 'sce_sys' / 'icon0.png' + '=sce_sys/icon0.png',
              '@OUTPUT@'],
    build_by_default: true)
