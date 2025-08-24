# Modules/Utils.psm1
<# Misc helpers #>

function Test-AdminRights {
    [CmdletBinding()]
    param()
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "Ce script doit être exécuté en tant qu'administrateur."
        exit 1
    }
}

function Get-DomainDN {
    [CmdletBinding()]
    param()
    try {
        return (Get-ADDomain).DistinguishedName
    } catch {
        throw "Impossible de récupérer le domaine AD : $($_.Exception.Message)"
    }
}

function Confirm-ToolkitAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message
    )
    $answer = Read-Host "$Message (o/n)"
    return ($answer -match '^[oOyY]')
}

function Resolve-AccountIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InputIdentity
    )
    if ($InputIdentity -match '\\' -or $InputIdentity -match '@') { return $InputIdentity }
    return "$env:USERDOMAIN\$InputIdentity"
}

function Read-MenuChoice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int[]]$ValidChoices,
        [string]$Prompt = "Votre choix"
    )
    do {
        $c = Read-Host $Prompt
    } while (-not ($ValidChoices -contains [int]$c))
    return [int]$c
}

Export-ModuleMember -Function Test-AdminRights, Get-DomainDN, Confirm-ToolkitAction, Resolve-AccountIdentity, Read-MenuChoice
