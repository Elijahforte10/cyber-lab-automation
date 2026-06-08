<#
    02-Provision-VMs.ps1 -- create all 5 VMs: specs, disk, NICs, attached ISO.
    Idempotent-ish: skips a VM that already exists. Does NOT start them (that's
    step 03 unattended install).
#>
. (Join-Path $PSScriptRoot "lab-config.ps1")

if (-not (Test-Path $LabRoot)) { New-Item -ItemType Directory -Path $LabRoot | Out-Null }

$registered = & $VBoxManage list vms

foreach ($vm in $VMs) {
    $name = $vm.Name
    if ($registered -match "`"$name`"") {
        Write-Host "[-] $name already exists -- skipping. (use 99-Teardown to remove)" -ForegroundColor Yellow
        continue
    }

    Write-Host "[*] Creating $name ($($vm.OS))..." -ForegroundColor Cyan
    $osType = if ($vm.OS -eq "Linux") { "Ubuntu_64" }
              elseif ($vm.Win11)      { "Windows11_64" }
              else                    { "Windows2019_64" }

    # Create & register
    Invoke-VBox createvm --name $name --ostype $osType --basefolder $LabRoot --register

    # CPU / RAM / firmware
    Invoke-VBox modifyvm $name --cpus $vm.CPU --memory $vm.RAM --vram 128 `
                --graphicscontroller vmsvga --ioapic on --rtcuseutc on

    # Windows 11 requires EFI + TPM 2.0 + Secure Boot
    if ($vm.Win11) {
        Invoke-VBox modifyvm $name --firmware efi --tpm-type 2.0
    } elseif ($vm.OS -ne "Linux") {
        Invoke-VBox modifyvm $name --firmware bios
    }

    # NIC1 = NAT (internet), NIC2 = Host-Only (lab LAN)
    Invoke-VBox modifyvm $name --nic1 nat
    Invoke-VBox modifyvm $name --nic2 hostonly --hostonlyadapter2 $HostOnlyNic

    # Disk
    $disk = Join-Path $LabRoot "$name\$name.vdi"
    Invoke-VBox createmedium disk --filename $disk --size $vm.Disk --format VDI
    Invoke-VBox storagectl $name --name "SATA" --add sata --controller IntelAhci --portcount 2
    Invoke-VBox storageattach $name --storagectl "SATA" --port 0 --device 0 --type hdd --medium $disk

    # Attach install ISO on a DVD drive
    Invoke-VBox storageattach $name --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium $vm.Iso

    # Boot order: disk then dvd (unattended install handles first boot)
    Invoke-VBox modifyvm $name --boot1 disk --boot2 dvd --boot3 none --boot4 none

    Write-Host "[+] $name created: $($vm.CPU) vCPU, $($vm.RAM) MB, $([math]::Round($vm.Disk/1024)) GB" -ForegroundColor Green
}

Write-Host "`n[*] Provisioning complete. Next: .\03-Install-OS.ps1" -ForegroundColor Cyan
