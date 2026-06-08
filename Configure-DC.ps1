<#
    Configure-DC.ps1 -- runs INSIDE DC01.
    Sets static IP, promotes to a new AD forest, configures DHCP, and seeds a
    realistic OU structure with test users. Designed to be run in two passes:
    the forest promotion forces a reboot, so re-running after reboot continues.

    Variables are injected by the orchestrator (04-Configure-Guests.ps1) via a
    generated header, or set them here for manual runs.
#>
param(
    [string]$Domain     = "lab.local",
    [string]$NetBIOS    = "LAB",
    [string]$StaticIp   = "192.168.56.10",
    [string]$Prefix     = "24",
    [string]$DhcpStart  = "192.168.56.100",
    [string]$DhcpEnd    = "192.168.56.200",
    [string]$SafeModePw = "P@ssw0rd-Lab-2026!"
)

$ErrorActionPreference = "Stop"

function Set-LabStaticIp {
    # NIC2 is the host-only lab LAN adapter (the one without a NAT gateway).
    $adapter = Get-NetAdapter | Where-Object Status -eq "Up" |
               Sort-Object ifIndex | Select-Object -Last 1
    Write-Host "[*] Setting static IP $StaticIp on $($adapter.Name)..."
    New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $StaticIp `
        -PrefixLength $Prefix -ErrorAction SilentlyContinue | Out-Null
    # DNS points at itself once promoted
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $StaticIp
}

function Install-Forest {
    if (-not (Get-WindowsFeature AD-Domain-Services).Installed) {
        Write-Host "[*] Installing AD DS role..."
        Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
    }
    if (-not (Get-Service NTDS -ErrorAction SilentlyContinue)) {
        Write-Host "[*] Promoting to forest $Domain (will REBOOT)..."
        $sm = ConvertTo-SecureString $SafeModePw -AsPlainText -Force
        Install-ADDSForest -DomainName $Domain -DomainNetbiosName $NetBIOS `
            -SafeModeAdministratorPassword $sm -InstallDns `
            -Force -NoRebootOnCompletion:$false
    } else {
        Write-Host "[+] Domain already present."
    }
}

function Install-Dhcp {
    if (-not (Get-WindowsFeature DHCP).Installed) {
        Write-Host "[*] Installing DHCP role..."
        Install-WindowsFeature DHCP -IncludeManagementTools
        Add-DhcpServerInDC -DnsName "dc01.$Domain" -IPAddress $StaticIp
    }
    $scopeName = "LabScope"
    if (-not (Get-DhcpServerv4Scope -ErrorAction SilentlyContinue |
              Where-Object Name -eq $scopeName)) {
        Write-Host "[*] Creating DHCP scope $DhcpStart-$DhcpEnd..."
        Add-DhcpServerv4Scope -Name $scopeName -StartRange $DhcpStart `
            -EndRange $DhcpEnd -SubnetMask 255.255.255.0 -State Active
        Set-DhcpServerv4OptionValue -DnsServer $StaticIp -DnsDomain $Domain -Router $StaticIp
    }
}

function New-LabOuStructure {
    $base = ($Domain.Split('.') | ForEach-Object { "DC=$_" }) -join ","
    foreach ($ou in @("Lab","Lab/Users","Lab/Admins","Lab/Workstations","Lab/Servers","Lab/Groups")) {
        $parts = $ou.Split('/')
        $name = $parts[-1]
        $path = if ($parts.Count -eq 1) { $base } else {
            (($parts[0..($parts.Count-2)] | ForEach-Object { "OU=$_" })[($parts.Count-2)..0] -join ",") + ",$base"
        }
        if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$name'" -SearchBase $path -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $name -Path $path -ProtectedFromAccidentalDeletion $false
            Write-Host "    [+] OU: $ou"
        }
    }
}

function New-TestUsers {
    $base = ($Domain.Split('.') | ForEach-Object { "DC=$_" }) -join ","
    $usersOu = "OU=Users,OU=Lab,$base"
    $pw = ConvertTo-SecureString "Welcome123!" -AsPlainText -Force
    $people = @(
        @{First="Alice"; Last="Nguyen";  Dept="Finance"}
        @{First="Bob";   Last="Smith";   Dept="IT"}
        @{First="Carol"; Last="Davis";   Dept="HR"}
        @{First="David"; Last="Lopez";   Dept="Sales"}
        @{First="Eve";   Last="Martinez";Dept="IT"}
    )
    foreach ($p in $people) {
        $sam = ($p.First.Substring(0,1) + $p.Last).ToLower()
        if (-not (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue)) {
            New-ADUser -Name "$($p.First) $($p.Last)" -GivenName $p.First -Surname $p.Last `
                -SamAccountName $sam -UserPrincipalName "$sam@$Domain" `
                -Department $p.Dept -Path $usersOu -AccountPassword $pw `
                -Enabled $true -ChangePasswordAtLogon $true
            Write-Host "    [+] User: $sam ($($p.Dept))"
        }
    }
}

# --- Orchestration ----------------------------------------------------------
# Pass 1 (pre-reboot): static IP + forest promotion.
# Pass 2 (post-reboot): DHCP + OUs + users.
if (-not (Get-Service NTDS -ErrorAction SilentlyContinue)) {
    Set-LabStaticIp
    Install-Forest          # reboots here
} else {
    Install-Dhcp
    New-LabOuStructure
    New-TestUsers
    Write-Host "[+] DC01 fully configured: AD + DNS + DHCP + OUs + users." -ForegroundColor Green
}
