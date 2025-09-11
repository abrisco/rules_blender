"""A tool for fetching the integrity values of all known versions of Blender"""

import argparse
import base64
import binascii
import json
import logging
import os
import re
import urllib.request
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin

BASE_URL = "https://download.blender.org/release/"

VERSION_DIR_REGEX = re.compile(r"Blender([\d\.]+)")

VERSION_FILE_REGEX = re.compile(r"blender-([\d\.]+).sha256")

PLATFORM_REGEX = re.compile(r"blender-[\d\.]+-([\w\d-]+)\.")

REQUEST_HEADERS = {"User-Agent": "curl/8.7.1"}  # Set the User-Agent header

SUPPORTED_EXTENSIONS = (
    "macos-arm64.dmg",
    "macos-x64.dmg",
    "linux-x64.tar.xz",
    "windows-x64.zip",
    "windows-arm64.zip",
)

BUILD_TEMPLATE = """\
\"\"\"Blender Versions

A mapping of platform to integrity of the archive for said platform for each version of Blender available.
\"\"\"

# AUTO-GENERATED: DO NOT MODIFY
#
# Update using the following command:
#
# ```
# bazel run //tools/update_versions
# ```

BLENDER_VERSIONS = {}
"""


def parse_args() -> argparse.Namespace:
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description=__doc__)

    repo_root = Path(__file__).parent.parent.parent
    if "BUILD_WORKSPACE_DIRECTORY" in os.environ:
        repo_root = Path(os.environ["BUILD_WORKSPACE_DIRECTORY"])

    parser.add_argument(
        "--output",
        type=Path,
        default=repo_root / "blender/private/versions.bzl",
        help="The path to write the versions bzl file to.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose logging",
    )

    return parser.parse_args()


class LinkParser(HTMLParser):
    """A class for parsing links from an HTML document."""

    def __init__(self) -> None:
        """The constructor."""
        super().__init__()
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        """Parse the start tag value of an element"""
        if tag == "a":
            href = dict(attrs).get("href")
            if href:
                self.links.append(href)


def list_directory_links(url: str) -> list[str]:
    """Parses an HTML directory index and returns all links."""
    req = urllib.request.Request(url, headers=REQUEST_HEADERS)
    with urllib.request.urlopen(req) as response:
        html = response.read().decode("utf-8")
    parser = LinkParser()
    parser.feed(html)
    return parser.links


def extract_sha256s_from_file(url: str) -> dict[str, str]:
    """Downloads a .sha256 file and extracts the hash."""
    req = urllib.request.Request(url, headers=REQUEST_HEADERS)

    output = {}
    with urllib.request.urlopen(req) as response:
        lines = response.read().decode("utf-8").splitlines()
        for line in lines:
            if not line:
                continue
            sha256, _, basename = line.strip().partition(" ")
            output[basename.strip()] = sha256

    return output


def integrity(hex_str: str) -> str:
    """Convert a sha256 hex value to a Bazel integrity value"""

    # Remove any whitespace and convert from hex to raw bytes
    try:
        raw_bytes = binascii.unhexlify(hex_str.strip())
    except binascii.Error as e:
        raise ValueError(f"Invalid hex input: {e}") from e

    # Convert to base64
    encoded = base64.b64encode(raw_bytes).decode("utf-8")
    return f"sha256-{encoded}"


def main() -> None:
    """The main entrypoint."""

    args = parse_args()

    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)

    output = {}
    version_dirs = []
    for link in list_directory_links(BASE_URL):
        regex = VERSION_DIR_REGEX.match(link)
        if regex:
            version_dirs.append(regex)

    for version_dir in version_dirs:
        if version_dir.group(1).startswith(("1", "2")):
            logging.debug("Skipping %s", version_dir.group(0))
            continue

        logging.info("Processing %s", version_dir.group(0))
        version_url = urljoin(BASE_URL, version_dir.group(0))
        sha256_files = [
            f for f in list_directory_links(version_url) if f.endswith(".sha256")
        ]

        for sha_file in sha256_files:
            regex = VERSION_FILE_REGEX.match(sha_file)
            if not regex:
                raise ValueError(
                    f"Unexpected sha256 file name from `{version_url}`: {sha_file}"
                )
            version = regex.group(1)
            sha_url = urljoin(f"{version_url}/", sha_file)

            sha256s = {
                k: v
                for k, v in extract_sha256s_from_file(sha_url).items()
                if k.endswith(SUPPORTED_EXTENSIONS)
            }

            plats_to_shas = {}
            for basename, sha in sha256s.items():
                regex = PLATFORM_REGEX.match(basename)
                if not regex:
                    raise ValueError(f"Unexpected file name: {basename}")
                plats_to_shas[regex.group(1)] = integrity(sha)

            output[version] = plats_to_shas

    logging.debug("Writing to %s", args.output)
    args.output.write_text(BUILD_TEMPLATE.format(json.dumps(output, indent=4)))
    logging.info("Done")


if __name__ == "__main__":
    main()
