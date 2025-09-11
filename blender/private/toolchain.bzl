"""A toolchain for Blender"""

load("@rules_venv//python:py_info.bzl", "PyInfo")

TOOLCHAIN_TYPE = str(Label("//blender:toolchain_type"))

def _blender_toolchain_impl(ctx):
    all_files = []
    if DefaultInfo in ctx.attr.blender:
        all_files.extend([
            ctx.attr.blender[DefaultInfo].files,
            ctx.attr.blender[DefaultInfo].default_runfiles.files,
        ])

    return [
        platform_common.ToolchainInfo(
            blender = ctx.executable.blender,
            bpy = ctx.attr.bpy,
            all_files = depset(transitive = all_files),
            is_local = ctx.attr.is_local,
        ),
    ]

blender_toolchain = rule(
    doc = "Define a toolchain for Blender rules.",
    implementation = _blender_toolchain_impl,
    attrs = {
        "blender": attr.label(
            doc = "The path to a Blender binary.",
            cfg = "exec",
            executable = True,
            allow_single_file = True,
            mandatory = True,
        ),
        "bpy": attr.label(
            doc = "The label to a [Blender Python API, `bpy`](https://docs.blender.org/api/current/index.html) target.",
            providers = [PyInfo],
            mandatory = True,
        ),
        "is_local": attr.bool(
            doc = "Whether or not the toolchain is backed by a host installed Blender.",
            default = False,
        ),
    },
)

def _current_blender_bpy_library_impl(ctx):
    toolchain = ctx.toolchains[TOOLCHAIN_TYPE]

    target = toolchain.bpy

    return [
        DefaultInfo(
            files = target[DefaultInfo].files,
            runfiles = target[DefaultInfo].default_runfiles,
        ),
        target[PyInfo],
        target[InstrumentedFilesInfo],
    ]

current_blender_bpy_library = rule(
    doc = "A rule for exposing the [Blender Python API, `bpy`](https://docs.blender.org/api/current/index.html)",
    implementation = _current_blender_bpy_library_impl,
    toolchains = [TOOLCHAIN_TYPE],
    provides = [PyInfo],
)
