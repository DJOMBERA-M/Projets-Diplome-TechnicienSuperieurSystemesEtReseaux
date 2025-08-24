# Modules/GPOManagement.psm1
<# GPO helpers #>
Import-Module GroupPolicy -ErrorAction SilentlyContinue

# Liste prédéfinie (comme script utilisateur)
$Global:ToolkitPredefGPOs = @(
    @{Name=\"FondEcran_Jaune\"; Desc=\"Fond d'écran jaune\"; Key=\"HKCU\Control Panel\Desktop\"; ValueName=\"Wallpaper\"; Type=\"String\"; Value=\"C:\Windows\Web\Wallpaper\Windows\img0.jpg\"},
    @{Name=\"AutoLogoff_15min\"; Desc=\"Déconnexion après 15min\"; Key=\"HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop\"; ValueName=\"ScreenSaveTimeOut\"; Type=\"String\"; Value=\"900\"},
    @{Name=\"Blocage_PanneauConfig\"; Desc=\"Blocage Panneau de config\"; Key=\"HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\"; ValueName=\"NoControlPanel\"; Type=\"DWord\"; Value=1},
    @{Name=\"PasswordPolicy_8char\"; Desc=\"Mot de passe min 8\"; Key=\"HKLM\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters\"; ValueName=\"MinimumPasswordLength\"; Type=\"DWord\"; Value=8},
    @{Name=\"Blocage_TaskManager\"; Desc=\"Blocage Gestionnaire tâches\"; Key=\"HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System\"; ValueName=\"DisableTaskMgr\"; Type=\"DWord\"; Value=1},
    @{Name=\"Blocage_USB\"; Desc=\"Blocage périphériques USB\"; Key=\"HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR\"; ValueName=\"Start\"; Type=\"DWord\"; Value=4},
    @{Name=\"Message_Logon\"; Desc=\"Message avant connexion\"; Key=\"HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System\"; ValueName=\"LegalNoticeText\"; Type=\"String\"; Value=\"Bienvenue sur le réseau sécurisé\"},
    @{Name=\"Blocage_CMD\"; Desc=\"Blocage CMD\"; Key=\"HKCU\Software\Policies\Microsoft\Windows\System\"; ValueName=\"DisableCMD\"; Type=\"DWord\"; Value=1}
)

function Ensure-GPO {
    param([string]$Name)
    $gpo = Get-GPO -Name $Name -ErrorAction SilentlyContinue
    if (-not $gpo) {
        $gpo = New-GPO -Name $Name
        Write-Host \"[GPO] '$Name' créée.\" -ForegroundColor Green
    } else {
        Write-Host \"[GPO] '$Name' existe déjà.\" -ForegroundColor Yellow
    }
    return $gpo
}

function Set-GPORegistryValueSafe {
    param(
        [string]$Name,
        [string]$Key,
        [string]$ValueName,
        [ValidateSet('String','DWord','QWord','Binary','ExpandString','MultiString')][string]$Type,
        [Parameter(Mandatory)]$Value
    )
    try {
        Set-GPRegistryValue -Name $Name -Key $Key -ValueName $ValueName -Type $Type -Value $Value -ErrorAction Stop
    } catch {
        Write-Host \"[GPO] Erreur paramétrage '$Name' : $($_.Exception.Message)\" -ForegroundColor Red
    }
}

function Link-GPOToOU {
    param([string]$GPOName,[string]$OUName)
    $domainDN = (Get-ADDomain).DistinguishedName
    $target = \"OU=$OUName,$domainDN\"
    New-GPLink -Name $GPOName -Target $target -LinkEnabled Yes -ErrorAction Stop
    Write-Host \"[GPO] '$GPOName' liée à l'OU $OUName.\" -ForegroundColor Green
}

function Link-GPOToDomain {
    param([string]$GPOName)
    $domainDN = (Get-ADDomain).DistinguishedName
    New-GPLink -Name $GPOName -Target $domainDN -LinkEnabled Yes -ErrorAction Stop
    Write-Host \"[GPO] '$GPOName' liée au domaine.\" -ForegroundColor Green
}

function New-CustomGPO {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Domaine','OU','Aucun')][string]$Scope,
        [string]$OUName
    )
    $gpo = Ensure-GPO -Name $Name
    switch ($Scope) {
        'Domaine' { Link-GPOToDomain -GPOName $Name }
        'OU'      { if ($OUName) { Link-GPOToOU -GPOName $Name -OUName $OUName } else { Write-Host \"Nom OU requis.\" -ForegroundColor Red } }
        'Aucun'   { Write-Host \"GPO créée sans lien.\" -ForegroundColor Yellow }
    }
    return $gpo
}

function Deploy-PredefinedGPOs {
    [CmdletBinding()]
    param(
        [ValidateSet('Domaine','OU')][string]$Scope='OU',
        [string]$OUName
    )
    foreach ($g in $Global:ToolkitPredefGPOs) {
        $gpo = Ensure-GPO -Name $g.Name
        Set-GPORegistryValueSafe -Name $g.Name -Key $g.Key -ValueName $g.ValueName -Type $g.Type -Value $g.Value
        if ($Scope -eq 'Domaine') {
            Link-GPOToDomain -GPOName $g.Name
        } elseif ($Scope -eq 'OU') {
            Link-GPOToOU -GPOName $g.Name -OUName $OUName
        }
    }
}

Export-ModuleMember -Function Ensure-GPO, Set-GPORegistryValueSafe, Link-GPOToOU, Link-GPOToDomain, New-CustomGPO, Deploy-PredefinedGPOs
