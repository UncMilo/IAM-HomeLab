# 02 — AGDLP / RBAC / least-privilege file access

## Objective

Use **AGDLP** (Accounts → Global groups → Domain Local groups → Permissions) to grant department access; verify both successful and denied operations.

## Groups used

| Department | Global Security group | Domain Local Security group |
|---|---|---|
| Development | `GG_Development_Users` | `DL_Development_Modify` |
| Finance | `GG_Finance_Users` | `DL_Finance_Modify` |
| HR | `GG_HR_Users` | `DL_HR_Modify` |

## Step-by-step: Finance example

1. Open **Active Directory Users and Computers** (ADUC) on DC01.
2. Under `OU=SecurityGroups`, create `GG_Finance_Users` as **Global / Security**.
3. Create `DL_Finance_Modify` as **Domain local / Security**.
4. Open `DL_Finance_Modify` → **Members** → add `GG_Finance_Users`.
5. Create the folder `C:\LabShares\Finance` on DC01 (the existing `C:\LabShares` root was reused).
6. Set folder **NTFS** permissions: retain SYSTEM and Administrators Full Control; grant `DL_Finance_Modify` **Modify** to this folder, subfolders and files. Limit broad users' access on the departmental folder.
7. In **Sharing → Advanced Sharing**, share as `Finance`; configure `DL_Finance_Modify` with **Change + Read** and retain appropriate administrator access.
8. Add a Finance employee to `GG_Finance_Users`, not directly to the ACL.
9. On CLIENT01, sign in as the employee; access `\\DC01\Finance`, create, edit and save a test file.
10. Attempt `\\DC01\Development`; confirm unauthorized access is denied.

Repeat the same design for `C:\LabShares\HR` shared as `\\DC01\HR`, using `GG_HR_Users` and `DL_HR_Modify`.

## Verification examples

```powershell
# DC01: inspect NTFS ACLs
(Get-Acl 'C:\LabShares\Finance').Access |
  Format-Table IdentityReference,FileSystemRights,AccessControlType,IsInherited -AutoSize

# DC01: inspect SMB share access
Get-SmbShareAccess -Name Finance
Get-SmbShareAccess -Name HR

# CLIENT01: inspect domain groups in current token
whoami /groups

# DC01: list active SMB connections
Get-SmbSession | Select-Object ClientComputerName,ClientUserName,NumOpens
```

## Incident: Finance access persisted after employee transfer

**Symptoms:** Emma Wilson moved from Finance to HR and no longer belonged to `GG_Finance_Users`, yet could still access Finance.

**Root cause identified:** `C:\LabShares\Finance` still granted `BUILTIN\Users` **ReadAndExecute** and **CreateFiles/AppendData** via explicit NTFS permissions.

**Correction:** Remove overly broad Users entries *from the Finance folder only*, retain admin/system permissions and `DL_Finance_Modify`. Avoid explicit Deny as a workaround. Refresh the user's Windows session and verify effective access.

**Evidence:** Emma and later Daniel/Sophie could access HR while Finance and Development were denied after the correction.

> Note: Access to a share can come through multiple permission paths; revoking a group membership alone is not enough if another ACL grants access. Share permissions and NTFS permissions both apply for SMB access.
