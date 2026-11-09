#!/usr/bin/env bash
# Base de datos local para desarrollo del panel, con datos de demostración.
#
#   ./dev_db.sh start   crea (si no existe) y arranca en el puerto 54330
#   ./dev_db.sh reset   borra y vuelve a crear con migraciones + demo
#   ./dev_db.sh stop    detiene
#
# Cadena de conexión: postgresql://postgres@localhost:54330/postgres
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="$DIR/.dev_db"
PORT="${DEV_DB_PORT:-54330}"

if command -v pg_config >/dev/null 2>&1 && [ -x "$(pg_config --bindir)/initdb" ]; then
  PGBIN="$(pg_config --bindir)"
else
  PGBIN="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)"
fi

if [ "$(id -u)" = "0" ]; then
  run() { runuser -u postgres -- "$@"; }
else
  run() { "$@"; }
fi

psql_() { run "$PGBIN/psql" -h localhost -p "$PORT" -U postgres -d postgres -v ON_ERROR_STOP=1 -q "$@"; }

crear() {
  mkdir -p "$DATA"
  [ "$(id -u)" = "0" ] && chown postgres "$DATA"
  run "$PGBIN/initdb" -D "$DATA/pg" -A trust -U postgres -E UTF8 --locale=C.UTF-8 >/dev/null
  arrancar
  for f in "$DIR"/migrations/*.sql; do psql_ -f "$f"; done
  psql_ -f "$DIR/seed/demo.sql" >/dev/null
  echo "Base de demostración lista en el puerto $PORT"
}

arrancar() {
  run "$PGBIN/pg_ctl" -D "$DATA/pg" -o "-p $PORT -c listen_addresses=localhost" -l "$DATA/log" -w start >/dev/null
}

detener() {
  [ -d "$DATA/pg" ] && run "$PGBIN/pg_ctl" -D "$DATA/pg" -m fast stop >/dev/null 2>&1 || true
}

case "${1:-start}" in
  start) if [ -d "$DATA/pg" ]; then arrancar; echo "Arrancada en el puerto $PORT"; else crear; fi ;;
  reset) detener; rm -rf "$DATA"; crear ;;
  stop)  detener; echo "Detenida" ;;
  *) echo "Uso: $0 start|reset|stop"; exit 1 ;;
esac
