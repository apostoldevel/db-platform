#!/bin/bash
#
# migrate.sh — Automatic patch migration for db-platform projects.
#
# Scans platform and configuration patch directories, compares against
# db.patch_log table, and applies only unapplied patches in sorted order.
# After patches, runs platform/update.psql + configuration/update.psql.
#
# Location: sql/platform/migrate.sh
# Usage:    cd db && sql/platform/migrate.sh [OPTIONS]
#
# Options:
#   --baseline    Mark all patches as applied without executing them
#   --dry-run     Show what would be applied, but do nothing
#   --no-update   Skip update.psql after patches (routines/views)
#   --status      Show applied/pending patches and exit
#
# Environment:
#   PSQL          psql command override (default: sudo -u postgres -H psql)
#
# The script expects to be run from the project's db/ directory, where
# sql/sets.psql and sql/.env.psql are accessible.
#

set -e

# ── Paths ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"   # .../sql/platform/
SQL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"        # .../sql/

# ── Connection ────────────────────────────────────────────────────────────────

PSQL="${PSQL:-sudo -u postgres -H psql}"

psql_run() {
  $PSQL "$@"
}

# ── Parse arguments ───────────────────────────────────────────────────────────

BASELINE=false
DRY_RUN=false
NO_UPDATE=false
STATUS_ONLY=false

for arg in "$@"; do
  case $arg in
    --baseline)   BASELINE=true ;;
    --dry-run)    DRY_RUN=true ;;
    --no-update)  NO_UPDATE=true ;;
    --status)     STATUS_ONLY=true ;;
    --help|-h)
      sed -n '2,/^$/{ s/^# \?//; p }' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      exit 1
      ;;
  esac
done

# ── Determine dbname from sets.psql ──────────────────────────────────────────

DB_NAME=$(grep -oP '\\set dbname \K\w+' "$SQL_DIR/sets.psql" 2>/dev/null || true)

if [[ -z "$DB_NAME" ]]; then
  echo "ERROR: Cannot determine dbname from $SQL_DIR/sets.psql"
  exit 1
fi

# ── Ensure db.patch_log table exists ─────────────────────────────────────────

psql_run -d "$DB_NAME" -v ON_ERROR_STOP=1 -q <<'EOSQL'
CREATE TABLE IF NOT EXISTS db.patch_log (
  name        text PRIMARY KEY,
  applied_at  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE db.patch_log IS 'Applied database patches (migration tracking).';
EOSQL

# ── Load applied patches into associative array ──────────────────────────────

declare -A APPLIED_MAP

while IFS= read -r line; do
  [[ -n "$line" ]] && APPLIED_MAP["$line"]=1
done < <(psql_run -d "$DB_NAME" -t -A -c "SELECT name FROM db.patch_log ORDER BY name")

is_applied() {
  [[ -v APPLIED_MAP["$1"] ]]
}

# ── Collect patches ──────────────────────────────────────────────────────────
# Each entry: "sort_key|patch_name|patch_rel"
#   sort_key   — for ordering (0-platform, 1-config)
#   patch_name — unique identifier stored in patch_log
#   patch_rel  — file path relative to SQL_DIR

PATCHES=()

# Platform patches: sql/platform/patch/v*/*.sql
for version_dir in $(find "$SQL_DIR/platform/patch" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort); do
  ver=$(basename "$version_dir")
  for f in $(find "$version_dir" -maxdepth 1 -name 'P*.sql' 2>/dev/null | sort); do
    name=$(basename "$f" .sql)
    PATCHES+=("0-$ver-$name|platform/$ver/$name|platform/patch/$ver/$name.sql")
  done
done

# Configuration patches: sql/configuration/*/patch/P*.{psql,sql}
for patch_dir in $(find "$SQL_DIR/configuration" -path '*/patch' -type d 2>/dev/null | sort); do
  cfg_name=$(basename "$(dirname "$patch_dir")")
  for f in $(find "$patch_dir" -maxdepth 1 \( -name 'P*.psql' -o -name 'P*.sql' \) 2>/dev/null | sort); do
    ext="${f##*.}"
    name=$(basename "$f" ".$ext")
    rel="${f#"$SQL_DIR/"}"
    PATCHES+=("1-$cfg_name-$name|config/$cfg_name/$name|$rel")
  done
done

# ── Status mode ──────────────────────────────────────────────────────────────

if $STATUS_ONLY; then
  echo
  echo "Database: $DB_NAME"
  echo "Applied patches: ${#APPLIED_MAP[@]}"
  echo
  pending=0
  for entry in "${PATCHES[@]}"; do
    IFS='|' read -r _ patch_name patch_rel <<< "$entry"
    if is_applied "$patch_name"; then
      echo "  [x] $patch_name"
    else
      echo "  [ ] $patch_name  ($patch_rel)"
      pending=$((pending + 1))
    fi
  done
  echo
  echo "Pending: $pending"
  exit 0
fi

# ── Apply patches ────────────────────────────────────────────────────────────

echo
echo "============================================"
echo " Patch migration — $DB_NAME"
echo " $(date -Iseconds)"
echo "============================================"
echo

TOTAL=${#PATCHES[@]}
APPLIED_COUNT=0
SKIPPED=0

for entry in "${PATCHES[@]}"; do
  IFS='|' read -r _ patch_name patch_rel <<< "$entry"

  if is_applied "$patch_name"; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if $DRY_RUN; then
    echo "  WOULD APPLY: $patch_name  ($patch_rel)"
    APPLIED_COUNT=$((APPLIED_COUNT + 1))
    continue
  fi

  if $BASELINE; then
    echo "  BASELINE: $patch_name"
    psql_run -d "$DB_NAME" -v ON_ERROR_STOP=1 -q \
      -c "INSERT INTO db.patch_log (name) VALUES ('$patch_name') ON CONFLICT DO NOTHING"
    APPLIED_COUNT=$((APPLIED_COUNT + 1))
    continue
  fi

  echo "  APPLY: $patch_name ..."

  # Create a wrapper .psql in sql/ dir so \ir relative paths resolve correctly.
  # The wrapper sets up psql variables (sets.psql) and connects as kernel,
  # then includes the actual patch file.
  local_wrapper="$SQL_DIR/.migrate_run.psql"
  cat > "$local_wrapper" <<WRAPPER
\\ir sets.psql
\\connect :dbname kernel
\\ir sets.psql
\\ir $patch_rel
WRAPPER

  if psql_run -d template1 -v ON_ERROR_STOP=1 -f "$local_wrapper" 2>&1; then
    psql_run -d "$DB_NAME" -v ON_ERROR_STOP=1 -q \
      -c "INSERT INTO db.patch_log (name) VALUES ('$patch_name') ON CONFLICT DO NOTHING"
    echo "  OK: $patch_name"
    APPLIED_COUNT=$((APPLIED_COUNT + 1))
  else
    rm -f "$local_wrapper"
    echo
    echo "  FAILED: $patch_name"
    echo "  Migration stopped. Fix the issue and re-run."
    exit 1
  fi

  rm -f "$local_wrapper"
done

echo
echo "  Total: $TOTAL  Applied: $APPLIED_COUNT  Skipped: $SKIPPED"

# ── Run update.psql (routines/views) ─────────────────────────────────────────

if ! $NO_UPDATE && ! $DRY_RUN && [[ $APPLIED_COUNT -gt 0 ]]; then
  echo
  echo "--- Running update (routines/views) ---"

  update_wrapper="$SQL_DIR/.migrate_update.psql"
  cat > "$update_wrapper" <<WRAPPER
\\ir sets.psql
\\connect :dbname kernel
\\ir sets.psql
\\ir './platform/update.psql'
\\ir './configuration/update.psql'
WRAPPER

  psql_run -d template1 -v ON_ERROR_STOP=1 -f "$update_wrapper" 2>&1
  rm -f "$update_wrapper"

  echo "  Update complete."
fi

echo
echo "============================================"
echo " Migration complete"
echo "============================================"
echo
