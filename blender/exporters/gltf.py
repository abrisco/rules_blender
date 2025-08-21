"""A script for export GLTF format files."""

import argparse
import json
from pathlib import Path

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


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)

    def _export_args_parser(arg: str) -> dict[str, str]:
        data = json.loads(arg)
        if not isinstance(data, dict):
            raise ValueError("Not a json map.")

        for illegal in ILLEGAL_EXPORT_ARGS:
            if illegal in data:
                raise ValueError(
                    f"Invalid export argument: `{illegal}`. The following are not allowed: {ILLEGAL_EXPORT_ARGS}"
                )
        return data

    parser.add_argument(
        "--blender",
        type=Path,
        required=True,
        help="The path to the Blender binary.",
    )
    parser.add_argument(
        "--output", type=Path, required=True, help="The path to the output file."
    )
    parser.add_argument(
        "--blend_file", type=Path, required=True, help="The path to the `.blend` file."
    )
    parser.add_argument(
        "--format",
        type=str,
        required=True,
        choices=SUPPORTED_EXPORTS.keys(),
        help="The export format to use.",
    )
    parser.add_argument(
        "--export_args",
        type=_export_args_parser,
        required=True,
        help="Arguments to pass to the export function.",
    )

    return parser.parse_args()


def main() -> None:
    """The main entrypoint to invoke under Blender."""
    args = parse_args()

    bpy.ops.export_scene.gltf(
        filepath=str(args.output),
        export_format=SUPPORTED_EXPORTS[args.format],
        **args.export_args,
    )


if __name__ == "__main__":
    main()
