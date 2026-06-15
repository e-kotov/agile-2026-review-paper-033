#!/bin/bash
set -e

# build.sh: 
# 1. Downloads and extracts data from Figshare (on host).
# 2. Builds the Docker image.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REVIEW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Step 1: Verification ==="
echo "Workspace is already initialized with tracked author code."

echo "=== Step 2: Building Container Image ==="
cd "$REVIEW_ROOT/containers"

if command -v docker &> /dev/null; then
    echo "Docker detected. Building image 'paper-033'..."
    cd "$REVIEW_ROOT"
    docker build -t paper-033 -f containers/Dockerfile .
elif command -v apptainer &> /dev/null; then
    if [ "$1" == "--local" ]; then
        echo "Apptainer detected. Building .sif from .def file locally..."
        # Local build requires fakeroot or root permissions
        apptainer build --fakeroot paper-033.sif apptainer.def
    else
        echo "Apptainer detected. Pulling pre-built image from Docker Hub..."
        echo "Use './scripts/build.sh --local' to build from .def file instead (requires fakeroot)."
        apptainer pull --force paper-033.sif docker://egorkotovdhub/agile-2026-paper-033:latest
    fi
else
    echo "Error: Neither Docker nor Apptainer found."
    exit 1
fi

echo "=== Build Complete ==="
