<#
    00-Get-HostSpecs.ps1 -- capture host hardware so you can tune lab-config.ps1.
    Run first. Tells you which RAM tier you're in and whether VT-x is usable.
#>

Write-Host "`n=== Host Hardware Summary ===" -ForegroundColor Cyan
$cs  = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB)

Write-Host ("CPU            : {0}" -f $cpu.Name)
Write-Host ("Cores/Threads  : {0} cores / {1} threads" -f $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors)
Write-Host ("Total RAM      : {0} GB" -f $ramGB)

Get-PhysicalDisk | ForEach-Object {
    Write-Host ("Disk           : {0}  [{1}]  {2} GB" -f $_.FriendlyName, $_.MediaType, [math]::Round($_.Size/1GB))
}
$free = [math]::Round((Get-PSDrive C).Free / 1GB)
Write-Host ("Free on C:     : {0} GB" -f $free)

Write-Host "`n=== Recommendation ===" -ForegroundColor Cyan
if     ($ramGB -le 16) { Write-Host "16 GB tier: run AD track OR SOC track, not all 5 at once." -ForegroundColor Yellow }
elseif ($ramGB -le 32) { Write-Host "32 GB tier: all 5 VMs OK with lean SIEM (default config)." -ForegroundColor Green }
else                   { Write-Host "64 GB+ tier: bump SIEM01 RAM to 8192 in lab-config.ps1." -ForegroundColor Green }

if ($free -lt 300) { Write-Host "WARNING: <300 GB free on C:. Snapshots will grow -- free up space or relocate `$LabRoot." -ForegroundColor Red }

# Virtualization / Hyper-V conflict check
$hv = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
if ($hv) {
    Write-Host "`nHyper-V/VBS appears PRESENT -- VirtualBox may run in slow paravirt mode." -ForegroundColor Yellow
    Write-Host "For full VT-x speed: disable Core Isolation > Memory Integrity, and optionally:" -ForegroundColor Yellow
    Write-Host "  bcdedit /set hypervisorlaunchtype off   (reboot required; disables WSL2/Docker Desktop)" -ForegroundColor Yellow
} else {
    Write-Host "`nNo active hypervisor detected -- VirtualBox should get full VT-x. Good." -ForegroundColor Green
}
