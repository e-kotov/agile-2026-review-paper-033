#!/bin/bash
set -e

# Wrapper script for download_and_prep.py
# Usage: ./download_data.sh <article_id> <target_dir>

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <article_id> <target_dir> [version]"
    exit 1
fi

ARTICLE_ID="$1"
TARGET_DIR="$2"
VERSION="$3"

echo "Launching Python-based Figshare downloader..."
python3 "$(dirname "$0")/download_and_prep.py" "${ARTICLE_ID}" "${TARGET_DIR}" "${VERSION}"

echo "Data acquisition complete."
