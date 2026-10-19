# Shared settings and helpers. Sourced by every script in this directory.
set -euo pipefail

CLUSTER="${CLUSTER:-cloudops}"
NAMESPACE="${NAMESPACE:-cloudops}"
RELEASE="${RELEASE:-cloudops}"
IMAGE_REPO="${IMAGE_REPO:-cloudops-api}"
BASE_URL="${BASE_URL:-http://localhost:8080}"
DB_USER="${DB_USER:-cloudops}"
DB_NAME="${DB_NAME:-cloudops}"
DB_POD="${RELEASE}-postgres-0"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Git Bash on Windows: stop MSYS rewriting /paths in arguments (they are paths inside pods),
# use C:/style paths that native Windows tools understand, and find winget-installed tools.
if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
  export MSYS_NO_PATHCONV=1
  ROOT="$(cd "$ROOT" && pwd -W)"
  export PATH="$PATH:$(cygpath -u "$LOCALAPPDATA")/Microsoft/WinGet/Links:/c/Program Files/GitHub CLI"
fi
CHART="$ROOT/deploy/helm/cloudops"

PYTHON="$(command -v python3 || command -v python)"
# Run Python, dropping the CR that Windows Python adds to every output line.
py() { "$PYTHON" "$@" | tr -d '\r'; }

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m OK\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; exit 1; }

require() {
  for bin in "$@"; do command -v "$bin" >/dev/null || die "'$bin' not found on PATH"; done
}

# Run psql inside the Postgres pod (local socket auth, no password needed).
psql_pod() {
  local db="$1"; shift
  kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$db" -At "$@"
}
