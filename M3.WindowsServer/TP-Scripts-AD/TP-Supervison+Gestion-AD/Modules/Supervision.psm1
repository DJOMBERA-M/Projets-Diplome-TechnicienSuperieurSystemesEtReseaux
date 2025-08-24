# Modules/Supervision.psm1
<# Supervision (événements, processus, services) #>

# Liste services critiques par défaut (inclut ADDS & DNS)
$Global:ToolkitCriticalServices = @(
    'Spooler',
    'wuauserv',
    'lanmanserver',
    'Dnscache',
    'Dhcp',
    'NTDS',        # Active Directory Domain Services
    'DNS'
)

function Get-CriticalEvents {
    [CmdletBinding()]
    param(
        [int]$MaxEvents = 20,
        [string[]]$Logs = @('System','Application')
    )
    Get-WinEvent -FilterHashtable @{LogName=$Logs; Level=1,2} -MaxEvents $MaxEvents |
        Select-Object TimeCreated,LogName,Id,LevelDisplayName,ProviderName,Message
}

function Export-CriticalEventsReport {
    [CmdletBinding()]
    param(
        [string]$ReportFolder = "$env:USERPROFILE\Desktop\Admin_Toolkit\Rapports",
        [int]$MaxEvents = 20
    )
    if (!(Test-Path $ReportFolder)) { New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null }
    $events = Get-CriticalEvents -MaxEvents $MaxEvents
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $csv = Join-Path $ReportFolder \"Events_$stamp.csv\"
    $html = Join-Path $ReportFolder \"Events_$stamp.html\"
    $events | Export-Csv -NoTypeInformation -Encoding UTF8 $csv
    $events | ConvertTo-Html -Title \"Événements Critiques\" | Out-File -Encoding UTF8 $html
    return [pscustomobject]@{Csv=$csv;Html=$html;Count=$events.Count}
}

function Get-TopProcesses {
    [CmdletBinding()]
    param([int]$Top=15)
    Get-Process | Sort-Object CPU -Descending | Select-Object -First $Top `
        Id,ProcessName,Path,StartTime,CPU,PM,WS,VM,Handles,Threads
}

function Export-TopProcessesReport {
    [CmdletBinding()]
    param(
        [string]$ReportFolder = "$env:USERPROFILE\Desktop\Admin_Toolkit\Rapports",
        [int]$Top=15
    )
    if (!(Test-Path $ReportFolder)) { New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null }
    $procs = Get-TopProcesses -Top $Top
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $csv = Join-Path $ReportFolder \"Procs_$stamp.csv\"
    $html = Join-Path $ReportFolder \"Procs_$stamp.html\"
    $procs | Export-Csv -NoTypeInformation -Encoding UTF8 $csv
    $procs | ConvertTo-Html -Title \"Processus Gourmands\" | Out-File -Encoding UTF8 $html
    return [pscustomobject]@{Csv=$csv;Html=$html;Count=$procs.Count}
}

function Get-CriticalServicesStatus {
    [CmdletBinding()]
    param([string[]]$Services = $Global:ToolkitCriticalServices)
    Get-Service -Name $Services -ErrorAction SilentlyContinue |
        Select-Object Status,Name,DisplayName,ServiceType,StartType,MachineName
}

function Export-CriticalServicesReport {
    [CmdletBinding()]
    param(
        [string]$ReportFolder = "$env:USERPROFILE\Desktop\Admin_Toolkit\Rapports",
        [string[]]$Services = $Global:ToolkitCriticalServices
    )
    if (!(Test-Path $ReportFolder)) { New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null }
    $svcs = Get-CriticalServicesStatus -Services $Services
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $csv = Join-Path $ReportFolder \"Services_$stamp.csv\"
    $html = Join-Path $ReportFolder \"Services_$stamp.html\"
    $svcs | Export-Csv -NoTypeInformation -Encoding UTF8 $csv
    $svcs | ConvertTo-Html -Title \"Services Critiques\" | Out-File -Encoding UTF8 $html
    return [pscustomobject]@{Csv=$csv;Html=$html;Count=$svcs.Count}
}

Export-ModuleMember -Function Get-CriticalEvents, Export-CriticalEventsReport, Get-TopProcesses, Export-TopProcessesReport, Get-CriticalServicesStatus, Export-CriticalServicesReport
