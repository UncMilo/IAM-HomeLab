
# Lab 12 - IAM Leaver Automation
# Simulated approved request: IAM-003

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestId
)

$ErrorActionPreference = 'Stop'

Import-Module ActiveDirectory

$Username = 'emma.wilson'
$GroupName = 'GG_HR_Users'
$ExpectedOU = 'OU=HR,OU=Employees,DC=corp,DC=sunrock,DC=test'
$DisabledOU = 'OU=DisabledUsers,DC=corp,DC=sunrock,DC=test'
$AuditFile = 'C:\IAMLab\AuditLogs\IAM-Leaver-Audit.csv'
$Operator = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

function Write-IAMAudit {
    param(
        [string]$Action,
        [string]$Result,
        [string]$Details
    )

    [pscustomobject]@{
        Timestamp = (Get-Date).ToString('o')
        RequestId = $RequestId
        Operator  = $Operator
        Username  = $Username
        Action    = $Action
        Result    = $Result
        Details   = $Details
    } | Export-Csv -Path $AuditFile -Append -NoTypeInformation
}

# Verify the intended account and OU before making changes
$User = Get-ADUser -Identity $Username -Properties MemberOf, Enabled

if ($User.Name -ne 'Emma Wilson' -or
    -not $User.DistinguishedName.EndsWith($ExpectedOU)) {
    throw 'Safety check failed: unexpected user identity or OU.'
}

$Group = Get-ADGroup -Identity $GroupName
$HasHRAccess = $User.MemberOf -contains $Group.DistinguishedName

Write-Host "Request: $RequestId"
Write-Host "Employee: $($User.Name)"
Write-Host "Account enabled: $($User.Enabled)"
Write-Host "HR group membership: $HasHRAccess"
Write-Host "Destination: $DisabledOU"

$Description = 'Disable account, revoke HR access, move to DisabledUsers'

if ($PSCmdlet.ShouldProcess($Username, $Description)) {
    try {
        if ($User.Enabled) {
            Disable-ADAccount -Identity $User.DistinguishedName
            Write-IAMAudit 'Disable account' 'Success' 'AD account disabled'
        }

        if ($HasHRAccess) {
            Remove-ADGroupMember -Identity $GroupName `
                -Members $Username -Confirm:$false

            Write-IAMAudit 'Revoke HR access' 'Success' $GroupName
        }

        Move-ADObject -Identity $User.DistinguishedName `
            -TargetPath $DisabledOU

        Write-IAMAudit 'Move account' 'Success' $DisabledOU

        Write-Host 'Offboarding AD changes completed.' -ForegroundColor Green
    }
    catch {
        Write-IAMAudit 'Offboarding' 'Failed' $_.Exception.Message
        throw
    }
}
