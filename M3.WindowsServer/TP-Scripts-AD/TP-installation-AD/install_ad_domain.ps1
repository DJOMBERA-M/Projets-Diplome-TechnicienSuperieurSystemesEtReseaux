# install_ad_domain.ps1
# Auteur : Joyboy
# Description : Script complet d'installation d'un domaine Active Directory avec configuration interactive, création d'utilisateurs via CSV (avec OU, groupes), et saisie manuelle du mot de passe à la création. Journalisation, redémarrage automatique, et exécution après ouverture de session inclus.

# ------------------- CONFIGURATION DU SCRIPT -------------------
$logPath = "$env:USERPROFILE\Desktop\logs"
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath | Out-Null
}

$logFile = Join-Path $logPath "install_ad_domain_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $logFile

# Définir la stratégie d'exécution pour éviter les interruptions
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

# Pause utilitaire
function Pause-Step {
    Write-Host "\nAppuyez sur Entrée pour continuer..."
    Read-Host
}

# Fonction pour attendre la disponibilité de l'AD après promotion
function Wait-ForADReady {
    Write-Host "Attente que le service Active Directory soit prêt..."
    $attempts = 0
    while ($true) {
        try {
            $null = Get-ADDomain
            Write-Host "Active Directory est opérationnel."
            break
        } catch {
            Start-Sleep -Seconds 5
            $attempts++
            if ($attempts -ge 30) {
                Write-Error "Timeout : Active Directory toujours indisponible après 150 secondes."
                exit 1
            }
        }
    }
}

# ------------------- SAUVEGARDE CONFIGURATION INTERACTIVE -------------------
$configFile = "$env:ProgramData\ADDeployConfig.json"

# Vérifier si redémarrage déjà effectué
if (Test-Path $configFile) {
    $config = Get-Content $configFile | ConvertFrom-Json

    if ($config.IsPromoted -eq $true) {
        Wait-ForADReady
        $domainRoot = (Get-ADDomain).DistinguishedName

        # Désactivation du pare-feu pour tests
        Write-Host "\n--- Désactivation du pare-feu Windows ---"
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
        Write-Host "Pare-feu désactivé."
        Pause-Step

        # Création des OU
        Write-Host "\n--- Création des unités d'organisation ---"
        foreach ($ou in $config.OUList) {
            $ouPath = "OU=$ou,$domainRoot"
            if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue)) {
                New-ADOrganizationalUnit -Name $ou -Path $domainRoot
                Write-Host "OU $ou créée"
            } else {
                Write-Host "OU $ou existe déjà"
            }
        }
        Pause-Step

        # Création des groupes
        Write-Host "\n--- Création des groupes ---"
        foreach ($group in $config.GroupList) {
            $ouPath = "OU=$($group.OU),$domainRoot"
            if (-not (Get-ADGroup -Filter "Name -eq '$($group.Name)'" -ErrorAction SilentlyContinue)) {
                New-ADGroup -Name $group.Name -GroupScope Global -Path $ouPath
                Write-Host "Groupe $($group.Name) créé dans $ouPath"
            } else {
                Write-Host "Groupe $($group.Name) existe déjà"
            }
        }
        Pause-Step

        # Création des utilisateurs depuis CSV avec mot de passe saisi manuellement
        Write-Host "\n--- Création des utilisateurs depuis CSV (mot de passe saisi manuellement) ---"
        if (Test-Path $config.CSVPath) {
            # Nettoyage BOM éventuel
            (Get-Content -Path $config.CSVPath -Encoding UTF8) | Set-Content -Path $config.CSVPath -Encoding UTF8

            $csvUsers = Import-Csv -Path $config.CSVPath

            # Vérification robuste des en-têtes CSV
            $expectedHeaders = @('Name', 'OU', 'Group')
            $actualHeaders = ($csvUsers[0].PSObject.Properties | ForEach-Object { $_.Name.Trim() }) -as [string[]]

            if (-not ($expectedHeaders.Count -eq $actualHeaders.Count -and ($expectedHeaders | ForEach-Object { $actualHeaders -contains $_ }))) {
                Write-Error "Les en-têtes du fichier CSV ne correspondent pas.`nAttendues : $($expectedHeaders -join ', ')`nTrouvées   : $($actualHeaders -join ', ')"
                Stop-Transcript
                exit 1
            }

            foreach ($user in $csvUsers) {
                $ouPath = "OU=$($user.OU),$domainRoot"
                $groupName = $user.Group
                $userName = $user.Name

                if (-not (Get-ADUser -Filter "SamAccountName -eq '$userName'" -ErrorAction SilentlyContinue)) {
                    $password = Read-Host "Mot de passe temporaire pour l'utilisateur $userName" -AsSecureString
                    New-ADUser -Name $userName
                               -SamAccountName $userName
                               -UserPrincipalName "$userName@$($config.DomainName)"
                               -AccountPassword $password
                               -Enabled $true
                               -ChangePasswordAtLogon $true
                               -Path $ouPath
                    Write-Host "Utilisateur $userName créé dans $ouPath"
                }

                try {
                    Add-ADGroupMember -Identity $groupName -Members $userName
                    Write-Host "Ajout de $userName au groupe $groupName"
                } catch {
                    Write-Warning "Erreur ajout $userName au groupe $groupName : $_"
                }
            }
        } else {
            Write-Warning "Fichier CSV introuvable : $($config.CSVPath)"
        }
        Pause-Step

        # Suppression de la tâche planifiée post-reboot
        schtasks /delete /tn "AutoADDeploy" /f
        Remove-Item $configFile -Force
        Stop-Transcript
        exit
    } else {
        Write-Host "Redémarrage effectué avant promotion AD. Le domaine n'est pas encore actif."
        Stop-Transcript
        exit
    }
}

# ------------------- PHASE INTERACTIVE INITIALE -------------------
$config = @{}

# 1. Adresse IP statique
$config.IP = Read-Host "Entrez l'adresse IP statique"
$config.Mask = Read-Host "Entrez le masque de sous-réseau (ex: 255.255.255.0)"
$config.Gateway = Read-Host "Entrez la passerelle par défaut"
$config.DNS = Read-Host "Entrez l'adresse du serveur DNS primaire (souvent identique à l'IP)"
$interface = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
New-NetIPAddress -InterfaceAlias $interface.Name -IPAddress $config.IP -PrefixLength (($config.Mask -split '\.').Where{$_ -ne '255'}.Count * 8) -DefaultGateway $config.Gateway
Set-DnsClientServerAddress -InterfaceAlias $interface.Name -ServerAddresses $config.DNS

# 2. Renommer le PC
$config.NewName = Read-Host "Entrez le nouveau nom du PC"
Rename-Computer -NewName $config.NewName -Force

# 3. Nom de domaine
$config.DomainName = Read-Host "Entrez le nom du domaine à créer"
$config.NetBIOSName = Read-Host "Entrez le nom NetBIOS du domaine (ex: MONDOMAINE, laisser vide pour auto)"
if ([string]::IsNullOrWhiteSpace($config.NetBIOSName)) {
    $config.NetBIOSName = ($config.DomainName -split '\.')[0].ToUpper()
    Write-Host "Nom NetBIOS automatiquement défini : $($config.NetBIOSName)"
}
$config.DomainSafePassword = Read-Host "Mot de passe du mode restauration DSRM" -AsSecureString

# 4. Création OU
[int]$nbOU = Read-Host "Combien d'OU souhaitez-vous créer ?"
$config.OUList = @()
for ($i = 1; $i -le $nbOU; $i++) {
    $config.OUList += Read-Host "Nom de l'OU #$i"
}

# 5. Création groupes
[int]$nbGroups = Read-Host "Combien de groupes souhaitez-vous créer ?"
$config.GroupList = @()
for ($i = 1; $i -le $nbGroups; $i++) {
    $grpName = Read-Host "Nom du groupe #$i"
    $grpOU   = Read-Host "OU d'appartenance pour ce groupe"
    $config.GroupList += @{ Name = $grpName; OU = $grpOU }
}

# 6. Partage
$config.ShareName = Read-Host "Nom du dossier de partage (créé sur le bureau)"

# 7. Utilisateurs via CSV
$config.UserMode = 'c'
$config.CSVPath = Read-Host "Chemin du fichier CSV utilisateurs (colonnes: Name,OU,Group)"

# 8. # --- Création et liaison de GPO ---
do {
    $createGpo = Read-Host "Souhaitez-vous créer une GPO ? (O/N)"
    if ($createGpo -eq "O") {
        $gpoName = Read-Host "Entrez le nom de la GPO à créer"
        New-GPO -Name $gpoName -ErrorAction Stop | Out-Null
        Write-Host "GPO '$gpoName' créée avec succès.`n"

        $linkChoice = Read-Host "Souhaitez-vous la lier à une OU (1), au domaine (2), ou l'appliquer localement (3) ?"

        switch ($linkChoice) {
            '1' {
                $ouName = Read-Host "Nom de l'OU cible"
                $ouDn = Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" | Select-Object -ExpandProperty DistinguishedName
                if ($ouDn) {
                    New-GPLink -Name $gpoName -Target $ouDn -Enforced:$false
                    Write-Host "GPO '$gpoName' liée à l'OU '$ouName'"
                } else {
                    Write-Warning "OU '$ouName' introuvable"
                }
            }
            '2' {
                $domainDn = (Get-ADDomain).DistinguishedName
                New-GPLink -Name $gpoName -Target $domainDn -Enforced:$false
                Write-Host "GPO '$gpoName' liée au domaine"
            }
            '3' {
                $tempPath = "$env:TEMP\LocalGpoBackup"
                Backup-GPO -Name $gpoName -Path $tempPath -ErrorAction Stop
                Import-GPO -BackupGpoName $gpoName -Path $tempPath -TargetName "LocalGPO" -CreateIfNeeded -TargetType Computer
                Write-Host "GPO '$gpoName' appliquée localement"
            }
            default {
                Write-Warning "Option inconnue. GPO créée mais non liée."
            }
        }
    }
} while ($createGpo -eq "O")

# Indicateur initial pour post-redémarrage
$config.IsPromoted = $false

# Enregistrement config pour post-reboot
$config | ConvertTo-Json | Set-Content -Path $configFile

# 9. Installation des rôles AD
Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools

# 10. Promotion du contrôleur de domaine
Install-ADDSForest -DomainName $config.DomainName -DomainNetbiosName $config.NetBIOSName -SafeModeAdministratorPassword $config.DomainSafePassword -Force

# 11. Mise à jour du statut post-promotion
$config.IsPromoted = $true
$config | ConvertTo-Json | Set-Content -Path $configFile

# 12. Tâche planifiée pour auto-exécution après ouverture de session
$taskPath = "$PSCommandPath"
schtasks /create /tn "AutoADDeploy" /tr "powershell -ExecutionPolicy Bypass -File '$taskPath'" /sc onlogon /rl highest /f

# 13. Redémarrage automatique
Write-Host "Redémarrage en cours..."
Restart-Computer
