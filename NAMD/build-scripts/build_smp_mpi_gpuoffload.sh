#!/usr/bin/env bash

#SBATCH --job-name=namd-mpi-smp-offload
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1      # 1 MPI rank
#SBATCH --cpus-per-task=4        # 1 comm + 3 worker threads
#SBATCH -G a100:1
#SBATCH --time=02:00:00
#SBATCH --output=namd_smp_offload_%j.out

# Multi-node variant (uncomment to use):
##SBATCH --nodes=2
##SBATCH --ntasks-per-node=4      # 4 MPI ranks per node
##SBATCH --cpus-per-task=2        # 1 comm + 1 worker per rank
##SBATCH -G a100:4                # 4 GPUs per node

# Set version: vanilla or imdv3 (can override via: VERSION=vanilla sbatch script.sh)
VERSION=${VERSION:-imdv3}

module purge
module load gcc-12.1.0-gcc-11.2.0
module load cmake/3.30.2
module load microOSU/openmpi/4.1.5/7.4-cuda
module load cuda-12.9.0-gcc-12.1.0

CUDA_ROOT="${CUDA_HOME:-${CUDA_ROOT}}"
if [[ -z "$CUDA_ROOT" ]]; then
    echo "CUDA_ROOT is not set by the module. Exiting." >&2
    exit 1
fi

# Project root - NAMD source directory
PROJECT_ROOT="$PWD/../namd"
CHARM_ROOT="$PROJECT_ROOT/charm-8.0.0"
BIN_DIR="$PWD/../bin"
EXEC_NAME="namd_mpi_smp_gpuoffload_${VERSION}"

# Clean up old build
BUILD_DIR="$PWD/../bin/build-mpi-smp-gpu-offload"
rm -rf "$BUILD_DIR"
rm -rf "$PROJECT_ROOT/Linux-x86_64-g++"

mkdir -p "$BIN_DIR" "$BUILD_DIR"

# Checkout the appropriate branch
cd "$PROJECT_ROOT"
git checkout ${VERSION}-benchmarking

# 1) Build Charm++ with MPI+SMP
cd "$CHARM_ROOT"
rm -rf mpi-linux-x86_64-smp-mpicxx
./build charm++ mpi-linux-x86_64 mpicxx smp --with-production

# 2) Configure NAMD to build in BUILD_DIR
cd "$PROJECT_ROOT"
./config "$BUILD_DIR/Linux-x86_64-g++" \
    --charm-base "$CHARM_ROOT" \
    --charm-arch mpi-linux-x86_64-smp-mpicxx \
    --with-cuda \
    --cuda-prefix "$CUDA_ROOT" \
    --cuda-gencode arch=compute_80,code=sm_80

# 3) Build in BUILD_DIR
cd "$BUILD_DIR/Linux-x86_64-g++"
gmake -j4

# 4) Copy the binary to bin directory
cp "$BUILD_DIR/Linux-x86_64-g++/namd3" "$BIN_DIR/$EXEC_NAME"
