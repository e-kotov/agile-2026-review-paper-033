#!/bin/bash
set -e

# run-notebooks.sh: Executes the Graz-only analysis notebooks (01-03) in order.

WORK_DIR="/work/repro-reviews/paper-033/runs/work"
cd "$WORK_DIR"

echo "Executing notebooks 01 to 03..."

for nb in 01_data_exploration.ipynb 02_route_profiles.ipynb 03_routing_analysis.ipynb; do
    echo "Running $nb..."
    jupyter nbconvert --to notebook --execute "$nb" --output "executed_$nb" 
    --ExecutePreprocessor.timeout=1200 
    --ExecutePreprocessor.kernel_name=python3
done

echo "Notebook execution complete."
echo "Generated notebooks: executed_01_data_exploration.ipynb, executed_02_route_profiles.ipynb, executed_03_routing_analysis.ipynb"
