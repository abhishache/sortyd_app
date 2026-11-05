#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_output_dir=$(mktemp -d "${TMPDIR:-/tmp}/sortyd-crash-tests.XXXXXX")
trap 'rm -rf "$test_output_dir"' EXIT
xcrun swiftc -module-cache-path "$test_output_dir/modules" \
  ios/SortydWidgetExtension/WidgetSharedData.swift \
  ios/Sortyd/Models/Models.swift \
  ios/Sortyd/Utilities/AppLocalization.swift \
  ios/Sortyd/Utilities/CompletionPolicy.swift \
  ios/Sortyd/Utilities/StarterTaskDraft.swift \
  ios/Sortyd/Utilities/ReviewPromptManager.swift \
  tests/CrashRegressionTests.swift -o "$test_output_dir/regressions"
"$test_output_dir/regressions" "$@"
