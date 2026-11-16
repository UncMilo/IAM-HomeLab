# 01 — Environment and Active Directory foundation

> Some early infrastructure exercises are documented here from their confirmed end state. Original installation wizard details were not fully retained; steps marked **reproduction guidance** are general instructions rather than verified click-by-click historical actions.

## Lab topology

| VM | Purpose | VirtualBox network | Address |
|---|---|---|---|
| DC01 | Domain controller, DNS, file server | Internal Network `IT-LAB` | `192.168.50.10` |
| CLIENT01 | Domain-joined Windows 11 workstation | Internal Network `IT-LAB` | `192.168.50.20` |
| CLOUDCLIENT01 | Separate Entra/Intune Windows 11 workstation | NAT | DHCP / internet |

Domain: `corp.sunrock.test`; NetBIOS: `CORP`.

## Reproduction guidance: build the on-premises network

1. Create DC01 and CLIENT01 in VirtualBox and attach both to the same **Internal Network** named `IT-LAB`.
2. Assign static IPs as above, using `192.168.50.10` for the domain controller's DNS service.
3. On DC01, install AD DS and DNS, then promote it to a domain controller for the new forest `corp.sunrock.test`.
4. Join CLIENT01 to the `corp.sunrock.test` domain using an authorized domain account.
5. Confirm that DC01 and CLIENT01 can resolve each other over the isolated network. No internet is required for domain authentication in this setup.

## Verified OU design

```text
DC=corp,DC=sunrock,DC=test
├── OU=Employees
│   ├── OU=Development
│   ├── OU=Finance
│   ├── OU=HR           # added during JML Mover lab
│   └── OU=IT
├── OU=DisabledUsers
├── OU=SecurityGroups
└── OU=WorkStations
```

There is also a default **Domain Controllers** OU, plus standard AD containers.

## Read-only verification commands

```powershell
Import-Module ActiveDirectory
Get-ADDomain
Get-ADOrganizationalUnit -Filter * |
  Select-Object Name,DistinguishedName |
  Sort-Object DistinguishedName
Get-ADComputer -Filter * | Select-Object Name,Enabled
```

## Earlier foundational activities

The lab also covered AD account lifecycle operations, security events, GPO-driven 10-minute workstation auto-lock, account disablement and security logging. For screenshots or procedure details of these earlier tasks, add your original evidence rather than reconstructing unrecorded settings.

**Verification goal:** A domain-joined CLIENT01 can authenticate domain users and access appropriately permissioned SMB resources on DC01.
