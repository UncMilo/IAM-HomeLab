# SC-300 — Identity Governance Labs

**Microsoft Identity and Access Administrator | Hands-on SC-300 Preparation**

This section documents my practical experience with identity governance using **Windows Server Active Directory, PowerShell, Microsoft Entra ID P2, Privileged Identity Management (PIM), and Microsoft Entra Access Reviews**.

All exercises were performed in a dedicated training environment using fictional employee identities. Active cloud account identifiers are redacted from public evidence.

---

## Lab Overview

| Lab | Topic | Status |
|---|---|---|
| Lab 19 | Automated Active Directory Access Reviews | ✅ Completed |
| Lab 21 | Microsoft Entra Privileged Identity Management | ✅ Completed |
| Lab 22 | Microsoft Entra Access Reviews | ✅ Completed |

## Lab 19 — Automated Active Directory Access Reviews

**Objective:** Detect and investigate inappropriate departmental access using a read-only PowerShell reporting script.

### Activities performed

1. Inspected Finance and HR security group memberships.
2. Created `Get-IAMAccessReview.ps1`.
3. Compared user account status, department attributes and group memberships.
4. Generated `IAM-Access-Review.csv`.
5. Simulated a disabled employee retaining HR group access.
6. Detected the violation and marked it `REVIEW REQUIRED`.
7. Added severity classification and remediation recommendations.
8. Removed the unauthorized group membership.
9. Generated clean post-remediation reports and saved audit evidence.

### Verified result

A disabled employee retaining HR group membership was correctly identified. After remediation, the employee's account remained disabled, the unnecessary entitlement was removed, and the review returned to `OK`.

**Skills demonstrated:** PowerShell automation, RBAC, least privilege, entitlement auditing, risk classification and remediation verification.

---

## Lab 21 — Microsoft Entra Privileged Identity Management

**Objective:** Replace permanent administrator privileges with Just-in-Time (JIT) access using Microsoft Entra PIM.

### Activities performed

1. Activated a Microsoft Entra ID P2 trial for the lab tenant.
2. Inspected the existing permanent Helpdesk Administrator assignment.
3. Converted the IT Support Lab account from active to eligible.
4. Verified that no permanent active assignment remained.
5. Signed in using the dedicated IT Support Lab account.
6. Activated Helpdesk Administrator through PIM.
7. Verified the activation under Active assignments.
8. Inspected PIM audit history.
9. Manually deactivated the privileged role.
10. Confirmed that the eligible assignment remained available.

### Verified result

The account successfully moved through the lifecycle:

**Active assignment → Eligible assignment → Temporary activation → Audit → Deactivation**

The main tenant administrator account remained unchanged.

**Skills demonstrated:** Privileged access management, Just-in-Time administration, eligible versus active assignments, PIM audit logging and least privilege.

---

## Lab 22 — Microsoft Entra Access Reviews

**Objective:** Review cloud security-group membership, record certification decisions and implement access remediation.

### Activities performed

1. Created `SG-IAM-AccessReview-Lab`.
2. Added two internal test users.
3. Configured a one-time access review with the scope set to Everyone.
4. Assigned group owners as reviewers.
5. Required review justifications.
6. Disabled automatic application of review results.
7. Approved Alex Morgan's continued group membership.
8. Denied IT Support Lab's continued membership.
9. Verified that review decisions did not automatically modify the group.
10. Manually removed the denied group membership.
11. Verified the remaining membership.
12. Located the successful removal event in Microsoft Entra audit logs.

### Verified result

| Test user | Review decision | Final access |
|---|---|---|
| Alex Morgan | Approved | Membership retained |
| IT Support Lab | Denied | Membership removed |

The audit trail identified the target user and the security group associated with the successful removal.

**Skills demonstrated:** Identity governance, access certification, resource-owner reviews, reviewer recommendations, approval and denial decisions, access remediation and directory auditing.

---

## Identity Governance Lifecycle

These exercises demonstrate the relationship between identity lifecycle management and governance:

**Provision access → Review entitlements → Identify excessive access → Approve or deny → Remediate → Verify → Audit**

The Active Directory exercise used PowerShell to simulate a recurring access review. The Microsoft Entra exercise used native cloud access-review functionality.

---

## Security Considerations

- All identities and employee scenarios are fictional training examples.
- Active cloud email addresses and tenant identifiers must not be published.
- Privileged roles should be activated only when required.
- Group membership changes should follow an authorized review or request.
- Review recommendations are advisory; reviewers remain responsible for decisions.
- A denied review decision does not necessarily remove access unless the result is applied or an administrator performs remediation.
- Trial licensing and feature availability may differ from production environments.
- CSV files and screenshots provide lab evidence, not a tamper-proof enterprise audit system.

---

## SC-300 Skills Demonstrated

- Identity governance and entitlement reviews
- Microsoft Entra Privileged Identity Management
- Just-in-Time privileged role activation
- Role assignment lifecycle management
- Cloud security-group access certification
- PowerShell-based access auditing
- Access remediation and verification
- Microsoft Entra audit-log investigation
- Least-privilege security principles

## Career Relevance

These labs demonstrate hands-on skills relevant to **IAM Analyst, Identity and Access Administrator, Junior IAM Engineer and IT Support Engineer** roles.

The project is part of my independent preparation for the **Microsoft SC-300 certification** and represents practical training experience rather than production-environment administration.

---

**Environment:** VirtualBox, Windows Server, Active Directory Domain Services, PowerShell, Microsoft Entra ID P2.

**Completed:** November 2026.
