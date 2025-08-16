"""Bzlmod module extensions that are only used for tests"""

load("//tools/http_dmg:http_dmg.bzl", "http_dmg")

_FIREFOX_BUILD_FILE = """\
alias(
    name = "info_plist",
    actual = "{file}",
    visibility = ["//visibility:public"],
)
"""

def _http_dmg_test_impl(module_ctx):
    http_dmg(
        name = "http_dmg_test_firefox",
        urls = ["https://ftp.mozilla.org/pub/firefox/releases/141.0.3/mac/en-US/Firefox%20141.0.3.dmg"],
        integrity = "sha256-u5Is2mkFQ73aofvDs8ulCMYHdIMmQ0UrwmZZUzH0LbE=",
        build_file_content = _FIREFOX_BUILD_FILE.format(
            file = "Firefox.app/Contents/Info.plist",
        ),
    )

    http_dmg(
        name = "http_dmg_test_firefox_strip_prefix",
        urls = ["https://ftp.mozilla.org/pub/firefox/releases/141.0.3/mac/en-US/Firefox%20141.0.3.dmg"],
        integrity = "sha256-u5Is2mkFQ73aofvDs8ulCMYHdIMmQ0UrwmZZUzH0LbE=",
        strip_prefix = "Firefox.app",
        build_file_content = _FIREFOX_BUILD_FILE.format(
            file = "Contents/Info.plist",
        ),
    )

    return module_ctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = [],
        root_module_direct_dev_deps = [
            "http_dmg_test_firefox_strip_prefix",
            "http_dmg_test_firefox",
        ],
    )

http_dmg_test = module_extension(
    doc = "A test module for `http_dmg`.",
    implementation = _http_dmg_test_impl,
)
