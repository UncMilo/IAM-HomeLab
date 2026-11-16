# 04 — Intune Win32 app: deployment, troubleshooting and uninstall

## Objective

Deploy **7-Zip 26.06 (x64 edition)** to CLOUDCLIENT01, validate MSI detection and Intune reporting, then uninstall it remotely.

## Packaging and deployment

1. Download the official 7-Zip x64 MSI in the lab. The package used was `7z2606-x64.msi`.
2. Use Microsoft's **Win32 Content Prep Tool** (`IntuneWinAppUtil.exe`) to wrap the MSI into `.intunewin` format. In this lab the output was `C:\IntuneLab\Output\7z2606-x64.intunewin`.
3. In **Intune admin center → Apps → Windows → Add**, select **Windows app (Win32)** and upload the `.intunewin` package.
4. Configure the app title `7-Zip 26.06 (x64 edition)` and publisher `Igor Pavlov`.
5. Configure the installation and uninstall commands for the MSI and use an **MSI product-code detection rule**.
6. Assign **Required** to `SG-Intune-Pilot-Devices` (included; no exclusions).
7. Verify the correct CLOUDCLIENT01 Entra object is in the pilot group.
8. From **Intune → Devices → CLOUDCLIENT01**, initiate **Sync**; optionally sync from Windows Settings under the MDM connection.
9. Verify locally and in Intune reports.

### MSI installation identifiers

```text
Product code: {23170F69-40C1-2702-2606-000001000000}
Example silent uninstall: msiexec.exe /x "{23170F69-40C1-2702-2606-000001000000}" /qn /norestart
```

### Local verification

```powershell
Get-Service IntuneManagementExtension |
  Select-Object Name,Status,StartType
Test-Path 'C:\Program Files\7-Zip\7z.exe'
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' |
  Where-Object DisplayName -like '7-Zip*' |
  Select-Object DisplayName,DisplayVersion,PSChildName
```

**Observed:** IME Running/Automatic, executable present, installed version `26.06.00.0`, MSI product code matched detection rule. Intune's installation details eventually showed **App installation completed** at 11:16:46 on the lab day (after an earlier agent-installation failure event).

## Troubleshooting notes

- An Intune **sync completed** or **applications offered** result does not prove app installation.
- The IME service was initially absent despite a manually MDM-enrolled record. Investigation uncovered two different Entra device objects for CLOUDCLIENT01.
- The current joined device was successfully re-enrolled under the matching Entra identity; the pilot group was retargeted, after which Windows displayed the IME software distribution notification for 7-Zip.
- Always verify both the file/MSI registration **and** Intune's device-level app installation result.
- See IME logs under `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` when needed.

## Remote uninstall lab

1. Open **Apps → Windows → 7-Zip 26.06 → Properties → Assignments**.
2. Remove the existing **Required** pilot-group assignment so it will not fight with uninstall intent.
3. Add `SG-Intune-Pilot-Devices` under **Uninstall**, included; save.
4. Confirm the app's configured uninstall command matches its MSI product code.
5. Sync the active CLOUDCLIENT01 from Intune and from Windows MDM settings.
6. Verify removal:

   ```powershell
   Test-Path 'C:\Program Files\7-Zip\7z.exe' # Expected: False
   Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' |
     Where-Object DisplayName -like '7-Zip*'
   ```

7. Check the updated Intune device install/managed apps reports for removal status.

**Evidence caveat:** User reported completing the uninstall workflow; explicit final uninstall log screenshots are not preserved in this guide. Do not claim a specific final Intune uninstall status without new evidence.
