# SC-300 Governance Labs 19, 21 and 22 — GitHub Upload Pack

This folder contains **three Markdown guides** plus **15 selected evidence screenshots** from the IAM homelab.

## Add to your existing `IAM-HomeLab` repository

1. Upload the three Markdown files from `docs/` into your repository's existing **root `docs/` folder**.
2. Upload the `evidence/SC300-governance/` folder into your repository's **root `evidence/` folder**. Keep the image paths unchanged.
3. Open each guide on GitHub and confirm all linked screenshots display.
4. Your existing tested `scripts/Get-IAMAccessReview.ps1` should remain the source of truth; this pack does not replace it.
5. Review the redactions and avoid uploading any unredacted source images or live cloud UPNs.

## Link from your main README

```markdown
| [Lab 19 — AD Access Reviews](docs/19-ad-access-reviews.md) | PowerShell entitlement review, severity and remediation |
| [Lab 21 — Entra PIM](docs/21-entra-pim-jit.md) | Eligible Helpdesk Administrator, JIT activation and audit |
| [Lab 22 — Entra Access Reviews](docs/22-entra-access-review.md) | Approve/deny, manual removal and directory audit |
| [Identity governance screenshots](evidence/SC300-governance/README.md) | Redacted lab evidence and limitations |
```

**Suggested commit message:** `Document SC-300 governance labs 19 21 22 with redacted evidence`
