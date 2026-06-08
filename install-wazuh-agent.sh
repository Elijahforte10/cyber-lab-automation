#!/usr/bin/env bash
#
# install-wazuh-agent.sh -- runs INSIDE LINUX01.
# Installs the Wazuh agent and enrolls it to SIEM01 for log forwarding.
#
# Usage: sudo bash install-wazuh-agent.sh <SIEM01_LAB_IP>

set -euo pipefail
MANAGER_IP="${1:-192.168.56.0}"   # pass SIEM01's lab-LAN IP

if [[ "$(id -u)" -ne 0 ]]; then echo "[!] Run as root (sudo)."; exit 1; fi

echo "[*] Adding Wazuh repository..."
install -m 0755 -d /usr/share/keyrings
curl -fsSL https://packages.wazuh.com/key/GPG-KEY-WAZUH | \
    gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
    > /etc/apt/sources.list.d/wazuh.list
apt-get update -y

echo "[*] Installing agent, enrolling to $MANAGER_IP..."
WAZUH_MANAGER="$MANAGER_IP" WAZUH_AGENT_GROUP="linux" apt-get install -y wazuh-agent

systemctl daemon-reload
systemctl enable --now wazuh-agent

echo "[+] Wazuh agent installed and forwarding to $MANAGER_IP."
