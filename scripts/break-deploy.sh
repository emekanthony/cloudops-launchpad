#!/usr/bin/env bash
# Simulate a bad release for the recovery drill: deploy an image tag that doesn't exist,
# WITHOUT automatic rollback, so the release is left in a failed state.
# Thanks to maxUnavailable=0 the old pods keep serving traffic while the new ones fail.
#   scripts/break-deploy.sh && scripts/recover.sh
source "$(dirname "$0")/lib.sh"
require helm kubectl

BAD_TAG="${1:-broken}"
log "Deploying bad image tag '$BAD_TAG' (expected to fail)"
if helm upgrade "$RELEASE" "$CHART" -n "$NAMESPACE" --reuse-values \
     --set image.tag="$BAD_TAG" --wait --timeout "${HELM_TIMEOUT:-60s}"; then
  die "bad deploy unexpectedly succeeded"
fi

warn "Release is now failed:"
helm history "$RELEASE" -n "$NAMESPACE" --max 3
kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$RELEASE-api"
if curl -fsS -o /dev/null "$BASE_URL/readyz"; then
  ok "Old pods are still serving traffic during the failed rollout"
fi
