# 05 — Manual Joiner–Mover–Leaver (JML): Emma Wilson

## Objective

Demonstrate a human-controlled identity lifecycle before automating it. All requests below are fictional approved lab scenarios.

### Joiner — IAM-001

1. In **ADUC → Employees → Finance**, create `Emma Wilson`, logon `emma.wilson`, UPN `emma.wilson@corp.sunrock.test`.
2. Set a temporary password and **User must change password at next logon**.
3. In **Organization**, set Department **Finance**, Title **Finance Analyst**.
4. Add Emma to `GG_Finance_Users`. Confirm that group is nested inside `DL_Finance_Modify`.
5. Confirm `C:\LabShares\Finance` has restricted NTFS and share ACLs; publish as `\\DC01\Finance`.
6. Sign into CLIENT01 as `CORP\emma.wilson`; change password if prompted.
7. Create, edit and save a file in `\\DC01\Finance`. Attempt `\\DC01\Development`; expect denied access.

**Observed:** Domain sign-in and Finance file creation succeeded; Development access was denied.

### Mover — IAM-002

1. Create HR OU under **Employees**.
2. Move Emma's existing AD object from Finance to HR; update Department to **HR** and Title to **HR Specialist**.
3. Remove `GG_Finance_Users` from **Member Of**.
4. Create `GG_HR_Users` (Global/Security) and `DL_HR_Modify` (Domain local/Security); nest Global in Domain Local.
5. Add Emma to `GG_HR_Users`.
6. Create `C:\LabShares\HR`; grant `DL_HR_Modify` **Modify** NTFS, **Change + Read** share access; retain SYSTEM/Administrators.
7. Sign Emma out and back in on CLIENT01. Test `\\DC01\HR` (allowed) and Finance/Development (denied).

**Incident and resolution:** Finance was still accessible even after Finance group membership removal. The Finance NTFS ACL granted broad `BUILTIN\Users` access. After removing the overly broad entries and retesting, HR worked and Finance was denied.

### Leaver — IAM-003

1. On DC01 capture a read-only pre-offboarding state:

   ```powershell
   Get-ADUser emma.wilson -Properties Department,Title,MemberOf,Enabled |
     Select-Object Name,SamAccountName,Department,Title,Enabled,DistinguishedName,MemberOf
   ```

2. Create `C:\IAMLab\AuditLogs` if needed.
3. Use `Invoke-IAMLeaver.ps1` from the original lab: run with `-RequestId IAM-003 -WhatIf`, verify target and actions, then run it without WhatIf and confirm.
4. The script disables Emma, removes `GG_HR_Users`, moves the object to `OU=DisabledUsers` and records a CSV audit row per action.
5. Verify:

   ```powershell
   Get-ADUser emma.wilson | Select-Object Name,Enabled,DistinguishedName
   Import-Csv C:\IAMLab\AuditLogs\IAM-Leaver-Audit.csv |
     Format-Table Timestamp,RequestId,Operator,Username,Action,Result
   Get-SmbSession | Select-Object ClientComputerName,ClientUserName,NumOpens
   ```

**Observed:** `Enabled=False`; location `DisabledUsers`; HR membership removed; audit actions all Success. `Get-SmbSession` returned no active SMB sessions at time of test.

### Re-enable incident investigation

Emma was temporarily enabled again for test authentication. Her active CLIENT01 token initially showed old HR group SIDs even though AD `MemberOf` was empty. After a new sign-in and fresh test, HR, Finance and Development shares all denied access. Emma was then **disabled again** and verified in `DisabledUsers`.

> Security note: AD disablement stops new authentication, but already-established sessions may persist. In a real organization, active sessions, VPN/cloud sessions and endpoint access also need review. Do not treat `Get-SmbSession` alone as complete session-revocation proof.
