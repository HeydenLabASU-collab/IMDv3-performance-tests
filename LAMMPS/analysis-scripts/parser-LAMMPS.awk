BEGIN {
    data["JobSubmitDateTime"] = "N/A"
    data["JobStartDateTime"] = "N/A"
    data["MDStartDateTime"] = "N/A"
    data["MDEndDateTime"] = "N/A"
    data["ClusterName"] = "N/A"
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

    frequency = 0
    if (match(runDir, /frequency-([^/]+)/, pathMatch)) {
        frequency = pathMatch[1]
    }
}

function hms_to_seconds(hms, fields) {
    split(hms, fields, ":")
    if (length(fields) == 3) {
        return (fields[1] * 3600) + (fields[2] * 60) + fields[3]
    }
    if (length(fields) == 2) {
        return (fields[1] * 60) + fields[2]
    }
    return hms
}

# data to be read from LAMMPS output
/using [0-9]+ OpenMP thread\(s\) per MPI task/ {
    data["OpenMPthreadsperNode"] = $2
}
/will use up to [0-9]+ GPU\(s\) per node/ {
    data["nGPUused"] = $5
}
/^  [0-9]+ by [0-9]+ by [0-9]+ MPI processor grid/ {
    mpiTasks = $1 * $3 * $5
    data["MPItasksperNode"] = mpiTasks
}
/Waiting for IMD connection on port/ {
    data["IMDfreqPositions"] = $NF
}
/Time step[[:space:]]*:/ {
    data["MDintstep"] = $NF
}
/^[[:space:]]*Step[[:space:]]+Temp[[:space:]]+E_pair/ {
    thermoBlock = 1
    next
}
thermoBlock && /^[[:space:]]*[0-9]+[[:space:]]+/ {
    currentStep = $1 + 0
    if (thermoStepCount == 0) {
        firstThermoStep = currentStep
    } else if (thermoStepCount == 1) {
        data["FileIOfreqLog"] = currentStep - firstThermoStep
    }
    thermoStepCount++
}
/Loop time of/ {
    data["runTime"] = $4
    data["nMDstep"] = $9
}
/Performance:/ && /timesteps\/s/ {
    data["performance"] = $4
}
/CPU use with [0-9]+ MPI tasks x [0-9]+ OpenMP threads/ {
    if (match($0, /CPU use with[[:space:]]+([0-9]+)[[:space:]]+MPI tasks x[[:space:]]+([0-9]+)[[:space:]]+OpenMP threads/, counts)) {
        data["MPItasksperNode"] = counts[1]
        data["OpenMPthreadsperNode"] = counts[2]
    }
}
/Total wall time:/ {
    totalWallSeen = 1
    data["totalWallTime"] = hms_to_seconds($NF)
}

# data to be read from job info log
/Job Submitted:/ {data["JobSubmitDateTime"] = $NF}
/Job Started:/ {data["JobStartDateTime"] = $NF}
/MD Started:/ {data["MDStartDateTime"] = $NF}
/MD Ended:/ {data["MDEndDateTime"] = $NF}
/Cluster Name:/ {data["ClusterName"] = $NF}
/Number of Nodes:/ {
    data["nNodereq"] = $NF
    data["nNodeused"] = $NF
}
/Node List:/ {
    data["NodeNameList"] = $NF
    data["NodeNameused"] = $NF
}
/Number of GPUs:/ {data["nGPUreq"] = $NF}
/GPU Type:/ {data["GPUtypereq"] = $NF}
/GPU IDs:/ {data["GPUIDList"] = $NF}
/Number of CPUs:/ {data["nCPUreq"] = $NF}
/CPU ID List:/ {data["CPUIDList"] = $NF}
/Type of Simulation:/ {data["SimType"] = $NF}
/Job Purpose:/ {data["RunPurpose"] = $NF}
/Type of Run:/ {data["RunType"] = $NF}

END {
    if (data["GPUtypeused"] == "N/A" && data["GPUtypereq"] != "N/A") {
        data["GPUtypeused"] = data["GPUtypereq"]
    }
    if (data["GPUIDsused"] == "N/A" && data["GPUIDList"] != "N/A") {
        data["GPUIDsused"] = data["GPUIDList"]
    }
    if (data["nGPUused"] == "N/A" && data["nGPUreq"] != "N/A") {
        data["nGPUused"] = data["nGPUreq"]
    }

    if (data["MPItasksperNode"] != "N/A" && data["OpenMPthreadsperNode"] != "N/A") {
        data["nCPUused"] = (data["MPItasksperNode"] + 0) * (data["OpenMPthreadsperNode"] + 0)
    } else if (data["nCPUreq"] != "N/A") {
        data["nCPUused"] = data["nCPUreq"]
    }

    if (data["SimType"] == "fileio") {
        data["FileIOfreqPositions"] = frequency
    } else if (data["SimType"] == "fileio-3") {
        data["FileIOfreqPositions"] = frequency
        data["FileIOfreqVelocities"] = frequency
        data["FileIOfreqForces"] = frequency
    } else if (data["SimType"] == "fileio-xtc" || data["SimType"] == "fileio-dcd") {
        data["FileIOfreqPositions"] = frequency
    } else if (data["SimType"] == "streaming") {
        data["IMDfreqPositions"] = frequency
        data["PosWrap"] = 1
    } else if (data["SimType"] == "streaming-3") {
        data["IMDfreqPositions"] = frequency
        data["IMDfreqVelocities"] = frequency
        data["IMDfreqForces"] = frequency
        data["PosWrap"] = 1
    }

    if (!totalWallSeen) {
        data["performance"] = "NaN"
        data["stdevperformance"] = "NaN"
    }

    printf("%s, ", data["JobSubmitDateTime"])
    printf("%s, ", data["JobStartDateTime"])
    printf("%s, ", data["MDStartDateTime"])
    printf("%s, ", data["MDEndDateTime"])
    printf("%s, ", data["ClusterName"])
    printf("%s, ", data["nNodereq"])
    printf("%s, ", data["NodeNameList"])
    printf("%s, ", data["nGPUreq"])
    printf("%s, ", data["GPUIDList"])
    printf("%s, ", data["GPUtypereq"])
    printf("%s, ", data["nCPUreq"])
    printf("%s, ", data["CPUIDList"])
    printf("%s, ", data["SimType"])
    printf("%s, ", data["RunPurpose"])
    printf("%s, ", data["RunType"])
    printf("%s, ", data["nNodeused"])
    printf("%s, ", data["NodeNameused"])
    printf("%s, ", data["nGPUused"])
    printf("%s, ", data["GPUtypeused"])
    printf("%s, ", data["GPUIDsused"])
    printf("%s, ", data["nCPUused"])
    printf("%s, ", data["CPUIDsused"])
    printf("%s, ", data["MPItasksperNode"])
    printf("%s, ", data["OpenMPthreadsperNode"])
    printf("%s, ", data["FileIOfreqLog"])
    printf("%s, ", data["FileIOfreqBox"])
    printf("%s, ", data["FileIOfreqPositions"])
    printf("%s, ", data["FileIOfreqVelocities"])
    printf("%s, ", data["FileIOfreqForces"])
    printf("%s, ", data["IMDfreqTime"])
    printf("%s, ", data["IMDfreqEnergies"])
    printf("%s, ", data["IMDfreqBox"])
    printf("%s, ", data["IMDfreqPositions"])
    printf("%s, ", data["IMDfreqVelocities"])
    printf("%s, ", data["IMDfreqForces"])
    printf("%s, ", data["PosWrap"])
    printf("%s, ", data["MDintstep"])
    printf("%s, ", data["nMDstep"])
    printf("%s, ", data["runTime"])
    printf("%s, ", data["performance"])
    printf("%s\n", data["stdevperformance"])
}