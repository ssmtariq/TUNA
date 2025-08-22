# TUNA: Tuning Unstable and Noisy Cloud Applications

[![DOI](https://zenodo.org/badge/927388945.svg)](https://doi.org/10.5281/zenodo.14872390)

This repository contains the source code used for "TUNA: <ins>T</ins>uning <ins>U</ins>nstable and <ins>N</ins>oisy Cloud <ins>A</ins>pplications" (to appear in [EuroSys'25](https://2025.eurosys.org/accepted-papers.html#pagetop)).
TUNA is a sampling methodology that uses a few key insights to improve the quality of configurations found during system autotuning.
In particular, TUNA uses
1. An *outlier detector* to prevent unstable configurations from being learned,
2. A *noise adjustor model* to provide a more stable signal to an optimizer to learn from, and
3. *Cost concious* *multi-fidelity* tuning to improve the rate of convergence.

This code can be used to run the main experimental results from our paper. Users interested in using these techniques can make small modifications to the scripts to integrate their own target systems, particularly in `nautilus`, or in `proxy/evaluation_server.py`.

## Fetching Code

To pull the code, we use submodules for library dependencies. These commands should pull all the necessary code. Clone it one the node-10 (the 11th node) in a 11 node cloudlab xl170 cluster.

```sh
git clone git@github.com:uw-mad-dash/TUNA.git
git submodule update --init --recursive
```
OR
```sh
git clone -b development https://github.com/ssmtariq/TUNA.git
cd TUNA
git config submodule.src/MLOS.url https://github.com/jsfreischuetz/MLOS.git
git submodule update --init --recursive
cd ..
```

### Dependencies
This project has been tested on Ubuntu 20, however we believe that it should work on most versions of linux.
We use the following dependencies:

- `python3.11`
- `miniconda`
- `docker`
- `java 21`
- `fio`
- `stress-ng`
- `linux-tools`

There are additional python library dependencies listed in `/src/processing/requirements.txt`

Both the python libraries and the dependencies can be installed using scripts in `/src/processing`. For the scripts to run properly, the `mlos` conda environment must be activated.

## Source Code Structure

TUNA uses [MLOS](https://github.com/microsoft/MLOS) as it's base tuning framework, and implements a custom scheduling and sampling policy on top of it, and then selects tuners from those offered (we intend to incorporate them [upstream](https://github.com/microsoft/MLOS/issues/926) in time).
TUNA also uses [Nautilus](https://dl.acm.org/doi/pdf/10.1145/3650203.3663336) to manage and deploy the execution environment. The code here is a fork of a private library that will be released soon.

- `src`
  - `benchmarks`: Metric collection scripts
  - `client`: Orchestrator side scheduling policies
  - `MLOS`: The MLOS library. We used a specific branch that is no longer available on git, so we provide a fork that has an up to date version, with minor updates to keep it compatible with updated version of the libraries.
  - `nautilus`: Nautilus dependency. See [Paper](https://dl.acm.org/doi/pdf/10.1145/3650203.3663336).
  - `proto`: gRPC communication definition files
  - `proxy`: A worker sided proxy to forward incoming messages to nautilus
    - `executors`: worker side server to listen for incoming gRPC requests
    - `nautilus`: stub files for proper linting
  - `processing`: deployment and management scripts
  - `spaces`
    - `benchmark`: Workload definitions for nautilus
    - `dbms`: Database definitions for nautilus
    - `experiment`: Files defining how benchmarks, dbms, knobs, and params are combined
    - `knobs`: List of knob definitions
    - `params`: Machine characteristics
- `sample_configs`: contains sample tuning runs for the data that is processed in the paper. Note these are the values seen during tuning, not deployment. This also Includes a short example notebook on how to read and print an sample convergence curve.
  - `azure`: Configurations that were found in our default azure region (south central us)
    - `<target system>`: The System under Test
      - `<target_workload>`: The workload that is being targeted
      - `tpcc_gp`: TPC-C tuning runs that were run with a gaussian process optimizer
  - `azure_centralus`: Configurations found in the central us region
    - `...`
  - `cloudlab`: Configurations found on cloudlab using `c220g5` nodes
    - `...`


## Environment

![TUNA Overview](images/System.png)

The environment for TUNA requires two different types of nodes: an Orchestrator and a set of Workers. These two different types of nodes has slightly different setup instruction, found below.

All scripts are found in `src/processing`. One script that may be useful is `add_hosts.sh <hosts> <port>` as a way to add all of the hosts listed in the specified host file to the trusted hosts list. This is required for `pssh` which we use to deploy our scripts. One point of note is that you cannot have your username in the hosts file when using this script.

These scripts should work on any platform, however, we have only tested this on [Azure](https://portal.azure.com/), and [CloudLab](https://www.cloudlab.us/). We provide experiment files for `c220g5` nodes on CloudLab, and `D8s_v5` nodes in Azure. These instance types will become important later, however users can provide their own files in `./src/spaces`.

If you are trying to replicate the work found in our paper, we recommend using 10 worker nodes and 1 orchestrator node, where the 10 worker nodes are the first 10 nodes that were created. This will allow you to use our provided hosts files (`hosts.azure` or `hosts.cloudlab`). Alternatively, a custom host file can be used.

### Configuring and testing parallel-ssh on CloudLab (quick start)

To verify SSH-based orchestration before running deployment scripts:

1. **Generate a key on one worker (e.g., node10)**:

   ```sh
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
   ```
2. **Add the public key to CloudLab:**

   ```sh
   cat ~/.ssh/id_ed25519.pub
   ```

   * Copy the public key
   * Go to **CloudLab Dashboard → Manage SSH Keys → Add Key**.
   * Paste the public key into the **Key** box and click **Add Key**.
   * Wait **1–2 minutes** or click **Update Keystore** if available.
     *(CloudLab will automatically propagate the new key to all nodes of active and future experiments.)*
3. **Create a clean host file (no usernames; e.g. `hosts_clean`):**
   Example:

   ```
   hp169.utah.cloudlab.us
   hp185.utah.cloudlab.us
   ...
   ```
4. **Add hosts to SSH known\_hosts:**

   ```sh
   cd src/processing #consider current dir is /users/username/TUNA
   ./add_hosts.sh <hosts> 22
   # example
   sh add_hosts.sh ../hosts_clean 22
   ```
5. **Set environment variables on orchestrator node (e.g., in `~/.bashrc`)**:

   ```sh
   export PSSH_USER=<your_username>
   export PSSH_OPTIONS="IdentityFile=$HOME/.ssh/id_ed25519"
   source ~/.bashrc
   ```
6. **Verify with a test `parallel-ssh` command:**

   ```bash
   sudo apt-get update
   sudo apt-get install -y pssh
   parallel-ssh -i -h <hosts> hostname
   #example
   parallel-ssh -i -h ../hosts_clean hostname
   ```

### Workers

To install and copy our files, there are two commands we will need to run.

```sh
sh worker_setup_remote.sh <hosts>
#example (provide absolute path of hosts file)
bash worker_setup_remote_v2.sh /users/username/TUNA/src/hosts_clean
```

The first command will install all of the dependencies, as well as set up the environment.

```sh
bash worker_deployment.sh <hosts> <node_type>
#example (provide absolute path of hosts file)
bash worker_deployment.sh /users/username/TUNA/src/hosts_clean c220g5
#For cloud lab cluster (use appropriate machine or node types. available instance types are c220g1, c220g2, c220g5, and xl170)
bash worker_deployment_cloudlab_v2.sh /users/username/TUNA/src/hosts_clean xl170
```
The script `worker_deployment_cloudlab*.sh` will wait for **5 minutes** for the docker and ray to be ready. Will print traces as below:
```bash
[11] 05:04:35 [SUCCESS] hp186.utah.cloudlab.us
+ read -p 'Press enter to continue once docker image has been built'
Press enter to continue once docker image has been built
+ RAY_PORT=50050
+ WAIT_SECS=300
+ SLEEP_SECS=2
+ parallel-ssh -i -t 0 -h /users/ssmtariq/TUNA/src/hosts_clean 'bash -lc '\''
  deadline=$(($(date +%s) + 300))
  echo "[INFO] $(hostname): waiting for Ray Client port :50050 to listen..."
  while [ $(date +%s) -lt $deadline ]; do
    # Bash /dev/tcp attempts a TCP connect; success means port is listening.
    if bash -c "echo > /dev/tcp/127.0.0.1/50050" >/dev/null 2>&1; then
      echo "[OK]   $(hostname): Ray listening on :50050"
      exit 0
    fi
    sleep 2
  done
  echo "[ERROR] $(hostname): timed out waiting for :50050"
  exit 1
'\'''
[1] 05:07:14 [SUCCESS] hp171.utah.cloudlab.us
[INFO] node5.tuna2.cloudprof-pg0.utah.cloudlab.us: waiting for Ray Client port :50050 to listen...
[OK]   node5.tuna2.cloudprof-pg0.utah.cloudlab.us: Ray listening on :50050
```
Once the `worker_deployment.sh` or `worker_deployment_cloudlab.sh` execution is finished, check the logs `/tmp/install_session.log`, `/tmp/proxy_session.log` and the tmux `proxy` terminal session to confirm if the deployment was successful and workers are running evaluation server listening to port `50051`.

Running `cat /tmp/proxy_session.log` will show traces like below-
```bash
Working directory /datadrive
2025-08-22 05:07:51,084 INFO packaging.py:530 -- Creating a file package for local directory '.'.
2025-08-22 05:07:51,135 INFO packaging.py:358 -- Pushing file package 'gcs://_ray_pkg_cc6a49eea0ba7f94.zip' (4.36MiB) to Ray cluster...
2025-08-22 05:07:51,206 INFO packaging.py:371 -- Successfully pushed file package 'gcs://_ray_pkg_cc6a49eea0ba7f94.zip'.
SIGTERM handler is not set because current thread is not the main thread.
Server started, listening on 50051
_pkg_cc6a49eea0ba7f94.zip'.
SIGTERM handler is not set because current thread is not the main thread.
Server started, listening on 50051
```

The second command will start all of the required processes. Note that the second command will say some of the commands fail. This is expected, as they simply ensure that any previous instances of stopped and deleted before beginning the initialization process.

At some point during running this command, there will be a required interaction to specify that the docker image that is building in the background has completed. There are two options here. 
First, you can connect to one of the workers and run `sudo tmux a -t install`, and sure that the pane has completed all of its commands. 
Alternatively, you can wait around 20 minutes, and this will most likely be long enough for the image to complete building.

### Orchestrator

Building the orchestrator requires slightly more interaction from the user.

```sh
bash orchestrator_deploy.sh <orchestrator_host> 22
#example(use single hostname not a file)
bash orchestrator_deploy.sh hp171.utah.cloudlab.us 22
#For cloudlab use
bash orchestrator_deploy_cloudlab.sh hp171.utah.cloudlab.us 22
```

First, like before we will set up the environment using a deployment script. This will, again, automate the file transfer and environment setup.

Next, connect to your orchestrator node and run the following commands. Note, that the first command is `tmux`. We recommend using this as tuning runs are long running. Without `tmux` disconnects are common over `ssh`, however this is not technically required.

```sh
tmux a -t proxy #open and attach the tmux terminal "proxy" running in each worker nodes to the terminal
# To detach tmux terminal; Press Ctrl+B then D
tmux ls #list tmux terminal sessions
tmux set -g mouse on #enable mouse scrolling in tmux session
tmux kill-session -t <session_name> #terminate a specific session
```
In the orchestrator or the 11th node (e.g. node-10), run the command to create the mlos Conda environment mentioned earlier.
```sh
cd ~/TUNA
make -C src/MLOS # (only the conda-env target is required)
conda activate mlos
```

## Usage Examples

To test functionality of TUNA, create the result directory `mkdir -p /path/to/TUNA/src/results`. 
There is one main script that can be run on the orchestartor node:

```sh
python3 TUNA.py <experiment> <seed> <hosts>
```

An example of this with the parameters filled out the way we used it in the paper is as follows:

```sh
python3 TUNA.py spaces/experiment/pg16.1-tpcc-8c32m.json 1 hosts.cloudlab
```

Running this command will run a tuning run for around 8 hours. The results will be output into the results folder in .csv and .pickle file formats. These can then be rerun using `mass_reruns_v2.py`, however this is not required to get tuning results.

## Description of tuning scripts

Here we provide a brief description of each tuning script. All of the following scripts are run with the following general pattern `python3 <script> <experiment> <seed> <hosts>`, with the exception of `parallel_prior.py` which takes an additional noise command at the end of the script. An example is included in the next section.

- `mass_reruns_v2.py`: A script to rerun selected configurations for the "inference" step as described in the paper.
- `naive_measured.py`: A script to run our naive distributed tuning setup, where every configuration is run on each node. This is the script we used in our ablation study.
- `parallel_gp.py`: A script to run traditional sampling, with a gaussian process model.
- `parallel_prior.py`: A script to run traditional sampling with injected gaussian noise determined by the noise level. This script is run as follows: `python3 parallel_prior.py <experiment> <seed> <hosts> <noise>`
- `parallel.py`: A script to run the default traditional sampling baseline as described in the paper.
- `TUNA_gp.py`: A script to run TUNA with the optimizer switched out for a gaussian process model
- `TUNA_no_model.py`:The full TUNA sampling methodology without the noise adjustor model.
- `TUNA_no_outlier.py`: The full TUNA sampling methodology without the outlier detection.
- `TUNA.py`: The normal TUNA sampling script that is used throughout the paper.

## One evaluation in flight
```
┌──────────────────────────────────────────  ORCHESTRATOR  ──────────────────────────────────────────┐
│                                                                                                    │
│   Ray HEAD daemon  (global scheduler + GCS)   ◄────────┐                                           │
│   Ray DRIVER process  (created by Worker-Manager)      │  same VM                                  │
│                                                                                                    │
│   MLOS / SMAC Optimizer                                                                            │
│   (decides next <config, budget>)                                                                  │
│           │                                                                                        │
│           ▼                                                                                        │
│   Distributed / Parallel Worker-Manager                                                            │
│   (global queue, noise filter, multi-fidelity bookkeeping)                                         │
│           │                                                                                        │
│           ▼   gRPC (protobuf)  ─── one call per evaluation ────────────────────────────────────────┐
└────────────────────────────────────────────── ⇣  N E T W O R K ⇣ ──────────────────────────────────┘
                                               results flow back                                     │
┌──────────────────────────────────────────── WORKER NODE ───────────────────────────────────────────┐
│ gRPC  EvaluatorServer  (“proxy”)                                                                   │
│ – flush page-cache, timeout guard                                                                  │
│        │                                                                                           │
│        ▼                                                                                           │
│ NautilusExecutor  (DB-specific harness)                                                            │
│ – rewrites postgresql.conf / redis.conf                                                            │
│ – selects benchmark (BenchBase, YCSB, …)                                                           │
│ – **spawns a Ray actor** with those args                                                           │
│        │                                                                                           │
│        ▼                                                                                           │
│ 0 … N  Ray actors  (RunDBMSConfiguration)  ◄── scheduled by Ray head                               │
│        │   each actor owns its own NautilusExecutor                                                │
│        ▼                                                                                           │
│ docker run  --name dbms_<uuid> …   (one container **per actor**)                                   │
│ │────────────────────────────────────────────────────────────────────────────────────────────────│ │
│ │  DBMS (PostgreSQL / Redis / …) + benchmark driver + metrics collectors                         │ │
│ │────────────────────────────────────────────────────────────────────────────────────────────────│ │
│        ▲                                                                                           │
│        │  raw metrics (throughput, p99, runtime, HW counters …)                                    │
│  Ray future resolved and returned to EvaluatorServer                                               │
│        ▲                                                                                           │
│ EvaluatorServer serialises metrics  ►  gRPC reply                                                  │
└──────────────────────────────────────────── ⇣  N E T W O R K ⇣ ────────────────────────────────────┘
                                               results flow back
┌──────────────────────────────────────────  ORCHESTRATOR  ──────────────────────────────────────────┐
│ Worker-Manager updates observations  →  passes aggregated score to MLOS/SMAC  →  next suggestion…  │
└────────────────────────────────────────────────────────────────────────────────────────────────────┘


Component Hierarchy “who wraps whom”
------------------------------------
MLOS / SMAC  ← outer-most search
  ↳ Worker-Manager
      ↳ gRPC EvaluatorClient
          ↳ gRPC EvaluatorServer  (proxy on worker)
              ↳ NautilusExecutor  (DB-specific harness)
                  ↳ Ray Actor  (0…N per worker, scheduled by Ray head)
                      ↳ Docker container  (1 per actor)
                          ↳ DBMS process + benchmark
                              ↳ OS / Hardware  ← inner-most
```

### Why each layer matters

| Layer         | Adds what you’d re-implement if it disappeared                                                                                                          |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Docker**    | Reproducible environment, quick teardown; without it every run would need manual clean-up of processes, files, ports.                                   |
| **Nautilus**  | Uniform Python API for *any* DBMS/benchmark pair; without it you’d write (and maintain) different bash scripts for Postgres, Redis, NGINX…              |
| **Ray**       | Cluster scheduling, retries, resource tracking, dynamic scaling; without it you’d build your own task-queue & heartbeat logic on top of gRPC/SSH.       |
| **gRPC**      | Efficient, language-agnostic transport; you *could* replace with raw sockets or HTTP, but gRPC gives typed messages, deadlines, and streaming for free. |
| **MLOS/SMAC** | Proven Bayesian/MF optimizer; replacing it means re-coding acquisition functions, model fitting, SH-style budgeting.                                    |

So **Docker isolates each experiment**, **Nautilus knows how to execute one experiment**, **Ray spreads thousands of those experiments across a cluster**, and **MLOS/SMAC decides which experiment to run next**.
- **Ray control-plane** – the orchestrator hosts both the *Ray head daemon* (scheduler + Global Control Store) *and* the *Ray driver* process that submits tasks.
- **Concurrency** – each worker can run **0…N Ray actors and containers** simultaneously, not just one.
- **Per-actor isolation** – Every Ray actor owns its own NautilusExecutor and spins up its own `dbms_<uuid>` container, enabling fully parallel exploration.


### Scripts used for Reproducing Selected Experiments

<table>
    <tr>
        <td></td>
        <td>Description</td>
        <td>Estimated Azure Cost</td>
        <td>Tuning Commands</td>
    </tr>
    <tr>
        <td>Figure 3</td>
        <td>Run parallel tuning runs with a gaussian prior. This is used to compare the rate of convergence in a noisy environment.</td>
        <td>N/A</td>
        <td>
          <code>python3 parallel_prior.py spaces/experiment/pg16.1-epinions-c220g5.json &lt;seed&gt; &lt;hosts&gt; &lt;noise&gt;</code>
        </td>
    </tr>
    <tr>
        <td>Figure 9a</td>
        <td>Run 10 parallel tuning runs, and 10 runs using TUNA targeting the TPC-C workload on Postgres 16.1 running on Azure. Take the data that is generated from this output and rerun the data on a set of 10 new worker nodes.</td>
        <td>$320</td>
        <td>
          <code>python3 parallel.py spaces/experiment/pg16.1-epinions-8c32m.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code>python3 TUNA.py spaces/experiment/pg16.1-epinions-8c32m.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code>python3 mass_reruns_v2.py</code>
        </td>
    </tr>
    <tr>
        <td>Figure 9b</td>
        <td>Run 10 parallel tuning runs, and 10 runs using TUNA targeting the epinions workload on Postgres 16.1 running on Azure. Take the data that is generated from this output and rerun the data on a set of 10 new worker nodes.</td>
        <td>$320</td>
        <td>
          <code>python3 parallel.py spaces/experiment/pg16.1-epinions-8c32m.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code>python3 TUNA.py spaces/experiment/pg16.1-epinions-8c32m.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code>python3 mass_reruns_v2.py</code>
        </td>
    </tr>
    <tr>
        <td>Figure 9c</td>
        <td>Run 10 parallel tuning runs, and 10 runs using TUNA targeting the TPC-H workload on Postgres 16.1 running on Azure. Take the data that is generated from this output and rerun the data on a set of 10 new worker nodes.on</td>
        <td>$320</td>
        <td>
          <code>python3 parallel.py spaces/experiment/pg16.1-tpch-8c32m.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code>python3 TUNA.py spaces/experiment/pg16.1-tpch-8c32m.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code>python3 mass_reruns_v2.py</code>
        </td>
    </tr>
    <tr>
        <td>Figure 10</td>
        <td>Identical to Figure 9a, however running on a different region.</td>
        <td>$320</td>
        <td>
          <code>python3 parallel.py spaces/experiment/pg16.1-tpcc-8c32m.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code>python3 TUNA.py spaces/experiment/pg16.1-tpcc-8c32m.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code>python3 mass_reruns_v2.py</code>
        </td>
    </tr>
    <tr>
        <td>Figure 11</td>
        <td>Identical to Figure 9a, however running on CloudLab `c220g5` nodes rather than on Azure.</td>
        <td>N/A</td>
        <td>
          <code>python3 parallel.py spaces/experiment/pg16.1-tpcc-c220g5.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code>python3 TUNA.py spaces/experiment/pg16.1-tpcc-c220g5.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code>python3 mass_reruns_v2.py</code>
        </td>
    </tr>
    <tr>
        <td>Figure 12</td>
        <td>Run 10 parallel tuning runs, and 10 runs using TUNA targeting the YCSB-C workload on redis running on Azure. Take the data that is generated from this output and rerun the data on a set of 10 new worker nodes.</td>
        <td>$320</td>
        <td>
          <code>python3 parallel.py spaces/experiment/redis7.2-ycsb-8c32m-latency.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code>python3 TUNA.py spaces/experiment/redis7.2-ycsb-8c32m-latency.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code>python3 mass_reruns_v2.py`</code>
        </td>
    </tr>
    <tr>
        <td>Figure 14</td>
        <td>Identical to Figure 9a, however using a gaussian process optimizer rather than a random forest optimizer (SMAC).</td>
        <td>$320</td>
        <td>
          <code>python3 parallel_gp.py spaces/experiment/pg16.1-tpcc-8c32m.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code>python3 TUNA_gp.py spaces/experiment/pg16.1-tpcc-8c32m.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code>python3 mass_reruns_v2.py</code>
        </td>
    </tr>
    <tr>
        <td>Figure 16</td>
        <td>Identical to Figure 9a, with the outlier detector ablated.</td>
        <td>$1400</td>
        <td>
          <code>python3 TUNA.py spaces/experiment/pg16.1-epinions-8c32m.json &lt;seed&gt; &lt;hosts&gt;</code>
          <br/><br/>
          <code> python3 TUNA_no_model.py spaces/experiment/pg16.1-epinions-8c32m.json &lt;seed&gt; &lt;hosts&gt</code>
        </td>
    </tr>
</table>

## See Also

- <https://aka.ms/mlos/tuna-eurosys-dataset> - The VM noise dataset used to inform the design of TUNA.
