#!/usr/bin/env python3
"""Copy Black Box into a newly generated, isolated iOS shell.

The helper does not execute Flutter, contact services, or handle credentials.
It only edits the staging project made by prepare_ios.sh.
"""

import plistlib
import re
import shutil
import sys
from pathlib import Path


def configure(source: Path, stage: Path, bundle_id: str) -> None:
    source = source.resolve()
    stage = stage.resolve()
    expected = source / ".cloud_build" / "family_ready"
    if stage != expected or not (stage / ".family_ready_cloud_stage").is_file():
        raise ValueError("Refusing to modify a folder that is not the generated cloud project.")
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle_id):
        raise ValueError("FR_BUNDLE_ID must be a reverse-domain identifier without spaces or underscores.")
    if bundle_id.startswith("com.example."):
        raise ValueError("Choose your proposed app identifier instead of com.example.")

    # Remove only generated sample code/tests; copy the actual project code.
    for name in ("lib", "test"):
        target = stage / name
        if target.exists():
            shutil.rmtree(target)
        original = source / name
        if original.is_dir():
            shutil.copytree(original, target)

    shutil.copy2(source / "pubspec.yaml", stage / "pubspec.yaml")
    # A generated Flutter lint file refers to a template-only dev dependency.
    # Keep the source project's own analyzer configuration if it has one.
    for name in ("analysis_options.yaml", "pubspec.lock", "l10n.yaml"):
        original = source / name
        target = stage / name
        if original.is_file():
            shutil.copy2(original, target)
        elif target.exists():
            target.unlink()
    for name in ("assets", "fonts"):
        original = source / name
        if original.is_dir():
            shutil.copytree(original, stage / name, dirs_exist_ok=True)

    project = stage / "ios" / "Runner.xcodeproj" / "project.pbxproj"
    text = project.read_text(encoding="utf-8")

    def replace_identifier(match: re.Match) -> str:
        original = match.group(1).strip('"')
        suffix = ".RunnerTests" if original.endswith(".RunnerTests") else ""
        return f"PRODUCT_BUNDLE_IDENTIFIER = {bundle_id}{suffix};"

    text, count = re.subn(
        r"PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);",
        replace_identifier,
        text,
    )
    if count < 3:
        raise ValueError("The generated Xcode template changed: expected Runner build identifiers were not found.")
    project.write_text(text, encoding="utf-8")

    plist_path = stage / "ios" / "Runner" / "Info.plist"
    with plist_path.open("rb") as handle:
        info = plistlib.load(handle)
    info["CFBundleDisplayName"] = "Black Box"
    info["CFBundleName"] = "Black Box"
    # Do not invent privacy or export-compliance declarations. Review any
    # App Store Connect questions against the actual app and SDK behavior.
    with plist_path.open("wb") as handle:
        plistlib.dump(info, handle, sort_keys=False)

    icon_set = stage / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    if not (icon_set / "Icon-App-1024x1024@1x.png").is_file():
        raise ValueError("The generated iOS app icon is missing. Review the Flutter template before uploading a build.")
    print(f"Configured Black Box with bundle identifier {bundle_id}.")
    print("The initial native build keeps Flutter's generated starter icons.")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("Usage: configure_ios.py SOURCE_DIR STAGE_DIR BUNDLE_ID")
    try:
        configure(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3])
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        raise SystemExit(f"iOS project setup failed: {error}") from error
