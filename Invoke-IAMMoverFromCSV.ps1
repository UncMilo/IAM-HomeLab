
# Lab 16 - CSV-Driven IAM Mover
# Domain: corp.sunrock.test
# Training environment only

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$AuditFile = 'C:\IAMLab\AuditLogs\IAM-CSV-Mover-Audit.csv'
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
    # 1. Read exactly one request
    $FullPath = (Resolve-Path -LiteralPath $Path).Path
    $Rows = @(Import-Csv -LiteralPath $FullPath)

    if ($Rows.Count -ne 1) {
        throw 'Expected exactly one Mover request.'
    }

    $Request = $Rows[0]
    $Required = @(
        'RequestId', 'Action', 'Username',
        'SourceDepartment', 'TargetDepartment',
        'NewJobTitle', 'ApprovalStatus'
    )

    foreach ($Field in $Required) {
        if ($Request.PSObject.Properties.Name -notcontains $Field -or
            [string]::IsNullOrWhiteSpace($Request.$Field)) {
            throw "Missing required field: $Field"
        }
    }

    $RequestId = $Request.RequestId
    $Username = $Request.Username

    if ($RequestId -notmatch '^IAM-[0-9]{3,}$') {
        throw 'Invalid request ID.'
    }

    if ($Request.Action -ne 'Mover') {
        throw 'Only Mover requests are supported.'
    }

    if ($Request.ApprovalStatus -ne 'Approved') {
        throw 'Request is not marked Approved.'
    }

    if ($Username -cnotmatch '^[a-z]+\.[a-z]+$') {
        throw 'Invalid username format.'
    }

    # 2. Allow only approved lab departments
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

    $Source = $Request.SourceDepartment
    $Target = $Request.TargetDepartment

    if (-not $Departments.ContainsKey($Source) -or
        -not $Departments.ContainsKey($Target)) {
        throw 'Unsupported department.'
    }

    if ($Source -eq $Target) {
        throw 'Source and target departments must differ.'
    }

    $OldOU = $Departments[$Source].OU
    $NewOU = $Departments[$Target].OU
    $OldGroup = $Departments[$Source].Group
    $NewGroup = $Departments[$Target].Group

    # 3. Validate Active Directory state
    $User = Get-ADUser -Identity $Username `
        -Properties Department, Title, Enabled, MemberOf

    $OldGroupObject = Get-ADGroup -Identity $OldGroup
    $NewGroupObject = Get-ADGroup -Identity $NewGroup
    Get-ADOrganizationalUnit -Identity $NewOU | Out-Null

    if (-not $User.Enabled) {
        throw 'Account is disabled.'
    }

    if ($User.Department -ne $Source) {
        throw 'Current department does not match the request.'
    }

    if (-not $User.DistinguishedName.EndsWith(
        ',' + $OldOU,
        [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Account is not in the expected source OU.'
    }

    foreach ($Group in @($OldGroupObject, $NewGroupObject)) {
        if ($Group.GroupCategory -ne 'Security' -or
            $Group.GroupScope -ne 'Global') {
            throw 'Unexpected security group type or scope.'
        }
    }

    if ($User.MemberOf -notcontains $OldGroupObject.DistinguishedName) {
        throw 'Expected source group membership is missing.'
    }

    if ($User.MemberOf -contains $NewGroupObject.DistinguishedName) {
        throw 'Target group membership already exists.'
    }

    # Keep the same AD identity through the transfer
    $Identity = $User.ObjectGUID

    Write-Host ''
    Write-Host '========== IAM MOVER REQUEST =========='
    Write-Host "Request ID:   $RequestId"
    Write-Host "Employee:     $($User.Name)"
    Write-Host "Username:     $Username"
    Write-Host "From:         $Source / $($User.Title)"
    Write-Host "To:           $Target / $($Request.NewJobTitle)"
    Write-Host "Remove group: $OldGroup"
    Write-Host "Add group:    $NewGroup"
    Write-Host "Destination:  $NewOU"
    Write-Host 'Validation:   PASSED'
    Write-Host '======================================='

    $Action = "Transfer from $Source to $Target"

    if ($PSCmdlet.ShouldProcess($Username, $Action)) {
        # 4. Revoke old access first
        Remove-ADGroupMember -Identity $OldGroup `
            -Members $Identity -Confirm:$false -ErrorAction Stop

        Write-IAMAudit 'Revoke old access' 'Success' $OldGroup

        # 5. Assign new access
        Add-ADGroupMember -Identity $NewGroup `
            -Members $Identity -ErrorAction Stop

        Write-IAMAudit 'Grant new access' 'Success' $NewGroup

        # 6. Update attributes
        Set-ADUser -Identity $Identity `
            -Department $Target `
            -Title $Request.NewJobTitle -ErrorAction Stop

        Write-IAMAudit 'Update attributes' 'Success' `
            "$Source -> $Target; $($Request.NewJobTitle)"

        # 7. Move the existing account
        Move-ADObject -Identity $Identity `
            -TargetPath $NewOU -ErrorAction Stop

        Write-IAMAudit 'Move OU' 'Success' $NewOU

        # 8. Independently re-read the account
        $Updated = Get-ADUser -Identity $Identity `
            -Properties Department, Title, Enabled, MemberOf

        $Verified = (
            $Updated.Enabled -and
            $Updated.Department -eq $Target -and
            $Updated.Title -eq $Request.NewJobTitle -and
            $Updated.MemberOf -contains $NewGroupObject.DistinguishedName -and
            $Updated.MemberOf -notcontains $OldGroupObject.DistinguishedName -and
            $Updated.DistinguishedName.EndsWith(
                ',' + $NewOU,
                [System.StringComparison]::OrdinalIgnoreCase)
        )

        if (-not $Verified) {
            throw 'Post-transfer verification failed.'
        }

        Write-IAMAudit 'Final verification' 'Success' `
            'Attributes, OU and group membership verified'

        Write-Host 'Employee transfer completed and verified.' `
            -ForegroundColor Green
    }
}
catch {
    $Failure = $_.Exception.Message

    try {
        Write-IAMAudit 'Mover workflow' 'Failed' $Failure
    }
    catch {
        Write-Warning "Audit logging failed: $($_.Exception.Message)"
    }

    Write-Error "IAM Mover FAILED: $Failure"
}
