#!/bin/sh

# Xcode Cloud doesn't automatically trust Swift macro targets from
# third-party packages. This script applies the default settings to
# allow them, matching what happens when you click "Trust & Enable"
# in Xcode locally.

defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

# Use the build number from the Xcode project instead of Xcode Cloud's
# auto-incrementing counter, so TestFlight builds match what's in the repo.
cd "$CI_PRIMARY_REPOSITORY_PATH"
BUILD_NUMBER=$(xcrun agvtool what-version -terse)
echo "Setting Xcode Cloud build number to project value: $BUILD_NUMBER"
agvtool new-version -all "$BUILD_NUMBER"
