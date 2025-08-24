while($true) { ####debut boucle gestion d'objet
    $DomainPath = (Get-ADDomain).DistinguishedName 
    $var = Read-Host "        Gestion des objet
    1- configuration OU ||2- configuration utilisateur || 3- configuration groupe ||4- Quitter 
    "
##########################################################################################################################################
    
    if ($var -eq 1) {  #debut condition configuration OU
        $conf_ou = 0 #ajout donn2E inexistante

        while ($conf_ou -notin 1,2,3,4 ) { #debut boucle configuratio OU
            Write-host "#####################################################"
            Write-host "######             OPTION CONFIG OU            ######"-ForegroundColor Cyan
            Write-host "#####################################################" 
            $conf_ou = Read-Host "1 - ajout OU ||2 - suppression OU ||3 - ajout GPO ||4 - retour" 
            
            if ($conf_ou -eq 1 ) { #debut condition ajout OU
                do { #debut de la boucle creation ou
                $OU = Read-Host "Entrez le nom de l'OU à ajouter"
                New-ADOrganizationalUnit -Name "$OU" -Path "$DomainPath"
                Write-Host "OU '$OU' créée avec succès." -ForegroundColor Green

                $reponse = Read-Host "Voulez-vous créer un autre OU ? (o/n)"
                } while ($reponse -eq 'o' -or $reponse -eq 'O') #cloture de la boucle creation OU si reponse n
            
            } #cloture condition ajout OU
           
            elseif($conf_ou -eq 2) { #debut condition suppression OU
                $OU = Read-Host "entrer le nom de l'OU a supprimer"
                Set-ADOrganizationalUnit -Identity "OU=$OU,$DomainPath" -ProtectedFromAccidentalDeletion $false #retrait de la protection anti-suppression OU
                Remove-ADOrganizationalUnit -Identity "OU=$OU,$DomainPath" -Recursive -Confirm:$false  #suppression de l'OU
                }  #cloture de la condition suppression OU
            
            elseif ($conf_ou -eq 3) {  # debut condition ajout GPO
            Write-Host "`n### Création et liaison des GPO ###" -ForegroundColor Cyan

            # Liste des GPO avec paramètres
            $GPOs = @(
                @{Name="FondEcran_Jaune"; Desc="Fond d'écran jaune"; Action={Set-GPRegistryValue -Name "FondEcran_Jaune" -Key "HKCU\Control Panel\Desktop" -ValueName "Wallpaper" -Type String -Value "C:\Windows\Web\Wallpaper\Windows\img0.jpg"}},
                @{Name="AutoLogoff_15min"; Desc="Déconnexion après 15min"; Action={Set-GPRegistryValue -Name "AutoLogoff_15min" -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" -ValueName "ScreenSaveTimeOut" -Type String -Value "900"}},
                @{Name="Blocage_PanneauConfig"; Desc="Blocage Panneau de config"; Action={Set-GPRegistryValue -Name "Blocage_PanneauConfig" -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -ValueName "NoControlPanel" -Type DWord -Value 1}},
                @{Name="PasswordPolicy_8char"; Desc="Mot de passe min 8"; Action={Set-GPRegistryValue -Name "PasswordPolicy_8char" -Key "HKLM\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -ValueName "MinimumPasswordLength" -Type DWord -Value 8}},
                @{Name="Blocage_TaskManager"; Desc="Blocage Gestionnaire tâches"; Action={Set-GPRegistryValue -Name "Blocage_TaskManager" -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "DisableTaskMgr" -Type DWord -Value 1}},
                @{Name="Blocage_USB"; Desc="Blocage périphériques USB"; Action={Set-GPRegistryValue -Name "Blocage_USB" -Key "HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR" -ValueName "Start" -Type DWord -Value 4}},
                @{Name="Message_Logon"; Desc="Message avant connexion"; Action={Set-GPRegistryValue -Name "Message_Logon" -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName "LegalNoticeText" -Type String -Value "Bienvenue sur le réseau sécurisé"}},
                @{Name="Blocage_CMD"; Desc="Blocage CMD"; Action={Set-GPRegistryValue -Name "Blocage_CMD" -Key "HKCU\Software\Policies\Microsoft\Windows\System" -ValueName "DisableCMD" -Type DWord -Value 1}}
            )

            # Création des GPO si inexistantes
            foreach ($gpo in $GPOs) { #pour chaque élément de $GPOs, crée la variable $gpo qui prend la valeur de cet élément, l’un après l’autre
                if (-not (Get-GPO -Name $gpo.Name -ErrorAction SilentlyContinue)) { #condition si le gpo de la liste GPOs n'existe pas 
                    New-GPO -Name $gpo.Name | Out-Null   #cree le gpo 
                    Write-Host "✅ GPO '$($gpo.Name)' créée." -ForegroundColor Green
                } else {
                    Write-Host "ℹ GPO '$($gpo.Name)' existe déjà." -ForegroundColor Yellow
                }
                # Application des paramètres
                & $gpo.Action   #(&) Exécute la commande stockée dans la propriété Action de l’objet ($gpo) via Set-GPRegistryValue. 
            } #cloture de la boucle foreach

            # Choisir une OU existante
            $OU = Read-Host "Entrez le nom de l'OU sur laquelle lier les GPO"
            $TargetOU = "OU=$OU,$DomainPath"

            # listage et  Sélection des GPO à lier
            Write-Host "`nListe des GPO disponibles :" -ForegroundColor Yellow
            for ($i = 0; $i -lt $GPOs.Count; $i++) {  #condition:pour pour chaque gpo de la liste GPOs par incrementation jusqu'au nombre maximal de la liste
                Write-Host "$($i+1) - $($GPOs[$i].Name) ($($GPOs[$i].Desc))" # lister les GPO avec un numero - nom - description
            } #cloture de la condition for

            $selection = Read-Host "Entrez les numéros des GPO à lier (ex: 1,3,5)"
            $choixArray = $selection.Split(",") | ForEach-Object { $_.Trim() }  #split separe la chaine entre chaque virgule et trim supprim les espaces

            foreach ($index in $choixArray) {  #pour chaque élément de $choixArray, crée la variable $index qui prend la valeur de cet élément, l’un après l’autre
                if ([int]::TryParse($index, [ref]$null) -and ($num = [int]$index) -ge 1 -and $num -le $GPOs.Count) { #TryParse verifie que $index est un chiffre, [ref]$null supprime le resultat 
                    $GPOName = $GPOs[$index - 1].Name # index -1 car le tableau $GPOs commence à 0, mais l’affichage utilisateur commence à 1.
                    New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes  #lie le GPO a l'OU
                    Write-Host "🔗 GPO '$GPOName' liée à l'OU $TargetOU" -ForegroundColor Green
                }  #cloture de la condition if
                else {
                    Write-Host "❌ Numéro invalide : $index" -ForegroundColor Red
                } #cloture condition else
            } #cloture boucle foreach
        } #cloture condition ajout GPO
   
        elseif ($conf_ou -eq 4) {  #debut de la condition retour
                break
        } #cloture condition retour4
            
        else { #debut condition final de la boucle

                Write-Host "erreur de configuratuion : recommencez !"
                } #cloture condition final de la boucle
        }  #cloture boucle configuration OU
    }  #cloture condition configuration OU
#################################################################################################################################################################################
    
    elseif ($var -eq 2) { # debut condition configuration utilisateur
        $conf_u = 0

        while ($conf_u -lt 1 -or $conf_u -gt 6) {#debut boucle coonfiguration utilisateur
            Write-host "#####################################################"
            Write-host "######     OPTION CONFIGURATION UTILISATEUR    ######"-ForegroundColor Cyan
            Write-host "#####################################################"
            $conf_u = Read-Host "1- ajout utilisateur ||2- suppression utilisateur ||3- affectation d'utilisateur a un OU ||4- affectation d'un utilisateur a un groupe ||5- modification ACL ||6 - retour"
            
            if ($conf_u -eq 1) { #debut de la condition ajout utilisateur
                        
                        Write-host "######        AJOUT UTILISATE               ######"

                do { #debut de la boucle creation d'utilisateur
                    # Demande des informations utilisateur
                    $name = Read-Host "Entrez le prénom et nom de l'utilisateur (ex: Jean Dupont)"
                    $gname = $name.Split(" ")[0]  # prend le prénom
                    $sname = $name.Split(" ")[1]  # prend le nom
                    $saname = ($gname[0] + $sname).ToLower() # login: première lettre prénom + nom
                    $ou = Read-Host "Entrez l'OU dans laquelle vous souhaitez intégrer l'utilisateur"

                    try {
                        # Création de l'utilisateur avec arrêt en cas d'erreur
                        New-ADUser -Name "$name" `
                                   -GivenName "$gname" `
                                   -Surname "$sname" `
                                   -SamAccountName "$saname" `
                                   -AccountPassword (ConvertTo-SecureString -AsPlainText "Pàssw0rd" -Force) `
                                   -Enabled $true `
                                   -ChangePasswordAtLogon $true `
                                   -Path "OU=$ou,$DomainPathl" `
                                   -ErrorAction Stop

                        Write-Host "✅ Utilisateur '$name' créé avec succès. Mot de passe temporaire: Pàssw0rd" -ForegroundColor Green
                        Write-Host "ℹ L'utilisateur devra créer un nouveau mot de passe à la première connexion." -ForegroundColor Yellow
                     }
                     catch {
                        Write-Host "❌ Échec de la création de l'utilisateur '$name' : $($_.Exception.Message)" -ForegroundColor Red
                        }

                    # Question pour continuer
                    $reponse = Read-Host "Voulez-vous créer un autre utilisateur ? (o/n)"
                } while ($reponse -eq 'o' -or $reponse -eq 'O') #cloture de la boucle creation d'utilisateur

            } #cloture de la condition creation d'utilisateur
            elseif ($conf_u -eq 2) { #debut de la condition suppression utilisateur 
           
                Write-host "######         SUPPRESSION UTILISATEUR         ######"
         
                do {
                    # Demande du SamAccountName
                    $saname = Read-Host "Entrez le nom d'ouverture de session de l'utilisateur à supprimer (ex : jdupont)"

                    # Vérifie si l'utilisateur existe avant suppression
                    $userExists = Get-ADUser -Filter { SamAccountName -eq $saname } -ErrorAction SilentlyContinue
                    if ($userExists) {
                        Remove-ADUser -Identity $saname -Confirm:$false
                        Write-Host "Utilisateur '$saname' supprimé avec succès." -ForegroundColor Green
                    } else {
                        Write-Host "Erreur : L'utilisateur '$saname' n'existe pas." -ForegroundColor Yellow
                    }

                    # Question pour continuer
                    $reponse = Read-Host "Voulez-vous supprimer un autre utilisateur ? (o/n)"
                } while ($reponse -eq 'o' -or $reponse -eq 'O')
            }#cloture de la condition suppression utilisateur         

            elseif ($conf_u -eq 3) { #debut de la condition affectation d'utilisateur a un OU

                Write-Host "######        AFFECTATION A UN OU            ######"
                   
                    $saname = Read-Host "Entrez le nom d'utilisateur de l'utilisateur (sAMMAccountName ex:jdupont) a affecter"
                    $OU = Read-Host "entrez le nom de l'OU auquel affecter l'utilisateur"
                    $userdn = (Get-ADUser -Identity $saname).DistinguishedName  # Récupérer le DistinguishedName de l'utilisateur
                    
                    Move-ADObject -Identity $userdn -TargetPath "OU=$OU,$DomainPath"#affectation de l'utilisateur a l'OU
            } #cloture de la condition d'affectation a un OU
                    
            elseif ($conf_u -eq 4) {#debut de la condition d'affectation d'utilisateur a un groupe
                
                $saname = Read-Host "entrez le nom d'utilisateur de l'utilisateur (sAMMAccountName ex:jdupont) a affecter "
                $group = Read-Host "entrez le nom du groupe auquel affecter l'utilisateur"
                Add-ADGroupMember -Identity "$group" -Members "$saname" #ajout de l'utilisateur dans le groupe
            } #cloture de la condition affectation a un groupe
                

            elseif ($conf_u -eq 5) { #debut de la condition modification ACL
                         
                         Write-host "######        MODIFICATION ACL        ######"
                        
                         Write-Host " Rappel des principaux types de permissions (FileSystemRights) disponibles :`n"
                         Write-Host "`t* FullControl`t: Contrôle total (toutes les permissions)"
                         Write-Host "`t* Modify`t: Lire, écrire, supprimer, créer, modifier"
                         Write-Host "`t* ReadAndExecute`t: Lire le contenu et exécuter les fichiers"
                         Write-Host "`t* Read`t: Lire les fichiers et les attributs"
                         Write-Host "`t* Write`t: Écrire dans les fichiers, créer des fichiers/dossiers"
                         Write-Host "`t* ListDirectory`t: Voir le contenu du dossier"
                         Write-Host "`t* ReadAttributes`t: Lire les attributs des fichiers/dossiers"
                         Write-Host "`t* ReadExtendedAttributes`t: Lire les attributs étendus (métadonnées)"
                         Write-Host "`t* WriteAttributes`t: Modifier les attributs"
                         Write-Host "`t* WriteExtendedAttributes`t: Modifier les attributs étendus"
                         Write-Host "`t* CreateFiles`t: Créer des fichiers dans un dossier"
                         Write-Host "`t* CreateDirectories`t: Créer des sous-dossiers"
                         Write-Host "`t* DeleteSubdirectoriesAndFiles`t: Supprimer les fichiers et sous-dossiers"
                         Write-Host "`t* Delete`t: Supprimer le fichier ou le dossier"
                         Write-Host "`t* ReadPermissions`t: Lire les permissions définies sur l’objet"
                         Write-Host "`t* ChangePermissions`t: Modifier les ACL"
                         Write-Host "`t* TakeOwnership`t: Prendre possession de l’objet"
                         Write-Host "`t* Synchronize`t: Synchroniser l’accès aux fichiers (usage système)"
                         Write-host "#####################################################`n"
                         # Chemin du dossier auquel on veut attribuer des droits
                         $folderPath = Read-host "Entrez le chemin de la ressource concernée. exemple C:\Partage\Docs"
 
                         # Nom d'utilisateur avec domaine (ou juste le nom si utilisateur local)
                         $user = Read-Host "Entrez l'identité de l'utilisateur concerné"
 
                         $permission = Read-Host "Entrez la permission"
 
                         # Récupère les règles de contrôle d’accès (ACL) actuelles du dossier
                         $acl = Get-Acl $folderPath
 
                         # Crée une règle d’accès :
                         # Paramètres :
                         # - $user : l’utilisateur ou groupe à qui on attribue les droits
                         # - "FullControl" : type d’autorisation (peut être Read, Write, Modify, etc.)
                         # - "ContainerInherit,ObjectInherit" :
                         #     ContainerInherit = s'applique aux sous-dossiers
                         #     ObjectInherit    = s'applique aux fichiers contenus dans le dossier
                         # - "None" : signifie que l’héritage des permissions n’est pas bloqué
                         # - "Allow" : on autorise l'accès (au lieu de "Deny" pour interdire)
                         $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                             "SETE\$user",                          # Nom de l’utilisateur ou groupe
                              $permission,                 # Type de permission
                             "ContainerInherit,ObjectInherit", # Application récursive sur sous-dossiers/fichiers
                             "None",                        # Pas de restriction d’héritage
                             "Allow"                        # Type d’accès : autoriser
                         )
 
                         # Ajoute la règle au jeu d’ACL actuel
                         $acl.SetAccessRule($rule)
 
                         # Applique les nouvelles permissions au dossier
                         Set-Acl -Path $folderPath -AclObject $acl

                elseif ($conf_u -eq 6) { #debut de la condition retour
                    break
                }
                            
                         } #cloture de la condition modification ACL

           }#cloture de la boucle configuration utilisateur
    } #cloture de la condition configuration utilisateur
                                
################################################################################################################################################  
    
    elseif ($var -eq 3) {  # début condition configuration GROUPE
    $conf_grp = 0  # initialisation de la variable de menu

    while ($conf_grp -ne 1 -and $conf_grp -ne 2 -and $conf_grp -ne 3) { #debut de la boucle configuration de groupe
        Write-host "#####################################################"
        Write-host "######         OPTION CONFIGURATION GROUPE     ######" -ForegroundColor Cyan
        Write-host "#####################################################"

        $conf_grp = Read-Host "1 - Création groupe || 2 - Suppression groupe || 3 - Retour"

        if ($conf_grp -eq 1) {  #debut de la condition creation de groupe

            do { #debut de la boucle creation de groupe
                $nomGroupe  = Read-Host "`nNom du groupe"
                $perimetre  = Read-Host "Périmètre du groupe (Global, DomainLocal, Universal)"
                $typeGroupe = Read-Host "Type de groupe (Security ou Distribution)"
                $ou         = Read-Host "Chemin LDAP complet (ex: OU=Services,DC=sete,DC=local)"

                $perimetresValides = @("Global", "DomainLocal", "Universal")
                $typesValides = @("Security", "Distribution")
                # verification d'erreur perimetre et groupe

                if ($perimetresValides -notcontains $perimetre) {
                    Write-Host "❌ Périmètre '$perimetre' invalide." -ForegroundColor Red
                    continue
                }
                if ($typesValides -notcontains $typeGroupe) {
                    Write-Host "❌ Type '$typeGroupe' invalide." -ForegroundColor Red
                    continue
                }
                
                if (Get-ADGroup -Filter "Name -eq '$nomGroupe'" -ErrorAction SilentlyContinue) {
                    Write-Host "⚠️ Le groupe '$nomGroupe' existe déjà." -ForegroundColor Yellow
                }
                else {
                    try {
                        New-ADGroup -Name $nomGroupe `
                            -GroupScope $perimetre `
                            -GroupCategory $typeGroupe `
                            -Path $ou `
                            -Description "Groupe $typeGroupe créé automatiquement"

                        Write-Host "✅ Groupe '$nomGroupe' créé avec succès." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "❌ Erreur lors de la création : $_" -ForegroundColor Red
                    }
                }

                $reponse = Read-Host "Créer un autre groupe ? (o/n)"
            } while ($reponse -eq 'o' -or $reponse -eq 'O') #cloture de la condition creation de groupe
        } #cloture de la condition creation de groupe

        elseif ($conf_grp -eq 2) {  #debut de la condition suppresion de groupe

            do { #debut de la boucle suppresion de groupe
                $nomGroupe = Read-Host "`nNom du groupe à supprimer"

                $groupe = Get-ADGroup -Filter "Name -eq '$nomGroupe'" -ErrorAction SilentlyContinue #n'affiche pas l'erreur a l'ecran et continu le script malgre l'erreur
                if ($null -eq $groupe) {
                    Write-Host "❌ Le groupe '$nomGroupe' n'existe pas." -ForegroundColor Red
                    continue
                }

                $confirm = Read-Host "Voulez-vous vraiment supprimer '$nomGroupe' ? (o/n)"
                if ($confirm -eq 'o' -or $confirm -eq 'O') {
                    try {
                        Remove-ADGroup -Identity $groupe -Confirm:$false
                        Write-Host "🗑️ Groupe '$nomGroupe' supprimé." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "❌ Erreur lors de la suppression : $_" -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "Suppression annulée." -ForegroundColor Yellow
                }

                $reponse = Read-Host "Supprimer un autre groupe ? (o/n)"
            } while ($reponse -eq 'o' -or $reponse -eq 'O') #cloture de la boucle suppresion de groupe
        }#cloture de la condition suppresion de groupe

        elseif ($conf_grp -eq 3) {
            break  # retour au menu principal
        }

        else {
            Write-Host "❌ Erreur : choix incorrect. Veuillez recommencer." -ForegroundColor Red
            $conf_grp = 0  # forcer à recommencer
        }
    }  # cloture de la boucle configuration de groupe
} # cloture de la condition gestion de groupe
##################################################################################################################################
    
    elseif ($var -eq "4") { #debut de la condition quitter
    Write-Host "`n👍 Fin du script. Au revoir !`n" -ForegroundColor Green
    exit
    } #cloture de la condition quitter
##################################################################################################################################    
    
    else { #condition final de la boucle  gestion d'objet
    write-host " erreur de lecture"
    }
}#cloture de la boucle gestion d'objet