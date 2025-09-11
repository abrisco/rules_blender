"""blender_toolchain"""

load(
    "//blender/private:toolchain.bzl",
    _blender_toolchain = "blender_toolchain",
    _current_blender_bpy_library = "current_blender_bpy_library",
)

blender_toolchain = _blender_toolchain
current_blender_bpy_library = _current_blender_bpy_library
