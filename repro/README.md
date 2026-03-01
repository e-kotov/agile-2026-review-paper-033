# Wheelchair Routing Graph Construction and Analysis for Graz
## Summary

The workflow builds a wheelchair-accessible routing graph for Graz and comparison cities from OpenStreetMap data, integrates elevation and kerb attributes, and produces analysis figures from Jupyter notebooks.

## Repository Structure

- `DATA/` input datasets (OSM extract, DEM, borders, hex grid)
- `setup.sh` end-to-end database setup
- `setup.sql` database pipeline (schemas, elevation, networks, viz, comparisons)
- `setup-postgres.md` PostgreSQL setup steps
- `requirements.txt` Python dependencies
- `01_data_exploration.ipynb` to `04_city_comparison.ipynb` analysis notebooks
- `fonts/` custom fonts used by the notebooks

## Requirements

System:

- PostgreSQL + PostGIS + pgRouting + osm2pgsql + osm2pgrouting
- Sufficient disk space for OSM and raster processing

Python:

- Python 3.x
- Packages in `requirements.txt`

## Data Inputs

All required data in `DATA/`:

- City OSM extracts and border layers were obtained via the Overpass API: <https://overpass-turbo.eu/>.
- DEM source: <https://www.landesentwicklung.steiermark.at/>.

- `graz_3` (OSM extract)
- `linz` (OSM extract, for comparisons)
- `salzburg` (OSM extract, for comparisons)
- `terrain_gesamt_clipped_5m.tif` (DEM raster, EPSG:32633)
- `terrain_gesamt_clipped_20m.tif` (used in notebook plots)
- `terrain_gesamt_clipped_zoomed.tif` (used in notebook plots)
- `graz_border.gpkg` (city border, OSM extract clipping, and for comparisons)
- `linz_border.gpkg` (city border, for comparisons, and OSM extract clipping)
- `salzburg_border.gpkg` (city border, for comparisons, and OSM extract clipping)
- `hex500.gpkg` (hex grid)

## Database Setup

Follow the full PostgreSQL setup instructions in `setup-postgres.md`.

Quick path:

1. Install system packages (PostGIS, pgRouting, osm2pgsql, osm2pgrouting).
2. System dependend, configure `pg_hba.conf` for password auth and restart PostgreSQL.
3. Create the `OSM` database.
4. Run the setup shell script:

```bash
./setup.sh
```

This script creates extensions/schemas, imports OSM and raster data, and runs `setup.sql`.
For comparison data imports (Linz/Salzburg), see the commented commands at the end of `setup.sh` and the comparison section in `setup.sql`.

Comparison database setup (optional):

1. Create a separate `OSM_comparison` database.
2. Import city extracts and borders into that database (see `setup.sh` comments).
3. Run the comparison section in `setup.sql` against `OSM_comparison`.

## Python Environment

- Create a Python virtual environment and install dependencies:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

## Run the Notebooks

Open notebooks in order for data exploration, route profiling, routing analysis, and city comparisons:

1. `01_data_exploration.ipynb` (wordcloud, highway type distribution, surface analysis, slope maps)
2. `02_route_profiles.ipynb` (route elevation profiles, before/after network comparison visualizations)
3. `03_routing_analysis.ipynb` (routing success rate analysis, network accessibility metrics)
4. `04_city_comparison.ipynb` (cross-city sidewalk coverage, tagging completeness comparison; requires `OSM_comparison` database)

## Database Connections Used by Notebooks

- `01_data_exploration.ipynb` uses `postgresql+psycopg2://postgres:admin@localhost/OSM`
- `02_route_profiles.ipynb` uses `postgresql+psycopg2://postgres:admin@localhost/OSM`
- `03_routing_analysis.ipynb` uses `postgresql+psycopg2://postgres:admin@localhost/OSM`
- `04_city_comparison.ipynb` uses `postgresql+psycopg2://postgres:admin@localhost/OSM` by default. If you run the comparison pipeline in a separate database, switch it to `OSM_comparison`.

## Expected Outputs

The notebooks generate plots saved as PNG files in the repository root (e.g., `wordcloud1.png`, `highway1.png`, `surface.png`).
