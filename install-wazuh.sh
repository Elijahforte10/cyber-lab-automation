#!/usr/bin/env bash
#
# install-wazuh.sh -- runs INSIDE SIEM01.
# Installs the Wazuh all-in-one stack (manager + indexer + dashboard) using the
# official installation assistant. After this, agents on the other VMs forward
# logs here for detection.
#
# Requirements: 4 GB RAM minimum (6-8 GB recommended), ~50 GB disk.
# Run with: sudo bash install-wazuh.sh

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then echo "[!] Run as root (sudo)."; exit 1; fi

# RAM guard -- Wazuh indexer will struggle below 4 GB
mem_gb=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 ))
if (( mem_gb < 4 )); then
    echo "[!] Only ${mem_gb} GB RAM detected. Wazuh needs 4 GB+ (6-8 GB recommended)."
    echo "    Increase SIEM01 RAM in lab-config.ps1 and redeploy."
    exit 1
fi

echo "[*] Downloading Wazuh installation assistant..."
curl -sO https://packages.wazuh.com/4.x/wazuh-install.sh

echo "[*] Running all-in-one install (this takes several minutes)..."
bash ./wazuh-install.sh -a -i

echo
echo "[+] Wazuh installed."
echo "    Dashboard: https://$(hostname -I | awk '{print $2}')"
echo "    Credentials were printed above and saved in wazuh-install-files.tar"
echo "    Retrieve admin password later with:"
echo "      sudo tar -O -xvf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt"
