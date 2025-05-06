#!/bin/bash
# Total cores available for the test
total_cores=12

for (( ntmpi=1; ntmpi<=total_cores; ntmpi++ )); do
    # Only consider combinations where total_cores is divisible by ntmpi
    if (( total_cores % ntmpi == 0 )); then
        ntomp=$(( total_cores / ntmpi ))
        # Create a unique folder for this combination
        run_folder="run_${ntmpi}mpi_${ntomp}omp"
        mkdir -p "${run_folder}"
        #echo "Running simulation with ${ntmpi} MPI tasks and ${ntomp} OpenMP threads in folder ${run_folder}"

        # Prepare the simulation input (adjust relative paths as needed)
        gmx grompp -f ../GROMACS_INPUT/test_production.mdp \
                   -o ${run_folder}/test_${ntmpi}mpi_${ntomp}omp.tpr \
                   -c step4.1_equilibration.gro \
                   -p ../GROMACS_INPUT/topol.top \
                   -n ../GROMACS_INPUT/index.ndx

        # Run the simulation, storing output inside the folder
        gmx mdrun -v -deffnm ${run_folder}/test_${ntmpi}mpi_${ntomp}omp \
                  -ntmpi ${ntmpi} -ntomp ${ntomp} >& ${run_folder}/production.out
    fi
done

