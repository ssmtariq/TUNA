PREFIX=${1:-$HOME/miniconda3}
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -u -p "$PREFIX"
rm -f Miniconda3-latest-Linux-x86_64.sh