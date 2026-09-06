-- 01_schemas.sql
-- Esquemas adicionales dentro de la base POSTGRES_DB.
-- Se ejecuta solo la primera vez que se crea el volumen de datos
-- (ver seccion "Scripts de inicializacion" del README).
--
-- Nombres en minusculas: Postgres pliega a minusculas todo identificador
-- que no vaya entre comillas dobles (ver seccion "Esquemas y usuarios" del README).

CREATE SCHEMA IF NOT EXISTS db_biblioteca;
CREATE SCHEMA IF NOT EXISTS db_gym;
