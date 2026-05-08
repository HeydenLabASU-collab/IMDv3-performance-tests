BEGIN {
    month["Jan"]="01"; month["Feb"]="02"; month["Mar"]="03"
    month["Apr"]="04"; month["May"]="05"; month["Jun"]="06"
    month["Jul"]="07"; month["Aug"]="08"; month["Sep"]="09"
    month["Oct"]="10"; month["Nov"]="11"; month["Dec"]="12"

    data["JobSubmitDateTime"] = "N/A"
    data["JobStartDateTime"] = "N/A"
    data["MDStartDateTime"] = "N/A"
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
    data["FileIOfreqPositions"] = "N/A"
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

# data to be read from GROMACS output file
# Getting Start and End DateTime
/^Started mdrun on/ {
    mon = month[$7]
    day = sprintf("%02d", $8)
    data["MDStartDateTime"] = sprintf("%s-%s-%sT%s", $10, mon, day, $9)
}
/^Finished mdrun on/ {
    mon = month[$7]
    day = sprintf("%02d", $8)
    data["MDEndDateTime"]   = sprintf("%s-%s-%sT%s", $10, mon, day, $9)
}
/^Hardware detected on host/ {
    # capture the word before the colon
    if ( match($0, /^Hardware detected on host[[:space:]]+([^:]+):/, m) ) {
        data["NodeNameList"] = m[1]
        data["NodeNameused"] = m[1]
    }
}
/^Running on/ && /total/ {
    data["nNodereq"] = $3
    data["nNodeused"] = $3
    data["nCPUreq"]   = $7    # “48” cores
    data["nCPUused"]  = $7    # “48” processing units
    data["nGPUused"]  = $12   # “4” GPUs
}
/GPU selected for this run\./ {
    match($0, /([0-9]+) GPU selected for this run\./, m)
    if (m[1] != "") {
        data["nGPUreq"] = m[1]
        data["nGPUused"] = m[1]
    }
}
/Mapping of GPU IDs to/ {
    if (getline mapLine > 0) {
        # remove leading whitespace
        sub(/^[[:space:]]+/, "", mapLine)
        # now mapLine == "PP:0,PME:0"

        # strip everything through the *last* colon
        sub(/.*:/, "", mapLine)
        # mapLine == "0"

        data["GPUIDsused"] = mapLine
        data["GPUIDList"] = mapLine
    }
}
/Using [0-9]+ MPI thread/ {
    # “Using 1 MPI thread”
    data["MPItasksperNode"] = $2
}
/Using [0-9]+ OpenMP threads/ {
    data["OpenMPthreadsperNode"] = $2
}
/nstlog[[:space:]]*=/ {
    data["FileIOfreqLog"] = $NF
}
/nstxout[[:space:]]*=/ {
    data["FileIOfreqPositions"] = $NF
}
/nstvout[[:space:]]*=/ {
    data["FileIOfreqVelocities"] = $NF
}
/nstfout[[:space:]]*=/ {
    data["FileIOfreqForces"] = $NF
}
/nstxout-compressed[[:space:]]*=/ {
    if (data["FileIOfreqPositions"] == 0)
        data["FileIOfreqPositions"] = $NF
}
/IMD-nst[[:space:]]*=/ {
    imdFreq = $NF
}
/IMD-time[[:space:]]*=/ {
    if ($NF == 1)
        data["IMDfreqTime"] = imdFreq
}
/IMD-coords[[:space:]]*=/ {
    if ($NF == 1)
        data["IMDfreqPositions"] = imdFreq
}
/IMD-vels[[:space:]]*=/ {
    if ($NF == 1)
        data["IMDfreqVelocities"] = imdFreq
}
/IMD-forces[[:space:]]*=/ {
    if ($NF == 1)
        data["IMDfreqForces"] = imdFreq
}
/IMD-box[[:space:]]*=/ {
    if ($NF == 1)
        data["IMDfreqBox"] = imdFreq
}
/IMD-energies[[:space:]]*=/ {
    if ($NF == 1)
        data["IMDfreqEnergies"] = imdFreq
}
/IMD-unwrap[[:space:]]*=/ {
    data["PosWrap"] = $NF
}
/dt[[:space:]]*=/ {
    data["MDintstep"] = $NF
}
/nsteps[[:space:]]*=/ {
    data["nMDstep"] = $NF
}
/^Performance:/ {
    data["performance"] = $2
}
/^[[:space:]]*Time:/ {
    data["runTime"] = $3
}

# data to be read from job_info.log (submission script output)
/Job Submitted/ {data["JobSubmitDateTime"] = $NF}
/Job Started/ {data["JobStartDateTime"] = $NF}
/MD Started/ {data["MDStartDateTime"] = $NF}
/MD Ended/ {data["MDEndDateTime"] = $NF}
/Cluster Name/ {data["ClusterName"] = $NF}
/Requested number of nodes/ {data["nNodereq"] = $NF}
/Node Name List/ {data["NodeNameList"] = $NF}
/Requested number of GPUs/ {data["nGPUreq"] = $NF}
/GPU IDs List/ {data["GPUIDList"] = $NF}
/Requested GPU Type/ {data["GPUtypereq"] = $NF}
/Requested number of CPUs/ {data["nCPUreq"] = $NF}
/CPU IDs List/ {data["CPUIDList"] = $NF}
/Type of simulation/ {data["SimType"] = $NF}
/Purpose of the run/ {data["RunPurpose"] = $NF}
/Type of run/ {data["RunType"] = $NF}

#(data["OpenMPthreadsperNode"] != "N/A" && data["nCPUused"] != "N/A") {
#    # coerce to numbers and compare
#    if ((data["OpenMPthreadsperNode"] + 0) < (data["nCPUused"] + 0)) {
#        data["nCPUused"] = data["OpenMPthreadsperNode"]
#    }
#}

(data["OpenMPthreadsperNode"] != "N/A" && data["nCPUused"] != "N/A") {
    # coerce to numbers and compare
    data["nCPUused"] = (data["OpenMPthreadsperNode"] + 0) * (data["MPItasksperNode"] + 0)
}

END {
    printf("%s, ",data["JobSubmitDateTime"])
    printf("%s, ",data["JobStartDateTime"])
    printf("%s, ",data["MDStartDateTime"])
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