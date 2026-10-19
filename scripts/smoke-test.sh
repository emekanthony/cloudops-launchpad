#!/usr/bin/env bash
# End-to-end check against a running API: health, readiness, and a CRUD round trip.
#   BASE_URL=http://localhost:8000 scripts/smoke-test.sh
source "$(dirname "$0")/lib.sh"
require curl

BODY=""
check() {  # check <name> <expected-status> <curl args...>; response body lands in $BODY
  local name="$1" want="$2" out got; shift 2
  out="$(curl -s -w '\n%{http_code}' "$@")" || out=$'\n000'
  got="${out##*$'\n'}"
  BODY="${out%$'\n'*}"
  [[ "$got" == "$want" ]] || die "$name: expected HTTP $want, got $got: $BODY"
  ok "$name ($got)"
}
json_field() { printf '%s' "$BODY" | py -c "import json,sys;print(json.load(sys.stdin)['$1'])"; }

log "Smoke testing $BASE_URL"
for _ in $(seq 1 30); do
  [[ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/readyz")" == 200 ]] && break
  sleep 2
done

check "liveness  /healthz" 200 "$BASE_URL/healthz"
check "readiness /readyz"  200 "$BASE_URL/readyz"

check "create equipment" 201 -X POST "$BASE_URL/equipment" -H 'content-type: application/json' \
  -d '{"name":"smoke-test-pump","type":"pump","location":"smoke"}'
ID="$(json_field id)"

check "add maintenance record" 201 -X POST "$BASE_URL/equipment/$ID/maintenance" \
  -H 'content-type: application/json' \
  -d '{"performed_at":"2026-01-01","technician":"smoke","next_due":"2026-02-01"}'
check "overdue check" 200 "$BASE_URL/equipment/$ID/overdue"
[[ "$(json_field overdue)" == "True" ]] || die "expected equipment $ID to be overdue"

check "delete equipment" 204 -X DELETE "$BASE_URL/equipment/$ID"
check "deleted is gone"  404 "$BASE_URL/equipment/$ID"
check "metrics endpoint" 200 "$BASE_URL/metrics"

ok "Smoke test passed"
