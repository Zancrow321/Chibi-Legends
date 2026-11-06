#!/usr/bin/env bash
# Runs the migration twice (must be repeatable) and the test on a throwaway
# local Postgres 16. Needs the postgresql-16 binaries (CI: apt install).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
bin="${PG_BIN:-$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1)}"
dir="$(mktemp -d)"
chown postgres "$dir" 2>/dev/null || true
run() { if [ "$(id -u)" = 0 ]; then su postgres -c "$*"; else bash -c "$*"; fi; }
run "$bin/initdb -D $dir/db -A trust -U postgres >/dev/null"
run "$bin/pg_ctl -D $dir/db -o '-k $dir -p 54329 -c listen_addresses=' -l $dir/log start >/dev/null"
trap 'run "$bin/pg_ctl -D $dir/db stop -m fast >/dev/null"; rm -rf "$dir"' EXIT
psql="psql -h $dir -p 54329 -U postgres -q -v ON_ERROR_STOP=1"
$psql -f "$here/stub_auth.sql"
# every migration twice in order (they must be repeatable), then every test
for round in 1 2; do
  for m in "$here"/../migrations/*.sql; do $psql -f "$m"; done
done
for t in "$here"/test_*.sql; do
  echo "== $(basename "$t")"
  $psql -f "$t"
done
