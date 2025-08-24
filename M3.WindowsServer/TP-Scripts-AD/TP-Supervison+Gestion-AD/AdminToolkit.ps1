# AdminToolkit.ps1 (V2 - Menu unique)
param(
    [string]$RootPath = "$env:USERPROFILE\Desktop\Admin_Toolkit"
)

# Chargement modules
Import-Module "$PSScriptRoot\Modules\Logging.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Utils.psm1" -Force
Import-Module "$PSScriptRoot\Modules\ADDeployment.psm1" -Force
Import-Module "$PSScriptRoot\Modules\PostConfig.psm1" -Force
Import-Module "$PSScriptRoot\Modules\GPOManagement.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Supervision.psm1" -Force
Import-Module "$PSScriptRoot\Modules\Report.psm1" -Force

# Vérif admin
Test-AdminRights

# Journalisation
Start-ToolkitLog -RootPath $RootPath

# S'assurer des dossiers Rapports/Logs
$RapportsDir = Join-Path $RootPath 'Rapports'
if (!(Test-Path $RapportsDir)) { New-Item -ItemType Directory -Path $RapportsDir -Force | Out-Null }

# --------------------------- Menus -----------------------------
function Show-MainMenu {
    Clear-Host
    Write-Host "========= ADMIN TOOLKIT =========" -ForegroundColor Cyan
    Write-Host "1. Supervision (Événements / Process / Services)"
    Write-Host "2. Gestion Active Directory"
    Write-Host "3. Générer Rapport Consolidé"
    Write-Host "4. Quitter"
    Write-Host "================================="
}

function Show-ADMenu {
    Clear-Host
    Write-Host "===== GESTION AD =====" -ForegroundColor Cyan
    Write-Host "1. Unités Organisationnelles"
    Write-Host "2. Utilisateurs"
    Write-Host "3. Groupes"
    Write-Host "4. GPO"
    Write-Host "5. ACL sur Partage"
    Write-Host "6. Retour"
}

function Show-OUMenu {
    Clear-Host
    Write-Host "===== GESTION OU =====" -ForegroundColor Cyan
    Write-Host "1. Créer OU"
    Write-Host "2. Supprimer OU"
    Write-Host "3. Lister OU"
    Write-Host "4. Retour"
}

function Show-UserMenu {
    Clear-Host
    Write-Host "===== GESTION UTILISATEURS =====" -ForegroundColor Cyan
    Write-Host "1. Créer utilisateur"
    Write-Host "2. Supprimer utilisateur"
    Write-Host "3. Déplacer utilisateur dans OU"
    Write-Host "4. Ajouter utilisateur à groupe"
    Write-Host "5. Retour"
}

function Show-GroupMenu {
    Clear-Host
    Write-Host "===== GESTION GROUPES =====" -ForegroundColor Cyan
    Write-Host "1. Créer groupe"
    Write-Host "2. Supprimer groupe"
    Write-Host "3. Retour"
}

function Show-GPOMenu {
    Clear-Host
    Write-Host "===== GESTION GPO =====" -ForegroundColor Cyan
    Write-Host "1. Déployer GPO prédéfinies"
    Write-Host "2. Créer GPO custom"
    Write-Host "3. Retour"
}

# --------------------------- Supervision wrapper -----------------------------
function Invoke-Supervision {
    Clear-Host
    Write-Host "===== SUPERVISION =====" -ForegroundColor Cyan
    Write-Host "1. Événements critiques"
    Write-Host "2. Processus gourmands"
    Write-Host "3. Services critiques"
    Write-Host "4. Retour"
    $c = Read-Host "Choix"
    switch ($c) {
        1 {
            $r = Export-CriticalEventsReport -ReportFolder $RapportsDir
            Write-Host "Rapports événements -> $($r.Csv), $($r.Html)" -ForegroundColor Green
        }
        2 {
            $r = Export-TopProcessesReport -ReportFolder $RapportsDir
            Write-Host "Rapports processus -> $($r.Csv), $($r.Html)" -ForegroundColor Green
        }
        3 {
            $r = Export-CriticalServicesReport -ReportFolder $RapportsDir
            Write-Host "Rapports services -> $($r.Csv), $($r.Html)" -ForegroundColor Green
        }
    }
    Read-Host "Entrée pour continuer..." | Out-Null
}

# --------------------------- AD wrapper flows -----------------------------
function Invoke-OUManagement {
    do {
        Show-OUMenu
        $c = Read-Host "Choix"
        switch ($c) {
            1 {
                $ou = Read-Host "Nom OU"
                New-ToolkitOU -OUName $ou
            }
            2 {
                $ou = Read-Host "Nom OU à supprimer"
                Remove-ToolkitOU -OUName $ou
            }
            3 {
                Get-AllOU | Format-Table Name,DistinguishedName -AutoSize
            }
            4 { break }
            default { Write-Host "Choix invalide." -ForegroundColor Red }
        }
        if ($c -ne 4) { Read-Host "Entrée pour continuer..." | Out-Null }
    } while ($c -ne 4)
}

function Invoke-UserManagement {
    do {
        Show-UserMenu
        $c = Read-Host "Choix"
        switch ($c) {
            1 {
                $display = Read-Host "Prénom Nom (ex: Jean Dupont)"
                $parts = $display.Split(' ')
                if ($parts.Count -lt 2) { Write-Host "Format invalide." -ForegroundColor Red; break }
                $given = $parts[0]; $sur = $parts[1]
                $ou = Read-Host "OU cible"
                New-ToolkitUser -DisplayName $display -GivenName $given -Surname $sur -OUName $ou
            }
            2 {
                $sam = Read-Host "SamAccountName à supprimer"
                Remove-ToolkitUser -SamAccountName $sam
            }
            3 {
                $sam = Read-Host "SamAccountName"
                $ou = Read-Host "OU cible"
                Move-ToolkitUserToOU -SamAccountName $sam -OUName $ou
            }
            4 {
                $sam = Read-Host "SamAccountName"
                $grp = Read-Host "Nom du groupe"
                Add-ToolkitUserToGroup -SamAccountName $sam -GroupName $grp
            }
            5 { break }
            default { Write-Host "Choix invalide." -ForegroundColor Red }
        }
        if ($c -ne 5) { Read-Host "Entrée pour continuer..." | Out-Null }
    } while ($c -ne 5)
}

function Invoke-GroupManagement {
    do {
        Show-GroupMenu
        $c = Read-Host "Choix"
        switch ($c) {
            1 {
                $name = Read-Host "Nom du groupe"
                $scope = Read-Host "Scope (Global/DomainLocal/Universal)"
                $cat = Read-Host "Type (Security/Distribution)"
                $ouPath = Read-Host "Chemin LDAP complet ou vide=par défaut"
                if (-not $ouPath) { $ouPath = (Get-ADDomain).DistinguishedName }
                New-ToolkitGroup -Name $name -GroupScope $scope -GroupCategory $cat -OUPath $ouPath
            }
            2 {
                $name = Read-Host "Nom du groupe à supprimer"
                Remove-ToolkitGroup -Name $name
            }
            3 { break }
            default { Write-Host "Choix invalide." -ForegroundColor Red }
        }
        if ($c -ne 3) { Read-Host "Entrée pour continuer..." | Out-Null }
    } while ($c -ne 3)
}

function Invoke-GPOManagement {
    do {
        Show-GPOMenu
        $c = Read-Host "Choix"
        switch ($c) {
            1 {
                $scope = Read-Host "Déployer sur Domaine ou OU ? (Domaine/OU)"
                $ou = if ($scope -eq 'OU') { Read-Host "Nom OU" } else { $null }
                Deploy-PredefinedGPOs -Scope $scope -OUName $ou
            }
            2 {
                $name = Read-Host "Nom GPO"
                $scope = Read-Host "Lien ? (Domaine/OU/Aucun)"
                $ou = if ($scope -eq 'OU') { Read-Host "Nom OU" } else { $null }
                New-CustomGPO -Name $name -Scope $scope -OUName $ou
            }
            3 { break }
            default { Write-Host "Choix invalide." -ForegroundColor Red }
        }
        if ($c -ne 3) { Read-Host "Entrée pour continuer..." | Out-Null }
    } while ($c -ne 3)
}

function Invoke-ACLManagement {
    $path = Read-Host "Chemin ressource (ex: C:\Partage\Docs)"
    $user = Read-Host "Identité utilisateur (nom simple, DOMAINE\user ou UPN)"
    $perm = Read-Host "Permission (FullControl, Modify, Read, etc.)"
    Set-ToolkitACL -Path $path -UserInput $user -Permission $perm
    Read-Host "Entrée pour continuer..." | Out-Null
}

function Invoke-ADMenu {
    do {
        Show-ADMenu
        $c = Read-Host "Choix"
        switch ($c) {
            1 { Invoke-OUManagement }
            2 { Invoke-UserManagement }
            3 { Invoke-GroupManagement }
            4 { Invoke-GPOManagement }
            5 { Invoke-ACLManagement }
            6 { break }
            default { Write-Host "Choix invalide." -ForegroundColor Red }
        }
    } while ($c -ne 6)
}

# --------------------------- Main loop -----------------------------
do {
    Show-MainMenu
    $choice = Read-Host "Votre choix"
    switch ($choice) {
        1 { Invoke-Supervision }
        2 { Invoke-ADMenu }
        3 {
            $r = New-ConsolidatedReport -ReportFolder $RapportsDir
            Write-Host "Rapport consolidé généré -> $r" -ForegroundColor Green
            Read-Host "Entrée pour continuer..." | Out-Null
        }
        4 { break }
        default { Write-Host "Choix invalide." -ForegroundColor Red }
    }
} while ($choice -ne 4)

Stop-ToolkitLog
Write-Host "Fin AdminToolkit." -ForegroundColor Green
