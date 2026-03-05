#!/usr/bin/env bash
set -euo pipefail

MATRIX_PATH="${1:-docs/complete_lti_support/conformance_matrix.md}"
EPIC_PATH="docs/complete_lti_support/epic_prd.md"

required_columns=(
  "requirement_id"
  "spec_reference"
  "cert_reference"
  "feature_slug"
  "implementation_refs"
  "test_refs"
  "status"
  "owner"
  "last_verified_date"
  "evidence_refs"
)

allowed_statuses=("not_started" "in_progress" "implemented" "verified")
allowed_feature_slugs=("core" "deep_linking" "ags" "nrps" "oauth_provider" "certification")

trim() {
  local value="$1"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  printf '%s' "$value"
}

contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

fail() {
  echo "matrix lint failed: $1" >&2
  exit 1
}

extract_cells() {
  local line="$1"
  local -n out_ref=$2
  out_ref=()

  local trimmed_line
  trimmed_line="$(trim "$line")"
  [[ -z "$trimmed_line" ]] && return
  [[ "${trimmed_line:0:1}" != "|" ]] && return

  local content="${trimmed_line#|}"
  content="${content%|}"

  local IFS='|'
  local parts=()
  read -r -a parts <<< "$content"

  local part
  for part in "${parts[@]}"; do
    out_ref+=("$(trim "$part")")
  done
}

validate_ref_list() {
  local label="$1"
  local refs="$2"

  local IFS=';'
  local entries=()
  read -r -a entries <<< "$refs"

  local entry
  for entry in "${entries[@]}"; do
    local ref
    ref="$(trim "$entry")"
    [[ -z "$ref" || "$ref" == "-" ]] && continue

    local path="$ref"
    path="${path%%::*}"
    path="${path%%#*}"
    path="${path%%:*}"

    if [[ ! -e "$path" ]]; then
      fail "missing path in ${label}: ${path} (from '${ref}')"
    fi
  done
}

[[ -f "$MATRIX_PATH" ]] || fail "matrix file not found: $MATRIX_PATH"
[[ -f "$EPIC_PATH" ]] || fail "epic requirements file not found: $EPIC_PATH"

header_line_number="$(grep -n '^| requirement_id |' "$MATRIX_PATH" | head -n 1 | cut -d: -f1)"
[[ -n "$header_line_number" ]] || fail "table header starting with 'requirement_id' not found"

header_line="$(sed -n "${header_line_number}p" "$MATRIX_PATH")"
separator_line="$(sed -n "$((header_line_number + 1))p" "$MATRIX_PATH")"

[[ "$separator_line" =~ ^\|[[:space:]-]+\| ]] || fail "table separator row missing after header"

header_cells=()
extract_cells "$header_line" header_cells

for col in "${required_columns[@]}"; do
  contains "$col" "${header_cells[@]}" || fail "required column missing: $col"
done

get_column_index() {
  local col_name="$1"
  local idx=0
  for cell in "${header_cells[@]}"; do
    if [[ "$cell" == "$col_name" ]]; then
      echo "$idx"
      return
    fi
    idx=$((idx + 1))
  done
  fail "column index lookup failed for: $col_name"
}

requirement_idx="$(get_column_index "requirement_id")"
feature_slug_idx="$(get_column_index "feature_slug")"
implementation_refs_idx="$(get_column_index "implementation_refs")"
test_refs_idx="$(get_column_index "test_refs")"
status_idx="$(get_column_index "status")"
last_verified_date_idx="$(get_column_index "last_verified_date")"
evidence_refs_idx="$(get_column_index "evidence_refs")"

seen_requirements=()
row_count=0

line_no=$((header_line_number + 2))
while true; do
  line="$(sed -n "${line_no}p" "$MATRIX_PATH")"
  [[ -z "$line" ]] && break

  if [[ ! "$line" =~ ^\| ]]; then
    line_no=$((line_no + 1))
    continue
  fi

  cells=()
  extract_cells "$line" cells
  [[ "${#cells[@]}" -lt "${#header_cells[@]}" ]] && fail "row has fewer cells than header at line ${line_no}"

  requirement_id="${cells[$requirement_idx]}"
  feature_slug="${cells[$feature_slug_idx]}"
  implementation_refs="${cells[$implementation_refs_idx]}"
  test_refs="${cells[$test_refs_idx]}"
  status="${cells[$status_idx]}"
  last_verified_date="${cells[$last_verified_date_idx]}"
  evidence_refs="${cells[$evidence_refs_idx]}"

  [[ -n "$requirement_id" ]] || fail "empty requirement_id at line ${line_no}"
  contains "$feature_slug" "${allowed_feature_slugs[@]}" || fail "invalid feature_slug '${feature_slug}' at line ${line_no}"
  contains "$status" "${allowed_statuses[@]}" || fail "invalid status '${status}' at line ${line_no}"

  if [[ "$status" == "verified" ]]; then
    [[ "$last_verified_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail "verified row missing ISO date at line ${line_no}"
  fi

  validate_ref_list "implementation_refs" "$implementation_refs"
  validate_ref_list "test_refs" "$test_refs"
  validate_ref_list "evidence_refs" "$evidence_refs"

  seen_requirements+=("$requirement_id")
  row_count=$((row_count + 1))
  line_no=$((line_no + 1))
done

[[ "$row_count" -gt 0 ]] || fail "no matrix rows found"

mapfile -t epic_requirements < <(grep -E '^### (FR|NFR)-' "$EPIC_PATH" | awk '{print $2}')
[[ "${#epic_requirements[@]}" -gt 0 ]] || fail "no FR/NFR requirement headers found in epic PRD"

for req in "${epic_requirements[@]}"; do
  if ! printf '%s\n' "${seen_requirements[@]}" | grep -Fxq "$req"; then
    fail "missing matrix row for requirement '${req}'"
  fi
done

echo "matrix lint passed: ${MATRIX_PATH}"
