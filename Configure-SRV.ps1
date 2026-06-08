<#
    Configure-SRV.ps1 -- runs INSIDE SRV01 (member server).
    Points DNS at DC01, joins the domain, creates a file share, and drops a
    sample GPO for Group Policy practice.
#>
param(
    [string]$Domain   = "lab.local",
    [string]$DcIp     = "192.168.56.10",
    [string]$JoinUser = "LAB\labadmin",
    [string]$JoinPass = "P@ssw0rd-Lab-2026!"
)
$ErrorActionPreference = "Stop"

# Point DNS at the DC so the domain resolves
$adapter = Get-NetAdapter | Where-Object Status -eq "Up" | Sort-Object ifIndex | Select-Object -Last 1
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DcIp

if ((Get-CimInstance Win32_ComputerSystem).PartOfDomain -ne $true) {
    Write-Host "[*] Joining domain $Domain..."
    $sec = ConvertTo-SecureString $JoinPass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($JoinUser, $sec)
    Add-Computer -DomainName $Domain -Credential $cred -Restart -Force
    return   # reboots; re-run after reboot for the share/GPO steps
}

# --- File share for IAM/permissions practice --------------------------------
$sharePath = "C:\Shares\Department"
if (-not (Test-Path $sharePath)) { New-Item -ItemType Directory -Path $sharePath -Force | Out-Null }
if (-not (Get-SmbShare -Name "Department" -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name "Department" -Path $sharePath -FullAccess "LAB\Domain Admins" `
        -ChangeAccess "LAB\Domain Users"
    Write-Host "[+] File share \\SRV01\Department created."
}

# --- Sample GPO for testing -------------------------------------------------
Import-Module GroupPolicy
if (-not (Get-GPO -Name "Lab - Desktop Standard" -ErrorAction SilentlyContinue)) {
    $gpo = New-GPO -Name "Lab - Desktop Standard"
    # Example setting: disable Windows tips (a harmless, observable policy)
    Set-GPRegistryValue -Name $gpo.DisplayName `
        -Key "HKLM\Software\Policies\Microsoft\Windows\CloudContent" `
        -ValueName "DisableSoftLanding" -Type DWord -Value 1
    New-GPLink -Name $gpo.DisplayName -Target "OU=Workstations,OU=Lab,$(($Domain.Split('.')|%{"DC=$_"}) -join ',')" -ErrorAction SilentlyContinue
    Write-Host "[+] Sample GPO created and linked to Workstations OU."
}

Write-Host "[+] SRV01 configured: domain-joined, file share, sample GPO." -ForegroundColor Green
