"""Blender bzlmod extensions"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load(
    "//blender/private:local_toolchain_repo.bzl",
    "blender_local_toolchain_repository",
)
load(
    "//blender/private:toolchain_repo.bzl",
    "BLENDER_PATHS",
    "BLENDER_VERSIONS",
    "BLENDER_VERSION_EXTENSIONS",
    "CONSTRAINTS",
    "blender_toolchain_repository_hub",
)
load("//tools/http_dmg:http_dmg.bzl", "http_dmg")

def _find_modules(module_ctx):
    root = None
    for mod in module_ctx.modules:
        if mod.is_root:
            return mod

    return root

def _format_toolchain_url(url, version, platform, extension):
    major_minor, _, _ = version.rpartition(".")

    return (
        url.replace("{major_minor}", major_minor)
            .replace("{semver}", version)
            .replace("{platform}", platform)
            .replace("{extension}", extension)
    )

_TOOLCHAIN_BUILD_FILE_CONTENT = """\
load("@rules_blender//blender:blender_toolchain.bzl", "blender_toolchain")

filegroup(
    name = "blender_bin",
    srcs = ["{blender}"],
    data = glob(
        include = ["**"],
        exclude = ["WORKSPACE", "BUILD", "*.bazel"],
    ),
)

blender_toolchain(
    name = "toolchain",
    blender = ":blender_bin",
    visibility = ["//visibility:public"],
)

alias(
    name = "{name}",
    actual = ":toolchain",
    visibility = ["//visibility:public"],
)
"""

def _blender_impl(module_ctx):
    root = _find_modules(module_ctx)

    reproducible = True
    for attrs in root.tags.local_toolchain:
        reproducible = False
        blender_local_toolchain_repository(
            name = attrs.name,
        )

    for attrs in root.tags.toolchain:
        if attrs.version not in BLENDER_VERSIONS:
            fail("Blender toolchain hub `{}` was given unsupported version `{}`. Try: {}".format(
                attrs.name,
                attrs.version,
                BLENDER_VERSIONS.keys(),
            ))
        available = BLENDER_VERSIONS[attrs.version]
        toolchain_names = []
        toolchain_labels = {}
        exec_compatible_with = {}
        for platform, integrity in available.items():
            extension = BLENDER_VERSION_EXTENSIONS[platform]

            urls = [
                _format_toolchain_url(url, attrs.version, platform, extension)
                for url in attrs.urls
            ]

            archive_rule = http_archive
            strip_prefix = "blender-{}-{}".format(attrs.version, platform)
            if extension == "dmg":
                archive_rule = http_dmg
                strip_prefix = ""

            tool_name = "{}__{}".format(attrs.name, platform)

            archive_rule(
                name = tool_name,
                urls = urls,
                integrity = integrity,
                strip_prefix = strip_prefix,
                build_file_content = _TOOLCHAIN_BUILD_FILE_CONTENT.format(
                    name = tool_name,
                    blender = BLENDER_PATHS[platform],
                ),
            )

            toolchain_names.append(tool_name)
            toolchain_labels[tool_name] = "@{}".format(tool_name)
            exec_compatible_with[tool_name] = CONSTRAINTS[platform]

        blender_toolchain_repository_hub(
            name = attrs.name,
            toolchain_labels = toolchain_labels,
            toolchain_names = toolchain_names,
            exec_compatible_with = exec_compatible_with,
            target_compatible_with = {},
            target_settings = {},
        )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = reproducible
    return module_ctx.extension_metadata(**metadata_kwargs)

_LOCAL_TOOLCHAIN_TAG = tag_class(
    doc = "An extension for defining a `blender_toolchain` backed by local install on the host. Note that this will only be instantiated for the root module.",
    attrs = {
        "name": attr.string(
            doc = "The name of the toolchain.",
            mandatory = True,
        ),
    },
)

_TOOLCHAIN_TAG = tag_class(
    doc = "An extension for defining a `blender_toolchain` from a download archive.",
    attrs = {
        "name": attr.string(
            doc = "The name of the toolchain.",
            mandatory = True,
        ),
        "urls": attr.string_list(
            doc = "Url templates to use for downloading Blender.",
            default = [
                "https://download.blender.org/release/Blender{major_minor}/blender-{semver}-{platform}.{extension}",
            ],
        ),
        "version": attr.string(
            doc = "The version of Blender to download.",
            default = "4.5.1",
        ),
    },
)

blender = module_extension(
    doc = "Bzlmod extensions for Blender",
    implementation = _blender_impl,
    tag_classes = {
        "local_toolchain": _LOCAL_TOOLCHAIN_TAG,
        "toolchain": _TOOLCHAIN_TAG,
    },
)
