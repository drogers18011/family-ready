#!/usr/bin/env bash
# Run on the selected Codemagic Mac build machine, not on Windows.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script prepares an iOS build on a Mac. Use Codemagic's iOS workflow."
  exit 1
fi

: "${CM_BUILD_DIR:?Start this script through the supplied Codemagic workflow.}"
: "${CM_ENV:?The Codemagic environment file is unavailable.}"
: "${FR_BUNDLE_ID:?Set FR_BUNDLE_ID in codemagic.yaml.}"

FR_SOURCE_DIR="$(cd "$CM_BUILD_DIR" && pwd -P)"
FR_STAGE_PARENT="$FR_SOURCE_DIR/.cloud_build"
FR_IOS_DIR="$FR_STAGE_PARENT/family_ready"

if [[ ! -f "$FR_SOURCE_DIR/pubspec.yaml" || ! -f "$FR_SOURCE_DIR/lib/main.dart" ]]; then
  echo "Upload the extracted project contents at the repository root, including pubspec.yaml and lib/main.dart."
  exit 1
fi
if [[ -L "$FR_STAGE_PARENT" || -e "$FR_IOS_DIR" || -L "$FR_IOS_DIR" ]]; then
  echo "The generated .cloud_build location already exists or is a link. Start a clean cloud build; do not commit .cloud_build."
  exit 1
fi

mkdir -p "$FR_STAGE_PARENT"
flutter create \
  --platforms=ios \
  --project-name=family_ready \
  --org=com.dennisrogers \
  --empty \
  --no-pub \
  "$FR_IOS_DIR"

# This marker prevents the configuration helper editing an ordinary project.
printf '%s\n' 'Family Ready generated cloud project' > "$FR_IOS_DIR/.family_ready_cloud_stage"
python3 "$FR_SOURCE_DIR/scripts/configure_ios.py" "$FR_SOURCE_DIR" "$FR_IOS_DIR" "$FR_BUNDLE_ID"

cd "$FR_IOS_DIR"
flutter pub get

# Each later Codemagic step receives these paths through CM_ENV.
printf '%s\n' "FR_IOS_DIR=$FR_IOS_DIR" >> "$CM_ENV"
echo "The isolated iOS project is ready. Source files in the repository were not replaced."
