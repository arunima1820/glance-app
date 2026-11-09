#!/bin/bash
# Loads a test data file into the Glance app on the booted simulator, replacing every list and
# food there. Debug builds only (the loader isn't compiled into Release). Nothing here ships.
#
#   ./scripts/load-test-data.sh                 # TestData/sample-data.json
#   ./scripts/load-test-data.sh empty.json      # wipe everything
#
# Build and run the app on a simulator once first (so it's installed).
set -euo pipefail
cd "$(dirname "$0")/.."
DATA="$(pwd)/TestData/${1:-sample-data.json}"
BUNDLE="com.ruminate.glance"

[ -f "$DATA" ] || { echo "No test data at $DATA"; exit 1; }
xcrun simctl terminate booted "$BUNDLE" 2>/dev/null || true
SIMCTL_CHILD_GLANCE_TEST_DATA="$DATA" xcrun simctl launch booted "$BUNDLE"
echo "Loaded $(basename "$DATA") into the simulator app."
