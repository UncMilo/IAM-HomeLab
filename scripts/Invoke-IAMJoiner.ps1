
# Lab 13 - IAM Joiner Automation
# Simulated approved HR request: IAM-004

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestId
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

# Employee details from the approved lab request
$Username = 'daniel.carter'
$FirstName = 'Daniel'
$LastName = 'Carter'
$Department = 'Finance'
$JobTitle = 'Finance Analyst'
$TargetOU = 'OU=Finance,OU=Employees,DC=corp,DC=sunrock,DC=test'
$GroupName = 'GG_Finance_Users'
$UPN = "$Username@corp.sunrock.test"

$AuditFile = 'C:\IAMLab\AuditLogs\IAM-Joiner-Audit.csv'
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

# Safety check: avoid duplicate identities
$ExistingUser = Get-ADUser -Filter {
    SamAccountName -eq $Username -or UserPrincipalName -eq $UPN
}

if ($ExistingUser) {
    throw "Safety check failed: account $Username already exists."
}

# Verify the requested OU and security group exist
Get-ADOrganizationalUnit -Identity $TargetOU | Out-Null
$Group = Get-ADGroup -Identity $GroupName

if ($Group.GroupCategory -ne 'Security' -or
    $Group.GroupScope -ne 'Global') {
    throw 'Safety check failed: unexpected group type or scope.'
}

Write-Host "Request: $RequestId"
Write-Host "Employee: $FirstName $LastName"
Write-Host "Username: $Username"
Write-Host "Department: $Department"
Write-Host "Target OU: $TargetOU"
Write-Host "Assign group: $GroupName"

$Description = 'Create employee account and assign Finance access'

if ($PSCmdlet.ShouldProcess($Username, $Description)) {
    try {
        # Prompt only during actual execution.
        # Password is not written to the audit log.
        $Password = Read-Host 'Enter temporary password' -AsSecureString

        New-ADUser `
            -Name "$FirstName $LastName" `
            -GivenName $FirstName `
            -Surname $LastName `
            -SamAccountName $Username `
            -UserPrincipalName $UPN `
            -Department $Department `
            -Title $JobTitle `
            -Path $TargetOU `
            -AccountPassword $Password `
            -ChangePasswordAtLogon $true `
            -Enabled $true

        Write-IAMAudit 'Create account' 'Success' $TargetOU

        Add-ADGroupMember -Identity $GroupName -Members $Username

        Write-IAMAudit 'Assign access' 'Success' $GroupName

        Write-Host 'Employee onboarding completed.' -ForegroundColor Green
    }
    catch {
        Write-IAMAudit 'Onboarding' 'Failed' $_.Exception.Message
        throw
    }
}
