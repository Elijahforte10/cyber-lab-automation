<#
    05-Snapshot-All.ps1 -- take a named snapshot of every VM so you can roll the
    whole lab back to a clean baseline (or any milestone) instantly.

    Usage:
      .\05-Snapshot-All.ps1                       # snapshot "clean-baseline"
      .\05-Snapshot-All.ps1 -Name "pre-attack"
      .\05-Snapshot-All.ps1 -Restore "clean-baseline"
#>
param(
    [string]$Name = "clean-baseline",
    [string]$Restore
)
. (Join-Path $PSScriptRoot "lab-config.ps1")

foreach ($vm in $VMs) {
    $n = $vm.Name
    if ($Restore) {
        Write-Host "[*] Restoring $n -> snapshot '$Restore'..." -ForegroundColor Cyan
        & $VBoxManage controlvm $n poweroff 2>$null
        Start-Sleep -Seconds 2
        Invoke-VBox snapshot $n restore $Restore
    } else {
        Write-Host "[*] Snapshotting $n -> '$Name'..." -ForegroundColor Cyan
        Invoke-VBox snapshot $n take $Name --description "Lab snapshot $(Get-Date -Format s)"
    }
}

if ($Restore) {
    Write-Host "[+] All VMs restored to '$Restore'. Power them on when ready." -ForegroundColor Green
} else {
    Write-Host "[+] Snapshot '$Name' taken on all VMs." -ForegroundColor Green
}
