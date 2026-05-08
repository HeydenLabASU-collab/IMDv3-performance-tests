BEGIN {
    data["JobSubmitDateTime"] = "N/A"
    data["JobStartDateTime"] = "N/A"
    data["MDJobStartDateTime"] = "N/A"
    data["MDEndDateTime"] = "N/A"
    data["ClusterName"] = "sol"
    data["nNodereq"] = "N/A"
    data["NodeNameList"] = "N/A"
    data["nGPUreq"] = "N/A"
    data["GPUIDList"] = "N/A"
    data["GPUtypereq"] = "N/A"
    data["nCPUreq"] = "N/A"
    data["CPUIDList"] = "N/A"
    data["SimType"] = "N/A"
    data["RunPurpose"] = "N/A"
    data["RunType"] = "N/A"
    data["nNodeused"] = "N/A"
    data["NodeNameused"] = "N/A"
    data["nGPUused"] = "N/A"
    data["GPUtypeused"] = "N/A"
    data["GPUIDsused"] = "N/A"
    data["nCPUused"] = "N/A"
    data["CPUIDsused"] = "N/A"
    data["MPItasksperNode"] = "N/A"
    data["OpenMPthreadsperNode"] = "N/A"
    data["FileIOfreqLog"] = 0
    data["FileIOfreqBox"] = 0
    data["FileIOfreqPositions"] = 0
    data["FileIOfreqVelocities"] = 0
    data["FileIOfreqForces"] = 0
    data["IMDfreqTime"] = 0
    data["IMDfreqEnergies"] = 0
    data["IMDfreqBox"] = 0
    data["IMDfreqPositions"] = 0
    data["IMDfreqVelocities"] = 0
    data["IMDfreqForces"] = 0
    data["PosWrap"] = "N/A"
    data["MDintstep"] = "N/A"
    data["nMDstep"] = "N/A"
    data["runTime"] = "N/A"
    data["performance"] = "N/A"
    data["stdevperformance"] = "N/A"
}

# data to be read from NAMD output file
/^Info:[[:space:]]+[0-9]+[[:space:]]+NAMD/ {
    data["NodeNameList"] = $(NF-1)
    data["NodeNameused"] = $(NF-1)
}
/Info: Running on/ && /processors/ {
    # In SMP mode nCPUused is already set from the Charm++ SMP line (PEs + comm threads);
    # only fall back to this line when not in SMP mode.
    if (!smp_mode) {
        data["nCPUreq"]        = $4
        data["nCPUused"]       = $4
        data["MPItasksperNode"]  = $6
    }
    data["nNodereq"]  = $8
    data["nNodeused"] = $8
}
# whenever a GPU is bound, bump the counter
/binding to CUDA device/ {
    gpuCount++

    if ( match($0, /device[[:space:]]+([0-9]+)/, idarr) ) {
        data["GPUIDsused"] = idarr[1]
    }

    # match anything inside single‐quotes (including the quotes themselves)
    if ( match($0, /'[^']+'/, arr) ) {
        data["GPUtypeused"] = arr[0]
    }
}
/^Charm\+\+> Running in SMP mode:/ {
    # "Charm++> Running in SMP mode: P processes, N worker threads (PEs) + C comm threads per process, T PEs total"
    # $6=P (processes), $8=N (PEs/worker threads per proc), $13=C (comm threads per proc)
    smp_procs     = $6 + 0
    smp_pe_per    = $8 + 0
    smp_comm_per  = $13 + 0
    data["MPItasksperNode"]       = smp_procs
    data["OpenMPthreadsperNode"]  = smp_pe_per
    data["nCPUused"]              = (smp_pe_per + smp_comm_per) * smp_procs
    data["nCPUreq"]               = data["nCPUused"]
    smp_mode = 1
}
/^Charm\+\+> Running in Multicore mode:/ {data["OpenMPthreadsperNode"] = $6}
/Info: TIMESTEP/ {data["MDintstep"] = $NF}
/Info: NUMBER OF STEPS/ {data["nMDstep"] = $NF}
/ENERGY OUTPUT STEPS/ {data["FileIOfreqLog"] = $NF}
/Info: INTERACTIVE MD FREQ/ {imdFreq = $NF}
/Info: INTERACTIVE MD WILL SEND THE FOLLOWING/ {
    imdSend = 1
    next
}
imdSend && /Info: / {
    if      ($0 ~ /Info: TIME$/)                           data["IMDfreqTime"]       = imdFreq
    else if ($0 ~ /Info: ENERGIES$/)                       data["IMDfreqEnergies"] = imdFreq
    else if ($0 ~ /Info: BOX DIMENSIONS$/)                 data["IMDfreqBox"]        = imdFreq
    else if ($0 ~ /Info: WRAPPED COORDINATES$/) {
        data["IMDfreqPositions"] = imdFreq
        data["PosWrap"]          = 1
    }
    else if ($0 ~ /Info: UNWRAPPED COORDINATES$/) {
        data["IMDfreqPositions"] = imdFreq
        data["PosWrap"]          = 0
    }
    else if ($0 ~ /Info: VELOCITIES$/)                     data["IMDfreqVelocities"] = imdFreq
    else if ($0 ~ /Info: FORCES$/) {
        data["IMDfreqForces"]     = imdFreq
        imdSend = 0
    }
}
/DCD FREQUENCY/ {data["FileIOfreqPositions"] = $NF}
/DCD FILE WILL CONTAIN UNIT CELL DATA/ {data["FileIOfreqBox"] = data["FileIOfreqPositions"]}
# /XST FREQUENCY/ {data["FileIOfreqBox"] = $NF}
/VELOCITY DCD FREQUENCY/ {data["FileIOfreqVelocities"] = $NF}
/FORCE DCD FREQUENCY/ {data["FileIOfreqForces"] = $NF}
/WallClock/ && /CPUTime/ {data["runTime"] = $2}
/PERFORMANCE/ && /averaging/ {
    data["performance"] = $4
    data["stdevperformance"] = $NF
}
/End of program/ {programEnded = 1}

# data to be read from job_info.log (submission script output)
/Job Submitted/ {data["JobSubmitDateTime"] = $NF}
/Job Started/ {data["JobStartDateTime"] = $NF}
/MD Started/ {data["MDJobStartDateTime"] = $NF}
/MD Ended/ {data["MDEndDateTime"] = $NF}
/Cluster Name/ {data["ClusterName"] = $NF}
/Number of Nodes requested/ {data["nNodereq"] = $NF}
/Node Name List/ {data["NodeNameList"] = $NF}
/Number of GPUs requested/ {data["nGPUreq"] = $NF}
/GPU type requested/ {data["GPUtypereq"] = $NF}
/GPU IDs/ {data["GPUIDList"] = $NF}
/Number of CPUs requested/ {data["nCPUreq"] = $NF}
/CPU ID/ {data["CPUIDList"] = $NF}
/Type of Simulation/ {data["SimType"] = $NF}
/Purpose of the job/ {data["RunPurpose"] = $NF}
/Type of Run/ {data["RunType"] = $NF}

END {
    if (!programEnded) {
        data["performance"] = "NaN"
        data["stdevperformance"] = "NaN"
    }
    printf("%s, ",data["JobSubmitDateTime"])
    printf("%s, ",data["JobStartDateTime"])
    printf("%s, ",data["MDJobStartDateTime"])
    printf("%s, ",data["MDEndDateTime"])
    printf("%s, ",data["ClusterName"])
    printf("%s, ",data["nNodereq"])
    printf("%s, ",data["NodeNameList"])
    printf("%s, ",data["nGPUreq"])
    printf("%s, ",data["GPUIDList"])
    printf("%s, ",data["GPUtypereq"])
    printf("%s, ",data["nCPUreq"])
    printf("%s, ",data["CPUIDList"])
    printf("%s, ",data["SimType"])
    printf("%s, ",data["RunPurpose"])
    printf("%s, ",data["RunType"])
    printf("%s, ",data["nNodeused"])
    printf("%s, ",data["NodeNameused"])
    if (gpuCount > 0) {
        data["nGPUused"] = gpuCount
    }
    printf("%s, ",data["nGPUused"])
    printf("%s, ",data["GPUtypeused"])
    printf("%s, ",data["GPUIDsused"])
    printf("%s, ",data["nCPUused"])
    printf("%s, ",data["CPUIDsused"])
    printf("%s, ",data["MPItasksperNode"])
    printf("%s, ",data["OpenMPthreadsperNode"])
    printf("%s, ",data["FileIOfreqLog"])
    printf("%s, ",data["FileIOfreqBox"])
    printf("%s, ",data["FileIOfreqPositions"])
    printf("%s, ",data["FileIOfreqVelocities"])
    printf("%s, ",data["FileIOfreqForces"])
    printf("%s, ",data["IMDfreqTime"])
    printf("%s, ",data["IMDfreqEnergies"])
    printf("%s, ",data["IMDfreqBox"])
    printf("%s, ",data["IMDfreqPositions"])
    printf("%s, ",data["IMDfreqVelocities"])
    printf("%s, ",data["IMDfreqForces"])
    printf("%s, ",data["PosWrap"])
    printf("%s, ",data["MDintstep"])
    printf("%s, ",data["nMDstep"])
    printf("%s, ",data["runTime"])
    printf("%s, ",data["performance"])
    printf("%s\n",data["stdevperformance"])
}