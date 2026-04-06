#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OPEN_COUNT=0

print_heading() {
  echo
  echo "== $1 =="
}

run_pattern_check() {
  local id="$1"
  local desc="$2"
  local cmd="$3"

  print_heading "$id: $desc"
  local output
  output=$(eval "$cmd" || true)
  if [[ -n "$output" ]]; then
    echo "$output"
    local count
    count=$(printf '%s\n' "$output" | wc -l | tr -d ' ')
    OPEN_COUNT=$((OPEN_COUNT + count))
    echo "OPEN: $count"
  else
    echo "PASS"
  fi
}

run_structural_check() {
  local id="$1"
  local desc="$2"
  local check_cmd="$3"
  print_heading "$id: $desc"
  if eval "$check_cmd"; then
    echo "PASS"
  else
    OPEN_COUNT=$((OPEN_COUNT + 1))
    echo "OPEN: 1"
  fi
}

run_pattern_check "ZKI-C01" "Detached tasks in app-owned views" \
  "rg -n 'Task\\.detached' 'Traveling Snails/Views'"

run_pattern_check "ZKI-C02" "Production fallback store construction in views" \
  "rg -n 'store \\?\\? Store\\(' 'Traveling Snails/Views'"

run_structural_check "ZKI-C03" "AppFeature.State equality compares child feature states" \
  "rg -n 'lhs\\.trips\\.trips\\.map\\(\\\\\\.id\\) == rhs\\.trips\\.trips\\.map\\(\\\\\\.id\\)' 'Traveling Snails/Features/AppFeature.swift' >/dev/null && \
   rg -n 'lhs\\.organizations\\.organizations\\.map\\(\\\\\\.id\\) == rhs\\.organizations\\.organizations\\.map\\(\\\\\\.id\\)' 'Traveling Snails/Features/AppFeature.swift' >/dev/null && \
   rg -n 'settingsEqual' 'Traveling Snails/Features/AppFeature.swift' >/dev/null"

run_pattern_check "ZKI-C04" "Unscoped all-attachments fetch in TripActivityDetailView" \
  "rg -n '@FetchAll private var allAttachments' 'Traveling Snails/Views/Activities/TripActivityDetailView.swift'"

run_pattern_check "ZKI-C05" "Snapshot-owned organization in OrganizationFeature" \
  "rg -n '^\\s*let organization: Organization' 'Traveling Snails/Features/OrganizationFeature.swift'"

run_pattern_check "ZKI-C06" "Snapshot-owned trip in TripDetailFeature" \
  "rg -n '^\\s*let trip: Trip' 'Traveling Snails/Features/TripDetailFeature.swift'"

run_pattern_check "ZKI-C07" "Legacy tabItem API usage" \
  "rg -n '\\.tabItem\\s*\\{' 'Traveling Snails'"

run_pattern_check "ZKI-C08" "Legacy foregroundColor usage" \
  "rg -n '\\.foregroundColor\\(' 'Traveling Snails'"

run_pattern_check "ZKI-C09" "Legacy cornerRadius usage" \
  "rg -n '\\.cornerRadius\\(' 'Traveling Snails'"

run_pattern_check "ZKI-C10" "AnyView usage in hot-path targets" \
  "rg -n 'AnyView\\(' 'Traveling Snails/Views/Navigation/EntityNavigationView.swift' 'Traveling Snails/Views/Components/ActivityForm/ActivityFormField.swift'"

echo
if [[ "$OPEN_COUNT" -eq 0 ]]; then
  echo "✅ Compliance audit PASS: zero open findings detected by automated checks."
else
  echo "❌ Compliance audit FAIL: $OPEN_COUNT open findings detected."
  exit 1
fi
