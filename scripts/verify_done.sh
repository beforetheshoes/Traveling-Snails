#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "== Running compliance_audit.sh =="
bash "$ROOT_DIR/scripts/compliance_audit.sh"

echo
echo "== Running broad done checks =="

count_store_initial_state="$(rg -n 'Store\(initialState:' 'Traveling Snails' || true)"
count_store_initial_state="$(printf '%s\n' "$count_store_initial_state" | sed '/^$/d' | wc -l | tr -d ' ')"

count_unsafe_concurrency="$(rg -n '@unchecked Sendable|nonisolated\(unsafe\)' 'Traveling Snails' || true)"
count_unsafe_concurrency="$(printf '%s\n' "$count_unsafe_concurrency" | sed '/^$/d' | wc -l | tr -d ' ')"

count_legacy_patterns="$(rg -n 'localizedCaseInsensitiveContains\(|String\(format:|AnyView\(' 'Traveling Snails' || true)"
count_legacy_patterns="$(printf '%s\n' "$count_legacy_patterns" | sed '/^$/d' | wc -l | tr -d ' ')"

count_broad_fetchall="$(rg -n '@FetchAll private var allAttachments|@FetchAll private var trips:|@FetchAll private var transportation:|@FetchAll private var organizations:|@FetchAll private var allTrips:|@FetchAll private var allTransportation:' 'Traveling Snails/Views' || true)"
count_broad_fetchall="$(printf '%s\n' "$count_broad_fetchall" | sed '/^$/d' | wc -l | tr -d ' ')"

echo "Store(initialState): $count_store_initial_state"
echo "Unsafe concurrency markers: $count_unsafe_concurrency"
echo "Legacy search/format/type-erasure patterns: $count_legacy_patterns"
echo "Broad FetchAll patterns: $count_broad_fetchall"

total=$((count_store_initial_state + count_unsafe_concurrency + count_legacy_patterns + count_broad_fetchall))

echo
if [[ "$total" -eq 0 ]]; then
  echo "✅ DONE: zero remaining issues across all agreed gates."
  exit 0
else
  echo "❌ NOT DONE: $total remaining issue hits."
  exit 1
fi
