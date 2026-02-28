"""Blender bzlmod extensions"""

load("@bazel_features//:features.bzl", "bazel_features")
load(
    "//blender/private:toolchain_repo.bzl",
    "BLENDER_VERSIONS",
    "CONSTRAINTS",
    "blender_toolchain_repository_hub",
    "blender_tools_repository",
)

def _find_modules(module_ctx):
    root = None
    rules_module = None
    for mod in module_ctx.modules:
        if mod.is_root:
            root = mod
        if mod.name == "rules_blender":
            rules_module = mod
    if root == None:
        root = rules_module
    if rules_module == None:
        fail("Unable to find rules_blender module")

    return root, rules_module

def _blender_impl(module_ctx):
    root, rules_module = _find_modules(module_ctx)
    if not root:
        root = rules_module
    reproducible = True

    for attrs in root.tags.toolchain:
        toolchain_names = []
        toolchain_labels = {}
        exec_compatible_with = {}
        target_settings = {}
        for version, available in BLENDER_VERSIONS.items():
            for platform, integrity in available.items():
                tool_name = blender_tools_repository(
                    name = "{}__{}_{}".format(attrs.name, version, platform),
                    version = version,
                    platform = platform,
                    url_templates = attrs.urls,
                    integrity = integrity,
                )

                toolchain_names.append(tool_name)
                toolchain_labels[tool_name] = "@{}".format(tool_name)
                exec_compatible_with[tool_name] = CONSTRAINTS[platform]
                target_settings[tool_name] = ["@rules_blender//blender/settings:version_{}".format(version)]

        blender_toolchain_repository_hub(
            name = attrs.name,
            toolchain_labels = toolchain_labels,
            toolchain_names = toolchain_names,
            exec_compatible_with = exec_compatible_with,
            target_compatible_with = {},
            target_settings = target_settings,
        )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = reproducible
    return module_ctx.extension_metadata(**metadata_kwargs)

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
    },
)

blender = module_extension(
    doc = "Bzlmod extensions for Blender",
    implementation = _blender_impl,
    tag_classes = {
        "toolchain": _TOOLCHAIN_TAG,
    },
)
