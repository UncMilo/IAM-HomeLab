# 07 — CSV-driven JML: validate, execute, verify

## Goal

Replace hardcoded employee names with a standardized input request, preserve the validated role/OU mapping, run a dry run, execute and record auditable outcomes.

## Folder structure

```text
C:\IAMLab
├── Scripts
│   ├── Test-IAMRequest.ps1
│   ├── Invoke-IAMJoinerFromCSV.ps1
│   ├── Invoke-IAMMoverFromCSV.ps1
│   └── Invoke-IAMLeaverFromCSV.ps1
├── Requests
│   ├── IAM-006.csv
│   ├── IAM-007.csv
│   └── IAM-008.csv
└── AuditLogs
```

## IAM-006 — Joiner: Sophie Brown

Create `C:\IAMLab\Requests\IAM-006.csv`:

```csv
RequestId,Action,FirstName,LastName,Username,Department,JobTitle,ApprovalStatus
IAM-006,Joiner,Sophie,Brown,sophie.brown,Finance,Finance Analyst,Approved
```

1. Import and inspect:

   ```powershell
   Import-Csv C:\IAMLab\Requests\IAM-006.csv | Format-List
   ```

2. Run the **read-only validator**; it checks required fields, username format, duplicate accounts, allowed department, target OU and group:

   ```powershell
   cd C:\IAMLab\Scripts
   .\Test-IAMRequest.ps1 -Path '..\Requests\IAM-006.csv' | Format-List
   ```

3. Run the Joiner workflow with WhatIf:

   ```powershell
   .\Invoke-IAMJoinerFromCSV.ps1 -Path '..\Requests\IAM-006.csv' -WhatIf
   ```

4. Verify `Get-ADUser -Filter "SamAccountName -eq 'sophie.brown'"` returns no account.
5. Run without `-WhatIf`, confirm and enter a temporary password securely.
6. The script creates a disabled user, assigns Finance group, enables account and verifies attributes/group/OU.
7. Verify four Success rows in `IAM-CSV-Joiner-Audit.csv`.
8. Rerun only the validator against the same CSV. **Expected:** rejection for `Account already exists: sophie.brown`.
9. Run the workflow against the duplicate request *for the negative test only*; it should reject before prompting for confirmation and record the failed/rejected attempt.

## IAM-007 — Mover: Sophie Brown, Finance → HR

Create `C:\IAMLab\Requests\IAM-007.csv`:

```csv
RequestId,Action,Username,SourceDepartment,TargetDepartment,NewJobTitle,ApprovalStatus
IAM-007,Mover,sophie.brown,Finance,HR,HR Specialist,Approved
```

1. Verify using `Import-Csv ... | Format-List`. If you see header `H1`, inspect the raw file using `Get-Content`: missing/extra leading columns can break CSV imports.
2. Execute the dry run:

   ```powershell
   .\Invoke-IAMMoverFromCSV.ps1 -Path '..\Requests\IAM-007.csv' -WhatIf
   ```

3. Confirm the employee, source and target departments, old/new groups and OU.
4. Run without WhatIf; confirm only after reviewing the target.
5. Verify five Success rows in `IAM-CSV-Mover-Audit.csv`.
6. On CLIENT01 sign in as Sophie and confirm **HR write access** plus denied **Finance** and **Development** access.

## IAM-008 — Leaver: Sophie Brown

Create `C:\IAMLab\Requests\IAM-008.csv`:

```csv
RequestId,Action,Username,ExpectedDepartment,ApprovalStatus
IAM-008,Leaver,sophie.brown,HR,Approved
```

1. Inspect the request using `Import-Csv`.
2. Run:

   ```powershell
   .\Invoke-IAMLeaverFromCSV.ps1 -Path '..\Requests\IAM-008.csv' -WhatIf
   Get-ADUser sophie.brown | Select-Object Name,Enabled,DistinguishedName
   ```

3. Verify Sophie remains enabled in HR after the dry run.
4. Execute the script without WhatIf and confirm the intended offboarding.
5. Verify four Success rows in `IAM-CSV-Leaver-Audit.csv`: **Disable account**, **Revoke department access**, **Move account**, **Final verification**.
6. Independently verify:

   ```powershell
   Get-ADUser sophie.brown -Properties MemberOf |
     Select-Object Name,Enabled,DistinguishedName,MemberOf
   ```

**Observed:** Sophie disabled, in DisabledUsers OU, HR membership removed.

## Design limits and future upgrades

- Files currently contain one request apiece; batch processing is **not** yet implemented.
- `Approved` in a user-writable CSV is **not** proof of approval. Production requires ticket-system/HR authorization checks.
- The scripts log actions locally to CSV; the logs are **not tamper-resistant**.
- Error handling may leave partially completed changes. Inspect AD manually before retry.
- The Leaver removes the known departmental group; it does **not** enumerate every possible entitlement or terminate existing sessions.
- Always use fresh test identities when reproducing the full lifecycle; the documented lab identities are no longer in their initial states.
