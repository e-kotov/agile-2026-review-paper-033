# Reproducibility Review: Paper-033

This repository contains the reproducibility review for Paper 033: *OpenStreetMap Suitability Analysis for Wheelchair Routing*.

## Core Documents
- **Reproduction Report**: See \`report/report.qmd\` (rendered as \`report.pdf\`).
- **Surgical Patches**: See \`repro_patches.diff\` for the exact changes required to execute the authors' code.

## Directory Structure
- \`containers/\`: Docker and Apptainer definitions for the reproduction runtime.
- \`repro/\`: Author's notebooks and SQL scripts (baseline on \`main\`, patched on \`edits\`).
- \`scripts/\`: Automation scripts for data acquisition, execution, and reporting.
- \`slurm/\`: Job submission scripts for HPC clusters.

## Getting Started
Please refer to the **Execution Steps** section in \`report/report.qmd\` for detailed instructions on reproducing the study.
