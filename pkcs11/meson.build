pkcs11_sources = files(
  'certificate-der-export-operation.vala',
  'pkcs11-certificate.vala',
  'pkcs11-certificate-dialog.vala',
  'pkcs11-certificate-widget.vala',
  'pkcs11-delete-operation.vala',
  'pkcs11-generate.vala',
  'pkcs11-module.vala',
  'pkcs11-private-key.vala',
  'pkcs11-private-key-widget.vala',
  'pkcs11-request.vala',
  'pkcs11-token.vala',
  'pkcs11-token-filter.vala',

  'cryptoki.vapi',
  'pkcs11.vapi',
  'seahorse-pkcs11-backend.c',
)

pkcs11_deps = [
  glib_deps,
  common_dep,
]

pkcs11_vala_args = [
  '--gresources', resources_xml,
]

pkcs11_lib = static_library('seahorse-pkcs11',
  pkcs11_sources,
  dependencies: pkcs11_deps,
  vala_args: pkcs11_vala_args,
)

pkcs11_dep = declare_dependency(
  link_with: pkcs11_lib,
  include_directories: include_directories('.'),
)
