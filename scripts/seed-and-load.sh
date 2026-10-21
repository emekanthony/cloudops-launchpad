#!/usr/bin/env bash
# Seed demo data, then generate traffic (including some 404s) so Grafana has something to show.
#   scripts/seed-and-load.sh            # seed + 60s of load
#   DURATION=300 scripts/seed-and-load.sh
#   SEED_ONLY=1 scripts/seed-and-load.sh
source "$(dirname "$0")/lib.sh"
require curl

post() { curl -fsS -o /dev/null -X POST "$BASE_URL$1" -H 'content-type: application/json' -d "$2"; }

log "Seeding equipment and maintenance history at $BASE_URL"
i=0
for spec in "Hydraulic Press|press|Plant 1" "Air Compressor|compressor|Plant 1" \
            "Forklift 07|forklift|Warehouse" "CNC Mill|cnc|Plant 2" "Conveyor B|conveyor|Plant 2"; do
  IFS='|' read -r name type loc <<< "$spec"
  id="$(curl -fsS -X POST "$BASE_URL/equipment" -H 'content-type: application/json' \
        -d "{\"name\":\"$name\",\"type\":\"$type\",\"location\":\"$loc\"}" \
        | py -c 'import json,sys;print(json.load(sys.stdin)["id"])')"
  i=$((i + 1))
  post "/equipment/$id/maintenance" \
    "{\"performed_at\":\"2026-0$i-15\",\"technician\":\"tech-$i\",\"notes\":\"routine service\",\"next_due\":\"2026-1$((i % 3))-01\"}"
done
ok "Seeded 5 equipment records"
[[ "${SEED_ONLY:-0}" == 1 ]] && exit 0

DURATION="${DURATION:-60}"
log "Generating load for ${DURATION}s"
end=$((SECONDS + DURATION)); n=0
while (( SECONDS < end )); do
  curl -s -o /dev/null "$BASE_URL/equipment"
  curl -s -o /dev/null "$BASE_URL/equipment/1/overdue"
  curl -s -o /dev/null "$BASE_URL/equipment/$((RANDOM % 20))"   # some of these 404
  n=$((n + 3))
done
ok "Sent $n requests"
