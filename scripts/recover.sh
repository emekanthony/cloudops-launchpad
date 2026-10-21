#!/usr/bin/env bash
# Detect a failed or unhealthy release and roll back to the last revision that deployed cleanly.
#   scripts/recover.sh            # diagnose; roll back only if something is wrong
#   scripts/recover.sh --force    # roll back to the previous good revision regardless
source "$(dirname "$0")/lib.sh"
require helm kubectl

FORCE=0; [[ "${1:-}" == "--force" ]] && FORCE=1

history_json="$(helm history "$RELEASE" -n "$NAMESPACE" -o json)" \
  || die "release '$RELEASE' not found in namespace '$NAMESPACE'"

read -r CURRENT STATUS < <(printf '%s' "$history_json" | py -c '
import json, sys
h = json.load(sys.stdin)[-1]
print(h["revision"], h["status"])')
log "Release $RELEASE is at revision $CURRENT (status: $STATUS)"

# Health = helm says deployed AND the API Deployment has fully rolled out AND the API answers.
healthy=1
if [[ "$STATUS" != "deployed" ]]; then
  warn "Helm release status is '$STATUS'"; healthy=0
elif ! kubectl rollout status -n "$NAMESPACE" "deploy/$RELEASE-api" --timeout 20s >/dev/null 2>&1; then
  warn "Deployment $RELEASE-api has not finished rolling out"; healthy=0
elif ! curl -fsS -o /dev/null "$BASE_URL/readyz"; then
  warn "API readiness check at $BASE_URL/readyz failed"; healthy=0
fi

if [[ $healthy == 1 && $FORCE == 0 ]]; then
  ok "Release is healthy - nothing to recover"
  exit 0
fi

# Show why pods are unhappy before we change anything (useful in the incident log).
log "Pod state before recovery:"
kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$RELEASE-api" \
  -o custom-columns='POD:.metadata.name,READY:.status.containerStatuses[*].ready,REASON:.status.containerStatuses[*].state.waiting.reason,INIT:.status.initContainerStatuses[*].state.waiting.reason' || true

# Last good revision = newest revision before the current one that reached "deployed"/"superseded".
TARGET="$(printf '%s' "$history_json" | py -c '
import json, sys
current = int(sys.argv[1])
good = [h["revision"] for h in json.load(sys.stdin)
        if h["revision"] < current and h["status"] in ("deployed", "superseded")]
print(good[-1] if good else "")' "$CURRENT")"
[[ -n "$TARGET" ]] || die "no earlier healthy revision to roll back to"

log "Rolling back $RELEASE: revision $CURRENT -> $TARGET"
helm rollback "$RELEASE" "$TARGET" -n "$NAMESPACE" --wait --timeout 3m
kubectl rollout status -n "$NAMESPACE" "deploy/$RELEASE-api" --timeout 120s

"$ROOT/scripts/smoke-test.sh"
ok "Recovered: release $RELEASE now runs the configuration from revision $TARGET"
