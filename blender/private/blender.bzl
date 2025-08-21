"""blender_export"""

load(":toolchain.bzl", "TOOLCHAIN_TYPE")
load("@rules_venv//python/venv:defs.bzl", "py_venv_common")
load("@rules_venv//python:py_info.bzl", "PyInfo")

def _generate_process_wrapper(*, ctx, blender_toolchain):
    venv_toolchain = py_venv_common.get_toolchain(ctx, cfg = "exec")

    dep_info = py_venv_common.create_dep_info(
        ctx = ctx,
        deps = [ctx.attr._process_wrapper, target],
    )

    py_info = py_venv_common.create_py_info(
        ctx = ctx,
        imports = [],
        srcs = [ctx.file._process_wrapper],
        dep_info = dep_info,
    )

    executable, runfiles = py_venv_common.create_venv_entrypoint(
        ctx = ctx,
        venv_toolchain = venv_toolchain,
        py_info = py_info,
        main = ctx.file._process_wrapper,
        runfiles = dep_info.runfiles + blender_toolchain.all_files,
        use_runfiles_in_entrypoint = False,
        force_runfiles = True,
    )

    return executable, runfiles

def _blender_export_impl(ctx):
    blender_toolchain = ctx.toolchains[TOOLCHAIN_TYPE]

    outs = [ctx.outputs]
    out_dirs = [
        ctx.actions.declare_directory(out)
        for out in ctx.attr.out_dirs
    ]

    if not outs and not out_dirs:
        fail("Some form of output must be provided. Please update {}".format(
            ctx.label
        ))

    inputs = [ctx.file.blend_file] + ctx.files.data

    args = ctx.actions.args()
    args.add("--blender", blender_toolchain.blender)
    args.add("--blend_file", ctx.file.blend_file)
    args.add_all(outs, format_each = "--output=%s")
    args.add_all(out_dirs, format_each = "--output_dir=%s")
    args.add("--export_args", json.encode(ctx.attr.args))

    execution_requirements = {}
    if blender_toolchain.is_local:
        execution_requirements["no-remote"] = "1"

    executable, runfiles = _generate_process_wrapper(
        ctx = ctx,
        blender_toolchain = blender_toolchain,
    )

    ctx.actions.run(
        mnemonic = "BlenderExport",
        executable = executable,
        arguments = [args],
        outputs = outs + out_dirs,
        inputs = depset(inputs),
        tools = runfiles.files,
        execution_requirements = execution_requirements,
    )

    return [DefaultInfo(
        files = depset(outs + out_dirs),
        runfiles = ctx.runfiles(files = outs + out_dirs),
    )]

_COMMON_ATTRS = {
    "args": attr.string_dict(
        doc = "Any additional arguments to provide tot he export script",
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
    "script": attr.label(
        doc = "The exporter script.",
        executable = True,
        mandatory = True,
        providers = [PyInfo],
    ),
    "_process_wrapper": attr.label(
        cfg = "exec",
        executable = True,
        default = Label("//blender/private:export_process_wrapper.py"),
    ),
} | py_venv_common.create_venv_attrs()

blender_export = rule(
    doc = """\
A Bazel rule for exporting scenes from a `.blend` file.
""",
    implementation = _blender_export_impl,
    attrs = _COMMON_ATTRS | {
        "outs": attr.output_list(
            doc = "Output files produced by this target.",
        ),
        "out_dirs": attr.string_list(
            doc = "Output directories produced by this target.",
        ),
    },
    toolchains = [
        TOOLCHAIN_TYPE,
        py_venv_common.TOOLCHAIN_TYPE,
    ],
)

def _blender_test_impl(ctx):
    pass

blender_test = rule(
    doc = """\
A Bazel rule for exporting scenes from a `.blend` file.
""",
    implementation = _blender_test_impl,
    attrs = _COMMON_ATTRS,
    toolchains = [
        TOOLCHAIN_TYPE,
        py_venv_common.TOOLCHAIN_TYPE,
    ],
    test = True,
)
