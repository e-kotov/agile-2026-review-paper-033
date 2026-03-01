# PostgreSQL Setup for  Project

## Prerequisites

- PostgreSQL installed and running
- `sudo` access

## Steps

### 0. Install required system packages

```bash
sudo dnf install postgis postgis-client pgrouting postgresql-contrib osm2pgsql osm2pgrouting
```

### 1. Update `pg_hba.conf` to use password authentication

```bash
sudo nano /var/lib/pgsql/data/pg_hba.conf
```

Change `ident` to `scram-sha-256` on these lines:

```
host  all  all  127.0.0.1/32  scram-sha-256
host  all  all  ::1/128       scram-sha-256
```

### 2. Restart PostgreSQL

```bash
sudo systemctl restart postgresql
```

### 3. Set the `postgres` user password

```bash
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'admin';"
```

### 4. Create the `OSM` database

```bash
sudo -u postgres psql -c 'CREATE DATABASE "OSM";'
```

### 5. Create the Python virtual environment

```bash
cd ~/
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

### 6. Run setup (extensions, schemas, and data imports)

Run everything automatically with:

```bash
~/setup.sh
```

This will:

1. Create extensions (`postgis`, `hstore`, `pgrouting`, `postgis_raster`) and schemas (`heightdata`, `sidewalk`, `nodes`, `viz`)
2. Import OSM data via `osm2pgsql` (from `DATA/graz_3`)
3. Import routing data via `osm2pgrouting` (creates `ways`, `ways_vertices_pgr`, `osm_nodes`, `configuration`)
4. Import raster elevation data into `heightdata.graz_dem` (from `DATA/terrain_gesamt_clipped.tif`)
5. Import `graz_border.gpkg` and `hex500.gpkg`
6. Add hstore tags column to `osm_ways`
7. Run `setup.sql` which:
   - Adds `tags_h` hstore columns to `planet_osm_ways`, `planet_osm_point`, `planet_osm_rels`
   - Creates `streets` (joined OSM ways + routing data)
   - Creates `streets_graz` (clipped to Graz border, with parsed `width_float` and `incline_float`)
   - Creates `heightdata.graz_dem_vector_square` (raster to vector polygons)
   - Creates `heightdata.streets_graz_dumpsegments` (segmentized streets for elevation sampling)
   - Creates `heightdata.streets_clipped_dumpsegments_new` (segments with start/end elevation + slope)
   - Creates `heightdata.graz_elvation_avg_slope` and `heightdata.graz_elvation_max_slope`
   - Creates `ways_vertices_pgr_elevation` (vertices with elevation)
   - Creates `graz_pgr` (streets + max slope) and `graz_pgr_avg_slope` (streets + avg slope)
   - Creates `graz_nodes` (OSM points within Graz border with barrier tags)
   - Creates `graz_sidewalk_unique` (deduplicated sidewalk geometries)

### 7. Run the notebook

Interactively:

```bash
.venv/bin/jupyter notebook 01_data_exploration.ipynb
```

### 8. Verify the connection eg, by running a simple query against the `OSM` database

```bash
cd ~/
.venv/bin/python -c "
from sqlalchemy import create_engine, text
engine = create_engine('postgresql+psycopg2://postgres:admin@localhost:5432/OSM', future=True)
with engine.connect() as conn:
    print(conn.execute(text('SELECT 1')).scalar())
    print('Connection successful!')
"
```

### To reset and re-run the full pipeline

```bash
sudo -u postgres psql -c 'DROP DATABASE IF EXISTS "OSM";'
sudo -u postgres psql -c 'CREATE DATABASE "OSM";'
~/setup.sh
```

## Expected tables after setup

| Schema | Table | Description |
|--------|-------|-------------|
| `heightdata` | `graz_dem` | Raster elevation data (5m resolution) |
| `heightdata` | `graz_dem_vector_square` | Vectorized elevation polygons |
| `heightdata` | `streets_graz_dumpsegments` | Street segments for elevation sampling |
| `heightdata` | `streets_clipped_dumpsegments_new` | Segments with elevation + slope |
| `heightdata` | `graz_elvation_avg_slope` | Average slope per street |
| `heightdata` | `graz_elvation_max_slope` | Max slope per street |
| `public` | `planet_osm_line` | OSM line features |
| `public` | `planet_osm_point` | OSM point features |
| `public` | `planet_osm_polygon` | OSM polygon features |
| `public` | `planet_osm_roads` | OSM road features |
| `public` | `planet_osm_ways` | OSM ways (with `tags_h` hstore) |
| `public` | `planet_osm_rels` | OSM relations (with `tags_h` hstore) |
| `public` | `ways` | pgRouting ways |
| `public` | `ways_vertices_pgr` | pgRouting vertices |
| `public` | `ways_vertices_pgr_elevation` | Vertices with elevation |
| `public` | `osm_nodes` | OSM nodes (from osm2pgrouting) |
| `public` | `osm_ways` | OSM ways (from osm2pgrouting, with hstore tags) |
| `public` | `configuration` | pgRouting tag configuration |
| `public` | `graz_border` | Graz border polygon |
| `public` | `hex500` | Hex 500m grid |
| `public` | `streets` | OSM ways joined with routing data |
| `public` | `streets_graz` | Streets clipped to Graz border |
| `public` | `graz_pgr` | Streets + max slope |
| `public` | `graz_pgr_avg_slope` | Streets + average slope |
| `public` | `graz_nodes` | OSM points in Graz (with barrier tags) |
| `public` | `graz_sidewalk_unique` | Deduplicated sidewalk geometries |

## Required data files

Files must be present in `~/DATA/`:

| File | Description |
|------|-------------|
| `graz_3` | OSM XML export for Graz |
| `mapconfig.xml` | osm2pgrouting tag configuration |
| `terrain_gesamt_clipped_5m.tif` | DEM raster (5m, EPSG:32633) |
| `terrain_gesamt_clipped_20m.tif` | DEM raster (20m, used in notebook DEM plot) |
| `terrain_gesamt_clipped_zoomed.tif` | Zoomed DEM raster (used in notebook DEM plot) |
| `graz_border.gpkg` | Graz city border polygon |
| `hex500.gpkg` | 500m hexagon grid |

## Connection String

```
postgresql+psycopg2://postgres:admin@localhost:5432/OSM
```
