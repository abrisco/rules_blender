"""blender_export"""

load(":toolchain.bzl", "TOOLCHAIN_TYPE")

_SUPPORTED_FORMATS = [
    "glb",
    "gltf",
]

def _blender_export_impl(ctx):
    blender_toolchain = ctx.toolchains[TOOLCHAIN_TYPE]

    if ctx.attr.out:
        output = ctx.actions.declare_file(ctx.attr.out)
    else:
        output = ctx.actions.declare_file(ctx.label.name)

    if ctx.attr.format:
        format = ctx.attr.format
    else:
        format = output.extension
        if format not in _SUPPORTED_FORMATS:
            fail("The extension of the output file ({}) does not match a supported format: {}".format(
                format.path,
                _SUPPORTED_FORMATS,
            ))

    inputs = [ctx.file.blend_file] + ctx.files.data

    args = ctx.actions.args()
    args.add("--blender", blender_toolchain.blender)
    args.add("--output", output)
    args.add("--blend_file", ctx.file.blend_file)
    args.add("--format", format)
    args.add("--export_args", json.encode(ctx.attr.args))

    execution_requirements = {}
    if blender_toolchain._is_local:
        execution_requirements["no-remote"] = "1"

    ctx.actions.run(
        mnemonic = "BlenderExport{}".format(format.capitalize()),
        executable = ctx.executable._process_wrapper,
        arguments = [args],
        outputs = [output],
        inputs = depset(inputs),
        tools = blender_toolchain.all_files,
        execution_requirements = execution_requirements,
    )

    return [DefaultInfo(
        files = depset([output]),
        runfiles = ctx.runfiles(files = [output]),
    )]

blender_export = rule(
    doc = """\
A Bazel rule for exporting scenes from a `.blend` file.
""",
    implementation = _blender_export_impl,
    attrs = {
        "args": attr.string_dict(
            doc = "A mapping of parameter names to assignments to pass to [bpy.ops.export_scene.gltf](https://docs.blender.org/api/current/bpy.ops.export_scene.html#bpy.ops.export_scene.gltf)",
        ),
        "blend_file": attr.label(
            doc = "The `.blend` file to export from.",
            allow_single_file = [".blend"],
            mandatory = True,
        ),
        "data": attr.label_list(
            doc = "Additional files associated with the `.blend` file.",
            allow_files = True,
        ),
        "format": attr.string(
            doc = "The format to export to.",
            values = _SUPPORTED_FORMATS,
        ),
        "out": attr.string(
            doc = "The name of the output file. If unspecified, the name of the target will be used.",
        ),
        "_process_wrapper": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//blender/private:export_process_wrapper"),
        ),
    },
    toolchains = [
        TOOLCHAIN_TYPE,
    ],
)
