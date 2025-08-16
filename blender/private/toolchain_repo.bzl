"""Blender toolchain repositories"""

load("//blender/private:versions.bzl", _BLENDER_VERSIONS = "BLENDER_VERSIONS")

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
