#!/usr/bin/env bash
set -euo pipefail

: "${FR_IOS_DIR:?Run the prepare iOS project step first.}"
if [[ ! -f "$FR_IOS_DIR/.family_ready_cloud_stage" ]]; then
  echo "The generated iOS project marker is missing. Start a clean cloud build."
  exit 1
fi

cd "$FR_IOS_DIR"
flutter analyze --no-pub
dart test/plan_models_check.dart
dart test/plan_store_check.dart
dart test/personal_packlist_check.dart
dart test/suggested_catalog_check.dart
dart test/guide_store_check.dart
