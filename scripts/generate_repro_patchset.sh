#!/bin/bash
# scripts/generate_repro_patchset.sh
# Generates a clean report of all surgical changes made to the author's original files.

# Paths relative to the script location
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REVIEW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ORIGINAL_SOURCE="$REVIEW_ROOT/../../paper-033/AGILE2026_OSM_Wheelchair_Routing"
REPRO_DIR="$REVIEW_ROOT/repro"

OUTPUT_FILE="$REVIEW_ROOT/repro_patches.diff"

echo "=== Reproducibility Patch Set for Paper 033 ===" > "$OUTPUT_FILE"
echo "Generated on: $(date)" >> "$OUTPUT_FILE"


echo "----------------------------------------------------------------------" >> "$OUTPUT_FILE"

# Iterate over all files in the repro directory
# Filter out binary assets and data
find "$REPRO_DIR" -type f \
    ! -path "*/DATA/*" \
    ! -name "*.ttf" \
    ! -name "*.gpkg" \
    ! -name "*.tif" \
    ! -name "*.png" \
    ! -name "*.pkl" \
    ! -name "executed_*.ipynb" \
    ! -name ".DS_Store" | while read -r repro_file; do
    
    # Get the relative path from the repro directory
    rel_path=${repro_file#$REPRO_DIR/}
    orig_file="$ORIGINAL_SOURCE/$rel_path"
    
    if [ -f "$orig_file" ]; then
        # Check if files differ
        if ! diff -q "$orig_file" "$repro_file" > /dev/null; then
            echo "" >> "$OUTPUT_FILE"
            echo "PATCH FOR: $rel_path" >> "$OUTPUT_FILE"
            echo "======================================================================" >> "$OUTPUT_FILE"
            # Generate unified diff
            diff -u --label="ORIGINAL/$rel_path" --label="MODIFIED/$rel_path" "$orig_file" "$repro_file" >> "$OUTPUT_FILE" || true
            echo "----------------------------------------------------------------------" >> "$OUTPUT_FILE"
        fi
    else
        echo "" >> "$OUTPUT_FILE"
        echo "NEW FILE (not in original source): $rel_path" >> "$OUTPUT_FILE"
        echo "======================================================================" >> "$OUTPUT_FILE"
    fi
done

echo "Patch set generated: $OUTPUT_FILE"
echo "You can share this file with the authors to show exactly what was changed for reproduction."
