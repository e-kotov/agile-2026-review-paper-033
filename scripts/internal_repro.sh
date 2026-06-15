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

# 3. Setup Runtime Library Extension
# Note: Python dependencies are pre-installed in the container's /opt/venv via uv.

# Check if we should skip setup (manual override or check pgdata)
if [ -f "setup_complete.lock" ]; then
    echo "Setup already complete (lock file found). Skipping SQL imports."
else
    echo "Running setup scripts..."
    chmod +x setup.sh import_comparison.sh
    ./setup.sh
    ./import_comparison.sh
    touch "setup_complete.lock"
fi

# 4. Run Notebooks (01-04)
echo "Running notebooks..."
for nb in 01_fire_horse.ipynb 02_fire_horse.ipynb 03_fire_horse.ipynb 04_fire_horse.ipynb; do
    echo "Executing $nb..."
    # Use the system jupyter but with our extended PYTHONPATH
    jupyter nbconvert --to notebook --execute "$nb" --output "executed_$nb" --ExecutePreprocessor.timeout=3600
done

echo "=== Reproduction Success ==="
