<#
    lab-config.ps1 -- central configuration for the cyber lab.
    Edit this ONE file to retune the whole lab, then run the numbered scripts.
    Every other script dot-sources this: . .\lab-config.ps1
#>

# --- Paths -------------------------------------------------------------------
$Global:LabRoot   = "C:\CyberLab"                 # where VM disks/configs live
$Global:IsoDir    = "C:\CyberLab\ISOs"            # put your ISOs here

# Point these at YOUR actual ISO files:
$Global:Iso = @{
    WS2019  = Join-Path $IsoDir "WindowsServer2019.iso"
    WS2016  = Join-Path $IsoDir "WindowsServer2016.iso"
    Win11   = Join-Path $IsoDir "Windows11.iso"
    Linux   = Join-Path $IsoDir "ubuntu-22.04-live-server.iso"
}

# --- Domain / network --------------------------------------------------------
$Global:Domain        = "lab.local"
$Global:DomainNetBIOS = "LAB"
$Global:LabSubnet     = "192.168.56.0"
$Global:LabNetmask    = "255.255.255.0"
$Global:HostOnlyIp    = "192.168.56.1"            # host side of vboxnet0
$Global:DcStaticIp    = "192.168.56.10"
$Global:DhcpStart     = "192.168.56.100"
$Global:DhcpEnd       = "192.168.56.200"
$Global:HostOnlyNic   = "vboxnet0"                 # adjust if VBox names it differently

# --- Credentials (CHANGE THESE; lab use only) --------------------------------
$Global:LocalAdminUser = "labadmin"
$Global:LocalAdminPass = "P@ssw0rd-Lab-2026!"      # also DSRM / domain admin seed
$Global:LinuxUser      = "labadmin"
$Global:LinuxPass      = "P@ssw0rd-Lab-2026!"

# --- VM definitions ----------------------------------------------------------
# RAM in MB, disk in MB. Tuned for a 32 GB host; see README for 16/64 GB tiers.
$Global:VMs = @(
    @{ Name="DC01";     OS="WS2019"; Iso=$Iso.WS2019; CPU=2; RAM=3072; Disk=61440; Win11=$false; Role="dc"     }
    @{ Name="SRV01";    OS="WS2016"; Iso=$Iso.WS2016; CPU=2; RAM=3072; Disk=61440; Win11=$false; Role="member" }
    @{ Name="CLIENT01"; OS="Win11";  Iso=$Iso.Win11;  CPU=2; RAM=4096; Disk=65536; Win11=$true;  Role="client" }
    @{ Name="LINUX01";  OS="Linux";  Iso=$Iso.Linux;  CPU=2; RAM=3072; Disk=40960; Win11=$false; Role="linux"  }
    @{ Name="SIEM01";   OS="Linux";  Iso=$Iso.Linux;  CPU=4; RAM=6144; Disk=61440; Win11=$false; Role="siem"   }
)

# --- VBoxManage location -----------------------------------------------------
$Global:VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
if (-not (Test-Path $VBoxManage)) {
    Write-Warning "VBoxManage not found at $VBoxManage -- edit lab-config.ps1."
}

function Invoke-VBox {
    param([Parameter(ValueFromRemainingArguments)] $Args)
    & $Global:VBoxManage @Args
    if ($LASTEXITCODE -ne 0) { Write-Warning "VBoxManage exited $LASTEXITCODE: $($Args -join ' ')" }
}
