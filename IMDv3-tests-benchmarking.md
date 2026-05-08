# IMDv3 performance tests and benchmarking

### Benchmarking

We benchmark the code by comparing it against the evident alternative for streaming viz. outputting data to files. To comprehensively study any effects of streaming on performance and quantitively verify its advantage over file I/O we run the following distinct scenarios:

1. vanilla code - `vanilla`
2. IMDv3 modified code - `imdv3`
3. IMDv3 modified code with File I/O (streaming set to off) - `fileio`
4. IMDV3 modified code with streaming - `streaming`

#### Choice of System

HEWL in water

The input files for each MD engine can be found in the GitHub respoitory

#### Procedure for benchmarking

We start off by preparing the system using the CHARMM GUI Input generator. The system is prepared by putting together the HEWL and adding water molecules around it. We use the starting structures provided for the MD engines viz. GROMACS and, NAMD to run minimization and equilibration for about $0.25 ns$ followed by minimization and equilibration steps. Theses step are done for the vanilla code

The final production step is for $1 ns$ and executed for the $4$ different cases discussed above.

For LAMMPS, we choose to run a system more suitable for LAMMPS viz. system of polymer chains in a box. The input for this system was adopted from the `bench` folder of the official LAMMPS repository. The starting configuration is already well-equilibrated, so we run production runs for $50000$ time steps for the 4 different cases discussed above. The simulation happens in `lj` units and thus performance is measured in `(timesteps/s)` instead of `(ns/day)`.

#### MD engine optimization

We aim to do the benchmarking at computational resource settings that would be optimum for the system of interest. We limit ourselves to a single a100 GPU. We first test to figure out the exact number of CPUs that produces optimum performance for each MD engine. We then use the optimum settings from this step for eventual production and benchmarking.

#### Benchmarking data storage

Data stored as 2-D dataframe/array with each representing a separate data point i.e. run

Columns for the data frame are as follows

1. Date and Time Job submitted
2. Date and Time Job ran
3. Date and Time MD job started
4. Date and Time MD job ended
5. Cluster Name
6. Number of Nodes requested
7. Node Name list
8. Number of GPUs requested
9. GPU type requested
10. GPU IDs list
11. Number of CPUs requested
12. CPU ID list
13. Type of Simulation (e.g. N/A, vanilla, imdv3, fileio, streaming)
14. Purpose of Run (e.g. optimization, performance)
15. Type of Run (e.g. equil, prod)
16. Number of Nodes used
17. Node Name used
18. Number of GPUs used
19. GPU type used
20. GPU IDs used
21. Number of CPUs used
22. CPU IDs used
23. MPI tasks per node
24. OpenMP threads per task
25. Frequency of *.out file I/O
26. Frequency of File I/O — box dimensions (N/A if not outputting)
27. Frequency of File I/O — positions (N/A if not outputting)
28. Frequency of File I/O — velocities (N/A if not outputting)
29. Frequency of File I/O — forces (N/A if not outputting)
30. Frequency of streaming I/O — time (N/A if not streaming)
31. Frequency of streaming I/O — energies (N/A if not streaming)
32. Frequency of streaming I/O — box dimensions (N/A if not streaming)
33. Frequency of streaming I/O — positions (N/A if not streaming)
34. Frequency of streaming I/O — velocities (N/A if not streaming)
35. Frequency of streaming I/O — forces (N/A if not streaming)
36. Positions wrapped (yes/no → 1/0; N/A if not outputting)
37. Integration Time Step (ps)
38. Number of Steps
39. Total time of run (s)
40. Average performance (ns/day) or (timesteps/s) depending on the MD engine and system of interest
41. Standard deviation of performance (if provided)

The data for this dataframe can be extracted from log files i.e. `*.out`/`*.log` files inside the output folders. The directory structure for these is as follows: 

##### Directory structure for output

`output/type-of-prod/purpose-of-run/type-of-run/run-config/freq-config/run-*`

`run-config` is a string that contains the various computational resource configurations of interest for benchmarking like number of GPUs, MPI tasks per node, OpenMP threads per task etc. `freq-config` is a string that contains the output/streaming frequency configurations of interest for `fileio` and `streaming` runs. The other run types do not use `freq-config`.

e.g. 1. `output/vanilla/optimization/prod/1-1-12/run-2`
e.g. 2. `output/fileio/performance/prod/1-1-12/run-1/frequency-10/`

NOTE: 

equil will only be run once inside `output/vanilla/performance/equil/run-config/run-1/`

The GitHub repository only stores data relevant for the analysis and post-processing i.e `*.out` and `*.log` files

#### Parameters of interest for becnhmarking

We vary the various output frequencies and streaming frequencies to study the effect of file I/O and streaming I/O on the speed and performance of the MD engine.