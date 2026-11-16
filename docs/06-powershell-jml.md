# 06 — PowerShell Joiner, Mover and Leaver

## Objectives

Automate individual approved lab requests with PowerShell, safety validation, `SupportsShouldProcess`, `-WhatIf` and per-action audit trails.

### Working project layout

```text
C:\IAMLab
├── Scripts
│   ├── Invoke-IAMJoiner.ps1
│   ├── Invoke-IAMMover.ps1
│   └── Invoke-IAMLeaver.ps1
└── AuditLogs
    ├── IAM-Joiner-Audit.csv
    ├── IAM-Mover-Audit.csv
    └── IAM-Leaver-Audit.csv
```

## Request IAM-003 — Leaver (Emma Wilson)

1. Read the user's current AD state, OU and group memberships.
2. `Invoke-IAMLeaver.ps1` validates the expected employee and HR OU.
3. Run the dry run:

   ```powershell
   cd C:\IAMLab\Scripts
   .\Invoke-IAMLeaver.ps1 -RequestId IAM-003 -WhatIf
   ```

4. Verify that the target is Emma and no AD changes occur.
5. Execute with `-RequestId IAM-003`; review confirmation target.
6. Verify the AD account is disabled, moved to DisabledUsers, removed from HR group, and that **three audit entries** exist.

## Request IAM-004 — Joiner (Daniel Carter)

1. Confirm `daniel.carter` does not already exist:

   ```powershell
   Get-ADUser -Filter "SamAccountName -eq 'daniel.carter'"
   ```

2. Run `Invoke-IAMJoiner.ps1 -RequestId IAM-004 -WhatIf`.
3. Verify the target OU `Employees/Finance` and `GG_Finance_Users` group.
4. Execute the script, confirm the target and enter a unique temporary password at the secure prompt.
5. Inspect `IAM-Joiner-Audit.csv`; expect **Create account** and **Assign access**, both Success.
6. Confirm Daniel appears in Finance OU as an enabled Finance Analyst.

## Request IAM-005 — Mover (Daniel Carter)

1. Capture pre-transfer state using `Get-ADUser daniel.carter -Properties Department,Title,MemberOf,Enabled`.
2. Run `Invoke-IAMMover.ps1 -RequestId IAM-005 -WhatIf`.
3. Verify Finance → HR, `GG_Finance_Users` removal, `GG_HR_Users` addition, and HR OU destination.
4. Run the script without `-WhatIf` and confirm the target.
5. Read `IAM-Mover-Audit.csv`: **Transfer started**, **Revoke Finance access**, **Grant HR access**, **Update attributes**, **Move OU**, **Final verification**.
6. ADUC may need **F5** or reopening to display the new OU membership; avoid running the script twice because of stale UI state.
7. On CLIENT01 sign in as Daniel. Confirm HR file creation succeeds and Finance/Development access is denied.

## Safety patterns

- Avoid hardcoded passwords; prompt with `Read-Host -AsSecureString` only when executing.
- Validate identity, current OU, and group membership before changing AD.
- Use `-WhatIf` for preview and confirmation before execution.
- Log timestamp, request ID, operator, target, action and result.
- If an operation fails midstream, **inspect AD before retrying**: workflows are not transactional.
- The CSV `ApprovalStatus` exercise in later labs represents a simulated request, not independently verified approval.

> Copy the actual tested script files from DC01. This guide documents their behavior and commands but intentionally does not re-create their full source code from memory.
