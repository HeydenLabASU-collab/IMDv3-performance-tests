import MDAnalysis as mda
import logging
import sys

if len(sys.argv) < 2:
    print("Usage: python3 IMDv3-client.py <argument>")
    sys.exit(1)

output_dir = sys.argv[1]

run = 1
LAMMPS_TOPOL = "input/data.chain"

logger = logging.getLogger("imdclient.IMDClient")
file_handler = logging.FileHandler(str(output_dir) + "/IMDClient.log")
formatter = logging.Formatter(
    "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)
logger.setLevel(logging.INFO)

i = 0
u = mda.Universe(LAMMPS_TOPOL, "imd://localhost:8887", topology_format="DATA", timeout=50000)
for ts in u.trajectory:
    i += 1

logger.info(f"Parsed {i} frames")
