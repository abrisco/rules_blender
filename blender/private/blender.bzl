"""blender_export"""

load("@rules_venv//python:py_info.bzl", "PyInfo")
load("@rules_venv//python/venv:defs.bzl", "py_venv_common")
load(":toolchain.bzl", "TOOLCHAIN_TYPE")

BlenderScriptInfo = provider(
    doc = "A provider encompasing additional metadata about a Blender python script.",
    fields = {
        "main": "File: The path to the `main` source of a Blender script.",
    },
)

def _blender_script_main_finder_aspect_impl(target, ctx):
    if PyInfo not in target:
        return []

    main = getattr(ctx.rule.file, "main")
    srcs = getattr(ctx.rule.files, "srcs")
    if main:
        if main not in srcs:
            fail("`main` was not found in `srcs`. Please add `{}` to `srcs` for {}".format(
                main.path,
                ctx.label,
            ))
        return main

    if len(srcs) == 1:
        main = srcs[0]
    else:
        for src in srcs:
            basename = src.basename[:-len(".py")]
            if basename == target.label.name:
                main = src

                # Accept the first candidate as `main`
                break

    if not main:
        fail("Failed to find `main` for {}".format(
            target.label,
        ))

    return [BlenderScriptInfo(
        main = main,
    )]

_blender_script_main_finder_aspect = aspect(
    doc = "An aspect accompanying `blender_export` to locate `main` for the `script` attribute.",
    implementation = _blender_script_main_finder_aspect_impl,
)

def _generate_process_wrapper(*, ctx, blender_toolchain, script_info, is_test = False):
    venv_toolchain = py_venv_common.get_toolchain(ctx, cfg = "exec")

    process_wrapper_main = ctx.attr._process_wrapper[BlenderScriptInfo].main
    deps = [ctx.attr._process_wrapper]
    srcs = [process_wrapper_main]
    if script_info.target:
        deps.append(script_info.target)
    else:
        srcs.append(script_info.main)

    dep_info = py_venv_common.create_dep_info(
        ctx = ctx,
        deps = deps,
    )

    py_info = py_venv_common.create_py_info(
        ctx = ctx,
        imports = [],
        srcs = srcs,
        dep_info = dep_info,
    )

    executable, runfiles = py_venv_common.create_venv_entrypoint(
        ctx = ctx,
        venv_toolchain = venv_toolchain,
        py_info = py_info,
        main = process_wrapper_main,
        runfiles = dep_info.runfiles.merge(ctx.runfiles(transitive_files = blender_toolchain.all_files)),
        use_runfiles_in_entrypoint = True if is_test else False,
        force_runfiles = False if is_test else True,
    )

    return executable, runfiles

def _output_map(value):
    key, file = value
    return "--output={}:{}".format(key, file.path)

def _get_script_attr(ctx):
    if BlenderScriptInfo in ctx.attr.script:
        return struct(
            main = ctx.attr.script[BlenderScriptInfo].main,
            target = ctx.attr.script,
        )

    files = ctx.files.script
    if len(files) != 1:
        fail("in script attribute of {rule} rule {export_label}: '{script_label}' must produce a single file".format(
            rule = ctx.rule.name,
            export_label = ctx.label,
            script_label = ctx.attr.script.label,
        ))

    return struct(
        main = files[0],
        target = None,
    )

def _blender_export_impl(ctx):
    blender_toolchain = ctx.toolchains[TOOLCHAIN_TYPE]

    output_map = {}

    for collection, constructor in [(ctx.attr.outs, ctx.actions.declare_file), (ctx.attr.out_dirs, ctx.actions.declare_directory)]:
        for file, key in collection.items():
            if ":" in key:
                fail("`:` is an illegal character in key: `{}`".format(key))
            if key in output_map:
                fail("Duplicate key detected. Output files and directories must have unique keys: {}".format(
                    key,
                ))
            output_map[key] = constructor(file)

    if not output_map:
        fail("Some form of output must be provided. Please update {}".format(
            ctx.label,
        ))

    inputs = [ctx.file.blend_file] + ctx.files.data

    script_info = _get_script_attr(ctx)

    args = ctx.actions.args()
    args.add("--blender", blender_toolchain.blender)
    args.add("--blend_file", ctx.file.blend_file)
    args.add("--main", script_info.main)
    args.add_all(output_map.items(), map_each = _output_map)
    args.add("--export_args", json.encode(ctx.attr.args or []))

    execution_requirements = {}
    if blender_toolchain.is_local:
        execution_requirements["no-remote"] = "1"

    executable, runfiles = _generate_process_wrapper(
        ctx = ctx,
        script_info = script_info,
        blender_toolchain = blender_toolchain,
    )

    outputs = list(output_map.values())

    ctx.actions.run(
        mnemonic = "BlenderExport",
        executable = executable,
        arguments = [args],
        outputs = outputs,
        inputs = depset(inputs),
        tools = runfiles.files,
        execution_requirements = execution_requirements,
    )

    output_groups = {
        "blender_export_{}".format(key): depset([out])
        for (key, out) in output_map.items()
    }

    return [
        DefaultInfo(
            files = depset(outputs),
            runfiles = ctx.runfiles(files = outputs),
        ),
        OutputGroupInfo(
            **output_groups
        ),
    ]

_COMMON_ATTRS = {
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
        cfg = "exec",
        aspects = [_blender_script_main_finder_aspect],
        executable = True,
        allow_files = True,
        mandatory = True,
    ),
    "_process_wrapper": attr.label(
        cfg = "exec",
        executable = True,
        aspects = [_blender_script_main_finder_aspect],
        default = Label("//blender/private:export_process_wrapper"),
    ),
} | py_venv_common.create_venv_attrs()

blender_export = rule(
    doc = """\
A Bazel rule for exporting scenes from a `.blend` file.
""",
    implementation = _blender_export_impl,
    attrs = _COMMON_ATTRS | {
        "args": attr.string_dict(
            doc = "Any additional arguments to provide tot he export script",
        ),
        "out_dirs": attr.string_dict(
            doc = "Output directories produced by this target.",
        ),
        "outs": attr.string_dict(
            doc = "Output files produced by this target.",
        ),
    },
    toolchains = [
        TOOLCHAIN_TYPE,
        py_venv_common.TOOLCHAIN_TYPE,
    ],
)

def _rlocationpath(file, workspace_name):
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]

    return "{}/{}".format(workspace_name, file.short_path)

def _blender_test_impl(ctx):
    blender_toolchain = ctx.toolchains[TOOLCHAIN_TYPE]

    script_info = _get_script_attr(ctx)

    args = ctx.actions.args()
    args.set_param_file_format("multiline")
    args.add("--blender", _rlocationpath(blender_toolchain.blender, ctx.workspace_name))
    args.add("--blend_file", _rlocationpath(ctx.file.blend_file, ctx.workspace_name))
    args.add("--main", _rlocationpath(script_info.main, ctx.workspace_name))
    args.add("--export_args", json.encode(ctx.attr.args))

    args_file = ctx.actions.declare_file("{}.args.txt".format(ctx.label.name))
    ctx.actions.write(args_file, args)

    execution_requirements = {}
    if blender_toolchain.is_local:
        execution_requirements["no-remote"] = "1"

    executable, runfiles = _generate_process_wrapper(
        ctx = ctx,
        blender_toolchain = blender_toolchain,
        script_info = script_info,
        is_test = True,
    )

    transitive_files = [depset([args_file])]
    for target in ctx.attr.data + [ctx.attr.blend_file]:
        if DefaultInfo in target:
            transitive_files.append(target[DefaultInfo].files)
            runfiles = runfiles.merge(target[DefaultInfo].default_runfiles)

    return [
        DefaultInfo(
            executable = executable,
            runfiles = runfiles.merge(ctx.runfiles(
                transitive_files = depset(transitive = transitive_files),
            )),
        ),
        RunEnvironmentInfo(
            environment = {
                "RULES_BLENDER_TEST_ARGS_FILE": _rlocationpath(args_file, ctx.workspace_name),
            },
        ),
    ]

blender_test = rule(
    doc = """\
A Bazel test rule for performing checks on a `.blend` file.
""",
    implementation = _blender_test_impl,
    attrs = _COMMON_ATTRS,
    toolchains = [
        TOOLCHAIN_TYPE,
        py_venv_common.TOOLCHAIN_TYPE,
    ],
    test = True,
)
