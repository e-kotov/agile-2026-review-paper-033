#!/bin/bash
set -e

DB_NAME="OSM"
DB_USER="postgres"
DB_HOST="localhost"
DB_PORT="5432"
DB_PASS="admin"
DATA_DIR="$(dirname "$0")/DATA"

# Optional comparison database import
RUN_COMPARISON="${RUN_COMPARISON:-false}"
COMP_DB_NAME="${COMP_DB_NAME:-OSM_comparison}"

export PGPASSWORD="$DB_PASS"

SQL_DIR="$(dirname "$0")"

echo "=== 1. Extensions & schemas (setup.sql section 1) ==="
psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -v ON_ERROR_STOP=1 <<'EOSQL'
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS hstore;
CREATE EXTENSION IF NOT EXISTS pgrouting;
CREATE EXTENSION IF NOT EXISTS postgis_raster;
CREATE SCHEMA IF NOT EXISTS heightdata;
CREATE SCHEMA IF NOT EXISTS sidewalk;
CREATE SCHEMA IF NOT EXISTS nodes;
CREATE SCHEMA IF NOT EXISTS viz;
EOSQL

echo "=== 2. Importing OSM data ==="
osm2pgsql "$DATA_DIR/graz_3" -r xml -c -d "$DB_NAME" -U "$DB_USER" -H "$DB_HOST" -k -s

echo "=== 3. Importing routing data ==="
osm2pgrouting -f "$DATA_DIR/graz_3" -c "$DATA_DIR/mapconfig.xml" -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" --password="$DB_PASS" --clean --addnodes

echo "=== 4. Importing raster elevation data ==="
raster2pgsql -c -C -s 32633 -f rast -F -I -M -t 100x100 "$DATA_DIR/terrain_gesamt_clipped_5m.tif" heightdata.graz_dem | psql -U "$DB_USER" -d "$DB_NAME" -h "$DB_HOST" -p "$DB_PORT" -q

echo "=== 5. Importing Graz border polygon ==="
ogr2ogr -f PostgreSQL "PG:host=$DB_HOST user=$DB_USER password=$DB_PASS dbname=$DB_NAME" "$DATA_DIR/graz_border.gpkg"

echo "=== 6. Importing hex500 grid ==="
ogr2ogr -f PostgreSQL "PG:host=$DB_HOST user=$DB_USER password=$DB_PASS dbname=$DB_NAME" "$DATA_DIR/hex500.gpkg"

echo "=== 7. Adding tags hstore column to osm_ways ==="
psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -c "ALTER TABLE osm_ways ADD COLUMN IF NOT EXISTS tags hstore;"
psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -c "UPDATE osm_ways SET tags = CASE WHEN tag_name IS NOT NULL THEN hstore(tag_name, tag_value) ELSE ''::hstore END;"

echo "=== 8. Running setup.sql (processing sections 2+3) ==="
psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -f "$SQL_DIR/setup.sql" -v ON_ERROR_STOP=1

echo "=== Done! Verifying tables ==="
psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -c "SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema') ORDER BY schemaname, tablename;"

if [[ "$RUN_COMPARISON" == "true" ]]; then
	echo "=== Comparison import (optional) ==="
	echo "Using COMP_DB_NAME=$COMP_DB_NAME"

	osm2pgsql "$DATA_DIR/graz_3" -r xml -c -d "$COMP_DB_NAME" -U "$DB_USER" -H "$DB_HOST" -k -s -p graz
	osm2pgsql "$DATA_DIR/linz" -r xml -c -d "$COMP_DB_NAME" -U "$DB_USER" -H "$DB_HOST" -k -s -p linz

	osm2pgrouting -f "$DATA_DIR/graz_3" -d "$COMP_DB_NAME" -U "$DB_USER" -h "$DB_HOST" --password="$DB_PASS" --clean --prefix graz_
	osm2pgrouting -f "$DATA_DIR/linz" -d "$COMP_DB_NAME" -U "$DB_USER" -h "$DB_HOST" --password="$DB_PASS" --clean --prefix linz_

	ogr2ogr -f PostgreSQL "PG:host=$DB_HOST user=$DB_USER password=$DB_PASS dbname=$COMP_DB_NAME" "$DATA_DIR/graz_border.gpkg"
	ogr2ogr -f PostgreSQL "PG:host=$DB_HOST user=$DB_USER password=$DB_PASS dbname=$COMP_DB_NAME" "$DATA_DIR/linz_border.gpkg"
fi
