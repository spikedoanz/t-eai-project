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
