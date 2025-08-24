# Modules/Report.psm1
<# Consolidated report across AD + Supervision #>

Import-Module ActiveDirectory -ErrorAction SilentlyContinue

function New-ConsolidatedReport {
    [CmdletBinding()]
    param(
        [string]$ReportFolder = "$env:USERPROFILE\Desktop\Admin_Toolkit\Rapports"
    )
    if (!(Test-Path $ReportFolder)) { New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $html = Join-Path $ReportFolder \"Consolidated_$stamp.html\"

    # Collect AD
    $users = Get-ADUser -Filter * -Properties SamAccountName,Enabled | Select Name,SamAccountName,Enabled
    $groups = Get-ADGroup -Filter * | Select Name,GroupScope,GroupCategory
    $ous = Get-ADOrganizationalUnit -Filter * | Select Name,DistinguishedName

    # Build HTML
    $htmlContent = @()
    $htmlContent += '<html><head><title>Rapport Consolidé AdminToolkit</title></head><body>'
    $htmlContent += '<h1>Rapport Consolidé AdminToolkit</h1>'
    $htmlContent += '<h2>OU</h2>'
    $htmlContent += ($ous | ConvertTo-Html -Fragment)
    $htmlContent += '<h2>Utilisateurs</h2>'
    $htmlContent += ($users | ConvertTo-Html -Fragment)
    $htmlContent += '<h2>Groupes</h2>'
    $htmlContent += ($groups | ConvertTo-Html -Fragment)
    $htmlContent += '</body></html>'

    $htmlContent -join \"`r`n\" | Out-File -Encoding UTF8 $html
    return $html
}

Export-ModuleMember -Function New-ConsolidatedReport
