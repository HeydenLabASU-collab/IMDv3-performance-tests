#!/bin/bash

# Production
#gmx grompp -f ../GROMACS_INPUT/step5_production.mdp -o test.tpr -c step4.1_equilibration.gro -p ../GROMACS_INPUT/topol.top -n ../GROMACS_INPUT/index.ndx
#gmx mdrun -v -deffnm test -ntmpi 1 -ntomp 12 -gpu_id 0 >& production.out

for (( i=1; i<=5; i++ )); do
    run_folder="run${i}"
    mkdir -p "${run_folder}"
    cd "${run_folder}"
    
    # Prepare the simulation input
    gmx grompp -f ../../../../GROMACS_INPUT/step5_production_imdv3.mdp -o run${i}.tpr -c ../../../vanilla/min-equi/step4.1_equilibration.gro -p ../../../../GROMACS_INPUT/topol.top -n ../../../../GROMACS_INPUT/index.ndx

    # Run the simulation
    gmx mdrun -v -deffnm run${i} -ntmpi 1 -ntomp 12 -gpu_id 0 >& "run${i}_production.out"

    cd ../
done
