
# ============================================================
# IAM Lab 15 - CSV-Driven Joiner Automation
# Domain: corp.sunrock.test
# Uses: Test-IAMRequest.ps1
# ============================================================

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'

Import-Module ActiveDirectory

$AuditFile = 'C:\IAMLab\AuditLogs\IAM-CSV-Joiner-Audit.csv'
$Operator = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$Validator = Join-Path $PSScriptRoot 'Test-IAMRequest.ps1'

$RequestId = 'UNKNOWN'
$Username = 'UNKNOWN'
$AccountCreated = $false
$Completed = $false

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
    # 1. Locate and read the request
    $FullPath = (Resolve-Path -LiteralPath $Path).Path
    $Rows = @(Import-Csv -LiteralPath $FullPath)

    if ($Rows.Count -ne 1) {
        throw 'Expected exactly one employee request.'
    }

    $Request = $Rows[0]
    $RequestId = $Request.RequestId
    $Username = $Request.Username

    # 2. Run our existing read-only validator
    $Validated = & $Validator -Path $FullPath -ErrorAction Stop

    if (-not $Validated -or $Validated.Validation -ne 'PASSED') {
        throw 'Request validation did not pass.'
    }

    # 3. Use the approved mapping from the validator
    $FullName = "$($Request.FirstName) $($Request.LastName)"
    $UPN = "$Username@corp.sunrock.test"
    $TargetOU = $Validated.TargetOU
    $TargetGroup = $Validated.TargetGroup

    Write-Host ''
    Write-Host '========== IAM JOINER REQUEST =========='
    Write-Host "Request ID:  $RequestId"
    Write-Host "Employee:    $FullName"
    Write-Host "Username:    $Username"
    Write-Host "Department:  $($Request.Department)"
    Write-Host "Job title:   $($Request.JobTitle)"
    Write-Host "Target OU:   $TargetOU"
    Write-Host "Group:       $TargetGroup"
    Write-Host 'Validation:  PASSED'
    Write-Host '========================================'
    Write-Host ''

    $Description = "Create account and grant $TargetGroup access"

    if ($PSCmdlet.ShouldProcess($Username, $Description)) {

        # 4. Securely request the initial password
        $Password = Read-Host 'Enter temporary password' -AsSecureString

        # 5. Create the account DISABLED initially
        New-ADUser `
            -Name $FullName `
            -GivenName $Request.FirstName `
            -Surname $Request.LastName `
            -SamAccountName $Username `
            -UserPrincipalName $UPN `
            -Department $Request.Department `
            -Title $Request.JobTitle `
            -Path $TargetOU `
            -AccountPassword $Password `
            -ChangePasswordAtLogon $true `
            -Enabled $false `
            -ErrorAction Stop

        $AccountCreated = $true

        Write-IAMAudit 'Create account' 'Success' `
            'Account created in disabled state'

        # 6. Grant role-based security group membership
        Add-ADGroupMember `
            -Identity $TargetGroup `
            -Members $Username `
            -ErrorAction Stop

        Write-IAMAudit 'Assign access' 'Success' $TargetGroup

        # 7. Enable account only after assigning access
        Enable-ADAccount -Identity $Username -ErrorAction Stop

        Write-IAMAudit 'Enable account' 'Success' `
            'Account enabled after group assignment'

        # 8. Verify the final AD state
        $User = Get-ADUser -Identity $Username `
            -Properties Department, Title, MemberOf, Enabled

        $Group = Get-ADGroup -Identity $TargetGroup

        $Verified = (
            $User.Enabled -and
            $User.Department -eq $Request.Department -and
            $User.Title -eq $Request.JobTitle -and
            $User.MemberOf -contains $Group.DistinguishedName -and
            $User.DistinguishedName.EndsWith(
                ',' + $TargetOU,
                [System.StringComparison]::OrdinalIgnoreCase)
        )

        if (-not $Verified) {
            throw 'Post-provisioning verification failed.'
        }

        Write-IAMAudit 'Final verification' 'Success' `
            'Enabled account, OU, attributes and group verified'

        $Completed = $true

        Write-Host ''
        Write-Host 'Employee onboarding completed and verified.' `
            -ForegroundColor Green
    }
}
catch {
    $Failure = $_.Exception.Message

    # If provisioning was partially completed, disable the
    # account to prevent unintended access.
    if ($AccountCreated -and -not $Completed) {
        try {
            Disable-ADAccount -Identity $Username -ErrorAction Stop
            Write-IAMAudit 'Safety disable' 'Success' `
                'Partial onboarding: account disabled for review'
        }
        catch {
            Write-Warning "Could not disable partial account: $($_.Exception.Message)"
        }
    }

    try {
        Write-IAMAudit 'Joiner workflow' 'Failed' $Failure
    }
    catch {
        Write-Warning "Audit logging failed: $($_.Exception.Message)"
    }

    throw
}
