
# Lab 18 - Consolidated IAM Audit Report
# Read-only: collects existing CSV audit records

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$LogFolder = 'C:\IAMLab\AuditLogs'
$ReportFolder = 'C:\IAMLab\Reports'

$LogFiles = @(
    'IAM-Joiner-Audit.csv'
    'IAM-Mover-Audit.csv'
    'IAM-Leaver-Audit.csv'
    'IAM-CSV-Joiner-Audit.csv'
    'IAM-CSV-Mover-Audit.csv'
    'IAM-CSV-Leaver-Audit.csv'
)

$Events = foreach ($File in $LogFiles) {
    $FullPath = Join-Path $LogFolder $File

    if (Test-Path -LiteralPath $FullPath) {
        Import-Csv -LiteralPath $FullPath | ForEach-Object {
            [pscustomobject]@{
                Timestamp = $_.Timestamp
                RequestId = $_.RequestId
                Operator  = $_.Operator
                Username  = $_.Username
                Action    = $_.Action
                Result    = $_.Result
                Details   = if ($_.Details) {
                    $_.Details
                } else {
                    "$($_.Before) -> $($_.After)"
                }
                SourceLog = $File
            }
        }
    }
    else {
        Write-Warning "Audit file not found: $File"
    }
}

if (-not $Events) {
    throw 'No IAM audit records were found.'
}

# Sort chronologically and create the reporting directory
$Events = @($Events | Sort-Object Timestamp)

New-Item -Path $ReportFolder `
    -ItemType Directory -Force | Out-Null

$ReportPath = Join-Path $ReportFolder 'IAM-Consolidated-Audit.csv'

$Events | Export-Csv -LiteralPath $ReportPath `
    -NoTypeInformation -Encoding UTF8

Write-Host "Consolidated audit report: $ReportPath" `
    -ForegroundColor Green

Write-Host "Total audit events: $($Events.Count)"

$Events |
    Group-Object Result |
    Select-Object Name, Count |
    Format-Table -AutoSize

$Events |
    Select-Object Timestamp, RequestId, Username, Action, Result |
    Format-Table -AutoSize
