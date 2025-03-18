from imdclient.IMD import IMDReader
import MDAnalysis as mda
import logging
import sys

if len(sys.argv) < 2:
    print("Usage: python a.py <argument>")
    sys.exit(1)

output_dir = sys.argv[1]

run = 1
NAMD_TOPOL = "input/step3_input.pdb"

logger = logging.getLogger("imdclient.IMDClient")
file_handler = logging.FileHandler(str(output_dir) + "/IMDClient.log")
formatter = logging.Formatter(
    "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)
logger.setLevel(logging.DEBUG)

i = 0
u = mda.Universe(NAMD_TOPOL, "imd://localhost:8888")
for ts in u.trajectory:
    i += 1

logger.info(f"Parsed {i} frames")
