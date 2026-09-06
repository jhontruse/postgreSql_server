# PostgreSQL 16 — Entorno local con Docker

Servidor PostgreSQL listo para desarrollo local, levantado con Docker Compose.
Pensado para tener una base de datos en el equipo sin instalarla de forma nativa.

Imagen base: [`postgres:16-alpine`](https://hub.docker.com/_/postgres)

---

## Requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y en ejecución
- ~2 GB de RAM disponibles (el contenedor está limitado a 2 GB por defecto)
- Opcional: [DBeaver](https://dbeaver.io/), [pgAdmin](https://www.pgadmin.org/) o la
  [extensión de PostgreSQL para VS Code](https://marketplace.visualstudio.com/items?itemName=ms-ossdata.vscode-pgsql)

> No hace falta Dockerfile: se usa la imagen oficial directamente.

---

## Configuración inicial

**1. Crear el archivo `.env`**

```bash
cp .env.example .env
```

| Variable             | Descripción                                          | Default   |
| -------------------- | ---------------------------------------------------- | --------- |
| `POSTGRES_DB`        | Base de datos que se crea al inicializar             | —         |
| `POSTGRES_USER`      | Usuario propietario (**es superusuario**)            | —         |
| `POSTGRES_PASSWORD`  | Contraseña de ese usuario                            | —         |
| `POSTGRES_PORT`      | Puerto expuesto en el host                           | `5432`    |
| `TZ`                 | Zona horaria del contenedor y de la sesión           | `America/Lima` |
| `POSTGRES_MEM_LIMIT` | Techo de RAM del contenedor                          | `2g`      |

> ⚠️ **Estas variables solo se aplican la primera vez que se crea la base.**
> Si el volumen `postgres_data` ya existe, cambiarlas no tiene ningún efecto.
> Para aplicarlas hay que recrear el volumen con `docker compose down -v`,
> lo cual **elimina todos los datos**.

**2. El `.env` no debe versionarse.** Verifica que Git lo esté ignorando:

```bash
git check-ignore -v .env      # debe responder con la regla que lo ignora
```

---

## Uso

```bash
docker compose up -d          # levantar
docker compose logs -f        # ver el arranque
docker compose ps             # estado (debe decir "healthy")
```

El arranque toma unos segundos. El healthcheck usa `pg_isready` contra el usuario
y la base definidos en el `.env`.

---

## Conexión

El listener está atado a `127.0.0.1`, por lo que solo acepta conexiones desde la
propia máquina. Para exponerlo a la red local, cambia `127.0.0.1` por `0.0.0.0`
en el `docker-compose.yml`.

| Campo      | Valor                        |
| ---------- | ---------------------------- |
| Host       | `localhost`                  |
| Puerto     | `5432`                       |
| Database   | valor de `POSTGRES_DB`       |
| Usuario    | valor de `POSTGRES_USER`     |
| Contraseña | valor de `POSTGRES_PASSWORD` |
| SSL mode   | `disable` / `prefer`         |

**Desde terminal, sin instalar nada:**

```bash
docker exec -it postgres_db psql -U $POSTGRES_USER -d $POSTGRES_DB
```

**Cadena JDBC:**

```
jdbc:postgresql://localhost:5432/BD_DEVELOPER
```

**Desde otro contenedor de la misma red de Compose**, el host no es `localhost`
sino el nombre del servicio: `postgres`.

---

## Esquemas y usuarios

En PostgreSQL un **esquema** es un espacio de nombres dentro de una base de datos,
independiente de los usuarios. No es lo mismo que en Oracle, donde esquema y usuario
son la misma entidad.

```sql
-- Crear un esquema
CREATE SCHEMA ventas AUTHORIZATION mi_usuario;

-- Trabajar en él sin escribir el prefijo cada vez
ALTER DATABASE "BD_DEVELOPER" SET search_path TO ventas, public;

-- Listar esquemas
SELECT schema_name FROM information_schema.schemata;
```

**Usuario de aplicación.** El usuario definido en `POSTGRES_USER` es **superusuario**
de la instancia. Para el trabajo diario conviene crear un rol con menos privilegios:

```sql
CREATE ROLE app_user WITH LOGIN PASSWORD 'xxx';
GRANT CONNECT ON DATABASE "BD_DEVELOPER" TO app_user;
GRANT USAGE, CREATE ON SCHEMA ventas TO app_user;
```

> **Sobre las mayúsculas:** PostgreSQL convierte a minúsculas todo identificador
> que no vaya entre comillas dobles. Si tu base se llama `BD_DEVELOPER`, en SQL
> debes escribirla como `"BD_DEVELOPER"`. Por eso la convención en Postgres es
> usar siempre nombres en minúsculas.

---

## Scripts de inicialización

Los archivos `.sql`, `.sql.gz` o `.sh` colocados en `init-scripts/` se ejecutan
automáticamente, en orden alfabético, **solo la primera vez** que se crea la base.

```
init-scripts/
└── 01_schemas.sql   # crea los esquemas db_biblioteca y db_gym
```

Numera los archivos para garantizar el orden (por ejemplo, un futuro `02_tables.sql`
con las tablas de cada esquema). En una base ya existente no se ejecutan: hay que
recrear el volumen (`docker compose down -v`, borra los datos) o aplicarlos a mano
contra el contenedor ya corriendo:

```bash
docker exec -i postgres_db psql -U $POSTGRES_USER -d $POSTGRES_DB < init-scripts/01_schemas.sql
```

---

## Flujo local → Supabase

Este proyecto usa Supabase como copia en la nube de la base local. El flujo es:

1. **Desarrolla en local**: conéctate al contenedor y crea/modifica tablas dentro de
   `db_biblioteca` o `db_gym` (o cualquier esquema propio) como quieras.
2. **Publica con un comando:**

   ```bash
   ./scripts/deploy_supabase.sh
   ```

   Esto hace `pg_dump` **solo** de los esquemas propios (nunca de `public` ni de los
   esquemas internos de Supabase como `auth`, `storage`, `extensions`), guarda un
   respaldo con fecha en `./backups/`, y restaura ese dump contra Supabase con
   `--clean --if-exists`, reemplazando por completo esos esquemas allá.

3. **Requisito:** el `.env` debe tener `SUPABASE_DB_URL` con el connection string de
   tipo **Session pooler** de tu proyecto (Supabase dashboard → botón **Connect**).

> ⚠️ **El despliegue reemplaza los datos en Supabase con los de local**, no los
> combina. Este flujo asume que Supabase es un espejo de la base local — si algún
> día Supabase tiene datos propios de usuarios reales que no vengan de local (por
> ejemplo, una app en producción escribiendo directo ahí), dejar de usar este script
> tal cual y pasar a migraciones incrementales (`ALTER TABLE ADD COLUMN`, etc.) que
> nunca borren nada.
>
> Para agregar más esquemas al despliegue, edita el arreglo `SCHEMAS` al inicio de
> `scripts/deploy_supabase.sh`.

---

## Backups

**Exportar:**

```bash
docker exec postgres_db pg_dump -U mi_usuario -d mi_base -F c -f /tmp/backup.dump
docker cp postgres_db:/tmp/backup.dump ./backups/backup.dump
```

**Restaurar:**

```bash
docker cp ./backups/backup.dump postgres_db:/tmp/backup.dump
docker exec postgres_db pg_restore -U mi_usuario -d mi_base --clean /tmp/backup.dump
```

**Volcado en SQL plano** (más portable, más pesado):

```bash
docker exec postgres_db pg_dumpall -U mi_usuario > ./backups/full.sql
```

---

## Persistencia de datos

Los datos viven en el volumen Docker `postgresql_server_postgres_data`, no dentro
del contenedor. `docker compose down` y `up` **no borran la base**.

```bash
docker volume ls | grep postgres     # ver el volumen
docker compose down -v               # ⚠️ borra el volumen y todos los datos
```

---

## Estructura del proyecto

```
postgreSql_server/
├── docker-compose.yml     # definición del servicio
├── .env                   # credenciales (no se versiona)
├── .env.example           # plantilla de variables
├── .gitignore
├── init-scripts/          # scripts SQL de inicialización
└── README.md
```

---

## Notas de configuración

- **`stop_grace_period: 30s`** — permite un apagado limpio y evita que el siguiente
  arranque entre en modo recovery.
- **`shm_size: 256m`** — el default de Docker (64 MB) es insuficiente para queries
  en paralelo y produce errores de memoria compartida.
- **Puerto en `127.0.0.1`** — la base no queda expuesta a la red local.
- **Variables con `:?`** — el compose falla con un mensaje claro si falta el `.env`.
- **`POSTGRES_INITDB_ARGS`** — fuerza codificación UTF8 y autenticación `scram-sha-256`.
- **Rotación de logs** — 10 MB × 3 archivos.

---

## Problemas frecuentes

**`Cannot connect to the Docker daemon`**
Docker Desktop no está abierto.

**`role "X" does not exist` / `database "X" does not exist`**
Cambiaste `POSTGRES_USER` o `POSTGRES_DB` en el `.env` sobre un volumen ya existente.
Esas variables solo aplican en la creación inicial. Conéctate con las credenciales
originales, o recrea el volumen con `docker compose down -v`.

**`database "bd_developer" does not exist` (en minúsculas, sin haberlo escrito así)**
Falta citar el identificador: usa `"BD_DEVELOPER"` entre comillas dobles.

**El puerto 5432 ya está en uso**
Tienes otro PostgreSQL corriendo. Cambia `POSTGRES_PORT` en el `.env`.

**El contenedor queda en `unhealthy`**
El healthcheck usa `POSTGRES_USER` y `POSTGRES_DB`. Si no coinciden con lo que hay
dentro del volumen, nunca pasará. Revisa con `docker compose logs`.

---

## Versión

PostgreSQL 16, con soporte de la comunidad hasta **noviembre de 2028**.
La versión actual de la serie es la 18. Actualizar de major requiere `pg_dump` o
`pg_upgrade`; no basta con cambiar el tag de la imagen.
