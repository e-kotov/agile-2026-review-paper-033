#!/bin/bash
set -e

# run-setup.sh: Executes the paper's database pipeline within the container.

PAPER_DIR="/work/paper-033/AGILE2026_OSM_Wheelchair_Routing"
WORK_DIR="/work/repro-reviews/paper-033/runs/work"

echo "Staging work directory..."
mkdir -p "$WORK_DIR"
cp -r "$PAPER_DIR"/* "$WORK_DIR/"

cd "$WORK_DIR"

# Patch setup.sh to use the correct data path if needed (though it uses $(dirname $0)/DATA)
# and ensure it uses the postgres user and OSM database.
# Note: entrypoint.sh already handles starting PG.

chmod +x setup.sh

echo "Starting setup.sh..."
./setup.sh

echo "Database setup complete."
