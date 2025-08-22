#!/bin/bash

# ── DEBUG ────────────────────────────────────────────────────────────────
set -e          # bail on first failure
set -x          # echo every command as it runs
# ─────────────────────────────────────────────────────────────────────────

# move the requiremenst over
parallel-scp -h $1 requirements.txt ~/requirements.txt

pushd ..

cat $1

# stop and remove the previous containers (fault-tolerant)
parallel-ssh -h $1 "sudo docker ps -q -f name=dbms | grep -q . && sudo docker kill dbms || echo 'No dbms container running'"
parallel-ssh -h $1 "sudo docker ps -a -q -f name=dbms | grep -q . && sudo docker rm dbms || echo 'No dbms container to remove'"
parallel-ssh -h $1 "pgrep python3 >/dev/null && sudo pkill python3 || echo 'No python3 process to kill'"

# remove old files
parallel-ssh -h $1 "sudo rm -rf ./nautilus"
parallel-scp -r -h $1 nautilus ~/nautilus
parallel-ssh -h $1 "sudo rm -rf /opt/nautilus"
parallel-ssh -h $1 "sudo cp -r nautilus /opt/nautilus"

# remake folders
parallel-ssh -h $1 "sudo mkdir -p /opt/proxy"
parallel-ssh -h $1 "sudo mkdir -p /opt/output"

# -----------------------------------------------------------------------
# Install the docker images  (tmux session "install")
# -----------------------------------------------------------------------
parallel-ssh -h $1 "sudo tmux kill-session -t install 2>/dev/null && tmux kill-session -t install || true"
parallel-ssh -h $1 "sudo tmux new-session -d -s install \"export PATH=\\\$PATH:~/miniconda3/bin ; . ~/miniconda3/etc/profile.d/conda.sh ; conda activate p311 ; cd /opt/nautilus && python3 -u deploy.py start head deploy=cloudlab +deploy/instance_type=$2 2>&1 | tee /tmp/install_session.log\" ; sudo tmux set-option remain-on-exit on"
parallel-ssh -h $1 "sudo tmux pipe-pane  -t install -o 'cat >> /tmp/install_session.log'"

read -p "Press enter to continue once docker image has been built"

# ─────────────────────────────────────────────────────────────────────────
# BLOCK until Ray Client port (host :50050) is accepting connections
# (Replaces the previous awk-based probe that had quoting issues)
# ─────────────────────────────────────────────────────────────────────────
RAY_PORT=50050
WAIT_SECS=300
SLEEP_SECS=2
parallel-ssh -i -t 0 -h $1 "bash -lc '
  deadline=\$((\$(date +%s) + $WAIT_SECS))
  echo \"[INFO] \$(hostname): waiting for Ray Client port :$RAY_PORT to listen...\"
  while [ \$(date +%s) -lt \$deadline ]; do
    # Bash /dev/tcp attempts a TCP connect; success means port is listening.
    if bash -c \"echo > /dev/tcp/127.0.0.1/$RAY_PORT\" >/dev/null 2>&1; then
      echo \"[OK]   \$(hostname): Ray listening on :$RAY_PORT\"
      exit 0
    fi
    sleep $SLEEP_SECS
  done
  echo \"[ERROR] \$(hostname): timed out waiting for :$RAY_PORT\"
  exit 1
'"

# small settle
parallel-ssh -h $1 "sleep 2"

# copy the files over
for files in proxy proto client benchmarks
do
    parallel-scp -r -h $1 $files ~/
    parallel-ssh -h $1 "sudo rm -rf /opt/proxy/$files"
    parallel-ssh -h $1 "sudo cp -r $files /opt/proxy"
done
parallel-ssh -h $1 "sudo cp -r /opt/proxy/proxy/* /opt/proxy"
parallel-ssh -h $1 "sudo rm -rf /opt/proxy/nautilus"
parallel-ssh -h $1 "sudo mkdir /opt/proxy/nautilus"
parallel-ssh -h $1 "sudo cp -r nautilus/* /opt/proxy/"
parallel-ssh -h $1 "cd /opt/nautilus && sudo mkdir logs"

# give permissions for global folders
parallel-ssh -h $1 "sudo chmod -R 777 /opt/proxy/"
parallel-ssh -h $1 "sudo chmod -R 777 /opt/nautilus/"

# -----------------------------------------------------------------------
# start the proxy  (tmux session "proxy")
# -----------------------------------------------------------------------
parallel-ssh -h $1 "tmux kill-session -t proxy 2>/dev/null || true"
parallel-ssh -h $1 "tmux new-session -d -s proxy \"export PATH=\\\$PATH:~/miniconda3/bin ; . ~/miniconda3/etc/profile.d/conda.sh ; conda activate p311 ; cd /opt/proxy && python3 -u evaluation_server.py --dir /datadrive 2>&1 | tee /tmp/proxy_session.log\" ; tmux set-option remain-on-exit on"
parallel-ssh -h $1 "tmux pipe-pane  -t proxy  -o 'cat >> /tmp/proxy_session.log'"

echo "🛈  install logs   → /tmp/install_session.log"
echo "🛈  proxy  logs    → /tmp/proxy_session.log"

popd
