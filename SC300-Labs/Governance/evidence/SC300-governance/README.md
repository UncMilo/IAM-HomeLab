# SC-300 Identity Governance — Screenshot Evidence

These screenshots come from **actual training-lab sessions on 17 November 2026**, not simulated portal mockups. Source filenames were standardized; the images were not used to create new identities or invent success messages.

## Lab 19 — On-premises AD Access Review

| File | Evidence |
|---|---|
| `19-01-baseline.png` | Review generated with five accounts and no initial findings |
| `19-02-risk-detected.png` | Disabled test user flagged `REVIEW REQUIRED` |
| `19-03-remediation.png` | Group membership removed; rerun returned `OK` |
| `19-04-severity-baseline.png` | Severity and recommendation fields exported |

## Lab 21 — Entra PIM

| File | Evidence |
|---|---|
| `21-01-eligible-assignment.png` | Role moved to eligible assignment |
| `21-02-my-roles-eligible.png` | Eligible Helpdesk Administrator shown in My roles |
| `21-03-role-activated.png` | Temporary active role assignment |
| `21-04-my-audit.png` | PIM personal audit events (tenant identifiers masked) |
| `21-05-role-deactivated.png` | Successful deactivation confirmation |

## Lab 22 — Entra Access Reviews

| File | Evidence |
|---|---|
| `22-01-review-active.png` | Access review active with two members in scope |
| `22-02-review-decisions.png` | One Approved, one Denied; active email addresses redacted |
| `22-03-before-remediation.png` | Two members remain after decisions; no automatic application |
| `22-04-after-remediation.png` | Denied member removed; one member remains |
| `22-05-removal-audit.png` | Core Directory removal event, Success |
| `22-06-target-details.png` | Audit targets, identifiers and UPN masked |

## Privacy and evidence integrity

- **Never publish original unredacted portal screenshots or raw audit exports** from the active cloud tenant.
- This package uses **opaque pixel replacement**, not reversible blur, for selected cloud account and directory identifiers.
- Fictional test display names and group names are retained for understanding the lab. **Review every image again before committing**, particularly new screenshots or outputs you add later.
- The source screenshots cannot independently establish PIM MFA and justification enforcement or the audit event's initiating administrator; the guides label those limitations.
- The governance license used was a time-limited **P2 trial**. Nothing in this repository implies a production deployment.
