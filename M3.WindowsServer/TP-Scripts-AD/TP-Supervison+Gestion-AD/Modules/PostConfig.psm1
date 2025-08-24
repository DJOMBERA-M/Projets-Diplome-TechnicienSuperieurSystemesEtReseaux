# Modules/PostConfig.psm1
<# Post promotion Active Directory configuration #>

Import-Module ActiveDirectory -ErrorAction SilentlyContinue

function Get-AllOU {
    [CmdletBinding()] param()
    Get-ADOrganizationalUnit -Filter * -Properties Name | Sort-Object Name
}

function New-ToolkitOU {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$OUName,
        [string]$ParentDN = (Get-ADDomain).DistinguishedName
    )
    $dn = "OU=$OUName,$ParentDN"
    if (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OUName)" -SearchBase $ParentDN -ErrorAction SilentlyContinue) {
        Write-Host "[OU] '$OUName' existe déjà." -ForegroundColor Yellow
        return
    }
    New-ADOrganizationalUnit -Name $OUName -Path $ParentDN -ProtectedFromAccidentalDeletion:$false -ErrorAction Stop
    Write-Host "[OU] '$OUName' créée." -ForegroundColor Green
}

function Remove-ToolkitOU {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$OUName,
        [string]$ParentDN = (Get-ADDomain).DistinguishedName,
        [switch]$Force
    )
    $dn = "OU=$OUName,$ParentDN"
    $ou = Get-ADOrganizationalUnit -Identity $dn -ErrorAction SilentlyContinue
    if (-not $ou) {
        Write-Host "[OU] '$OUName' introuvable." -ForegroundColor Red
        return
    }
    if (-not $Force) {
        $confirm = Read-Host "Confirmer suppression OU '$OUName' (o/n)"
        if ($confirm -notmatch '^[oOyY]') { Write-Host "Annulé."; return }
    }
    Set-ADOrganizationalUnit -Identity $dn -ProtectedFromAccidentalDeletion:$false -ErrorAction SilentlyContinue
    Remove-ADOrganizationalUnit -Identity $dn -Recursive -Confirm:$false -ErrorAction Stop
    Write-Host "[OU] '$OUName' supprimée." -ForegroundColor Green
}

function New-ToolkitUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][string]$GivenName,
        [Parameter(Mandatory)][string]$Surname,
        [Parameter(Mandatory)][string]$OUName,
        [string]$Password = 'Pàssw0rd'
    )
    $domainDN = (Get-ADDomain).DistinguishedName
    $path = "OU=$OUName,$domainDN"
    $sam  = ($GivenName.Substring(0,1) + $Surname).ToLower()
    # Q6c verify user existence
    $exists = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
    if ($exists) {
        Write-Host "[User] sAMAccountName $sam existe déjà. Création ignorée." -ForegroundColor Yellow
        return
    }
    try {
        New-ADUser -Name $DisplayName `
            -GivenName $GivenName `
            -Surname $Surname `
            -SamAccountName $sam `
            -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) `
            -Enabled $true `
            -ChangePasswordAtLogon $true `
            -Path $path `
            -ErrorAction Stop
        Write-Host "[User] '$DisplayName' créé ($sam)." -ForegroundColor Green
    } catch {
        Write-Host "[User] Erreur création '$DisplayName' : $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Remove-ToolkitUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SamAccountName,
        [switch]$Force
    )
    $u = Get-ADUser -Identity $SamAccountName -ErrorAction SilentlyContinue
    if (-not $u) { Write-Host "[User] $SamAccountName introuvable." -ForegroundColor Yellow; return }
    if (-not $Force) {
        $c = Read-Host "Supprimer utilisateur '$SamAccountName' ? (o/n)"
        if ($c -notmatch '^[oOyY]') { Write-Host "Annulé."; return }
    }
    Remove-ADUser -Identity $SamAccountName -Confirm:$false -ErrorAction Stop
    Write-Host "[User] $SamAccountName supprimé." -ForegroundColor Green
}

function Move-ToolkitUserToOU {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SamAccountName,
        [Parameter(Mandatory)][string]$OUName
    )
    $domainDN = (Get-ADDomain).DistinguishedName
    $target = "OU=$OUName,$domainDN"
    $udn = (Get-ADUser -Identity $SamAccountName -ErrorAction Stop).DistinguishedName
    Move-ADObject -Identity $udn -TargetPath $target -ErrorAction Stop
    Write-Host "[User] $SamAccountName déplacé vers $OUName." -ForegroundColor Green
}

function Add-ToolkitUserToGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SamAccountName,
        [Parameter(Mandatory)][string]$GroupName
    )
    $grp = Get-ADGroup -Identity $GroupName -ErrorAction SilentlyContinue
    if (-not $grp) { Write-Host "[Groupe] $GroupName introuvable." -ForegroundColor Red; return }
    Add-ADGroupMember -Identity $GroupName -Members $SamAccountName -ErrorAction Stop
    Write-Host "[Groupe] $SamAccountName ajouté à $GroupName." -ForegroundColor Green
}

function New-ToolkitGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [ValidateSet('Global','DomainLocal','Universal')][string]$GroupScope='Global',
        [ValidateSet('Security','Distribution')][string]$GroupCategory='Security',
        [string]$OUPath = (Get-ADDomain).DistinguishedName
    )
    if (Get-ADGroup -Filter "Name -eq '$Name'" -ErrorAction SilentlyContinue) {
        Write-Host "[Groupe] '$Name' existe déjà." -ForegroundColor Yellow
        return
    }
    New-ADGroup -Name $Name -GroupScope $GroupScope -GroupCategory $GroupCategory -Path $OUPath -Description "Groupe $GroupCategory créé via Toolkit" -ErrorAction Stop
    Write-Host "[Groupe] '$Name' créé." -ForegroundColor Green
}

function Remove-ToolkitGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$Force
    )
    $grp = Get-ADGroup -Filter "Name -eq '$Name'" -ErrorAction SilentlyContinue
    if (-not $grp) { Write-Host "[Groupe] '$Name' introuvable." -ForegroundColor Yellow; return }
    if (-not $Force) {
        $c = Read-Host "Supprimer groupe '$Name' ? (o/n)"
        if ($c -notmatch '^[oOyY]') { Write-Host "Annulé."; return }
    }
    Remove-ADGroup -Identity $grp -Confirm:$false -ErrorAction Stop
    Write-Host "[Groupe] '$Name' supprimé." -ForegroundColor Green
}

function Set-ToolkitACL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$UserInput,
        [Parameter(Mandatory)][string]$Permission
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "[ACL] Chemin '$Path' introuvable." -ForegroundColor Red
        return
    }
    $account = if ($UserInput -match '\\' -or $UserInput -match '@') { $UserInput } else { \"$env:USERDOMAIN\\$UserInput\" }
    try {
        $acl = Get-Acl -LiteralPath $Path
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($account,$Permission,\"ContainerInherit,ObjectInherit\",\"None\",\"Allow\")
        $acl.SetAccessRule($rule)
        Set-Acl -LiteralPath $Path -AclObject $acl
        Write-Host \"[ACL] Droits '$Permission' appliqués à '$account' sur '$Path'.\" -ForegroundColor Green
    } catch {
        Write-Host \"[ACL] Erreur : $($_.Exception.Message)\" -ForegroundColor Red
    }
}

Export-ModuleMember -Function Get-AllOU, New-ToolkitOU, Remove-ToolkitOU, New-ToolkitUser, Remove-ToolkitUser, Move-ToolkitUserToOU, Add-ToolkitUserToGroup, New-ToolkitGroup, Remove-ToolkitGroup, Set-ToolkitACL
