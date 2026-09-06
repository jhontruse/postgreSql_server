#!/usr/bin/env bash
# Publica (espeja) los esquemas propios de la base local hacia Supabase.
#
# Dump con "-n" por esquema: nunca toca los esquemas internos de Supabase
# (auth, storage, extensions, public, etc.), solo los que son nuestros.
#
# --clean --if-exists hace que el restore sea un REEMPLAZO COMPLETO de esos
# esquemas en Supabase con el estado actual de local (estructura + datos).
# Si Supabase llega a tener datos propios que no vengan de local, este
# script los borraria: usalo solo mientras Supabase sea un espejo de local.

set -euo pipefail
cd "$(dirname "$0")/.."

set -a
source .env
set +a

: "${SUPABASE_DB_URL:?falta SUPABASE_DB_URL en .env}"
: "${POSTGRES_USER:?falta POSTGRES_USER en .env}"
: "${POSTGRES_DB:?falta POSTGRES_DB en .env}"

SCHEMAS=(db_biblioteca db_gym)

SCHEMA_ARGS=()
for s in "${SCHEMAS[@]}"; do
  SCHEMA_ARGS+=(-n "$s")
done

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="/tmp/deploy_${TIMESTAMP}.dump"

echo "==> Dump local de: ${SCHEMAS[*]}"
docker exec postgres_db pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  "${SCHEMA_ARGS[@]}" -F c -f "$DUMP_FILE"

mkdir -p ./backups
docker cp "postgres_db:${DUMP_FILE}" "./backups/deploy_${TIMESTAMP}.dump"
echo "==> Respaldo local: ./backups/deploy_${TIMESTAMP}.dump"

echo "==> Publicando en Supabase..."
docker exec postgres_db pg_restore --no-owner --no-privileges --clean --if-exists \
  --dbname="$SUPABASE_DB_URL" "$DUMP_FILE"

echo "==> Listo. Esquemas en Supabase:"
docker exec postgres_db psql "$SUPABASE_DB_URL" -c "\dn"
