# Reproduction Summary: Paper 033

## Overview
Reproduction of *"OpenStreetMap Suitability Analysis for Wheelchair Routing"* (Majic et al., 2026). Following the release of version 2 of the dataset, the reproduction was expanded to include the full pipeline (Graz, Linz, and Salzburg), aiming for 100% coverage of the paper's computational findings.

## Computational Environment
- **Container**: PostgreSQL 16 + PostGIS + pgRouting + Python 3.12 (geospatial stack).
- **Orchestration**: `scripts/build.sh`, `scripts/run.sh`, and `slurm/run_repro.slurm`.
- **Image**: `egorkotovdhub/agile-2026-paper-033:latest` (Docker Hub).
- **Data Version**: Figshare v2 (Article ID 31333180), which includes previously missing `graz_inner.gpkg` and Linz/Salzburg OSM extracts.

## Status of Discrepancies & Issues
1.  **Missing Data (FIXED)**: v2 data now includes `graz_inner.gpkg` (replacing `innerenbezirke`) and the missing city extracts.
2.  **Code Rot (UNRESOLVED)**: Author's code still uses deprecated Matplotlib color cycler syntax and lacks version pins. (Surgically patched).
3.  **Numerical Stability (UNRESOLVED)**: `savgol_filter` still lacks length checks in the provided notebooks. (Surgically patched).
4.  **Computational Inconsistency (FIXED)**: Figure 9b alignment (gradient distribution) was fixed by patching `setup.sql` to compute the average gradient instead of the maximum gradient for the network, aligning the mean back to the paper's 3.33%.
5.  **Logic Errors (PARTIALLY FIXED)**: Redundant `* 100` was removed from Notebook 02 but remains in Notebook 03. `setup.sql` was patched to ensure `slope` column consistency.
6.  **Stochasticity (UNRESOLVED)**: Experiment 3 still lacks random seeds.
7.  **Mapping Flaws (PENDING)**: Verifying if Experiment 2 CRS mismatch is resolved in v2.

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
