#!/bin/bash
set -e

# run.sh: Host-side script to run the reproduction container.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
REPRO_DIR="/mnt/vast-standard/home/egor.kotov/u14190/jupyterhub-gwdg/projects/agile-2026"

echo "=== Running Reproduction Container ==="

if command -v docker &> /dev/null; then
    docker run --rm \
        -v "$PROJECT_ROOT:/work" \
        -w /work \
        paper-033 /work/repro-reviews/paper-033/scripts/entrypoint.sh /work/repro-reviews/paper-033/scripts/internal_repro.sh
    elif command -v apptainer &> /dev/null; then
    # Export PGDATA to a local project directory to avoid HPC temporary space limits
    export APPTAINERENV_PGDATA=/work/repro-reviews/paper-033/pgdata
    apptainer run \
        --bind "$PROJECT_ROOT:/work" \
        --pwd /work \
        "$PROJECT_ROOT/repro-reviews/paper-033/containers/paper-033.sif" \
        /work/repro-reviews/paper-033/scripts/entrypoint.sh /work/repro-reviews/paper-033/scripts/internal_repro.sh
else
    echo "Error: Neither Docker nor Apptainer found."
    exit 1
fi
