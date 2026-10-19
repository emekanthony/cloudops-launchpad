#!/usr/bin/env bash
# Build the API image, load it into kind, and roll it out with Helm.
# A failed rollout is rolled back automatically (--rollback-on-failure).
#   scripts/deploy.sh            # tag = short git sha (or timestamp)
#   scripts/deploy.sh v1.2.0     # explicit tag
#   NO_BUILD=1 scripts/deploy.sh <tag>   # skip the build; deploy an image already in docker
source "$(dirname "$0")/lib.sh"
require docker kind helm kubectl

TAG="${1:-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"
IMAGE="$IMAGE_REPO:$TAG"

if [[ "${NO_BUILD:-0}" != 1 ]]; then
  log "Building $IMAGE"
  docker build -t "$IMAGE" --build-arg APP_VERSION="$TAG" "$ROOT"
fi
log "Loading $IMAGE into kind cluster '$CLUSTER'"
kind load docker-image "$IMAGE" --name "$CLUSTER"

log "Helm upgrade: release=$RELEASE tag=$TAG"
helm upgrade --install "$RELEASE" "$CHART" \
  --namespace "$NAMESPACE" --create-namespace \
  --set image.tag="$TAG" \
  --rollback-on-failure --wait --timeout "${HELM_TIMEOUT:-4m}" \
  "${@:2}"

kubectl rollout status -n "$NAMESPACE" "deploy/$RELEASE-api" --timeout 60s
"$ROOT/scripts/smoke-test.sh"
ok "Deployed $IMAGE (helm revision $(helm history "$RELEASE" -n "$NAMESPACE" --max 1 -o json | py -c 'import json,sys;print(json.load(sys.stdin)[-1]["revision"])'))"
