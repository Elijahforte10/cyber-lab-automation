<#
    03-Install-OS.ps1 -- drive VirtualBox unattended OS installs.

    Uses `VBoxManage unattended install`, which auto-generates the answer file
    (autounattend.xml for Windows, preseed/cloud-init for Linux), creates the
    admin user, and installs Guest Additions so later guestcontrol works.

    *** THIS IS THE PART TO TEST FIRST AND TUNE PER-ISO. ***
    - Windows Server unattended may need a product key and explicit edition.
      Add:  --key "XXXXX-..."  and  --image-index N  (find indexes with:
      VBoxManage unattended detect --iso <path>)
    - Run one VM at a time when first validating.

    Usage:
      .\03-Install-OS.ps1               # install all
      .\03-Install-OS.ps1 -Only DC01    # just one
#>
param([string]$Only)

. (Join-Path $PSScriptRoot "lab-config.ps1")

foreach ($vm in $VMs) {
    if ($Only -and $vm.Name -ne $Only) { continue }
    $name = $vm.Name
    Write-Host "[*] Unattended install: $name" -ForegroundColor Cyan

    $hostname = $name.ToLower()
    if ($vm.OS -eq "Linux") {
        $user = $LinuxUser; $pass = $LinuxPass
    } else {
        $user = $LocalAdminUser; $pass = $LocalAdminPass
    }

    # Detect installable images (useful for Windows edition index)
    Write-Host "    (detecting ISO; for Windows note the desired --image-index)" -ForegroundColor DarkGray
    & $VBoxManage unattended detect --iso $vm.Iso | Out-Host

    $args = @(
        "unattended","install",$name,
        "--iso=$($vm.Iso)",
        "--user=$user",
        "--password=$pass",
        "--full-user-name=$user",
        "--hostname=$hostname.$Domain",
        "--locale=en_US",
        "--time-zone=UTC",
        "--install-additions",
        "--start-vm=gui"
    )
    # For Windows Server you will likely need to append, e.g.:
    #   "--key=XXXXX-XXXXX-XXXXX-XXXXX-XXXXX","--image-index=2"

    & $VBoxManage @args
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "$name unattended install reported an error -- check ISO/key/index."
    } else {
        Write-Host "[+] $name installing (watch the GUI window)." -ForegroundColor Green
    }
}

Write-Host "`n[*] Wait for installs to finish + reach desktop/login, then run 04-Configure-Guests.ps1" -ForegroundColor Cyan
