#!/usr/bin/env bash

#SBATCH --job-name=multicore-namd-resident
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH -G a100:1
#SBATCH --time=00:30:00
#SBATCH --output=multicore_namd_resident_%j.out

# Set version: vanilla or imdv3 (can override via: VERSION=vanilla sbatch script.sh)
VERSION=${VERSION:-imdv3}

module purge
# module load gcc-12.1.0-gcc-11.2.0
module load gcc-11.2.0-gcc-11.2.0
module load cmake/3.30.2
# module load cuda-12.9.0-gcc-12.1.0
module load cuda-11.7.0-gcc-11.2.0

CUDA_ROOT="${CUDA_HOME:-${CUDA_ROOT}}"
if [[ -z "$CUDA_ROOT" ]]; then
    echo "CUDA_ROOT is not set by the module. Exiting." >&2
    exit 1
fi

# Project root - GROMACS source directory
PROJECT_ROOT="$PWD/../gromacs"

BUILD_DIR="$PWD/../bin/build-gpu"
BIN_DIR="$PWD/../bin"
EXEC_NAME="gmx_gpu_${VERSION}"

# Clean up old build
rm -rf "$BUILD_DIR"

mkdir -p "$BIN_DIR" "$BUILD_DIR"

# Checkout the appropriate branch
cd "$PROJECT_ROOT"
git checkout ${VERSION}-benchmarking

# 1) Configure GROMACS to build in BUILD_DIR with GPU acceleration
cd "$BUILD_DIR"
cmake "$PROJECT_ROOT" \
    -DCMAKE_BUILD_TYPE=Release \
    -DGMX_MPI=ON \
    -DGMX_GPU=CUDA \
    -DGMX_CUDA_TARGET_SM=80 \
    -DGMX_BUILD_OWN_FFTW=ON \
    -DREGRESSIONTEST_DOWNLOAD=ON

# 2) Build in BUILD_DIR
make -j4
make check

make install