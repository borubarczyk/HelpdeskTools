# Przestrzenie robocze: lokalne Active Directory - użytkownicy, komputery, grupy (moduł ActiveDirectory z RSAT)

#region Użytkownicy AD
Register-HTWorkspace -Key 'ADUsers' -Title 'Użytkownicy AD' -Icon 'E77B' -Panel 'adusers' -Service 'AD' `
    -Description 'Konta lokalnego Active Directory: hasła i blokady, źródło blokady, grupy, nowe konta, raporty, synchronizacja z Entra' `
    -Categories @('Konto', 'Hasło i blokady', 'Grupy', 'Cykl życia', 'Raporty')

$panel = New-HTTargetPanel -Key 'adusers' -Title 'Użytkownicy AD' -Placeholder 'Szukaj (nazwa, login, dział, e-mail)…' -EmptyIcon 'E77B' `
    -EmptyText 'Kliknij «Wczytaj», aby pobrać konta z domeny.' -Describe {
    param($u)
    $state = if ($u.LockedOut) { ' • ZABLOKOWANE' } elseif (-not $u.Enabled) { ' • wyłączone' } elseif ($u.PasswordExpired) { ' • hasło wygasło' } else { '' }
    @{ Key = [string]$u.ObjectGUID; Title = $(if ($u.DisplayName) { $u.DisplayName } else { $u.Name }); Sub = "$($u.SamAccountName)$(if ($u.Department) { " • $($u.Department)" })$state"
        Dot = $(if ($u.LockedOut) { 'crit' } elseif (-not $u.Enabled) { 'off' } elseif ($u.PasswordExpired) { 'warn' } else { 'ok' })
        Search = "$($u.UserPrincipalName) $($u.EmailAddress) $($u.Title) $(if ($u.LockedOut) { 'zablokowane' }) $(if (-not $u.Enabled) { 'wyłączone' })" }
}
Add-HTPanelLoader -Panel $panel -Service 'AD' -Loader { param($p) Get-HTADObjectList -Section 'User' } | Out-Null
Add-HTPanelHint -Panel $panel -Text 'Kropka: czerwona - zablokowane, szara - wyłączone, żółta - hasło wygasło. Wpisz «zablokowane», aby odfiltrować.' | Out-Null

function Get-HTADLabel { param($o) if ($o.SamAccountName) { [string]$o.SamAccountName } else { [string]$o.Name } }

function Update-HTADPanelObject {
    param([string]$Panel, [Parameter(Mandatory)][object]$Object, [hashtable]$Changes = @{})
    foreach ($k in $Changes.Keys) { $Object.$k = $Changes[$k] }
    $p = Get-HTPanel $Panel
    if ($p) { Update-HTTargetItem -Panel $p -Item $Object }
}

Register-HTModule -Workspace 'ADUsers' -Category 'Konto' -Key 'adu.details' -Title 'Szczegóły konta' -Icon 'E8A1' `
    -Description 'Atrybuty konta, stan hasła, profil, lokalizacja w drzewie (OU) i członkostwo w grupach.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż szczegóły' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Szczegóły konta AD' -Label { param($t) Get-HTADLabel $t } -Action { param($t) ConvertTo-HTDetailRows -Data (Get-HTADObjectDetail -Section 'User' -Identity $t.ObjectGUID) }
    } | Out-Null
}

Register-HTModule -Workspace 'ADUsers' -Category 'Konto' -Key 'adu.state' -Title 'Stan konta' -Icon 'E7E8' `
    -Description 'Włączenie, wyłączenie, data wygaśnięcia konta, przeniesienie do innej OU i usunięcie.' -Build {
    param($m)
    Add-HTStateCheck -Module $m -Label { param($t) Get-HTADLabel $t } -Action {
        param($t)
        Select-HTDetailFields -Detail (Get-HTADObjectDetail -Section 'User' -Identity $t.ObjectGUID) -Fields 'Nazwa', 'Włączone', 'Zablokowane', 'Wygaśnięcie konta', 'Ostatnie logowanie', @{ Name = 'DN'; Label = 'Lokalizacja (DN)' }
    } | Out-Null
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Włącz' -Icon 'E73E' -Primary -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Włączenie konta' -Label { param($t) Get-HTADLabel $t } -Action { param($t) Set-HTADAccountState -Identity $t.ObjectGUID -State Enable; Update-HTADPanelObject -Panel 'adusers' -Object $t -Changes @{ Enabled = $true }; 'Włączone' }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Wyłącz' -Icon 'E711' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Wyłączenie konta' -Danger -Confirm 'Wyłączyć wybrane konta?' -Label { param($t) Get-HTADLabel $t } -Action { param($t) Set-HTADAccountState -Identity $t.ObjectGUID -State Disable; Update-HTADPanelObject -Panel 'adusers' -Object $t -Changes @{ Enabled = $false }; 'Wyłączone' }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Data wygaśnięcia…' -Icon 'E787' -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $form = Show-HTFormDialog -Title 'Wygaśnięcie konta' -Description "Konta: $($targets.Count)" -Icon 'E787' -Fields @(
            @{ Name = 'Date'; Label = 'Konto wygasa (puste = nigdy)'; Type = 'Date'; DateOnly = $true; Optional = $true }
        )
        if (-not $form) { return }
        Invoke-HTTargetAction -Module $m -Name 'Data wygaśnięcia' -Targets $targets -Label { param($t) Get-HTADLabel $t } -Action {
            param($t)
            Set-HTADAccountExpiration -Identity $t.ObjectGUID -Date $form.Date
            if ($form.Date) { "Wygasa: $($form.Date.ToString('yyyy-MM-dd'))" } else { 'Nigdy nie wygasa' }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Przenieś do OU…' -Icon 'E8DE' -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $ou = Select-HTADOrganizationalUnit
        if (-not $ou) { return }
        Invoke-HTTargetAction -Module $m -Name 'Przeniesienie do OU' -Targets $targets -Confirm "Przenieść do $($ou.CanonicalName)?" -Label { param($t) Get-HTADLabel $t } -Action { param($t) Move-HTADObject -Identity $t.ObjectGUID -TargetPath $ou.DistinguishedName; "Do: $($ou.CanonicalName)" }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Usuń konto' -Icon 'E74D' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie konta' -Danger -TypeToConfirm 'USUŃ' -Confirm 'Usunąć wybrane konta z Active Directory? (bez kosza AD operacji nie można cofnąć)' -Label { param($t) Get-HTADLabel $t } -Action {
            param($t)
            Remove-HTADObject -Section 'User' -Identity $t.ObjectGUID
            Remove-HTTargetItem -Panel (Get-HTPanel 'adusers') -Item $t
            'Usunięto'
        }
    } | Out-Null
}

Register-HTModule -Workspace 'ADUsers' -Category 'Konto' -Key 'adu.edit' -Title 'Edycja atrybutów' -Icon 'E70F' `
    -Description 'Nazwa wyświetlana, stanowisko, dział, telefony, opis, przełożony; profil (ścieżka, skrypt logowania, katalog domowy). Dla wielu kont - tylko wypełnione pola.' -Build {
    param($m)
    Add-HTStateCheck -Module $m -Label { param($t) Get-HTADLabel $t } -Action {
        param($t)
        Select-HTDetailFields -Detail (Get-HTADObjectDetail -Section 'User' -Identity $t.ObjectGUID) -Fields 'Nazwa wyświetlana', 'Stanowisko', 'Dział', 'Firma', 'Biuro', 'Telefon', 'Komórka', 'Przełożony', 'Opis', 'Ścieżka profilu', 'Skrypt logowania', 'Katalog domowy', 'Dysk domowy'
    } | Out-Null
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Edytuj atrybuty…' -Icon 'E70F' -Primary -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $single = $targets.Count -eq 1
        $u = if ($single) { Get-ADUser -Identity $targets[0].ObjectGUID -Properties DisplayName, Title, Department, Company, Office, OfficePhone, MobilePhone, EmailAddress, Description, Manager } else { $null }
        $names = [ordered]@{ DisplayName = 'Nazwa wyświetlana'; Title = 'Stanowisko'; Department = 'Dział'; Company = 'Firma'; Office = 'Biuro'; OfficePhone = 'Telefon'; MobilePhone = 'Komórka'; EmailAddress = 'E-mail'; Description = 'Opis'; Manager = 'Przełożony (login)' }
        $fields = @()
        if (-not $single) { $fields += @{ Type = 'Info'; Label = "Zmiana dla $($targets.Count) kont - wypełnij tylko pola do ustawienia." } }
        foreach ($k in $names.Keys) {
            if (-not $single -and $k -in 'DisplayName', 'OfficePhone', 'MobilePhone', 'EmailAddress') { continue }
            $value = if ($u) { if ($k -eq 'Manager') { if ($u.Manager) { (Get-ADUser -Identity $u.Manager).SamAccountName } } else { $u.$k } } else { '' }
            $fields += @{ Name = $k; Label = $names[$k]; Default = $value }
        }
        $result = Show-HTFormDialog -Title 'Atrybuty konta' -Description $(if ($single) { Get-HTADLabel $targets[0] } else { "$($targets.Count) kont" }) -Fields $fields -Icon 'E70F'
        if (-not $result) { return }
        $changes = @{}
        foreach ($k in $result.Keys) {
            $new = [string]$result[$k]
            $old = if ($single) { [string]($fields | Where-Object { $_.Name -eq $k }).Default } else { '' }
            if (($single -and $new -ne $old) -or (-not $single -and $new)) {
                $changes[$k] = if ($k -eq 'Manager' -and $new) { (Resolve-HTADUser -Identity $new).DistinguishedName } else { $new }
            }
        }
        if ($changes.Count -eq 0) { Show-HTToast 'Brak zmian.' 'info'; return }
        Invoke-HTTargetAction -Module $m -Name 'Zmiana atrybutów' -Summary @(ConvertTo-HTChangeSummary -Settings $changes) -Targets $targets -Label { param($t) Get-HTADLabel $t } -Action { param($t) Set-HTADUserAttributes -Identity $t.ObjectGUID -Attributes $changes; "Zmieniono: $(@($changes.Keys) -join ', ')" }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Profil i katalog domowy…' -Icon 'E8B7' -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $u = if ($targets.Count -eq 1) { Get-ADUser -Identity $targets[0].ObjectGUID -Properties ProfilePath, ScriptPath, HomeDirectory, HomeDrive } else { $null }
        $form = Show-HTFormDialog -Title 'Profil użytkownika' -Description 'Zmienna %username% zostanie zastąpiona loginem każdego konta.' -Icon 'E8B7' -Fields @(
            @{ Name = 'ProfilePath'; Label = 'Ścieżka profilu'; Default = $u.ProfilePath; Placeholder = '\\serwer\profile$\%username%' }
            @{ Name = 'ScriptPath'; Label = 'Skrypt logowania'; Default = $u.ScriptPath }
            @{ Name = 'HomeDirectory'; Label = 'Katalog domowy'; Default = $u.HomeDirectory; Placeholder = '\\serwer\home$\%username%' }
            @{ Name = 'HomeDrive'; Label = 'Litera dysku'; Type = 'Combo'; Editable = $true; Options = @('', 'H:', 'U:', 'P:', 'Z:'); Default = $u.HomeDrive }
        )
        if (-not $form) { return }
        Invoke-HTTargetAction -Module $m -Name 'Profil użytkownika' -Targets $targets -Label { param($t) Get-HTADLabel $t } -Action {
            param($t)
            $values = @{}
            foreach ($k in $form.Keys) { $values[$k] = ([string]$form[$k]) -replace '%username%', $t.SamAccountName }
            Set-HTADUserProfile -Identity $t.ObjectGUID @values
            'Zapisano'
        }
    } | Out-Null
}

Register-HTModule -Workspace 'ADUsers' -Category 'Hasło i blokady' -Key 'adu.password' -Title 'Reset hasła' -Icon 'E8D7' `
    -Description 'Losowe lub podane hasło, wymuszenie zmiany przy logowaniu, odblokowanie. Także: «hasło nigdy nie wygasa» i wymuszenie zmiany hasła.' -Build {
    param($m)
    Add-HTStateCheck -Module $m -Label { param($t) Get-HTADLabel $t } -Action {
        param($t)
        Select-HTDetailFields -Detail (Get-HTADObjectDetail -Section 'User' -Identity $t.ObjectGUID) -Fields 'Włączone', 'Zablokowane', 'Hasło ustawione', 'Hasło nigdy nie wygasa', 'Zmiana hasła przy logowaniu', 'Błędne logowania', 'Ostatnie logowanie'
    } | Out-Null
    $m.SecretColumns = @('Hasło')
    $row = Add-HTToolbarRow -Module $m -Title 'Opcje'
    $m.C.Mode = Add-HTSegmented -Parent $row -Items @('Losowe hasła', 'Podane hasło')
    Add-HTLabel -Parent $row -Text 'Długość:' | Out-Null
    $m.C.Length = Add-HTNumeric -Parent $row -Value ([Math]::Max(8, [int]$Global:PasswordDefaultLength)) -Minimum 8 -Maximum 64
    $m.C.Change = Add-HTCheckBox -Parent $row -Text 'Zmiana przy logowaniu' -Checked $true
    $m.C.Unlock = Add-HTCheckBox -Parent $row -Text 'Odblokuj konto' -Checked $true
    $actions = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $actions -Module $m -Text 'Resetuj hasło' -Icon 'E8D7' -Primary -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $fixed = $null
        if ((Get-HTSegmentIndex $m.C.Mode) -eq 1) {
            $fixed = Show-InputBox -Title 'Nowe hasło' -Prompt 'Hasło dla wybranych kont:' -Password -Icon 'E8D7'
            if (-not $fixed) { return }
        }
        $length = Get-HTNum $m.C.Length
        $change = Test-HTChecked $m.C.Change
        $unlock = Test-HTChecked $m.C.Unlock
        Invoke-HTTargetAction -Module $m -Name 'Reset hasła AD' -Targets $targets -Confirm "Zresetować hasło $($targets.Count) kont?" -Label { param($t) Get-HTADLabel $t } -Action {
            param($t)
            $password = if ($fixed) { $fixed } else { New-HTRandomPassword -Length $length }
            Reset-HTADUserPassword -Identity $t.ObjectGUID -Password $password -ChangeAtLogon $change -Unlock $unlock
            if ($unlock) { Update-HTADPanelObject -Panel 'adusers' -Object $t -Changes @{ LockedOut = $false; PasswordExpired = $false } }
            @{ Hasło = $password; Szczegóły = $(if ($change) { 'Zmiana przy logowaniu' } else { 'Hasło stałe' }) }
        }
    } | Out-Null
    Add-HTButton -Parent $actions -Module $m -Text 'Kopiuj hasła' -Icon 'E8C8' -OnClick {
        param($m)
        $rows = @(Get-HTResultSelection -Module $m -AllVisible | Where-Object { $_.Hasło })
        if ($rows.Count -eq 0) { return }
        Set-HTClipboard -Text (($rows | ForEach-Object { "$($_.Obiekt)`t$($_.Hasło)" }) -join "`r`n") -Secret
        Show-HTToast "Skopiowano hasła: $($rows.Count) (schowek zostanie wyczyszczony po 60 s)." 'ok'
    } | Out-Null
    $row3 = Add-HTToolbarRow -Module $m -Title 'Zasady hasła'
    Add-HTButton -Parent $row3 -Module $m -Text 'Wymuś zmianę przy logowaniu' -Icon 'E8D7' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Wymuszenie zmiany hasła' -Label { param($t) Get-HTADLabel $t } -Action { param($t) Set-HTADChangePasswordAtLogon -Identity $t.ObjectGUID -Value $true; 'Zmiana przy następnym logowaniu' }
    } | Out-Null
    Add-HTButton -Parent $row3 -Module $m -Text 'Hasło nigdy nie wygasa' -Icon 'E916' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Hasło nigdy nie wygasa' -Confirm 'Ustawić «hasło nigdy nie wygasa»? (niezalecane dla kont użytkowników)' -Label { param($t) Get-HTADLabel $t } -Action { param($t) Set-HTADPasswordNeverExpires -Identity $t.ObjectGUID -Value $true; 'Włączono' }
    } | Out-Null
    Add-HTButton -Parent $row3 -Module $m -Text 'Hasło wygasa normalnie' -Icon 'E777' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Wygasanie hasła' -Label { param($t) Get-HTADLabel $t } -Action { param($t) Set-HTADPasswordNeverExpires -Identity $t.ObjectGUID -Value $false; 'Hasło wygasa zgodnie z zasadami' }
    } | Out-Null
}

Register-HTModule -Workspace 'ADUsers' -Category 'Hasło i blokady' -Key 'adu.lockout' -Title 'Blokady kont' -Icon 'E72E' `
    -Description 'Odblokowanie, stan na każdym kontrolerze domeny (błędne hasła) i źródło blokady - komputer, z którego przychodzą błędne hasła (zdarzenie 4740 z PDC).' -Build {
    param($m)
    Add-HTStateCheck -Module $m -Label { param($t) Get-HTADLabel $t } -Action {
        param($t)
        Select-HTDetailFields -Detail (Get-HTADObjectDetail -Section 'User' -Identity $t.ObjectGUID) -Fields 'Włączone', 'Zablokowane', 'Błędne logowania', 'Hasło ustawione', 'Ostatnie logowanie'
    } | Out-Null
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Odblokuj' -Icon 'E785' -Primary -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Odblokowanie konta' -Label { param($t) Get-HTADLabel $t } -Action { param($t) Set-HTADAccountState -Identity $t.ObjectGUID -State Unlock; Update-HTADPanelObject -Panel 'adusers' -Object $t -Changes @{ LockedOut = $false }; 'Odblokowane' }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Stan na kontrolerach' -Icon 'E968' -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Stan blokady na kontrolerach' -AlwaysShowObject -Label { param($t) Get-HTADLabel $t } -Action { param($t) Get-HTADLockoutStatus -Identity $t.ObjectGUID }
    } | Out-Null
    Add-HTLabel -Parent $row -Text 'Ostatnie godziny:' | Out-Null
    $m.C.Hours = Add-HTNumeric -Parent $row -Value 24 -Minimum 1 -Maximum 720
    Add-HTButton -Parent $row -Module $m -Text 'Źródło blokady' -Icon 'E721' -ToolTip 'Zdarzenia 4740 z dziennika Security emulatora PDC (zaznaczone konta albo wszystkie, gdy nic nie zaznaczono)' -OnClick {
        param($m)
        $hours = Get-HTNum $m.C.Hours
        $names = @(Get-HTTargets -Module $m -Quiet | ForEach-Object { $_.SamAccountName })
        Invoke-HTQuery -Module $m -Name 'Źródło blokad' -ScriptBlock {
            $events = @(Get-HTADLockoutEvents -SamAccountName $names -Hours $hours)
            if ($events.Count -eq 0) { [PSCustomObject]@{ Wynik = "Brak zdarzeń blokady w ciągu $hours h."; __flag = 'muted' } }
            $events
        }
    } | Out-Null
}

Register-HTModule -Workspace 'ADUsers' -Category 'Grupy' -Key 'adu.groups' -Title 'Grupy użytkownika' -Icon 'E902' `
    -Description 'Członkostwo w grupach, dodawanie do grup, kopiowanie grup z konta wzorcowego. Prawy przycisk - usunięcie z grupy.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż grupy' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Grupy użytkowników' -AlwaysShowObject -Label { param($t) Get-HTADLabel $t } -Action {
            param($t)
            foreach ($g in @(Get-HTADObjectGroups -DistinguishedName $t.DistinguishedName)) { [PSCustomObject]@{ Grupa = $g.Name; DN = $g.DistinguishedName } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Dodaj do grup…' -Icon 'E710' -Create -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $groups = @(Select-HTADGroups -Prompt "Grupy dla $($targets.Count) kont.")
        if ($groups.Count -eq 0) { return }
        Invoke-HTTargetAction -Module $m -Name 'Dodanie do grup' -Summary "Grupy ($($groups.Count)): $(@($groups | ForEach-Object { $_.Name }) -join ', ')" -Targets $targets -Label { param($t) Get-HTADLabel $t } -Action {
            param($t)
            foreach ($g in $groups) { Add-HTADGroupMember -Group $g.DistinguishedName -Members @([string]$t.ObjectGUID) }
            "Dodano do: $(@($groups | ForEach-Object { $_.Name }) -join ', ')"
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Kopiuj grupy od…' -Icon 'E8C8' -Create -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $source = Select-HTADUser -Title 'Konto wzorcowe' -Prompt 'Grupy tego konta zostaną skopiowane.'
        if (-not $source) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Kopiowanie grup')) { return }
        if (-not (Confirm-HTChange -Name 'Kopiowanie grup' -Labels @($targets | ForEach-Object { Get-HTADLabel $_ }) -Summary "Wzorzec: $(Get-HTADLabel $source) - konta zostaną dodane do jego grup" -Confirm 'Dodać konta do grup konta wzorcowego?')) { return }
        Reset-HTResults -Module $m
        Invoke-HTQuery -Module $m -Name "Kopiowanie grup od $($source.SamAccountName)" -KeepResults -Record Change -ScriptBlock {
            foreach ($t in $targets) {
                foreach ($r in @(Copy-HTADGroupMembership -SourceIdentity $source.ObjectGUID -TargetIdentity $t.ObjectGUID)) {
                    [PSCustomObject]@{ Obiekt = $t.SamAccountName; Grupa = $r.Grupa; Status = $r.Status; Szczegóły = $r.Szczegóły }
                }
            }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń z grupy' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie z grupy' -Rows @($rows | Where-Object { $_.DN }) -Confirm 'Usunąć użytkowników z zaznaczonych grup?' -Label { param($r) "$($r.Obiekt): $($r.Grupa)" } `
            -Action { param($r) Remove-HTADGroupMember -Group $r.DN -Members @([string]$r.__target.ObjectGUID) } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'ADUsers' -Category 'Cykl życia' -Key 'adu.new' -Title 'Nowy użytkownik' -Icon 'E8FA' -Service 'AD' `
    -Description 'Konto z loginem utworzonym z imienia i nazwiska (bez polskich znaków), losowym hasłem, w wybranej OU; grupy z konta wzorcowego.' -Build {
    param($m)
    $m.SecretColumns = @('Hasło')
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz użytkownika…' -Create -NoRowMenu -Icon 'E8FA' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'AD')) { return }
        $suffixes = @(Get-HTADUpnSuffixes)
        $form = Show-HTFormDialog -Title 'Nowy użytkownik AD' -Icon 'E8FA' -OkText 'Dalej' -Fields @(
            @{ Name = 'Given'; Label = 'Imię'; Required = $true }
            @{ Name = 'Surname'; Label = 'Nazwisko'; Required = $true }
            @{ Name = 'Login'; Label = 'Login (puste = imie.nazwisko)' }
            @{ Name = 'Suffix'; Label = 'Sufiks UPN'; Type = 'Combo'; Options = $suffixes }
            @{ Name = 'Title'; Label = 'Stanowisko' }
            @{ Name = 'Department'; Label = 'Dział' }
            @{ Name = 'Ou'; Label = 'Wybierz OU (po kliknięciu «Dalej»)'; Type = 'Check'; Default = $true }
            @{ Name = 'Template'; Label = 'Skopiuj grupy z konta wzorcowego'; Type = 'Check' }
            @{ Name = 'Change'; Label = 'Zmiana hasła przy pierwszym logowaniu'; Type = 'Check'; Default = $true }
        )
        if (-not $form) { return }
        $login = if ($form.Login) { $form.Login } else { New-HTADLoginName -GivenName $form.Given -Surname $form.Surname }
        $ou = if ($form.Ou) { Select-HTADOrganizationalUnit -Title 'OU nowego konta' } else { $null }
        if ($form.Ou -and -not $ou) { return }
        $template = if ($form.Template) { Select-HTADUser -Title 'Konto wzorcowe' } else { $null }
        if (@(Get-ADUser -Filter "SamAccountName -eq '$($login.Replace("'", "''"))'" -ErrorAction SilentlyContinue).Count -gt 0) { Show-HTWarning "Login $login jest już zajęty."; return }
        $extra = @(if ($ou) { "OU: $($ou.Name)" }; if ($template) { "Grupy z konta wzorcowego: $(Get-HTADLabel $template)" })
        if (-not (Confirm-HTChange -Name 'Tworzenie konta AD' -Labels @($login) -Summary (@(Get-HTPendingFormSummary) + $extra) -Confirm "Utworzyć konto $($login)? Hasło zostanie wygenerowane.")) { return }
        Invoke-HTQuery -Module $m -Name 'Tworzenie konta AD' -KeepResults -Record Change -ScriptBlock {
            $password = New-HTRandomPassword
            $user = New-HTADUser -GivenName $form.Given -Surname $form.Surname -SamAccountName $login -UserPrincipalName "$login@$($form.Suffix)" -Password $password `
                -Path $(if ($ou) { $ou.DistinguishedName }) -Title $form.Title -Department $form.Department -ChangeAtLogon $form.Change
            $notes = @("Utworzono w $(if ($ou) { $ou.CanonicalName } else { 'kontenerze domyślnym' })")
            if ($template) {
                $copied = @(Copy-HTADGroupMembership -SourceIdentity $template.ObjectGUID -TargetIdentity $user.ObjectGUID)
                $notes += "grupy: $(@($copied | Where-Object Status -eq 'OK').Count)"
            }
            Write-Log -Message "Utworzono konto AD: $login" -Type 'Info&Notification'
            [PSCustomObject]@{ Obiekt = $login; UPN = "$login@$($form.Suffix)"; Status = 'OK'; Hasło = $password; Szczegóły = ($notes -join '; ') }
        }
        $p = Get-HTPanel 'adusers'
        if ($p) { Invoke-HTPanelLoad -Panel $p -Quiet }
    } | Out-Null
}

Register-HTModule -Workspace 'ADUsers' -Category 'Cykl życia' -Key 'adu.offboard' -Title 'Odejście pracownika' -Icon 'E8F8' `
    -Description 'Wyłączenie konta, losowe hasło, usunięcie z grup, opis z datą i przeniesienie do OU dla kont wyłączonych.' -Build {
    param($m)
    Add-HTStateCheck -Module $m -Label { param($t) Get-HTADLabel $t } -Action {
        param($t)
        Select-HTDetailFields -Detail (Get-HTADObjectDetail -Section 'User' -Identity $t.ObjectGUID) -Fields 'Nazwa', 'Włączone', 'Opis', 'Ostatnie logowanie', @{ Name = 'Członkostwo'; Label = 'Grupy' }, @{ Name = 'DN'; Label = 'Lokalizacja (DN)' }
    } | Out-Null
    $m.SecretColumns = @('Hasło')
    $row = Add-HTToolbarRow -Module $m -Title 'Kroki'
    $m.C.Disable = Add-HTCheckBox -Parent $row -Text 'Wyłącz konto' -Checked $true
    $m.C.Password = Add-HTCheckBox -Parent $row -Text 'Losowe hasło' -Checked $true
    $m.C.Groups = Add-HTCheckBox -Parent $row -Text 'Usuń z grup' -Checked $true
    $m.C.Describe = Add-HTCheckBox -Parent $row -Text 'Opis «Wyłączone RRRR-MM-DD»' -Checked $true
    $m.C.Move = Add-HTCheckBox -Parent $row -Text 'Przenieś do OU (wybór)' -Checked $false
    $actions = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $actions -Module $m -Text 'Wykonaj' -Icon 'E8F8' -Primary -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $o = @{}
        foreach ($k in 'Disable', 'Password', 'Groups', 'Describe', 'Move') { $o[$k] = Test-HTChecked $m.C[$k] }
        $ou = if ($o.Move) { Select-HTADOrganizationalUnit -Title 'OU kont wyłączonych' } else { $null }
        if ($o.Move -and -not $ou) { return }
        $steps = @(
            if ($o.Disable) { 'Wyłączenie konta' }
            if ($o.Password) { 'Losowe hasło (zmiana przy logowaniu)' }
            if ($o.Groups) { 'Usunięcie ze wszystkich grup' }
            if ($o.Describe) { "Opis: Wyłączone $(Get-Date -Format 'yyyy-MM-dd')" }
            if ($ou) { "Przeniesienie do OU: $($ou.Name)" }
        )
        if ($steps.Count -eq 0) { Show-HTWarning 'Zaznacz co najmniej jeden krok.'; return }
        Invoke-HTTargetAction -Module $m -Name 'Odejście pracownika' -Danger -TypeToConfirm 'OFFBOARDING' -Confirm 'Wykonać wybrane kroki dla kont?' -Summary $steps -Targets $targets -Label { param($t) Get-HTADLabel $t } -Action {
            param($t)
            $done = @()
            $result = @{}
            if ($o.Password) { $pw = New-HTRandomPassword; Reset-HTADUserPassword -Identity $t.ObjectGUID -Password $pw -ChangeAtLogon $true -Unlock $false; $result['Hasło'] = $pw; $done += 'hasło' }
            if ($o.Disable) { Set-HTADAccountState -Identity $t.ObjectGUID -State Disable; Update-HTADPanelObject -Panel 'adusers' -Object $t -Changes @{ Enabled = $false }; $done += 'wyłączone' }
            if ($o.Groups) { $removed = @(Remove-HTADAllGroupMembership -Identity $t.ObjectGUID); $done += "grupy: $($removed.Count)" }
            if ($o.Describe) { Set-HTADUserAttributes -Identity $t.ObjectGUID -Attributes @{ Description = "Wyłączone $(Get-Date -Format 'yyyy-MM-dd') ($env:USERNAME)" }; $done += 'opis' }
            if ($ou) { Move-HTADObject -Identity $t.ObjectGUID -TargetPath $ou.DistinguishedName; $done += "OU: $($ou.Name)" }
            $result['Szczegóły'] = $done -join ', '
            $result
        }
    } | Out-Null
    Add-HTLabel -Parent $actions -Hint -Text 'Konto w Microsoft 365 (licencje, skrzynka) - moduł Offboarding w przestrzeni Microsoft 365.' | Out-Null
}

Register-HTModule -Workspace 'ADUsers' -Category 'Cykl życia' -Key 'adu.sync' -Title 'Synchronizacja Entra Connect' -Icon 'E895' -Service '' `
    -Description 'Uruchamia synchronizację delta na serwerze Microsoft Entra Connect - zmiany z AD trafiają do Microsoft 365 od razu, bez czekania 30 minut.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Serwer'
    $m.C.Server = Add-HTTextBox -Parent $row -Width 240 -Text "$($Global:AadSyncServer)" -Placeholder 'np. srv-sync01'
    $m.C.Type = Add-HTSegmented -Parent $row -Items @('Delta', 'Pełna (Initial)')
    Add-HTButton -Parent $row -Module $m -Text 'Synchronizuj' -Icon 'E895' -Primary -Danger -NoRowMenu -OnClick {
        param($m)
        $server = $m.C.Server.Text.Trim()
        if (-not $server) { Show-HTWarning 'Podaj nazwę serwera Entra Connect (można ją zapisać w Ustawieniach).'; return }
        $type = if ((Get-HTSegmentIndex $m.C.Type) -eq 1) { 'Initial' } else { 'Delta' }
        if (-not (Confirm-HTChange -Name 'Synchronizacja Entra Connect' -Labels @($server) -Summary "Typ synchronizacji: $type" -Confirm $(if ($type -eq 'Initial') { 'Uruchomić pełną synchronizację? Może trwać długo.' } else { 'Uruchomić synchronizację zmian (delta)?' }))) { return }
        if ($server -ne $Global:AadSyncServer) { try { Set-HTConfigValue -Name 'AadSyncServer' -Value $server; $Global:AadSyncServer = $server } catch { Write-Verbose $_ } }
        Invoke-HTQuery -Module $m -Name 'Synchronizacja Entra Connect' -Service '' -KeepResults -ScriptBlock {
            $result = Start-HTEntraConnectSync -Server $server -PolicyType $type
            Write-Log -Message "Entra Connect ($server, $type): $result" -Type 'Info&Notification'
            [PSCustomObject]@{ Czas = Get-Date; Serwer = $server; Typ = $type; Wynik = $result }
        }
    } | Out-Null
}

function Register-HTADUserReport {
    param([string]$Key, [string]$Title, [string]$Icon, [string]$Type, [string]$Description, [string]$DaysLabel = '')
    $script:ADReportDefs[$Key] = @{ Type = $Type; DaysLabel = $DaysLabel }
    Register-HTModule -Workspace 'ADUsers' -Category 'Raporty' -Key $Key -Title $Title -Icon $Icon -Description $Description -Build {
        param($m)
        $def = $script:ADReportDefs[$m.Key]
        $m.Data.Type = $def.Type
        $row = Add-HTToolbarRow -Module $m
        if ($def.DaysLabel) {
            Add-HTLabel -Parent $row -Text $def.DaysLabel | Out-Null
            $m.C.Days = Add-HTNumeric -Parent $row -Value $(if ($def.Type -eq 'Inactive') { Get-HTInactiveDaysDefault } else { 14 }) -Minimum 1 -Maximum 3650
        }
        Add-HTButton -Parent $row -Module $m -Text 'Generuj raport' -Icon 'E9D2' -Primary -OnClick {
            param($m)
            $days = if ($m.C.Days) { Get-HTNum $m.C.Days } else { 90 }
            $type = $m.Data.Type
            Invoke-HTQuery -Module $m -Name $m.Title -ScriptBlock { Get-HTADUserReport -Type $type -Days $days }
        } | Out-Null
        Add-HTRowAction -Module $m -Text 'Zaznacz na liście kont' -Icon 'E8B3' -Action {
            param($m, $rows)
            $p = Get-HTPanel 'adusers'
            if ($p.Table.Rows.Count -eq 0) { Invoke-HTPanelLoad -Panel $p }
            $ids = @($rows | ForEach-Object { [string]$_.ObjectGUID })
            foreach ($r in $p.Table.Rows) { if ($ids -contains [string]$r['Key']) { $r['Sel'] = $true } }
            Update-HTTargetCount $p
            Show-HTToast 'Zaznaczono konta na liście - wybierz akcję (np. Stan konta).' 'ok'
        }
        Add-HTRowAction -Module $m -Text 'Odblokuj' -Icon 'E785' -Danger -Action {
            param($m, $rows)
            Invoke-HTRowAction -Module $m -Name 'Odblokowanie konta' -Rows $rows -Label { param($r) $r.Login } -Action { param($r) Set-HTADAccountState -Identity $r.ObjectGUID -State Unlock }
        }
        Add-HTRowAction -Module $m -Text 'Wyłącz konto' -Icon 'E711' -Danger -Action {
            param($m, $rows)
            Invoke-HTRowAction -Module $m -Name 'Wyłączenie konta' -Rows $rows -Danger -Confirm 'Wyłączyć zaznaczone konta?' -Label { param($r) $r.Login } -Action { param($r) Set-HTADAccountState -Identity $r.ObjectGUID -State Disable }
        }
    }
}
$script:ADReportDefs = @{}

Register-HTADUserReport -Key 'adu.rep.inactive' -Title 'Nieaktywne konta' -Icon 'E916' -Type 'Inactive' -DaysLabel 'Bez logowania od (dni):' -Description 'Włączone konta bez logowania od wskazanej liczby dni (lastLogonTimestamp - dokładność ok. 14 dni).'
Register-HTADUserReport -Key 'adu.rep.never' -Title 'Nigdy nie zalogowane' -Icon 'E9CE' -Type 'NeverLoggedOn' -Description 'Włączone konta, które nigdy się nie zalogowały.'
Register-HTADUserReport -Key 'adu.rep.expiring' -Title 'Wygasające hasła' -Icon 'E823' -Type 'PasswordExpiring' -DaysLabel 'Wygasa w ciągu (dni):' -Description 'Hasła wygasające w najbliższych dniach - można uprzedzić użytkowników (czerwone - do 3 dni).'
Register-HTADUserReport -Key 'adu.rep.expired' -Title 'Wygasłe hasła' -Icon 'E7BA' -Type 'PasswordExpired' -Description 'Włączone konta z wygasłym hasłem.'
Register-HTADUserReport -Key 'adu.rep.locked' -Title 'Zablokowane konta' -Icon 'E72E' -Type 'Locked' -Description 'Konta zablokowane po błędnych hasłach. Prawy przycisk - odblokowanie.'
Register-HTADUserReport -Key 'adu.rep.disabled' -Title 'Wyłączone konta' -Icon 'E711' -Type 'Disabled' -Description 'Wyłączone konta (np. do usunięcia po okresie przechowywania).'
Register-HTADUserReport -Key 'adu.rep.neverexpires' -Title 'Hasło nie wygasa' -Icon 'E8D7' -Type 'PasswordNeverExpires' -Description 'Konta z ustawieniem «hasło nigdy nie wygasa» (audyt bezpieczeństwa).'
Register-HTADUserReport -Key 'adu.rep.accexpiring' -Title 'Wygasające konta' -Icon 'E787' -Type 'AccountExpiring' -DaysLabel 'Wygasa w ciągu (dni):' -Description 'Konta z ustawioną datą wygaśnięcia w najbliższych dniach (umowy terminowe, praktykanci).'
#endregion

#region Komputery AD
Register-HTWorkspace -Key 'ADComputers' -Title 'Komputery AD' -Icon 'E977' -Panel 'adcomputers' -Service 'AD' `
    -Description 'Komputery w domenie: dostępność, informacje systemowe, zalogowani użytkownicy, LAPS i BitLocker, raporty' `
    -Categories @('Komputer', 'Bezpieczeństwo', 'Zarządzanie', 'Raporty')

$panel = New-HTTargetPanel -Key 'adcomputers' -Title 'Komputery AD' -Placeholder 'Szukaj (nazwa, system, opis)…' -EmptyIcon 'E977' -EmptyText 'Kliknij «Wczytaj», aby pobrać komputery z domeny.' -Describe {
    param($c)
    $idle = Get-HTDaysSince $c.LastLogonDate
    @{ Key = [string]$c.ObjectGUID; Title = $c.Name; Sub = "$($c.OperatingSystem)$(if ($c.Description) { " • $($c.Description)" })"
        Dot = $(if (-not $c.Enabled) { 'off' } elseif ($null -eq $idle -or $idle -gt 90) { 'warn' } else { 'ok' })
        Search = "$($c.DNSHostName) $($c.DistinguishedName)" }
}
Add-HTPanelLoader -Panel $panel -Service 'AD' -Loader { param($p) Get-HTADObjectList -Section 'Computer' } | Out-Null
Add-HTPanelHint -Panel $panel -Text 'Kropka: żółta - brak logowania ponad 90 dni, szara - wyłączony.' | Out-Null

Register-HTModule -Workspace 'ADComputers' -Category 'Komputer' -Key 'adc.details' -Title 'Szczegóły' -Icon 'E8A1' -Description 'Atrybuty komputera w AD: system, adres IP, opis, ostatnie logowanie, grupy.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż szczegóły' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Szczegóły komputera' -Label { param($t) $t.Name } -Action { param($t) ConvertTo-HTDetailRows -Data (Get-HTADObjectDetail -Section 'Computer' -Identity $t.ObjectGUID) }
    } | Out-Null
}

Register-HTModule -Workspace 'ADComputers' -Category 'Komputer' -Key 'adc.ping' -Title 'Dostępność' -Icon 'E703' -Service '' -Description 'DNS i ping - czy komputer jest włączony i osiągalny w sieci.' -Build {
    param($m)
    $m.ColorBools = $true
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź' -Icon 'E703' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Dostępność' -Label { param($t) $t.Name } -Action {
            param($t)
            $r = Test-HTComputerReachable -ComputerName $(if ($t.DNSHostName) { $t.DNSHostName } else { $t.Name })
            [PSCustomObject][ordered]@{ Komputer = $t.Name; Status = $(if ($r['Odpowiada na ping']) { 'OK' } else { 'Brak odpowiedzi' }); 'Adresy IP' = $r['Adresy IP (DNS)']; Ping = $r['Odpowiada na ping']; 'Opóźnienie (ms)' = $r['Opóźnienie (ms)'] }
        }
    } | Out-Null
}

Register-HTModule -Workspace 'ADComputers' -Category 'Komputer' -Key 'adc.sysinfo' -Title 'Informacje systemowe' -Icon 'E770' -Service '' `
    -Description 'Zdalnie (CIM / WinRM): system i kompilacja, czas pracy, model, numer seryjny, pamięć, wolne miejsce na dyskach, zalogowany użytkownik.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz informacje' -Icon 'E770' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Informacje systemowe' -Service '' -Label { param($t) $t.Name } -Action { param($t) ConvertTo-HTDetailRows -Data (Get-HTComputerSystemInfo -ComputerName $(if ($t.DNSHostName) { $t.DNSHostName } else { $t.Name })) }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Zalogowani użytkownicy' -Icon 'E77B' -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Zalogowani użytkownicy' -Service '' -AlwaysShowObject -Label { param($t) $t.Name } -Action {
            param($t)
            $users = @(Get-HTLoggedOnUsers -ComputerName $(if ($t.DNSHostName) { $t.DNSHostName } else { $t.Name }))
            if ($users.Count -eq 0) { return [PSCustomObject]@{ Użytkownik = '(nikt nie jest zalogowany)'; __flag = 'muted' } }
            foreach ($u in $users) { [PSCustomObject]@{ Użytkownik = $u } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Pulpit zdalny' -Icon 'E7F4' -OnClick {
        param($m)
        $t = @(Get-HTTargets -Module $m -Single)[0]
        if ($t) { Start-Process 'mstsc.exe' -ArgumentList "/v:$(if ($t.DNSHostName) { $t.DNSHostName } else { $t.Name })" }
    } | Out-Null
}

Register-HTModule -Workspace 'ADComputers' -Category 'Bezpieczeństwo' -Key 'adc.secrets' -Title 'LAPS i BitLocker' -Icon 'E8D7' -Description 'Hasło lokalnego administratora (Windows LAPS / Microsoft LAPS) i klucze odzyskiwania BitLocker zapisane w AD.' -Build {
    param($m)
    $m.SecretColumns = @('Hasło', 'Klucz odzyskiwania')
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Hasło LAPS' -Icon 'E7EF' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Hasła LAPS' -AlwaysShowObject -Label { param($t) $t.Name } -Action {
            param($t)
            $laps = Get-HTADLapsPassword -ComputerName $t.Name
            if (-not $laps) { return [PSCustomObject]@{ Konto = '(brak hasła LAPS lub uprawnień)'; __flag = 'muted' } }
            [PSCustomObject]@{ Konto = $laps.Account; Hasło = $laps.Password; Zmieniono = $laps.Updated; Wygasa = $laps.Expiration; Źródło = $laps.Source }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Klucze BitLocker' -Icon 'E8D7' -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Klucze BitLocker' -AlwaysShowObject -Label { param($t) $t.Name } -Action {
            param($t)
            $keys = @(Get-HTADBitLockerKeys -ComputerName $t.Name)
            if ($keys.Count -eq 0) { return [PSCustomObject]@{ 'ID klucza' = '(brak kluczy w AD)'; __flag = 'muted' } }
            foreach ($k in $keys) { [PSCustomObject]@{ 'ID klucza' = $k.KeyId; Utworzono = $k.Created; 'Klucz odzyskiwania' = $k.RecoveryPassword } }
        }
    } | Out-Null
}

Register-HTModule -Workspace 'ADComputers' -Category 'Zarządzanie' -Key 'adc.manage' -Title 'Zarządzanie' -Icon 'E713' -Description 'Opis komputera, włączenie / wyłączenie konta, przeniesienie do OU, zdalny restart i usunięcie z domeny.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Opis'
    $m.C.Description = Add-HTTextBox -Parent $row -Width 320 -Placeholder 'np. Jan Kowalski, pokój 12'
    Add-HTButton -Parent $row -Module $m -Text 'Ustaw opis' -Icon 'E70F' -Primary -Danger -OnClick {
        param($m)
        $text = $m.C.Description.Text.Trim()
        Invoke-HTTargetAction -Module $m -Name 'Opis komputera' -Summary "Opis: $(if ($text) { $text } else { '(wyczyść)' })" -Label { param($t) $t.Name } -Action { param($t) Set-HTADComputerDescription -Identity $t.ObjectGUID -Description $text; Update-HTADPanelObject -Panel 'adcomputers' -Object $t -Changes @{ Description = $text }; 'Zapisano' }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Konto'
    Add-HTButton -Parent $row2 -Module $m -Text 'Włącz' -Icon 'E73E' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Włączenie komputera' -Label { param($t) $t.Name } -Action { param($t) Set-HTADAccountState -Identity $t.ObjectGUID -State Enable; Update-HTADPanelObject -Panel 'adcomputers' -Object $t -Changes @{ Enabled = $true }; 'Włączony' }
    } | Out-Null
    Add-HTButton -Parent $row2 -Module $m -Text 'Wyłącz' -Icon 'E711' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Wyłączenie komputera' -Danger -Confirm 'Wyłączyć konta wybranych komputerów? Użytkownicy nie zalogują się na nie kontami domenowymi.' -Label { param($t) $t.Name } -Action { param($t) Set-HTADAccountState -Identity $t.ObjectGUID -State Disable; Update-HTADPanelObject -Panel 'adcomputers' -Object $t -Changes @{ Enabled = $false }; 'Wyłączony' }
    } | Out-Null
    Add-HTButton -Parent $row2 -Module $m -Text 'Przenieś do OU…' -Icon 'E8DE' -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $ou = Select-HTADOrganizationalUnit
        if (-not $ou) { return }
        Invoke-HTTargetAction -Module $m -Name 'Przeniesienie do OU' -Targets $targets -Confirm "Przenieść do $($ou.CanonicalName)?" -Label { param($t) $t.Name } -Action { param($t) Move-HTADObject -Identity $t.ObjectGUID -TargetPath $ou.DistinguishedName; "Do: $($ou.CanonicalName)" }
    } | Out-Null
    $row3 = Add-HTToolbarRow -Module $m -Title 'Operacje'
    Add-HTButton -Parent $row3 -Module $m -Text 'Uruchom ponownie' -Icon 'E777' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Restart komputera' -Service '' -Danger -Confirm 'Uruchomić ponownie wybrane komputery (wymuszenie, bez pytania użytkownika)?' -Label { param($t) $t.Name } -Action { param($t) Restart-HTComputer -ComputerName $(if ($t.DNSHostName) { $t.DNSHostName } else { $t.Name }); 'Wysłano polecenie restartu' }
    } | Out-Null
    Add-HTButton -Parent $row3 -Module $m -Text 'Usuń z domeny' -Icon 'E74D' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie komputera' -Danger -TypeToConfirm 'USUŃ' -Confirm 'Usunąć obiekty komputerów z AD (razem z kluczami BitLocker)?' -Label { param($t) $t.Name } -Action {
            param($t)
            Remove-HTADObject -Section 'Computer' -Identity $t.ObjectGUID
            Remove-HTTargetItem -Panel (Get-HTPanel 'adcomputers') -Item $t
            'Usunięto'
        }
    } | Out-Null
}

function Register-HTADComputerReport {
    param([string]$Key, [string]$Title, [string]$Icon, [string]$Type, [string]$Description, [switch]$Days)
    $script:ADReportDefs[$Key] = @{ Type = $Type; Days = [bool]$Days }
    Register-HTModule -Workspace 'ADComputers' -Category 'Raporty' -Key $Key -Title $Title -Icon $Icon -Description $Description -Build {
        param($m)
        $def = $script:ADReportDefs[$m.Key]
        $m.Data.Type = $def.Type
        $row = Add-HTToolbarRow -Module $m
        if ($def.Days) {
            Add-HTLabel -Parent $row -Text 'Bez logowania od (dni):' | Out-Null
            $m.C.Days = Add-HTNumeric -Parent $row -Value (Get-HTInactiveDaysDefault) -Minimum 1 -Maximum 3650
        }
        Add-HTButton -Parent $row -Module $m -Text 'Generuj raport' -Icon 'E9D2' -Primary -OnClick {
            param($m)
            $days = if ($m.C.Days) { Get-HTNum $m.C.Days } else { 90 }
            $type = $m.Data.Type
            Invoke-HTQuery -Module $m -Name $m.Title -ScriptBlock { Get-HTADComputerReport -Type $type -Days $days }
        } | Out-Null
        Add-HTRowAction -Module $m -Text 'Zaznacz na liście komputerów' -Icon 'E8B3' -Action {
            param($m, $rows)
            $p = Get-HTPanel 'adcomputers'
            if ($p.Table.Rows.Count -eq 0) { Invoke-HTPanelLoad -Panel $p }
            $ids = @($rows | ForEach-Object { [string]$_.ObjectGUID })
            foreach ($r in $p.Table.Rows) { if ($ids -contains [string]$r['Key']) { $r['Sel'] = $true } }
            Update-HTTargetCount $p
            Show-HTToast 'Zaznaczono komputery na liście - wybierz akcję (np. Zarządzanie).' 'ok'
        }
    }
}
Register-HTADComputerReport -Key 'adc.rep.inactive' -Title 'Nieaktywne komputery' -Icon 'E916' -Type 'Inactive' -Days -Description 'Włączone komputery bez logowania do domeny od wskazanej liczby dni (kandydaci do wyłączenia).'
Register-HTADComputerReport -Key 'adc.rep.os' -Title 'Systemy operacyjne' -Icon 'E7F8' -Type 'OperatingSystems' -Days -Description 'Liczba komputerów według systemu (czerwone - systemy bez wsparcia).'
Register-HTADComputerReport -Key 'adc.rep.disabled' -Title 'Wyłączone komputery' -Icon 'E711' -Type 'Disabled' -Description 'Wyłączone konta komputerów (do usunięcia po okresie przechowywania).'
#endregion

#region Grupy AD
Register-HTWorkspace -Key 'ADGroups' -Title 'Grupy AD' -Icon 'E902' -Panel 'adgroups' -Service 'AD' `
    -Description 'Grupy Active Directory: członkowie, dodawanie i usuwanie, nowe grupy, edycja, puste grupy' -Categories @('Grupa', 'Zarządzanie', 'Raporty')

$panel = New-HTTargetPanel -Key 'adgroups' -Title 'Grupy AD' -Placeholder 'Szukaj (nazwa, opis)…' -EmptyIcon 'E902' -EmptyText 'Kliknij «Wczytaj», aby pobrać grupy z domeny.' -Describe {
    param($g)
    @{ Key = [string]$g.ObjectGUID; Title = $g.Name; Sub = "$($g.GroupCategory) • $($g.GroupScope)$(if ($g.Description) { " • $($g.Description)" })"
        Dot = $(if ($g.GroupCategory -eq 'Distribution') { 'info' } else { 'ok' }); Search = "$($g.SamAccountName) $($g.Mail) $($g.DistinguishedName)" }
}
Add-HTPanelLoader -Panel $panel -Service 'AD' -Loader { param($p) Get-HTADObjectList -Section 'Group' } | Out-Null

Register-HTModule -Workspace 'ADGroups' -Category 'Grupa' -Key 'adg.members' -Title 'Członkowie' -Icon 'E716' `
    -Description 'Członkowie grup (także eksport do CSV dla wielu grup naraz). Dodawanie członków z listy loginów; prawy przycisk - usunięcie.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż członków' -Icon 'E716' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Członkowie grup' -AlwaysShowObject -Label { param($t) $t.Name } -Action {
            param($t)
            foreach ($x in @(Get-HTADGroupMembers -Identity $t.ObjectGUID)) { [PSCustomObject]@{ Członek = $x.Name; Login = $x.SamAccountName; Typ = $x.ObjectClass; DN = $x.DistinguishedName } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Dodaj członków…' -Icon 'E8FA' -Create -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $text = Show-InputBox -Title 'Dodaj członków' -Prompt "Loginy, UPN, nazwy komputerów lub grup (jeden w linii) - do $($targets.Count) grup:" -Multiline -Icon 'E8FA'
        $ids = @(Split-HTInputList $text)
        if ($ids.Count -eq 0) { return }
        $resolved = @()
        $missing = @()
        foreach ($id in $ids) { try { $resolved += Resolve-HTADObject -Identity $id } catch { $missing += "$id - $($_.Exception.Message)" } }
        if ($missing.Count -gt 0 -and -not (Show-HTConfirm -Warning -Title 'Nie znaleziono' -Message 'Części obiektów nie znaleziono. Dodać pozostałe?' -Items $missing)) { return }
        if ($resolved.Count -eq 0) { return }
        Invoke-HTTargetAction -Module $m -Name 'Dodanie członków' -Summary "Nowi członkowie ($($resolved.Count)): $(@($resolved | Select-Object -First 15 | ForEach-Object { $_.Name }) -join ', ')$(if ($resolved.Count -gt 15) { ' …' })" -Targets $targets -Label { param($t) $t.Name } -Action {
            param($t)
            Add-HTADGroupMember -Group $t.DistinguishedName -Members @($resolved | ForEach-Object { $_.DistinguishedName })
            "Dodano: $(@($resolved | ForEach-Object { $_.Name }) -join ', ')"
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń z grupy' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie członka' -Rows @($rows | Where-Object { $_.DN }) -Danger -Confirm 'Usunąć zaznaczonych członków z grup?' -Label { param($r) "$($r.Obiekt): $($r.Członek)" } `
            -Action { param($r) Remove-HTADGroupMember -Group $r.__target.DistinguishedName -Members @($r.DN) } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'ADGroups' -Category 'Grupa' -Key 'adg.details' -Title 'Szczegóły' -Icon 'E8A1' -Description 'Typ, zakres, opis, właściciel (Managed By), adres e-mail i członkowie grupy.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż szczegóły' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Szczegóły grupy' -Label { param($t) $t.Name } -Action { param($t) ConvertTo-HTDetailRows -Data (Get-HTADObjectDetail -Section 'Group' -Identity $t.ObjectGUID) }
    } | Out-Null
}

Register-HTModule -Workspace 'ADGroups' -Category 'Zarządzanie' -Key 'adg.manage' -Title 'Edycja i nowe grupy' -Icon 'E70F' -Description 'Nowa grupa, zmiana nazwy, typu i zakresu, opis i właściciel, usunięcie.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Nowa grupa…' -Create -NoRowMenu -Icon 'E710' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'AD')) { return }
        $form = Show-HTFormDialog -Title 'Nowa grupa AD' -Icon 'E902' -OkText 'Dalej' -Fields @(
            @{ Name = 'Name'; Label = 'Nazwa'; Required = $true }
            @{ Name = 'Category'; Label = 'Typ'; Type = 'Combo'; Options = @('Security', 'Distribution') }
            @{ Name = 'Scope'; Label = 'Zakres'; Type = 'Combo'; Options = @('Global', 'DomainLocal', 'Universal') }
            @{ Name = 'Description'; Label = 'Opis' }
        )
        if (-not $form) { return }
        $ou = Select-HTADOrganizationalUnit -Title 'OU nowej grupy'
        if (-not $ou) { return }
        if (-not (Confirm-HTChange -Name 'Tworzenie grupy' -Labels @([string]$form.Name) -Summary (@(Get-HTPendingFormSummary) + "OU: $($ou.Name)") -Confirm "Utworzyć grupę $($form.Name)?")) { return }
        Invoke-HTQuery -Module $m -Name 'Tworzenie grupy' -KeepResults -Record Change -ScriptBlock {
            New-HTADGroup -Name $form.Name -Category $form.Category -Scope $form.Scope -Path $ou.DistinguishedName -Description $form.Description | Out-Null
            Write-Log -Message "Utworzono grupę AD: $($form.Name)" -Type 'Info&Notification'
            [PSCustomObject]@{ Obiekt = $form.Name; Status = 'OK'; Szczegóły = "$($form.Category) / $($form.Scope) w $($ou.CanonicalName)" }
        }
        Invoke-HTPanelLoad -Panel (Get-HTPanel 'adgroups') -Quiet
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Edytuj…' -Icon 'E70F' -Danger -OnClick {
        param($m)
        $t = @(Get-HTChangeTargets -Module $m -Single)[0]
        if (-not $t) { return }
        $g = Get-ADGroup -Identity $t.ObjectGUID -Properties Description, ManagedBy
        $owner = if ($g.ManagedBy) { (Get-ADObject -Identity $g.ManagedBy -Properties sAMAccountName).sAMAccountName } else { '' }
        $form = Show-HTFormDialog -Title 'Edycja grupy' -Description $t.Name -Icon 'E70F' -Fields @(
            @{ Name = 'Name'; Label = 'Nazwa'; Default = $g.Name; Required = $true }
            @{ Name = 'Category'; Label = 'Typ'; Type = 'Combo'; Options = @('Security', 'Distribution'); Default = "$($g.GroupCategory)" }
            @{ Name = 'Scope'; Label = 'Zakres'; Type = 'Combo'; Options = @('Global', 'DomainLocal', 'Universal'); Default = "$($g.GroupScope)" }
            @{ Name = 'Description'; Label = 'Opis'; Default = $g.Description }
            @{ Name = 'ManagedBy'; Label = 'Właściciel (login)'; Default = $owner }
        )
        if (-not $form) { return }
        Invoke-HTTargetAction -Module $m -Name 'Edycja grupy' -Targets @($t) -Label { param($t) $t.Name } -Action {
            param($t)
            $done = @()
            if ($form.Description -ne [string]$g.Description -or $form.ManagedBy -ne $owner) { Set-HTADGroupProperties -Identity $t.ObjectGUID -Description $form.Description -ManagedBy $form.ManagedBy; $done += 'opis/właściciel' }
            if ($form.Category -ne "$($g.GroupCategory)") { Set-HTADGroupCategory -Identity $t.ObjectGUID -Category $form.Category; $done += "typ: $($form.Category)" }
            if ($form.Scope -ne "$($g.GroupScope)") { Set-HTADGroupScope -Identity $t.ObjectGUID -Scope $form.Scope; $done += "zakres: $($form.Scope)" }
            if ($form.Name -ne $g.Name) { Rename-HTADGroup -Identity $t.ObjectGUID -NewName $form.Name; $done += "nazwa: $($form.Name)" }
            if ($done.Count -eq 0) { return @{ Status = 'Pominięto'; Szczegóły = 'Brak zmian' } }
            $done -join ', '
        }
        Invoke-HTPanelLoad -Panel (Get-HTPanel 'adgroups') -Quiet
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Usuń grupę' -Icon 'E74D' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie grupy' -Danger -TypeToConfirm 'USUŃ' -Confirm 'Usunąć wybrane grupy? Członkowie utracą wynikające z nich uprawnienia.' -Label { param($t) $t.Name } -Action {
            param($t)
            Remove-HTADObject -Section 'Group' -Identity $t.ObjectGUID
            Remove-HTTargetItem -Panel (Get-HTPanel 'adgroups') -Item $t
            'Usunięto'
        }
    } | Out-Null
}

Register-HTModule -Workspace 'ADGroups' -Category 'Raporty' -Key 'adg.rep.empty' -Title 'Puste grupy' -Icon 'E9D2' -Description 'Grupy bez członków (szare - systemowe). Kandydaci do uporządkowania.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Generuj raport' -Icon 'E9D2' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Puste grupy' -ScriptBlock { Get-HTADEmptyGroups } } | Out-Null
}
#endregion
