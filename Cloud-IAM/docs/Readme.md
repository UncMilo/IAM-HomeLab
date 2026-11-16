# 09 — Microsoft Entra ID & Intune: Cloud Identity and Endpoint Troubleshooting Case Study

> **Project type:** Self-directed lab | **Platform:** Microsoft Entra ID, Microsoft Intune, Windows 11 Enterprise Evaluation, VirtualBox | **Status:** Deployment and policy results verified; uninstall workflow reported complete, final uninstall evidence not preserved.
>
> **Architecture note:** The cloud environment was separate from the on-premises AD domain. No Microsoft Entra Connect synchronization was configured.

## 1. Business scenario and objectives

This lab simulated the work of an identity/endpoint administrator onboarding and securing a Windows device, applying endpoint security controls, and distributing software through Microsoft Intune. A device initially reported successful MDM sync but did not receive the assigned Win32 app. Troubleshooting led to an identity/enrollment repair and a verified installation.

**Learning goals:** understand Entra join vs MDM enrollment; enforce configuration and compliance; target policies and apps with security groups; use local and portal evidence; distinguish a successful sync from a successful Win32 installation; investigate device-registration mismatches.

## 2. Environment

| Component | Configuration |
|---|---|
| Cloud endpoint | `CLOUDCLIENT01`, Windows 11 Enterprise Evaluation VM |
| VirtualBox network | NAT (internet-connected, independent of on-premises IT-LAB) |
| Test tenant | Microsoft Entra ID training tenant |
| Cloud user | `alex.morgan` (fictional test identity, Intune licensed) |
| Pilot group | `SG-Intune-Pilot-Devices` |
| Configuration profile | `WIN-Cloud-AutoLock-10min` |
| Compliance policy | `WIN-Cloud-Security-Compliance` |
| Win32 application | `7-Zip 26.06 (x64 edition)` |

**Privacy:** The account and tenant names in this guide are fictional lab examples. Omit passwords, tokens, device certificate thumbprints and live tenant identifiers from public evidence.

## 3. Lab A — Cloud identity and device management

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com/) and create or select the lab's licensed test identity. Verify the required sign-in and MFA flow.
2. Create/select the device pilot security group `SG-Intune-Pilot-Devices` and verify the target device is a member. Remember that **group membership must refer to the correct device object**, not merely an object with the same computer name.
3. Configure Windows 11 Enterprise Evaluation on `CLOUDCLIENT01` with internet access using VirtualBox NAT.
4. In Windows, open **Settings → Accounts → Access work or school**. Use **Enroll only in device management** where manual enrollment is required by the lab license configuration. The tenant did not support Entra ID Premium automatic MDM enrollment.
5. Review the device in [Intune admin center](https://intune.microsoft.com/) under **Devices → All devices** and confirm device check-in and management state.
6. Open an elevated PowerShell session and record the current device registration state:

   ```powershell
   dsregcmd /status
   ```

   Relevant fields: `AzureAdJoined`, `DeviceAuthStatus`, `AzureAdPrt`, and `DeviceId`. **The Entra join `DeviceId` should correspond to the Entra device ID on the active Intune managed-device record.** The Intune managed device's own ID is a separate identifier.

### Evidence to capture

- Entra device **Join type**, **Owner**, and **MDM** (with sensitive identifiers masked).
- Intune device **Last check-in** and **Microsoft Entra device ID**.
- Relevant `dsregcmd /status` fields only (redact tokens and tenant-specific details).

## 4. Lab B — Windows inactivity lock policy

1. Go to **Intune → Devices → Configuration** and create a Windows configuration profile.
2. Name it `WIN-Cloud-AutoLock-10min`.
3. Configure **Interactive logon: Machine inactivity limit** to **600 seconds**.
4. Assign it to `SG-Intune-Pilot-Devices` under **Included** groups, with no accidental exclusion of the same group.
5. Sync `CLOUDCLIENT01` and inspect its **Device configuration** report. The lab reported **Succeeded**.
6. Verify locally:

   ```powershell
   Get-ItemPropertyValue `
     'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
     -Name InactivityTimeoutSecs
   ```

   **Observed:** `600`.

## 5. Lab C — Endpoint security compliance

1. In **Intune → Devices → Compliance**, create `WIN-Cloud-Security-Compliance` for Windows.
2. Require **Firewall**, **Antivirus**, **Microsoft Defender Antimalware**, and **Real-time protection**.
3. Assign to `SG-Intune-Pilot-Devices` and sync the device.
4. Verify Defender and Windows Firewall locally:

   ```powershell
   Get-MpComputerStatus |
     Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled

   Get-NetFirewallProfile |
     Select-Object Name, Enabled
   ```

5. Verify the policy's **device-specific status** in Intune.

**Observed:** Defender components enabled; firewall profiles enabled; device marked **Compliant** under the lab policy.

## 6. Lab D — Entra join and mismatched device identities

### Symptom

The original manual MDM registration and later Entra join resulted in **two device records with the same display name**. An older MDM-only record had no meaningful join type or owner in Entra, while the newly joined record displayed **Microsoft Entra joined** and a signed-in owner but initially lacked MDM management. The existing IME installation was also missing or unstable.

### Investigation

1. Examine **Settings → Accounts → Access work or school**. The machine initially displayed both a tenant MDM connection and an Entra ID connection.
2. Confirm the Entra join with `dsregcmd /status`:
   - `AzureAdJoined : YES`
   - `DeviceAuthStatus : SUCCESS`
   - `AzureAdPrt : YES` after signing into Windows as the Entra account.
3. In the Entra admin center, compare the two `CLOUDCLIENT01` objects' device IDs, join types and MDM fields.
4. In Intune, inspect the active managed-device record's **Microsoft Entra device ID** and compare it to the local `dsregcmd` device ID. **Do not compare the separate Intune managed-device ID to the Entra join ID.**

### Repair carried out in this lab

1. Take a **VirtualBox snapshot** before identity/enrollment changes.
2. Preserve the valid Entra join; remove only the obsolete MDM connection from the Windows **Access work or school** settings.
3. Manually re-enroll the now Entra-joined device in Intune, sign in with the licensed test user, and sync.
4. Confirm a fresh active Intune managed-device record references the correct joined Entra device ID.
5. Ensure `SG-Intune-Pilot-Devices` includes the **current** Entra device object.
6. Remove obsolete cloud records only after confirming the correct active enrollment and device check-in.

**Result:** The device became both Entra-joined and Intune-managed under matching Entra identity. It was compliant, checked in and subsequently received its assigned Win32 application.

> **Production warning:** These steps describe one isolated lab repair, not a general-purpose MDM recovery procedure. In production, use approved change control and enrollment recovery guidance.

## 7. Lab E — Deploy 7-Zip as a Win32 app

1. Obtain the official x64 MSI `7z2606-x64.msi` and Microsoft's `IntuneWinAppUtil.exe` packaging tool.
2. Package the MSI into `7z2606-x64.intunewin` (lab output: `C:\IntuneLab\Output\7z2606-x64.intunewin`).
3. Go to **Intune → Apps → Windows → Add → Windows app (Win32)** and upload the package.
4. Configure the metadata: **7-Zip 26.06 (x64 edition)**, publisher **Igor Pavlov**.
5. Specify the appropriate silent MSI installation/uninstallation commands; set an MSI detection rule using the exact product code observed in this lab:

   ```text
   {23170F69-40C1-2702-2606-000001000000}
   ```

6. Under **Assignments**, add `SG-Intune-Pilot-Devices` to **Required**; avoid exclusions.
7. Sync the active managed device. Check the Win32 app device-install-status report separately from the MDM sync-status panel.
8. Verify on the client:

   ```powershell
   Get-Service IntuneManagementExtension |
     Select-Object Name, Status, StartType

   Test-Path 'C:\Program Files\7-Zip\7z.exe'

   Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' |
     Where-Object { $_.DisplayName -like '7-Zip*' } |
     Select-Object DisplayName, DisplayVersion, PSChildName
   ```

**Verified outcome:** IME **Running / Automatic**; `Test-Path` **True**; installed version **26.06.00.0**; matching MSI product code. The Intune installation-details panel displayed **App installation completed** at 11:16:46 on the lab day.

## 8. Win32 troubleshooting case study

| Finding | Meaning / response |
|---|---|
| MDM sync reported `Applications: offered` | The device received an offer; this is **not proof of installation** |
| `7z.exe` missing | Application not yet present on disk |
| `Get-Service IntuneManagementExtension` returned no service | IME not installed at that time |
| Installer event log showed IME install and removal events | Extension installation state was unstable |
| `AppWorkload.log` contained null-reference policy retrieval errors | Win32 app policy retrieval failed, requiring further diagnosis |
| Two Entra objects shared the `CLOUDCLIENT01` name | App assignment and management identity needed reconciliation |
| After enrollment repair, Windows displayed IME software distribution notification | Win32 delivery was active |
| Intune reported `App installation completed` | Portal corroboration of local installation evidence |

Logs investigated: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AppWorkload.log` and `IntuneManagementExtension.log`. Do not publish unredacted logs containing auth details.

## 9. Lab F — Remote uninstall

1. In **Intune → Apps → Windows → 7-Zip → Properties → Assignments**, remove the **Required** assignment for the pilot group.
2. Under **Uninstall**, include `SG-Intune-Pilot-Devices`; save the assignment.
3. Verify the application's configured uninstall command. For this MSI, a suitable example is:

   ```powershell
   msiexec.exe /x "{23170F69-40C1-2702-2606-000001000000}" /qn /norestart
   ```

4. Sync the active device. Review Intune's device install-status / managed-app status.
5. Validate locally:

   ```powershell
   Test-Path 'C:\Program Files\7-Zip\7z.exe'
   ```

   Expected after uninstall: `False`. Also check that the MSI uninstall-registry entry no longer exists.

**Evidence limitation:** The uninstall procedure was reported complete in conversation, but the final local uninstall check and final Intune app status were not retained as screenshots. Do not describe the final status as independently verified by this document.

## 10. Portfolio artifacts to include

Recommended **sanitized** images under `evidence/cloud/`:

- `entra-joined-device.png` — Entra join type, owner, management fields.
- `intune-managed-device.png` — active Intune record / compliance status.
- `intune-compliance-policy.png` — compliance result.
- `intune-inactivity-policy.png` — configuration Succeeded result.
- `intune-win32-install-completed.png` — final Intune app installation details.
- `windows-7zip-msi-verification.png` — local service, executable and MSI registry evidence.

For every image, remove usernames that are not fictitious, login/session data, certificates, tenant/device IDs, and other private information.

## 11. Lessons learned and production gaps

- **Entra join is distinct from MDM enrollment.** A Windows endpoint can be joined but not MDM-managed, or MDM-managed under a different record.
- **Directory object identity matters more than display name.** Two objects named `CLOUDCLIENT01` are not interchangeable for group assignments.
- **Compliance and application management are separate systems.** A device can sync policies and report compliant while app installation is failing.
- **Troubleshoot using both local evidence and cloud reports.** Service state, registry/MSI registration, client logs and portal installation statuses each answer different questions.
- **Licensing must be documented.** This lab did not have Entra ID Premium automatic MDM enrollment; advanced identity governance and Conditional Access features should not be claimed as implemented.
- **Uninstall should be verified independently.** A successful assignment change is not proof of complete removal.

### Resume-ready project summary

> **Microsoft Entra ID and Intune Endpoint Management Homelab:** Entra-joined and manually enrolled a Windows 11 endpoint into Intune; deployed a 10-minute inactivity configuration policy and endpoint security compliance checks; packaged and deployed an MSI-based Win32 app. Diagnosed conflicting Entra/Intune device records and Intune Management Extension policy-delivery errors, repaired enrollment and verified app deployment through Windows and Intune evidence.
