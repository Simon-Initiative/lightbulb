#!/usr/bin/env bash
set -euo pipefail

ROOT="docs/complete_lti_support/evidence"
OUT="${ROOT}/summary.md"

[[ -d "$ROOT" ]] || {
  echo "evidence root not found: $ROOT" >&2
  exit 1
}

{
  echo "# Evidence Summary"
  echo
  echo "Generated at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo
  echo "## Evidence Index"

  find "$ROOT" -type f -name '*.md' \
    ! -path "$OUT" \
    ! -path "$ROOT/README.md" \
    | sort \
    | while read -r file; do
      rel="${file#${ROOT}/}"
      echo "- ${rel}"
    done
} > "$OUT"

echo "updated ${OUT}"
