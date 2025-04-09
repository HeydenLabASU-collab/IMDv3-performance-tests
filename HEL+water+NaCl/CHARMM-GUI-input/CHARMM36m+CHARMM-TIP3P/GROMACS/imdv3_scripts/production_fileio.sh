#!/bin/bash

# Production
#gmx grompp -f ../GROMACS_INPUT/step5_production.mdp -o test.tpr -c step4.1_equilibration.gro -p ../GROMACS_INPUT/topol.top -n ../GROMACS_INPUT/index.ndx
#gmx mdrun -v -deffnm test -ntmpi 1 -ntomp 12 -gpu_id 0 >& production.out

mkdir -p performance_fileio
cd performance_fileio


for (( i=1; i<=5; i++ )); do
    run_folder="run${i}"
    mkdir -p "${run_folder}"
    #cd "${run_folder}"
    
    # Prepare the simulation input
    gmx grompp -f ../../../GROMACS_INPUT/step5_production_imdv3_fileio.mdp -o ${run_folder}/run.tpr -c ../../../GROMACS_INPUT/step4.1_equilibration.gro -p ../../../GROMACS_INPUT/topol.top -n ../../../GROMACS_INPUT/index.ndx

    # Run the simulation
    # Number of -ntmpi and -ntomp will need to multiply to the number of cores requested (e.g. 1 tmpi * 12 omp = 12 cores)
    
    gmx mdrun -v -deffnm ${run_folder}/run -ntmpi 1 -ntomp 12 -gpu_id 0 >& "${run_folder}_production.out"

    #cd ../
done
