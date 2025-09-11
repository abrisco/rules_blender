"""Blender toolchain repositories"""

load("@apple_support//tools/http_dmg:http_dmg.bzl", "http_dmg")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//blender/private:versions.bzl", _BLENDER_VERSIONS = "BLENDER_VERSIONS")

BLENDER_DEFAULT_VERSION = "4.5.1"

BLENDER_VERSIONS = _BLENDER_VERSIONS

BLENDER_VERSION_EXTENSIONS = {
    "linux-x64": "tar.xz",
    "macos-arm64": "dmg",
    "macos-x64": "dmg",
    "windows-arm64": "zip",
    "windows-x64": "zip",
}

BLENDER_PATHS = {
    "linux-x64": "blender",
    "macos-arm64": "Blender.app/Contents/MacOS/Blender",
    "macos-x64": "Blender.app/Contents/MacOS/Blender",
    "windows-arm64": "blender.exe",
    "windows-x64": "blender.exe",
}

CONSTRAINTS = {
    "linux-x64": ["@platforms//os:linux", "@platforms//cpu:x86_64"],
    "macos-arm64": ["@platforms//os:macos", "@platforms//cpu:aarch64"],
    "macos-x64": ["@platforms//os:macos", "@platforms//cpu:x86_64"],
    "windows-arm64": ["@platforms//os:windows", "@platforms//cpu:aarch64"],
    "windows-x64": ["@platforms//os:windows", "@platforms//cpu:x86_64"],
}

_BLENDER_TOOLCHAIN_BUILD_FILE_CONTENT = """\
load("@rules_blender//blender:blender_toolchain.bzl", "blender_toolchain")
load("@rules_venv//python:py_library.bzl", "py_library")

filegroup(
    name = "blender_bin",
    srcs = ["{blender}"],
    data = glob(
        include = ["**"],
        exclude = ["WORKSPACE", "BUILD", "*.bazel"],
    ),
)

py_library(
    name = "bpy",
    srcs = glob(
        include = {bpy_srcs_globs},
    ),
    data = glob(
        include = {bpy_data_globs},
        exclude = {bpy_srcs_globs},
        allow_empty = True,
    ),
    imports = {bpy_imports},
)

blender_toolchain(
    name = "toolchain",
    blender = ":blender_bin",
    bpy = ":bpy",
    visibility = ["//visibility:public"],
)

alias(
    name = "{name}",
    actual = ":toolchain",
    visibility = ["//visibility:public"],
)
"""

_BPY_PLATFORM_IMPORT = {
    "linux-x64": "{major_minor}/scripts/modules",
    "macos-arm64": "Blender.app/Contents/Resources/{major_minor}/scripts/modules",
    "macos-x64": "Blender.app/Contents/Resources/{major_minor}/scripts/modules",
    "windows-arm64": "{major_minor}/scripts/modules",
    "windows-x64": "{major_minor}/scripts/modules",
}

def _format_toolchain_url(url, version, platform, extension):
    major_minor, _, _ = version.rpartition(".")

    return (
        url.replace("{major_minor}", major_minor)
            .replace("{semver}", version)
            .replace("{platform}", platform)
            .replace("{extension}", extension)
    )

def blender_tools_repository(*, name, version, platform, url_templates, integrity):
    """Download a version of Blender and instantiate targets for itl

    Args:
        name (str): The name of the repository to create.
        version (str): The version of Blender
        platform (str): The target platform of the Blender executable.
        url_templates (list): A list of urls to format for fetching blender.
        integrity (str): The integrity checksum of the blender binary.

    Returns:
        str: Return `name` for convenience.
    """
    extension = BLENDER_VERSION_EXTENSIONS[platform]

    urls = [
        _format_toolchain_url(url, version, platform, extension)
        for url in url_templates
    ]

    archive_rule = http_archive
    strip_prefix = "blender-{}-{}".format(version, platform)
    if extension == "dmg":
        archive_rule = http_dmg
        strip_prefix = ""

    # While not a url, the formatting does the same desired replacements
    bpy_import = _format_toolchain_url(_BPY_PLATFORM_IMPORT[platform], version, platform, extension)

    bpy_imports = [bpy_import]
    bpy_srcs_globs = ["{}/bpy/**/*.py".format(bpy_import)]
    bpy_data_globs = ["{}/bpy/**/*.pyc".format(bpy_import)]

    archive_rule(
        name = name,
        urls = urls,
        integrity = integrity,
        strip_prefix = strip_prefix,
        build_file_content = _BLENDER_TOOLCHAIN_BUILD_FILE_CONTENT.format(
            name = name,
            blender = BLENDER_PATHS[platform],
            bpy_imports = repr(bpy_imports),
            bpy_srcs_globs = repr(bpy_srcs_globs),
            bpy_data_globs = repr(bpy_data_globs),
        ),
    )

    return name

_BUILD_FILE_FOR_TOOLCHAIN_HUB_TEMPLATE = """
toolchain(
    name = "{name}",
    exec_compatible_with = {exec_constraint_sets_serialized},
    target_compatible_with = {target_constraint_sets_serialized},
    target_settings = {target_settings_serialized},
    toolchain = "{toolchain}",
    toolchain_type = "@rules_blender//blender:toolchain_type",
    visibility = ["//visibility:public"],
)
"""

def _BUILD_for_toolchain_hub(
        toolchain_names,
        toolchain_labels,
        target_settings,
        target_compatible_with,
        exec_compatible_with):
    return "\n".join([_BUILD_FILE_FOR_TOOLCHAIN_HUB_TEMPLATE.format(
        name = toolchain_name,
        exec_constraint_sets_serialized = json.encode(exec_compatible_with[toolchain_name]),
        target_constraint_sets_serialized = json.encode(target_compatible_with.get(toolchain_name, [])),
        target_settings_serialized = json.encode(target_settings.get(toolchain_name)) if toolchain_name in target_settings else "None",
        toolchain = toolchain_labels[toolchain_name],
    ) for toolchain_name in toolchain_names])

def _blender_toolchain_repository_hub_impl(repository_ctx):
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    repository_ctx.file("BUILD.bazel", _BUILD_for_toolchain_hub(
        toolchain_names = repository_ctx.attr.toolchain_names,
        toolchain_labels = repository_ctx.attr.toolchain_labels,
        target_settings = repository_ctx.attr.target_settings,
        target_compatible_with = repository_ctx.attr.target_compatible_with,
        exec_compatible_with = repository_ctx.attr.exec_compatible_with,
    ))

blender_toolchain_repository_hub = repository_rule(
    doc = (
        "Generates a toolchain-bearing repository that declares a set of other toolchains from other " +
        "repositories. This exists to allow registering a set of toolchains in one go with the `:all` target."
    ),
    attrs = {
        "exec_compatible_with": attr.string_list_dict(
            doc = "A list of constraints for the execution platform for this toolchain, keyed by toolchain name.",
            mandatory = True,
        ),
        "target_compatible_with": attr.string_list_dict(
            doc = "A list of constraints for the target platform for this toolchain, keyed by toolchain name.",
            mandatory = True,
        ),
        "target_settings": attr.string_list_dict(
            doc = "A list of config_settings that must be satisfied by the target configuration in order for this toolchain to be selected during toolchain resolution.",
            mandatory = True,
        ),
        "toolchain_labels": attr.string_dict(
            doc = "The name of the toolchain implementation target, keyed by toolchain name.",
            mandatory = True,
        ),
        "toolchain_names": attr.string_list(
            mandatory = True,
        ),
    },
    implementation = _blender_toolchain_repository_hub_impl,
)
