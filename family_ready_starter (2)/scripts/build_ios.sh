#!/usr/bin/env bash
set -euo pipefail

: "${FR_IOS_DIR:?Run the prepare iOS project step first.}"
: "${PROJECT_BUILD_NUMBER:?Use the Codemagic workflow so builds receive unique project numbers.}"
FR_BUILD_KIND="${1:-}"

if [[ "$(uname -s)" != "Darwin" || ! -f "$FR_IOS_DIR/.family_ready_cloud_stage" ]]; then
  echo "Use the supplied Codemagic Mac workflow to build the generated iOS project."
  exit 1
fi
if [[ ! "$PROJECT_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Codemagic's project build number must be numeric."
  exit 1
fi
# The project-wide counter avoids collisions between the two workflows.
FR_BUILD_NUMBER="$((10#$PROJECT_BUILD_NUMBER + 1))"

cd "$FR_IOS_DIR"
case "$FR_BUILD_KIND" in
  unsigned)
    flutter build ios --release --no-codesign --no-pub --build-number="$FR_BUILD_NUMBER"
    echo "Unsigned compile check finished. This artifact cannot be installed on the iPhone."
    ;;
  testflight)
    FR_EXPORT_OPTIONS="$FR_IOS_DIR/export_options.plist"
    xcode-project use-profiles \
      --project="ios/Runner.xcodeproj" \
      --export-options-plist="$FR_EXPORT_OPTIONS" \
      --custom-export-options='{"testFlightInternalTestingOnly":true}'
    if [[ ! -s "$FR_EXPORT_OPTIONS" ]]; then
      echo "No export options were created. Check your Apple signing certificate and matching App Store provisioning profile in Codemagic."
      exit 1
    fi
    flutter build ipa --release --no-pub \
      --build-number="$FR_BUILD_NUMBER" \
      --export-options-plist="$FR_EXPORT_OPTIONS"
    echo "Signed archive finished. The workflow uploads it for manual internal TestFlight setup; no App Store release is requested."
    ;;
  *)
    echo "Usage: build_ios.sh unsigned|testflight"
    exit 1
    ;;
esac
