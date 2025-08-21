"""A script for export GLTF format files."""

import json
import os
from pathlib import Path
from typing import Sequence

import bpy

SUPPORTED_EXPORTS = {
    "gltf": "GLTF_SEPARATE",
    "glb": "GLB",
}

ILLEGAL_EXPORT_ARGS = [
    # Only Bazel should provide these.
    "filepath",
    "export_format",
    # TODO: These are arguments
    "export_texture_dir",
]


def parse_args(argv: Sequence[str]) -> dict[str, str]:
    """Parse command line arguments."""
    pairs = {}
    for i in range(0, len(argv), 2):
        key = argv[i]
        value = argv[i + 1]
        if key in ILLEGAL_EXPORT_ARGS:
            raise ValueError(f"Illegal `bpy.ops.export_scene.gltf` arg: `{key}`")
        pairs[key] = value

    return pairs


def main() -> None:
    """The main entrypoint to invoke under Blender."""

    args_data = json.loads(
        Path(os.environ["RULES_BLENDER_ARGS_FILE"]).read_text(encoding="utf-8")
    )
    args = parse_args(args_data["arguments"])

    if not args_data["outputs"]:
        raise EnvironmentError("No outputs defined in rules_blender args file.")

    for key, output in args_data["outputs"].items():
        # `bin` is an output of `GLTF_SEPARATE`
        if key == "bin":
            continue

        if key not in SUPPORTED_EXPORTS:
            raise ValueError(
                f"output `{key}` ({output}) is not a supported output: {sorted(SUPPORTED_EXPORTS.keys())}"
            )

        bpy.ops.export_scene.gltf(
            filepath=str(output),
            export_format=SUPPORTED_EXPORTS[key],
            **args,
        )


if __name__ == "__main__":
    main()
