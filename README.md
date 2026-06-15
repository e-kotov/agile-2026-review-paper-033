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
Please refer to the **Execution Steps** section in `report/report.qmd` for detailed instructions on reproducing the study.

### Container Build and Distribution
To build the container locally (requires Docker and root access):

```bash
# Build from the root of the paper-033 review folder
docker build --platform linux/amd64 -t paper-033 -f containers/Dockerfile .

# Tag and push to your registry
docker tag paper-033 <your-registry>/agile-2026-paper-033:latest
docker push <your-registry>/agile-2026-paper-033:latest
```

On the cluster (Apptainer), pull the pre-built image:

```bash
module load apptainer
apptainer pull containers/paper_033.sif docker://<your-registry>/agile-2026-paper-033:latest
```
