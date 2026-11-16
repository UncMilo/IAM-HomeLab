# 08 — Consolidated audit reporting and security lessons

## Objective

Merge existing IAM lifecycle audit CSVs into one analyst-friendly report and explain findings.

## Audit sources

```text
C:\IAMLab\AuditLogs
├── IAM-Joiner-Audit.csv
├── IAM-Mover-Audit.csv
├── IAM-Leaver-Audit.csv
├── IAM-CSV-Joiner-Audit.csv
├── IAM-CSV-Mover-Audit.csv
└── IAM-CSV-Leaver-Audit.csv
```

## Step-by-step

1. Save the tested script `Get-IAMAuditReport.ps1` in `C:\IAMLab\Scripts`.
2. Run on DC01:

   ```powershell
   cd C:\IAMLab\Scripts
   .\Get-IAMAuditReport.ps1
   ```

3. Open the consolidated output:

   ```powershell
   Import-Csv 'C:\IAMLab\Reports\IAM-Consolidated-Audit.csv' |
     Select-Object Timestamp,RequestId,Username,Action,Result |
     Format-Table -AutoSize
   ```

4. Filter failures/rejections:

   ```powershell
   Import-Csv 'C:\IAMLab\Reports\IAM-Consolidated-Audit.csv' |
     Where-Object Result -eq 'Failed' |
     Format-List Timestamp,RequestId,Operator,Username,Action,Details
   ```

## Verified final result

| Metric | Value |
|---|---:|
| Total audit events | **25** |
| Success | **23** |
| Started | **1** |
| Failed | **1** |

The Failed event was the expected duplicate-account rejection for Sophie (`IAM-006`), **not** a failed account creation. The Started event recorded initiation of Daniel's Mover workflow (`IAM-005`), which had later successful completion steps.

Request coverage:

| ID | Workflow | Identity |
|---|---|---|
| IAM-003 | Leaver | Emma Wilson |
| IAM-004 | Joiner | Daniel Carter |
| IAM-005 | Mover | Daniel Carter |
| IAM-006 | CSV Joiner + duplicate rejection | Sophie Brown |
| IAM-007 | CSV Mover | Sophie Brown |
| IAM-008 | CSV Leaver | Sophie Brown |

## Issues encountered and remediation

| Issue | Investigation | Resolution |
|---|---|---|
| Emma retained Finance access after transfer | `whoami /groups`, `Get-Acl`, `Get-SmbShareAccess` | Removed broad `BUILTIN\Users` access on Finance folder |
| HR group still appeared in Emma's Windows token | Compare `whoami /groups` against AD `MemberOf` | Fresh domain logon; validate SMB access; disable test account again |
| Intune Win32 app missing | IME service, logs, `dsregcmd /status`, old vs new Entra IDs | Re-enrolled correct device identity and retargeted pilot group |
| ADUC HR OU initially looked empty after Mover | Script audit and AD state disagreed with GUI | Refreshed/reopened ADUC; account was present |
| `Test-IAMRequest.ps1` path not found | Prompt was already `C:\IAMLab\Scripts` | Used `..\Requests\IAM-006.csv` relative path |
| `IAM-007.csv` import warning | `Import-Csv` generated `H1` | Corrected CSV header and raw row; verified with `Get-Content` |
| Consolidated report lacked CSV Leaver file | CSV Leaver had only been dry-run | Executed IAM-008 and regenerated report |

## Production hardening backlog (not implemented)

- Independent approval check against HR/ticketing system, separation of duties.
- Restricted delegated admin identity rather than Domain Administrator for every workflow.
- Configuration-driven mapping plus signed/reviewed change control.
- Comprehensive entitlement discovery across AD, file services, groups, applications and cloud.
- Credential handling via managed identity, secret store or other approved process.
- Idempotent restart/recovery after partial execution, retries and reconciliation.
- Protected/append-only centralized audit pipeline and retention controls; time synchronization and unique event correlation.
- Verified session revocation for SMB, workstation, VPN and cloud refresh tokens where relevant.
- Approver review evidence, scheduled access recertification and exception workflows.

**Next planned lab:** Read-only access review comparing department attributes, group membership and disabled-account state. This was proposed but not yet created or executed.
