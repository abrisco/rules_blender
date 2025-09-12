"""# rules_blender
"""

load(
    ":blender_export.bzl",
    _blender_export = "blender_export",
)
load(
    ":blender_test.bzl",
    _blender_test = "blender_test",
)
load(
    ":blender_toolchain.bzl",
    _blender_toolchain = "blender_toolchain",
)

blender_export = _blender_export
blender_test = _blender_test
blender_toolchain = _blender_toolchain
