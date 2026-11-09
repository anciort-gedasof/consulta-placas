#!/usr/bin/env bash
# Levanta un PostgreSQL temporal, aplica las migraciones y corre las pruebas.
# Uso: cd backend && ./tests/run_tests.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ubicar los binarios de PostgreSQL
if command -v pg_config >/dev/null 2>&1 && [ -x "$(pg_config --bindir)/initdb" ]; then
  PGBIN="$(pg_config --bindir)"
else
  PGBIN="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)"
fi
[ -x "$PGBIN/initdb" ] || { echo "No se encontró PostgreSQL (initdb)"; exit 1; }

TMP="$(mktemp -d)"
PORT="${PGPORT_PRUEBAS:-54329}"

# PostgreSQL no corre como root: usar el usuario postgres si hace falta.
if [ "$(id -u)" = "0" ]; then
  chown postgres "$TMP"
  run() { runuser -u postgres -- "$@"; }
else
  run() { "$@"; }
fi

cleanup() {
  run "$PGBIN/pg_ctl" -D "$TMP/data" -m fast stop >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

run "$PGBIN/initdb" -D "$TMP/data" -A trust -E UTF8 --locale=C.UTF-8 >/dev/null
run "$PGBIN/pg_ctl" -D "$TMP/data" -o "-p $PORT -k $TMP -c listen_addresses=''" -l "$TMP/log" -w start >/dev/null

PSQL=(run "$PGBIN/psql" -h "$TMP" -p "$PORT" -d postgres -v ON_ERROR_STOP=1 -q)

for f in "$DIR"/migrations/*.sql; do
  echo "Migración: $(basename "$f")"
  "${PSQL[@]}" -f "$f"
done

for f in "$DIR"/tests/pruebas*.sql; do
  echo "Pruebas: $(basename "$f")"
  "${PSQL[@]}" -f "$f"
done
