# Modules/Logging.psm1
<# Logging & Transcript helpers #>

function Start-ToolkitLog {
    [CmdletBinding()]
    param(
        [string]$RootPath = "$env:USERPROFILE\Desktop\Admin_Toolkit",
        [string]$LogsSub  = "logs",
        [switch]$NoTranscript
    )
    $logDir = Join-Path $RootPath $LogsSub
    if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $Global:ToolkitLogDir = $logDir
    $Global:ToolkitLogFile = Join-Path $logDir ("Transcript-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    if (-not $NoTranscript) {
        try {
            Start-Transcript -Path $Global:ToolkitLogFile -Append -ErrorAction Stop | Out-Null
            Write-Host "[Journalisation] Transcript démarré : $Global:ToolkitLogFile" -ForegroundColor Green
        } catch {
            Write-Warning "Impossible de démarrer le transcript : $($_.Exception.Message)"
        }
    }
}

function Stop-ToolkitLog {
    [CmdletBinding()]
    param()
    try {
        Stop-Transcript | Out-Null
        Write-Host "[Journalisation] Transcript arrêté." -ForegroundColor Yellow
    } catch {
        # ignore si pas démarré
    }
}

function Write-ToolkitLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','ACTION')][string]$Level='INFO'
    )
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$ts `t[$Level] `t$Message"
    if ($Global:ToolkitLogDir) {
        $logtxt = Join-Path $Global:ToolkitLogDir "AdminToolkit-Actions.log"
        Add-Content -Path $logtxt -Value $line
    }
    Write-Host $line
}

Export-ModuleMember -Function Start-ToolkitLog, Stop-ToolkitLog, Write-ToolkitLog
