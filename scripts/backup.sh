#!/usr/bin/env bash
# Back up the database.
#   scripts/backup.sh               # stream pg_dump to ./backups/<timestamp>.dump (+ manifest)
#   scripts/backup.sh --in-cluster  # trigger the backup CronJob now and wait for it
source "$(dirname "$0")/lib.sh"
require kubectl

if [[ "${1:-}" == "--in-cluster" ]]; then
  job="manual-backup-$(date +%s)"
  log "Starting job $job from cronjob/$RELEASE-backup"
  kubectl create job -n "$NAMESPACE" --from="cronjob/$RELEASE-backup" "$job"
  kubectl wait -n "$NAMESPACE" --for=condition=complete "job/$job" --timeout 120s
  kubectl logs -n "$NAMESPACE" "job/$job"
  ok "In-cluster backup complete (stored on PVC backups-$DB_POD)"
  exit 0
fi

mkdir -p "$ROOT/backups"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
dump="$ROOT/backups/cloudops-$stamp.dump"

# Record row counts + checksums alongside the dump so restore-verify.sh can prove the
# restored copy matches what was backed up (not whatever the live DB holds later).
log "Writing manifest of table checksums"
"$ROOT/scripts/db-checksums.sh" "$DB_NAME" > "$dump.manifest"

log "Running pg_dump -> $(basename "$dump")"
kubectl exec -n "$NAMESPACE" "$DB_POD" -- pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc > "$dump.partial"
mv "$dump.partial" "$dump"

# A dump that pg_restore can't list is not a backup.
kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- pg_restore --list < "$dump" > /dev/null \
  || die "pg_restore cannot read $dump"

ok "Backup written: backups/$(basename "$dump") ($(du -h "$dump" | cut -f1))"
cat "$dump.manifest"
