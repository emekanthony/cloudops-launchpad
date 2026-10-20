#!/usr/bin/env bash
# Print "<table> <row_count> <md5>" for every table in the public schema of a database.
# The md5 covers every row's full text in a stable order, so any changed value shows up.
#   scripts/db-checksums.sh cloudops
source "$(dirname "$0")/lib.sh"
DB="${1:-$DB_NAME}"

tables="$(psql_pod "$DB" -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY 1")"
for t in $tables; do
  psql_pod "$DB" -F ' ' -c \
    "SELECT '$t', count(*), coalesce(md5(string_agg(x::text, '|' ORDER BY x::text)), '-') FROM public.\"$t\" x"
done
