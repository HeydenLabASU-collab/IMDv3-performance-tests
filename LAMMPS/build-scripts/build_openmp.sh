#!/usr/bin/env bash

#SBATCH --job-name=openmp
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --time=01:00:00
#SBATCH --output=openmp_%j.out

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

PROJECT_ROOT=$(pwd)/../..
BUILD_DIR="$PROJECT_ROOT/bin/build-openmp"
RUN_DIR="$PROJECT_ROOT/bin/run-openmp"
EXEC_NAME="lmp_openmp"

rm -rf "$BUILD_DIR"

mkdir -p "$BUILD_DIR" "$RUN_DIR"

cmake -S "$PROJECT_ROOT/cmake" -B "$BUILD_DIR" \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_CXX_FLAGS_RELEASE="-march=native" \
  -D CMAKE_C_FLAGS_RELEASE="-march=native" \
  -D BUILD_MPI=OFF \
  -D BUILD_OMP=ON \
  -D PKG_GPU=OFF \
  -D PKG_CHARMM=ON \
  -D PKG_CMAP=ON \
  -D PKG_KSPACE=ON \
  -D PKG_MOLECULE=ON \
  -D PKG_RIGID=ON \
  -D PKG_OPENMP=ON \
  -D PKG_EXTRA-DUMP=ON \
  -D PKG_COLVARS=ON \
  -D PKG_SHAKE=ON \
  -D PKG_MISC=ON \
  -D LAMMPS_MACHINE=openmp

cmake --build "$BUILD_DIR" -- -j4

cp "$BUILD_DIR/lmp_openmp" "$RUN_DIR/$EXEC_NAME"

# export OMP_NUM_THREADS=4
# "$RUN_DIR/$EXEC_NAME" -in "$PROJECT_ROOT/bench/in.lj" -log "$RUN_DIR/log.lammps"
