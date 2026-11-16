# 03 — Microsoft Entra ID and Intune device management

## Objective

Build a separate cloud-managed endpoint and practice tenant identities, device registration, compliance and configuration policies.

## Environment

- **CLOUDCLIENT01**: separate Windows 11 Enterprise Evaluation VM, VirtualBox NAT network.
- **Microsoft Entra tenant**: training tenant separate from `corp.sunrock.test` (no Entra Connect synchronization).
- **Test identity:** Alex Morgan, cloud user with an Intune license.
- **Pilot group:** `SG-Intune-Pilot-Devices`.

## Step-by-step summary

1. In the Entra admin center, create or identify a licensed test user and verify MFA sign-in.
2. In Intune, create `SG-Intune-Pilot-Devices` as the assignment target; verify its device membership before deploying policies.
3. Manually enroll CLOUDCLIENT01 into MDM from **Settings → Accounts → Access work or school → Enroll only in device management** (the lab tenant did not have Entra ID Premium for automatic MDM enrollment).
4. Configure `WIN-Cloud-AutoLock-10min` with machine inactivity limit `600` seconds; assign it to the pilot device group.
5. Verify the setting on CLOUDCLIENT01:

   ```powershell
   Get-ItemPropertyValue `
     'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
     -Name InactivityTimeoutSecs
   ```

6. Configure `WIN-Cloud-Security-Compliance` to check Firewall, Antivirus, Microsoft Defender Antimalware and real-time protection. Assign to the pilot group.
7. Verify Windows Defender and Firewall:

   ```powershell
   Get-MpComputerStatus |
     Select-Object AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled
   Get-NetFirewallProfile | Select-Object Name,Enabled
   ```

8. In Intune, verify the configuration profile result and compliance status for CLOUDCLIENT01.

## Important enrollment troubleshooting finding

Initially an MDM-only device identity and an Entra-joined device identity differed. The enrolled record remained managed, while the joined record was not MDM managed.

**Repair performed in the lab:**

1. Preserve the VM with a VirtualBox snapshot.
2. Confirm the Entra join with `dsregcmd /status`: `AzureAdJoined=YES`, `DeviceAuthStatus=SUCCESS`, `AzureAdPrt=YES`.
3. Disconnect **only** the obsolete MDM-only connection from Windows Settings, retaining the Entra ID connection.
4. Re-enroll manually via **Enroll only in device management**, sign in as the test user and sync.
5. Open **Intune → Devices → CLOUDCLIENT01 → Device details → System** and compare **Microsoft Entra device ID** to `dsregcmd /status`.
6. Add the **current** Entra-joined device object to `SG-Intune-Pilot-Devices` and verify compliance.
7. Clean up obsolete records only after identifying the active record and verifying management.

**Result:** The Intune record's Microsoft Entra device ID matched the joined Windows device; Win32 deployment subsequently started working.

**Caution:** Manual enrollment behavior and available features vary by tenant, licensing and Windows build. Do not copy this as a blanket production repair runbook. Never disconnect a managed production device without change control, backup and recovery planning.
