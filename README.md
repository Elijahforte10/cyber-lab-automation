# Cyber Lab Automation (VirtualBox)

A repeatable, config-driven enterprise security lab for Windows hosts using
**VirtualBox + `VBoxManage`**. Deploy, snapshot, destroy, and rebuild a 5-VM
Active Directory + SIEM environment with minimal manual effort.

Built for: AD administration, IAM, Windows Server, security monitoring,
vulnerability management, SOC analyst practice, and Security+/CySA+ study.

## Architecture

```
                    NAT (internet/updates)            Host-Only vboxnet0 (lab LAN)
                          |                                  192.168.56.0/24
   +------------+   +------------+   +-------------+   +-----------+   +-----------+
   |   DC01     |   |   SRV01    |   |  CLIENT01   |   | LINUX01   |   |  SIEM01   |
   | WS2019     |   | WS2016     |   | Win11       |   | Docker    |   | Wazuh     |
   | AD/DNS/DHCP|   | member/FS  |   | domain-join |   | web/tools |   | indexer   |
   | .10 static |   |  /GPO      |   | user sim    |   | DVWA tgt  |   | dashboard |
   +------------+   +------------+   +-------------+   +-----------+   +-----------+
        |                |                 |                |               |
        +----------------+--------- agents forward logs ---------------> SIEM01
```

- **DC01** is authoritative for DHCP + DNS on the lab LAN (VBox host-only DHCP
  is disabled by `01-Setup-Networks.ps1`).
- Every VM has **NAT (NIC1)** for internet and **Host-Only (NIC2)** for the lab.

## Hardware tiers

The default `lab-config.ps1` is tuned for a **32 GB host**. Run
`00-Get-HostSpecs.ps1` first; then:

| RAM | What to do |
|---|---|
| 16 GB | Run an **AD track** (DC01+SRV01+CLIENT01) *or* **SOC track** (LINUX01+SIEM01), not all 5 at once. |
| 32 GB | Default config: all 5, SIEM at 6 GB. |
| 64 GB | Bump `SIEM01` RAM to 8192 in `lab-config.ps1`. |

An **SSD/NVMe is strongly recommended** and keep ~300 GB free (snapshots grow).

## Host prerequisites (one time)

1. **Use VirtualBox only** -- don't run VMware Workstation at the same time.
2. Install **VirtualBox + the Extension Pack**.
3. **Hyper-V/VBS conflict:** for full VT-x speed, disable *Core Isolation ->
   Memory Integrity*, and if VBox still runs slow:
   ```
   bcdedit /set hypervisorlaunchtype off    (reboot; disables WSL2/Docker Desktop)
   ```
4. Put your ISOs in `C:\CyberLab\ISOs` and update paths in `lab-config.ps1`.

## Run order

```powershell
.\00-Get-HostSpecs.ps1                 # confirm tier, tune lab-config.ps1
.\01-Setup-Networks.ps1                # host-only net, disable VBox DHCP
.\02-Provision-VMs.ps1                 # create all 5 VMs (specs/disk/NIC/ISO)
.\03-Install-OS.ps1                    # unattended OS installs  <-- TEST FIRST
# wait for installs to reach login...
.\04-Configure-Guests.ps1 -Target DC01      # promote forest (reboots)
.\04-Configure-Guests.ps1 -Target DC01      # re-run: DHCP + OUs + users
.\04-Configure-Guests.ps1 -Target SIEM01    # install Wazuh; note its IP
# set $SiemIp in 04-Configure-Guests.ps1, then:
.\04-Configure-Guests.ps1 -Target SRV01
.\04-Configure-Guests.ps1 -Target CLIENT01
.\04-Configure-Guests.ps1 -Target LINUX01
.\05-Snapshot-All.ps1                  # "clean-baseline" snapshot
```

Roll back anytime: `.\05-Snapshot-All.ps1 -Restore clean-baseline`
Full rebuild: `.\99-Teardown.ps1` then re-run `01 -> 05`.

## What gets built

- **DC01:** AD forest `lab.local`, DNS, DHCP scope, OU tree (Users/Admins/
  Workstations/Servers/Groups), 5 test users.
- **SRV01:** domain-joined, `\\SRV01\Department` file share, sample GPO.
- **CLIENT01:** domain-joined Win11 for user-activity simulation.
- **LINUX01:** Docker + nmap/tcpdump, DVWA vulnerable target on :8080.
- **SIEM01:** Wazuh all-in-one; agents on the other four forward logs here.

## Honest caveats (read these)

- **`03-Install-OS.ps1` is the part to validate first.** `VBoxManage unattended`
  auto-builds answer files, but **Windows Server installs usually need a product
  key and an explicit edition index** -- run `VBoxManage unattended detect --iso
  <path>` and add `--key` / `--image-index`. Test one VM before batching.
- **Reboot timing isn't fully hands-off.** Forest promotion and domain joins
  reboot the guest; re-run the relevant `04` step after the VM is back up. The
  scripts are written to be safe to re-run.
- **Win11 in VBox needs EFI + TPM 2.0** (set automatically). If install still
  blocks, your Win11 ISO may also want Secure Boot enabled in VM settings.
- **These are PowerShell host scripts** -- author-tested for structure; run them
  against your environment and expect per-ISO tuning. The Linux guest scripts
  are plain bash and the most portable part.
- **Lab credentials in `lab-config.ps1` are placeholders -- change them.** This
  lab is isolated training infrastructure, not production.

## Tech used

PowerShell (host orchestration), `VBoxManage` (VM/network/snapshot/guestcontrol),
PowerShell DSC-style config inside Windows guests, Bash inside Linux guests,
Wazuh (SIEM).
