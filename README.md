# Reproducibility Review: Paper-033

This directory contains the isolated review environment for paper-033: *Wheelchair Routing Graph Construction and Analysis for Graz*.

## Directory Structure

- `containers/`: Dockerfiles and Apptainer definitions for the reproduction runtime.
- `report/`: The reproducibility report (`reproreview.Rmd`) and associated evidence.
- `runs/`: Output directory for clean reproduction runs (original source files remain untouched).
- `logs/`: Build and execution logs.
- `metadata/`: Scope definitions, dependency manifests, and known deviations.
- `scripts/`: Wrapper scripts for database initialization, data import, and notebook execution.

## Reproducibility Verdict

The reproduction study focuses on the Graz-only pipeline. See `metadata/scope.md` for details on what is included and excluded.

## Quick Start (Conceptual)

```bash
# Initialize and run reproduction
./scripts/init-db.sh
./scripts/run-setup.sh
./scripts/run-notebooks.sh
```
