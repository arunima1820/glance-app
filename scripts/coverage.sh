#!/bin/bash
# coverage.sh: run the full test suite with code coverage on, then summarize it.
# Writes ../_lasttest.log (full log), ../_coverage.json (per-file data Claude reads),
# and prints a per-area summary with pass/fail against the coverage targets.
set -uo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

SIM=$(xcrun simctl list devices available | grep -m1 -oE 'iPhone [0-9]+( Pro( Max)?| Plus)?')
UDID=$(xcrun simctl list devices available | grep -m1 "$SIM (" | grep -oE '[0-9A-F-]{36}')
RESULT="/tmp/glance-coverage-$(date +%s).xcresult"   # fresh path each run (xcodebuild won't overwrite)

xcodebuild test -scheme Glance -destination "platform=iOS Simulator,id=$UDID" \
  -enableCodeCoverage YES -resultBundlePath "$RESULT" > /tmp/glance-test.log 2>&1
STATUS=$?
cp /tmp/glance-test.log ../_lasttest.log
tail -n 3 /tmp/glance-test.log
[ $STATUS -ne 0 ] && { echo "Tests failed; coverage not summarized."; exit $STATUS; }

xcrun xccov view --report --json "$RESULT" > ../_coverage.json
/usr/bin/python3 scripts/coverage_summary.py ../_coverage.json
