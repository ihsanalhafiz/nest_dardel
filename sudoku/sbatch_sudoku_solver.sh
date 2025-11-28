#!/usr/bin/env bash
#SBATCH -A naiss2024-22-1457 -p main
#SBATCH --time=00:30:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --hint=nomultithread
#SBATCH --job-name=sudoku_solver      # Job name
#SBATCH --error=./slurm_logs/sudoku_solver_%j.err         # Error file (%j expands to jobID)
#SBATCH --output=./slurm_logs/sudoku_solver_%j.out         # Output file (%j expands to jobID)
#SBATCH --open-mode=append
#SBATCH --mail-user=ihsanalhafiz28@gmail.com
#SBATCH --mail-type=BEGIN,END,FAIL       # options: BEGIN,END,FAIL,REQUEUE,TIME_LIMIT,ALL

set -Eeuo pipefail
IFS=$'\n\t'

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export OMP_PROC_BIND=TRUE

# Ensure log directory exists (best-effort; slurm opens files earlier)
mkdir -p ./slurm_logs || true

# Re-route stdout/stderr to files that encode key resource info for benching
nodes_val="${SLURM_JOB_NUM_NODES:-${SLURM_NNODES:-unknown}}"
ntpn_val="${SLURM_NTASKS_PER_NODE:-unknown}"
ntasks_val="${SLURM_NTASKS:-unknown}"
cpus_per_task_val="${SLURM_CPUS_PER_TASK:-${SLURM_CPUS_ON_NODE:-unknown}}"
log_suffix="nodes_${nodes_val}_ntpn_${ntpn_val}_ntasks_${ntasks_val}_cpt_${cpus_per_task_val}"
log_base="./slurm_logs/sudoku_solver_${log_suffix}_${SLURM_JOB_ID:-unknown}"
exec >"${log_base}.out"
exec 2>"${log_base}.err"

start_ts=$(date -Is)
echo "=== [INFO] Job starting at: ${start_ts} ==="
echo "=== [INFO] Basic job info ==="
echo "User: $(whoami)"
echo "Host: $(hostname)"
echo "Working dir: $(pwd)"
echo "SLURM_JOB_ID=${SLURM_JOB_ID:-unknown} SLURM_JOB_NAME=${SLURM_JOB_NAME:-sudoku_solver}"
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
ml openmpi
ml mpi4py
ml miniconda3

source activate /cfs/klemming/home/m/miahafiz/miahafiz_klemming/nest_nompi

echo "=== [INFO] Module list ==="
module list 2>&1 || true

echo "=== [INFO] Conda environment ==="
echo "CONDA_DEFAULT_ENV=${CONDA_DEFAULT_ENV:-}"
echo "CONDA_PREFIX=${CONDA_PREFIX:-}"
command -v conda >/dev/null 2>&1 && conda info --envs || echo "conda not available"

echo "=== [INFO] Python runtime ==="
python3 --version || true
python3 -c 'import platform,sys; print("platform:", platform.platform()); print("python:", sys.version.replace("\n"," "))' || true

# Print parameters from sudoku_solver.py (puzzle_index, noise_rate, sim_time, max_sim_time, max_iterations)
echo "=== [INFO] sudoku_solver.py simulation parameters ==="
python3 - <<'EOF'
import sudoku_solver
params = [
    ("puzzle_index", getattr(sudoku_solver, "puzzle_index", None)),
    ("noise_rate", getattr(sudoku_solver, "noise_rate", None)),
    ("sim_time", getattr(sudoku_solver, "sim_time", None)),
    ("max_sim_time", getattr(sudoku_solver, "max_sim_time", None)),
    ("max_iterations", getattr(sudoku_solver, "max_iterations", None)),
]

for name, value in params:
    print(f"{name}: {value}")
EOF

echo "=== [INFO] Launching workload ==="

set -x
srun --exclusive python3 sudoku_solver.py
set +x

end_ts=$(date -Is)
echo "=== [INFO] Job finished at: ${end_ts} ==="
