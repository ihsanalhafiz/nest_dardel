#!/usr/bin/env bash
#SBATCH -A naiss2024-22-1457 -p main
#SBATCH --time=00:10:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=128
#SBATCH --hint=nomultithread
#SBATCH --job-name=run_microcircuit      # Job name
#SBATCH --error=./slurm_logs/run_microcircuit_%j.err         # Error file (%j expands to jobID)
#SBATCH --output=./slurm_logs/run_microcircuit_%j.out         # Output file (%j expands to jobID)
#SBATCH --open-mode=append
#SBATCH --mail-user=ihsanalhafiz28@gmail.com
#SBATCH --mail-type=BEGIN,END,FAIL       # options: BEGIN,END,FAIL,REQUEUE,TIME_LIMIT,ALL

set -Eeuo pipefail
IFS=$'\n\t'

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export OMP_PROC_BIND=TRUE

# Ensure log directory exists (best-effort; slurm opens files earlier)
mkdir -p ./slurm_logs || true

# Re-route stdout/stderr to files that include the actual ntasks/cpus-per-task
log_suffix="n_${SLURM_NTASKS:-unknown}_c_${SLURM_CPUS_PER_TASK:-${SLURM_CPUS_ON_NODE:-unknown}}"
log_base="./slurm_logs/run_microcircuit_${log_suffix}_${SLURM_JOB_ID:-unknown}"
exec >"${log_base}.out"
exec 2>"${log_base}.err"

start_ts=$(date -Is)
echo "=== [INFO] Job starting at: ${start_ts} ==="
echo "=== [INFO] Basic job info ==="
echo "User: $(whoami)"
echo "Host: $(hostname)"
echo "Working dir: $(pwd)"
echo "SLURM_JOB_ID=${SLURM_JOB_ID:-unknown} SLURM_JOB_NAME=${SLURM_JOB_NAME:-run_microcircuit}"
echo "SLURM_NTASKS=${SLURM_NTASKS:-1} SLURM_CPUS_PER_TASK=${SLURM_CPUS_PER_TASK:-${SLURM_CPUS_ON_NODE:-unknown}}"
echo "SLURM_NODELIST=${SLURM_NODELIST:-unknown}"

echo "=== [INFO] SBATCH directives (from this script) ==="
grep '^#SBATCH' "$0" || true

#echo "=== [INFO] System and resource details ==="
#command -v lscpu >/dev/null 2>&1 && lscpu || echo "lscpu not available"
#command -v numactl >/dev/null 2>&1 && numactl --hardware || echo "numactl not available"
#command -v free >/dev/null 2>&1 && free -h || echo "free not available"
#ulimit -a || true

echo "=== [INFO] Environment snapshot (selected) ==="
echo "PATH=${PATH}"
echo "PYTHONPATH=${PYTHONPATH:-}"
echo "OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-} MKL_NUM_THREADS=${MKL_NUM_THREADS:-}"

ml PDC 
ml miniconda3

source activate /cfs/klemming/home/m/miahafiz/miahafiz_klemming/nest

echo "=== [INFO] Module list ==="
module list 2>&1 || true

echo "=== [INFO] Conda environment ==="
echo "CONDA_DEFAULT_ENV=${CONDA_DEFAULT_ENV:-}"
echo "CONDA_PREFIX=${CONDA_PREFIX:-}"
command -v conda >/dev/null 2>&1 && conda info --envs || echo "conda not available"

echo "=== [INFO] Python runtime ==="
python3 --version || true
python3 -c 'import platform,sys; print("platform:", platform.platform()); print("python:", sys.version.replace("\n"," "))' || true

echo "=== [INFO] Simulation and network parameters snapshot ==="
# Print parameters from sim_params.py and network_params.py
python3 - <<'PY' || true
import os
import sys
import pprint
import numpy as np

# Ensure this script's directory (cortical_microcircuit) is importable
script_dir = os.path.dirname(os.path.abspath(__file__))
if script_dir not in sys.path:
    sys.path.insert(0, script_dir)

pp = pprint.PrettyPrinter(width=120, compact=False, sort_dicts=True)

print("---- sim_params.py (sim_dict) ----")
try:
    import sim_params as sp
    pp.pprint(sp.sim_dict)
except Exception as e:
    print(f"[WARN] Could not import/print sim_params.sim_dict: {e}")

print("\n---- network_params.py (net_dict) ----")
try:
    import network_params as npmod
    # Make numpy printing a bit more compact and readable
    np.set_printoptions(precision=6, suppress=True)
    pp.pprint(npmod.net_dict)
except Exception as e:
    print(f"[WARN] Could not import/print network_params.net_dict: {e}")
PY

echo "=== [INFO] Launching workload ==="

set -x
srun --exclusive python3 run_microcircuit.py
set +x

end_ts=$(date -Is)
echo "=== [INFO] Job finished at: ${end_ts} ==="
