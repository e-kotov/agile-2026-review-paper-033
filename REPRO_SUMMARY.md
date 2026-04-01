# Reproduction Summary: Paper 033

## Overview
Reproduction of *"OpenStreetMap Suitability Analysis for Wheelchair Routing"* (Majic et al., 2026). The reproduction focused on the Graz-only pipeline, successfully recomputing the database setup and core analysis notebooks.

## Computational Environment
- **Container**: PostgreSQL 16 + PostGIS + pgRouting + Python 3.12 (geospatial stack).
- **Orchestration**: `scripts/build.sh`, `scripts/run.sh`, and `slurm/run_repro.slurm`.
- **Image**: `egorkotovdhub/agile-2026-paper-033:latest` (Docker Hub).

## Key Discrepancies & Issues Identified
1.  **Missing Data**: `innerenbezirke` shapefile and Linz/Salzburg OSM extracts were absent.
2.  **Code Rot**: Author's code used deprecated Matplotlib color cycler syntax and lacked explicit library versions.
3.  **Numerical Stability**: `savgol_filter` failed on short route segments (patched with length checks).
4.  **Computational Inconsistency**: Figure 9b histogram excludes outliers visually but the mean (5.32%) is calculated on the full dataset, unlike the 3.33% claimed in the paper.
5.  **Logic Errors**: Redundant `* 100` multiplication in slope queries caused incorrect "Red" (> 6%) classifications (patched).
6.  **Stochasticity**: Experiment 3 route selection lacked a random seed/sort, leading to visual differences in Figure 22.
7.  **Mapping Flaws**: Experiment 2 map (Figure 19) suffered from a CRS mismatch (4326 vs 3857).

## Surgical Edits (Patches)
Consolidated in `repro_patches.diff`:
- **`setup.sql`**: Handling missing data and restoring tables.
- **`02_route_profiles.ipynb`**: Fixed empty dataframe errors, smoothing logic, and slope calculation.
- **`03_routing_analysis.ipynb`**: Fixed redundant slope multiplication in stats.
- **`01_data_exploration.ipynb`**: Fixed x-axis legibility for Figure 9b.

## Git Workflow
- **`main`**: Pristine baseline (Infrastructure + Original Author Files).
- **`edits`**: Clean branch with exactly one commit containing all surgical patches.
- **`backup`**: Local-only backup of the full reproduction state.

## Automation Tools
- `scripts/extract_tables.py`: Programmatically extracts LaTeX tables from notebooks for the Quarto report.
- `scripts/generate_repro_patchset.sh`: Generates the `repro_patches.diff` comparing original vs. patched files.
- `report/report.qmd`: Quarto source for the final reproducibility review.

## Re-Execution Commands
```bash
# 1. Acquire Data
./scripts/download_data.sh 31333180 repro/DATA

# 2. Run Pipeline (HPC)
sbatch slurm/run_repro.slurm

# 3. Post-Process
python3 scripts/extract_tables.py
./scripts/generate_repro_patchset.sh
cd report && quarto render report.qmd
```
