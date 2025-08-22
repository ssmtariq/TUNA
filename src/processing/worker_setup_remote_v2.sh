#!/bin/bash
set -euo pipefail
trap 'echo "[ERROR] Command failed on line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

parallel-scp -h $1 requirements.txt ~/
parallel-scp -h $1 *.sh ~/

parallel-ssh -t 0 -h $1 "bash ./install_conda.sh"

# Create env if missing (fail fast; accept Anaconda TOS before create)
parallel-ssh -i -t 0 -h $1 "bash -lc '
  set -euo pipefail
  echo \"[INFO] \$(hostname): checking for env p311\"
  if ~/miniconda3/bin/conda env list | grep -q \"^p311[[:space:]]\"; then
    echo \"[OK]   \$(hostname): env p311 exists\"
  else
    echo \"[INFO] \$(hostname): accepting Anaconda TOS for default channels\"
    ~/miniconda3/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
    ~/miniconda3/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
    echo \"[INFO] \$(hostname): creating env p311 (python=3.11)\"
    ~/miniconda3/bin/conda create -n p311 python=3.11 -y
  fi
'"

# Run node_setup.sh inside the env (fail fast; unchanged logic)
parallel-ssh -i -t 0 -h $1 "bash -lc '
  set -euo pipefail
  echo \"[INFO] \$(hostname): running node_setup.sh in env p311\"
  ~/miniconda3/bin/conda run -n p311 bash ./node_setup.sh
  echo \"[OK]   \$(hostname): node_setup.sh completed\"
'"