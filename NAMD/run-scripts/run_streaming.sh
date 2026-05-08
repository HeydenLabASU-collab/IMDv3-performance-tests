#!/usr/bin/env bash

module load mamba
source deactivate
source activate imdclient-new

# Avoid ~/.local packages shadowing the conda env and pin python to the env.
export PYTHONNOUSERSITE=1
if [[ -n "${CONDA_PREFIX:-}" && -x "${CONDA_PREFIX}/bin/python3" ]]; then
    PYTHON_BIN="${CONDA_PREFIX}/bin/python3"
else
    PYTHON_BIN="$(command -v python3)"
fi

# Function to expand a CPU list (e.g., "1-2,20-21,42-45") into an array of individual cores
expand_cpu_list() {
    local list="$1"
    local expanded=()
    IFS=',' read -ra ranges <<< "$list"
    for range in "${ranges[@]}"; do
        if [[ "$range" == *"-"* ]]; then
            IFS='-' read -r start end <<< "$range"
            for (( i=start; i<=end; i++ )); do
                expanded+=("$i")
            done
        else
            expanded+=("$range")
        fi
    done
    echo "${expanded[@]}"
}

# Resolve allocated CPU IDs from thisjob or SLURM.
cpu_ids=$(thisjob | grep CPU_IDs | sed -E 's/.*CPU_IDs=([^ ]+).*/\1/')
if [[ -n "$cpu_ids" ]]; then
    echo "Using CPU_IDs from thisjob: $cpu_ids"
    allocated=($(expand_cpu_list "$cpu_ids"))
else
    # Fallback: Ensure SLURM_JOB_CPUS_LIST is set
    if [[ -z "$SLURM_JOB_CPUS_LIST" ]]; then
        echo "SLURM_JOB_CPUS_LIST is not set."
        exit 1
    fi
    allocated=($(expand_cpu_list "$SLURM_JOB_CPUS_LIST"))
fi

# Input parameters
# Usage: ./script.sh <NAMD_CORES> <GPU_DEVICE> <PYTHON_CORES> <n_runs> <typeprod> <COMMON_LOG> <pos_freq> <vel_freq> <force_freq> <box_freq> [MODE] [TASKS] [WORKERS] [EXEC_NAME] [USE_GPU] [INPUT_FILE] [SIM_LABEL]
NAMD_CORES="$1"    # Total cores (for multicore) or total reserved for NAMD (for mpi_smp)
GPU_DEVICE="$2"    # GPU device to use
PYTHON_CORES="$3"  # Number of CPU cores for client.py
n_runs="$4"        # Number of runs
typeprod="$5"      # Type of production (optimization/performance)
COMMON_LOG="$6"    # Common log information
pos_freq="$7"      # Frequency for position output
vel_freq="$8"      # Frequency for velocity output
force_freq="$9"    # Frequency for force output
box_freq="${10}"   # Frequency for box output
MODE="${11:-multicore}"
TASKS="${12:-1}"
WORKERS="${13:-0}"
EXEC_NAME="${14:-bin/namd3_IMDv3_gpu_mc}"
USE_GPU="${15:-1}"
INPUT_FILE="${16:-input/step5_production_streaming.inp}"
INPUT_PY_FILE="${17:-input/IMDv3-client.py}"
SIM_LABEL="${18:-streaming}"  # folder label: streaming or streaming-3

# Use the max requested stream frequency.
imd_freq=$(( pos_freq > vel_freq ? (pos_freq > force_freq ? (pos_freq > box_freq ? pos_freq : box_freq) : (force_freq > box_freq ? force_freq : box_freq)) : (vel_freq > force_freq ? (vel_freq > box_freq ? vel_freq : box_freq) : (force_freq > box_freq ? force_freq : box_freq)) ))

# Check if enough cores are allocated
total_allocated=${#allocated[@]}
if [[ "$MODE" == *"mpi_smp"* ]]; then
    namd_required=$((TASKS * (WORKERS + 1)))
else
    namd_required=$NAMD_CORES
fi
required=$((namd_required + PYTHON_CORES))
if (( total_allocated < required )); then
    echo "Not enough allocated cores. Allocated: $total_allocated, Required: $required"
    exit 1
fi

# Build core lists for NAMD and Python.
if [[ "$MODE" == *"mpi_smp"* ]]; then
    total_cores=$((TASKS * (WORKERS + 1)))
else
    total_cores="$NAMD_CORES"
    TASKS=0
    WORKERS=$NAMD_CORES
fi
namd_cores_array=("${allocated[@]:0:total_cores}")
python_cores_array=("${allocated[@]:total_cores:PYTHON_CORES}")

# Convert arrays to comma-separated lists.
namd_core_list=$(IFS=, ; echo "${namd_cores_array[*]}")
python_core_list=$(IFS=, ; echo "${python_cores_array[*]}")

# Variables for file names and paths
equi_prefix="step4_equilibration"
prod_prefix="step5_streaming"
namd="$EXEC_NAME"
output_dir="output/${SIM_LABEL}/${typeprod}/prod/${USE_GPU}-${TASKS}-${WORKERS}/frequency-${pos_freq}"
equi_dir="output/vanilla/performance/equil/1-0-40/run-1"

LOG_FILE="job_info_${SLURM_JOB_ID}.log"

for run in $(seq 1 "$n_runs"); do
    # Create output directory for this run.
    if [[ ! -d "${output_dir}/run-${run}" ]]; then
        mkdir -p "${output_dir}/run-${run}"
    fi

    if [[ "$namd" == /* ]]; then
        namd_cmd="$namd"
    else
        namd_cmd="./$namd"
    fi

    prod_run_input="input/${prod_prefix}_${SIM_LABEL}_run_${run}.inp"
    sed "s|^outputName.*|outputName              ../${output_dir}/run-${run}/${prod_prefix};|" "$INPUT_FILE" > "$prod_run_input"
    sed -i "s|^set inputname.*|set inputname           ../${equi_dir}/${equi_prefix};|" "$prod_run_input"
    sed -i "s/imd_frequency/${imd_freq}/g" "$prod_run_input"
    md_start_time=$(date "+%Y-%m-%dT%H:%M:%S")

    # Build NAMD command and optionally add GPU flag
    if [[ "$MODE" == *"mpi_smp"* ]]; then
        NAMD_CMD_ARGS=("$namd_cmd" +ppn "$WORKERS" +setcpuaffinity +ignoresharing)
    else
        NAMD_CMD_ARGS=("$namd_cmd" +p"$NAMD_CORES" +setcpuaffinity)
    fi

    if [[ "$USE_GPU" == "1" ]]; then
        NAMD_CMD_ARGS+=(+devices "$GPU_DEVICE")
    fi

    NAMD_CMD_ARGS+=("$prod_run_input")

    echo "[NAMD] ${NAMD_CMD_ARGS[*]}"
    "${NAMD_CMD_ARGS[@]}" > "${output_dir}/run-${run}/${prod_prefix}.out" 2>&1 &
    namd_pid=$!

    sleep 10

    echo "[PYTHON] $PYTHON_BIN $INPUT_PY_FILE ${output_dir}/run-${run}"
    "$PYTHON_BIN" "$INPUT_PY_FILE" "${output_dir}/run-${run}" > "${output_dir}/run-${run}/imdclient.out" 2>&1 &
    python_pid=$!

    wait # "$namd_pid" "$python_pid"

    md_end_time=$(date "+%Y-%m-%dT%H:%M:%S")
    rm -f "$prod_run_input"

    # Write job info log
    echo "$COMMON_LOG" > "${output_dir}/run-${run}/$LOG_FILE"
    {
        echo "Type of Simulation: ${SIM_LABEL}"
        echo "Type of Run: prod"
        echo "MD Started: $md_start_time"
        echo "MD Ended: $md_end_time"
    } >> "${output_dir}/run-${run}/$LOG_FILE"
done
