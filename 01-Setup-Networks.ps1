<#
    01-Setup-Networks.ps1 -- create the lab networks.
    NIC1 on each VM uses built-in NAT (no setup needed).
    NIC2 uses this Host-Only network for the isolated lab LAN.
    VBox's own host-only DHCP is DISABLED so DC01 can serve DHCP authoritatively.
#>
. (Join-Path $PSScriptRoot "lab-config.ps1")

Write-Host "[*] Ensuring host-only network exists..." -ForegroundColor Cyan

# List existing host-only interfaces; create one if our expected name is absent.
$existing = & $VBoxManage list hostonlyifs
if ($existing -notmatch [regex]::Escape($HostOnlyNic)) {
    Write-Host "[*] Creating host-only interface..."
    & $VBoxManage hostonlyif create
    Start-Sleep -Seconds 2
    # Re-read to find the new interface name (often vboxnet0)
    $existing = & $VBoxManage list hostonlyifs
}

# Configure the host side IP on our interface
Invoke-VBox hostonlyif ipconfig $HostOnlyNic --ip $HostOnlyIp --netmask $LabNetmask

# Disable any VBox DHCP server on this interface (DC01 will own DHCP)
Write-Host "[*] Disabling VirtualBox host-only DHCP (DC01 will serve DHCP)..." -ForegroundColor Cyan
& $VBoxManage dhcpserver modify --interface $HostOnlyNic --disable 2>$null
if ($LASTEXITCODE -ne 0) {
    # No server existed; that's fine.
    Write-Host "    (no existing DHCP server on $HostOnlyNic -- nothing to disable)"
}

Write-Host "[+] Network ready: host-only $HostOnlyNic at $HostOnlyIp/$LabNetmask" -ForegroundColor Green
Write-Host "    Lab LAN: $LabSubnet  |  DC/DNS/DHCP: $DcStaticIp" -ForegroundColor Green
