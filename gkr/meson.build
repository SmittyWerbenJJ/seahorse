gkr_sources = files(
  'gkr-backend.vala',
  'gkr-dialogs.vala',
  'gkr-item-add.vala',
  'gkr-item-delete-operation.vala',
  'gkr-item-info.vala',
  'gkr-item-properties.vala',
  'gkr-item.vala',
  'gkr-keyring-add.vala',
  'gkr-keyring-delete-operation.vala',
  'gkr-keyring-permission.vala',
  'gkr-keyring-properties.vala',
  'gkr-keyring.vala',
  'gkr-module.vala',
)

gkr_dependencies = [
  glib_deps,
  gtk4_dep,
  gcr4_dep,
  libsecret,
  libpwquality,
  common_dep,
]

gkr_vala_args = [
  '--gresources', resources_xml,
  '--vapidir', meson.current_source_dir(),
  '--pkg=pwquality',
]

gkr_lib = static_library('seahorse-gkr',
  gkr_sources,
  vala_args: gkr_vala_args,
  dependencies: gkr_dependencies,
)

gkr_dep = declare_dependency(
  link_with: gkr_lib,
  include_directories: include_directories('.'),
)
