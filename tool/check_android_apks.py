"""Report Android release sizes and check APK compatibility before signing."""

import argparse
from collections import Counter
from pathlib import Path
import re
import subprocess
from zipfile import ZipFile


# Byte ceilings leave room for normal growth above the alpha.3 package baseline.
SIZE_LIMITS = {
    "universal": 126_000_000,
    "arm64-v8a": 49_000_000,
    "armeabi-v7a": 41_500_000,
    "x86_64": 52_000_000,
}
ABIS = set(SIZE_LIMITS) - {"universal"}
REQUIRED_LIBRARIES = {
    "libapp.so",
    "libflutter.so",
    "libmlkit_google_ocr_pipeline.so",
    "libsqlcipher.so",
}


def describe_apk(apk, abis, aapt, version_code, version_name):
    badging = subprocess.check_output([aapt, "dump", "badging", apk], text=True)
    package = re.search(
        r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'",
        badging,
        re.MULTILINE,
    )
    expected_package = ("com.lootr.app", version_code, version_name)
    if not package or package.groups() != expected_package:
        raise ValueError(f"{apk.name} has an unexpected app ID or version.")
    native_code = re.search(r"^native-code: (.+)$", badging, re.MULTILINE)
    actual_abis = set(re.findall(r"'([^']+)'", native_code[1])) if native_code else set()
    if actual_abis != abis:
        raise ValueError(
            f"{apk.name} advertises ABIs {sorted(actual_abis)}. Expected {sorted(abis)}."
        )

    with ZipFile(apk) as archive:
        files = archive.infolist()
    paths = {file.filename for file in files}
    missing_libraries = {
        f"lib/{abi}/{library}" for abi in abis for library in REQUIRED_LIBRARIES
    } - paths
    if missing_libraries:
        raise ValueError(f"{apk.name} is missing {', '.join(sorted(missing_libraries))}.")

    sections = Counter()
    for file in files:
        name = file.filename
        if name.startswith("lib/"):
            section = "/".join(name.split("/")[:2])
        elif name.startswith("assets/flutter_assets/"):
            section = "Dart assets"
        elif name.startswith("assets/mlkit-google-ocr-models/"):
            section = "ML Kit models"
        elif name.startswith("classes") and name.endswith(".dex"):
            section = "Android bytecode"
        elif name.startswith("res/") or name == "resources.arsc":
            section = "Android resources"
        else:
            section = "Other entries"
        sections[section] += file.compress_size
    return sections


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("tag")
    parser.add_argument("version_code")
    parser.add_argument("aapt")
    args = parser.parse_args()

    over_budget = []
    print("### Android release APKs (bytes before signing)")
    print()
    print("| APK | Size | Limit | ZIP payload by section |")
    print("| --- | ---: | ---: | --- |")
    for variant, limit in SIZE_LIMITS.items():
        suffix = "" if variant == "universal" else f"-{variant}"
        apk = args.directory / f"lootr-{args.tag}-android{suffix}.apk"
        abis = ABIS if variant == "universal" else {variant}
        sections = describe_apk(apk, abis, args.aapt, args.version_code, args.tag[1:])
        size = apk.stat().st_size
        breakdown = ", ".join(f"{name} {count:,}" for name, count in sections.most_common())
        print(f"| {variant} | {size:,} | {limit:,} | {breakdown} |")
        if size > limit:
            over_budget.append((variant, size - limit))
    for variant, excess in over_budget:
        print(f"::error::{variant} APK exceeds its size limit by {excess:,} bytes.")
    return int(bool(over_budget))


if __name__ == "__main__":
    raise SystemExit(main())
