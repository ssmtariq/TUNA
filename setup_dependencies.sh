#!/bin/bash

set -e

echo "=== Starting Dependency Installation on Ubuntu 20.04 ==="

# Update system packages
echo ">> Updating system packages..."
sudo apt update -y && sudo apt upgrade -y
echo "✅ System updated."

# ---- Python 3.11 ----
if command -v python3.11 &>/dev/null; then
    echo "✅ Python 3.11 already installed: $(python3.11 --version)"
else
    echo ">> Installing Python 3.11..."
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt update -y
    sudo apt install -y python3.11 python3.11-venv python3.11-dev
    echo "✅ Python 3.11 installed: $(python3.11 --version)"
fi

# Set python3 alternatives (but do not change system default to 3.11)
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1 || true
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 2 || true

# ---- Miniconda ----
if [ -x "$HOME/miniconda/bin/conda" ]; then
    eval "$($HOME/miniconda/bin/conda shell.bash hook)"
    echo "✅ Miniconda already installed: $(conda --version)"
else
    echo ">> Installing Miniconda..."
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p $HOME/miniconda
    eval "$($HOME/miniconda/bin/conda shell.bash hook)"
    conda init
    source ~/.bashrc
    conda deactivate
    echo "✅ Miniconda installed: $(conda --version)"
fi

# ---- Docker ----
if command -v docker &>/dev/null; then
    echo "✅ Docker already installed: $(docker --version)"
else
    echo ">> Installing Docker..."
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu focal stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update -y
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER
    echo "✅ Docker installed: $(docker --version)"
    echo "ℹ️ Please log out and back in or run 'newgrp docker' to use Docker without sudo."
fi

# ---- Java 21 via SDKMAN ----
if command -v java &>/dev/null && java --version | grep -q "21"; then
    echo "✅ Java 21 already installed: $(java --version | head -n 1)"
else
    echo ">> Installing Java 21 via SDKMAN..."
    curl -s "https://get.sdkman.io" | bash
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk install java 21-tem || true
    echo "✅ Java installed: $(java --version | head -n 1)"
fi

# ---- fio ----
if command -v fio &>/dev/null; then
    echo "✅ fio already installed: $(fio --version)"
else
    echo ">> Installing fio..."
    sudo apt install -y fio
    echo "✅ fio installed: $(fio --version)"
fi

# ---- stress-ng ----
if command -v stress-ng &>/dev/null; then
    echo "✅ stress-ng already installed: $(stress-ng --version | head -n 1)"
else
    echo ">> Installing stress-ng..."
    sudo apt install -y stress-ng
    echo "✅ stress-ng installed: $(stress-ng --version | head -n 1)"
fi

# ---- perf ----
if command -v perf &>/dev/null; then
    echo "✅ perf already installed: $(perf --version)"
else
    echo ">> Installing linux-tools (perf)..."
    sudo apt install -y linux-tools-$(uname -r) linux-tools-common linux-tools-generic
    echo "✅ perf installed: $(perf --version)"
fi

echo -e "\n🎉 All dependencies installed or already present. Setup complete!"
