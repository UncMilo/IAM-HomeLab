# Active Directory & Microsoft Entra IAM Homelab

**Hands-on identity and access management portfolio | Windows Server, Active Directory, Microsoft Entra ID, Intune & PowerShell**

> **Scope:** A self-directed training environment, not a production deployment. Names, organization and identities in this repository are fictional lab examples. Screenshots and outputs should be sanitized before publishing.

## Project overview

I built a hybrid-themed identity and endpoint lab to practice the **Joiner–Mover–Leaver (JML)** lifecycle, role-based access control (**RBAC**), least privilege, Win32 application management, device compliance, incident troubleshooting, and PowerShell-based audit reporting.

The on-premises AD domain and Microsoft Entra tenant are **separate**: I did not deploy Microsoft Entra Connect synchronization. The lab illustrates both environments, not a synchronized hybrid directory.

### Verified outcomes

| Area | Evidence / outcome |
|---|---|
| Active Directory | Domain controller and domain-joined workstation; organizational units and security groups |
| Authorization | AGDLP group nesting; departmental SMB shares; allowed and denied access tests |
| Identity lifecycle | Manual JML process for Emma Wilson; automated JML for Daniel Carter and Sophie Brown |
| Automation | PowerShell `-WhatIf`, CSV requests, validation, group management, OU moves and audit logging |
| Endpoint management | CLOUDCLIENT01 Entra joined, manually enrolled in Intune; device compliance and inactivity policy |
| Software deployment | Packaged, deployed, detected and uninstalled 7-Zip 26.06 via Intune Win32 app management |
| Audit consolidation | **25 events:** 23 Success, 1 Started, 1 Failed (duplicate request correctly blocked) |

### Architecture

```text
VirtualBox host
├── IT-LAB (isolated internal network)
│   ├── DC01          Windows Server / AD DS / DNS / SMB     192.168.50.10
│   └── CLIENT01      Windows 11 / joined to AD domain      192.168.50.20
└── NAT (internet access)
    └── CLOUDCLIENT01 Windows 11 / Entra joined / Intune MDM

AD domain: corp.sunrock.test
Cloud tenant: separate Microsoft Entra environment (not directory-synced)
```

### Repository navigation

| Guide | What it covers |
|---|---|
| [01 — Environment and directory](docs/01-environment-active-directory.md) | VirtualBox, domain, OUs, domain join and basic validation |
| [02 — RBAC and SMB access](docs/02-rbac-file-access.md) | AGDLP, NTFS/share ACLs, positive/negative access tests |
| [03 — Entra and Intune](docs/03-entra-intune.md) | Cloud registration, compliance, lock policy and enrollment caveats |
| [04 — Intune Win32 deployment](docs/04-intune-win32.md) | 7-Zip packaging, assignment, troubleshooting, deployment and uninstall |
| [05 — Manual JML](docs/05-manual-jml.md) | Emma Wilson joiner, mover and leaver |
| [06 — PowerShell JML](docs/06-powershell-jml.md) | Daniel Carter automation, WhatIf and per-action audit logs |
| [07 — CSV-driven JML](docs/07-csv-driven-jml.md) | Sophie Brown requests IAM-006 through IAM-008 |
| [08 — Audit and hardening](docs/08-audit-troubleshooting.md) | Consolidated report, lessons and production gaps |
| [Evidence checklist](evidence/README.md) | Screenshots and sensitive-data redaction |

## Lab timeline

| Lab / workstream | Status |
|---|---|
| On-premises AD fundamentals, GPO and permissions | Completed in lab; summarized where exact steps were not preserved |
| Entra ID and Intune policies | Completed |
| Lab 10 — Intune Win32 app installation | Verified in Windows and Intune |
| Lab 11 — Intune app uninstallation | Completed according to lab notes |
| Lab 12 — Manual Joiner–Mover–Leaver | Verified |
| Labs 13–14 — Hardcoded PowerShell Joiner/Mover plus Leaver | Verified |
| Lab 15 — CSV Joiner and duplicate prevention | Verified |
| Lab 16 — CSV Mover | Verified in AD and from Windows client |
| Lab 17 — CSV Leaver | Verified |
| Lab 18 — Consolidated audit | Verified |
| Access-review automation | **Planned**, not yet implemented |

## Key IAM security lessons

1. **Group membership is not the whole effective-access story.** Emma retained Finance access because `BUILTIN\\Users` had broad NTFS permissions; fixing the ACL resolved the exposure.
2. **Logon tokens and sessions matter.** An existing Windows session can show old group memberships after AD membership changes. Sign out and sign back in; check SMB sessions separately.
3. **Device identity matters.** A manual MDM record and an Entra-joined device initially had different identities, preventing reliable Win32 deployment. Re-enrollment aligned the IDs.
4. **Validation and audit logging matter.** A repeated Sophie Joiner request was rejected as a duplicate and recorded in the audit log.
5. **Evidence beats assumptions.** The project validates changes through AD user state, effective SMB access, Windows service state, application installation and Intune reports.

## Running the automation labs

The original tested scripts are stored on the lab DC at `C:\IAMLab\Scripts`. **Copy your actual tested `.ps1` files into this repository's [`scripts/`](scripts/) directory** before uploading; this starter package intentionally does not substitute unverified re-creations of those scripts.

```powershell
# On DC01, first use -WhatIf; approve only after reviewing the target.
cd C:\IAMLab\Scripts
.\Invoke-IAMJoinerFromCSV.ps1 -Path '..\Requests\IAM-006.csv' -WhatIf
.\Invoke-IAMMoverFromCSV.ps1 -Path '..\Requests\IAM-007.csv' -WhatIf
.\Invoke-IAMLeaverFromCSV.ps1 -Path '..\Requests\IAM-008.csv' -WhatIf

# Consolidate existing local audit files
.\Get-IAMAuditReport.ps1
```

See the individual guides for chronological steps and verification commands. Do **not** replay these requests against an already-used AD domain: the documented users were already provisioned, transferred and/or disabled.

## Career relevance

This independent lab demonstrates practical experience with identity provisioning, deprovisioning, RBAC, Windows authentication, AD DS, device identities, Microsoft Intune and auditable PowerShell workflows. It supports preparation for **Microsoft SC-300** identity and access administration topics; it is not a claim of production IAM experience.

## Security and publication notes

Never publish real passwords, SecureString values, authentication tokens, certificates, real organizational identifiers, sensitive device IDs, live employee data or raw security logs. Export and redact screenshots before adding them to [`evidence/`](evidence/). Treat CSV `ApprovalStatus=Approved` as a **simulation**, not a trusted approval source. See [audit and hardening notes](docs/08-audit-troubleshooting.md).
