#!/bin/bash
set -e

# internal_repro.sh: Executed INSIDE the container.
# This version runs directly in the author code subfolder.

# 1. Start Postgres (handled by entrypoint.sh wrapping this script)
echo "Waiting for PostgreSQL..."
until pg_isready -h localhost -p 5432 > /dev/null 2>&1; do
    sleep 1
done

# 2. Navigate to the author code subfolder
WORK_DIR="/work/repro-reviews/paper-033/repro"
cd "$WORK_DIR"

# 3. Run Patched Setup
echo "Running patched setup scripts in place..."
chmod +x setup.sh
./setup.sh

# 4. Run Notebooks (01-03)
echo "Running notebooks..."
for nb in 01_data_exploration.ipynb 02_route_profiles.ipynb 03_routing_analysis.ipynb; do
    echo "Executing $nb..."
    jupyter nbconvert --to notebook --execute "$nb" --output "executed_$nb" --ExecutePreprocessor.timeout=3600
done

echo "=== Reproduction Success ==="
