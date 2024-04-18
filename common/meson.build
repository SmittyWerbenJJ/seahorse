common_sources = files(
  'actions.vala',
  'add-keyserver-dialog.vala',
  'app-settings.vala',
  'backend.vala',
  'catalog.vala',
  'datepicker.vala',
  'deletable.vala',
  'delete-operation.vala',
  'exportable.vala',
  'export-operation.vala',
  'interaction.vala',
  'lockable.vala',
  'object.vala',
  'passphrase-prompt.vala',
  'pgp-settings.vala',
  'place.vala',
  'place-sorter.vala',
  'prefs.vala',
  'server-category.vala',
  'types.vala',
  'util.vala',
  'validity.vala',
  'viewable.vala',
)

common_deps = [
  glib_deps,
  gtk4_dep,
  gcr4_dep,
  libadwaita_dep,
  config,
]

common_vala_args = [
  '--gresources', resources_xml,
  '--use-header',
]

if get_option('keyservers-support')
  common_sources += ['keyserver-dropdown.vala', 'prefs-keyservers.vala']
  common_vala_args += [ '-D', 'WITH_KEYSERVER' ]
endif

common_lib = static_library('common',
  common_sources,
  dependencies: common_deps,
  vala_args: common_vala_args,
  vala_header: 'seahorse-common.h',
)

common_dep = declare_dependency(
  link_with: common_lib,
  include_directories: include_directories('.'),
  dependencies: common_deps,
)
