
# Lab 14 - IAM Mover Automation
# Simulated approved request: IAM-005

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestId
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

# Approved lab request
$Username = 'daniel.carter'
$ExpectedName = 'Daniel Carter'
$SourceOU = 'OU=Finance,OU=Employees,DC=corp,DC=sunrock,DC=test'
$TargetOU = 'OU=HR,OU=Employees,DC=corp,DC=sunrock,DC=test'

$OldGroup = 'GG_Finance_Users'
$NewGroup = 'GG_HR_Users'
$NewDepartment = 'HR'
$NewTitle = 'HR Specialist'

$AuditFile = 'C:\IAMLab\AuditLogs\IAM-Mover-Audit.csv'
$Operator = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

function Write-IAMAudit {
    param(
        [string]$Action,
        [string]$Result,
        [string]$Before,
        [string]$After
    )

    [pscustomobject]@{
        Timestamp = (Get-Date).ToString('o')
        RequestId = $RequestId
        Operator  = $Operator
        Username  = $Username
        Action    = $Action
        Result    = $Result
        Before    = $Before
        After     = $After
    } | Export-Csv -Path $AuditFile -Append -NoTypeInformation
}

# Validate the request
if ($RequestId -ne 'IAM-005') {
    throw 'Unexpected request ID. Expected IAM-005.'
}

$User = Get-ADUser -Identity $Username `
    -Properties Department, Title, MemberOf, Enabled

$OldGroupObject = Get-ADGroup -Identity $OldGroup
$NewGroupObject = Get-ADGroup -Identity $NewGroup

Get-ADOrganizationalUnit -Identity $TargetOU | Out-Null

if ($User.Name -ne $ExpectedName -or -not $User.Enabled) {
    throw 'Safety check failed: unexpected identity or disabled account.'
}

if (-not $User.DistinguishedName.EndsWith(
    ',' + $SourceOU, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Safety check failed: user is not in the expected Finance OU.'
}

if ($User.Department -ne 'Finance') {
    throw 'Safety check failed: unexpected starting department.'
}

if ($User.MemberOf -notcontains $OldGroupObject.DistinguishedName) {
    throw 'Safety check failed: expected Finance group membership is missing.'
}

if ($User.MemberOf -contains $NewGroupObject.DistinguishedName) {
    throw 'Safety check failed: user already belongs to the HR group.'
}

# Keep the AD object GUID stable throughout the move
$Identity = $User.ObjectGUID

Write-Host "Request: $RequestId"
Write-Host "Employee: $($User.Name)"
Write-Host "From: $($User.Department) / $($User.Title)"
Write-Host "To: $NewDepartment / $NewTitle"
Write-Host "Remove access: $OldGroup"
Write-Host "Grant access: $NewGroup"
Write-Host "Move to: $TargetOU"

$Action = 'Revoke Finance, grant HR, update attributes and move OU'

if ($PSCmdlet.ShouldProcess($Username, $Action)) {
    try {
        Write-IAMAudit 'Transfer started' 'Started' `
            "$($User.Department); $($User.Title); $SourceOU" `
            "$NewDepartment; $NewTitle; $TargetOU"

        # 1. Revoke old departmental access
        Remove-ADGroupMember -Identity $OldGroup `
            -Members $Identity -Confirm:$false -ErrorAction Stop

        Write-IAMAudit 'Revoke Finance access' 'Success' `
            $OldGroup 'Removed'

        # 2. Grant the approved new departmental access
        Add-ADGroupMember -Identity $NewGroup `
            -Members $Identity -ErrorAction Stop

        Write-IAMAudit 'Grant HR access' 'Success' `
            'Not a member' $NewGroup

        # 3. Update employee attributes
        Set-ADUser -Identity $Identity `
            -Department $NewDepartment `
            -Title $NewTitle -ErrorAction Stop

        Write-IAMAudit 'Update attributes' 'Success' `
            "$($User.Department); $($User.Title)" `
            "$NewDepartment; $NewTitle"

        # 4. Move existing identity, keeping its SID
        Move-ADObject -Identity $Identity `
            -TargetPath $TargetOU -ErrorAction Stop

        Write-IAMAudit 'Move OU' 'Success' `
            $SourceOU $TargetOU

        # 5. Verify final state
        $Updated = Get-ADUser -Identity $Identity `
            -Properties Department, Title, MemberOf, Enabled

        $Verified = (
            $Updated.Enabled -and
            $Updated.Department -eq $NewDepartment -and
            $Updated.Title -eq $NewTitle -and
            $Updated.MemberOf -contains $NewGroupObject.DistinguishedName -and
            $Updated.MemberOf -notcontains $OldGroupObject.DistinguishedName -and
            $Updated.DistinguishedName.EndsWith(
                ',' + $TargetOU,
                [System.StringComparison]::OrdinalIgnoreCase)
        )

        if (-not $Verified) {
            throw 'Post-transfer validation failed.'
        }

        Write-IAMAudit 'Final verification' 'Success' `
            'Finance role' 'HR role verified'

        Write-Host 'Employee transfer completed and verified.' `
            -ForegroundColor Green
    }
    catch {
        Write-IAMAudit 'Transfer failed' 'Failed' `
            'Inspect current AD state' $_.Exception.Message

        throw
    }
}
