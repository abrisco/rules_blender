"""A toolchain for Blender"""

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
            all_files = depset(transitive = all_files),
            _is_local = False,
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
        "is_local": attr.bool(
            doc = "Whether or not the toolchain is backed by a host installed Blender.",
            default = False,
        ),
    },
)
