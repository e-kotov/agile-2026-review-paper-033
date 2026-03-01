# Reproduction Scope for `paper-033`

## Included in Scope
- Database cluster initialization with PostgreSQL 16 + PostGIS + pgRouting.
- Execution of `setup.sh` to import Graz-specific OSM data and DEM.
- Verification of database tables and spatial integrity for the Graz extent.
- Full execution of the following Jupyter notebooks:
    - `01_data_exploration.ipynb`
    - `02_route_profiles.ipynb`
    - `03_routing_analysis.ipynb`
- Comparison of generated PNG outputs against original paper figures.

## Excluded from Scope
- `04_city_comparison.ipynb`: This notebook requires comparison data for Linz and Salzburg which is not present in the current repository.
- Comparison city database imports (Linz/Salzburg sections of `setup.sh` and `setup.sql`): Excluded due to missing input assets.

## Deviations from Author Instructions
- Using a single-container architecture (PostgreSQL + App) instead of local system installation to ensure portability across Docker and Apptainer environments.
- Non-interactive execution of notebooks using `nbconvert` or similar tooling.
