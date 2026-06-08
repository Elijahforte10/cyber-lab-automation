<#
    Install-WazuhAgent.ps1 -- runs INSIDE each Windows VM (DC01/SRV01/CLIENT01).
    Installs the Wazuh agent and points it at SIEM01 for log forwarding.
#>
param(
    [string]$ManagerIp = "192.168.56.0",   # set to SIEM01's lab-LAN IP
    [string]$AgentGroup = "windows"
)
$ErrorActionPreference = "Stop"

$ver = "4.9.0-1"   # pin to your installed Wazuh version
$msi = "$env:TEMP\wazuh-agent.msi"
$url = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$ver.msi"

Write-Host "[*] Downloading Wazuh agent $ver..."
Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing

Write-Host "[*] Installing and registering to manager $ManagerIp..."
Start-Process msiexec.exe -Wait -ArgumentList @(
    "/i", "`"$msi`"", "/q",
    "WAZUH_MANAGER=$ManagerIp",
    "WAZUH_REGISTRATION_SERVER=$ManagerIp",
    "WAZUH_AGENT_GROUP=$AgentGroup"
)

Start-Service WazuhSvc
Set-Service WazuhSvc -StartupType Automatic
Write-Host "[+] Wazuh agent installed and forwarding to $ManagerIp." -ForegroundColor Green
