<#
    Join-Domain.ps1 -- runs INSIDE CLIENT01 (Windows 11).
    Points DNS at DC01 and joins the domain. After reboot you can log in as a
    domain user (e.g. LAB\bsmith / Welcome123!) for user-activity simulation.
#>
param(
    [string]$Domain   = "lab.local",
    [string]$DcIp     = "192.168.56.10",
    [string]$JoinUser = "LAB\labadmin",
    [string]$JoinPass = "P@ssw0rd-Lab-2026!"
)
$ErrorActionPreference = "Stop"

$adapter = Get-NetAdapter | Where-Object Status -eq "Up" | Sort-Object ifIndex | Select-Object -Last 1
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DcIp

if ((Get-CimInstance Win32_ComputerSystem).PartOfDomain -ne $true) {
    Write-Host "[*] Joining $Domain..."
    $sec  = ConvertTo-SecureString $JoinPass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($JoinUser, $sec)
    Add-Computer -DomainName $Domain -Credential $cred -Restart -Force
} else {
    Write-Host "[+] CLIENT01 already domain-joined." -ForegroundColor Green
}
