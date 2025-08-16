"""Rules for locating local Blender installs"""

_BUILD_FILE_CONTENT = """\
load("@rules_blender//blender:blender_toolchain.bzl", "blender_toolchain")

blender_toolchain(
    name = "blender_toolchain",
    blender = "{wrapper}",
    is_local = True,
    visibility = ["//visibility:public"],
)

toolchain(
    name = "{name}",
    toolchain = ":blender_toolchain",
    toolchain_type = "@rules_blender//blender:toolchain_type",
    visibility = ["//visibility:public"],
)
"""

_UNIX_WRAPPER_TEMPLATE = """\
#!/usr/bin/env bash

set -euo pipefail

exec {blender} $@
"""

_WINDOWS_WRAPPER_TEMPLATE = """\
@ECHO OFF

{blender} %*
"""

_DEFAULT_OS_PATHS = {
    "mac os x": "/Applications/Blender.app/Contents/MacOS/Blender",
    "windows": "C:\\Program Files\\Blender Foundation\\Blender 4.5\\blender.exe",
}

def _blender_local_toolchain_repository_impl(repository_ctx):
    blender = repository_ctx.which("blender")
    if not blender:
        os_path = _DEFAULT_OS_PATHS.get(repository_ctx.os.name)
        if os_path:
            blender = repository_ctx.path(os_path)
            if not blender.exists:
                blender = None

    if not blender:
        fail("Unable to locate blender.")

    is_windows = "win" in repository_ctx.os.name
    if is_windows:
        wrapper_name = "blender.bat"
        wrapper_content = _WINDOWS_WRAPPER_TEMPLATE.format(
            blender = str(blender).replace("/", "\\"),
        )
    else:
        wrapper_name = "blender.sh"
        wrapper_content = _UNIX_WRAPPER_TEMPLATE.format(
            blender = blender,
        )

    repository_ctx.file(wrapper_name, wrapper_content, executable = True)
    repository_ctx.file("BUILD.bazel", _BUILD_FILE_CONTENT.format(
        name = repository_ctx.original_name,
        wrapper = wrapper_name,
    ))
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(repository_ctx.name))

blender_local_toolchain_repository = repository_rule(
    doc = "A repository rule for instantiating a `blender_toolchain` target backed by a host installed Blender.",
    implementation = _blender_local_toolchain_repository_impl,
)
