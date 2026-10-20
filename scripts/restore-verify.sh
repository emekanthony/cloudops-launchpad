#!/usr/bin/env bash
# Prove a backup is restorable: restore it into a scratch database, compare per-table row
# counts and checksums against the manifest captured at backup time, then drop the scratch DB.
#   scripts/restore-verify.sh                          # newest dump in ./backups
#   scripts/restore-verify.sh backups/cloudops-X.dump  # a specific dump
source "$(dirname "$0")/lib.sh"
require kubectl diff

DUMP="${1:-$(ls -1t "$ROOT"/backups/*.dump 2>/dev/null | head -1)}"
[[ -f "$DUMP" ]] || die "no dump found (run scripts/backup.sh first)"
VERIFY_DB="verify_restore"

if [[ -f "$DUMP.manifest" ]]; then
  EXPECTED="$(cat "$DUMP.manifest")"
  source_desc="manifest recorded at backup time"
else
  warn "No manifest next to $DUMP - comparing against the live database instead"
  EXPECTED="$("$ROOT/scripts/db-checksums.sh" "$DB_NAME")"
  source_desc="live database"
fi

cleanup() { psql_pod postgres -c "DROP DATABASE IF EXISTS $VERIFY_DB" >/dev/null 2>&1 || true; }
trap cleanup EXIT

log "Restoring $(basename "$DUMP") into scratch database '$VERIFY_DB'"
cleanup
psql_pod postgres -c "CREATE DATABASE $VERIFY_DB" >/dev/null
kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- \
  pg_restore -U "$DB_USER" -d "$VERIFY_DB" --no-owner --exit-on-error < "$DUMP"

log "Comparing restored tables against the $source_desc"
ACTUAL="$("$ROOT/scripts/db-checksums.sh" "$VERIFY_DB")"
printf '%-22s %8s  %s\n' TABLE ROWS MD5
printf '%s\n' "$ACTUAL" | while read -r t n sum; do printf '%-22s %8s  %s\n' "$t" "$n" "$sum"; done

if diff <(printf '%s\n' "$EXPECTED") <(printf '%s\n' "$ACTUAL") >/dev/null; then
  ok "RESTORE VERIFIED: PASS - $(printf '%s\n' "$ACTUAL" | wc -l | tr -d ' ') tables match"
else
  warn "Differences (expected vs restored):"
  diff <(printf '%s\n' "$EXPECTED") <(printf '%s\n' "$ACTUAL") || true
  die "RESTORE VERIFIED: FAIL"
fi
