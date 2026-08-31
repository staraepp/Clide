#!/bin/bash
set -euo pipefail

# Clide is Apple Silicon only: FluidAudio (Parakeet) uses Float16, which is
# unavailable on x86_64 macOS, so it cannot compile for Intel at all.
#
# ARCHS must be passed on the command line rather than left to project.yml.
# SPM package targets in an Xcode project don't reliably inherit the project's
# ARCHS, so without this FluidAudio still gets built for x86_64 and fails.
# See handoff.md.

cd "$(dirname "$0")/.."
xcodegen generate

xcodebuild \
  -project Clide.xcodeproj \
  -scheme Clide \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  build
