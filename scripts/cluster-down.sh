#!/usr/bin/env bash
# Delete the kind cluster (and every PVC inside it). Local backups in ./backups are kept.
source "$(dirname "$0")/lib.sh"
require kind
log "Deleting kind cluster '$CLUSTER'"
kind delete cluster --name "$CLUSTER"
