#!/usr/bin/env bash

# LAMMPS streaming production script.
# Usage: ./run_streaming_lammps.sh <n_threads> <gpu_device> <python_cores> <n_runs> <typeprod> <COMMON_LOG> <pos_freq> <vel_freq> <force_freq> <box_freq> <mode> <tasks> <workers> <exec_name> <use_gpu> <input_file> <python_client> <sim_label>

module load mamba
source activate imdclient-new

# Avoid user-site package shadowing (e.g., ~/.local) and pin python to the active conda env.
export PYTHONNOUSERSITE=1
if [[ -n "${CONDA_PREFIX:-}" && -x "${CONDA_PREFIX}/bin/python3" ]]; then
    PYTHON_BIN="${CONDA_PREFIX}/bin/python3"
else
    PYTHON_BIN="$(command -v python3)"
fi

# Input parameters
N_THREADS="${1:-2}"
GPU_DEVICE="${2:-0}"
PYTHON_CORES="${3:-2}"   # Cores for Python client
N_RUNS="${4:-1}"
TYPEPROD="${5:-production}"
COMMON_LOG="${6:-}"
POS_FREQ="${7:-1}"
VEL_FREQ="${8:-0}"
FORCE_FREQ="${9:-0}"
BOX_FREQ="${10:-0}"
MODE="${11:-kokkos}"
TASKS="${12:-1}"
WORKERS="${13:-0}"
EXEC_NAME="${14:-bin/lmp_openmp_mpi_gpu_single_imdv3}"
USE_GPU="${15:-1}"
INPUT_FILE="${16:-input/in.chain-streaming}"
PYTHON_CLIENT="${17:-input/IMDv3-client.py}"
SIM_LABEL="${18:-streaming}" # streaming or streaming-3

# Function to expand a CPU list
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

# GPU aware option for Kokkos.
gpu_aware="on"

# Get allocated CPUs
cpu_ids=$(thisjob 2>/dev/null | grep CPU_IDs | sed -E 's/.*CPU_IDs=([^ ]+).*/\1/' || echo "")
if [[ -n "$cpu_ids" ]]; then
    allocated=($(expand_cpu_list "$cpu_ids"))
else
    if [[ -z "$SLURM_JOB_CPUS_LIST" ]]; then
        allocated=($(seq 0 $(($(nproc) - 1))))
    else
        allocated=($(expand_cpu_list "$SLURM_JOB_CPUS_LIST"))
    fi
fi

# Calculate required cores
total_allocated=${#allocated[@]}
if [[ "$MODE" == "kokkos" ]]; then
    lammps_cores=$N_THREADS
    TASKS=0
    WORKERS=$N_THREADS
    threads_per_task=$((lammps_cores + PYTHON_CORES))
else
    echo "Error: Only kokkos mode is supported for streaming production."
    exit 1
fi
required=$((lammps_cores + PYTHON_CORES))

if (( total_allocated < required )); then
    echo "Warning: Not enough allocated cores. Allocated: $total_allocated, Required: $required"
fi

# Split cores: LAMMPS gets first N, Python gets remaining
lammps_cores_array=("${allocated[@]:0:lammps_cores}")
python_cores_array=("${allocated[@]:lammps_cores:PYTHON_CORES}")
lammps_core_list=$(IFS=, ; echo "${lammps_cores_array[*]}")
python_core_list=$(IFS=, ; echo "${python_cores_array[*]}")

# Calculate IMD frequency (max of all frequencies)
imd_freq=$(( POS_FREQ > VEL_FREQ ? (POS_FREQ > FORCE_FREQ ? (POS_FREQ > BOX_FREQ ? POS_FREQ : BOX_FREQ) : (FORCE_FREQ > BOX_FREQ ? FORCE_FREQ : BOX_FREQ)) : (VEL_FREQ > FORCE_FREQ ? (VEL_FREQ > BOX_FREQ ? VEL_FREQ : BOX_FREQ) : (FORCE_FREQ > BOX_FREQ ? FORCE_FREQ : BOX_FREQ)) ))

# Variables for file paths
prod_prefix="step2_production_${SIM_LABEL}"
lammps="$EXEC_NAME"
if [[ "$MODE" == "kokkos" ]]; then
    config_label="${USE_GPU}-0-${N_THREADS}"
else
    echo "Error: Only kokkos mode is supported for streaming production."
    exit 1
fi
output_dir="output/${SIM_LABEL}/${TYPEPROD}/prod/${config_label}/frequency-${imd_freq}"
LOG_FILE="job_info_${SLURM_JOB_ID}.log"
export CHECK_CPU_LIST=1

mkdir -p "${output_dir}"

for run in $(seq 1 "$N_RUNS"); do
    echo "=========================================="
    echo "Running ${SIM_LABEL} production: config=$config_label, freq=$imd_freq, run=$run"
    echo "=========================================="

    mkdir -p "${output_dir}/run-${run}"

    if [[ "$lammps" == /* ]]; then
        lammps_cmd="$lammps"
    else
        lammps_cmd="./$lammps"
    fi

    if [[ ! -x "$lammps_cmd" ]]; then
        echo "Error: LAMMPS executable not found or not executable: $lammps_cmd" >&2
        exit 1
    fi

    # Create temp input file
    prod_run_input="input/${prod_prefix}_${config_label}_freq${imd_freq}_run${run}.in"
    cp "$INPUT_FILE" "$prod_run_input"

    # Fix read_data path
    sed -i "s|^read_data[[:space:]]*.*|read_data       input/data.chain|" "$prod_run_input"

    # Set IMD frequency in the generated input.
    if grep -q "imd_frequency" "$prod_run_input"; then
        sed -i "s/imd_frequency/${imd_freq}/g" "$prod_run_input"
    fi

    md_start_time=$(date "+%Y-%m-%dT%H:%M:%S")

    echo "Expected LAMMPS cores: ${lammps_core_list}"
    echo "Expected Python cores: ${python_core_list}"

    # Run LAMMPS.
    if [[ "$MODE" == "kokkos" ]]; then
        if [[ "$USE_GPU" == "1" ]]; then
            "$lammps_cmd" -k on g 1 t "$lammps_cores" -sf kk -pk kokkos gpu/aware "$gpu_aware" newton on neigh half -in "$prod_run_input" -log "${output_dir}/run-${run}/${prod_prefix}.log" > "${output_dir}/run-${run}/${prod_prefix}.out" 2>&1 &
        else
            "$lammps_cmd" -k on t "$lammps_cores" -sf kk -pk kokkos gpu/aware "$gpu_aware" newton on neigh half -in "$prod_run_input" -log "${output_dir}/run-${run}/${prod_prefix}.log" > "${output_dir}/run-${run}/${prod_prefix}.out" 2>&1 &
        fi
    else
        echo "Error: Only kokkos mode is supported for streaming production."
        exit 1
    fi

    sleep 45 # Give LAMMPS time to start and listen on the port

    # Run Python IMD client.
    "$PYTHON_BIN" "$PYTHON_CLIENT" "${output_dir}/run-${run}" > "${output_dir}/run-${run}/imdclient.out" 2>&1 &

    wait

    md_end_time=$(date "+%Y-%m-%dT%H:%M:%S")

    # Write job info log
    echo "$COMMON_LOG" > "${output_dir}/run-${run}/$LOG_FILE"
    {
        echo "Type of Simulation: ${SIM_LABEL}"
        echo "Type of Run: prod"
        echo "MD Started: $md_start_time"
        echo "MD Ended: $md_end_time"
    } >> "${output_dir}/run-${run}/$LOG_FILE"

    rm -f "$prod_run_input"
    echo ""
done

echo "=========================================="
echo "${SIM_LABEL} production complete for config=$config_label, freq=$imd_freq"
echo "=========================================="
