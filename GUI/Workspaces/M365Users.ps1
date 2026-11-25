# Przestrzeń robocza: Microsoft 365 - użytkownicy Entra ID (Microsoft Graph)

Register-HTWorkspace -Key 'M365' -Title 'Microsoft 365' -Icon 'E716' -Panel 'm365users' -Service 'Graph' `
    -Description 'Użytkownicy Microsoft 365 / Entra ID: konta, hasła i MFA, licencje, grupy, offboarding i raporty' `
    -Categories @('Konto', 'Bezpieczeństwo', 'Licencje i grupy', 'Cykl życia', 'Raporty')

$panel = New-HTTargetPanel -Key 'm365users' -Title 'Użytkownicy Microsoft 365' -Placeholder 'Szukaj (nazwa, UPN, dział)…' -EmptyIcon 'E716' `
    -EmptyText 'Połącz z Microsoft 365 i kliknij «Wczytaj».' -Describe {
    param($u)
    $sub = $u.UserPrincipalName
    if ($u.Department) { $sub += " • $($u.Department)" }
    if ($u.UserType -eq 'Guest') { $sub += ' • gość' }
    @{ Key = $u.Id; Title = $(if ($u.DisplayName) { $u.DisplayName } else { $u.UserPrincipalName }); Sub = $sub
        Dot = $(if (-not $u.AccountEnabled) { 'off' } elseif ($u.UserType -eq 'Guest') { 'info' } elseif (-not $u.Licenses) { 'warn' } else { 'ok' })
        Search = "$($u.Mail) $($u.JobTitle) $($u.Licenses) $($u.UserType)" }
}
Add-HTPanelLoader -Panel $panel -Service 'Graph' -Loader { param($p) Get-HTM365Users } | Out-Null
Add-HTPanelHint -Panel $panel -Text 'Kropka: zielona - aktywne z licencją, żółta - bez licencji, szara - zablokowane, niebieska - gość.' | Out-Null

function Get-HTM365Label { param($u) if ($u.UserPrincipalName) { [string]$u.UserPrincipalName } else { [string]$u.DisplayName } }

function Update-HTM365PanelUser {
    # Odświeża wpis użytkownika na liście po zmianie (np. blokada konta)
    param([Parameter(Mandatory)][object]$User, [hashtable]$Changes = @{})
    foreach ($k in $Changes.Keys) { $User.$k = $Changes[$k] }
    $p = Get-HTPanel 'm365users'
    if ($p) { Update-HTTargetItem -Panel $p -Item $User }
}

#region Konto
Register-HTModule -Workspace 'M365' -Category 'Konto' -Key 'm365.details' -Title 'Szczegóły konta' -Icon 'E77B' `
    -Description 'Pełne informacje o koncie: kontakt, logowanie, synchronizacja z AD, licencje, metody MFA i grupy.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż szczegóły' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Szczegóły konta' -Label { param($t) Get-HTM365Label $t } -Action { param($t) ConvertTo-HTDetailRows -Data (Get-HTM365UserDetail -Id $t.Id) }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Otwórz w Entra' -Icon 'E8A7' -OnClick {
        param($m)
        foreach ($t in @(Get-HTTargets -Module $m | Select-Object -First 5)) { Start-Process "https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($t.Id)" }
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Konto' -Key 'm365.edit' -Title 'Dane kontaktowe' -Icon 'E70F' `
    -Description 'Edycja stanowiska, działu, telefonów i adresu. Dla wielu kont - ustawienie wybranych pól hurtowo (puste pola pozostają bez zmian).' -Build {
    param($m)
    Add-HTStateCheck -Module $m -Label { param($t) Get-HTM365Label $t } -Action {
        param($t)
        Select-HTDetailFields -Detail (Get-HTM365UserDetail -Id $t.Id) -Fields 'Imię', 'Nazwisko', 'Stanowisko', 'Dział', 'Firma', 'Biuro', 'Telefon komórkowy', 'Telefon służbowy', 'Adres', 'Lokalizacja użycia', 'Przełożony'
    } | Out-Null
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Edytuj…' -Icon 'E70F' -Primary -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $single = $targets.Count -eq 1
        $d = if ($single) { Invoke-HTGraphRequest -Uri "users/$($targets[0].Id)?`$select=displayName,givenName,surname,jobTitle,department,companyName,officeLocation,mobilePhone,businessPhones,streetAddress,city,postalCode,country,usageLocation,employeeId" } else { $null }
        $names = [ordered]@{ displayName = 'Nazwa wyświetlana'; givenName = 'Imię'; surname = 'Nazwisko'; jobTitle = 'Stanowisko'; department = 'Dział'; companyName = 'Firma'; officeLocation = 'Biuro'
            mobilePhone = 'Telefon komórkowy'; businessPhones = 'Telefon służbowy'; streetAddress = 'Ulica'; city = 'Miasto'; postalCode = 'Kod pocztowy'; country = 'Kraj'; usageLocation = 'Lokalizacja użycia (np. PL)'; employeeId = 'ID pracownika' }
        $fields = @()
        if (-not $single) { $fields += @{ Type = 'Info'; Label = "Zmiana dla $($targets.Count) kont. Wypełnij tylko pola, które mają zostać ustawione." } }
        foreach ($k in $names.Keys) {
            if (-not $single -and $k -in 'displayName', 'givenName', 'surname', 'employeeId', 'mobilePhone', 'businessPhones') { continue }
            $value = if ($d) { if ($k -eq 'businessPhones') { @($d.businessPhones) -join ', ' } else { $d.$k } } else { '' }
            $fields += @{ Name = $k; Label = $names[$k]; Default = $value }
        }
        $result = Show-HTFormDialog -Title 'Dane kontaktowe' -Description $(if ($single) { Get-HTM365Label $targets[0] } else { "$($targets.Count) kont" }) -Fields $fields -Icon 'E70F'
        if (-not $result) { return }
        $changes = @{}
        foreach ($k in $result.Keys) {
            $new = [string]$result[$k]
            if ($single) {
                $old = if ($k -eq 'businessPhones') { @($d.businessPhones) -join ', ' } else { [string]$d.$k }
                if ($new -ne $old) { $changes[$k] = $(if ($k -eq 'businessPhones') { @(Split-HTInputList $new) } else { $new }) }
            }
            elseif ($new) { $changes[$k] = $new }
        }
        if ($changes.Count -eq 0) { Show-HTToast 'Brak zmian.' 'info'; return }
        Invoke-HTTargetAction -Module $m -Name 'Zmiana danych kontaktowych' -Summary @(ConvertTo-HTChangeSummary -Settings $changes) -Targets $targets -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            Set-HTM365UserContact -Id $t.Id -Properties $changes
            "Zmieniono: $(@($changes.Keys) -join ', ')"
        }
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Konto' -Key 'm365.manager' -Title 'Przełożony' -Icon 'E902' `
    -Description 'Podgląd i ustawienie przełożonego (pole Manager w Entra ID) - używane m.in. w zatwierdzeniach i schemacie organizacyjnym.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Przełożeni' -AlwaysShowObject -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $mgr = Get-HTM365UserManager -Id $t.Id
            [PSCustomObject]@{ Przełożony = $(if ($mgr) { $mgr.displayName } else { '(brak)' }); 'UPN przełożonego' = $mgr.userPrincipalName; Stanowisko = $mgr.jobTitle; __flag = $(if (-not $mgr) { 'muted' } else { '' }) }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Ustaw przełożonego…' -Icon 'E8FA' -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $manager = Select-HTM365User -Title 'Przełożony' -Prompt "Przełożony dla: $($targets.Count) kont."
        if (-not $manager) { return }
        Invoke-HTTargetAction -Module $m -Name 'Ustawienie przełożonego' -Summary "Przełożony: $(Get-HTM365Label $manager)" -Targets $targets -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $previous = Get-HTM365UserManager -Id $t.Id
            Set-HTM365UserManager -Id $t.Id -ManagerId $manager.Id
            Register-HTUndo -Operation 'Ustawienie przełożonego' -Object (Get-HTM365Label $t) -Kind 'Manager' -Data @{ UserId = $t.Id; ManagerId = $(if ($previous) { [string]$previous.id } else { '' }) }
            "Przełożony: $($manager.DisplayName)"
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Usuń przełożonego' -Icon 'E74D' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie przełożonego' -Confirm 'Usunąć przypisanie przełożonego?' -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $previous = Get-HTM365UserManager -Id $t.Id
            if (-not $previous) { return @{ Status = 'Pominięto'; Szczegóły = 'Brak przełożonego' } }
            Remove-HTM365UserManager -Id $t.Id
            Register-HTUndo -Operation 'Usunięcie przełożonego' -Object (Get-HTM365Label $t) -Kind 'Manager' -Data @{ UserId = $t.Id; ManagerId = [string]$previous.id }
            'Usunięto'
        }
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Konto' -Key 'm365.devices' -Title 'Urządzenia użytkownika' -Icon 'E7F8' `
    -Description 'Urządzenia zarządzane w Intune i zarejestrowane w Entra ID przypisane do użytkownika.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż urządzenia' -Icon 'E7F8' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Urządzenia użytkownika' -Label { param($t) Get-HTM365Label $t } -Action { param($t) Get-HTM365UserDevices -Id $t.Id }
    } | Out-Null
}
#endregion

#region Bezpieczeństwo
Register-HTModule -Workspace 'M365' -Category 'Bezpieczeństwo' -Key 'm365.block' -Title 'Blokada i sesje' -Icon 'E72E' `
    -Description 'Blokada logowania (z unieważnieniem sesji), odblokowanie i wylogowanie ze wszystkich urządzeń - np. przy podejrzeniu przejęcia konta.' -Build {
    param($m)
    # Etapy: konta z listy po lewej -> «Sprawdź stan» -> zmiana (czerwone przyciski) na wierszach zaznaczonych w wynikach
    $row0 = Add-HTToolbarRow -Module $m -Title 'Stan'
    Add-HTButton -Parent $row0 -Module $m -Text 'Sprawdź stan' -Icon 'E946' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Stan kont' -Label { param($t) Get-HTM365Label $t } -Action { param($t) Get-HTM365AccountState -Id $t.Id }
    } | Out-Null
    Add-HTLabel -Parent $row0 -Hint -Text 'Logowanie, ostatnie logowanie, sesje i synchronizacja z AD (konto z AD zablokuj w AD - synchronizacja nadpisze zmianę). Zaznacz wiersze, aby zmienić tylko je.' | Out-Null
    $row = Add-HTToolbarRow -Module $m -Title 'Zmiany'
    Add-HTButton -Parent $row -Module $m -Text 'Zablokuj logowanie' -Icon 'E72E' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Blokada logowania' -Danger -Confirm 'Zablokować logowanie i unieważnić wszystkie sesje wybranych kont?' -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            Set-HTM365UserEnabled -Id $t.Id -Enabled $false -RevokeSessions $true
            Update-HTM365PanelUser -User $t -Changes @{ AccountEnabled = $false }
            Register-HTUndo -Operation 'Blokada logowania' -Object (Get-HTM365Label $t) -Kind 'UserEnabled' -Data @{ UserId = $t.Id; Enabled = $true }
            'Logowanie zablokowane, sesje unieważnione'
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Odblokuj' -Icon 'E785' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Odblokowanie logowania' -Confirm 'Odblokować logowanie wybranych kont?' -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            Set-HTM365UserEnabled -Id $t.Id -Enabled $true
            Update-HTM365PanelUser -User $t -Changes @{ AccountEnabled = $true }
            Register-HTUndo -Operation 'Odblokowanie logowania' -Object (Get-HTM365Label $t) -Kind 'UserEnabled' -Data @{ UserId = $t.Id; Enabled = $false }
            'Logowanie odblokowane'
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Unieważnij sesje' -Icon 'E7E8' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Unieważnienie sesji' -Confirm 'Wylogować wybrane konta ze wszystkich aplikacji i urządzeń?' -Label { param($t) Get-HTM365Label $t } -Action { param($t) Revoke-HTM365UserSessions -Id $t.Id; 'Sesje unieważnione' }
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Bezpieczeństwo' -Key 'm365.password' -Title 'Reset hasła' -Icon 'E8D7' `
    -Description 'Losowe hasła (wg ustawień generatora) lub jedno podane hasło; opcjonalnie wymuszenie zmiany przy logowaniu. Hasła są ukryte - «Pokaż poufne».' -Build {
    param($m)
    Add-HTStateCheck -Module $m -Label { param($t) Get-HTM365Label $t } -Action { param($t) Get-HTM365AccountState -Id $t.Id } | Out-Null
    $m.SecretColumns = @('Hasło')
    $row = Add-HTToolbarRow -Module $m -Title 'Opcje'
    $m.C.Mode = Add-HTSegmented -Parent $row -Items @('Losowe hasła', 'Podane hasło')
    Add-HTLabel -Parent $row -Text 'Długość:' | Out-Null
    $m.C.Length = Add-HTNumeric -Parent $row -Value ([Math]::Max(8, [int]$Global:PasswordDefaultLength)) -Minimum 8 -Maximum 64
    $m.C.Force = Add-HTCheckBox -Parent $row -Text 'Zmiana hasła przy logowaniu' -Checked $true
    $m.C.Revoke = Add-HTCheckBox -Parent $row -Text 'Unieważnij sesje' -Checked $false
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
        $force = Test-HTChecked $m.C.Force
        $revoke = Test-HTChecked $m.C.Revoke
        Invoke-HTTargetAction -Module $m -Name 'Reset hasła' -Targets $targets -Confirm "Zresetować hasło $($targets.Count) kont?" -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $password = if ($fixed) { $fixed } else { New-HTRandomPassword -Length $length }
            Reset-HTM365UserPassword -Id $t.Id -Password $password -ForceChange $force
            if ($revoke) { Revoke-HTM365UserSessions -Id $t.Id }
            @{ Hasło = $password; Szczegóły = $(if ($force) { 'Zmiana przy logowaniu' } else { 'Hasło stałe' }) }
        }
    } | Out-Null
    Add-HTButton -Parent $actions -Module $m -Text 'Kopiuj hasła' -Icon 'E8C8' -ToolTip 'Kopiuje pary UPN - hasło do schowka (czyszczony po 60 s)' -OnClick {
        param($m)
        $rows = @(Get-HTResultSelection -Module $m -AllVisible | Where-Object { $_.Hasło })
        if ($rows.Count -eq 0) { return }
        Set-HTClipboard -Text (($rows | ForEach-Object { "$($_.Obiekt)`t$($_.Hasło)" }) -join "`r`n") -Secret
        Show-HTToast "Skopiowano hasła: $($rows.Count) (schowek zostanie wyczyszczony po 60 s)." 'ok'
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Bezpieczeństwo' -Key 'm365.mfa' -Title 'Metody MFA' -Icon 'E928' `
    -Description 'Zarejestrowane metody uwierzytelniania; usuwanie metod (np. zgubiony telefon), dodanie numeru telefonu i jednorazowy kod Temporary Access Pass.' -Build {
    param($m)
    $m.SecretColumns = @('Kod TAP')
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż metody' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Metody uwierzytelniania' -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            foreach ($method in @(Get-HTM365AuthMethods -Id $t.Id)) {
                [PSCustomObject]@{ Metoda = $method.Type; Szczegóły = $method.Detail; Utworzono = $method.Created; 'Można usunąć' = $method.Removable; __method = $method }
            }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Dodaj telefon…' -Icon 'E717' -Create -OnClick {
        param($m)
        $t = @(Get-HTChangeTargets -Module $m -Single)[0]
        if (-not $t) { return }
        $form = Show-HTFormDialog -Title 'Telefon MFA' -Description (Get-HTM365Label $t) -Icon 'E717' -OkText 'Dodaj' -Fields @(
            @{ Name = 'Phone'; Label = 'Numer telefonu'; Required = $true; Validation = 'Phone'; Placeholder = '+48 600 100 200'; Hint = 'Numer bez kierunkowego jest traktowany jako polski.' }
            @{ Name = 'Type'; Label = 'Rodzaj'; Type = 'Combo'; Options = @('mobile', 'alternateMobile', 'office') }
        )
        if (-not $form) { return }
        Invoke-HTTargetAction -Module $m -Name 'Dodanie telefonu MFA' -Targets @($t) -Label { param($t) Get-HTM365Label $t } -Action { param($t) "Dodano: $(Add-HTM365PhoneMethod -UserId $t.Id -PhoneNumber $form.Phone -PhoneType $form.Type)" }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Temporary Access Pass…' -Icon 'E8D7' -ToolTip 'Jednorazowy kod do zalogowania i zarejestrowania nowych metod (np. nowy telefon)' -Create -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $form = Show-HTFormDialog -Title 'Temporary Access Pass' -Description "Kody dla $($targets.Count) kont." -Icon 'E8D7' -OkText 'Generuj' -Fields @(
            @{ Name = 'Minutes'; Label = 'Ważność (minuty)'; Type = 'Number'; Default = 60; Min = 10; Max = 43200 }
            @{ Name = 'Once'; Label = 'Jednorazowy'; Type = 'Check'; Default = $true }
        )
        if (-not $form) { return }
        Invoke-HTTargetAction -Module $m -Name 'Temporary Access Pass' -Targets $targets -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $tap = New-HTM365TemporaryAccessPass -UserId $t.Id -LifetimeInMinutes $form.Minutes -IsUsableOnce $form.Once
            @{ 'Kod TAP' = $tap.temporaryAccessPass; Szczegóły = "Ważny $($form.Minutes) min od $($tap.startDateTime)" }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń metody' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $rows = @($rows | Where-Object { $_.__method -and $_.__method.Removable })
        if ($rows.Count -eq 0) { Show-HTWarning 'Zaznaczone metody nie mogą być usunięte (np. hasło).'; return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie metody MFA' -Rows $rows -Danger -Confirm 'Usunąć zaznaczone metody uwierzytelniania? Użytkownik będzie musiał zarejestrować je ponownie.' `
            -Label { param($r) "$(Get-HTM365Label $r.__target): $($r.Metoda) $($r.Szczegóły)" } -Action { param($r) Remove-HTM365AuthMethod -UserId $r.__target.Id -Method $r.__method }
    }
}

Register-HTModule -Workspace 'M365' -Category 'Bezpieczeństwo' -Key 'm365.signins' -Title 'Logowania' -Icon 'E81C' `
    -Description 'Ostatnie logowania użytkownika: aplikacja, adres IP, lokalizacja, wynik i dostęp warunkowy (Entra ID P1, AuditLog.Read.All).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Liczba wpisów:' | Out-Null
    $m.C.Top = Add-HTNumeric -Parent $row -Value 50 -Minimum 1 -Maximum 1000
    $m.C.Failed = Add-HTCheckBox -Parent $row -Text 'Tylko nieudane'
    $actions = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $actions -Module $m -Text 'Pokaż logowania' -Icon 'E81C' -Primary -OnClick {
        param($m)
        $top = Get-HTNum $m.C.Top
        $failed = Test-HTChecked $m.C.Failed
        Invoke-HTTargetQuery -Module $m -Name 'Logowania' -Label { param($t) Get-HTM365Label $t } -Action { param($t) Get-HTM365SignIns -UserId $t.Id -Top $top -FailedOnly:$failed }
    } | Out-Null
}
#endregion

#region Licencje i grupy
Register-HTModule -Workspace 'M365' -Category 'Licencje i grupy' -Key 'm365.licenses' -Title 'Licencje' -Icon 'E8EC' `
    -Description 'Licencje przypisane do kont; przypisywanie i usuwanie licencji (lokalizacja użycia ustawiana automatycznie, gdy jej brakuje).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż licencje' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Licencje użytkowników' -AlwaysShowObject -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $licenses = @(Get-HTM365UserLicenses -Id $t.Id)
            if ($licenses.Count -eq 0) { return [PSCustomObject]@{ Licencja = '(brak)'; SKU = ''; __flag = 'muted' } }
            foreach ($l in $licenses) { [PSCustomObject]@{ Licencja = Get-HTSkuFriendlyName $l.SkuPartNumber; SKU = $l.SkuPartNumber; __sku = $l } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Przypisz licencję…' -Icon 'E710' -Create -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        Set-HTBusy -Busy $true -Text 'Pobieranie licencji…'
        try { $skus = @(Get-HTSubscribedSkus -Force | Where-Object { $_.Status -eq 'Enabled' } | ForEach-Object { [PSCustomObject]@{ Licencja = Get-HTSkuFriendlyName $_.SkuPartNumber; SKU = $_.SkuPartNumber; Dostępne = $_.Available; Przypisane = $_.Consumed; SkuId = $_.SkuId } }) }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        $selected = Show-HTSelectionDialog -Title 'Przypisz licencję' -Prompt "Licencje dla $($targets.Count) kont." -Items $skus -MultiSelect -Icon 'E8EC'
        if (-not $selected) { return }
        $ids = @($selected | ForEach-Object { "$($_.SkuId)" })
        $names = @($selected | ForEach-Object { $_.Licencja }) -join ', '
        $short = @($selected | Where-Object { $_.Dostępne -lt $targets.Count })
        if ($short.Count -gt 0 -and -not (Show-HTConfirm -Warning -Title 'Za mało licencji' -Message "Niewystarczająca liczba wolnych licencji: $(@($short | ForEach-Object { "$($_.Licencja) ($($_.Dostępne))" }) -join ', '). Kontynuować?")) { return }
        Invoke-HTTargetAction -Module $m -Name 'Przypisanie licencji' -Summary "Licencje do przypisania: $names" -Targets $targets -Label { param($t) Get-HTM365Label $t } -Action { param($t) Set-HTM365UserLicense -Id $t.Id -AddSkuIds $ids; "Przypisano: $names" }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Usuń licencję…' -Icon 'E738' -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        Set-HTBusy -Busy $true -Text 'Pobieranie licencji…'
        try { $skus = @(Get-HTSubscribedSkus -Force | Where-Object { $_.Consumed -gt 0 } | ForEach-Object { [PSCustomObject]@{ Licencja = Get-HTSkuFriendlyName $_.SkuPartNumber; SKU = $_.SkuPartNumber; Przypisane = $_.Consumed; SkuId = $_.SkuId } }) }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        $selected = Show-HTSelectionDialog -Title 'Usuń licencję' -Prompt "Licencje do usunięcia z $($targets.Count) kont." -Items $skus -MultiSelect -Icon 'E8EC'
        if (-not $selected) { return }
        $ids = @($selected | ForEach-Object { "$($_.SkuId)" })
        $names = @($selected | ForEach-Object { $_.Licencja }) -join ', '
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie licencji' -Targets $targets -Danger -Confirm "Usunąć licencje ($names)? Usunięcie licencji Exchange rozpoczyna 30-dniowy okres usunięcia skrzynki." -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $owned = @(Get-HTM365UserLicenses -Id $t.Id | ForEach-Object { "$($_.SkuId)" })
            $remove = @($ids | Where-Object { $owned -contains $_ })
            if ($remove.Count -eq 0) { return @{ Status = 'Pominięto'; Szczegóły = 'Brak wskazanych licencji' } }
            Set-HTM365UserLicense -Id $t.Id -RemoveSkuIds $remove
            Register-HTUndo -Operation 'Usunięcie licencji' -Object (Get-HTM365Label $t) -Kind 'License' -Data @{ UserId = $t.Id; SkuIds = $remove }
            "Usunięto licencji: $($remove.Count)"
        }
    } | Out-Null
}

function New-HTM365GroupInteractive {
    <#
        Nowa grupa Entra ID (zabezpieczeń albo Microsoft 365): formularz (rodzaj, nazwa, alias, opis, widoczność, właściciele,
        członkowie - UPN; -Members: wstępnie wpisani), potwierdzenie, utworzenie i wpis do podsumowania. Zwraca grupę albo $null.
    #>
    param([string[]]$Members = @())
    if (-not (Assert-HTConnection -Service 'Graph')) { return $null }
    if (-not (Assert-HTWriteAllowed -Operation 'Nowa grupa Microsoft 365')) { return $null }
    $types = @('Zabezpieczeń - uprawnienia (np. SharePoint), aplikacje, licencje grupowe', 'Microsoft 365 - wspólna poczta, kalendarz, Teams i witryna')
    $pick = {
        param($w, [string]$Field, [string]$Title)
        $users = @(Select-HTM365User -Title $Title -Multi)
        if (-not $users.Count) { return }
        $box = $w.Tag.Controls[$Field].Control
        $box.Text = (@(Split-HTInputList $box.Text) + @($users | Where-Object { $_ } | ForEach-Object { [string]$_.UserPrincipalName }) | Select-Object -Unique) -join "`r`n"
    }
    $form = Show-HTFormDialog -Title 'Nowa grupa (Microsoft 365 / Entra ID)' -Icon 'E902' -OkText 'Dalej' -Width 660 -MaxHeight 660 -Fields @(
        @{ Name = 'Type'; Label = 'Rodzaj grupy'; Type = 'Combo'; Options = $types }
        @{ Name = 'Name'; Label = 'Nazwa wyświetlana'; Required = $true }
        @{ Name = 'Alias'; Label = 'Alias (część adresu przed @; puste - z nazwy)'; Hint = 'Litery, cyfry, myślnik, podkreślenie, kropka - bez polskich znaków i spacji.' }
        @{ Name = 'Description'; Label = 'Opis (np. do czego służy grupa)' }
        @{ Name = 'Visibility'; Label = 'Widoczność'; Type = 'Combo'; Options = @('Prywatna', 'Publiczna'); ShowWhen = @{ Field = 'Type'; Values = @($types[1]) } }
        @{ Name = 'Owners'; Label = 'Właściciele (UPN, jeden w linii)'; Type = 'Multiline'; Height = 50 }
        @{ Type = 'Buttons'; Buttons = @(@{ Text = 'Wybierz właścicieli…'; Icon = 'E716'; OnClick = { param($w) & $pick $w 'Owners' 'Właściciele grupy' }.GetNewClosure() }) }
        @{ Name = 'Members'; Label = 'Członkowie (UPN, jeden w linii)'; Type = 'Multiline'; Height = 90; Default = (@($Members | Where-Object { $_ }) -join "`r`n") }
        @{ Type = 'Buttons'; Buttons = @(@{ Text = 'Wybierz członków…'; Icon = 'E716'; OnClick = { param($w) & $pick $w 'Members' 'Członkowie grupy' }.GetNewClosure() }) }
    )
    if (-not $form) { return $null }
    $type = if ([string]$form.Type -eq $types[1]) { 'Microsoft365' } else { 'Security' }
    $alias = ([string]$form.Alias).Trim()
    if ($alias -and $alias -notmatch '^[A-Za-z0-9][A-Za-z0-9\-_\.]{0,63}$') { Show-HTWarning "Alias «$alias» ma niedozwolone znaki (dozwolone: litery bez polskich znaków, cyfry, - _ .)." -Title 'Nowa grupa'; return $null }
    $ownerUpns = @(Split-HTInputList $form.Owners)
    $memberUpns = @(Split-HTInputList $form.Members)
    if (-not (Confirm-HTChange -Name 'Nowa grupa' -Labels @([string]$form.Name) -Summary @(Get-HTPendingFormSummary) -Confirm "Utworzyć grupę $($form.Name)?")) { return $null }
    Set-HTBusy -Busy $true -Text "Tworzenie grupy $($form.Name)…"
    try {
        $resolve = { param([string[]]$Upns) foreach ($upn in $Upns) { try { [string](Resolve-HTM365User -Identity $upn).id } catch { throw "Nie znaleziono konta $upn ($($_.Exception.Message))" } } }
        $ownerIds = @(& $resolve $ownerUpns)
        $memberIds = @(& $resolve $memberUpns)
        $group = New-HTM365Group -DisplayName ([string]$form.Name) -Type $type -MailNickname $alias -Description ([string]$form.Description) -Visibility $(if ($form.Visibility -eq 'Publiczna') { 'Public' } else { 'Private' }) -OwnerIds $ownerIds -MemberIds $memberIds
        $details = "$($group.Type)$(if ($group.Mail) { ", $($group.Mail)" }), właścicieli: $($ownerIds.Count), członków: $($memberIds.Count)"
        Add-HTOperationRecord -Operation 'Nowa grupa (Microsoft 365 / Entra ID)' -Object $group.DisplayName -Details $details -Module 'Grupy'
        Write-Log -Message "Utworzono grupę $($group.DisplayName) ($details)." -Type 'Info'
        Show-HTToast "Utworzono grupę $($group.DisplayName)." 'ok'
        return $group
    }
    catch {
        Add-HTOperationRecord -Operation 'Nowa grupa (Microsoft 365 / Entra ID)' -Object ([string]$form.Name) -Status 'Błąd' -Details $_.Exception.Message -Module 'Grupy'
        Show-HTError -Text "Nie utworzono grupy $($form.Name)." -ErrorObject $_
        return $null
    }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
}

Register-HTModule -Workspace 'M365' -Category 'Licencje i grupy' -Key 'm365.groups' -Title 'Grupy' -Icon 'E902' `
    -Description 'Członkostwo w grupach (Microsoft 365, zabezpieczeń, dystrybucyjnych - te ostatnie wymagają Exchange). Kopiowanie grup z innego użytkownika. Nowe grupy zabezpieczeń i Microsoft 365 (np. do uprawnień SharePoint).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż grupy' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Grupy użytkowników' -AlwaysShowObject -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            foreach ($g in @(Get-HTM365UserGroups -Id $t.Id)) {
                [PSCustomObject]@{ Grupa = $g.DisplayName; Typ = $g.Type; 'E-mail' = $g.Mail; Dynamiczna = $g.Dynamic; 'Z AD' = $g.Synced; __group = $g; __flag = $(if (-not (Test-HTM365GroupManageable -Group $g)) { 'muted' } else { '' }) }
            }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nowa grupa…' -Icon 'E902' -Create -NoRowMenu -ToolTip 'Nowa grupa zabezpieczeń albo Microsoft 365 (Entra ID) - członkowie: konta zaznaczone na liście po lewej' -OnClick {
        param($m)
        $members = @(Get-HTTargets -Module $m -Quiet | ForEach-Object { [string]$_.UserPrincipalName } | Where-Object { $_ })
        [void](New-HTM365GroupInteractive -Members $members)
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Dodaj do grup…' -Icon 'E710' -Create -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        Set-HTBusy -Busy $true -Text 'Pobieranie grup…'
        try { $groups = @(Get-HTM365Groups | Where-Object { Test-HTM365GroupManageable -Group $_ }) } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        $columns = @(@{ Text = 'Nazwa'; Property = 'DisplayName' }, @{ Text = 'Typ'; Property = 'Type' }, @{ Text = 'E-mail'; Property = 'Mail' }, @{ Text = 'Opis'; Property = 'Description' })
        $selected = @(Show-HTSelectionDialog -Title 'Dodaj do grup' -Prompt "Grupy dla $($targets.Count) kont (bez dynamicznych i synchronizowanych z AD)." -Items $groups -Columns $columns -MultiSelect -Icon 'E902')
        if ($selected.Count -eq 0) { return }
        Invoke-HTTargetAction -Module $m -Name 'Dodanie do grup' -Summary "Grupy ($($selected.Count)): $(@($selected | ForEach-Object { $_.DisplayName }) -join ', ')" -Targets $targets -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $done = foreach ($g in $selected) { Add-HTM365UserToGroup -Group $g -User $t; $g.DisplayName }
            "Dodano do: $(@($done) -join ', ')"
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Kopiuj grupy od…' -Icon 'E8C8' -ToolTip 'Dodaje zaznaczonych użytkowników do grup, do których należy wskazany użytkownik wzorcowy' -Create -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $source = Select-HTM365User -Title 'Użytkownik wzorcowy' -Prompt 'Grupy tego użytkownika zostaną skopiowane.'
        if (-not $source) { return }
        Set-HTBusy -Busy $true -Text 'Pobieranie grup wzorca…'
        try { $groups = @(Get-HTM365UserGroups -Id $source.Id | Where-Object { Test-HTM365GroupManageable -Group $_ }) } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        if ($groups.Count -eq 0) { Show-HTMessage -Text 'Użytkownik wzorcowy nie należy do grup, którymi można zarządzać.'; return }
        Invoke-HTTargetAction -Module $m -Name 'Kopiowanie grup' -Confirm "Dodać konta do grup użytkownika wzorcowego $($source.DisplayName)?" `
            -Summary @("Wzorzec: $(Get-HTM365Label $source)", "Grupy ($($groups.Count)): $(@($groups | ForEach-Object { $_.DisplayName }) -join ', ')") -Targets $targets -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $current = @(Get-HTM365UserGroups -Id $t.Id | ForEach-Object { $_.Id })
            $added = 0
            $errors = @()
            foreach ($g in $groups) {
                if ($current -contains $g.Id) { continue }
                try { Add-HTM365UserToGroup -Group $g -User $t; $added++ } catch { $errors += "$($g.DisplayName): $($_.Exception.Message)" }
            }
            @{ Status = $(if ($errors) { 'Błąd (częściowo)' } else { 'OK' }); Szczegóły = "Dodano do grup: $added$(if ($errors) { '; ' + ($errors -join '; ') })" }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń z grupy' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $rows = @($rows | Where-Object { $_.__group -and (Test-HTM365GroupManageable -Group $_.__group) })
        if ($rows.Count -eq 0) { Show-HTWarning 'Zaznacz grupy, którymi można zarządzać (nie dynamiczne i nie synchronizowane z AD).'; return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie z grupy' -Rows $rows -Confirm 'Usunąć użytkowników z zaznaczonych grup?' -Label { param($r) "$(Get-HTM365Label $r.__target) - $($r.Grupa)" } `
            -Action {
            param($r)
            Remove-HTM365UserFromGroup -Group $r.__group -User $r.__target
            if ($r.__group.Type -notin 'Dystrybucyjna', 'Zabezpieczeń (mail)') { Register-HTUndo -Operation 'Usunięcie z grupy' -Object "$(Get-HTM365Label $r.__target) - $($r.Grupa)" -Kind 'GroupMember' -Data @{ GroupId = $r.__group.Id; UserId = $r.__target.Id; Added = $false } }
        } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Cykl życia
#region Profile tworzenia kont
function Save-HTUserProfile {
    # Zapis profilu (nowy albo zmieniony; -Touch - data ostatniego użycia)
    param([Parameter(Mandatory)]$UserProfile, [string]$OriginalName = '', [switch]$Touch)
    $p = ConvertTo-HTUserProfile $UserProfile
    if ($Touch) { $p.LastUsed = (Get-Date).ToUniversalTime().ToString('o') }
    $others = @(Get-HTUserProfiles | Where-Object { $_.Name -ine $(if ($OriginalName) { $OriginalName } else { $p.Name }) })
    Save-HTUserProfiles -Profiles (@($others) + @($p))
}

function Edit-HTUserProfile {
    <#
        Formularz profilu tworzenia kont (sekcje). Zwraca profil albo $null. Błędy - komunikat i formularz ponownie
        z wpisanymi wartościami. Licencje, grupy i konto wzorcowe można wybrać z połączonego tenanta.
    #>
    param($UserProfile = $null, [switch]$New)
    $base = if ($UserProfile) { ConvertTo-HTUserProfile $UserProfile } else { ConvertTo-HTUserProfile @{} }
    $original = if ($New) { '' } else { $base.Name }
    $domains = @()
    if ($Global:ConnectedToGraphAPI) { try { $domains = @(Get-HTM365Domains) } catch { Write-Verbose $_ } }
    $values = $base
    while ($true) {
        $fields = @(
            @{ Type = 'Header'; Label = 'Profil'; Icon = 'E77B'; Hint = 'Profil jest proponowany przy «Utwórz użytkownika…» w tenancie, który ma domenę profilu.' }
            @{ Name = 'Name'; Label = 'Nazwa profilu (np. nazwa klienta)'; Required = $true; Default = $values.Name }
            @{ Name = 'Domain'; Label = 'Domena kont (część UPN po @, puste - każdy tenant)'; Type = 'Combo'; Editable = $true; Options = $domains; Default = $values.Domain }
            @{ Name = 'LoginFormat'; Label = 'Format loginu'; Type = 'Combo'; Editable = $true; Options = @(Get-HTLoginFormats | ForEach-Object { $_.Format }); Default = $values.LoginFormat; Hint = '{imie}, {nazwisko}, {i} - pierwsza litera imienia, {n} - nazwiska. Np. {i}.{nazwisko} - j.kowalski. Polskie znaki są zamieniane.' }
            @{ Name = 'UsageLocation'; Label = 'Lokalizacja użycia (kod kraju)'; Default = $values.UsageLocation; Placeholder = 'PL' }
            @{ Name = 'Notes'; Label = 'Notatki'; Default = $values.Notes }
            @{ Type = 'Header'; Label = 'Dane konta'; Icon = 'E779'; Hint = 'Wartości domyślne w formularzu nowego konta (można je zmienić przy tworzeniu).' }
            @{ Name = 'JobTitle'; Label = 'Stanowisko'; Default = $values.JobTitle }
            @{ Name = 'Department'; Label = 'Dział'; Default = $values.Department }
            @{ Name = 'CompanyName'; Label = 'Firma'; Default = $values.CompanyName }
            @{ Name = 'OfficeLocation'; Label = 'Biuro'; Default = $values.OfficeLocation }
            @{ Name = 'ForceChange'; Label = 'Zmiana hasła przy pierwszym logowaniu'; Type = 'Check'; Default = $values.ForceChange }
            @{ Type = 'Header'; Label = 'Licencje i grupy'; Icon = 'E8EC'; Hint = 'Przypisywane po utworzeniu konta. Grupy dynamiczne i synchronizowane z AD są pomijane.' }
            @{ Name = 'Licenses'; Label = 'Licencje (kody SKU, jeden w wierszu)'; Type = 'Multiline'; Height = 70; Default = ($values.Licenses -join "`r`n") }
            @{ Type = 'Buttons'; Buttons = @(@{ Text = 'Wybierz licencje z tenanta…'; Icon = 'E8EC'; OnClick = {
                            param($w)
                            if (-not (Assert-HTConnection -Service 'Graph')) { return }
                            $items = @(Get-HTSubscribedSkus -Force | ForEach-Object { [PSCustomObject]@{ Licencja = (Get-HTSkuFriendlyName $_.SkuPartNumber); SKU = $_.SkuPartNumber; Wolne = $_.Available } })
                            $sel = @(Show-HTSelectionDialog -Title 'Licencje profilu' -Items $items -Columns @(@{ Text = 'Licencja'; Property = 'Licencja' }, @{ Text = 'SKU'; Property = 'SKU' }, @{ Text = 'Wolne'; Property = 'Wolne' }) -MultiSelect -Icon 'E8EC')
                            if ($sel.Count) { $box = $w.Tag.Controls['Licenses'].Control; $box.Text = (@(ConvertTo-HTStringList @($box.Text, @($sel | Where-Object { $_ } | ForEach-Object { $_.SKU })))) -join "`r`n" }
                        }
                    }) }
            @{ Name = 'Groups'; Label = 'Grupy (nazwy, jedna w wierszu)'; Type = 'Multiline'; Height = 90; Default = ($values.Groups -join "`r`n") }
            @{ Type = 'Buttons'; Buttons = @(@{ Text = 'Wybierz grupy z tenanta…'; Icon = 'E902'; OnClick = {
                            param($w)
                            if (-not (Assert-HTConnection -Service 'Graph')) { return }
                            $groups = @(Get-HTM365Groups | Where-Object { Test-HTM365GroupManageable -Group $_ })
                            $sel = @(Show-HTSelectionDialog -Title 'Grupy profilu' -Items $groups -Columns @(@{ Text = 'Nazwa'; Property = 'DisplayName' }, @{ Text = 'Typ'; Property = 'Type' }, @{ Text = 'E-mail'; Property = 'Mail' }) -MultiSelect -Icon 'E902')
                            if ($sel.Count) { $box = $w.Tag.Controls['Groups'].Control; $box.Text = (@(ConvertTo-HTStringList @($box.Text, @($sel | Where-Object { $_ } | ForEach-Object { $_.DisplayName })))) -join "`r`n" }
                        }
                    }) }
            @{ Name = 'TemplateUser'; Label = 'Konto wzorcowe - nowe konto dostanie jego grupy (UPN, opcjonalnie)'; Default = $values.TemplateUser }
            @{ Type = 'Buttons'; Buttons = @(@{ Text = 'Wybierz konto…'; Icon = 'E77B'; OnClick = { param($w) $u = Select-HTM365User -Title 'Konto wzorcowe profilu'; if ($u) { $w.Tag.Controls['TemplateUser'].Control.Text = [string]$u.UserPrincipalName } } }) }
        )
        $form = Show-HTFormDialog -Title $(if ($New) { 'Nowy profil konta' } else { "Profil konta: $original" }) -Fields $fields -Sections -Width 940 -MaxHeight 520 -Icon 'E77B' -OkText 'Zapisz'
        if (-not $form) { return $null }
        $candidate = ConvertTo-HTUserProfile $form
        $candidate.LastUsed = $base.LastUsed
        $errors = @(Test-HTUserProfile -UserProfile $candidate -Existing @(Get-HTUserProfiles) -OriginalName $original)
        if (-not $errors.Count) { return $candidate }
        Show-HTWarning -Title 'Profil konta' -Text ("Popraw:`n`n" + ($errors -join "`n"))
        $values = $candidate
    }
}

function Show-HTUserProfilesEditor {
    # Profile tworzenia kont: dodawanie, edycja, duplikat, usuwanie, import i eksport (JSON)
    while ($true) {
        $profiles = @(Get-HTUserProfiles)
        $list = if ($profiles.Count) { "Profili: $($profiles.Count)`n$(@($profiles | Select-Object -First 10 | ForEach-Object { "• $($_.Name) - $(Get-HTUserProfileDescription $_)" }) -join "`n")" } else { 'Brak profili. Profil zapamiętuje, jak tworzyć konta u danego klienta: format loginu, domenę, firmę, licencje, grupy i konto wzorcowe.' }
        $choices = @(
            @{ Key = 'Add'; Text = 'Nowy profil…'; Icon = 'E710'; Style = 'Create'; Description = 'Np. dla klienta albo działu' }
            if ($profiles.Count) { @{ Key = 'Edit'; Text = 'Edytuj profil…'; Icon = 'E70F' } }
            if ($profiles.Count) { @{ Key = 'Copy'; Text = 'Duplikuj profil…'; Icon = 'E8C8'; Description = 'Nowy profil na podstawie istniejącego' } }
            @{ Key = 'Import'; Text = 'Import z pliku…'; Icon = 'E8B5'; Style = 'Create'; Description = 'Plik JSON z eksportu (np. z innego komputera)' }
            if ($profiles.Count) { @{ Key = 'Export'; Text = 'Eksport do pliku…'; Icon = 'EDE1' } }
            if ($profiles.Count) { @{ Key = 'Remove'; Text = 'Usuń profile…'; Icon = 'E74D'; Style = 'Danger' } }
        )
        $choice = Show-HTChoiceDialog -Title 'Profile tworzenia kont' -Prompt $list -Icon 'E77B' -Choices $choices
        $pickProfile = {
            param([string]$Title)
            $key = Show-HTChoiceDialog -Title $Title -Icon 'E77B' -Choices @($profiles | ForEach-Object { @{ Key = $_.Name; Text = $_.Name; Icon = 'E77B'; Description = (Get-HTUserProfileDescription $_) } })
            if ($key) { @($profiles | Where-Object { $_.Name -eq $key })[0] }
        }
        switch ($choice) {
            'Add' { $edited = Edit-HTUserProfile -New; if ($edited) { Save-HTUserProfile -UserProfile $edited; Write-Log -Message "Zapisano profil konta: $($edited.Name)" -Type 'Info' } }
            'Edit' {
                $p = & $pickProfile 'Edytuj profil'
                if ($p) { $edited = Edit-HTUserProfile -UserProfile $p; if ($edited) { Save-HTUserProfile -UserProfile $edited -OriginalName $p.Name; Write-Log -Message "Zmieniono profil konta: $($edited.Name)" -Type 'Info' } }
            }
            'Copy' {
                $p = & $pickProfile 'Duplikuj profil'
                if ($p) { $copy = ConvertTo-HTUserProfile $p; $copy.Name = "$($p.Name) (kopia)"; $copy.LastUsed = ''; $edited = Edit-HTUserProfile -UserProfile $copy -New; if ($edited) { Save-HTUserProfile -UserProfile $edited } }
            }
            'Import' {
                $path = Select-HTOpenFile -Title 'Import profili kont' -Filter 'JSON (*.json)|*.json|Wszystkie pliki (*.*)|*.*'
                if (-not $path) { continue }
                try { $incoming = @(Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop | ForEach-Object { $_ }) }
                catch { Show-HTError 'Nie odczytano pliku profili.' $_; continue }
                $same = @($incoming | Where-Object { $n = [string]$_.Name; @($profiles | Where-Object { $_.Name -ieq $n }).Count })
                $skip = $false
                if ($same.Count) {
                    $mode = Show-HTChoiceDialog -Title 'Import profili kont' -Prompt "Profile w pliku: $($incoming.Count), w tym o istniejących nazwach: $($same.Count)." -Icon 'E8B5' -Choices @(
                        @{ Key = 'Replace'; Text = 'Zastąp istniejące profile'; Icon = 'E72C' }
                        @{ Key = 'Skip'; Text = 'Pomiń istniejące profile'; Icon = 'E8FB' }
                    )
                    if (-not $mode) { continue }
                    $skip = ($mode -eq 'Skip')
                }
                $merge = Merge-HTUserProfiles -Existing $profiles -Incoming $incoming -Skip:$skip
                Save-HTUserProfiles -Profiles $merge.Profiles
                Write-Log -Message "Profile kont z pliku $(Split-Path $path -Leaf): dodane $($merge.Added), zastąpione $($merge.Replaced), pominięte $($merge.Skipped)." -Type 'Info&Notification'
            }
            'Export' {
                $path = Select-HTSaveFile -Title 'Eksport profili kont' -Filter 'JSON (*.json)|*.json' -FileName 'ProfileKont.json' -DefaultExt '.json'
                if ($path) { Save-HTUserProfiles -Profiles $profiles -Path $path; Show-HTToast "Zapisano profile: $($profiles.Count)." 'ok' }
            }
            'Remove' {
                $rows = @($profiles | ForEach-Object { [PSCustomObject]@{ Nazwa = $_.Name; Opis = (Get-HTUserProfileDescription $_) } })
                $sel = @(Show-HTSelectionDialog -Title 'Usuń profile kont' -Items $rows -Columns @(@{ Text = 'Nazwa'; Property = 'Nazwa' }, @{ Text = 'Opis'; Property = 'Opis' }) -MultiSelect -OkText 'Usuń' -Icon 'E74D')
                $names = @($sel | Where-Object { $_ } | ForEach-Object { $_.Nazwa })
                if ($names.Count -and (Show-HTConfirm -Title 'Usuń profile kont' -Message 'Usunąć zaznaczone profile tworzenia kont?' -Items $names -Danger -ConfirmText 'Usuń')) {
                    Save-HTUserProfiles -Profiles @($profiles | Where-Object { $names -notcontains $_.Name })
                    Write-Log -Message "Usunięto profile kont: $($names -join ', ')" -Type 'Info'
                }
            }
            default { return }
        }
    }
}
#endregion

Register-HTModule -Workspace 'Organization' -Category 'Tworzenie' -Key 'm365.new' -Title 'Nowy użytkownik' -Icon 'E8FA' -Service 'Graph' `
    -Description 'Tworzy konto w chmurze z losowym hasłem; opcjonalnie od razu licencja i grupy skopiowane z użytkownika wzorcowego.' -Build {
    param($m)
    $m.SecretColumns = @('Hasło')
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz użytkownika…' -Create -NoRowMenu -Icon 'E8FA' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'Graph')) { return }
        Set-HTBusy -Busy $true -Text 'Pobieranie domen i licencji…'
        try {
            $domains = @(Get-HTM365Domains)
            $allSkus = @(Get-HTSubscribedSkus -Force | Where-Object { $_.Status -eq 'Enabled' })
            $skus = @($allSkus | Where-Object { $_.Available -gt 0 })
        }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        # Profil tworzenia kont (np. klienta): format loginu, domena, dane firmy, licencje, grupy i konto wzorcowe
        $userProfile = $null
        $profiles = @(Find-HTUserProfilesForDomains -Profiles @(Get-HTUserProfiles) -Domains $domains)
        if ($profiles.Count) {
            $choices = @(@($profiles | ForEach-Object { @{ Key = $_.Name; Text = $_.Name; Icon = 'E77B'; Description = (Get-HTUserProfileDescription $_) } }) + @(@{ Key = '__none'; Text = 'Bez profilu'; Icon = 'E8FA'; Description = 'Puste pola - wszystko ręcznie' }))
            $pick = Show-HTChoiceDialog -Title 'Profil nowego konta' -Prompt 'Profile pasujące do domen tego tenanta (edycja: «Profile kont…»).' -Icon 'E77B' -Choices $choices
            if (-not $pick) { return }
            if ($pick -ne '__none') { $userProfile = @($profiles | Where-Object { $_.Name -eq $pick })[0] }
        }
        $up = $userProfile
        $format = if ($up) { $up.LoginFormat } else { '{imie}.{nazwisko}' }
        $skuOptions = @('(bez licencji)') + @($skus | ForEach-Object { "$(Get-HTSkuFriendlyName $_.SkuPartNumber) [$($_.SkuPartNumber)] - wolne: $($_.Available)" })
        $fields = @(
            if ($up -and $up.Notes) { @{ Type = 'Info'; Label = "Profil «$($up.Name)»: $($up.Notes)" } }
            @{ Name = 'Given'; Label = 'Imię'; Required = $true }
            @{ Name = 'Surname'; Label = 'Nazwisko'; Required = $true }
            @{ Name = 'Login'; Label = 'Login (część UPN przed @)'; Placeholder = "puste = $format, np. $(ConvertTo-HTLoginFromFormat -Format $format -GivenName 'Jan' -Surname 'Kowalski')" }
            @{ Name = 'Domain'; Label = 'Domena'; Type = 'Combo'; Options = $domains; Default = $(if ($up -and $domains -contains $up.Domain) { $up.Domain }) }
            @{ Name = 'JobTitle'; Label = 'Stanowisko'; Default = $(if ($up) { $up.JobTitle }) }
            @{ Name = 'Department'; Label = 'Dział'; Default = $(if ($up) { $up.Department }) }
            @{ Name = 'CompanyName'; Label = 'Firma'; Default = $(if ($up) { $up.CompanyName }) }
            @{ Name = 'OfficeLocation'; Label = 'Biuro'; Default = $(if ($up) { $up.OfficeLocation }) }
            @{ Name = 'UsageLocation'; Label = 'Lokalizacja użycia'; Default = $(if ($up -and $up.UsageLocation) { $up.UsageLocation } else { $Global:DefaultUsageLocation }) }
            if ($up -and $up.Licenses.Count) { @{ Name = 'ProfileLicenses'; Label = "Licencje z profilu: $(@($up.Licenses | ForEach-Object { Get-HTSkuFriendlyName $_ }) -join ', ')"; Type = 'Check'; Default = $true } }
            @{ Name = 'Sku'; Label = $(if ($up -and $up.Licenses.Count) { 'Dodatkowa licencja' } else { 'Licencja' }); Type = 'Combo'; Options = $skuOptions }
            if ($up -and $up.Groups.Count) { @{ Name = 'ProfileGroups'; Label = "Grupy z profilu ($($up.Groups.Count)): $($up.Groups -join ', ')"; Type = 'Check'; Default = $true } }
            if ($up -and $up.TemplateUser) { @{ Name = 'ProfileTemplate'; Label = "Grupy konta wzorcowego z profilu: $($up.TemplateUser)"; Type = 'Check'; Default = $true } }
            @{ Name = 'CopyGroups'; Label = 'Skopiuj grupy z innego użytkownika wzorcowego (wybór po kliknięciu «Utwórz»)'; Type = 'Check' }
            @{ Name = 'Force'; Label = 'Zmiana hasła przy pierwszym logowaniu'; Type = 'Check'; Default = $(if ($up) { $up.ForceChange } else { $true }) }
        )
        $form = Show-HTFormDialog -Title 'Nowy użytkownik Microsoft 365' -Description $(if ($up) { "Profil: $($up.Name)" } else { '' }) -Icon 'E8FA' -OkText 'Utwórz' -Fields $fields
        if (-not $form) { return }
        $login = if ($form.Login) { $form.Login } else { ConvertTo-HTLoginFromFormat -Format $format -GivenName $form.Given -Surname $form.Surname }
        $upn = "$login@$($form.Domain)"
        $template = if ($form.CopyGroups) { Select-HTM365User -Title 'Użytkownik wzorcowy' -Prompt 'Nowe konto otrzyma jego grupy.' } else { $null }
        $sku = if ($form.Sku -and $form.Sku -ne '(bez licencji)') { $skus[[array]::IndexOf($skuOptions, $form.Sku) - 1] } else { $null }
        # Licencje, grupy i konto wzorcowe z profilu
        $profileSkus = @()
        $missingSkus = @()
        if ($form.Contains('ProfileLicenses') -and $form.ProfileLicenses) {
            foreach ($name in @($up.Licenses)) {
                $found = @($allSkus | Where-Object { $_.SkuPartNumber -ieq $name -or "$($_.SkuId)" -ieq $name })[0]
                if ($found) { $profileSkus += $found } else { $missingSkus += $name }
            }
        }
        $profileGroups = if ($form.Contains('ProfileGroups') -and $form.ProfileGroups) { @($up.Groups) } else { @() }
        $profileTemplate = if ($form.Contains('ProfileTemplate') -and $form.ProfileTemplate) { $up.TemplateUser } else { '' }
        $extra = @(
            if ($template) { "Grupy z konta wzorcowego: $(Get-HTM365Label $template)" }
            if ($missingSkus.Count) { "Brak w tenancie licencji z profilu (pominięte): $($missingSkus -join ', ')" }
        )
        if (-not (Confirm-HTChange -Name 'Tworzenie użytkownika' -Labels @($upn) -Summary (@(Get-HTPendingFormSummary) + $extra) -Confirm "Utworzyć konto $($upn)? Hasło zostanie wygenerowane.")) { return }
        Invoke-HTQuery -Module $m -Name 'Tworzenie użytkownika' -KeepResults -Record Change -ScriptBlock {
            $password = New-HTRandomPassword
            $user = New-HTM365User -DisplayName "$($form.Given) $($form.Surname)" -UserPrincipalName $upn -Password $password -GivenName $form.Given -Surname $form.Surname `
                -JobTitle $form.JobTitle -Department $form.Department -CompanyName $form.CompanyName -OfficeLocation $form.OfficeLocation -UsageLocation $form.UsageLocation -ForceChange $form.Force
            $notes = New-Object System.Collections.Generic.List[string]
            $notes.Add('Konto utworzone')
            foreach ($s in @(@($profileSkus) + @($sku) | Where-Object { $_ } | Sort-Object { "$($_.SkuId)" } -Unique)) {
                try { Set-HTM365UserLicense -Id $user.id -AddSkuIds @("$($s.SkuId)") -UsageLocation $form.UsageLocation; $notes.Add("licencja $(Get-HTSkuFriendlyName $s.SkuPartNumber)") }
                catch { $notes.Add("błąd licencji $($s.SkuPartNumber): $($_.Exception.Message)") }
            }
            $newUser = [PSCustomObject]@{ Id = $user.id; UserPrincipalName = $upn }
            $added = 0
            if ($profileGroups.Count) {
                $allGroups = @(Get-HTM365Groups)
                foreach ($gName in $profileGroups) {
                    $g = @($allGroups | Where-Object { $_.DisplayName -ieq $gName -or $_.Mail -ieq $gName -or "$($_.Id)" -eq $gName })[0]
                    if (-not $g) { $notes.Add("nie znaleziono grupy «$gName»"); continue }
                    if (-not (Test-HTM365GroupManageable -Group $g)) { $notes.Add("grupa «$gName» dynamiczna albo z AD - pominięta"); continue }
                    try { Add-HTM365UserToGroup -Group $g -User $newUser; $added++ } catch { $notes.Add("grupa $($gName): $($_.Exception.Message)") }
                }
            }
            $templateIds = @(if ($template) { $template.Id })
            if ($profileTemplate) {
                try { $templateIds += (Invoke-HTGraphRequest -Uri "users/$([uri]::EscapeDataString($profileTemplate))?`$select=id").id }
                catch { $notes.Add("nie znaleziono konta wzorcowego $profileTemplate") }
            }
            $done = @{}
            foreach ($tid in @($templateIds | Where-Object { $_ } | Select-Object -Unique)) {
                foreach ($g in @(Get-HTM365UserGroups -Id $tid | Where-Object { Test-HTM365GroupManageable -Group $_ })) {
                    if ($done.ContainsKey("$($g.Id)")) { continue }
                    $done["$($g.Id)"] = $true
                    try { Add-HTM365UserToGroup -Group $g -User $newUser; $added++ }
                    catch { if ("$($_.Exception.Message)" -notmatch 'already exist|już') { $notes.Add("grupa $($g.DisplayName): $($_.Exception.Message)") } }
                }
            }
            if ($added) { $notes.Add("grup: $added") }
            Write-Log -Message "Utworzono użytkownika M365: $upn$(if ($up) { " (profil $($up.Name))" })" -Type 'Info&Notification'
            [PSCustomObject]@{ Obiekt = $upn; Status = 'OK'; Hasło = $password; Profil = $(if ($up) { $up.Name } else { '' }); Szczegóły = ($notes -join '; ') }
        }
        if ($up) { Save-HTUserProfile -UserProfile $up -OriginalName $up.Name -Touch }
        $p = Get-HTPanel 'm365users'
        if ($p) { Invoke-HTPanelLoad -Panel $p -Quiet }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Profile kont…' -Icon 'E77B' -ToolTip 'Profile tworzenia kont (np. dla każdego klienta): format loginu, domena, firma, licencje, grupy, konto wzorcowe' -OnClick { param($m) Show-HTUserProfilesEditor } | Out-Null
    if ($Global:ShowOnPremises) { Add-HTLabel -Parent $row -Hint -Text 'Dla kont synchronizowanych z lokalnym AD użyj przestrzeni «Użytkownicy AD».' | Out-Null }
}

Register-HTModule -Workspace 'M365' -Category 'Cykl życia' -Key 'm365.offboarding' -Title 'Offboarding' -Icon 'E8F8' `
    -Description 'Odejście pracownika w jednym kroku: blokada, wylogowanie, reset hasła, autoodpowiedź i przekierowanie, skrzynka współdzielona, ukrycie w GAL, grupy, MFA i licencje.' -Build {
    param($m)
    Add-HTStateCheck -Module $m -Label { param($t) Get-HTM365Label $t } -Action {
        param($t)
        $state = Get-HTM365AccountState -Id $t.Id
        $licenses = @(Get-HTM365UserLicenses -Id $t.Id | ForEach-Object { Get-HTSkuFriendlyName $_.SkuPartNumber })
        $manager = Get-HTM365UserManager -Id $t.Id
        [PSCustomObject][ordered]@{ Logowanie = $state.Logowanie; 'Ostatnie logowanie' = $state.'Ostatnie logowanie'; Licencje = ($licenses -join ', '); Przełożony = $(if ($manager) { $manager.userPrincipalName }); 'Synchronizowane z AD' = $state.'Synchronizowane z AD'; __flag = $state.__flag }
    } | Out-Null
    $m.SecretColumns = @('Hasło')
    $row0 = Add-HTToolbarRow -Module $m -Title 'Kopia'
    $m.C.Backup = Add-HTCheckBox -Parent $row0 -Text 'Najpierw zapisz kopię ustawień konta (plik do przywrócenia konta)' -Checked $true -ToolTip 'Konto, logowanie, przełożony, licencje, grupy, skrzynka (typ, GAL, przekierowanie, autoodpowiedź) i lista metod MFA - folder eksportu > «Kopie kont». Gdy kopia się nie zapisze, konto jest pomijane.'
    $row = Add-HTToolbarRow -Module $m -Title 'Konto'
    $m.C.Block = Add-HTCheckBox -Parent $row -Text 'Zablokuj logowanie i unieważnij sesje' -Checked $true
    $m.C.Password = Add-HTCheckBox -Parent $row -Text 'Losowe hasło' -Checked $true
    $m.C.Mfa = Add-HTCheckBox -Parent $row -Text 'Usuń metody MFA' -Checked $false
    $row2 = Add-HTToolbarRow -Module $m -Title 'Poczta (Exchange)'
    $m.C.Shared = Add-HTCheckBox -Parent $row2 -Text 'Konwertuj na skrzynkę współdzieloną' -Checked $true -ToolTip 'Skrzynka współdzielona do 50 GB nie wymaga licencji'
    $m.C.Hide = Add-HTCheckBox -Parent $row2 -Text 'Ukryj w książce adresowej' -Checked $true
    $m.C.Forward = Add-HTTextBox -Parent $row2 -Width 240 -Placeholder 'Przekieruj pocztę do (opcjonalnie)'
    Add-HTAddressPicker -Parent $row2 -Module $m -TextBox $m.C.Forward | Out-Null
    $row3 = Add-HTToolbarRow -Module $m -Title 'Autoodpowiedź'
    $m.C.AutoReply = Add-HTTextBox -Parent $row3 -Width 560 -Multiline -Height 54 -Placeholder 'Treść autoodpowiedzi - ta sama dla osób z firmy i spoza firmy (opcjonalnie), np. Pracownik nie pracuje już w firmie. Proszę kontaktować się z ...'
    $row4 = Add-HTToolbarRow -Module $m -Title 'Dostęp'
    $m.C.Groups = Add-HTCheckBox -Parent $row4 -Text 'Usuń z grup' -Checked $true
    $m.C.Licenses = Add-HTCheckBox -Parent $row4 -Text 'Usuń licencje (po konwersji skrzynki)' -Checked $true
    $m.C.Manager = Add-HTCheckBox -Parent $row4 -Text 'Usuń przełożonego' -Checked $false
    $m.C.OneDrive = Add-HTCheckBox -Parent $row4 -Text 'Dostęp przełożonego do OneDrive' -Checked $false -ToolTip 'Przełożony zostaje administratorem OneDrive odchodzącego (PnP, rola SharePoint Administrator) - przed usunięciem przełożonego z konta'
    $actions = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $actions -Module $m -Text 'Wykonaj offboarding' -Icon 'E8F8' -Primary -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $o = @{}
        if (-not (Assert-HTWriteAllowed -Operation 'Offboarding')) { return }
        foreach ($k in 'Backup', 'Block', 'Password', 'Mfa', 'Shared', 'Hide', 'Groups', 'Licenses', 'Manager', 'OneDrive') { $o[$k] = Test-HTChecked $m.C[$k] }
        $o.Forward = $m.C.Forward.Text.Trim()
        $o.AutoReply = $m.C.AutoReply.Text.Trim()
        if ($o.Forward -and -not (Test-HTInputValue -Value $o.Forward -ValidationType Email)) { Show-HTWarning 'Nieprawidłowy adres przekierowania.'; return }
        $needsExchange = $o.Shared -or $o.Hide -or $o.Forward -or $o.AutoReply
        if ($needsExchange -and -not $Global:ConnectedToExchange) {
            if (-not (Show-HTConfirm -Warning -Title 'Offboarding' -Message 'Brak połączenia z Exchange Online - kroki pocztowe zostaną pominięte. Kontynuować?')) { return }
        }
        $steps = @()
        if ($o.Block) { $steps += 'blokada i wylogowanie' }
        if ($o.Password) { $steps += 'reset hasła' }
        if ($o.AutoReply) { $steps += 'autoodpowiedź (w firmie i na zewnątrz)' }
        if ($o.Forward) { $steps += "przekierowanie do $($o.Forward)" }
        if ($o.Shared) { $steps += 'skrzynka współdzielona' }
        if ($o.Hide) { $steps += 'ukrycie w GAL' }
        if ($o.Mfa) { $steps += 'usunięcie MFA' }
        if ($o.OneDrive) { $steps += 'dostęp przełożonego do OneDrive' }
        if ($o.Groups) { $steps += 'usunięcie z grup' }
        if ($o.Manager) { $steps += 'usunięcie przełożonego' }
        if ($o.Licenses) { $steps += 'usunięcie licencji' }
        if ($steps.Count -eq 0) { Show-HTWarning 'Wybierz co najmniej jeden krok.'; return }
        if ($o.Backup) { $steps = @("kopia ustawień konta (plik: $(Get-HTAccountBackupDirectory))") + $steps }
        if (-not (Confirm-HTChange -Danger -Name 'Offboarding' -Confirm 'Wykonać wybrane kroki dla kont?' -Summary $steps -Labels @($targets | ForEach-Object { Get-HTM365Label $_ }) -TypeToConfirm 'OFFBOARDING')) { return }
        $exo = [bool]$Global:ConnectedToExchange
        $adminConnection = $null
        if ($o.OneDrive) {
            try { $adminConnection = Connect-HTPnPReturn -Url (Get-HTSharePointAdminUrl) }
            catch {
                Write-Log -Message "Offboarding - połączenie z centrum administracyjnym SharePoint: $($_.Exception.Message)" -Type 'Warn'
                if (-not (Show-HTConfirm -Warning -Title 'Offboarding' -Message "Nie połączono z centrum administracyjnym SharePoint - krok OneDrive zostanie pominięty. Kontynuować?`n`n$($_.Exception.Message)")) { return }
                $o.OneDrive = $false
            }
        }
        Reset-HTResults -Module $m
        Set-HTBusy -Busy $true -Text 'Offboarding…'
        try {
            $i = 0
            foreach ($t in $targets) {
                $i++
                $label = Get-HTM365Label $t
                Set-HTProgress -Value $i -Maximum $targets.Count -Text "Offboarding [$i/$($targets.Count)] $label"
                $run = {
                    param([string]$Step, [scriptblock]$Do)
                    $r = [ordered]@{ Obiekt = $label; Krok = $Step; Status = 'OK'; Szczegóły = ''; Hasło = '' }
                    try {
                        $out = & $Do
                        if ($out -is [hashtable]) { foreach ($k in $out.Keys) { $r[$k] = $out[$k] } } elseif ($out) { $r.Szczegóły = [string]$out }
                    }
                    catch { $r.Status = 'Błąd'; $r.Szczegóły = $_.Exception.Message }
                    Write-Log -Message "Offboarding $label - $($Step): $($r.Status) $(if ($r.Status -ne 'OK') { $r.Szczegóły })" -Type $(if ($r.Status -eq 'Błąd') { 'Warn' } else { 'Info' })
                    Add-HTOperationRecord -Operation "Offboarding: $Step" -Object $label -Status $r.Status -Details $(if ($r.Hasło) { '' } else { $r.Szczegóły }) -Module 'Offboarding' 
                    Add-HTResultRows -Module $m -Objects @([PSCustomObject]$r)
                    $r.Status
                }
                $mailbox = $t.UserPrincipalName
                # Kopia ustawień przed zmianami - bez kopii konto jest pomijane (żeby dało się je przywrócić)
                if ($o.Backup) {
                    $backupStatus = & $run 'Kopia ustawień konta' {
                        $backup = Get-HTM365AccountBackup -Id $t.Id
                        if ($exo) { try { $backup.Mailbox = Get-HTMailboxBackupInfo -Identity $mailbox } catch { $backup.MailboxError = $_.Exception.Message } }
                        "Zapisano: $(Save-HTAccountBackup -Backup $backup)"
                    }
                    if ($backupStatus -ne 'OK') {
                        Add-HTResultRows -Module $m -Objects @([PSCustomObject][ordered]@{ Obiekt = $label; Krok = 'Pozostałe kroki'; Status = 'Pominięto'; Szczegóły = 'Nie zapisano kopii ustawień - konto bez zmian'; Hasło = ''; __flag = 'warn' })
                        continue
                    }
                }
                if ($o.Block) { & $run 'Blokada i wylogowanie' { Set-HTM365UserEnabled -Id $t.Id -Enabled $false -RevokeSessions $true; Update-HTM365PanelUser -User $t -Changes @{ AccountEnabled = $false } } }
                if ($o.Password) { & $run 'Reset hasła' { $pw = New-HTRandomPassword; Reset-HTM365UserPassword -Id $t.Id -Password $pw -ForceChange $true; @{ Hasło = $pw } } }
                if ($exo) {
                    if ($o.AutoReply) { & $run 'Autoodpowiedź' { Set-HTMailboxAutoReply -Identity $mailbox -State Enabled -InternalMessage $o.AutoReply -ExternalMessage $o.AutoReply -ExternalAudience All } }
                    if ($o.Forward) { & $run 'Przekierowanie' { Set-HTMailboxForwarding -Identity $mailbox -ForwardTo $o.Forward -KeepCopy $true; "Do: $($o.Forward)" } }
                    if ($o.Shared) { & $run 'Skrzynka współdzielona' { Convert-HTMailboxType -Identity $mailbox -Type Shared } }
                    if ($o.Hide) { & $run 'Ukrycie w GAL' { Set-HTMailboxHiddenFromGAL -Identity $mailbox -Hidden $true } }
                }
                if ($o.Mfa) {
                    & $run 'Usunięcie metod MFA' {
                        $removed = 0
                        foreach ($method in @(Get-HTM365AuthMethods -Id $t.Id | Where-Object Removable)) { Remove-HTM365AuthMethod -UserId $t.Id -Method $method; $removed++ }
                        "Usunięto: $removed"
                    }
                }
                if ($o.Groups) {
                    & $run 'Usunięcie z grup' {
                        $removed = @()
                        $skipped = 0
                        foreach ($g in @(Get-HTM365UserGroups -Id $t.Id)) {
                            if (-not (Test-HTM365GroupManageable -Group $g)) { $skipped++; continue }
                            if ($g.Type -in 'Dystrybucyjna', 'Zabezpieczeń (mail)' -and -not $exo) { $skipped++; continue }
                            Remove-HTM365UserFromGroup -Group $g -User $t
                            $removed += $g.DisplayName
                        }
                        "Usunięto z: $($removed.Count)$(if ($skipped) { ", pominięto (dynamiczne/AD/pocztowe): $skipped" })"
                    }
                }
                if ($o.OneDrive) {
                    & $run 'Dostęp przełożonego do OneDrive' {
                        $mgr = Get-HTM365UserManager -Id $t.Id
                        if (-not $mgr) { throw 'konto nie ma przełożonego (ustaw go w module «Przełożony»)' }
                        $site = Grant-HTOneDriveAccess -UserId $t.Id -GrantTo @($mgr.userPrincipalName) -AdminConnection $adminConnection
                        "$($mgr.userPrincipalName) - $site"
                    }
                }
                if ($o.Manager) { & $run 'Usunięcie przełożonego' { if (Get-HTM365UserManager -Id $t.Id) { Remove-HTM365UserManager -Id $t.Id; 'Usunięto' } else { 'Brak przełożonego' } } }
                if ($o.Licenses) {
                    & $run 'Usunięcie licencji' {
                        $ids = @(Get-HTM365UserLicenses -Id $t.Id | ForEach-Object { "$($_.SkuId)" })
                        if ($ids.Count -eq 0) { return 'Brak licencji' }
                        Set-HTM365UserLicense -Id $t.Id -RemoveSkuIds $ids
                        "Usunięto licencji: $($ids.Count)"
                    }
                }
            }
        }
        finally { Set-HTBusy -Busy $false -Text 'Offboarding zakończony' }
        $failed = @($m.Table.Select("Status LIKE 'Błąd*'")).Count
        Show-HTToast "Offboarding zakończony$(if ($failed) { " - błędy: $failed" })." $(if ($failed) { 'warn' } else { 'ok' })
        [void](Send-HTTeamsMessage -Event 'Offboarding' -Title 'Offboarding zakończony' -Tone $(if ($failed) { 'warn' } else { 'ok' }) -Text "Kroki: $($steps -join ', ')." -Facts ([ordered]@{ Konta = (@($targets | ForEach-Object { Get-HTM365Label $_ }) -join ', '); Błędy = "$failed" }))
    } | Out-Null
    Add-HTButton -Parent $actions -Module $m -Text 'Przywróć z kopii…' -Icon 'E777' -Danger -NoRowMenu -ToolTip 'Przywrócenie konta po offboardingu z pliku kopii ustawień (folder eksportu > «Kopie kont»)' -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'Graph')) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Przywrócenie konta')) { return }
        $path = Select-HTOpenFile -Title 'Kopia ustawień konta' -Filter 'Kopia konta (*.json)|*.json|Wszystkie pliki (*.*)|*.*' -InitialDirectory (Get-HTAccountBackupDirectory)
        if (-not $path) { return }
        try { $backup = Read-HTAccountBackup -Path $path }
        catch { Show-HTError 'Nie odczytano kopii ustawień konta.' $_; return }
        $plan = @(Get-HTAccountRestorePlan -Backup $backup)
        $exo = [bool]$Global:ConnectedToExchange
        $fields = @(
            @{ Type = 'Info'; Label = (Get-HTAccountBackupSummary -Backup $backup) }
            foreach ($s in $plan) {
                $blocked = $s.Service -eq 'Exchange' -and -not $exo
                @{ Name = $s.Key; Label = "$($s.Text)$(if ($blocked) { ' - wymaga połączenia z Exchange (pominięte)' })"; Type = 'Check'; Default = ($s.Default -and -not $blocked) }
            }
        )
        $form = Show-HTFormDialog -Title "Przywrócenie konta: $($backup.User.UserPrincipalName)" -Description 'Zaznacz, co przywrócić z kopii.' -Icon 'E777' -OkText 'Dalej' -Width 700 -Fields $fields
        if (-not $form) { return }
        $chosen = @($plan | Where-Object { $form[$_.Key] -and ($_.Service -ne 'Exchange' -or $exo) })
        if ($chosen.Count -eq 0) { Show-HTWarning 'Nie wybrano żadnego kroku.'; return }
        $upn = [string]$backup.User.UserPrincipalName
        $id = [string]$backup.User.Id
        if (-not (Confirm-HTChange -Name 'Przywrócenie konta' -Labels @($upn) -Summary @($chosen | ForEach-Object { $_.Text }) -Confirm "Przywrócić ustawienia konta z kopii $(Split-Path $path -Leaf)?")) { return }
        Reset-HTResults -Module $m
        Set-HTBusy -Busy $true -Text "Przywracanie konta $upn…"
        try {
            $run = {
                param([string]$Step, [scriptblock]$Do)
                $r = [ordered]@{ Obiekt = $upn; Krok = $Step; Status = 'OK'; Szczegóły = ''; Hasło = '' }
                try {
                    $out = & $Do
                    if ($out -is [hashtable]) { foreach ($k in $out.Keys) { $r[$k] = $out[$k] } } elseif ($out) { $r.Szczegóły = [string]$out }
                }
                catch { $r.Status = 'Błąd'; $r.Szczegóły = $_.Exception.Message }
                Write-Log -Message "Przywrócenie konta $upn - $($Step): $($r.Status) $(if ($r.Status -ne 'OK') { $r.Szczegóły })" -Type $(if ($r.Status -eq 'Błąd') { 'Warn' } else { 'Info' })
                Add-HTOperationRecord -Operation "Przywrócenie konta: $Step" -Object $upn -Status $r.Status -Details $(if ($r.Hasło) { '' } else { $r.Szczegóły }) -Module 'Offboarding'
                Add-HTResultRows -Module $m -Objects @([PSCustomObject]$r)
            }
            foreach ($s in $chosen) {
                switch ($s.Key) {
                    'Enable' { & $run $s.Text { Set-HTM365UserEnabled -Id $id -Enabled $true; 'Logowanie dozwolone' } }
                    'Password' { & $run $s.Text { $pw = New-HTRandomPassword; Reset-HTM365UserPassword -Id $id -Password $pw -ForceChange $true; @{ Hasło = $pw } } }
                    'Manager' { & $run $s.Text { Set-HTM365UserManager -Id $id -ManagerId ([string]$backup.Manager.Id); 'Ustawiono' } }
                    'Licenses' {
                        & $run $s.Text {
                            $current = @(Get-HTM365UserLicenses -Id $id | ForEach-Object { "$($_.SkuId)" })
                            $added = @()
                            $failedLicenses = @()
                            foreach ($l in @($backup.Licenses | Where-Object { $_.Direct })) {
                                if ($current -contains [string]$l.SkuId) { continue }
                                try { Set-HTM365UserLicense -Id $id -AddSkuIds @([string]$l.SkuId) -UsageLocation ([string]$backup.User.UsageLocation); $added += [string]$l.Name }
                                catch { $failedLicenses += "$($l.Name): $($_.Exception.Message)" }
                            }
                            if (-not $added.Count -and $failedLicenses.Count) { throw ($failedLicenses -join '; ') }
                            "Przypisano: $(if ($added.Count) { $added -join ', ' } else { 'nic - licencje już są' })$(if ($failedLicenses.Count) { "; nie przypisano: $($failedLicenses -join '; ')" })"
                        }
                    }
                    'Groups' {
                        & $run $s.Text {
                            $current = @(Get-HTM365UserGroups -Id $id | ForEach-Object { "$($_.Id)" })
                            $member = [PSCustomObject]@{ Id = $id; UserPrincipalName = $upn }
                            $added = 0
                            $failedGroups = @()
                            foreach ($g in @($backup.Groups | Where-Object { -not $_.Dynamic -and -not $_.Synced })) {
                                if ($current -contains [string]$g.Id) { continue }
                                if ($g.Type -in 'Dystrybucyjna', 'Zabezpieczeń (mail)' -and -not $exo) { $failedGroups += "$($g.DisplayName): wymaga Exchange"; continue }
                                try { Add-HTM365UserToGroup -Group ([PSCustomObject]$g) -User $member; $added++ } catch { $failedGroups += "$($g.DisplayName): $($_.Exception.Message)" }
                            }
                            if (-not $added -and $failedGroups.Count) { throw ($failedGroups -join '; ') }
                            "Dodano do grup: $added$(if ($failedGroups.Count) { "; nie dodano: $($failedGroups -join '; ')" })"
                        }
                    }
                    'MailboxType' { & $run $s.Text { Convert-HTMailboxType -Identity $upn -Type Regular; 'Skrzynka użytkownika' } }
                    'Gal' { & $run $s.Text { Set-HTMailboxHiddenFromGAL -Identity $upn -Hidden $false; 'Widoczna' } }
                    'Forwarding' { & $run $s.Text { Set-HTMailboxForwarding -Identity $upn -ForwardTo ([string]$backup.Mailbox.ForwardTo) -KeepCopy ([bool]$backup.Mailbox.KeepCopy); if ($backup.Mailbox.ForwardTo) { "Do: $($backup.Mailbox.ForwardTo)" } else { 'Usunięto' } } }
                    'AutoReply' { & $run $s.Text { Set-HTMailboxAutoReply -Identity $upn -State Disabled; 'Wyłączona' } }
                }
            }
        }
        finally { Set-HTBusy -Busy $false -Text 'Przywracanie zakończone' }
        $failed = @($m.Table.Select("Status LIKE 'Błąd*'")).Count
        Show-HTToast "Przywracanie konta $upn zakończone$(if ($failed) { " - błędy: $failed" })." $(if ($failed) { 'warn' } else { 'ok' })
    } | Out-Null
    Add-HTLabel -Parent $actions -Hint -Text 'Wymaga potwierdzenia słowem OFFBOARDING. Wyniki każdego kroku pojawią się w tabeli. Kopia ustawień - folder eksportu > «Kopie kont».' | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Cykl życia' -Key 'm365.deleted' -Title 'Usunięci użytkownicy' -Icon 'E74D' -Service 'Graph' `
    -Description 'Kosz katalogu: konta usunięte w ciągu 30 dni można przywrócić razem ze skrzynką, OneDrive i członkostwem.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż usuniętych' -Icon 'E72C' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Usunięci użytkownicy' -ScriptBlock { Get-HTM365DeletedUsers } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Usuń zaznaczone konta…' -Icon 'E74D' -Danger -ToolTip 'Usuwa konta zaznaczone na liście po lewej (trafiają do kosza na 30 dni)' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie konta' -Danger -TypeToConfirm 'USUŃ' -Confirm 'Usunąć wybrane konta? Można je przywrócić w ciągu 30 dni.' -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            Remove-HTM365User -Id $t.Id
            $p = Get-HTPanel 'm365users'
            if ($p) { Remove-HTTargetItem -Panel $p -Item $t }
            'Konto usunięte (kosz 30 dni)'
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Przywróć konto' -Icon 'E777' -Create -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Przywrócenie konta' -Rows $rows -Confirm 'Przywrócić zaznaczone konta?' -Action { param($r) Restore-HTM365DeletedUser -Id $r.Id | Out-Null } `
            -Refresh { param($m) Invoke-HTQuery -Module $m -Name 'Usunięci użytkownicy' -ScriptBlock { Get-HTM365DeletedUsers } }
    }
    Add-HTRowAction -Module $m -Text 'Usuń trwale' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Trwałe usunięcie' -Rows $rows -Danger -TypeToConfirm 'USUŃ' -Confirm 'Trwale usunąć zaznaczone konta? Operacji nie można cofnąć.' -Action { param($r) Remove-HTM365DeletedUser -Id $r.Id } `
            -Refresh { param($m) Invoke-HTQuery -Module $m -Name 'Usunięci użytkownicy' -ScriptBlock { Get-HTM365DeletedUsers } }
    }
}
#endregion

#region Akcje na kontach z dowolnych wyników (prawy przycisk > «Konto Microsoft 365»)
function ConvertTo-HTGraphUserKey {
    # UPN gościa (z #EXT#) w adresie zapytania Graph
    param([string]$Id)
    return ($Id -replace '#', '%23')
}

Register-HTObjectKind -Kind 'M365User' -Title 'Konto Microsoft 365' -Icon 'E77B' -Service 'Graph' -Workspaces @('Dashboard', 'Organization', 'M365', 'Groups', 'Security', 'Exchange', 'Intune', 'Sites', 'SharePoint', 'Tasks') -Resolve {
    param($o)
    foreach ($n in 'UPN', 'UserPrincipalName', 'Konto', 'Użytkownik') {
        $p = $o.PSObject.Properties[$n]
        if ($p -and "$($p.Value)" -match '^[^@\s]+@[^@\s]+\.[^@\s]+$') { return "$($p.Value)" }
    }
    $p = $o.PSObject.Properties['UserId']
    if ($p -and "$($p.Value)" -match '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') { return "$($p.Value)" }
    return $null
}
Register-HTObjectAction -Kind 'M365User' -Text 'Szczegóły konta' -Icon 'E8A1' -View -Action {
    param($Id, $Row)
    Set-HTBusy -Busy $true -Text "Szczegóły konta $Id…"
    try { $rows = @(ConvertTo-HTDetailRows -Data (Get-HTM365UserDetail -Id (ConvertTo-HTGraphUserKey $Id))) } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
    Show-HTDataViewer -Title "Konto: $Id" -Data $rows -ExportName "konto_$Id" -Icon 'E77B'
}
Register-HTObjectAction -Kind 'M365User' -Text 'Stan konta (logowanie, sesje)' -Icon 'E946' -View -Action {
    param($Id, $Row)
    Set-HTBusy -Busy $true -Text "Stan konta $Id…"
    try { $state = Get-HTM365AccountState -Id (ConvertTo-HTGraphUserKey $Id) } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
    Show-HTDataViewer -Title "Stan konta: $Id" -Data @($state) -ExportName "stan_$Id" -Icon 'E946'
}
Register-HTObjectAction -Kind 'M365User' -Text 'Zablokuj logowanie' -Icon 'E72E' -Danger -Name 'Blokada logowania' -Confirm 'Zablokować logowanie i unieważnić wszystkie sesje zaznaczonych kont?' -Action {
    param($Id, $Row)
    $key = ConvertTo-HTGraphUserKey $Id
    Set-HTM365UserEnabled -Id $key -Enabled $false -RevokeSessions $true
    Register-HTUndo -Operation 'Blokada logowania' -Object $Id -Kind 'UserEnabled' -Data @{ UserId = $key; Enabled = $true }
    'Logowanie zablokowane, sesje unieważnione'
}
Register-HTObjectAction -Kind 'M365User' -Text 'Odblokuj logowanie' -Icon 'E785' -Danger -Name 'Odblokowanie logowania' -Confirm 'Odblokować logowanie zaznaczonych kont?' -Action {
    param($Id, $Row)
    $key = ConvertTo-HTGraphUserKey $Id
    Set-HTM365UserEnabled -Id $key -Enabled $true
    Register-HTUndo -Operation 'Odblokowanie logowania' -Object $Id -Kind 'UserEnabled' -Data @{ UserId = $key; Enabled = $false }
    'Logowanie odblokowane'
}
Register-HTObjectAction -Kind 'M365User' -Text 'Unieważnij sesje' -Icon 'E7E8' -Danger -Name 'Unieważnienie sesji' -Confirm 'Wylogować zaznaczone konta ze wszystkich aplikacji i urządzeń?' -Action {
    param($Id, $Row)
    Revoke-HTM365UserSessions -Id (ConvertTo-HTGraphUserKey $Id)
    'Sesje unieważnione'
}
#endregion

#region Raporty
function Register-HTM365Report {
    # -Prepare { param($m) }: przed raportem w wątku okna (np. pytanie o uprawnienia); $false - raport nie startuje
    param([string]$Key, [string]$Title, [string]$Icon, [string]$Description, [scriptblock]$Query, [switch]$Days, [int]$DefaultDays = 0, [string]$DaysLabel = 'Dni:', [scriptblock]$Extra, [scriptblock]$Prepare)
    Register-HTModule -Workspace 'M365' -Category 'Raporty' -Key $Key -Title $Title -Icon $Icon -Service 'Graph' -Description $Description -Build {
        param($m)
        $def = $script:M365ReportDefs[$m.Key]
        foreach ($k in $def.Keys) { $m.Data[$k] = $def[$k] }
        $row = Add-HTToolbarRow -Module $m
        if ($m.Data.Days) {
            Add-HTLabel -Parent $row -Text $m.Data.DaysLabel | Out-Null
            $m.C.Days = Add-HTNumeric -Parent $row -Value $m.Data.DefaultDays -Minimum 1 -Maximum 3650
        }
        if ($m.Data.Extra) { & $m.Data.Extra $m $row }
        Add-HTButton -Parent $row -Module $m -Text 'Generuj raport' -Icon 'E9D2' -Primary -OnClick {
            param($m)
            $days = if ($m.C.Days) { Get-HTNum $m.C.Days } else { 0 }
            if ($m.Data.Prepare -and (& $m.Data.Prepare $m) -eq $false) { return }
            $query = $m.Data.Query
            Invoke-HTQuery -Module $m -Name $m.Title -ScriptBlock { & $query $m $days }
        } | Out-Null
        Add-HTRowAction -Module $m -Text 'Zaznacz na liście użytkowników' -Icon 'E8B3' -Action {
            param($m, $rows)
            $p = Get-HTPanel 'm365users'
            $ids = @($rows | ForEach-Object { if ($_.Id) { [string]$_.Id } })
            $found = 0
            foreach ($r in $p.Table.Rows) { if ($ids -contains [string]$r['Key']) { $r['Sel'] = $true; $found++ } }
            Update-HTTargetCount $p
            Show-HTToast "Zaznaczono na liście: $found (np. do blokady lub offboardingu)." 'ok'
        }
    }
    # Parametry raportu trafiają do kontekstu modułu przy pierwszym otwarciu
    $script:M365ReportDefs[$Key] = @{ Query = $Query; Days = [bool]$Days; DefaultDays = $DefaultDays; DaysLabel = $DaysLabel; Extra = $Extra; Prepare = $Prepare }
}
$script:M365ReportDefs = @{}

Register-HTM365Report -Key 'm365.rep.inactive' -Title 'Nieaktywni użytkownicy' -Icon 'E916' -Days -DefaultDays (Get-HTInactiveDaysDefault) -DaysLabel 'Bez logowania od (dni):' `
    -Description 'Konta bez logowania (interaktywnego i nieinteraktywnego) od wskazanej liczby dni. Wyróżnione - z przypisanymi licencjami (koszt).' `
    -Extra { param($m, $row) $m.C.Disabled = Add-HTCheckBox -Parent $row -Text 'Także zablokowane'; $m.C.Guests = Add-HTCheckBox -Parent $row -Text 'Także goście' } `
    -Query { param($m, $days) Get-HTM365InactiveUsers -Days $days -IncludeDisabled:(Test-HTChecked $m.C.Disabled) -IncludeGuests:(Test-HTChecked $m.C.Guests) }
Register-HTM365Report -Key 'm365.rep.guests' -Title 'Goście' -Icon 'E8D4' -Description 'Konta gości: stan zaproszenia i ostatnie logowanie. Wyróżnione - nieaktywne ponad 90 dni.' -Query { param($m, $days) Get-HTM365GuestUsers }
function Invoke-HTPerUserMfaAction {
    <#
        MFA na koncie (per-user MFA) dla zaznaczonych wierszy raportu - tenanty bez Entra ID P1 i dostępu warunkowego.
        enabled - konto objęte MFA, rejestracja metody przy najbliższym logowaniu (potem Microsoft zmienia stan na
        «wymuszone»); enforced - MFA wymagane przy każdym logowaniu; disabled - wyłączenie. Wpis do «Cofanie zmian».
    #>
    param([Parameter(Mandatory)][hashtable]$Module, [AllowEmptyCollection()][object[]]$Rows, [Parameter(Mandatory)][ValidateSet('enabled', 'enforced', 'disabled')][string]$State)
    $targets = @($Rows | Where-Object { $_ -and $_.Id })
    if (-not $targets.Count) { Show-HTWarning 'Zaznacz konta w wynikach raportu.'; return }
    if (-not (Assert-HTGraphScopes -Scopes @('Policy.ReadWrite.AuthenticationMethod') -Feature 'MFA na koncie (per-user)')) { return }
    $label = Get-HTPerUserMfaStateLabel $State
    $summary = New-Object System.Collections.Generic.List[string]
    $summary.Add("MFA na koncie (per-user): $($label.ToLowerInvariant())")
    switch ($State) {
        'enabled' { $summary.Add('Konto musi zarejestrować metodę MFA przy najbliższym logowaniu; po rejestracji stan zmieni się na «wymuszone».') }
        'enforced' { $summary.Add('MFA będzie wymagane przy każdym logowaniu. Konto bez zarejestrowanej metody zarejestruje ją przy logowaniu; stare aplikacje bez nowoczesnego uwierzytelniania potrzebują haseł aplikacji.') }
        'disabled' { $summary.Add('Konto przestanie wymagać MFA przy logowaniu (zarejestrowane metody zostają).') }
    }
    if ((Get-HTSecurityDefaultsState) -eq $true) { $summary.Add('Uwaga: w tenancie są włączone ustawienia domyślne zabezpieczeń (Security Defaults) - one same wymagają MFA, a Microsoft nie zaleca łączenia ich z MFA na koncie.') }
    $before = @{}
    try { $before = Get-HTM365PerUserMfaStates -Ids @($targets | ForEach-Object { [string]$_.Id }) } catch { Write-Log -Message "MFA na koncie - odczyt stanu przed zmianą: $($_.Exception.Message)" -Type 'Warn' }
    Invoke-HTRowAction -Module $Module -Name "MFA na koncie: $($label.ToLowerInvariant())" -Rows $targets -Danger -Summary $summary.ToArray() -Label { param($r) [string]$r.UPN } -Action {
        param($r)
        $previous = [string]$before[[string]$r.Id]
        Set-HTM365PerUserMfaState -Id $r.Id -State $State
        if ($previous -and $previous -ne $State) { Register-HTUndo -Operation "MFA na koncie: $label" -Object ([string]$r.UPN) -Kind 'PerUserMfa' -Data @{ UserId = [string]$r.Id; State = $previous } }
        "MFA na koncie: $(if ($previous) { "$(Get-HTPerUserMfaStateLabel $previous) -> " })$label"
    } -Refresh { param($m) Invoke-HTModulePrimary $m }
}

Register-HTM365Report -Key 'm365.rep.mfa' -Title 'Rejestracja MFA' -Icon 'E928' `
    -Description 'Kto nie ma zarejestrowanego MFA (czerwone - administratorzy bez MFA), data utworzenia konta i stan MFA na koncie (per-user). Bez Entra ID P1 - z metod uwierzytelniania kont. Prawy przycisk: włączenie (Enable) i wymuszenie (Enforce) MFA na zaznaczonych kontach - gdy tenant nie ma dostępu warunkowego.' `
    -Extra {
    param($m, $row)
    $m.C.PerUser = Add-HTCheckBox -Parent $row -Text 'Stan MFA na koncie (per-user)' -Checked $true -ToolTip 'Kolumna «MFA na koncie»: wyłączone / włączone / wymuszone (wymaga uprawnienia Microsoft Graph Policy.Read.All)'
    Add-HTRowAction -Module $m -Text 'MFA na koncie: włącz (Enable)' -Icon 'E8D7' -Danger -Action { param($m, $rows) Invoke-HTPerUserMfaAction -Module $m -Rows $rows -State 'enabled' }
    Add-HTRowAction -Module $m -Text 'MFA na koncie: wymuś (Enforce)' -Icon 'E72E' -Danger -Action { param($m, $rows) Invoke-HTPerUserMfaAction -Module $m -Rows $rows -State 'enforced' }
    Add-HTRowAction -Module $m -Text 'MFA na koncie: wyłącz' -Icon 'E711' -Danger -Action { param($m, $rows) Invoke-HTPerUserMfaAction -Module $m -Rows $rows -State 'disabled' }
} -Prepare {
    param($m)
    $m.Data.PerUser = Test-HTChecked $m.C.PerUser
    if ($m.Data.PerUser -and -not (Test-HTGraphScopes -Scopes @('Policy.Read.All')) -and -not (Test-HTGraphScopes -Scopes @('Policy.ReadWrite.AuthenticationMethod'))) {
        if (-not (Assert-HTGraphScopes -Scopes @('Policy.Read.All') -Feature 'Stan MFA na koncie (per-user)')) { $m.Data.PerUser = $false }
    }
    return $true
} -Query { param($m, $days) Get-HTM365MfaRegistration -PerUserState:([bool]$m.Data.PerUser) }
Register-HTM365Report -Key 'm365.rep.unlicensed' -Title 'Bez licencji' -Icon 'E8EC' -Description 'Konta członków organizacji bez żadnej licencji.' -Query { param($m, $days) Get-HTM365UnlicensedUsers }
Register-HTM365Report -Key 'm365.rep.admins' -Title 'Role administracyjne' -Icon 'E7EF' -Description 'Członkowie aktywnych ról katalogu (Global Administrator wyróżniony).' -Query { param($m, $days) Get-HTM365AdminRoles }
Register-HTM365Report -Key 'm365.rep.failed' -Title 'Nieudane logowania' -Icon 'E7BA' -Days -DefaultDays 24 -DaysLabel 'Ostatnie godziny:' `
    -Description 'Nieudane logowania w całej organizacji (np. ataki password spray, zablokowane konta, błędne MFA).' -Query { param($m, $hours) Get-HTM365FailedSignIns -Hours ([Math]::Min(720, $hours)) }
#endregion

#region Narzędzia helpdesku: wizytówka, porównanie kont, diagnoza logowania, dostęp warunkowy i zgody użytkownika
function Find-HTM365UserInteractive {
    # Użytkownik po UPN, adresie albo początku nazwy (paleta Ctrl+K); kilka trafień - okno wyboru
    param([Parameter(Mandatory)][string]$Query)
    if (-not (Assert-HTConnection -Service 'Graph')) { return $null }
    $q = $Query.Trim()
    if ($q -match '^[^@\s]+@[^@\s]+$') {
        try {
            $u = Resolve-HTM365User -Identity $q
            if ($u) { return [PSCustomObject]@{ Id = $u.id; DisplayName = $u.displayName; UserPrincipalName = $u.userPrincipalName } }
        }
        catch { Write-Verbose "Wyszukanie po UPN: $_" }
    }
    $e = $q.Replace("'", "''")
    $filter = [uri]::EscapeDataString("startswith(displayName,'$e') or startswith(userPrincipalName,'$e') or startswith(mail,'$e')")
    $found = @(Invoke-HTGraphRequest -Uri "users?`$filter=$filter&`$select=id,displayName,userPrincipalName,department,accountEnabled&`$top=25" | ForEach-Object {
            [PSCustomObject]@{ Id = $_.id; DisplayName = $_.displayName; UserPrincipalName = $_.userPrincipalName; Department = $_.department; AccountEnabled = [bool]$_.accountEnabled }
        })
    if ($found.Count -eq 0) { Show-HTWarning "Nie znaleziono użytkownika: $q"; return $null }
    if ($found.Count -eq 1) { return $found[0] }
    $columns = @(
        @{ Text = 'Nazwa'; Property = 'DisplayName' }
        @{ Text = 'UPN'; Property = 'UserPrincipalName' }
        @{ Text = 'Dział'; Property = 'Department' }
        @{ Text = 'Włączone'; Property = 'AccountEnabled' }
    )
    return @(Show-HTSelectionDialog -Title 'Wybierz użytkownika' -Prompt "Wyniki dla «$q»" -Items $found -Columns $columns -Icon 'E77B')[0]
}

function ConvertTo-HTCardDictionary {
    # Obiekt wiersza (np. urządzenie) jako słownik dla tabeli wizytówki
    param($Object)
    $d = [ordered]@{}
    foreach ($p in $Object.PSObject.Properties) {
        if ($p.Name -like '__*') { continue }
        $d[$p.Name] = if ($p.Value -is [datetime]) { $p.Value.ToString('yyyy-MM-dd HH:mm') } else { [string]$p.Value }
    }
    $d['__flag'] = [string]$Object.__flag
    return $d
}

function New-HTUserCardFile {
    # Wizytówka (HTML): konto Microsoft 365, skrzynka Exchange (po połączeniu), urządzenia i ostatnie logowania
    param([Parameter(Mandatory)]$User)
    $detail = Get-HTM365UserDetail -Id $User.Id
    $general = [ordered]@{}
    $sections = [ordered]@{ 'Microsoft 365' = $general }
    foreach ($k in $detail.Keys) {
        $v = $detail[$k]
        if ($v -is [System.Collections.IDictionary]) { $sections[$k] = $v } else { $general[$k] = $v }
    }
    $enabled = [bool]$general['Konto włączone']
    $chips = @(@{ Text = $(if ($enabled) { 'konto aktywne' } else { 'logowanie zablokowane' }); Tone = $(if ($enabled) { 'ok' } else { 'crit' }) })
    if ($general['Typ'] -eq 'Guest') { $chips += @{ Text = 'gość'; Tone = 'info' } }
    if ($sections['Konto'] -and $sections['Konto']['Synchronizacja z AD']) { $chips += @{ Text = 'synchronizowane z AD'; Tone = 'info' } }
    $tables = @()
    if ($Global:ConnectedToExchange) {
        try {
            $mbx = Get-HTMailboxDetail -Identity $User.UserPrincipalName
            $mGeneral = [ordered]@{}
            $sections['Skrzynka Exchange'] = $mGeneral
            foreach ($k in $mbx.Keys) { $v = $mbx[$k]; if ($v -is [System.Collections.IDictionary]) { $sections["Poczta - $k"] = $v } else { $mGeneral[$k] = $v } }
            if ("$($mbx['Rozmiar i limity']['Archiwum'])" -eq 'Active') { $chips += @{ Text = 'archiwum online'; Tone = 'info' } }
            $forward = [string]$mbx['Przekierowanie']['Przekieruj do']
            if ($forward -and $forward -ne '(brak)') { $chips += @{ Text = "przekierowanie: $forward"; Tone = 'warn' } }
            $perms = @(Get-HTMailboxPermissions -Identity $User.UserPrincipalName)
            $tables += @{ Title = 'Uprawnienia do skrzynki'; Columns = @('Typ', 'Użytkownik', 'Uprawnienia'); Rows = @($perms | ForEach-Object { [ordered]@{ Typ = $_.Type; 'Użytkownik' = $_.User; Uprawnienia = $_.AccessRights } }) }
        }
        catch { $sections['Skrzynka Exchange'] = [ordered]@{ Stan = "Brak skrzynki albo błąd: $($_.Exception.Message)" } }
    }
    else { $sections['Skrzynka Exchange'] = [ordered]@{ Stan = 'Połącz z Exchange Online, aby dołączyć dane skrzynki.' } }
    try {
        $devices = @(Get-HTM365UserDevices -Id $User.Id)
        $tables += @{ Title = 'Urządzenia (Intune i Entra ID)'; Columns = @('Źródło', 'Nazwa', 'System', 'Zgodność', 'Model', 'Numer seryjny', 'Ostatnia aktywność'); Rows = @($devices | ForEach-Object { ConvertTo-HTCardDictionary $_ }) }
        if (@($devices | Where-Object { $_.Zgodność -eq 'noncompliant' }).Count) { $chips += @{ Text = 'urządzenie niezgodne'; Tone = 'warn' } }
    }
    catch { Write-Log -Message "Wizytówka - urządzenia: $($_.Exception.Message)" -Type 'Warn' }
    try {
        $signIns = @(Get-HTM365SignIns -UserId $User.Id -Top 15)
        $tables += @{ Title = 'Ostatnie logowania'; Columns = @('Czas', 'Aplikacja', 'Adres IP', 'Lokalizacja', 'Wynik', 'Powód', 'Klient', 'System'); Rows = @($signIns | ForEach-Object { ConvertTo-HTCardDictionary $_ }) }
        if (@($signIns | Where-Object { $_.Wynik -ne 'Sukces' }).Count) { $chips += @{ Text = 'nieudane logowania'; Tone = 'warn' } }
    }
    catch { Write-Log -Message "Wizytówka - logowania (AuditLog.Read.All, Entra ID P1): $($_.Exception.Message)" -Type 'Warn' }
    $subtitle = (@($general['UPN'], $general['Stanowisko'], $general['Dział']) | Where-Object { $_ }) -join ' • '
    $html = ConvertTo-HTUserCardHtml -Title ([string]$general['Nazwa wyświetlana']) -Subtitle $subtitle -Sections $sections -Tables $tables -Chips $chips `
        -Meta ('Helpdesk Tools {0} • {1:yyyy-MM-dd HH:mm} • {2}' -f $Global:AppVersion, (Get-Date), $env:USERNAME)
    $name = ($User.UserPrincipalName -split '@')[0] -replace '[^\w\.\-]+', '_'
    $path = Join-Path (Get-HTExportDirectory) ('Wizytowka_{0}_{1:yyyy-MM-dd_HH-mm}.html' -f $name, (Get-Date))
    [System.IO.File]::WriteAllText($path, $html, (New-Object System.Text.UTF8Encoding($true)))
    return $path
}

function Show-HTUserCard {
    param([Parameter(Mandatory)]$User)
    Set-HTBusy -Busy $true -Text "Wizytówka: $(Get-HTM365Label $User)…"
    try {
        $path = New-HTUserCardFile -User $User
        Write-Log -Message "Utworzono wizytówkę użytkownika: $path" -Type 'Info'
        Start-Process -FilePath $path
    }
    catch {
        Write-Log -Message "Wizytówka $(Get-HTM365Label $User): $($_.Exception.Message)" -Type 'Error'
        Show-HTError 'Nie utworzono wizytówki.' $_
    }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
}

function Show-HTLoginDiagnosisFor {
    # Diagnoza logowania w osobnym oknie (paleta Ctrl+K)
    param([Parameter(Mandatory)]$User, [int]$Days = 7)
    if (-not (Assert-HTGraphScopes -Scopes @('AuditLog.Read.All', 'Policy.Read.All', 'IdentityRiskyUser.Read.All') -Feature 'Diagnoza logowania')) { return }
    Set-HTBusy -Busy $true -Text "Diagnoza logowania: $(Get-HTM365Label $User)…"
    try { $rows = @(Get-HTLoginDiagnosis -UserId $User.Id -Days $Days) }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
    Show-HTDataViewer -Title "Diagnoza logowania - $(Get-HTM365Label $User)" -Data $rows -Description "Konto, hasło, MFA, ryzyko, dostęp warunkowy i logowania z ostatnich $Days dni." -ExportName 'diagnoza_logowania' -Icon 'E9D9'
}

Register-HTModule -Workspace 'M365' -Category 'Konto' -Key 'm365.card' -Title 'Wizytówka (raport HTML)' -Icon 'E8A5' -Service 'Graph' `
    -Description 'Wszystko o użytkowniku na jednej stronie: konto i licencje, MFA, grupy, skrzynka Exchange (uprawnienia, przekierowanie, autoodpowiedź), urządzenia i ostatnie logowania. Plik HTML do zgłoszenia lub wydruku.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz wizytówkę' -Icon 'E8A5' -Primary -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -gt 5 -and -not (Show-HTConfirm -Title 'Wizytówki' -Message "Utworzyć $($targets.Count) plików wizytówek?")) { return }
        foreach ($t in $targets) { Show-HTUserCard -User $t }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Dane skrzynki po połączeniu z Exchange. Ctrl+K > «Wizytówka» - dla dowolnego konta bez wczytywania listy.' | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Konto' -Key 'm365.compare' -Title 'Porównanie kont' -Icon 'E8AB' -Service 'Graph' `
    -Description 'Grupy, licencje, role i aplikacje dwóch kont obok siebie (np. «nowa osoba ma mieć to samo co…»). Zaznacz dwa konta na liście albo jedno i wybierz drugie. Prawy przycisk - uzupełnienie brakujących grup.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.OnlyDiff = Add-HTCheckBox -Parent $row -Text 'Tylko różnice' -Checked $true
    Add-HTButton -Parent $row -Module $m -Text 'Porównaj' -Icon 'E8AB' -Primary -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        if ($targets.Count -eq 1) {
            $other = Select-HTM365User -Title 'Porównaj z' -Prompt "Drugie konto do porównania z $(Get-HTM365Label $targets[0])."
            if (-not $other) { return }
            $targets += $other
        }
        $m.Data.A = $targets[0]
        $m.Data.B = $targets[1]
        Invoke-HTQuery -Module $m -Name 'Porównanie kont' -Background -Arguments @{ A = $targets[0].Id; B = $targets[1].Id; NameA = (Get-HTM365Label $targets[0]); NameB = (Get-HTM365Label $targets[1]); OnlyDiff = (Test-HTChecked $m.C.OnlyDiff) } -ScriptBlock {
            param($x)
            $sa = Get-HTUserAccessSummary -UserId $x.A
            $sb = Get-HTUserAccessSummary -UserId $x.B
            $groups = @{}
            foreach ($g in @($sa.__groups) + @($sb.__groups)) { if ($g) { $groups[[string]$g.DisplayName] = $g } }
            $sa.Remove('__groups')
            $sb.Remove('__groups')
            foreach ($r in @(Compare-HTUserSets -A $sa -B $sb -NameA $x.NameA -NameB $x.NameB -OnlyDifferences:$x.OnlyDiff)) {
                if ($r.Kategoria -eq 'Grupy') { $r | Add-Member -NotePropertyName '__group' -NotePropertyValue $groups[$r.Nazwa] }
                $r
            }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Uzupełnij brakujące grupy (drugie konto)' -Icon 'E902' -Create -Action {
        param($m, $rows)
        $a = $m.Data.A
        $b = $m.Data.B
        $todo = @($rows | Where-Object { $_.Kategoria -eq 'Grupy' -and $_.__group -and ($_.__inA -xor $_.__inB) })
        if (-not $todo.Count) { Show-HTWarning 'Zaznacz wiersze grup, które ma tylko jedno z kont.'; return }
        Invoke-HTRowAction -Module $m -Name 'Uzupełnienie grup' -Rows $todo -Confirm "Dodać konta do grup, których im brakuje?`n$(Get-HTM365Label $a) ↔ $(Get-HTM365Label $b)" -Label { param($r) $r.Nazwa } -Action {
            param($r)
            $user = if ($r.__inA) { $b } else { $a }
            if (-not (Test-HTM365GroupManageable -Group $r.__group)) { throw 'grupa dynamiczna albo synchronizowana z AD' }
            Add-HTM365UserToGroup -Group $r.__group -User $user
            "Dodano: $(Get-HTM365Label $user)"
        }
    }
}

Register-HTModule -Workspace 'M365' -Category 'Bezpieczeństwo' -Key 'm365.diag' -Title 'Diagnoza logowania' -Icon 'E9D9' -Service 'Graph' `
    -Description '«Nie mogę się zalogować»: stan konta i hasła, MFA, ryzyko, zasady dostępu warunkowego i ostatnie błędy logowania z wyjaśnieniem kodów (50053, 50074, 53003…) i zaleceniem.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Logowania z ostatnich (dni):' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 7 -Minimum 1 -Maximum 30
    Add-HTButton -Parent $row -Module $m -Text 'Diagnozuj' -Icon 'E9D9' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('AuditLog.Read.All', 'Policy.Read.All', 'IdentityRiskyUser.Read.All') -Feature 'Diagnoza logowania')) { return }
        $days = Get-HTNum $m.C.Days
        Invoke-HTTargetQuery -Module $m -Name 'Diagnoza logowania' -Label { param($t) Get-HTM365Label $t } -Action { param($t) Get-HTLoginDiagnosis -UserId $t.Id -Days $days }
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Bezpieczeństwo' -Key 'm365.causer' -Title 'Dostęp warunkowy konta' -Icon 'E83D' -Service 'Graph' `
    -Description 'Zasady dostępu warunkowego obejmujące konto (bezpośrednio, przez grupy, role lub jako gościa) z wymaganą kontrolą. Ocena warunku «Użytkownicy» - aplikacje i lokalizacje opisuje kolumna «Warunki».' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.All = Add-HTCheckBox -Parent $row -Text 'Pokaż też zasady, które nie obejmują konta'
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź zasady' -Icon 'E83D' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('Policy.Read.All') -Feature 'Dostęp warunkowy')) { return }
        $all = Test-HTChecked $m.C.All
        Invoke-HTTargetQuery -Module $m -Name 'Dostęp warunkowy konta' -Label { param($t) Get-HTM365Label $t } -Action { param($t) Get-HTConditionalAccessForUser -UserId $t.Id -IncludeNotApplied:$all }
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Bezpieczeństwo' -Key 'm365.consents' -Title 'Zgody aplikacji konta' -Icon 'E8D7' -Service 'Graph' `
    -Description 'Aplikacje, którym użytkownik udzielił dostępu do swoich danych (zgody delegowane) - np. po phishingu zgód. Wyróżnione - szerokie uprawnienia od niezweryfikowanych wydawców. Prawy przycisk - cofnięcie zgody.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż zgody' -Icon 'E8D7' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Zgody aplikacji' -Label { param($t) Get-HTM365Label $t } -Action { param($t) Get-HTOAuthGrants -UserId $t.Id | Where-Object { $_.Zgoda -eq 'Użytkownik' } }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Cofnij zgodę' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        if (-not (Assert-HTGraphScopes -Scopes @('DelegatedPermissionGrant.ReadWrite.All') -Feature 'Cofanie zgód aplikacji')) { return }
        Invoke-HTRowAction -Module $m -Name 'Cofnięcie zgody aplikacji' -Rows $rows -Danger -Confirm 'Cofnąć zgody wybranych aplikacji? Aplikacja straci dostęp do danych użytkownika (sesje aplikacji mogą działać do wygaśnięcia tokenu - rozważ też unieważnienie sesji).' -Label { param($r) $r.Aplikacja } -Action { param($r) Remove-HTOAuthGrant -GrantId $r.Id; 'Cofnięto' }
    }
}
#endregion

#region Licencje grupowe, licencje do odzyskania
Register-HTModule -Workspace 'Organization' -Category 'Licencje' -Key 'm365.licerr' -Title 'Błędy licencji grupowych' -Icon 'E7BA' -Service 'Graph' `
    -Description 'Użytkownicy, którym grupa nie przypisała licencji (brak wolnych licencji, konflikt planów, brak lokalizacji użycia). Po usunięciu przyczyny - «Ponów przypisanie».' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź błędy' -Icon 'E72C' -Primary -OnClick {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Błędy licencji grupowych' -Background -ScriptBlock { param($a) Get-HTGroupLicenseErrors }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Ponów przypisanie licencji' -Icon 'E72C' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Ponowne przetworzenie licencji' -Rows $rows -Label { param($r) $r.UPN } -Action { param($r) Invoke-HTLicenseReprocess -UserId $r.Id; 'Zlecono ponowne przetworzenie' }
    }
    Add-HTRowAction -Module $m -Text 'Ustaw lokalizację użycia…' -Icon 'E909' -Danger -Action {
        param($m, $rows)
        $loc = Show-InputBox -Title 'Lokalizacja użycia' -Prompt 'Dwuliterowy kod kraju (np. PL) dla zaznaczonych kont:' -DefaultText $(if ($Global:DefaultUsageLocation) { $Global:DefaultUsageLocation } else { 'PL' }) -Icon 'E909'
        if (-not $loc -or $loc -notmatch '^[A-Za-z]{2}$') { return }
        Invoke-HTRowAction -Module $m -Name 'Lokalizacja użycia' -Summary "Lokalizacja użycia: $($loc.ToUpperInvariant())" -Rows $rows -Label { param($r) $r.UPN } -Action {
            param($r)
            Invoke-HTGraphRequest -Uri "users/$($r.Id)" -Method PATCH -Body @{ usageLocation = $loc.ToUpperInvariant() } | Out-Null
            Invoke-HTLicenseReprocess -UserId $r.Id
            "Lokalizacja: $($loc.ToUpperInvariant()), ponowiono przypisanie"
        }
    }
}

Register-HTModule -Workspace 'Organization' -Category 'Licencje' -Key 'm365.reclaim' -Title 'Licencje do odzyskania' -Icon 'E8EC' -Service 'Graph' `
    -Description 'Licencje przypisane kontom zablokowanym albo nieaktywnym (bez logowania od N dni). Prawy przycisk - usunięcie licencji bezpośrednich (licencje z grup usuwa się przez członkostwo).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Bez logowania od (dni):' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value (Get-HTInactiveDaysDefault) -Minimum 1 -Maximum 3650
    $m.C.Guests = Add-HTCheckBox -Parent $row -Text 'Także goście'
    Add-HTButton -Parent $row -Module $m -Text 'Szukaj' -Icon 'E721' -Primary -OnClick {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Licencje do odzyskania' -Background -Arguments @{ Days = (Get-HTNum $m.C.Days); Guests = (Test-HTChecked $m.C.Guests) } -ScriptBlock { param($a) Get-HTReclaimableLicenses -Days $a.Days -IncludeGuests:$a.Guests }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń licencje bezpośrednie' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $rows = @($rows | Where-Object { $_.Id })
        $none = @($rows | Where-Object { -not @($_.__direct).Count })
        $rows = @($rows | Where-Object { @($_.__direct).Count })
        if ($none.Count) { Write-Log -Message "Usunięcie licencji - pominięto konta tylko z licencjami z grup: $(@($none | ForEach-Object { $_.UPN }) -join ', ')" -Type 'Info' }
        if ($rows.Count -eq 0) { Show-HTWarning 'Zaznaczone konta mają tylko licencje z grup - usuń je przez członkostwo w grupie.'; return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie licencji' -Rows $rows -Danger -Confirm 'Usunąć bezpośrednio przypisane licencje zaznaczonych kont? Licencje z grup zostają (usuwa się je przez członkostwo). Przed usunięciem licencji skrzynkę warto przekonwertować na współdzieloną (dane skrzynki bez licencji są usuwane po 30 dniach).' `
            -Summary @("Usuwane: licencje bezpośrednie wymienione przy kontach", "Liczba licencji: $(@($rows | ForEach-Object { @($_.__direct) }).Count)") `
            -Label { param($r) "$($r.UPN) - $(@($r.__directNames) -join ', ')" } -Refresh { param($m) Invoke-HTModulePrimary $m } -Action {
            param($r)
            $names = @{}
            $ids = @($r.__direct)
            $labels = @($r.__directNames)
            for ($i = 0; $i -lt $ids.Count; $i++) { $names[$ids[$i]] = $(if ($i -lt $labels.Count) { $labels[$i] } else { $ids[$i] }) }
            $result = Remove-HTM365DirectLicenses -Id $r.Id -SkuIds $ids -Names $names
            if (@($result.Removed).Count) { Register-HTUndo -Operation 'Usunięcie licencji' -Object $r.UPN -Kind 'License' -Data @{ UserId = $r.Id; SkuIds = @($result.Removed) } }
            $removedText = @($result.Removed | ForEach-Object { $names[$_] }) -join ', '
            $failedText = @($result.Failed | ForEach-Object { "$($_.Name): $($_.Error)" }) -join '; '
            if (-not @($result.Removed).Count) { throw "Nie usunięto żadnej licencji. $failedText" }
            if ($failedText) { "Usunięto: $removedText. Nie usunięto: $failedText" } else { "Usunięto: $removedText" }
        }
    }
}
#endregion

#region Teams
Register-HTModule -Workspace 'Groups' -Category 'Zespoły Teams' -Key 'm365.teams' -Title 'Zespoły Teams' -Icon 'E902' -Service 'Graph' `
    -Description 'Zespoły z właścicielami, liczbą członków i gości, archiwizacją i ostatnią aktywnością. Czerwone - zespół bez właściciela. Prawy przycisk - właściciel, archiwizacja, goście.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.Issues = Add-HTCheckBox -Parent $row -Text 'Tylko z uwagami (bez właściciela, jeden właściciel, goście)'
    $m.C.Activity = Add-HTCheckBox -Parent $row -Text 'Ostatnia aktywność (raport użycia)' -Checked $true
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz zespoły' -Icon 'E72C' -Primary -OnClick {
        param($m)
        if ((Test-HTChecked $m.C.Activity) -and -not (Assert-HTGraphScopes -Scopes @('Reports.Read.All') -Feature 'Aktywność zespołów')) { return }
        Invoke-HTQuery -Module $m -Name 'Zespoły Teams' -Background -Arguments @{ Issues = (Test-HTChecked $m.C.Issues); Activity = (Test-HTChecked $m.C.Activity) } -ScriptBlock { param($a) Get-HTTeamsOverview -OnlyIssues:$a.Issues -NoActivity:(-not $a.Activity) }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Dodaj właściciela…' -Icon 'E8FA' -Create -Action {
        param($m, $rows)
        $owner = Select-HTM365User -Title 'Nowy właściciel' -Prompt "Właściciel dla zespołów: $($rows.Count)."
        if (-not $owner) { return }
        Invoke-HTRowAction -Module $m -Name 'Dodanie właściciela zespołu' -Summary "Nowy właściciel: $(Get-HTM365Label $owner)" -Rows $rows -Label { param($r) $r.Zespół } -Action { param($r) Add-HTTeamOwner -GroupId $r.Id -UserId $owner.Id; "Właściciel: $(Get-HTM365Label $owner)" }
    }
    Add-HTRowAction -Module $m -Text 'Archiwizuj zespół' -Icon 'E7B8' -Danger -Action {
        param($m, $rows)
        if (-not (Assert-HTGraphScopes -Scopes @('TeamSettings.ReadWrite.All') -Feature 'Archiwizacja zespołów')) { return }
        Invoke-HTRowAction -Module $m -Name 'Archiwizacja zespołu' -Rows $rows -Confirm 'Zarchiwizować wybrane zespoły? Zespół stanie się tylko do odczytu (można go przywrócić).' -Label { param($r) $r.Zespół } -Action {
            param($r)
            Set-HTTeamArchived -TeamId $r.Id -Archived $true
            Register-HTUndo -Operation 'Archiwizacja zespołu' -Object $r.Zespół -Kind 'TeamArchive' -Data @{ TeamId = $r.Id }
            'Zarchiwizowano'
        }
    }
    Add-HTRowAction -Module $m -Text 'Przywróć z archiwum' -Icon 'E777' -Create -Action {
        param($m, $rows)
        if (-not (Assert-HTGraphScopes -Scopes @('TeamSettings.ReadWrite.All') -Feature 'Archiwizacja zespołów')) { return }
        Invoke-HTRowAction -Module $m -Name 'Przywrócenie zespołu' -Rows $rows -Label { param($r) $r.Zespół } -Action { param($r) Set-HTTeamArchived -TeamId $r.Id -Archived $false; 'Przywrócono' }
    }
    Add-HTRowAction -Module $m -Text 'Pokaż gości zespołu' -Icon 'E8D4' -Action {
        param($m, $rows)
        $guests = @(foreach ($r in $rows) { Get-HTTeamGuests -GroupId $r.Id -TeamName $r.Zespół })
        Show-HTDataViewer -Title 'Goście zespołów' -Data $guests -Description 'Usunięcie gościa z zespołu: moduł «Członkowie grup» (Licencje i grupy).' -ExportName 'goscie_zespolow' -Icon 'E8D4'
    }
}
#endregion

#region Masowe tworzenie kont z pliku CSV
Register-HTModule -Workspace 'Organization' -Category 'Tworzenie' -Key 'm365.bulk' -Title 'Masowe tworzenie kont (CSV)' -Icon 'E8F4' -Service 'Graph' `
    -Description 'Nowe konta z pliku CSV według szablonu: imię, nazwisko, login, stanowisko, dział, licencje, grupy, przełożony. Najpierw sprawdzenie pliku (podgląd błędów), potem utworzenie kont z losowymi hasłami.' -Build {
    param($m)
    $m.SecretColumns = @('Hasło')
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Zapisz szablon CSV' -Icon 'E74E' -OnClick {
        param($m)
        $path = Select-HTSaveFile -Title 'Szablon CSV' -Filter 'CSV (*.csv)|*.csv' -FileName 'Nowe_konta.csv' -DefaultExt '.csv'
        if (-not $path) { return }
        [System.IO.File]::WriteAllText($path, (Get-HTBulkUserTemplate), (New-Object System.Text.UTF8Encoding($true)))
        Show-HTToast 'Zapisano szablon. Licencje: nazwa SKU (np. O365_BUSINESS_PREMIUM), kilka wartości po przecinku.' 'ok' 8
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Wczytaj i sprawdź plik…' -Icon 'E8E5' -Primary -OnClick {
        param($m)
        $path = Select-HTOpenFile -Title 'Plik CSV z nowymi kontami' -Filter 'CSV (*.csv)|*.csv'
        if (-not $path) { return }
        Invoke-HTQuery -Module $m -Name 'Sprawdzenie pliku CSV' -ScriptBlock {
            $rows = @(Import-HTBulkUserCsv -Path $path)
            $domains = @(Get-HTM365Domains)
            $skus = @(Get-HTSubscribedSkus | ForEach-Object { $_.SkuPartNumber })
            $existing = @(Get-HTM365Users | ForEach-Object { $_.UserPrincipalName })
            $seen = New-Object System.Collections.Generic.List[string]
            $m.Data.Bulk = New-Object System.Collections.Generic.List[object]
            $n = 0
            foreach ($r in $rows) {
                $n++
                $check = Test-HTBulkUserRow -Row $r -Domains $domains -ExistingUpns $existing -SeenUpns $seen.ToArray() -KnownSkus $skus
                if ($check.Upn) { $seen.Add($check.Upn) }
                $check.Source = $r
                $m.Data.Bulk.Add($check)
                [PSCustomObject]@{ Lp = $n; Nazwa = $check.DisplayName; UPN = $check.Upn; Licencje = ($check.Licenses -join ', '); Grupy = ($check.Groups -join ', '); Przełożony = $check.Manager
                    Status = $(if ($check.Valid) { 'Do utworzenia' } else { 'Błąd' }); Szczegóły = ($check.Errors -join '; '); Hasło = ''; __flag = $(if ($check.Valid) { '' } else { 'crit' }) }
            }
        }
        $bad = @($m.Data.Bulk | Where-Object { -not $_.Valid }).Count
        if ($m.Data.Bulk.Count) { Show-HTToast "Wierszy: $($m.Data.Bulk.Count), z błędami: $bad. Popraw plik albo utwórz poprawne konta." $(if ($bad) { 'warn' } else { 'ok' }) 6 }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz poprawne konta' -Icon 'E8FA' -Create -OnClick {
        param($m)
        $valid = @($m.Data.Bulk | Where-Object { $_.Valid })
        if (-not $valid.Count) { Show-HTWarning 'Najpierw wczytaj i sprawdź plik CSV (brak poprawnych wierszy).'; return }
        if (-not (Assert-HTWriteAllowed -Operation 'Masowe tworzenie kont')) { return }
        if (-not (Confirm-HTChange -Name 'Masowe tworzenie kont' -Confirm "Utworzyć kont: $($valid.Count)? Hasła zostaną wygenerowane (zmiana przy pierwszym logowaniu) i pokazane w kolumnie «Hasło» (przycisk «Pokaż poufne»)." -Labels @($valid | ForEach-Object { $_.Upn }))) { return }
        $groupCache = @{}
        $skuMap = @{}
        foreach ($s in @(Get-HTSubscribedSkus)) { $skuMap[$s.SkuPartNumber.ToUpperInvariant()] = "$($s.SkuId)" }
        Reset-HTResults -Module $m
        Set-HTBusy -Busy $true -Text 'Tworzenie kont…'
        try {
            $i = 0
            foreach ($v in $valid) {
                $i++
                Set-HTProgress -Value $i -Maximum $valid.Count -Text "Tworzenie [$i/$($valid.Count)] $($v.Upn)"
                $src = $v.Source
                $notes = New-Object System.Collections.Generic.List[string]
                $password = if ("$($src.Haslo)".Trim()) { "$($src.Haslo)".Trim() } else { New-HTRandomPassword }
                try {
                    $created = New-HTM365User -DisplayName $v.DisplayName -UserPrincipalName $v.Upn -Password $password -GivenName "$($src.Imie)".Trim() -Surname "$($src.Nazwisko)".Trim() `
                        -JobTitle "$($src.Stanowisko)".Trim() -Department "$($src.Dzial)".Trim() -UsageLocation "$($src.LokalizacjaUzycia)".Trim().ToUpperInvariant()
                    $extra = @{}
                    if ("$($src.Firma)".Trim()) { $extra.companyName = "$($src.Firma)".Trim() }
                    if ("$($src.TelefonKomorkowy)".Trim()) { $extra.mobilePhone = "$($src.TelefonKomorkowy)".Trim() }
                    if ("$($src.Biuro)".Trim()) { $extra.officeLocation = "$($src.Biuro)".Trim() }
                    if ($extra.Count) { try { Set-HTM365UserContact -Id $created.id -Properties $extra } catch { $notes.Add("dane kontaktowe: $($_.Exception.Message)") } }
                    $skuIds = @(foreach ($l in $v.Licenses) { $skuMap[$l.ToUpperInvariant()] })
                    if ($skuIds.Count) { try { Set-HTM365UserLicense -Id $created.id -AddSkuIds $skuIds -UsageLocation "$($src.LokalizacjaUzycia)".Trim(); $notes.Add("licencje: $($v.Licenses -join ', ')") } catch { $notes.Add("licencje - błąd: $($_.Exception.Message)") } }
                    foreach ($gName in $v.Groups) {
                        try {
                            if (-not $groupCache.ContainsKey($gName)) { $groupCache[$gName] = Resolve-HTM365Group -Identity $gName }
                            Add-HTM365GroupMember -GroupId $groupCache[$gName].id -MemberId $created.id
                            $notes.Add("grupa: $gName")
                        }
                        catch { $notes.Add("grupa $gName - błąd: $($_.Exception.Message)") }
                    }
                    if ($v.Manager) {
                        try { $mgr = Resolve-HTM365User -Identity $v.Manager; Set-HTM365UserManager -Id $created.id -ManagerId $mgr.id; $notes.Add("przełożony: $($v.Manager)") }
                        catch { $notes.Add("przełożony - błąd: $($_.Exception.Message)") }
                    }
                    Add-HTOperationRecord -Operation 'Utworzenie konta (CSV)' -Object $v.Upn -Details ($notes -join '; ') -Module $m.Title
                    Write-Log -Message "Utworzono konto z pliku CSV: $($v.Upn)" -Type 'Info'
                    Add-HTResultRows -Module $m -Objects @([PSCustomObject]@{ Nazwa = $v.DisplayName; UPN = $v.Upn; Status = 'OK'; Szczegóły = ($notes -join '; '); Hasło = $password; __flag = $(if (@($notes | Where-Object { $_ -match 'błąd' }).Count) { 'warn' } else { '' }) })
                }
                catch {
                    Add-HTOperationRecord -Operation 'Utworzenie konta (CSV)' -Object $v.Upn -Status 'Błąd' -Details $_.Exception.Message -Module $m.Title
                    Add-HTResultRows -Module $m -Objects @([PSCustomObject]@{ Nazwa = $v.DisplayName; UPN = $v.Upn; Status = 'Błąd'; Szczegóły = $_.Exception.Message; Hasło = ''; __flag = 'crit' })
                }
            }
        }
        finally { Set-HTBusy -Busy $false -Text 'Tworzenie kont zakończone' }
        $m.Data.Bulk = $null
        $p = Get-HTPanel 'm365users'
        if ($p) { Invoke-HTPanelLoad -Panel $p -Quiet }
        Show-HTToast 'Utworzono konta - hasła w kolumnie «Hasło» (Pokaż poufne), eksport: Excel.' 'ok' 8
    } | Out-Null
}
#endregion

#region Polecenia palety (Ctrl+K)
Register-HTPaletteAction -Text 'Wizytówka użytkownika' -Icon 'E8A5' -Description 'Raport HTML: konto, MFA, grupy, skrzynka, urządzenia, logowania' -NeedsQuery -Action {
    param($q)
    $u = Find-HTM365UserInteractive -Query $q
    if ($u) { Show-HTUserCard -User $u }
}
Register-HTPaletteAction -Text 'Diagnoza logowania' -Icon 'E9D9' -Description '«Nie mogę się zalogować» - konto, MFA, ryzyko, dostęp warunkowy, błędy' -NeedsQuery -Action {
    param($q)
    $u = Find-HTM365UserInteractive -Query $q
    if ($u) { Show-HTLoginDiagnosisFor -User $u }
}
#endregion

#region OneDrive odchodzącego pracownika
Register-HTModule -Workspace 'M365' -Category 'Cykl życia' -Key 'm365.onedrive' -Title 'OneDrive odchodzącego' -Icon 'E753' -Service 'Graph' `
    -Description 'Dostęp przełożonego (lub innej osoby) do OneDrive odchodzącego pracownika - przed usunięciem konta (OneDrive jest usuwany po okresie przechowywania). Opcjonalnie odebranie dostępu po N dniach (zadania zaplanowane). Także udostępnienia z OneDrive.' -Build {
    param($m)
    Add-HTStateCheck -Module $m -Label { param($t) Get-HTM365Label $t } -Action {
        param($t)
        $state = Get-HTM365AccountState -Id $t.Id
        $manager = Get-HTM365UserManager -Id $t.Id
        [PSCustomObject][ordered]@{ Logowanie = $state.Logowanie; 'Ostatnie logowanie' = $state.'Ostatnie logowanie'; 'Przełożony (dostanie dostęp)' = $(if ($manager) { $manager.userPrincipalName } else { '(brak - wpisz osobę)' }); __flag = $state.__flag }
    } | Out-Null
    $row = Add-HTToolbarRow -Module $m -Title 'Dostęp'
    $m.C.GrantTo = Add-HTTextBox -Parent $row -Width 300 -Placeholder 'Dla (UPN, puste - przełożony z Entra ID)'
    Add-HTLabel -Parent $row -Text 'Odbierz po (dni, 0 - nie):' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 30 -Minimum 0 -Maximum 365
    Add-HTButton -Parent $row -Module $m -Text 'Nadaj dostęp' -Icon 'E8FA' -Primary -Create -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Dostęp do OneDrive')) { return }
        $grantTo = $m.C.GrantTo.Text.Trim()
        $days = Get-HTNum $m.C.Days
        # Potwierdzenie przed połączeniem z centrum administracyjnym SharePoint (zmiany poniżej już bez pytania)
        $summary = @("Administrator OneDrive: $(if ($grantTo) { $grantTo } else { 'przełożony każdego konta' })", "Odebranie dostępu: $(if ($days -gt 0) { "za $days dni" } else { 'nie (ręcznie)' })")
        if (-not (Confirm-HTChange -Name 'Dostęp do OneDrive' -Labels @($targets | ForEach-Object { Get-HTM365Label $_ }) -Summary $summary -Confirm 'Nadać rolę administratora OneDrive kont odchodzących? Wymaga roli SharePoint Administrator.')) { return }
        try { $admin = Connect-HTPnPReturn -Url (Get-HTSharePointAdminUrl) }
        catch { Show-HTError 'Nie połączono z centrum administracyjnym SharePoint.' $_; return }
        Invoke-HTTargetAction -Module $m -Name 'Dostęp do OneDrive' -NoConfirm -Targets $targets -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $who = $grantTo
            if (-not $who) {
                $mgr = Get-HTM365UserManager -Id $t.Id
                if (-not $mgr) { throw 'brak przełożonego - wpisz UPN osoby' }
                $who = $mgr.userPrincipalName
            }
            $site = Grant-HTOneDriveAccess -UserId $t.Id -GrantTo @($who) -AdminConnection $admin
            if ($days -gt 0) { [void](New-HTScheduledJob -Type 'RevokeOneDriveAccess' -RunAt (Get-Date).AddDays($days) -Object (Get-HTM365Label $t) -Description "Odebranie dostępu $who do OneDrive" -Data @{ SiteUrl = $site; Users = @($who) }) }
            @{ Szczegóły = "$who - administrator OneDrive$(if ($days -gt 0) { ", odebranie: $((Get-Date).AddDays($days).ToString('yyyy-MM-dd'))" })"; OneDrive = $site }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Otwórz OneDrive' -Icon 'E8A7' -OnClick {
        param($m)
        foreach ($t in @(Get-HTTargets -Module $m | Select-Object -First 3)) { try { Start-Process (Get-HTOneDriveSiteUrl -UserId $t.Id) } catch { Show-HTError "OneDrive $(Get-HTM365Label $t)" $_ } }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Udostępnienia'
    $m.C.External = Add-HTCheckBox -Parent $row2 -Text 'Tylko anonimowe i zewnętrzne' -Checked $true
    Add-HTButton -Parent $row2 -Module $m -Text 'Udostępnione pliki' -Icon 'E72D' -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        if (-not (Assert-HTGraphScopes -Scopes @('Files.Read.All') -Feature 'Udostępnienia OneDrive')) { return }
        Invoke-HTQuery -Module $m -Name 'Udostępnienia OneDrive' -Background -Arguments @{ Users = @($targets | ForEach-Object { @{ Id = $_.Id; Label = (Get-HTM365Label $_) } }); External = (Test-HTChecked $m.C.External) } -ScriptBlock {
            param($a)
            foreach ($u in $a.Users) {
                try { Get-HTOneDriveSharing -UserId $u.Id -Label $u.Label -OnlyExternal:$a.External }
                catch { Write-Log -Message "Udostępnienia OneDrive $($u.Label): $($_.Exception.Message)" -Type 'Warn' }
            }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń link / udostępnienie' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $items = @($rows | Where-Object { $_.__permId })
        if (-not $items.Count) { return }
        if (-not (Assert-HTGraphScopes -Scopes @('Files.ReadWrite.All') -Feature 'Usuwanie udostępnień')) { return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie udostępnienia' -Rows $items -Danger -Confirm 'Usunąć zaznaczone linki i udostępnienia? Osoby z linkiem stracą dostęp.' -Label { param($r) "$($r.Element) - $($r.Udostępnienie)" } -Action { param($r) Remove-HTDriveItemPermission -DriveId $r.__driveId -ItemId $r.__itemId -PermissionId $r.__permId; 'Usunięto' }
    }
}
#endregion
