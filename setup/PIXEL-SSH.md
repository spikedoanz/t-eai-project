> **Note**: For complete Pixel 7/8 setup including benchmarking, see the automated setup script:
> - **Full setup**: `setup/pixel7_setup.sh`
> - **Benchmark guide**: `setup/PIXEL-BENCHMARK.md`
> - **Troubleshooting**: `setup/PIXEL-TROUBLESHOOTING.md`
>
> This document provides a quick reference for SSH-only setup.

0. install tailscale from playstore and add phone to tailnet

1. install and setup ssh portal
```
pkg install ssh
sshd
passwd
```

2. install croc for file transfer (repeat for client device)
```
pkg install golang
echo 'export PATH=$PATH:~/go/bin' >> ~/.bashrc
exec bash
```

3. (optional) send over network information
```
ifconfig >> networkinfo.txt
id >> networkinfo.txt
croc send networkinfo.txt
```

4. obtain ssh information with id and tailscale
```
# running id will give username, will be something like u0_a190
# tailscale status on client to see the phone information
ssh u0_190@tailscale-ip
```
