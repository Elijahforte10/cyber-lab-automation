<#
    99-Teardown.ps1 -- destroy the lab so you can rebuild from scratch.
    Powers off and DELETES every lab VM and its disks. The host-only network is
    left intact (re-used on next build).

    Rebuild = run: 99-Teardown -> 01 -> 02 -> 03 -> 04 (per VM) -> 05.

    Usage:
      .\99-Teardown.ps1            # prompts for confirmation
      .\99-Teardown.ps1 -Force     # no prompt
#>
param([switch]$Force)
. (Join-Path $PSScriptRoot "lab-config.ps1")

if (-not $Force) {
    $ans = Read-Host "This DELETES all lab VMs and disks. Type 'DELETE' to proceed"
    if ($ans -ne "DELETE") { Write-Host "Aborted."; return }
}

foreach ($vm in $VMs) {
    $n = $vm.Name
    Write-Host "[*] Removing $n..." -ForegroundColor Cyan
    & $VBoxManage controlvm $n poweroff 2>$null
    Start-Sleep -Seconds 2
    & $VBoxManage unregistervm $n --delete 2>$null
}

Write-Host "[+] Lab torn down. Rebuild with 01 -> 02 -> 03 -> 04 -> 05." -ForegroundColor Green
