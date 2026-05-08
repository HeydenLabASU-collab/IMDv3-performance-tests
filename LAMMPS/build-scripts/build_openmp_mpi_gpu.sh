#!/usr/bin/env bash
#SBATCH --job-name=openmp_mpi_gpu
#SBATCH --nodes=1 #2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH -G a100:1
#SBATCH --time=00:45:00
#SBATCH --output=%x_%j.out

module unload openmpi/4.1.5
module load gcc-12.1.0-gcc-11.2.0
module load microOSU/openmpi/4.1.5/7.4-cuda
module load cuda-12.9.0-gcc-12.1.0
module load cmake/3.30.2
module load fftw-3.3.10-gcc-12.1.0
module load gsl/2.8

export LIBRARY_PATH=/packages/apps/spack/21/opt/spack/linux-rocky8-zen3/gcc-12.1.0/fftw-3.3.10-al4inhytbdu5b5s5ygzsie6i5g4luvid/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/packages/apps/spack/21/opt/spack/linux-rocky8-zen3/gcc-12.1.0/fftw-3.3.10-al4inhytbdu5b5s5ygzsie6i5g4luvid/lib:$LD_LIBRARY_PATH
export C_INCLUDE_PATH=/packages/apps/gsl/2.8/include:$C_INCLUDE_PATH
export LIBRARY_PATH=/packages/apps/gsl/2.8/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/packages/apps/gsl/2.8/lib:$LD_LIBRARY_PATH
CUDA_ROOT="${CUDA_HOME:-${CUDA_ROOT}}"
if [[ -z "$CUDA_ROOT" ]]; then
    echo "CUDA_ROOT is not set by the module. Please check the CUDA module path." >&2
    exit 1
fi

# PROJECT_ROOT="$SLURM_SUBMIT_DIR"
PROJECT_ROOT=$(pwd)/../..
BUILD_DIR="$PROJECT_ROOT/bin/build-openmp-mpi-gpu"
RUN_DIR="$PROJECT_ROOT/bin/run-openmp-mpi-gpu"

# GPU precision
GPU_PREC="single"  # Options: single, double, mixed (default)

EXEC_NAME="lmp_openmp_mpi_gpu_${GPU_PREC}"

# GPU Architecture selection based on available hardware
# Uncomment the line for your target GPU:
GPU_ARCH="sm_80"          # NVIDIA A100 80GiB (recommended)
#GPU_ARCH="sm_86"         # NVIDIA A30 24GiB  
#GPU_ARCH="sm_90"         # NVIDIA GH200 (Grace Hopper)

# Kokkos Architecture selection (must match GPU_ARCH)
KOKKOS_ARCH="AMPERE80"    # For A100 (sm_80)
#KOKKOS_ARCH="AMPERE86"   # For A30 (sm_86)
#KOKKOS_ARCH="HOPPER90"   # For GH200 (sm_90)

rm -rf "$BUILD_DIR"

mkdir -p "$BUILD_DIR" "$RUN_DIR"

find "$BUILD_DIR" -maxdepth 1 ! -name 'openmp_mpi_gpu_*.out' -type f -exec rm -f {} +

# removed -ffast-math \
cmake -S "$PROJECT_ROOT/cmake" -B "$BUILD_DIR" \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_CXX_FLAGS_RELEASE="-march=native" \
  -D CMAKE_C_FLAGS_RELEASE="-march=native" \
  -D BUILD_MPI=ON \
  -D BUILD_OMP=ON \
  -D PKG_GPU=ON \
  -D PKG_KOKKOS=ON \
  -D Kokkos_ENABLE_SERIAL=ON \
  -D Kokkos_ENABLE_CUDA=ON \
  -D Kokkos_ENABLE_OPENMP=ON \
  -D Kokkos_ARCH_${KOKKOS_ARCH}=ON \
  -D CMAKE_CXX_COMPILER="$PROJECT_ROOT/lib/kokkos/bin/nvcc_wrapper" \
  -D FFT_KOKKOS=CUFFT \
  -D Kokkos_ENABLE_DEPRECATION_WARNINGS=OFF \
  -D PKG_CHARMM=ON \
  -D PKG_CMAP=ON \
  -D PKG_COLVARS=ON \
  -D PKG_SHAKE=ON \
  -D PKG_KSPACE=ON \
  -D PKG_RIGID=ON \
  -D PKG_MOLECULE=ON \
  -D PKG_OPENMP=ON \
  -D PKG_EXTRA-FIX=ON \
  -D PKG_EXTRA-DUMP=ON \
  -D PKG_MOLFILE=ON \
  -D LAMMPS_MACHINE=openmp_mpi_gpu \
  -D GPU_API=cuda \
  -D GPU_ARCH=${GPU_ARCH} \
  -D GPU_PREC=${GPU_PREC} \
  -D CUDA_TOOLKIT_ROOT_DIR="$CUDA_ROOT" \
  -D CMAKE_CUDA_COMPILER="$CUDA_ROOT/bin/nvcc"

cmake --build "$BUILD_DIR" -- -j8

cp "$BUILD_DIR/lmp_openmp_mpi_gpu" "$RUN_DIR/$EXEC_NAME"

# Tell Open MPI to use its classic OB1 PML + openib BTL
# export UCX_TLS=rc_mlx5,cma,sm,self
# export OMPI_MCA_coll_hcoll_enable=0

# export OMP_NUM_THREADS=4
# --- Diagnostic info gathering block commented out ---
# srun --export=ALL --mpi=pmix --nodes=2 --ntasks-per-node=1 --cpus-per-task=4 --cpu-bind=cores --output="$RUN_DIR/log-%t.out" \
#   /usr/bin/env bash -lc '
#    echo "---- RANK $SLURM_PROCID on $(hostname) launching LAMMPS in background ----"
#    "$RUN_DIR/$EXEC_NAME" -sf gpu -pk gpu 1 -in "$PROJECT_ROOT/bench/in.lj" -log "$RUN_DIR/log.$SLURM_PROCID.lammps" & 
#    LMPID=$!
#    echo "LAMMPS PID=$LMPID"
#    echo "Sleeping 2s to let threads spawn…"; sleep 2
#    echo "---- Inspecting thread→core binding for PID $LMPID ----"
#    taskset -pc $LMPID
#    ps -L -p $LMPID -o tid,psr,comm
#    echo "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"
#    nvidia-smi --query-gpu=index,name,utilization.gpu --format=csv
#    echo "---- now waiting for LAMMPS to finish ----"
#    wait $LMPID
#    echo "---- LAMMPS exited with code $? ----"
# '
# echo "=== DONE INSPECTING; waiting for LAMMPS to finish ==="
# wait   # wait for the backgrounded LAMMPS to complete

# --- Efficient run command for LAMMPS ---
# srun --export=ALL --mpi=pmix --nodes=2 --ntasks-per-node=1 --cpus-per-task=4 --cpu-bind=cores --output="$RUN_DIR/log-%t.out" \
#   "$RUN_DIR/$EXEC_NAME" -k on g 1 t 4 -sf kk -pk kokkos newton on neigh half -in "$PROJECT_ROOT/bench/in.lj" -log "$RUN_DIR/log.$SLURM_PROCID.lammps"

# Option 3: Hybrid GPU + Kokkos (for maximum performance on specific workloads)
# srun --export=ALL --mpi=pmix --nodes=2 --ntasks-per-node=1 --cpus-per-task=4 --cpu-bind=cores --output="$RUN_DIR/log-%t.out" \
#   "$RUN_DIR/$EXEC_NAME" -k on g 1 t 4 -sf hybrid kk gpu -pk kokkos newton on neigh half -pk gpu 1 -in "$PROJECT_ROOT/bench/in.lj" -log "$RUN_DIR/log.$SLURM_PROCID.lammps"