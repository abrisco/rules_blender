"""The process wrapper for `BlenderExport` actions in Bazel."""

import argparse
import json
import logging
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Sequence

from python.runfiles import Runfiles

RULES_BLENDER_RUNNING_UNDER_PROCESS_WRAPPER = (
    "RULES_BLENDER_RUNNING_UNDER_PROCESS_WRAPPER"
)
RULES_BLENDER_ARGS_FILE = "RULES_BLENDER_ARGS_FILE"
RULES_BLENDER_TEST_ARGS_FILE = "RULES_BLENDER_TEST_ARGS_FILE"
RULES_BLENDER_DEBUG = "RULES_BLENDER_DEBUG"


def _rlocation(rlocationpath: str) -> Path:
    """Look up a runfile and ensure the file exists

    Args:
        rlocationpath: The runfile key

    Returns:
        The requested runifle.
    """
    runfiles = Runfiles.Create()
    if not runfiles:
        raise EnvironmentError("Failed to locate runfiles")
    runfile = runfiles.Rlocation(rlocationpath, os.getenv("TEST_WORKSPACE"))
    if not runfile:
        raise FileNotFoundError(f"Failed to find runfile: {rlocationpath}")
    path = Path(runfile)
    if not path.exists():
        raise FileNotFoundError(f"Runfile does not exist: ({rlocationpath}) {path}")
    return path


def parse_args(
    argv: Sequence[str] | None = None, use_runfiles: bool = False
) -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)

    def _output_parser(value: str) -> tuple[str, Path]:
        key, _, path = value.partition(":")
        return key, Path(path)

    parser.add_argument(
        "--blender",
        type=_rlocation if use_runfiles else Path,
        required=True,
        help="The path to the Blender binary.",
    )
    parser.add_argument(
        "--main",
        type=_rlocation if use_runfiles else Path,
        required=True,
        help="The path to the script entrypoint.",
    )
    parser.add_argument(
        "--output",
        dest="outputs",
        type=_output_parser,
        default=[],
        action="append",
        help="A mapping of `key:path` for output files or directories.",
    )
    parser.add_argument(
        "--blend_file",
        type=_rlocation if use_runfiles else Path,
        required=True,
        help="The path to the `.blend` file.",
    )
    parser.add_argument(
        "--export_args",
        type=json.loads,
        required=True,
        help="Arguments to pass to the export function.",
    )

    return parser.parse_args(argv)


def main() -> None:
    """The main entrypoint."""
    if RULES_BLENDER_DEBUG in os.environ:
        logging.basicConfig(level=logging.DEBUG)

    argv = None
    use_runfiles = False
    is_test = RULES_BLENDER_TEST_ARGS_FILE in os.environ
    if is_test:
        argv = (
            _rlocation(os.environ[RULES_BLENDER_TEST_ARGS_FILE])
            .read_text(encoding="utf-8")
            .splitlines()
        )
        use_runfiles = True

    args = parse_args(argv, use_runfiles)

    blender_args = [
        str(args.blender),
        str(args.blend_file),
        "--offline-mode",
        "--background",
        "--python",
        str(args.main),
        "--",
    ] + args.export_args

    tmp_dir = Path(tempfile.mkdtemp(prefix="bzlblend-", dir=os.getenv("TEST_TMPDIR")))

    args_data = {
        "outputs": {key: str(path) for key, path in args.outputs},
        "arguments": args.export_args,
    }
    args_path = Path(tmp_dir) / "args.json"
    args_path.write_text(json.dumps(args_data, indent=4) + "\n")

    env = dict(os.environ)
    env[RULES_BLENDER_RUNNING_UNDER_PROCESS_WRAPPER] = "1"
    env[RULES_BLENDER_ARGS_FILE] = str(args_path)

    logging.debug("Command: `%s`", " ".join(blender_args))
    result = subprocess.run(
        blender_args,
        env=env,
        check=False,
        stderr=sys.stderr if is_test else subprocess.STDOUT,
        stdout=sys.stdout if is_test else subprocess.PIPE,
    )

    if is_test:
        sys.exit(result.returncode)

    if result.returncode:
        print(result.stdout.decode("utf-8"), file=sys.stderr)
        sys.exit(result.returncode)

    # Blender doesn't forward the return codes for exceptions in python scripts
    # so to ensure errors are correctly logged, check that all outputs exist.
    for _, output in args.outputs:
        if not output.exists():
            print(result.stdout.decode("utf-8"), file=sys.stderr)
            sys.exit(1)

    shutil.rmtree(tmp_dir)


if __name__ == "__main__":
    main()
