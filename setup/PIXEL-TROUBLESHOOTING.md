# Pixel 7/8 Benchmark Troubleshooting Guide

This comprehensive guide covers common issues encountered during setup and benchmarking on Pixel devices, organized by problem category.

---

## Table of Contents

1. [Setup Phase Issues](#setup-phase-issues)
2. [Build and Compilation Problems](#build-and-compilation-problems)
3. [Runtime Issues](#runtime-issues)
4. [Network and Transfer Problems](#network-and-transfer-problems)
5. [Performance and Optimization](#performance-and-optimization)
6. [Diagnostic Commands](#diagnostic-commands)

---

## Setup Phase Issues

### Phase 1: Package Installation Errors

#### Symptom: `pkg install` fails with "Unable to locate package"

**Diagnostic**:
```bash
pkg update
pkg list-all | grep python
pkg list-all | grep cmake
```

**Solution**:
```bash
# Clean package cache and update
pkg clean
pkg update && pkg upgrade -y

# If specific package still fails, try alternative names
pkg search python  # Find available Python packages
pkg install python3  # Try python3 instead of python
```

**Alternative**: Some packages may have different names in Termux:
- `opencl-headers` → `ocl-icd` (older Termux versions)
- `opencl-vendor-driver` → May not be available on all devices

---

#### Symptom: "Packages are not signed correctly"

**Cause**: Using Play Store version of Termux instead of F-Droid

**Solution**:
1. Uninstall Play Store Termux
2. Install from F-Droid: https://f-droid.org/en/packages/com.termux/
3. Run setup again

---

#### Symptom: Python version too old (< 3.11)

**Diagnostic**:
```bash
python3 --version
pkg show python
```

**Solution**:
```bash
# Update to latest available Python
pkg upgrade python

# If still too old, check available versions
pkg search python | grep "^python"
pkg install python-<version>  # Install specific version
```

**Workaround**: If Python 3.11+ not available, you may need to:
- Use tur-repo for newer packages: `pkg install tur-repo`
- Or compile Python from source (advanced, time-consuming)

---

### Phase 2: SSH Connection Issues

#### Symptom: Cannot connect via SSH ("Connection refused")

**Diagnostic**:
```bash
# On Pixel
ps aux | grep sshd
netstat -tuln | grep 8022
```

**Solution**:
```bash
# Restart SSH daemon
pkill sshd
sshd

# Check if running
ps aux | grep sshd

# Verify port 8022 is listening
netstat -tuln | grep 8022
```

---

#### Symptom: "Permission denied (publickey,password)"

**Diagnostic**:
```bash
# Check if password is set
passwd -S
```

**Solution**:
```bash
# Set/reset password
passwd

# Verify SSH configuration allows password auth
cat $PREFIX/etc/ssh/sshd_config | grep PasswordAuthentication

# If disabled, enable it
echo "PasswordAuthentication yes" >> $PREFIX/etc/ssh/sshd_config
pkill sshd && sshd
```

---

#### Symptom: Tailscale IP not found

**Diagnostic**:
```bash
# On host machine
tailscale status | grep pixel

# On Pixel (if Tailscale app installed)
ifconfig tailscale0
```

**Solution**:
1. Ensure Tailscale app is installed and running on Pixel
2. Check if logged into same tailnet as host
3. Verify Pixel shows as "connected" in Tailscale app
4. If not working, use local network IP instead:
   ```bash
   ifconfig wlan0 | grep "inet "
   ```

---

### Phase 3: croc Installation Issues

#### Symptom: `go install` fails or croc not found

**Diagnostic**:
```bash
which go
go version
echo $PATH | grep go
```

**Solution**:
```bash
# Ensure Go is installed
pkg install golang

# Add Go bin to PATH if not present
echo 'export PATH=$PATH:~/go/bin' >> ~/.bashrc
source ~/.bashrc

# Retry croc installation
go install github.com/schollz/croc/v10@latest

# Verify installation
~/go/bin/croc --version
```

**Alternative**: If Go installation fails, use scp/rsync for file transfer instead

---

## Build and Compilation Problems

### Phase 6: llama.cpp Build Failures

#### Symptom: CMake error: "OpenCL not found"

**Diagnostic**:
```bash
ls /system/vendor/lib64/libOpenCL*
pkg list-installed | grep opencl
echo $LD_LIBRARY_PATH
```

**Solution**:
```bash
# Install OpenCL packages
pkg install opencl-headers opencl-vendor-driver

# Set library path
export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH

# Verify OpenCL libraries exist
ls -la /system/vendor/lib64/libOpenCL*

# Retry build
cd deps/llama.cpp
rm -rf build && mkdir build && cd build
cmake .. -DGGML_OPENCL=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
cmake --build . --config Release -j$(nproc)
```

---

#### Symptom: "clang: command not found" during build

**Diagnostic**:
```bash
which clang
which clang++
pkg list-installed | grep clang
```

**Solution**:
```bash
# Install clang compiler
pkg install clang

# Verify installation
clang --version
clang++ --version

# Retry build
cd deps/llama.cpp/build
cmake .. -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
cmake --build . --config Release -j$(nproc)
```

---

#### Symptom: Build fails with "ninja: build stopped: subcommand failed"

**Diagnostic**:
```bash
# Check build log for specific error
cd deps/llama.cpp/build
cmake --build . --verbose 2>&1 | tee build.log
```

**Common causes and solutions**:

**Out of memory during compilation**:
```bash
# Reduce parallel jobs
cmake --build . --config Release -j2  # Use only 2 cores instead of $(nproc)

# Or build single-threaded
cmake --build . --config Release -j1
```

**Missing dependencies**:
```bash
# Install all build dependencies
pkg install cmake clang ninja git

# Clean and rebuild
cd deps/llama.cpp
rm -rf build
mkdir build && cd build
cmake .. -DGGML_OPENCL=ON
cmake --build . --config Release -j2
```

---

#### Symptom: "libstdc++.so not found" when running binaries

**Diagnostic**:
```bash
ldd deps/llama.cpp/build/bin/llama-server
```

**Solution**:
```bash
# Install libc++ (C++ standard library)
pkg install libc++

# Or set library path
export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH
```

---

## Runtime Issues

### OpenCL GPU Not Detected

#### Symptom: Benchmarks running on CPU instead of GPU (slow performance)

**Diagnostic**:
```bash
# Check OpenCL libraries
ls -la /system/vendor/lib64/libOpenCL*

# Check environment variables
echo $LD_LIBRARY_PATH
echo $PYOPENCL_CTX
echo $PYOPENCL_PLATFORM

# Test OpenCL detection (if clinfo available)
pkg install clinfo
clinfo
```

**Solution**:
```bash
# Set environment variables
export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH
export PYOPENCL_CTX=0
export PYOPENCL_PLATFORM=0

# Add to .bashrc for persistence
cat >> ~/.bashrc << 'EOF'
export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH
export PYOPENCL_CTX=0
export PYOPENCL_PLATFORM=0
EOF

# Reload environment
source ~/.bashrc

# Verify llama.cpp detects GPU
cd deps/llama.cpp/build
./bin/llama-server --help | grep -i gpu
```

---

#### Symptom: "No suitable OpenCL device found"

**Diagnostic**:
```bash
# Check Android version
getprop ro.build.version.release

# Check SoC/GPU
getprop ro.product.board
getprop ro.hardware
```

**Solution**:

For **Pixel 7** (Adreno 730):
```bash
export LD_LIBRARY_PATH=/vendor/lib64:/system/vendor/lib64:$LD_LIBRARY_PATH
```

For **Pixel 8** (Adreno 740):
```bash
export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH
```

If still not working:
```bash
# Try alternative library paths
export LD_LIBRARY_PATH=/vendor/lib64/egl:/vendor/lib64:$LD_LIBRARY_PATH
```

---

### Python Import Errors

#### Symptom: `ModuleNotFoundError: No module named 'tinygrad'`

**Diagnostic**:
```bash
echo $PYTHONPATH
ls -la deps/tinygrad/tinygrad/
```

**Solution**:
```bash
# Set PYTHONPATH
export PYTHONPATH="$HOME/t-eai-project/deps/tinygrad:$PYTHONPATH"

# Add to .bashrc
echo 'export PYTHONPATH="$HOME/t-eai-project/deps/tinygrad:$PYTHONPATH"' >> ~/.bashrc

# Verify import works
python3 -c "from tinygrad.helpers import fetch; print('Success')"
```

---

#### Symptom: `ModuleNotFoundError: No module named 'bottle'` (or tiktoken, verifiers)

**Diagnostic**:
```bash
pip3 list | grep bottle
pip3 list | grep tiktoken
pip3 list | grep verifiers
```

**Solution**:
```bash
# Install missing packages
pip3 install --user bottle tiktoken verifiers

# Or install from requirements.txt
cd ~/t-eai-project
pip3 install --user -r requirements.txt

# Verify installation
python3 -c "import bottle; import tiktoken; print('Success')"
```

---

### Out of Memory During Benchmarking

#### Symptom: Process killed, "Killed" message in terminal

**Diagnostic**:
```bash
# Check available memory
free -h

# Check memory usage during benchmark
top  # Run in separate session while benchmark runs

# Check Android's low memory killer logs
logcat -d | grep lowmemorykiller
```

**Solutions** (in order of preference):

**1. Use more aggressive quantization:**
```bash
# Use nf4 (smallest) instead of default or float16
python3 llamacpp_benchmark.py --quantize nf4

# Or edit llamacpp_benchmark.py to only use nf4
SQUANTS = [("--quantize", "nf4")]
```

**2. Close other Android apps:**
```bash
# Free up system memory
# Close all apps via Android UI
# Disable background processes in Settings > Developer Options
```

**3. Reduce context length:**
```bash
# Edit llamacpp_benchmark.py line 143
# Change from -n 20 to -n 10
"-n", "10",  # Generate 10 tokens instead of 20
```

**4. Use smaller model:**
```bash
# Stick with 1B model, don't try 8B or larger
python3 llamacpp_benchmark.py --size 1B
```

---

### Model Download Failures

#### Symptom: Download hangs or fails with timeout

**Diagnostic**:
```bash
# Check internet connection
ping -c 3 huggingface.co

# Check available storage
df -h $HOME

# Check if partial download exists
ls -lh models/*.gguf
```

**Solution**:
```bash
# Remove partial downloads
rm models/*.gguf.tmp

# Download manually with wget (resumable)
cd models
wget -c https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf

# Or use croc to transfer from host
# On host:
croc send ~/.cache/huggingface/hub/models--bartowski--Llama-3.2-1B-Instruct-GGUF/snapshots/*/Llama-3.2-1B-Instruct-Q4_K_M.gguf

# On Pixel:
cd ~/t-eai-project/models
croc <code>
```

---

#### Symptom: "No space left on device" during model download

**Diagnostic**:
```bash
df -h $HOME
du -h models/*.gguf 2>/dev/null | tail -5
```

**Solution**:
```bash
# Free up space
rm -rf ~/.cache/*  # Clear cache
pkg clean  # Clean package cache

# Remove unnecessary models
cd models
ls -lh  # See which models exist
rm Llama-3.2-1B-Instruct-f16.gguf  # Remove large float16 model

# Download only essential quantizations
# Edit llamacpp_benchmark.py to only use nf4
SQUANTS = [("--quantize", "nf4")]
```

---

## Network and Transfer Problems

### SSH Transfer Speed Issues

#### Symptom: SCP/rsync very slow (< 1MB/s)

**Diagnostic**:
```bash
# Test network speed
iperf3 -s  # On Pixel
iperf3 -c <pixel-ip>  # On host

# Check if compression is enabled
# SCP should use -C flag for compression
```

**Solution**:
```bash
# Use croc instead (much faster)
croc send file.tar.gz

# If must use SCP, enable compression
scp -C -P 8022 file.tar.gz user@host:

# Or use rsync with compression
rsync -avz -e "ssh -p 8022" file.tar.gz user@host:
```

---

### croc Transfer Issues

#### Symptom: croc fails with "relay connection failed"

**Diagnostic**:
```bash
# Test internet connectivity
ping -c 3 8.8.8.8

# Check if behind restrictive firewall
croc --debug send test.txt
```

**Solution**:
```bash
# Use custom relay server
croc --relay <custom-relay> send file.tar.gz

# Or use local relay (on same network)
# On host:
croc relay

# On Pixel:
croc --relay <host-ip>:9009 send file.tar.gz

# Alternative: Use direct file transfer via SSH
scp -P 8022 file.tar.gz user@<pixel-ip>:
```

---

## Performance and Optimization

### Slow Benchmark Performance

#### Symptom: Benchmarks much slower than expected

**Diagnostic**:
```bash
# Check if GPU is being used
cat /sys/class/kgsl/kgsl-3d0/gpubusy_percentage

# Check CPU frequency (thermal throttling)
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq

# Check temperature
cat /sys/class/thermal/thermal_zone*/temp
```

**Solutions**:

**1. Verify GPU usage:**
```bash
# Ensure OpenCL environment is set
export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH
source ~/.bashrc

# Rebuild with OpenCL if not done
cd deps/llama.cpp/build
cmake .. -DGGML_OPENCL=ON
cmake --build . --config Release
```

**2. Prevent thermal throttling:**
- Connect to charger
- Allow device to cool between runs
- Remove phone case for better heat dissipation
- Use in cool environment (air conditioning)

**3. Close background apps:**
- Close all apps via Android recent apps
- Disable battery optimization for Termux
- Enable airplane mode to reduce background activity

---

### Inconsistent Benchmark Results

#### Symptom: Large variance in tok/s across runs

**Causes**:
- Thermal throttling
- Background processes
- Variable network activity
- Cached vs non-cached model loading

**Solutions**:
```bash
# Use consistent environment
# 1. Same charge level (preferably on charger)
# 2. Same temperature (allow cooling between runs)
# 3. Airplane mode enabled
# 4. All background apps closed

# Run multiple repetitions (already default)
# llamacpp_benchmark.py uses -r 5 (5 repetitions)

# Discard first run (warmup)
# Edit llamacpp_benchmark.py to skip first iteration in analysis
```

---

## Diagnostic Commands

### System Information

```bash
# Android version
getprop ro.build.version.release

# Device model
getprop ro.product.model

# SoC/chipset
getprop ro.hardware
getprop ro.product.board

# CPU information
cat /proc/cpuinfo | grep -E "(processor|model name|cpu MHz)"

# Memory information
cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable)"

# Storage information
df -h $HOME
```

### OpenCL Diagnostics

```bash
# Check OpenCL libraries
ls -la /system/vendor/lib64/libOpenCL*
ls -la /vendor/lib64/libOpenCL*

# Check library path
echo $LD_LIBRARY_PATH

# Install and run clinfo (if available)
pkg install clinfo
clinfo  # Shows all OpenCL platforms and devices

# Check GPU device
ls /dev/kgsl-3d0
cat /sys/class/kgsl/kgsl-3d0/devfreq/cur_freq
```

### Python Environment Diagnostics

```bash
# Python version
python3 --version

# Installed packages
pip3 list

# Check specific packages
pip3 show bottle
pip3 show tiktoken
pip3 show verifiers

# Import test
python3 << 'EOF'
import sys
print("Python:", sys.version)
print("Path:", sys.path)

try:
    import bottle
    print("✓ bottle")
except ImportError as e:
    print("✗ bottle:", e)

try:
    import tiktoken
    print("✓ tiktoken")
except ImportError as e:
    print("✗ tiktoken:", e)

try:
    from tinygrad.helpers import fetch
    print("✓ tinygrad")
except ImportError as e:
    print("✗ tinygrad:", e)
EOF
```

### Build Diagnostics

```bash
# Check llama.cpp build
ls -lh deps/llama.cpp/build/bin/

# Test binaries
deps/llama.cpp/build/bin/llama-server --version
deps/llama.cpp/build/bin/llama-bench --help

# Check build configuration
cat deps/llama.cpp/build/CMakeCache.txt | grep OPENCL

# Verify OpenCL was enabled
cat deps/llama.cpp/build/CMakeCache.txt | grep "GGML_OPENCL:BOOL=ON"
```

### Network Diagnostics

```bash
# Check network interfaces
ifconfig

# WiFi connection
ifconfig wlan0

# Tailscale (if installed)
ifconfig tailscale0

# Test connectivity
ping -c 3 8.8.8.8
ping -c 3 huggingface.co

# Check open ports
netstat -tuln

# SSH daemon
netstat -tuln | grep 8022
ps aux | grep sshd
```

---

## Getting Help

If issues persist after trying these solutions:

1. **Collect diagnostic information**:
   ```bash
   bash -x setup/pixel7_setup.sh > setup_debug.log 2>&1
   ```

2. **Check existing issues**: https://github.com/spikedoanz/t-eai-project/issues

3. **Create detailed bug report** including:
   - Pixel model (7 or 8)
   - Android version (`getprop ro.build.version.release`)
   - Termux version (`termux-info`)
   - Error messages (full output)
   - Steps to reproduce
   - Diagnostic command outputs

4. **Consult upstream documentation**:
   - llama.cpp Android guide: `deps/llama.cpp/docs/android.md`
   - Termux wiki: https://wiki.termux.com/
   - Verifiers docs: `deps/verifiers/README.md`

---

## Quick Reference: Most Common Fixes

```bash
# Fix 1: Environment variables not set
source ~/.bashrc

# Fix 2: OpenCL library path
export LD_LIBRARY_PATH=/system/vendor/lib64:$LD_LIBRARY_PATH

# Fix 3: Python import errors
export PYTHONPATH="$HOME/t-eai-project/deps/tinygrad:$PYTHONPATH"

# Fix 4: Rebuild llama.cpp
cd ~/t-eai-project/deps/llama.cpp
rm -rf build && mkdir build && cd build
cmake .. -DGGML_OPENCL=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
cmake --build . --config Release -j2

# Fix 5: Reinstall Python packages
pip3 install --user --force-reinstall bottle tiktoken verifiers

# Fix 6: Out of memory - use smaller model/quantization
python3 llamacpp_benchmark.py --quantize nf4 --size 1B
```
