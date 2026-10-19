#!/usr/bin/env bash
# Create the kind cluster and install the monitoring stack. Safe to re-run.
#   SKIP_MONITORING=1 scripts/cluster-up.sh   # app only (used in CI)
source "$(dirname "$0")/lib.sh"
require docker kind kubectl helm

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  log "kind cluster '$CLUSTER' already exists"
else
  log "Creating kind cluster '$CLUSTER'"
  kind create cluster --config "$ROOT/deploy/kind-config.yaml" --wait 120s
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

if [[ "${SKIP_MONITORING:-0}" != 1 ]]; then
  log "Installing kube-prometheus-stack (first run downloads ~1 GB of images)"
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update prometheus-community >/dev/null
  helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace \
    -f "$ROOT/deploy/monitoring/values.yaml" \
    --wait --timeout 10m
  ok "Grafana:    http://localhost:3000  (admin / cloudops)"
  ok "Prometheus: http://localhost:9090"
fi
ok "Cluster ready: $(kubectl get nodes --no-headers | wc -l) node(s)"
