<#
    04-Configure-Guests.ps1 -- push guest-scripts into each VM and run them via
    VBoxManage guestcontrol (Guest Additions were installed in step 03).

    Because several steps reboot (forest promotion, domain joins), run this
    per-VM and re-run after a reboot where noted. Start with DC01.

    Usage:
      .\04-Configure-Guests.ps1 -Target DC01
      .\04-Configure-Guests.ps1 -Target SRV01
      .\04-Configure-Guests.ps1 -Target CLIENT01
      .\04-Configure-Guests.ps1 -Target LINUX01
      .\04-Configure-Guests.ps1 -Target SIEM01
#>
param([Parameter(Mandatory)][ValidateSet("DC01","SRV01","CLIENT01","LINUX01","SIEM01")][string]$Target)

. (Join-Path $PSScriptRoot "lab-config.ps1")
$gs = Join-Path $PSScriptRoot "guest-scripts"

function Push-And-Run-Windows {
    param($VM, $LocalScript, $GuestPath, $ArgList = @())
    $user = $LocalAdminUser; $pass = $LocalAdminPass
    Write-Host "[*] Copying $LocalScript -> $VM:$GuestPath" -ForegroundColor Cyan
    Invoke-VBox guestcontrol $VM --username $user --password $pass `
        copyto $LocalScript $GuestPath
    Write-Host "[*] Executing on $VM..." -ForegroundColor Cyan
    $runArgs = @("guestcontrol",$VM,"--username",$user,"--password",$pass,
        "run","--exe","C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
        "--","powershell","-ExecutionPolicy","Bypass","-File",$GuestPath) + $ArgList
    & $VBoxManage @runArgs
}

function Push-And-Run-Linux {
    param($VM, $LocalScript, $GuestPath, $ArgString = "")
    $user = $LinuxUser; $pass = $LinuxPass
    Write-Host "[*] Copying $LocalScript -> $VM:$GuestPath" -ForegroundColor Cyan
    Invoke-VBox guestcontrol $VM --username $user --password $pass `
        copyto $LocalScript $GuestPath
    Write-Host "[*] Executing on $VM (sudo)..." -ForegroundColor Cyan
    & $VBoxManage guestcontrol $VM --username $user --password $pass `
        run --exe /bin/bash -- bash -c "sudo bash $GuestPath $ArgString"
}

# SIEM01's lab-LAN IP (DHCP-assigned). Discover it before agent enrollment, or
# set a reservation. Placeholder default; update after SIEM01 is up.
$SiemIp = "192.168.56.50"

switch ($Target) {
    "DC01" {
        Push-And-Run-Windows "DC01" "$gs\Configure-DC.ps1" "C:\Configure-DC.ps1" `
            @("-Domain",$Domain,"-NetBIOS",$DomainNetBIOS,"-StaticIp",$DcStaticIp,
              "-DhcpStart",$DhcpStart,"-DhcpEnd",$DhcpEnd,"-SafeModePw",$LocalAdminPass)
        Write-Host "`n[!] DC01 will reboot after forest promotion. Re-run this same command after it boots to finish DHCP/OUs/users." -ForegroundColor Yellow
    }
    "SRV01" {
        Push-And-Run-Windows "SRV01" "$gs\Configure-SRV.ps1" "C:\Configure-SRV.ps1" `
            @("-Domain",$Domain,"-DcIp",$DcStaticIp,"-JoinUser","$DomainNetBIOS\$LocalAdminUser","-JoinPass",$LocalAdminPass)
        Push-And-Run-Windows "SRV01" "$gs\Install-WazuhAgent.ps1" "C:\Install-WazuhAgent.ps1" @("-ManagerIp",$SiemIp)
    }
    "CLIENT01" {
        Push-And-Run-Windows "CLIENT01" "$gs\Join-Domain.ps1" "C:\Join-Domain.ps1" `
            @("-Domain",$Domain,"-DcIp",$DcStaticIp,"-JoinUser","$DomainNetBIOS\$LocalAdminUser","-JoinPass",$LocalAdminPass)
        Push-And-Run-Windows "CLIENT01" "$gs\Install-WazuhAgent.ps1" "C:\Install-WazuhAgent.ps1" @("-ManagerIp",$SiemIp)
    }
    "LINUX01" {
        Push-And-Run-Linux "LINUX01" "$gs/setup-linux.sh" "/tmp/setup-linux.sh"
        Push-And-Run-Linux "LINUX01" "$gs/install-wazuh-agent.sh" "/tmp/install-wazuh-agent.sh" $SiemIp
    }
    "SIEM01" {
        Push-And-Run-Linux "SIEM01" "$gs/install-wazuh.sh" "/tmp/install-wazuh.sh"
        Write-Host "`n[!] Note SIEM01's lab-LAN IP, then set `$SiemIp in this script before enrolling agents." -ForegroundColor Yellow
    }
}

Write-Host "[+] $Target step issued." -ForegroundColor Green
