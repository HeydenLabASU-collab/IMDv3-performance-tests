#!/usr/bin/env bash

#SBATCH --job-name=mpi-only-namd
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4    # 4 MPI ranks
#SBATCH --cpus-per-task=1       # one core per MPI rank
#SBATCH --time=01:00:00
#SBATCH --output=mpi_only_namd_%j.out

# Multi-node variant (uncomment to use):
##SBATCH --nodes=2
##SBATCH --ntasks-per-node=4    # 4 MPI ranks per node → total 8 ranks

# Set version: vanilla or imdv3 (can override via: VERSION=vanilla sbatch script.sh)
VERSION=${VERSION:-imdv3}

module purge
module load gcc-12.1.0-gcc-11.2.0
module load openmpi/4.1.5
module load cmake/3.30.2
module load fftw-3.3.10-gcc-12.1.0

# FFTW paths
export FFTW_PREFIX="/packages/apps/spack/21/opt/spack/linux-rocky8-zen3/gcc-12.1.0/fftw-3.3.10-al4inhytbdu5b5s5ygzsie6i5g4luvid"
export LIBRARY_PATH="$FFTW_PREFIX/lib:$LIBRARY_PATH"
export LD_LIBRARY_PATH="$FFTW_PREFIX/lib:$LD_LIBRARY_PATH"

# Project root - NAMD source directory
PROJECT_ROOT="$PWD/../namd"
CHARM_ROOT="$PROJECT_ROOT/charm-8.0.0"

BUILD_DIR="$PWD/../bin/build-mpi-only"
BIN_DIR="$PWD/../bin"

EXEC_NAME="namd_mpi_${VERSION}"

# Clean up old build
rm -rf "$BUILD_DIR"
rm -rf "$PROJECT_ROOT/Linux-x86_64-g++"

mkdir -p "$BIN_DIR" "$BUILD_DIR"

# Checkout the appropriate branch
cd "$PROJECT_ROOT"
git checkout ${VERSION}-benchmarking

# 1) Pure-MPI Charm++ build (no smp)
cd "$CHARM_ROOT"
rm -rf mpi-linux-x86_64-mpicxx
./build charm++ mpi-linux-x86_64 mpicxx --with-production

# 2) Configure NAMD to build in BUILD_DIR
cd "$PROJECT_ROOT"
./config "$BUILD_DIR/Linux-x86_64-g++" \
    --charm-base "$CHARM_ROOT" \
    --charm-arch mpi-linux-x86_64-mpicxx \
    --with-fftw3 \
    --fftw-prefix "$FFTW_PREFIX"

# 3) Build in BUILD_DIR
cd "$BUILD_DIR/Linux-x86_64-g++"
gmake -j4

# 4) Copy the binary to bin directory
cp "$BUILD_DIR/Linux-x86_64-g++/namd3" "$BIN_DIR/$EXEC_NAME"
