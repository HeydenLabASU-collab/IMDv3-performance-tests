#!/usr/bin/env bash

#SBATCH --job-name=namd-mpi-gpu-offload
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4      # 4 MPI ranks
#SBATCH --cpus-per-task=1        # 1 core per MPI rank
#SBATCH -G a100:1
#SBATCH --time=02:00:00
#SBATCH --output=namd_mpi_offload_%j.out

# Multi-node variant (uncomment to use):
##SBATCH --nodes=2
##SBATCH --ntasks-per-node=4      # 4 MPI ranks per node
##SBATCH -G a100:4                # 4 GPUs per node

# ============================================================================
# PURE MPI + GPU OFFLOAD (SINGLE NODE)
# ============================================================================
# Pure MPI (no threading) with GPU Offload mode
# 4 MPI ranks (one per core) on single node
# Only non-bonded forces on GPU (slower than resident)
# For multi-node, use build_mpi_smp_gpuoffload.sh instead
# ============================================================================

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
EXEC_NAME="namd_mpi_gpuoffload_${VERSION}"

# Clean up old build
BUILD_DIR="$PWD/../bin/build-mpi-gpu-offload"
rm -rf "$BUILD_DIR"
rm -rf "$PROJECT_ROOT/Linux-x86_64-g++"

mkdir -p "$BIN_DIR" "$BUILD_DIR"

# Checkout the appropriate branch
cd "$PROJECT_ROOT"
git checkout ${VERSION}-benchmarking

# 1) Build Charm++ (pure‑MPI)
cd "$CHARM_ROOT"
rm -rf mpi-linux-x86_64-mpicxx
./build charm++ mpi-linux-x86_64 mpicxx --with-production

# 2) Configure NAMD to build in BUILD_DIR
cd "$PROJECT_ROOT"
./config "$BUILD_DIR/Linux-x86_64-g++" \
    --charm-base "$CHARM_ROOT" \
    --charm-arch mpi-linux-x86_64-mpicxx \
    --with-cuda \
    --cuda-prefix "$CUDA_ROOT"

# 3) Build in BUILD_DIR
cd "$BUILD_DIR/Linux-x86_64-g++"
gmake -j4

# 4) Copy the binary to bin directory
cp "$BUILD_DIR/Linux-x86_64-g++/namd3" "$BIN_DIR/$EXEC_NAME"
