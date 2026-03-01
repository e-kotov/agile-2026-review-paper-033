#!/bin/bash
#SBATCH --job-name=repro-paper-033
#SBATCH --partition=scc-cpu
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --output=slurm/logs/repro.%j.txt
#SBATCH --error=slurm/logs/repro.error.%j.txt
#SBATCH --mail-user=kotov@demogr.mpg.de
#SBATCH --mail-type=ALL

# Figure out the project root and paper directory dynamically
if [ -n "$SLURM_SUBMIT_DIR" ]; then
  cd "$SLURM_SUBMIT_DIR"
fi

PAPER_DIR="$(pwd)"
PROJECT_ROOT="$(cd ../.. && pwd)"

CONTAINER_IMAGE="${PAPER_DIR}/containers/paper_033.sif"

mkdir -p slurm/logs

# Ensure the module command is available if possible
MODULE_INIT_SOURCED=0
if ! command -v module >/dev/null 2>&1; then
  for module_init in /etc/profile.d/modules.sh /etc/profile /usr/share/lmod/lmod/init/bash; do
    if [ -f "$module_init" ]; then
      . "$module_init"
      MODULE_INIT_SOURCED=1
      break
    fi
  done
fi

if command -v module >/dev/null 2>&1; then
  module purge
  module load apptainer || module load singularity || true
fi

CONTAINER_RUNTIME_BIN=""
if command -v apptainer >/dev/null 2>&1; then
  CONTAINER_RUNTIME_BIN="$(command -v apptainer)"
elif command -v singularity >/dev/null 2>&1; then
  CONTAINER_RUNTIME_BIN="$(command -v singularity)"
else
  echo "ERROR: neither apptainer nor singularity is available on the manager host." >&2
  exit 127
fi

export XDG_RUNTIME_DIR=""

# Export Apptainer environment variables
export APPTAINERENV_LC_ALL="en_US.UTF-8"
export APPTAINERENV_PGDATA="/work/repro-reviews/paper-033/pgdata"

PATHS_TO_CHECK=(
    "/home" "/local" "/mnt" "/mnt/vast-orga" "/mnt/vast-standard" "/opt/misc" "/opt/slurm" 
    "/projects" "/user_datastore_map" "/pools" "/run/munge" "/scratch" 
    "/sw/viz/jupyterhub-nhr" "/user" "/usr/local/slurm" "/var/run/dbus" 
    "/var/run/munge" "/var/spool/slurmd"
    "/etc/group" "/etc/nsswitch.conf"
    /sw /scratch-emmy /scratch-grete /scratch-scc /scratch1 /usr/users /mnt/vast-* /mnt/lustre-* /mnt/ceph-*
    "$HOME/.cache/renv" "$HOME/.local/share/renv" "$HOME/R" "$HOME/.cache/R" "$PWD"
)

for path in "/etc/slurm" "/etc/slurm/slurm.conf"; do
    if [ -e "$path" ]; then
        PATHS_TO_CHECK+=("$path")
    fi
done

if [ -f "/etc/slurm/slurm.conf" ]; then
    export APPTAINERENV_SLURM_CONF="/etc/slurm/slurm.conf"
fi

# Create a fake passwd file to satisfy Postgres initdb which needs a username for the current UID
FAKE_PASSWD=$(mktemp)
grep -v "^$(id -un):" /etc/passwd > "$FAKE_PASSWD" || true
echo "$(id -un):x:$(id -u):$(id -g)::${HOME}:/bin/bash" >> "$FAKE_PASSWD"

BIND=""
BIND="${BIND:+$BIND,}$FAKE_PASSWD:/etc/passwd:ro"

for path in "${PATHS_TO_CHECK[@]}"; do
    if [ -e "$path" ]; then
        if [[ ! ",$BIND," =~ ",$path," ]]; then
            BIND="${BIND:+$BIND,}$path"
        fi
    fi
done

# Explicitly bind PROJECT_ROOT to /work
BIND="${BIND:+$BIND,}$PROJECT_ROOT:/work"

HOST_LIBS=(
    '/usr/lib64/liblustreapi.so.1' '/usr/lib64/liblnetconfig.so.4' '/usr/lib64/libgdrapi.so.2' 
    '/usr/lib64/liblua-5.3.so' '/usr/lib64/liblua-5.3.so.0' '/usr/lib64/liblua-5.1.so.0' 
    '/usr/lib64/libmunge.so.2' '/usr/lib64/libmunge.so.2.0.0' '/usr/lib64/libjson-c.so.4' 
    '/usr/lib64/libjwt.so.1' '/usr/lib64/libyaml-0.so.2'
)

for lib in "${HOST_LIBS[@]}"; do
    if [ -e "$lib" ]; then
        BIND="${BIND:+$BIND,}$lib:/usr/lib/$(basename $lib)"
    fi
done

BIND="${BIND#,}"

echo "Starting reproduction pipeline inside $CONTAINER_IMAGE on $(hostname)"

"$CONTAINER_RUNTIME_BIN" run \
  --bind "$BIND" \
  --pwd "/work" \
  "${CONTAINER_IMAGE}" \
  /work/repro-reviews/paper-033/scripts/entrypoint.sh /work/repro-reviews/paper-033/scripts/internal_repro.sh
