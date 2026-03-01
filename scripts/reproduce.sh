#!/bin/bash
set -e

# reproduce.sh: Fully automated reproduction for Paper-033.
# 1. Downloads reproducibility package from Figshare.
# 2. Unpacks it into a clean work directory.
# 3. Executes the author's original setup and analysis.

FIGSHARE_ID="31333180"
WORK_DIR="/work/repro-reviews/paper-033/runs/work"
SCRIPTS_DIR="/work/repro-reviews/paper-033/scripts"

echo "=== Automated Reproduction for Paper-033 ==="

# 1. Clean and prepare work directory
echo "Preparing work directory: $WORK_DIR"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

# 2. Download data from Figshare using API
echo "Downloading package from Figshare (ID: $FIGSHARE_ID)..."
chmod +x "$SCRIPTS_DIR/download_data.sh"
"$SCRIPTS_DIR/download_data.sh" "$FIGSHARE_ID" "$WORK_DIR"

# 3. Unpack the package
# The zip contains the 'AGILE2026_OSM_Wheelchair_Routing' folder.
cd "$WORK_DIR"
echo "Unpacking zip files..."
find . -name "*.zip" -exec unzip -o {} \;

# 4. Navigate to the code directory
# Note: Based on the zip listing, it unpacks into AGILE2026_OSM_Wheelchair_Routing/
cd AGILE2026_OSM_Wheelchair_Routing

# 5. Run Author's Setup
# This script handles DB initialization via osm2pgsql, osm2pgrouting, etc.
# Precondition: PostgreSQL must be running (handled by container entrypoint)
echo "Running original setup.sh..."
chmod +x setup.sh
./setup.sh

# 6. Run Analysis Notebooks (Graz only: 01-03)
echo "Running analysis notebooks..."
for nb in 01_data_exploration.ipynb 02_route_profiles.ipynb 03_routing_analysis.ipynb; do
    echo "Executing $nb..."
    jupyter nbconvert --to notebook --execute "$nb" --output "executed_$nb" \
    --ExecutePreprocessor.timeout=3600
done

echo "=== Reproduction Complete ==="
echo "Executed notebooks and results are in: $WORK_DIR/AGILE2026_OSM_Wheelchair_Routing"
