# Modules/ADDeployment.psm1
<# Basic automated AD DS deployment helpers #>

function Configure-Network {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InterfaceAlias,
        [Parameter(Mandatory)][string]$IPAddress,
        [Parameter(Mandatory)][int]$PrefixLength,
        [Parameter(Mandatory)][string]$Gateway,
        [Parameter(Mandatory)][string[]]$DNSServers
    )
    Write-Host "[Réseau] Configuration sur interface $InterfaceAlias..." -ForegroundColor Cyan
    New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway -ErrorAction Stop
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServers -ErrorAction Stop
}

function Rename-ToolkitComputer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$NewName,
        [switch]$Restart = $true
    )
    if ((hostname) -ieq $NewName) {
        Write-Host "[Réseau] Le nom d'ordinateur est déjà $NewName."
        return
    }
    Rename-Computer -NewName $NewName -Force -ErrorAction Stop
    if ($Restart) {
        Write-Host "[Réseau] Redémarrage..." -ForegroundColor Yellow
        Restart-Computer -Force
    }
}

function Install-ToolkitADDS {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DomainName,
        [Parameter(Mandatory)][string]$SafeModeAdministratorPassword
    )
    Write-Host "[ADDS] Installation rôles..." -ForegroundColor Cyan
    Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools -ErrorAction Stop
    Write-Host "[ADDS] Promotion en forêt $DomainName ..." -ForegroundColor Cyan
    Install-ADDSForest -DomainName $DomainName `
        -SafeModeAdministratorPassword (ConvertTo-SecureString $SafeModeAdministratorPassword -AsPlainText -Force) `
        -Force:$true
}

function Wait-ForAD {
    [CmdletBinding()]
    param(
        [int]$TimeoutSeconds = 600,
        [int]$IntervalSeconds = 10
    )
    Write-Host "[AD] Attente disponibilité AD ($TimeoutSeconds s max)..." -ForegroundColor Yellow
    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        try {
            Get-ADDomain | Out-Null
            Write-Host "[AD] Disponible." -ForegroundColor Green
            return $true
        } catch {
            Start-Sleep -Seconds $IntervalSeconds
            $elapsed += $IntervalSeconds
        }
    }
    Write-Error "[AD] Timeout après $TimeoutSeconds s."
    return $false
}

Export-ModuleMember -Function Configure-Network, Rename-ToolkitComputer, Install-ToolkitADDS, Wait-ForAD
