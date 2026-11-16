
# Lab 17 - CSV-Driven IAM Leaver
# Domain: corp.sunrock.test
# Training environment only

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$AuditFile = 'C:\IAMLab\AuditLogs\IAM-CSV-Leaver-Audit.csv'
$DisabledOU = 'OU=DisabledUsers,DC=corp,DC=sunrock,DC=test'
$Operator = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

$RequestId = 'UNKNOWN'
$Username = 'UNKNOWN'

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
    } | Export-Csv -LiteralPath $AuditFile -Append -NoTypeInformation
}

try {
    # 1. Read exactly one CSV request
    $FullPath = (Resolve-Path -LiteralPath $Path).Path
    $Rows = @(Import-Csv -LiteralPath $FullPath)

    if ($Rows.Count -ne 1) {
        throw 'Expected exactly one Leaver request.'
    }

    $Request = $Rows[0]

    $RequiredFields = @(
        'RequestId',
        'Action',
        'Username',
        'ExpectedDepartment',
        'ApprovalStatus'
    )

    foreach ($Field in $RequiredFields) {
        if ($Request.PSObject.Properties.Name -notcontains $Field -or
            [string]::IsNullOrWhiteSpace($Request.$Field)) {
            throw "Missing required field: $Field"
        }
    }

    $RequestId = $Request.RequestId
    $Username = $Request.Username

    # 2. Validate request format
    if ($RequestId -notmatch '^IAM-[0-9]{3,}$') {
        throw 'Invalid IAM request ID.'
    }

    if ($Request.Action -ne 'Leaver') {
        throw 'Only Leaver requests are supported.'
    }

    if ($Request.ApprovalStatus -ne 'Approved') {
        throw 'Request is not marked Approved.'
    }

    if ($Username -cnotmatch '^[a-z]+\.[a-z]+$') {
        throw 'Invalid username format.'
    }

    # 3. Restrict operations to supported lab departments
    $Departments = @{
        Finance = @{
            OU = 'OU=Finance,OU=Employees,DC=corp,DC=sunrock,DC=test'
            Group = 'GG_Finance_Users'
        }
        HR = @{
            OU = 'OU=HR,OU=Employees,DC=corp,DC=sunrock,DC=test'
            Group = 'GG_HR_Users'
        }
    }

    $Department = $Request.ExpectedDepartment

    if (-not $Departments.ContainsKey($Department)) {
        throw 'Unsupported department.'
    }

    $ExpectedOU = $Departments[$Department].OU
    $GroupName = $Departments[$Department].Group

    # 4. Validate current Active Directory state
    $User = Get-ADUser -Identity $Username `
        -Properties Department, Enabled, MemberOf

    $Group = Get-ADGroup -Identity $GroupName

    Get-ADOrganizationalUnit -Identity $DisabledOU |
        Out-Null

    if (-not $User.Enabled) {
        throw 'Account is already disabled.'
    }

    if ($User.Department -ne $Department) {
        throw 'AD department does not match the request.'
    }

    if (-not $User.DistinguishedName.EndsWith(
        ',' + $ExpectedOU,
        [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Account is not in the expected OU.'
    }

    if ($User.MemberOf -notcontains $Group.DistinguishedName) {
        throw 'Expected department group membership is missing.'
    }

    # Preserve the same AD identity throughout the operation
    $Identity = $User.ObjectGUID

    Write-Host ''
    Write-Host '========== IAM LEAVER REQUEST =========='
    Write-Host "Request ID:    $RequestId"
    Write-Host "Employee:      $($User.Name)"
    Write-Host "Username:      $Username"
    Write-Host "Department:    $Department"
    Write-Host "Account:       Enabled"
    Write-Host "Remove group:  $GroupName"
    Write-Host "Destination:   $DisabledOU"
    Write-Host 'Validation:    PASSED'
    Write-Host '========================================'

    # 5. Require confirmation before actual offboarding
    $Action = 'Disable account, revoke access, and move to DisabledUsers'

    if ($PSCmdlet.ShouldProcess($Username, $Action)) {

        # Disable first to prevent new domain authentication
        Disable-ADAccount -Identity $Identity -ErrorAction Stop

        Write-IAMAudit 'Disable account' 'Success' `
            'AD account disabled'

        # Remove approved departmental group
        Remove-ADGroupMember -Identity $GroupName `
            -Members $Identity -Confirm:$false -ErrorAction Stop

        Write-IAMAudit 'Revoke department access' 'Success' `
            $GroupName

        # Move account without changing its SID
        Move-ADObject -Identity $Identity `
            -TargetPath $DisabledOU -ErrorAction Stop

        Write-IAMAudit 'Move account' 'Success' `
            $DisabledOU

        # 6. Verify resulting AD state
        $Updated = Get-ADUser -Identity $Identity `
            -Properties Enabled, MemberOf

        $Verified = (
            -not $Updated.Enabled -and
            $Updated.MemberOf -notcontains $Group.DistinguishedName -and
            $Updated.DistinguishedName.EndsWith(
                ',' + $DisabledOU,
                [System.StringComparison]::OrdinalIgnoreCase)
        )

        if (-not $Verified) {
            throw 'Post-offboarding verification failed.'
        }

        Write-IAMAudit 'Final verification' 'Success' `
            'Account disabled, group removed, OU verified'

        Write-Host ''
        Write-Host 'Employee offboarding completed and verified.' `
            -ForegroundColor Green
    }
}
catch {
    $Failure = $_.Exception.Message

    try {
        Write-IAMAudit 'Leaver workflow' 'Failed' $Failure
    }
    catch {
        Write-Warning "Audit logging failed: $($_.Exception.Message)"
    }

    throw
}
