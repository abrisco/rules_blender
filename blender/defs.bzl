"""# rules_blender
"""

load(":blender_export.bzl", _blender_export = "blender_export")
load(":blender_toolchain.bzl", _blender_toolchain = "blender_toolchain")

blender_export = _blender_export
blender_toolchain = _blender_toolchain
