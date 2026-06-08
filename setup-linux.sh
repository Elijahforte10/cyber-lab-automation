#!/usr/bin/env bash
#
# setup-linux.sh -- runs INSIDE LINUX01.
# Installs Docker + a starter set of security tools and spins up a deliberately
# vulnerable web app target for vulnerability-management / scanning practice.
#
# Run with: sudo bash setup-linux.sh

set -euo pipefail

echo "[*] Updating packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y && apt-get upgrade -y

echo "[*] Installing base security tooling..."
apt-get install -y \
    curl wget git net-tools tcpdump nmap \
    python3 python3-pip jq unzip ca-certificates gnupg

echo "[*] Installing Docker Engine..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
    > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker

echo "[*] Launching a vulnerable web target (DVWA) for scanning practice..."
docker rm -f dvwa 2>/dev/null || true
docker run -d --name dvwa --restart unless-stopped -p 8080:80 vulnerables/web-dvwa

echo "[+] LINUX01 ready."
echo "    DVWA target: http://$(hostname -I | awk '{print $2}'):8080  (login admin/password)"
echo "    Tools: nmap, tcpdump, docker. Add more as your labs require."
