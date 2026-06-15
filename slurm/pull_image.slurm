#!/bin/bash
#SBATCH --job-name=pull-paper-033
#SBATCH --partition=scc-cpu
#SBATCH --time=00:30:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --output=slurm/logs/pull.%j.txt
#SBATCH --error=slurm/logs/pull.error.%j.txt

# Figure out the paper directory
if [ -n "$SLURM_SUBMIT_DIR" ]; then
  cd "$SLURM_SUBMIT_DIR"
fi

# Load apptainer
if ! command -v apptainer >/dev/null 2>&1; then
    module load apptainer || module load singularity || true
fi

cd containers
echo "Pulling latest image from Docker Hub: egorkotovdhub/agile-2026-paper-033:latest"
apptainer pull --force paper_033.sif docker://egorkotovdhub/agile-2026-paper-033:latest

echo "Pull complete."
