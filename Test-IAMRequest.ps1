
# IAM CSV Request Validator - Lab 15
# Read-only validation for Joiner requests

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

try {
    $Requests = @(Import-Csv -LiteralPath $Path)

    if ($Requests.Count -ne 1) {
        throw 'This version requires exactly one request per CSV.'
    }

    $Request = $Requests[0]

    $RequiredFields = @(
        'RequestId', 'Action', 'FirstName', 'LastName',
        'Username', 'Department', 'JobTitle', 'ApprovalStatus'
    )

    foreach ($Field in $RequiredFields) {
        if ($Request.PSObject.Properties.Name -notcontains $Field -or
            [string]::IsNullOrWhiteSpace($Request.$Field)) {
            throw "Missing required field: $Field"
        }
    }

    if ($Request.RequestId -notmatch '^IAM-[0-9]{3,}$') {
        throw 'Invalid request ID format.'
    }

    if ($Request.Action -ne 'Joiner') {
        throw 'This validator currently supports Joiner only.'
    }

    if ($Request.ApprovalStatus -ne 'Approved') {
        throw 'Request is not marked Approved.'
    }

    if ($Request.Username -cnotmatch '^[a-z]+\.[a-z]+$') {
        throw 'Username must follow firstname.lastname.'
    }

    $ExpectedUsername = (
        $Request.FirstName + '.' + $Request.LastName
    ).ToLowerInvariant()

    if ($Request.Username -cne $ExpectedUsername) {
        throw 'Username does not match employee name.'
    }

    # Approved department-to-role mapping
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

    if (-not $Departments.ContainsKey($Request.Department)) {
        throw 'Department is not on the approved list.'
    }

    $Target = $Departments[$Request.Department]
    $Username = $Request.Username
    $UPN = "$Username@corp.sunrock.test"

    $Existing = Get-ADUser -Filter {
        SamAccountName -eq $Username -or UserPrincipalName -eq $UPN
    }

    if ($Existing) {
        throw "Account already exists: $Username"
    }

    Get-ADOrganizationalUnit -Identity $Target.OU |
        Out-Null

    $Group = Get-ADGroup -Identity $Target.Group

    if ($Group.GroupCategory -ne 'Security' -or
        $Group.GroupScope -ne 'Global') {
        throw 'Target group must be a Global Security group.'
    }

    [pscustomobject]@{
        RequestId = $Request.RequestId
        Employee = "$($Request.FirstName) $($Request.LastName)"
        Username = $Username
        Action = $Request.Action
        Department = $Request.Department
        TargetOU = $Target.OU
        TargetGroup = $Target.Group
        Validation = 'PASSED'
        ADChanges = 'None'
    }
}
catch {
    Write-Error "IAM request validation FAILED: $($_.Exception.Message)"
}
