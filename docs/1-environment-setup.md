# Environment Setup

This guide walks through everything needed to build, simulate, and synthesize the CVA6 RISC-V core — from a clean machine to a working toolchain. The steps draw from all four project READMEs and are ordered to minimize backtracking.

---

## 1. System Requirements

Before cloning anything, make sure your machine actually meets the requirements. Mismatches here are the most common source of silent, hard-to-diagnose failures later.

---

### 1.1 Operating System & Filesystem

**For simulation (Verilator-based flows):**

- **OS:** Linux only. Ubuntu 20.04 or newer is recommended.
  Windows is **not supported** — not even with WSL2. You need a native Linux installation.
- **Filesystem:** The working directory must be on an **ext4** partition.
  NTFS (e.g., a mounted Windows drive) will silently break the build. If your `/home` is on NTFS, move the repo to an ext4 partition before starting.

**For Vivado synthesis only:**

- Linux (Ubuntu 20.04/22.04) **or** Windows with WSL2 are both supported.
  WSL2 support here is specific to the synthesis flow — the simulation flow still requires native Linux.

**Common pitfall:** developers who dual-boot sometimes clone the repo on a shared NTFS partition for convenience. This always ends in broken symlinks and failed submodule states. Clone on ext4, always.

---

### 1.2 Storage & RAM

| Resource | Minimum | Notes |
|---|---|---|
| Free disk space | 40 GB | Toolchain artifacts + sim outputs |
| Temp disk during build | ~8–10 GB | Reclaimed after build completes |
| RAM (simulation) | 4 GB | Build works; more headroom is better |
| RAM (Vivado synthesis) | 16 GB | Hard minimum; below this only post-synthesis flow is viable |

**Toolchain build time:** expect 1–3 hours depending on your machine. The build is CPU-bound and will saturate all cores.

**Behavioral simulation RAM issue (Vivado xsim):**
Even with 16 GB RAM, the behavioral `xsim` simulation crashes due to huge internal arrays. The verified workaround is adding a 16 GB swap file:

```bash
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

To make it persist across reboots, add to `/etc/fstab`:
/swapfile none swap sw 0 0


Post-synthesis simulation is lighter — it peaked at ~10.8 GB RAM in testing, so 16 GB physical RAM handles it without swap.

---

### 1.3 Network

A stable internet connection is required to clone the repository and its submodules, and to download the GCC toolchain sources. Partial downloads are a common failure point — the build will either fail mid-way or produce a broken toolchain with no clear error message.

**If you're accessing from Iran or another region with restricted GitHub/GNU access**, you need a working VPN or proxy configured **before** you start. This applies to:
- `git clone` and `git submodule update`
- Fetching GCC/binutils sources during toolchain build
- Any `pip install` that pulls from PyPI

Set your proxy in the environment if needed:
```bash
export https_proxy=http://127.0.0.1:<port>
export http_proxy=http://127.0.0.1:<port>
```

A failed mid-build download leaves partial artifacts that can confuse subsequent builds. If a download fails, clean the affected directory and retry from scratch rather than resuming.

---

**Once your system checks out, move on to [Section 2: Repository & Submodule Setup].**

## 2. Repository Setup

CVA6 uses Git submodules extensively, and getting the clone right the first time saves a lot of pain. A missing or partial submodule won't fail loudly here — it'll surface later as a cryptic missing-module error during synthesis or a silent Verilator abort. The steps below make sure you have a clean, fully-initialized tree before touching any toolchain.

---

### 2.1 Cloning the Repository

Two approaches, depending on your flow:

**Simulation flow (two-step):**
```bash
git clone https://github.com/openhwgroup/cva6.git
cd cva6
```

**Synthesis flow (single-step, preferred for Vivado):**
```bash
git clone --recursive https://github.com/openhwgroup/cva6.git
cd cva6
```

The `--recursive` flag clones all submodules in one shot. For the simulation flow, the Makefile manages some submodule state internally — but `--recursive` works fine for both flows regardless.

**Pinning to a known-good commit (synthesis):**

The synthesis flow is validated against a specific commit. If you're doing synthesis work, check it out before going further:

```bash
git checkout 41e30493046e7719ff59b77af5a6f0e436066a55
```

Keep this hash somewhere. If things break after a `git pull`, this is your fallback.

---

### 2.2 Initializing Submodules

If you cloned without `--recursive`, initialize explicitly:

```bash
git submodule update --init --recursive
```

This pulls in the three core submodules the project depends on:

| Submodule | Role |
|---|---|
| `axi` |s break after a `git pull`, this is your fallback.

---

### 2.2 Initializing Submodules

If you cloned without `--recursive`, initialize explicitly:

```bash
git submodule update --init --recursive
```

This pulls in the three core submodules the project depends on:

| Submodule | Role |
|---|---|
| `axi` | AXI bus protocol IPs |
| `common_cells` |e state:**

```bash
git submodule status
```

Each line should start with a space (` `) or a `+`. A leading `-` means that submodule isn't initialized yet. Re-run for just that path:

```bash
git submodule update --init --recursive -- <path/to/submodule>
```

---

**Common errors and fixes:**

**Partial clone / network drop mid-download**

Symptoms: `git submodule update` hangs, outputs a checksum error, or exits silently with missing files.

```bash
# Delete the corrupted submodule directory and retry
rm -rf <path/to/failed/submodule>
git submodule update --init --recursive
```

Make sure your VPN/proxy is active before retrying. A mid-download disconnect leaves partial state that confuses the next run — you have to delete it, not resume it.

**Synthesis fails with "missing dependencies" or Tcl errors**

If `bender script vivado` or the generated `cva6_files.tcl` throws missing-module errors, the root cause is almost always uninitialized submodules, not a Bender misconfiguration. Re-run `git submodule update --init --recursive` and regenerate the file list before debugging anything else.

**Verilator aborts with an internal error in `lzc.sv`**

Recent Verilator versions may fail with an internal assertion in `lzc.sv`. Confirm the submodule is at the right commit first (`git submodule status`). If the commit is correct, the issue is a version incompatibility — use the Verilator version the project pins rather than whatever your package manager installs.

---

**Submodules verified and clean — move on to [Section 3: Toolchain Setup].**

## 3. System Dependencies

Before building the toolchain or running any simulation, a handful of system packages need to be in place. Missing even one of these usually produces a cryptic failure deep inside a build script — not a clear "package not found" message. Install everything here upfront and you won't be chasing it later.

---

### 3.1 APT Packages

Start with the base build tools and simulation dependencies:

```bash
sudo apt-get update
sudo apt-get install cmake help2man device-tree-compiler
```

**Verify CMake version immediately after:**

```bash
cmake --version
```

The project requires CMake **3.14 or higher**. Ubuntu 20.04's default package is often older. If the version check fails:

```bash
sudo apt-get install --only-upgrade cmake
```

If upgrading via apt still gives you something older than 3.14, you'll need to install from Kitware's PPA:

```bash
wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | \
  gpg --dearmor - | sudo tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] \
  https://apt.kitware.com/ubuntu/ focal main' | \
  sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
sudo apt-get update && sudo apt-get install cmake
```

---

Next, the GCC toolchain build has its own prerequisite list. These are required to compile RISC-V GCC from source — missing any of them causes the build to fail partway through, often without a useful error:

```bash
sudo apt-get install \
  autoconf automake autotools-dev curl python3 \
  libmpc-dev libmpfr-dev libgmp-dev \
  gawk build-essential bison flex \
  texinfo gperf libtool patchutils bc \
  zlib1g-dev libexpat-dev git
```

What each group covers:

| Package group | Purpose |
|---|---|
| `libmpc-dev`, `libmpfr-dev`, `libgmp-dev` | Arbitrary-precision math — required to compile GCC itself |
| `bison`, `flex` | Parser generators used in GCC and binutils |
| `texinfo` | Documentation build tooling — GCC's build system calls it directly |
| `autoconf`, `automake`, `autotools-dev` | Build system infrastructure |
| `zlib1g-dev`, `libexpat-dev` | Compression and XML parsing for toolchain internals |

**Common pitfall:** `libmpc-dev` and friends are easy to overlook because the build proceeds fine for a while before hitting them deep in GCC's configuration phase. If you see an error like `checking for mpc_init2 in -lmpc... no`, this is why.

---

### 3.2 Python Virtual Environment

The simulation flow needs a Python virtual environment for its verification scripts and DV tooling. Set it up in the repo root after cloning:

```bash
sudo apt-get install python3-full
python3 -m venv venv_cva6
source venv_cva6/bin/activate
pip3 install -r verif/sim/dv/requirements.txt
```

The `python3-full` package bundles both `venv` and `pip` support. On minimal Ubuntu installs, `python3` alone doesn't include either.

**Activate the environment every session** before running simulation commands:

```bash
source venv_cva6/bin/activate
```

Adding it to your `.bashrc` is convenient if you're working on this project regularly, but keep in mind it affects your system's default Python environment for every shell.

---

**Known pip failure — safe to ignore:**

The `requirements.txt` install may throw errors related to random instruction generation packages. These are only needed for a specific test generation flow, not for standard simulation runs. If you see failures there, proceed — they won't affect the core simulation targets.

**If pip installs hang or fail with network errors:**

Make sure your proxy is active before running pip (see Section 1.3). PyPI is blocked in some regions and pip will silently time out rather than give a clear error:

```bash
export https_proxy=http://127.0.0.1:<port>
export http_proxy=http://127.0.0.1:<port>
pip3 install -r verif/sim/dv/requirements.txt
```

If a package installs partially and the next run fails with import errors, the cleanest fix is:

```bash
deactivate
rm -rf venv_cva6
python3 -m venv venv_cva6
source venv_cva6/bin/activate
pip3 install -r verif/sim/dv/requirements.txt
```

Don't try to repair a partial install — recreating the venv takes 30 seconds and avoids subtle version conflicts.

---

**Dependencies installed — move on to [Section 4: RISC-V Toolchain Build].**

## 4. RISC-V GCC Toolchain

The CVA6 simulation and verification flows both require a RISC-V cross-compiler. You can't use a distro package here — the project needs a specific GCC version with CVA6-specific patches applied, targeting `riscv64-unknown-elf`. The provided build script handles everything: fetching sources, applying patches, and compiling. Your job is to set the install path correctly beforehand and give the build time to finish.

Expect 1–3 hours. Don't try to shortcut it.

---

### 4.1 Build Prerequisites

Make sure the APT packages from Section 3.1 are installed before starting — especially the math libraries (`libmpc-dev`, `libmpfr-dev`, `libgmp-dev`) and the parser generators (`bison`, `flex`). The build will get through a significant portion before hitting a missing dependency, which is a frustrating place to fail.

Also confirm CMake is at 3.14 or higher:

```bash
cmake --version
```

If not, handle it now using the PPA method from Section 3.1 rather than after a failed build.

---

### 4.2 Setting the `$RISCV` Environment Variable

`$RISCV` tells the build script where to install the toolchain. Every binary ends up in `$RISCV/bin`, and the simulation flow expects this variable to be set at runtime too — not just during the build. Getting this wrong means the build succeeds but nothing finds the compiler later.

Set it before running anything:

```bash
export RISCV=$HOME/riscv
```

Then make it permanent:

```bash
echo 'export RISCV=$HOME/riscv' >> ~/.bashrc
echo 'export PATH=$RISCV/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

Verify it's set:

```bash
echo $RISCV
```

You should see your chosen path. If the output is empty, the build script will install to an undefined location and the toolchain will be unfindable.

**Path notes:**
- Avoid paths with spaces or special characters — the build system handles them poorly.
- Make sure `$HOME/riscv` (or your chosen path) has at least 2–3 GB free for the installed binaries and headers.

---

### 4.3 Building the Toolchain

With `$RISCV` set and prerequisites installed, run the build script from inside the cloned repo:

```bash
cd cva6
bash util/toolchain-builder/get-toolchain.sh
```

What the script does:
- Downloads GCC, Binutils, and Newlib sources from upstream
- Applies CVA6-specific patches
- Configures the build for `riscv64-unknown-elf`
- Compiles and installs everything to `$RISCV/bin`

To parallelize the build:

```bash
NUM_JOBS=$(nproc) bash util/toolchain-builder/get-toolchain.sh
```

This saturates all cores and meaningfully reduces build time. Leave it running — there's no interactive step.

**Resource usage during build:**

| Resource | Expected |
|---|---|
| Build time | 1–3 hours |
| Temp disk (build artifacts) | 8–10 GB (reclaimed after install) |
| RAM | ≥ 4 GB |
| Installed footprint | ~2–3 GB in `$RISCV` |

The build is CPU-bound. On a modern 8-core machine with a fast connection, expect 60–90 minutes. On older hardware or a slow network, budget 3 hours.

**If you're in a restricted network environment**, make sure your proxy is active before running the script. The script fetches GCC and Binutils source tarballs from GNU mirrors and GitHub — both commonly blocked:

```bash
export https_proxy=http://127.0.0.1:<port>
export http_proxy=http://127.0.0.1:<port>
NUM_JOBS=$(nproc) bash util/toolchain-builder/get-toolchain.sh
```

A mid-download failure leaves partial source archives that confuse the next run. If the build dies during the fetch phase, delete the partial files from the build directory and retry from scratch with your proxy confirmed active.

---

### 4.4 Resource Estimates

The table in 4.3 gives you the headline numbers. A few things worth knowing beyond them:

**On core count and diminishing returns:** `NUM_JOBS=$(nproc)` is always worth setting, but GCC's own build system serializes some stages regardless of the parallelism you throw at it. On 4 cores you'll sit close to the 3-hour mark; on 8 cores you land around 60–90 minutes; beyond that the gains flatten noticeably.

**What normal looks like:** expect long stretches with zero output — sometimes 10–15 minutes — especially during GCC's configure phase and early compilation stages. This is not a hang. If you want confirmation it's still alive:

```bash
top -o %CPU
```

A process consuming CPU means it's working. If everything is at 0% CPU for several minutes, that's a network stall during a source fetch, not normal compilation silence. See Section 4.5 for the fix.

**Disk note:** the 8–10 GB temp space during build is reclaimed once the install completes. The installed footprint in `$RISCV` settles around 2–3 GB. Make sure both your build partition and `$RISCV` destination have enough room independently — the build artifacts and the installed tree can end up on different mounts.

---

### 4.5 Common Build Errors & Fixes

Three failure modes cover the vast majority of problems. All are recoverable without re-cloning.

---

**Error 1 — Architecture mismatch: `cannot guess build type`**

configure: error: cannot guess build type; you must specify one


The `config.guess` and `config.sub` scripts inside the GCC/Binutils source tree are older than the host system they're running on — they don't recognize the triplet. This gets more common as distros age forward.

Fix: replace both scripts from the Savannah canonical copies.

```bash
# Find all instances across the build tree
find . -name config.guess -o -name config.sub | while read f; do
  case "$f" in
    *config.guess) wget -qO "$f" \
      'https://git.savannah.gnu.org/cgit/config.git/plain/config.guess' ;;
    *config.sub)   wget -qO "$f" \
      'https://git.savannah.gnu.org/cgit/config.git/plain/config.sub' ;;
  esac
done
```

Then rerun the build script. You don't need to clean first — the configure step will pick up the new scripts on the next pass.

---

**Error 2 — CMake too old**

CMake 3.14 or higher is required. You are running version 3.10.2


Ubuntu 20.04's APT-provided CMake is often 3.10.x, which is too old for this build. The PPA method from Section 3.1 is the clean fix:

```bash
wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | \
  gpg --dearmor - | sudo tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null

echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] \
  https://apt.kitware.com/ubuntu/ focal main' | \
  sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null

sudo apt-get update && sudo apt-get install cmake
cmake --version  # should now report 3.14+
```

---

**Error 3 — Truncated or corrupted source download**

make[2]: *** [Makefile:...] Error 1

or a checksum error during source extraction.

This happens when a GCC or Binutils tarball was fetched partially — dropped connection, proxy timeout, or a DNS failure partway through. The partial archive sits in the build directory and confuses every subsequent run because the script sees the file as already downloaded.

Fix: wipe the build artifacts entirely and retry from a stable connection.

```bash
cd util/toolchain-builder
rm -rf build/
```

Then confirm your proxy is active and re-run:

```bash
export https_proxy=http://127.0.0.1:<port>
export http_proxy=http://127.0.0.1:<port>
NUM_JOBS=$(nproc) bash get-toolchain.sh
```

Don't try to resume — the script doesn't support partial retries and the partial archive will just break again at extraction.

---

### 4.6 Verifying the Installation

Once the build script finishes, confirm the toolchain is actually usable before touching anything else. A build that completed without errors can still have an incomplete install if disk space ran out near the end or `$RISCV` wasn't set.

**Step 1 — Check the binary is present and reports the right version:**

```bash
$RISCV/bin/riscv64-unknown-elf-gcc --version
```

Expected output:

riscv64-unknown-elf-gcc (GCC) 13.1.0
Copyright (C) 2023 Free Software Foundation, Inc.
...


If the command isn't found, check that `$RISCV` is set correctly and that `$RISCV/bin` is on your `PATH`:

```bash
echo $RISCV
ls $RISCV/bin/ | grep gcc
```

**Note on binary naming:** some parts of the project documentation refer to `riscv-none-elf-gcc` while the build section uses `riscv64-unknown-elf-gcc`. Both point to the same GCC 13.1.0 toolchain. The `riscv-none-elf-*` naming appears in the verification and test-running sections (`README-sim.md`, lines 421–448); use whichever prefix `ls $RISCV/bin/` shows you actually have installed.

**Step 2 — Compile a minimal test program:**

```bash
cat > /tmp/test.c << 'EOF'
int main() { return 0; }
EOF

$RISCV/bin/riscv64-unknown-elf-gcc \
  -march=rv64imac -mabi=lp64 -O2 \
  /tmp/test.c -o /tmp/test.elf
```

No output means success. If you get a linker error about missing `crt0.o` or `libc`, add `-nostdlib`:

```bash
$RISCV/bin/riscv64-unknown-elf-gcc \
  -march=rv64imac -mabi=lp64 -O2 -nostdlib \
  /tmp/test.c -o /tmp/test.elf
```

**Step 3 — Confirm the expected tools are present:**

The full toolchain install should include, at minimum:

```bash
ls $RISCV/bin/ | grep riscv
```

You should see: `gcc`, `as`, `ld`, `objcopy`, `objdump`, `readelf`, `nm`, `strip`, and the GDB suite alongside them. If only `gcc` is present and the rest are missing, the install was interrupted — clean and rebuild.

---

**Toolchain installed and verified — move on to [Section 5: Simulation Setup].**

## 5. Bender (Dependency Manager)

Bender is the SystemVerilog dependency manager used by PULP Platform projects, including CVA6. It resolves the RTL source tree and generates the file lists that both the Verilator simulation flow and Vivado synthesis flow consume. Without it, neither flow has a reliable way to enumerate the right sources in the right order. Installation is a single binary drop — it takes about two minutes.

---

### 5.1 Installing Bender

The recommended approach is a direct binary download. There's no package manager entry for Bender, and building from source adds unnecessary complexity.

**Step 1 — Download the binary:**

Go to the releases page and grab the Linux binary:

https://github.com/pulp-platform/bender/releases/latest


Under **Assets**, look for a file named `bender-x86_64-linux` or `bender-...-ubuntu20.04`. Download it to your machine.

**Step 2 — Install it:**

From wherever you downloaded it:

```bash
chmod +x bender-x86_64-linux
sudo mv bender-x86_64-linux /usr/local/bin/bender
```

If your download has a different filename, rename it to just `bender` during the move — the rest of the documentation and the project scripts expect that exact name.

**Why `/usr/local/bin`?** It's on the default `PATH` for most Ubuntu installs and doesn't require any shell configuration changes. You can install it elsewhere, but you'll need to update your `PATH` manually in that case.

---

### 5.2 Verifying Bender

Confirm the binary is reachable and reports a version:

```bash
bender --version
```

Expected output:

0.27.3


The exact version number will vary with the release you downloaded. What matters is that the command resolves at all and doesn't throw an error.

---

**If you get `bash: bender: command not found`:**

The binary installed correctly but the shell can't find it. Check whether `/usr/local/bin` is actually on your `PATH`:

```bash
echo $PATH | grep "/usr/local/bin"
```

If that returns nothing, `/usr/local/bin` is missing from your environment. Add it:

```bash
export PATH=$PATH:/usr/local/bin
```

To make it permanent:

```bash
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
source ~/.bashrc
```

Then retry `bender --version`. If it still fails, confirm where the binary actually ended up:

```bash
which bender
ls /usr/local/bin/bender
```

If `ls` shows the file is there but `which` returns nothing, the issue is definitely the `PATH`. If `ls` shows nothing, the `mv` step didn't complete — repeat Step 2.

---

**Bender installed and on PATH — move on to [Section 6: Simulation Setup].**

## 6. Simulators (Verilator & Spike)

CVA6's simulation environment runs two simulators in tandem. Verilator compiles the RTL into a fast cycle-accurate C++ model; Spike acts as the golden RISC-V reference — it executes the same binary and produces a commit log that the regression framework diffs against Verilator's output. Both need to be present and consistent before any simulation target is meaningful.

The automated flow (driven by `cva6.py` and the smoke-test scripts) builds both simulators for you as part of the first run. The manual flow assumes Verilator is already installed and focuses on getting Spike built correctly for commit logging. Both flows share the same environment setup and the same two source patches — those need to be applied before anything builds.

---

### 6.1 Configuring the Environment

After cloning and submodule init, source the project's environment script from the repo root:

```bash
source verif/sim/setup-env.sh
```

This sets up paths and toolchain references the simulation flow expects. It needs to be run in every fresh shell before invoking any simulation target — adding it to `.bashrc` is fine if CVA6 is your primary workspace, but keep in mind it exports variables that may shadow other RISC-V projects.

Next, declare which simulators to use:

```bash
export DV_SIMULATORS=veri-testharness,spike
```

`veri-testharness` selects the Verilator-based simulation of the CVA6 testbench. `spike` selects Spike as the reference. The regression framework reads this variable to decide what to build and run — if it's unset or wrong, you'll get a silent no-op or a confusing "no simulator found" error rather than a clear failure. Export it before invoking any `make` target.

---

### 6.2 Known Patches Before Build

Two source-level patches are required before the first build. Neither is applied automatically by the setup script. Skip them and the Spike build will fail partway through — often with an error that points at yaml-cpp rather than the real cause.

Apply both now, before running anything.

---

**Patch 1 — yaml-cpp CMake version conflict**

Spike bundles yaml-cpp, and yaml-cpp's `CMakeLists.txt` declares `cmake_minimum_required(VERSION 3.14)`. This conflicts with certain CMake configurations and causes the build to error out during Spike's configure phase.

Fix: lower the minimum to `3.5` to eliminate the conflict.

File to edit:
verif/core-v-verif/vendor/riscv/riscv-isa-sim/yaml-cpp/CMakeLists.txt


Change line 2 from:
```cmake
cmake_minimum_required(VERSION 3.14)
```
to:
```cmake
cmake_minimum_required(VERSION 3.5)
```

One-liner if you'd rather not open an editor:
```bash
sed -i 's/cmake_minimum_required(VERSION 3.14)/cmake_minimum_required(VERSION 3.5)/' \
  verif/core-v-verif/vendor/riscv/riscv-isa-sim/yaml-cpp/CMakeLists.txt
```

---

**Patch 2 — missing `<cstdint>` header for GCC 13+**

Modern GCC (13 and later, and definitely 15+) no longer implicitly includes `<cstdint>` through other headers. yaml-cpp's `emitterutils.cpp` uses `uint8_t` without explicitly including it, which causes a compile error that looks like:

error: 'uint8_t' was not declared in this scope


Fix: add `#include <cstdint>` at the top of the file.

File to edit:
verif/core-v-verif/vendor/riscv/riscv-isa-sim/yaml-cpp/src/emitterutils.cpp


Add this as the first line (or anywhere in the header block at the top):
```cpp
#include <cstdint>
```

One-liner:
```bash
sed -i '1s/^/#include <cstdint>\n/' \
  verif/core-v-verif/vendor/riscv/riscv-isa-sim/yaml-cpp/src/emitterutils.cpp
```

---

**If you already have a broken partial build**, clean the Spike and yaml-cpp artifacts before rebuilding — the build system won't re-run configure on files it thinks are already processed:

```bash
rm -rf verif/core-v-verif/vendor/riscv/riscv-isa-sim/build
rm -rf verif/core-v-verif/vendor/riscv/riscv-isa-sim/yaml-cpp/build
rm -rf tools/spike
```

Then re-run the smoke test. The patches above need to be in place before that retry.

---

### 6.3 Building Verilator & Spike

With the environment sourced and both patches applied, you're ready to actually build. There are two paths: the automated flow, which is the right default, and a manual Spike build for when you need commit logging control or the automated flow breaks in a specific way.

---

#### Automated Build (Smoke Tests)

The smoke-test scripts are the standard entry point. They handle Verilator and Spike compilation, then run a short battery of tests to confirm everything is wired together correctly.

Set the job count first to parallelize the build:

```bash
export NUM_JOBS=$(nproc)
```

Then pick your target and run the corresponding script:

| CPU target | Script |
|---|---|
| `cv32a65x` | `smoke-tests-cv32a65x.sh` |
| `cv32a6_imac_sv32` | `smoke-tests-cv32a6_imac_sv32.sh` |
| `cv64a6_imafdc_sv39` | `smoke-tests-cv64a6_imafdc_sv39.sh` |

```bash
bash verif/regress/smoke-tests-cv32a6_imac_sv32.sh
```

The first run compiles both simulators from scratch — give it time. When it finishes cleanly, the last line will be:

SUCCESS


That's your confirmation that Verilator and Spike are both built, the environment is wired correctly, and the regression harness can reach both simulators.

---

#### Build Failure Recovery

If the smoke test fails mid-build — especially after a patching error, a previous broken attempt, or a toolchain version change — don't try to resume from a partial state. The build system doesn't handle it gracefully, and partial artifacts from a failed configure or compile pass will silently poison the next run.

Wipe all three relevant directories and start clean:

```bash
rm -rf verif/core-v-verif/vendor/riscv/riscv-isa-sim/build
rm -rf verif/core-v-verif/vendor/riscv/riscv-isa-sim/yaml-cpp/build
rm -rf tools/spike
```

Then confirm both patches from Section 6.2 are applied, and re-run the smoke test:

```bash
bash verif/regress/smoke-tests-cv32a6_imac_sv32.sh
```

This is the recovery sequence for the majority of build failures. If it fails a second time with the same error, the issue is upstream — check the toolchain version and CMake version before anything else.

---

#### Manual Spike Build

The automated flow builds Spike without commit logging enabled by default. If you need Spike to produce a commit log — which is required for meaningful trace comparison with Verilator — build it manually with `--enable-commitlog`.

Clone and build from the project's pinned source:

```bash
cd verif/core-v-verif/vendor/riscv/riscv-isa-sim
mkdir build && cd build
../configure --prefix=$RISCV --enable-commitlog
make -j$(nproc)
make install
```

`--enable-commitlog` bakes commit-log support into the binary. Without it, passing `--log-commits` at runtime will appear to work but produce a plain trace with no per-instruction commit entries — which means the regression framework's diff step silently passes on empty data. If you're getting misleading "no mismatches" results, this is a likely cause.

**Note on recent Spike versions:** newer builds of Spike support `--log-commits` as a runtime flag without needing the compile-time option. If your Spike already produces commit logs when you pass `--log-commits`, the `--enable-commitlog` flag is redundant but harmless.

---

#### Known Errors

**Verilator internal error in `lzc.sv`**

%Error: Internal Error: .../common_cells/src/lzc.sv:50:45:
  ../V3FuncOpt.cpp:228: Inconsistent assignment


This is a Verilator version incompatibility, not an RTL bug. The `lzc.sv` file is well-formed for the Verilator version the project pins — newer system-installed Verilator versions may trip on it.

The fix is to use the Verilator version the project expects, not whatever `apt install verilator` gives you. Check `git submodule status` first to confirm the submodule is at the right commit. If it is, and you're still hitting this, your system Verilator is being picked up instead of the project-pinned one — check which binary is on your `PATH` with `which verilator`.

**yaml-cpp build errors despite patches**

If you applied both patches but the Spike build still fails with CMake or `uint8_t` errors, the likeliest cause is that the patches were applied to the wrong files. The paths are long and easy to mistype:

```bash
# Verify both patches are actually in place
grep "cmake_minimum_required" \
  verif/core-v-verif/vendor/riscv/riscv-isa-sim/yaml-cpp/CMakeLists.txt

head -3 \
  verif/core-v-verif/vendor/riscv/riscv-isa-sim/yaml-cpp/src/emitterutils.cpp
```

The first command should show `VERSION 3.5`. The second should show `#include <cstdint>` on the first line. If either doesn't match, re-apply the patch and wipe the build directories before retrying.

---

#### Running Tests with `cva6.py`

Once both simulators are built, `cva6.py` is the primary way to run individual tests and compare outputs. It compiles your test binary, runs it through both Verilator and Spike, and diffs the commit traces.

Run from `verif/sim/`:

```bash
cd verif/sim
python3 cva6.py \
  --target cv32a6_imac_sv32 \
  --iss=$DV_SIMULATORS \
  --iss_yaml=cva6.yaml \
  --c_tests ../tests/custom/hello_world/hello_world.c \
  --linker=../../config/gen_from_riscv_config/linker/link.ld \
  --gcc_opts="-static -mcmodel=medany -fvisibility=hidden -nostdlib -N -mno-relax"
```

For assembly tests, swap `--c_tests` for `--asm_tests`:

```bash
python3 cva6.py \
  --target cv32a6_imac_sv32 \
  --iss=$DV_SIMULATORS \
  --iss_yaml=cva6.yaml \
  --asm_tests ../tests/custom/your_test.S \
  --linker=../../config/gen_from_riscv_config/linker/link.ld \
  --gcc_opts="-static -mcmodel=medany -fvisibility=hidden -nostdlib -N -mno-relax"
```

**GCC flag notes:** these flags aren't optional — they're required for the binary to run correctly in the CVA6 simulation environment:

| Flag | Purpose |
|---|---|
| `-static` | No dynamic linker in the simulation environment |
| `-mcmodel=medany` | Position-independent code model for RISC-V |
| `-fvisibility=hidden` | Prevents symbol visibility issues in bare-metal context |
| `-nostdlib` | No hosted standard library — bare-metal target |
| `-N` | Makes text and data segments writable, disables page alignment |
| `-mno-relax` | Disables linker relaxation, which can break bare-metal layouts |

Drop any of these and the binary will likely assemble and link but fail silently or crash at the start of simulation with no useful output.

---

**Both simulators built and verified — move on to [Section 7: Checklist].**

## 7. Setup Checklist

Use this as your final pass before running any simulation or synthesis work. Every item maps to a specific section — if something's broken, the fix is already in this guide.

---

### 7.1 Pre-Flight Checklist

Work through these in order. Each item links back to the section where the details live.

---

**System ([1](#1-system-requirements))**

- [ ] Running native Linux (Ubuntu 20.04+) — not WSL2, not a VM with shared NTFS storage
- [ ] Repo will live on an **ext4** partition — not a mounted Windows drive ([1.1](#11-operating-system--filesystem))
- [ ] At least **40 GB** free disk space on that partition ([1.2](#12-storage--ram))
- [ ] At least **4 GB RAM** (16 GB if doing Vivado synthesis or behavioral xsim) ([1.2](#12-storage--ram))
- [ ] 16 GB swapfile configured if running behavioral xsim simulation ([1.2](#12-storage--ram))
- [ ] VPN or proxy active and verified if accessing from Iran or another restricted region ([1.3](#13-network))

---

**Repository ([2](#2-repository-setup))**

- [ ] Repo cloned (`git clone` or `git clone --recursive`) ([2.1](#21-cloning-the-repository))
- [ ] If synthesis work: checked out the known-good commit `41e30493...` ([2.1](#21-cloning-the-repository))
- [ ] Submodules initialized: `git submodule update --init --recursive` ([2.2](#22-initializing-submodules))
- [ ] `git submodule status` shows no lines prefixed with `-` ([2.2](#22-initializing-submodules))

---

**System Dependencies ([3](#3-system-dependencies))**

- [ ] APT packages installed (`cmake help2man device-tree-compiler` + GCC prerequisites) ([3.1](#31-apt-packages))
- [ ] `cmake --version` reports **3.14 or higher** — upgraded via Kitware PPA if needed ([§3.1](#31-apt-packages))
- [ake --version` reports **3.14 or higher** — upgraded via Kitware PPA if needed ([3.1](#31-apt-packages))
- [ ] Python venv created: `python3 -m venv-risc-v-gcc-toolchain))**

- [ ] `$RISCV` exported and persisted in `~/.bashrc` ([4.2](#42-setting-the-riscv-environment-variable))
- [ ] `$RISCV/bin` is on `$PATH` ([4.2](#42-setting-the-riscv-environment-variable))
- [ ] Toolchain built: `NUM_JOBS=$(nproc) bash util/toolchain-builder/get-toolchain.sh` ([4.3](#43-building-the-toolchain))
- [ ] `$RISCV/bin/riscv64-unknown-elf-gcc --version` reports **GCC 13.1.0** ([4.6](#46-verifying-the-installation))
- [ ] Minimal test binary compiles without errors ([4.6](#46-verifying-the-installation))
- [ ] `ls $RISCV/bin/ | grep riscv` shows `gcc`, `as`, `ld`, `objcopy`, `objdump`, and friends ([§4.6](#46-verifying-the-installation))

---

**Bender ([5](#5-bender-dependency-manager))**

- [ ] Binary downloaded from the releases page ([5.1](#51-installing-bender))
- [ ] Installed to `/usr/local/bin/bender` and marked executable ([5.1](#51-installing-bender))
- [ ] `bender --version` returns a version string without error ([5.2](#52-verifying-bender))

---

**Simulators ([6](#6-simulators-verilator--spike))**

- [ ] `source verif/sim/setup-env.sh` runs without errors ([6.1](#61-configuring-the-environment))
- [ ] `DV_SIMULATORS=veri-testharness,spike` exported ([6.1](#61-configuring-the-environment))
- [ ] yaml-cpp CMake patch applied (line 2 of `yaml-cpp/CMakeLists.txt` reads `VERSION 3.5`) ([6.2](#62-known-patches-before-build))
- [ ] `<cstdint>` header patch applied (first line of `emitterutils.cpp` is `#include <cstdint>`) ([6.2](#62-known-patches-before-build))
- [ ] Smoke test completed and last line reads `SUCCESS` ([6.3](#63-building-verilator--spike))
- [ ] *(If running trace comparison)* Spike rebuilt manually with `--enable-commitlog` ([6.3](#63-building-verilator--spike))

---

### 7.2 Error Quick-Reference

If something's broken, find the symptom below and jump straight to the fix.

| Symptom | Where to look |
|---|---|
| Broken symlinks or failed submodule state | [1.1](#11-operating-system--filesystem) — you're likely on NTFS |
| `xsim` simulation crashes with out-of-memory | [1.2](#12-storage--ram) — add the 16 GB swapfile |
| `git clone` or `git submodule update` hangs or times out | [1.3](#13-network) — proxy not active |
| `pip install` hangs silently or fails with connection errors | [1.3](#13-network) and [§3.2](#32-python-virtual-environment) |
| `git submodule status` shows lines starting with `-` | [2.2](#22-initializing-submodules) — re-run `git submodule update --init --recursive` |
| Synthesis throws "missing dependencies" or Tcl errors | [2.2](#22-initializing-submodules) — almost always uninitialized submodules |
| Verilator aborts with an internal error in `lzc.sv` | [2.2](#22-initializing-submodules) and [6.3](#63-building-verilator--spike) — wrong Verilator version |
| `cmake --version` reports older than 3.14 | [3.1](#31-apt-packages) — install via Kitware PPA |
| GCC build fails with `checking for mpc_init2 in -lmpc... no` | [3.1](#31-apt-packages) — install `libmpc-dev` and friends |
| `configure: error: cannot guess build type` during toolchain build | [4.5](#45-common-build-errors--fixes) — replace `config.guess` / `config.sub` |
| Checksum error or truncated tarball during toolchain build | [4.5](#45-common-build-errors--fixes) — wipe `build/` and retry with proxy active |
| `riscv64-unknown-elf-gcc` not found after build | [4.6](#46-verifying-the-installation) — check `$RISCV` is set and `$RISCV/bin` is on `$PATH` |
| Only `gcc` present in `$RISCV/bin`, rest missing | [4.6](#46-verifying-the-installation) — install was interrupted; clean and rebuild |
| `bash: bender: command not found` | [5.2](#52-verifying-bender) — `/usr/local/bin` not on `$PATH` |
| Spike build fails with CMake version errors | [6.2](#62-known-patches-before-build) — yaml-cpp CMake patch not applied or applied to wrong path |
| Spike build fails with `'uint8_t' was not declared in this scope` | [6.2](#62-known-patches-before-build) — `<cstdint>` patch not applied |
| Smoke test fails mid-build after a previous broken attempt | [6.3](#63-building-verilator--spike) — wipe `build/`, `yaml-cpp/build/`, and `tools/spike/`, then retry |
| Trace comparison passes with no mismatches on every test | [6.3](#63-building-verilator--spike) — Spike was built without `--enable-commitlog`; rebuild manually |
| `cva6.py` test runs but binary crashes at start with no output | [6.3](#63-building-verilator--spike) — check GCC flags, especially `-nostdlib`, `-static`, `-mno-relax` |

---

### 7.3 Session Startup

Every new shell needs these before you touch any simulation target:

```bash
source venv_cva6/bin/activate
source verif/sim/setup-env.sh
export DV_SIMULATORS=veri-testharness,spike
export RISCV=$HOME/riscv          # already in ~/.bashrc if you followed 4.2
```

If you added `$RISCV` and the venv activation to `~/.bashrc`, only `setup-env.sh` and `DV_SIMULATORS` need to be re-sourced manually. Consider wrapping all four in a small script at the repo root so there's nothing to remember.

---

That's everything. If the smoke test passed and the checklist is clean, the environment is ready.