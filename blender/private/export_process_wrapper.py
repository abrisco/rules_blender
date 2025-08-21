"""The process wrapper for `BlenderExport` actions in Bazel."""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Sequence

RUNNING_UNDER_PROCESS_WRAPPER = "RULES_BLENDER_RUNNING_UNDER_PROCESS_WRAPPER"

def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)

    def _export_args_parser(arg: str) -> dict[str, str]:
        data = json.loads(arg)
        if not isinstance(data, dict):
            raise ValueError("Not a json map.")

        return data

    parser.add_argument(
        "--blender",
        type=Path,
        required=True,
        help="The path to the Blender binary.",
    )
    parser.add_argument(
        "--main",
        type=Path,
        required=True,
        help="The path to the script entrypoint.",
    )
    parser.add_argument(
        "--output", type=Path, required=True, help="The path to the output file."
    )
    parser.add_argument(
        "--blend_file", type=Path, required=True, help="The path to the `.blend` file."
    )
    parser.add_argument(
        "--export_args",
        type=_export_args_parser,
        required=True,
        help="Arguments to pass to the export function.",
    )

    return parser.parse_args(argv)


def main() -> None:
    """The main entrypoint."""
    args = parse_args()

    env = dict(os.environ)
    env[RUNNING_UNDER_PROCESS_WRAPPER] = json.dumps(sys.argv[1:])

    blender_args = [
        str(args.blender),
        str(args.blend_file),
        "--background",
        "--python",
        __file__,
    ]

    result = subprocess.run(
        blender_args,
        env=env,
        check=False,
        stderr=subprocess.STDOUT,
        stdout=subprocess.PIPE,
    )

    if result.returncode:
        print(result.stdout.decode("utf-8"), file=sys.stderr)
        sys.exit(result.returncode)


def blender_main() -> None:
    """The main entrypoint to invoke under Blender."""
    argv = json.loads(os.environ[RUNNING_UNDER_PROCESS_WRAPPER])
    args = parse_args(argv)

    # TODO: Import main



if __name__ == "__main__":
    if RUNNING_UNDER_PROCESS_WRAPPER in os.environ:
        blender_main()
    else:
        main()
