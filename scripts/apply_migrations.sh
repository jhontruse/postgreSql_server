#!/usr/bin/env bash
# Aplica los .sql de init-scripts/ contra la base indicada en $1, una sola
# vez cada uno. Se registra en la tabla public._migrations_applied para no
# reaplicar un archivo ya corrido (a diferencia de deploy_supabase.sh, esto
# NO reemplaza nada: solo corre lo nuevo, pensado para correr sin supervision
# desde Jenkins en cada push).
#
# Uso: ./scripts/apply_migrations.sh "<connection-string>"

set -euo pipefail

TARGET_DB_URL="${1:?uso: $0 <connection-string>}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

psql "$TARGET_DB_URL" -v ON_ERROR_STOP=1 -c \
  "CREATE TABLE IF NOT EXISTS public._migrations_applied (
     filename text PRIMARY KEY,
     applied_at timestamptz NOT NULL DEFAULT now()
   );"

for f in "$SCRIPT_DIR"/init-scripts/*.sql; do
  name="$(basename "$f")"
  already=$(psql "$TARGET_DB_URL" -tAc \
    "SELECT 1 FROM public._migrations_applied WHERE filename = '${name}';")

  if [ "$already" = "1" ]; then
    echo "==> ${name}: ya aplicado, se salta."
    continue
  fi

  echo "==> Aplicando ${name}..."
  psql "$TARGET_DB_URL" -v ON_ERROR_STOP=1 -f "$f"
  psql "$TARGET_DB_URL" -c \
    "INSERT INTO public._migrations_applied (filename) VALUES ('${name}');"
done

echo "==> Migraciones al dia."
