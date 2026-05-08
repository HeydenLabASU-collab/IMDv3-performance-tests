#!/usr/bin/env bash

#SBATCH --job-name=openmp
#SBATCH --nodes=1 #2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --time=00:25:00
#SBATCH --output=%x_%j.out

module load openmpi/4.1.5
module load cmake/3.30.2
module load gcc-12.1.0-gcc-11.2.0
module load fftw-3.3.10-gcc-12.1.0
module load gsl/2.8

export LIBRARY_PATH=/packages/apps/spack/21/opt/spack/linux-rocky8-zen3/gcc-12.1.0/fftw-3.3.10-al4inhytbdu5b5s5ygzsie6i5g4luvid/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/packages/apps/spack/21/opt/spack/linux-rocky8-zen3/gcc-12.1.0/fftw-3.3.10-al4inhytbdu5b5s5ygzsie6i5g4luvid/lib:$LD_LIBRARY_PATH
export C_INCLUDE_PATH=/packages/apps/gsl/2.8/include:$C_INCLUDE_PATH
export LIBRARY_PATH=/packages/apps/gsl/2.8/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/packages/apps/gsl/2.8/lib:$LD_LIBRARY_PATH

# PROJECT_ROOT="$SLURM_SUBMIT_DIR"
PROJECT_ROOT=$(pwd)/../..
BUILD_DIR="$PROJECT_ROOT/bin/build-openmp-mpi"
RUN_DIR="$PROJECT_ROOT/bin/run-openmp-mpi"
EXEC_NAME="lmp_openmp_mpi"

rm -rf "$BUILD_DIR"

mkdir -p "$BUILD_DIR" "$RUN_DIR"

cmake -S "$PROJECT_ROOT/cmake" -B "$BUILD_DIR" \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_CXX_FLAGS_RELEASE="-march=native" \
  -D CMAKE_C_FLAGS_RELEASE="-march=native" \
  -D BUILD_MPI=ON \
  -D BUILD_OMP=ON \
  -D PKG_GPU=OFF \
  -D PKG_CHARMM=ON \
  -D PKG_CMAP=ON \
  -D PKG_SHAKE=ON \
  -D PKG_KSPACE=ON \
  -D PKG_RIGID=ON \
  -D PKG_MOLECULE=ON \
  -D PKG_OPENMP=ON \
  -D LAMMPS_MACHINE=openmp_mpi

cmake --build "$BUILD_DIR" -- -j4

cp "$BUILD_DIR/lmp_openmp_mpi" "$RUN_DIR/$EXEC_NAME"

# export OMP_NUM_THREADS=4
# srun --export=ALL --mpi=pmix --nodes=2 --ntasks-per-node=1 --cpus-per-task=4 --cpu-bind=cores --output="$RUN_DIR/log.%t.out" \
#   "$RUN_DIR/$EXEC_NAME" -in "$PROJECT_ROOT/bench/in.lj" -log "$RUN_DIR/log.%t.lammps"

