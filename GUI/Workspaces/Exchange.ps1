# Przestrzeń robocza: Exchange Online - skrzynki, uprawnienia, poczta, zgodność, raporty

Register-HTWorkspace -Key 'Exchange' -Title 'Exchange' -Icon 'E715' -Panel 'mailboxes' -Service 'Exchange' `
    -Description 'Skrzynki Exchange Online: uprawnienia, kalendarze, autoodpowiedzi, reguły, kwarantanna. Tworzenie, przepływ poczty i raporty organizacji - przestrzeń Organizacja; grupy dynamiczne - Grupy i zespoły.' `
    -Categories @('Skrzynka', 'Uprawnienia', 'Poczta', 'Sale i zasoby', 'Grupy i adresy', 'Zgodność')

$panel = New-HTTargetPanel -Key 'mailboxes' -Title 'Skrzynki' -Placeholder 'Szukaj (nazwa, adres, typ: shared, room)…' -EmptyIcon 'E715' `
    -EmptyText 'Połącz z Exchange Online i kliknij «Wczytaj».' -Describe {
    param($x)
    $types = @{ UserMailbox = 'użytkownika'; SharedMailbox = 'współdzielona'; RoomMailbox = 'sala'; EquipmentMailbox = 'zasób' }
    $type = $types[$x.RecipientTypeDetails] ?? $x.RecipientTypeDetails
    $sub = "$($x.PrimarySmtpAddress) • $type"
    if ($x.Forwarding) { $sub += " • → $($x.Forwarding)" }
    @{ Key = $x.PrimarySmtpAddress; Title = $x.DisplayName; Sub = $sub
        Dot = $(if ($x.Forwarding) { 'warn' } elseif ($x.RecipientTypeDetails -eq 'UserMailbox') { 'ok' } else { 'info' })
        Search = "$($x.UserPrincipalName) $($x.RecipientTypeDetails) $type $(if ($x.HiddenFromGAL) { 'ukryta' })" }
}
Add-HTPanelLoader -Panel $panel -Service 'Exchange' -Loader { param($p) Get-HTMailboxes } | Out-Null
Add-HTPanelHint -Panel $panel -Text 'Kropka: zielona - użytkownika, niebieska - współdzielona/sala/zasób, żółta - ustawione przekierowanie.' | Out-Null

function Get-HTMailboxLabel { param($x) [string]$x.PrimarySmtpAddress }

# Akcje na skrzynkach z dowolnych wyników przestrzeni Exchange (prawy przycisk > «Skrzynka»)
Register-HTObjectKind -Kind 'Mailbox' -Title 'Skrzynka' -Icon 'E715' -Service 'Exchange' -Workspaces @('Exchange', 'Organization', 'Groups') -Resolve {
    param($o)
    foreach ($n in 'PrimarySmtpAddress', '__address', 'Adres', 'Obiekt', 'Skrzynka') {
        $p = $o.PSObject.Properties[$n]
        if ($p -and "$($p.Value)" -match '^[^@\s]+@[^@\s]+\.[^@\s]+$') { return "$($p.Value)" }
    }
    $p = $o.PSObject.Properties['__target']
    if ($p -and $p.Value -and $p.Value.PSObject.Properties['PrimarySmtpAddress']) { return [string]$p.Value.PrimarySmtpAddress }
    return $null
}
Register-HTObjectAction -Kind 'Mailbox' -Text 'Szczegóły skrzynki' -Icon 'E8A1' -View -Action {
    param($Id, $Row)
    Set-HTBusy -Busy $true -Text "Szczegóły skrzynki $Id…"
    try { $rows = @(ConvertTo-HTDetailRows -Data (Get-HTMailboxDetail -Identity $Id)) } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
    Show-HTDataViewer -Title "Skrzynka: $Id" -Data $rows -ExportName "skrzynka_$Id" -Icon 'E715'
}
Register-HTObjectAction -Kind 'Mailbox' -Text 'Ukryj w książce adresowej' -Icon 'ED1A' -Danger -Name 'Ukrycie w GAL' -Confirm 'Ukryć zaznaczone skrzynki w książce adresowej?' -Action { param($Id, $Row) Set-HTMailboxHiddenFromGAL -Identity $Id -Hidden $true; 'Ukryta' }
Register-HTObjectAction -Kind 'Mailbox' -Text 'Pokaż w książce adresowej' -Icon 'E7B3' -Danger -Name 'Pokazanie w GAL' -Confirm 'Pokazać zaznaczone skrzynki w książce adresowej?' -Action { param($Id, $Row) Set-HTMailboxHiddenFromGAL -Identity $Id -Hidden $false; 'Widoczna' }

#region Skrzynka
Register-HTModule -Workspace 'Exchange' -Category 'Skrzynka' -Key 'exo.details' -Title 'Szczegóły skrzynki' -Icon 'E8A1' `
    -Description 'Typ, rozmiar i limity, archiwum, Litigation Hold, przekierowanie, autoodpowiedź, aliasy i delegaci.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Widok' | Out-Null
    $m.C.View = Add-HTComboBox -Parent $row -Items @('Pola (wiersz = pole)', 'Skrzynki (wiersz = skrzynka)') -Width 220
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż szczegóły' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        if ($m.C.View.SelectedIndex -eq 1) {
            $m.ResultHint = 'Dwuklik na skrzynce - wszystkie szczegóły'
            Invoke-HTTargetQuery -Module $m -Name 'Zestawienie skrzynek' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) ConvertTo-HTMailboxSummaryRow -Detail (Get-HTMailboxDetail -Identity $t.PrimarySmtpAddress) }
        }
        else {
            $m.ResultHint = $null
            Invoke-HTTargetQuery -Module $m -Name 'Szczegóły skrzynki' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) ConvertTo-HTDetailRows -Data (Get-HTMailboxDetail -Identity $t.PrimarySmtpAddress) }
        }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text '«Skrzynki» - jedna skrzynka w wierszu (porównanie wielu skrzynek), dwuklik otwiera jej szczegóły.' | Out-Null
    # Widok «Skrzynki»: dwuklik - szczegóły skrzynki w osobnym oknie; widok «Pola» - jak dotąd (szczegóły wiersza)
    $m.RowDoubleClick = {
        param($m, $row)
        $item = Get-HTObjectValue $row '__obj'
        if ($item -and $item.PSObject.Properties['__detail'] -and $item.__detail) {
            Show-HTDataViewer -Title "Skrzynka: $($item.Skrzynka)" -Description "$($item.Adres) • $($item.Typ)" -Data @(ConvertTo-HTDetailRows -Data $item.__detail) -ExportName "skrzynka_$($item.Adres)" -Icon 'E8A1'
        }
        else { Show-HTRowDetails -Module $m -Row $row }
    }
}

Register-HTModule -Workspace 'Exchange' -Category 'Skrzynka' -Key 'exo.usage' -Title 'Rozmiar i limity' -Icon 'EDA2' `
    -Description 'Rozmiar, liczba elementów, wykorzystanie limitu, archiwum i ostatnia aktywność. Wyróżnione - ponad 85% limitu.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź rozmiar' -Icon 'EDA2' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Rozmiar skrzynek' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTMailboxUsage -Identity $t.PrimarySmtpAddress }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Zaznacz wszystkie skrzynki na liście, aby uzyskać raport rozmiarów całej organizacji.' | Out-Null
}

Register-HTModule -Workspace 'Exchange' -Category 'Skrzynka' -Key 'exo.type' -Title 'Typ i widoczność' -Icon 'E8AB' `
    -Description 'Konwersja na skrzynkę współdzieloną / użytkownika / salę, ukrycie w książce adresowej, archiwum online.' -Build {
    param($m)
    # Najpierw odczyt (niebieski przycisk), potem zmiany (czerwone) - na wierszach zaznaczonych w wynikach albo na skrzynkach z listy po lewej
    $row0 = Add-HTToolbarRow -Module $m -Title 'Stan'
    Add-HTButton -Parent $row0 -Module $m -Text 'Pobierz informacje' -Icon 'E946' -Primary -OnClick {
        param($m)
        $target = Get-HTComboText $m.C.Type
        Invoke-HTTargetQuery -Module $m -Name 'Typ i widoczność' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTMailboxTypeInfo -Identity $t.PrimarySmtpAddress -TargetType $target }
    } | Out-Null
    Add-HTLabel -Parent $row0 -Hint -Text 'Typ, GAL i archiwum wybranych skrzynek. Żółte - inny typ niż wybrany niżej. Zaznacz wiersze w wynikach, aby zmienić tylko je.' | Out-Null
    # Skrzynki do zmiany: zaznaczone wiersze wyników «Pobierz informacje», a bez zaznaczenia - skrzynki wybrane na liście
    $m.Data.Targets = {
        param($m)
        $rows = @(Get-HTResultSelection -Module $m | Where-Object { $_ -and $_.PSObject.Properties['__address'] -and $_.__address })
        if ($rows.Count) { return @($rows | ForEach-Object { [PSCustomObject]@{ PrimarySmtpAddress = $_.__address; DisplayName = $_.Skrzynka } }) }
        return @(Get-HTTargets -Module $m)
    }
    $row = Add-HTToolbarRow -Module $m -Title 'Typ skrzynki'
    $m.C.Type = Add-HTComboBox -Parent $row -Items @('Shared', 'Regular', 'Room', 'Equipment') -Width 140
    Add-HTButton -Parent $row -Module $m -Text 'Konwertuj' -Icon 'E8AB' -Danger -OnClick {
        param($m)
        $type = Get-HTComboText $m.C.Type
        Invoke-HTTargetAction -Module $m -Name "Konwersja na $type" -Targets (& $m.Data.Targets $m) -Danger -Confirm "Zmienić typ wybranych skrzynek na $($type)?" -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            Convert-HTMailboxType -Identity $t.PrimarySmtpAddress -Type $type
            "Typ: $type"
        }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Książka adresowa'
    Add-HTButton -Parent $row2 -Module $m -Text 'Ukryj w GAL' -Icon 'ED1A' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Ukrycie w GAL' -Summary 'Skrzynka ukryta w książce adresowej (GAL): tak' -Targets (& $m.Data.Targets $m) -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Set-HTMailboxHiddenFromGAL -Identity $t.PrimarySmtpAddress -Hidden $true; 'Ukryta' }
    } | Out-Null
    Add-HTButton -Parent $row2 -Module $m -Text 'Pokaż w GAL' -Icon 'E7B3' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Pokazanie w GAL' -Summary 'Skrzynka ukryta w książce adresowej (GAL): nie' -Targets (& $m.Data.Targets $m) -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Set-HTMailboxHiddenFromGAL -Identity $t.PrimarySmtpAddress -Hidden $false; 'Widoczna' }
    } | Out-Null
    $row3 = Add-HTToolbarRow -Module $m -Title 'Archiwum'
    $m.C.AutoExpand = Add-HTCheckBox -Parent $row3 -Text 'Archiwum automatycznie rozszerzane'
    Add-HTButton -Parent $row3 -Module $m -Text 'Włącz archiwum' -Icon 'E7B8' -Danger -OnClick {
        param($m)
        $auto = Test-HTChecked $m.C.AutoExpand
        Invoke-HTTargetAction -Module $m -Name 'Włączenie archiwum' -Summary "Archiwum automatycznie rozszerzane: $(if ($auto) { 'tak' } else { 'nie' })" -Targets (& $m.Data.Targets $m) -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Enable-HTMailboxArchive -Identity $t.PrimarySmtpAddress -AutoExpanding:$auto; 'Archiwum włączone' }
    } | Out-Null
}

Register-HTModule -Workspace 'Exchange' -Category 'Skrzynka' -Key 'exo.mobile' -Title 'Urządzenia mobilne' -Icon 'E8EA' `
    -Description 'Telefony i tablety synchronizujące pocztę (ActiveSync / Outlook Mobile). Usunięcie powiązania wymusza ponowną konfigurację.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż urządzenia' -Icon 'E8EA' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Urządzenia mobilne' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTMailboxMobileDevices -Identity $t.PrimarySmtpAddress }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń powiązanie urządzenia' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie urządzenia mobilnego' -Rows @($rows | Where-Object { $_.DeviceIdentity }) -Danger -Confirm 'Usunąć powiązanie zaznaczonych urządzeń ze skrzynką?' `
            -Label { param($r) "$($r.Device) ($($r.Model))" } -Action { param($r) Remove-HTMailboxMobileDevice -Identity $r.DeviceIdentity } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Uprawnienia
Register-HTModule -Workspace 'Exchange' -Category 'Uprawnienia' -Key 'exo.perms' -Title 'Uprawnienia do skrzynki' -Icon 'E8D7' `
    -Description 'Pełny dostęp, Wyślij jako i Wyślij w imieniu - także wiele osób naraz z różnymi uprawnieniami i automapowaniem (lista albo CSV). Kopie wiadomości wysłanych przez delegatów w Elementach wysłanych skrzynki. Prawy przycisk na wierszu - odebranie uprawnienia.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż uprawnienia' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Uprawnienia do skrzynek' -AlwaysShowObject -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            foreach ($p in @(Get-HTMailboxPermissions -Identity $t.PrimarySmtpAddress)) { [PSCustomObject]@{ Uprawnienie = $p.Type; Użytkownik = $p.User; Prawa = $p.AccessRights } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nadaj uprawnienia…' -Icon 'E8FA' -Create -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $form = Show-HTFormDialog -Title 'Nadaj uprawnienia' -Description "Skrzynki: $($targets.Count)" -Icon 'E8D7' -OkText 'Nadaj' -Fields @(
            @{ Name = 'User'; Label = 'Użytkownicy (adres e-mail, kilka - jeden w linii)'; Type = 'Multiline'; Required = $true; Height = 70 }
            @{ Name = 'Full'; Label = 'Pełny dostęp (FullAccess)'; Type = 'Check'; Default = $true }
            @{ Name = 'AutoMap'; Label = 'Automatyczne dodanie skrzynki w Outlooku (AutoMapping)'; Type = 'Check'; Default = $true }
            @{ Name = 'SendAs'; Label = 'Wyślij jako (SendAs)'; Type = 'Check' }
            @{ Name = 'OnBehalf'; Label = 'Wyślij w imieniu (SendOnBehalf)'; Type = 'Check' }
            @{ Name = 'CopySent'; Label = 'Zapisuj kopie wysłanych przez delegatów w Elementach wysłanych skrzynki (przy «jako» / «w imieniu»)'; Type = 'Check'; Default = $true }
        )
        if (-not $form) { return }
        $users = @(Split-HTInputList $form.User)
        $types = @()
        if ($form.Full) { $types += 'FullAccess' }
        if ($form.SendAs) { $types += 'SendAs' }
        if ($form.OnBehalf) { $types += 'SendOnBehalf' }
        if ($types.Count -eq 0) { Show-HTWarning 'Wybierz rodzaj uprawnień.'; return }
        Invoke-HTTargetAction -Module $m -Name 'Nadanie uprawnień' -Targets $targets -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            foreach ($u in $users) { Add-HTMailboxPermission -Identity $t.PrimarySmtpAddress -User $u -Type $types -AutoMapping $form.AutoMap }
            $copy = $form.CopySent -and ($types -contains 'SendAs' -or $types -contains 'SendOnBehalf')
            if ($copy) { Set-HTMailboxSentItemsCopy -Identity $t.PrimarySmtpAddress }
            "$($types -join ', ') dla: $($users -join ', ')$(if ($copy) { '; kopie wysłanych włączone' })"
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nadaj z listy…' -Icon 'E8FD' -Create -ToolTip 'Wiele osób naraz, każda z innymi uprawnieniami i automapowaniem - lista «adres; uprawnienia; automapowanie» albo plik CSV' -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $prev = @{}
        $get = { param($k, $d) if ($prev.Contains($k)) { $prev[$k] } else { $d } }
        $addLines = { param($w, [string[]]$Lines) $box = $w.Tag.Controls['List'].Control; $box.Text = (@(([string]$box.Text).TrimEnd()) + @($Lines) | Where-Object { $_ }) -join "`r`n" }
        while ($true) {
            $form = Show-HTFormDialog -Title 'Nadaj uprawnienia z listy' -Icon 'E8D7' -OkText 'Dalej' -Width 720 -MaxHeight 720 `
                -Description "Skrzynki: $($targets.Count). Jedna osoba w linii: adres; uprawnienia; automapowanie - np. «jan@firma.pl; pełny, jako; nie». Linia bez uprawnień - ustawienia domyślne poniżej." -Fields @(
                @{ Name = 'List'; Label = 'Osoby (uprawnienia: pełny, jako, w imieniu, wszystkie; automapowanie: tak / nie)'; Type = 'Multiline'; Height = 200; Required = $true; Default = (& $get 'List' '') }
                @{ Type = 'Buttons'; Buttons = @(
                        @{ Text = 'Wybierz osoby…'; Icon = 'E716'; OnClick = { param($w) $picked = @(Select-HTRecipientAddress -Multiple -Title 'Osoby z dostępem do skrzynki' | Where-Object { $_ }); if ($picked.Count) { & $addLines $w $picked } }.GetNewClosure() }
                        @{ Text = 'Wczytaj z CSV…'; Icon = 'E8E5'; OnClick = {
                                param($w)
                                $path = Select-HTOpenFile -Title 'Plik CSV: Uzytkownik; Uprawnienia; Automapowanie' -Filter 'CSV (*.csv)|*.csv'
                                if (-not $path) { return }
                                try { & $addLines $w @(ConvertFrom-HTMailboxPermissionCsv -Path $path) } catch { Show-HTError -Text 'Nie wczytano pliku CSV.' -ErrorObject $_ }
                            }.GetNewClosure() }
                    ) }
                @{ Type = 'Header'; Label = 'Domyślnie (linie bez uprawnień)' }
                @{ Name = 'DefFull'; Label = 'Pełny dostęp (FullAccess)'; Type = 'Check'; Default = (& $get 'DefFull' $true) }
                @{ Name = 'DefSendAs'; Label = 'Wyślij jako (SendAs)'; Type = 'Check'; Default = (& $get 'DefSendAs' $false) }
                @{ Name = 'DefOnBehalf'; Label = 'Wyślij w imieniu (SendOnBehalf)'; Type = 'Check'; Default = (& $get 'DefOnBehalf' $false) }
                @{ Name = 'DefAuto'; Label = 'Automapowanie - skrzynka sama pojawi się w Outlooku'; Type = 'Check'; Default = (& $get 'DefAuto' $true) }
                @{ Type = 'Header'; Label = 'Skrzynka' }
                @{ Name = 'CopySent'; Label = 'Zapisuj kopie wiadomości wysłanych przez delegatów («jako» / «w imieniu») w Elementach wysłanych skrzynki'; Type = 'Check'; Default = (& $get 'CopySent' $true) }
            )
            if (-not $form) { return }
            $prev = $form
            $defaults = @()
            if ($form.DefFull) { $defaults += 'FullAccess' }
            if ($form.DefSendAs) { $defaults += 'SendAs' }
            if ($form.DefOnBehalf) { $defaults += 'SendOnBehalf' }
            $entries = @(ConvertFrom-HTMailboxPermissionLines -Text ([string]$form.List) -DefaultTypes $defaults -DefaultAutoMapping ([bool]$form.DefAuto))
            $bad = @($entries | Where-Object { $_.Problem })
            if ($entries.Count -and -not $bad.Count) { break }
            Show-HTWarning -Title 'Nadaj uprawnienia z listy' -Text $(if (-not $entries.Count) { 'Lista jest pusta.' } else { "Popraw linie:`n`n" + (@($bad | Select-Object -First 25 | ForEach-Object { "$($_.Line) - $($_.Problem)" }) -join "`n") })
        }
        $copySent = [bool]$form.CopySent -and [bool]@($entries | Where-Object { $_.Types -contains 'SendAs' -or $_.Types -contains 'SendOnBehalf' }).Count
        $pairs = @(foreach ($t in $targets) { foreach ($e in $entries) { [PSCustomObject]@{ Mailbox = $t; Entry = $e } } })
        $summary = @(@("Skrzynki: $($targets.Count), osoby: $($entries.Count), operacji: $($pairs.Count)") +
            @($entries | Select-Object -First 40 | ForEach-Object { "$($_.User): $(Get-HTMailboxPermissionLabel -Types $_.Types -AutoMapping $_.AutoMapping)" }) +
            @($(if ($entries.Count -gt 40) { "… i $($entries.Count - 40) kolejnych" }), $(if ($copySent) { 'Kopie wiadomości wysłanych przez delegatów w Elementach wysłanych skrzynki: włączone' })) | Where-Object { $_ })
        $copied = @{}
        Invoke-HTTargetAction -Module $m -Name 'Nadanie uprawnień z listy' -Targets $pairs -Label { param($p) "$(Get-HTMailboxLabel $p.Mailbox) ← $($p.Entry.User)" } -Summary $summary -Action {
            param($p)
            $mailbox = [string]$p.Mailbox.PrimarySmtpAddress
            Add-HTMailboxPermission -Identity $mailbox -User $p.Entry.User -Type $p.Entry.Types -AutoMapping $p.Entry.AutoMapping
            $note = ''
            if ($copySent -and -not $copied.ContainsKey($mailbox)) { Set-HTMailboxSentItemsCopy -Identity $mailbox; $copied[$mailbox] = $true; $note = '; kopie wysłanych włączone' }
            [ordered]@{ Osoba = $p.Entry.User; Uprawnienia = (Get-HTMailboxPermissionLabel -Types $p.Entry.Types -AutoMapping $p.Entry.AutoMapping); Szczegóły = "Nadano$note" }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Kopie wysłanych' -Icon 'E724' -ToolTip 'Czy wiadomości wysłane przez delegatów («jako» / «w imieniu») trafiają też do Elementów wysłanych skrzynki' -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Kopie wysłanych przez delegatów' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTMailboxSentItemsCopy -Identity $t.PrimarySmtpAddress }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Ustaw kopie wysłanych…' -Icon 'E724' -Danger -ToolTip 'Włączenie albo wyłączenie kopii wiadomości wysłanych przez delegatów w Elementach wysłanych zaznaczonych skrzynek' -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $form = Show-HTFormDialog -Title 'Kopie wysłanych przez delegatów' -Icon 'E724' -OkText 'Dalej' -Width 640 -Description "Skrzynki: $($targets.Count). Gdy delegat wysyła z tej skrzynki, kopia wiadomości trafia też do jej Elementów wysłanych (widzą ją wszyscy z dostępem), a nie tylko do skrzynki delegata." -Fields @(
            @{ Name = 'SentAs'; Label = 'Kopia wiadomości wysłanych «jako» (SendAs)'; Type = 'Check'; Default = $true }
            @{ Name = 'OnBehalf'; Label = 'Kopia wiadomości wysłanych «w imieniu» (SendOnBehalf)'; Type = 'Check'; Default = $true }
        )
        if (-not $form) { return }
        $sentAs = [bool]$form.SentAs
        $onBehalf = [bool]$form.OnBehalf
        Invoke-HTTargetAction -Module $m -Name 'Kopie wysłanych przez delegatów' -Targets $targets -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            Set-HTMailboxSentItemsCopy -Identity $t.PrimarySmtpAddress -SentAs $sentAs -SendOnBehalf $onBehalf
            "«jako»: $(if ($sentAs) { 'tak' } else { 'nie' }), «w imieniu»: $(if ($onBehalf) { 'tak' } else { 'nie' })"
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Odbierz uprawnienie' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Odebranie uprawnień' -Rows @($rows | Where-Object { $_.Uprawnienie }) -Danger -Confirm 'Odebrać zaznaczone uprawnienia?' `
            -Label { param($r) "$($r.Obiekt): $($r.Uprawnienie) - $($r.Użytkownik)" } -Action {
            param($r)
            Remove-HTMailboxPermission -Identity $r.__target.PrimarySmtpAddress -User $r.Użytkownik -Type $r.Uprawnienie
            Register-HTUndo -Operation 'Odebranie uprawnienia do skrzynki' -Object "$($r.__target.PrimarySmtpAddress) - $($r.Użytkownik)" -Kind 'MailboxPermission' -Data @{ Identity = $r.__target.PrimarySmtpAddress; User = $r.Użytkownik; Type = $r.Uprawnienie }
        } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'Exchange' -Category 'Uprawnienia' -Key 'exo.access' -Title 'Dostęp użytkownika' -Icon 'E716' `
    -Description 'Do których skrzynek ma dostęp wskazany użytkownik (FullAccess, SendAs, SendOnBehalf)? Przegląd wszystkich skrzynek może potrwać kilka minut.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Użytkownik'
    $m.C.User = Add-HTTextBox -Parent $row -Width 300 -Placeholder 'adres e-mail (puste = zaznaczona skrzynka)'
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź dostęp' -Icon 'E721' -Primary -OnClick {
        param($m)
        $user = $m.C.User.Text.Trim()
        if (-not $user) {
            $t = @(Get-HTTargets -Module $m -Single)[0]
            if (-not $t) { return }
            $user = $t.PrimarySmtpAddress
        }
        Invoke-HTQuery -Module $m -Name "Dostęp użytkownika $user" -ScriptBlock {
            Get-HTUserMailboxAccess -User $user -OnProgress { param($i, $total, $name) if ($i % 5 -eq 0 -or $i -eq $total) { Set-HTProgress -Value $i -Maximum $total -Text "Sprawdzanie skrzynek [$i/$total] $name" } }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Odbierz uprawnienie' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $user = $m.C.User.Text.Trim()
        if (-not $user) { Show-HTWarning 'Wpisz adres użytkownika w polu powyżej.'; return }
        Invoke-HTRowAction -Module $m -Name 'Odebranie uprawnień' -Rows $rows -Danger -Confirm "Odebrać użytkownikowi $user zaznaczone uprawnienia?" `
            -Label { param($r) "$($r.Adres): $($r.Uprawnienie)" } -Action { param($r) Remove-HTMailboxPermission -Identity $r.Adres -User $user -Type $r.Uprawnienie }
    }
}

Register-HTModule -Workspace 'Exchange' -Category 'Uprawnienia' -Key 'exo.calendar' -Title 'Kalendarz' -Icon 'E787' `
    -Description 'Uprawnienia do kalendarza (Reviewer, Editor, AvailabilityOnly…). Nazwa folderu wykrywana automatycznie (Kalendarz / Calendar).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż uprawnienia' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Uprawnienia kalendarza' -AlwaysShowObject -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            foreach ($p in @(Get-HTCalendarPermissions -Identity $t.PrimarySmtpAddress)) { [PSCustomObject]@{ Użytkownik = $p.User; Uprawnienia = $p.AccessRights; Delegat = $p.SharingPermissionFlags; Folder = $p.Folder } }
        }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Nadaj'
    $m.C.User = Add-HTTextBox -Parent $row2 -Width 260 -Placeholder 'Użytkownik (e-mail) lub Default'
    $m.C.Level = Add-HTComboBox -Parent $row2 -Items @('Reviewer', 'LimitedDetails', 'AvailabilityOnly', 'Author', 'Editor', 'PublishingEditor', 'Owner', 'None') -Width 160
    Add-HTButton -Parent $row2 -Module $m -Text 'Ustaw' -Icon 'E73E' -Danger -OnClick {
        param($m)
        $user = $m.C.User.Text.Trim()
        if (-not $user) { Show-HTWarning 'Podaj użytkownika.'; return }
        $level = Get-HTComboText $m.C.Level
        Invoke-HTTargetAction -Module $m -Name 'Uprawnienia kalendarza' -Summary @("Użytkownik: $user", "Poziom uprawnień do kalendarza: $level") -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Set-HTCalendarPermission -Identity $t.PrimarySmtpAddress -User $user -AccessRights $level; "$user : $level" }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń uprawnienie' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie uprawnień kalendarza' -Rows @($rows | Where-Object { $_.Użytkownik -notin 'Default', 'Anonymous', 'Domyślne', 'Anonimowe' }) -Confirm 'Usunąć zaznaczone uprawnienia do kalendarza?' `
            -Label { param($r) "$($r.Obiekt): $($r.Użytkownik)" } -Action { param($r) Remove-HTCalendarPermission -Identity $r.__target.PrimarySmtpAddress -User $r.Użytkownik } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Poczta
Register-HTModule -Workspace 'Exchange' -Category 'Poczta' -Key 'exo.autoreply' -Title 'Autoodpowiedź' -Icon 'E8BD' `
    -Description 'Odpowiedzi automatyczne (poza biurem): podgląd, włączenie, zaplanowanie w czasie, wyłączenie i wyczyszczenie treści.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż stan' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Autoodpowiedzi' -AlwaysShowObject -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            $a = Get-HTMailboxAutoReply -Identity $t.PrimarySmtpAddress
            [PSCustomObject]@{ Stan = "$($a.AutoReplyState)"; Od = $(if ("$($a.AutoReplyState)" -eq 'Scheduled') { $a.StartTime }); Do = $(if ("$($a.AutoReplyState)" -eq 'Scheduled') { $a.EndTime })
                'Odbiorcy zewn.' = "$($a.ExternalAudience)"; Wewnętrzna = (ConvertFrom-HTAutoReplyHtml $a.InternalMessage); Zewnętrzna = (ConvertFrom-HTAutoReplyHtml $a.ExternalMessage)
                __flag = $(if ("$($a.AutoReplyState)" -eq 'Disabled') { 'muted' } else { '' }) }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Ustaw…' -Icon 'E70F' -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $current = $null
        if ($targets.Count -eq 1) { try { $current = Get-HTMailboxAutoReply -Identity $targets[0].PrimarySmtpAddress } catch { $current = $null } }
        $form = Show-HTFormDialog -Title 'Autoodpowiedź' -Description "Skrzynki: $($targets.Count)" -Icon 'E8BD' -Width 640 -Fields @(
            @{ Name = 'State'; Label = 'Tryb'; Type = 'Combo'; Options = @('Enabled', 'Scheduled', 'Disabled'); Default = $(if ($current) { "$($current.AutoReplyState)" } else { 'Enabled' }) }
            @{ Name = 'Start'; Label = 'Od'; Type = 'Date'; Optional = $true; ShowWhen = @{ Field = 'State'; Values = @('Scheduled') }; Default = $(if ($current -and "$($current.AutoReplyState)" -eq 'Scheduled') { $current.StartTime } else { (Get-Date).Date.AddHours(8) }) }
            @{ Name = 'End'; Label = 'Do'; Type = 'Date'; Optional = $true; ShowWhen = @{ Field = 'State'; Values = @('Scheduled') }; Default = $(if ($current -and "$($current.AutoReplyState)" -eq 'Scheduled') { $current.EndTime } else { (Get-Date).Date.AddDays(7).AddHours(17) }) }
            @{ Name = 'Internal'; Label = 'Wiadomość wewnętrzna'; Type = 'Multiline'; ShowWhen = @{ Field = 'State'; Values = @('Enabled', 'Scheduled') }; Default = $(if ($current) { ConvertFrom-HTAutoReplyHtml $current.InternalMessage }) }
            @{ Name = 'External'; Label = 'Wiadomość zewnętrzna (puste = jak wewnętrzna)'; Type = 'Multiline'; ShowWhen = @{ Field = 'State'; Values = @('Enabled', 'Scheduled') }; Default = $(if ($current) { ConvertFrom-HTAutoReplyHtml $current.ExternalMessage }) }
            @{ Name = 'Audience'; Label = 'Odbiorcy zewnętrzni'; Type = 'Combo'; Options = @('All', 'Known', 'None'); ShowWhen = @{ Field = 'State'; Values = @('Enabled', 'Scheduled') }; Default = $(if ($current) { "$($current.ExternalAudience)" } else { 'All' }) }
        )
        if (-not $form) { return }
        if ($form.State -ne 'Disabled' -and -not $form.Internal) { Show-HTWarning 'Wpisz treść wiadomości.'; return }
        Invoke-HTTargetAction -Module $m -Name 'Autoodpowiedź' -Targets $targets -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            Set-HTMailboxAutoReply -Identity $t.PrimarySmtpAddress -State $form.State -InternalMessage $form.Internal -ExternalMessage $form.External -ExternalAudience $form.Audience -StartTime $form.Start -EndTime $form.End
            "Tryb: $($form.State)"
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Wyłącz' -Icon 'E711' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Wyłączenie autoodpowiedzi' -Summary 'Tryb: Disabled (odpowiedzi automatyczne wyłączone)' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Set-HTMailboxAutoReply -Identity $t.PrimarySmtpAddress -State Disabled; 'Wyłączona' }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Wyczyść' -Icon 'E894' -Danger -ToolTip 'Wyłącza autoodpowiedź i usuwa jej treść (dla osób z firmy i spoza firmy) - niezależnie od tego, czy jest włączona' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Wyczyszczenie autoodpowiedzi' -Summary @('Tryb: Disabled', 'Treść wewnętrzna i zewnętrzna: usunięta') -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Clear-HTMailboxAutoReply -Identity $t.PrimarySmtpAddress; 'Wyłączona, treść usunięta' }
    } | Out-Null
}

Register-HTModule -Workspace 'Exchange' -Category 'Poczta' -Key 'exo.forward' -Title 'Przekierowanie' -Icon 'E89C' `
    -Description 'Przekierowanie poczty na inny adres (z kopią w skrzynce lub bez) i jego usunięcie.' -Build {
    param($m)
    Add-HTStateCheck -Module $m -Label { param($t) Get-HTMailboxLabel $t } -Action {
        param($t)
        Select-HTDetailFields -Detail (Get-HTMailboxDetail -Identity $t.PrimarySmtpAddress) -Fields 'Typ skrzynki', 'Przekieruj do', 'Zachowaj kopię'
    } | Out-Null
    $row = Add-HTToolbarRow -Module $m -Title 'Przekieruj do'
    $m.C.To = Add-HTTextBox -Parent $row -Width 280 -Placeholder 'adres@domena.pl'
    Add-HTAddressPicker -Parent $row -Module $m -TextBox $m.C.To | Out-Null
    $m.C.Keep = Add-HTCheckBox -Parent $row -Text 'Zachowaj kopię w skrzynce' -Checked $true
    Add-HTButton -Parent $row -Module $m -Text 'Ustaw' -Icon 'E89C' -Primary -Danger -OnClick {
        param($m)
        $to = $m.C.To.Text.Trim()
        if (-not (Test-HTInputValue -Value $to -ValidationType Email)) { Show-HTWarning 'Podaj prawidłowy adres e-mail.'; return }
        $keep = Test-HTChecked $m.C.Keep
        Invoke-HTTargetAction -Module $m -Name 'Przekierowanie' -Confirm "Przekierować pocztę do $($to)?" -Summary @("Przekierowanie do: $to", "Kopia w skrzynce: $(if ($keep) { 'tak' } else { 'nie' })") -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            Set-HTMailboxForwarding -Identity $t.PrimarySmtpAddress -ForwardTo $to -KeepCopy $keep
            $t.Forwarding = $to
            Update-HTTargetItem -Panel (Get-HTPanel 'mailboxes') -Item $t
            "Do: $to$(if ($keep) { ' (z kopią)' })"
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Usuń przekierowanie' -Icon 'E711' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie przekierowania' -Summary 'Przekierowanie poczty: (wyczyść)' -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            Set-HTMailboxForwarding -Identity $t.PrimarySmtpAddress -ForwardTo ''
            $t.Forwarding = ''
            Update-HTTargetItem -Panel (Get-HTPanel 'mailboxes') -Item $t
            'Usunięto'
        }
    } | Out-Null
}

Register-HTModule -Workspace 'Exchange' -Category 'Poczta' -Key 'exo.rules' -Title 'Reguły skrzynki' -Icon 'E71C' `
    -Description 'Reguły Outlooka użytkownika. Wyróżnione - przekazujące lub usuwające pocztę (częsty ślad przejęcia konta).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż reguły' -Icon 'E71C' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Reguły skrzynki' -AlwaysShowObject -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTInboxRules -Identity $t.PrimarySmtpAddress }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Wyłącz regułę' -Icon 'E711' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Wyłączenie reguły' -Rows @($rows | Where-Object { $_.RuleIdentity }) -Label { param($r) "$($r.Obiekt): $($r.Name)" } `
            -Action { param($r) Disable-HTInboxRule -Mailbox $r.__target.PrimarySmtpAddress -Identity $r.RuleIdentity } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Usuń regułę' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie reguły' -Rows @($rows | Where-Object { $_.RuleIdentity }) -Danger -Confirm 'Usunąć zaznaczone reguły?' -Label { param($r) "$($r.Obiekt): $($r.Name)" } `
            -Action { param($r) Remove-HTInboxRule -Mailbox $r.__target.PrimarySmtpAddress -Identity $r.RuleIdentity } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'Exchange' -Category 'Poczta' -Key 'exo.trace' -Title 'Śledzenie wiadomości' -Icon 'E721' `
    -Description 'Czy wiadomość dotarła? Wyniki śledzenia (do 10 dni wstecz) dla adresu wpisanego lub zaznaczonych skrzynek.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Parametry'
    $m.C.Address = Add-HTTextBox -Parent $row -Width 260 -Placeholder 'adres (puste = zaznaczone skrzynki)'
    $m.C.Direction = Add-HTSegmented -Parent $row -Items @('Odebrane', 'Wysłane')
    Add-HTLabel -Parent $row -Text 'Dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 2 -Minimum 1 -Maximum 10
    Add-HTButton -Parent $row -Module $m -Text 'Szukaj' -Icon 'E721' -Primary -OnClick {
        param($m)
        $direction = if ((Get-HTSegmentIndex $m.C.Direction) -eq 1) { 'Sent' } else { 'Received' }
        $days = Get-HTNum $m.C.Days
        $address = $m.C.Address.Text.Trim()
        if ($address) {
            Invoke-HTQuery -Module $m -Name 'Śledzenie wiadomości' -ScriptBlock { Get-HTMessageTrace -Address $address -Direction $direction -Days $days }
        }
        else {
            Invoke-HTTargetQuery -Module $m -Name 'Śledzenie wiadomości' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTMessageTrace -Address $t.PrimarySmtpAddress -Direction $direction -Days $days }
        }
    } | Out-Null
}
#endregion

#region Grupy i adresy
Register-HTModule -Workspace 'Exchange' -Category 'Grupy i adresy' -Key 'exo.aliases' -Title 'Adresy e-mail' -Icon 'E910' `
    -Description 'Aliasy (dodatkowe adresy) skrzynki: dodawanie, usuwanie i zmiana adresu głównego. Adresy systemowe (SIP - Teams, SPO - SharePoint, X500) są tylko do podglądu. Dla skrzynek synchronizowanych z AD adresy zmienia się w lokalnym AD (proxyAddresses).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż adresy' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Adresy e-mail' -AlwaysShowObject -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTMailboxAddresses -Identity $t.PrimarySmtpAddress }
    } | Out-Null
    $m.C.Alias = Add-HTTextBox -Parent $row -Width 260 -Placeholder 'nowy.alias@domena.pl'
    Add-HTButton -Parent $row -Module $m -Text 'Dodaj alias' -Icon 'E710' -Create -OnClick {
        param($m)
        $alias = $m.C.Alias.Text.Trim()
        $t = @(Get-HTChangeTargets -Module $m -Single)[0]
        if (-not $t) { return }
        Invoke-HTTargetAction -Module $m -Name 'Dodanie aliasu' -Summary "Nowy adres (alias): $alias" -Targets @($t) -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Add-HTMailboxAddress -Identity $t.PrimarySmtpAddress -Address $alias; "Dodano: $alias" }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń adres' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        # Tylko dodatkowe adresy SMTP (aliasy): adres główny zmienia się przez «Ustaw jako adres główny», a adresy systemowe
        # (SIP - Teams / Skype, SPO - SharePoint, X500 - migracje) tworzy i potrzebuje Microsoft 365
        $smtp = @($rows | Where-Object { $_ -and $_.Wartość -and [string]$_.Typ -eq 'SMTP' -and -not $_.Główny })
        $skipped = @($rows | Where-Object { $_ -and $smtp -notcontains $_ })
        if ($skipped.Count) { Write-Log -Message "Usunięcie adresu - pominięto (adres główny albo systemowy): $(@($skipped | ForEach-Object { "$($_.Typ) $($_.Adres)" }) -join ', ')" -Type 'Warn' }
        if (-not $smtp.Count) { Show-HTWarning 'Usunąć można tylko dodatkowe adresy SMTP (aliasy). Adres główny zmień przez «Ustaw jako adres główny». Adresów systemowych (SIP - Teams, SPO - SharePoint, X500) nie usuwaj - tworzy je i używa Microsoft 365.' -Title 'Adresy e-mail'; return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie adresu' -Rows $smtp -Confirm "Usunąć zaznaczone aliasy?$(if ($skipped.Count) { " Pominięte (główny albo systemowy): $($skipped.Count)." })" -Label { param($r) "$($r.Obiekt): $($r.Adres)" } `
            -Action { param($r) Remove-HTMailboxAddress -Identity $r.__target.PrimarySmtpAddress -Value $r.Wartość } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Ustaw jako adres główny' -Icon 'E8FB' -Danger -Action {
        param($m, $rows)
        $r = @($rows | Where-Object { $_.Typ -eq 'SMTP' -and -not $_.Główny })[0]
        if (-not $r) { Show-HTWarning 'Zaznacz dodatkowy adres SMTP (alias), który ma zostać adresem głównym.'; return }
        Invoke-HTRowAction -Module $m -Name 'Zmiana adresu głównego' -Rows @($r) -Confirm "Ustawić $($r.Adres) jako adres główny? Dotychczasowy adres zostanie aliasem (poczta nadal dotrze), a wiadomości będą wysyłane z nowego adresu." `
            -Label { param($x) "$($x.__target.PrimarySmtpAddress) -> $($x.Adres)" } -Action { param($x) Set-HTMailboxPrimaryAddress -Identity $x.__target.PrimarySmtpAddress -Address $x.Adres; 'Adres główny zmieniony' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'Exchange' -Category 'Grupy i adresy' -Key 'exo.dl' -Title 'Grupy dystrybucyjne' -Icon 'E902' `
    -Description 'Listy dystrybucyjne: tworzenie, ustawienia (właściciele, dołączanie, kto może pisać, moderowanie), członkowie, przynależność skrzynek, dodawanie i usuwanie członków oraz usuwanie grup (prawy przycisk).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Wszystkie grupy' -Icon 'E902' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Grupy dystrybucyjne' -ScriptBlock { Get-HTDistributionGroups } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nowa grupa…' -Create -NoRowMenu -Icon 'E710' -OnClick { param($m) New-HTDistributionGroupInteractive -Module $m } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Grupy zaznaczonych skrzynek' -Icon 'E716' -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Przynależność do grup' -AlwaysShowObject -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            foreach ($g in @(Get-HTRecipientGroups -Identity $t.PrimarySmtpAddress)) { [PSCustomObject]@{ Nazwa = $g.Grupa; Adres = $g.Adres; Typ = $g.Typ; Identity = $g.Adres } }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Pokaż członków' -Icon 'E716' -Action {
        param($m, $rows)
        $g = @($rows)[0]
        Set-HTBusy -Busy $true -Text "Członkowie $($g.Nazwa)…"
        try { $members = @(Get-HTDistributionGroupMembers -Identity $g.Identity) } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        Show-HTDataViewer -Title "Członkowie: $($g.Nazwa)" -Description "$($members.Count) członków" -Data $members -ExportName "czlonkowie_$($g.Nazwa)"
    }
    Add-HTRowAction -Module $m -Text 'Dodaj zaznaczone skrzynki do grupy' -Icon 'E710' -Create -Action {
        param($m, $rows)
        $mailboxes = @(Get-HTTargets -Module $m)
        if ($mailboxes.Count -eq 0) { return }
        foreach ($g in @($rows)) {
            Invoke-HTRowAction -Module $m -Name "Dodanie do $($g.Nazwa)" -Rows $mailboxes -Confirm "Dodać $($mailboxes.Count) skrzynek do grupy $($g.Nazwa)?" -Label { param($r) Get-HTMailboxLabel $r } `
                -Action { param($r) Add-HTDistributionGroupMember -Group $g.Identity -Member $r.PrimarySmtpAddress }
        }
    }
    Add-HTRowAction -Module $m -Text 'Usuń zaznaczone skrzynki z grupy' -Icon 'E738' -Danger -Action {
        param($m, $rows)
        $mailboxes = @(Get-HTTargets -Module $m)
        if ($mailboxes.Count -eq 0) { return }
        foreach ($g in @($rows)) {
            Invoke-HTRowAction -Module $m -Name "Usunięcie z $($g.Nazwa)" -Rows $mailboxes -Danger -Confirm "Usunąć $($mailboxes.Count) skrzynek z grupy $($g.Nazwa)?" -Label { param($r) Get-HTMailboxLabel $r } `
                -Action { param($r) Remove-HTDistributionGroupMember -Group $g.Identity -Member $r.PrimarySmtpAddress }
        }
    }
    Add-HTRowAction -Module $m -Text 'Ustawienia grupy…' -Icon 'E713' -Danger -Action {
        param($m, $rows)
        $groups = @($rows | Where-Object { $_.Identity })
        if ($groups.Count -eq 0) { return }
        $defs = @(Get-HTMailboxSettingDefinitions -Group)
        $current = $null
        if ($groups.Count -eq 1) {
            Set-HTBusy -Busy $true -Text "Odczyt ustawień grupy $($groups[0].Nazwa)…"
            try { $current = Get-HTMailboxSettings -Identity $groups[0].Identity -Definitions $defs }
            catch { Set-HTBusy -Busy $false -Text 'Błąd'; Show-HTError 'Nie odczytano ustawień grupy.' $_; return }
            finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        }
        $desc = if ($groups.Count -eq 1) { "$($groups[0].Nazwa) <$($groups[0].Identity)>" } else { "Grup: $($groups.Count) - zmienione zostaną tylko wypełnione pola" }
        $changes = Show-HTSettingsEditor -Title 'Ustawienia grupy' -Description $desc -Definitions $defs -Current $current -Objects @($groups | ForEach-Object { $_.Nazwa }) -Icon 'E902'
        if (-not $changes) { return }
        $plan = ConvertTo-HTMailboxSettingPlan -Changes @($changes)
        Invoke-HTRowAction -Module $m -Name 'Ustawienia grupy' -Rows $groups -NoConfirm -Label { param($r) $r.Nazwa } -Action { param($r) Invoke-HTMailboxSettingPlan -Identity $r.Identity -Plan $plan } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Dodaj członków (adresy)…' -Icon 'E8FA' -Create -Action {
        param($m, $rows)
        $g = @($rows | Where-Object { $_.Identity })[0]
        if (-not $g) { return }
        $members = @(Split-HTInputList (Show-InputBox -Title "Dodaj do: $($g.Nazwa)" -Prompt 'Adresy e-mail członków (jeden w linii, przecinek albo średnik):' -Multiline -Icon 'E8FA'))
        if ($members.Count -eq 0) { return }
        Invoke-HTRowAction -Module $m -Name "Dodanie członków do $($g.Nazwa)" -Summary @("Nowi członkowie ($($members.Count)): $(@($members | Select-Object -First 15) -join ', ')$(if ($members.Count -gt 15) { ' …' })") -Rows @($g) -Label { param($r) $r.Nazwa } -Action {
            param($r)
            $res = Add-HTDistributionGroupMembers -Group $r.Identity -Members $members
            if (@($res.Errors).Count) { throw "dodano: $($res.Added); błędy: $(@($res.Errors) -join '; ')" }
            "Dodano: $($res.Added) (pozostali już byli członkami)"
        }
    }
    Add-HTRowAction -Module $m -Text 'Usuń grupę' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $groups = @($rows | Where-Object { $_.Identity -and $_.Typ -ne 'GroupMailbox' })
        if ($groups.Count -eq 0) { Show-HTWarning 'Zaznacz grupy dystrybucyjne (grupy Microsoft 365 - przestrzeń Microsoft 365 > Grupy).'; return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie grupy' -Rows $groups -Danger -TypeToConfirm 'USUŃ' -Confirm 'Usunąć zaznaczone grupy? Wiadomości na ich adresy przestaną być dostarczane. Grup dystrybucyjnych nie można przywrócić.' `
            -Label { param($r) "$($r.Nazwa) <$($r.Identity)>" } -Action { param($r) Remove-HTMailDistributionGroup -Identity $r.Identity; 'Usunięto' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Zgodność
Register-HTModule -Workspace 'Exchange' -Category 'Zgodność' -Key 'exo.quarantine' -Title 'Kwarantanna' -Icon 'EA18' -Service 'Exchange' `
    -Description 'Wiadomości zatrzymane przez filtr spamu / phishingu / malware. Zwolnienie, podgląd treści i usunięcie (prawy przycisk).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.Scope = Add-HTSegmented -Parent $row -Items @('Zaznaczone skrzynki', 'Cała organizacja')
    Add-HTLabel -Parent $row -Text 'Dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 7 -Minimum 1 -Maximum 30
    $m.C.Sender = Add-HTTextBox -Parent $row -Width 220 -Placeholder 'Nadawca (opcjonalnie)'
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż' -Icon 'E72C' -Primary -OnClick {
        param($m)
        $days = Get-HTNum $m.C.Days
        $fromAddress = $m.C.Sender.Text.Trim()
        $recipients = @()
        if ((Get-HTSegmentIndex $m.C.Scope) -eq 0) {
            $recipients = @(Get-HTTargets -Module $m | ForEach-Object { $_.PrimarySmtpAddress })
            if ($recipients.Count -eq 0) { return }
        }
        Invoke-HTQuery -Module $m -Name 'Kwarantanna' -ScriptBlock { Get-HTQuarantineMessages -Recipients $recipients -Days $days -SenderAddress $fromAddress }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Podgląd treści' -Icon 'E8A1' -Action {
        param($m, $rows)
        $r = @($rows)[0]
        Set-HTBusy -Busy $true -Text 'Pobieranie wiadomości…'
        try { $text = Get-HTQuarantinePreview -Identity $r.Identity } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        Show-HTTextDialog -Title "Kwarantanna: $($r.Temat)" -Subtitle $r.Nadawca -Text $text
    }
    Add-HTRowAction -Module $m -Text 'Zwolnij do odbiorców' -Icon 'E73E' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Zwolnienie z kwarantanny' -Rows $rows -Confirm 'Zwolnić zaznaczone wiadomości do wszystkich odbiorców?' -Label { param($r) "$($r.Nadawca): $($r.Temat)" } -Action { param($r) Invoke-HTQuarantineRelease -Identity $r.Identity }
    }
    Add-HTRowAction -Module $m -Text 'Zwolnij i zezwól nadawcy' -Icon 'E8FB' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Zwolnienie i zezwolenie' -Rows $rows -Confirm 'Zwolnić wiadomości i dodać nadawców do listy dozwolonych?' -Label { param($r) "$($r.Nadawca): $($r.Temat)" } -Action { param($r) Invoke-HTQuarantineRelease -Identity $r.Identity -AllowSender }
    }
    Add-HTRowAction -Module $m -Text 'Usuń z kwarantanny' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie z kwarantanny' -Rows $rows -Danger -Confirm 'Trwale usunąć zaznaczone wiadomości?' -Label { param($r) "$($r.Nadawca): $($r.Temat)" } -Action { param($r) Remove-HTQuarantineMessage -Identity $r.Identity }
    }
}

Register-HTModule -Workspace 'Exchange' -Category 'Zgodność' -Key 'exo.recover' -Title 'Odzyskiwanie elementów' -Icon 'E777' `
    -Description 'Przywracanie usuniętych wiadomości i elementów z folderu Elementy możliwe do odzyskania (wymaga roli Mailbox Import Export).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Filtr'
    Add-HTLabel -Parent $row -Text 'Usunięte w ciągu dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 14 -Minimum 1 -Maximum 90
    $m.C.Subject = Add-HTTextBox -Parent $row -Width 240 -Placeholder 'Temat zawiera (opcjonalnie)'
    Add-HTButton -Parent $row -Module $m -Text 'Szukaj' -Icon 'E721' -Primary -OnClick {
        param($m)
        $days = Get-HTNum $m.C.Days
        $subject = $m.C.Subject.Text.Trim()
        Invoke-HTTargetQuery -Module $m -Name 'Elementy do odzyskania' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTRecoverableItems -Identity $t.PrimarySmtpAddress -Days $days -SubjectContains $subject }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Przywróć' -Icon 'E777' -Create -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Przywrócenie elementów' -Rows @($rows | Where-Object { $_.EntryID }) -Confirm 'Przywrócić zaznaczone elementy do pierwotnych folderów?' -Label { param($r) "$($r.Skrzynka): $($r.Temat)" } `
            -Action { param($r) Restore-HTRecoverableItem -Identity $r.Skrzynka -EntryID $r.EntryID }
    }
}

Register-HTModule -Workspace 'Exchange' -Category 'Zgodność' -Key 'exo.hold' -Title 'Litigation Hold i retencja' -Icon 'E72E' `
    -Description 'Blokada postępowania sądowego (zachowanie całej zawartości skrzynki) i czas przechowywania usuniętych elementów (do 30 dni).' -Build {
    param($m)
    Add-HTStateCheck -Module $m -Label { param($t) Get-HTMailboxLabel $t } -Action {
        param($t)
        Select-HTDetailFields -Detail (Get-HTMailboxDetail -Identity $t.PrimarySmtpAddress) -Fields 'Typ skrzynki', 'Litigation Hold', 'Retencja elementów usuniętych', 'Archiwum', 'Rozmiar'
    } | Out-Null
    $row = Add-HTToolbarRow -Module $m -Title 'Litigation Hold'
    Add-HTLabel -Parent $row -Text 'Czas (dni, 0 = bez limitu):' | Out-Null
    $m.C.Duration = Add-HTNumeric -Parent $row -Value 0 -Minimum 0 -Maximum 36500
    Add-HTButton -Parent $row -Module $m -Text 'Włącz' -Icon 'E72E' -Primary -Danger -OnClick {
        param($m)
        $days = Get-HTNum $m.C.Duration
        Invoke-HTTargetAction -Module $m -Name 'Litigation Hold' -Confirm 'Włączyć Litigation Hold dla wybranych skrzynek? (wymaga licencji Exchange Plan 2 lub archiwum)' -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            Set-HTMailboxLitigationHold -Identity $t.PrimarySmtpAddress -Enabled $true -DurationDays $days
            "Włączono$(if ($days) { " na $days dni" } else { ' bez limitu' })"
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Wyłącz' -Icon 'E785' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Wyłączenie Litigation Hold' -Confirm 'Wyłączyć Litigation Hold?' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Set-HTMailboxLitigationHold -Identity $t.PrimarySmtpAddress -Enabled $false; 'Wyłączono' }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Usunięte elementy'
    Add-HTLabel -Parent $row2 -Text 'Przechowuj (dni):' | Out-Null
    $m.C.Retain = Add-HTNumeric -Parent $row2 -Value 30 -Minimum 1 -Maximum 30
    Add-HTButton -Parent $row2 -Module $m -Text 'Ustaw' -Icon 'E73E' -Danger -OnClick {
        param($m)
        $days = Get-HTNum $m.C.Retain
        Invoke-HTTargetAction -Module $m -Name 'Retencja usuniętych elementów' -Summary "Przechowywanie usuniętych elementów: $days dni" -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Set-HTMailboxRetainDeletedItems -Identity $t.PrimarySmtpAddress -Days $days; "$days dni" }
    } | Out-Null
}
#endregion

#region Raporty
Register-HTModule -Workspace 'Organization' -Category 'Raporty' -Key 'exo.rep.forwarding' -Title 'Przekierowania zewnętrzne' -Icon 'E7BA' -Service 'Exchange' `
    -Description 'Audyt bezpieczeństwa: skrzynki i reguły przekazujące pocztę poza organizację (na czerwono - adresy spoza domen akceptowanych).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.Rules = Add-HTCheckBox -Parent $row -Text 'Sprawdź także reguły skrzynek (wolniej)' -Checked $true
    Add-HTButton -Parent $row -Module $m -Text 'Generuj raport' -Icon 'E9D2' -Primary -OnClick {
        param($m)
        $rules = Test-HTChecked $m.C.Rules
        Invoke-HTQuery -Module $m -Name 'Przekierowania zewnętrzne' -ScriptBlock {
            Get-HTExternalForwardingReport -IncludeInboxRules:$rules -OnProgress { param($i, $total, $name) if ($i % 5 -eq 0 -or $i -eq $total) { Set-HTProgress -Value $i -Maximum $total -Text "Reguły skrzynek [$i/$total] $name" } }
        }
    } | Out-Null
}

Register-HTModule -Workspace 'Organization' -Category 'Raporty' -Key 'exo.rep.inactive' -Title 'Nieaktywne skrzynki' -Icon 'E916' -Service 'Exchange' `
    -Description 'Skrzynki bez aktywności użytkownika od wskazanej liczby dni (kandydaci do konwersji lub usunięcia licencji). Sprawdzane są skrzynki z listy.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Brak aktywności od (dni):' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value (Get-HTInactiveDaysDefault) -Minimum 1 -Maximum 3650
    Add-HTButton -Parent $row -Module $m -Text 'Generuj raport' -Icon 'E9D2' -Primary -OnClick {
        param($m)
        $days = Get-HTNum $m.C.Days
        $all = @(Get-HTPanelObjects -Key 'mailboxes' | Where-Object { $_.RecipientTypeDetails -in 'UserMailbox', 'SharedMailbox' })
        if ($all.Count -eq 0) { return }
        Invoke-HTQuery -Module $m -Name 'Nieaktywne skrzynki' -ScriptBlock {
            $i = 0
            foreach ($x in $all) {
                $i++
                if ($i % 5 -eq 0 -or $i -eq $all.Count) { Set-HTProgress -Value $i -Maximum $all.Count -Text "Statystyki skrzynek [$i/$($all.Count)]" }
                try {
                    $u = Get-HTMailboxUsage -Identity $x.PrimarySmtpAddress
                    $idle = $u.'Dni bez aktywności'
                    if ($null -eq $idle -or $idle -ge $days) { $u.__flag = 'warn'; $u }
                }
                catch { [PSCustomObject]@{ Skrzynka = $x.DisplayName; Adres = $x.PrimarySmtpAddress; Status = 'Błąd'; Szczegóły = $_.Exception.Message } }
            }
        }
    } | Out-Null
}
#endregion

#region Pełny raport dostępu i automapowanie
Register-HTModule -Workspace 'Exchange' -Category 'Uprawnienia' -Key 'exo.accessreport' -Title 'Kto ma dostęp do skrzynki' -Icon 'E8D7' `
    -Description 'Pełny raport: pełny dostęp, wyślij jako, wyślij w imieniu oraz uprawnienia do folderów (skrzynka odbiorcza, kalendarz, kontakty albo wszystkie foldery). Prawy przycisk - odebranie uprawnienia, wyłączenie automapowania.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Foldery:' | Out-Null
    $m.C.Folders = Add-HTComboBox -Parent $row -Width 260 -Items @('Standardowe (odebrane, kalendarz, kontakty)', 'Wszystkie foldery (dłużej)', 'Bez folderów')
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż dostęp' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        $folders = switch ($m.C.Folders.SelectedIndex) { 1 { 'All' } 2 { 'None' } default { 'Standard' } }
        Invoke-HTTargetQuery -Module $m -Name 'Dostęp do skrzynek' -AlwaysShowObject -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTMailboxAccessReport -Identity $t.PrimarySmtpAddress -Folders $folders }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Odbierz uprawnienie' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Odebranie uprawnień' -Rows @($rows | Where-Object { $_.__type }) -Danger -Confirm 'Odebrać zaznaczone uprawnienia?' `
            -Label { param($r) "$($r.__target.PrimarySmtpAddress): $($r.Rodzaj) $($r.Folder) - $($r.Użytkownik)" } -Action {
            param($r)
            if ($r.__type -eq 'Folder') { Remove-HTMailboxFolderPermissionEntry -FolderIdentity $r.__folder -User $r.Użytkownik; return 'Odebrano uprawnienie do folderu' }
            Remove-HTMailboxPermission -Identity $r.__target.PrimarySmtpAddress -User $r.Użytkownik -Type $r.__type
            Register-HTUndo -Operation 'Odebranie uprawnienia do skrzynki' -Object "$($r.__target.PrimarySmtpAddress) - $($r.Użytkownik)" -Kind 'MailboxPermission' -Data @{ Identity = $r.__target.PrimarySmtpAddress; User = $r.Użytkownik; Type = $r.__type }
            'Odebrano'
        } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Wyłącz automapowanie (Outlook)' -Icon 'E8F0' -Danger -Action {
        param($m, $rows)
        $full = @($rows | Where-Object { $_.__type -eq 'FullAccess' })
        if (-not $full.Count) { Show-HTWarning 'Zaznacz wiersze «Pełny dostęp».'; return }
        Invoke-HTRowAction -Module $m -Name 'Wyłączenie automapowania' -Rows $full -Confirm 'Wyłączyć automatyczne dodawanie skrzynki w Outlooku? Pełny dostęp zostanie odebrany i nadany ponownie bez automapowania (Outlook usunie skrzynkę z listy po kilku godzinach - można ją dodać ręcznie).' `
            -Label { param($r) "$($r.__target.PrimarySmtpAddress) - $($r.Użytkownik)" } -Action { param($r) Set-HTMailboxAutoMapping -Identity $r.__target.PrimarySmtpAddress -User $r.Użytkownik -Enabled $false; 'Pełny dostęp bez automapowania' }
    }
    Add-HTRowAction -Module $m -Text 'Włącz automapowanie' -Icon 'E8F0' -Danger -Action {
        param($m, $rows)
        $full = @($rows | Where-Object { $_.__type -eq 'FullAccess' })
        if (-not $full.Count) { Show-HTWarning 'Zaznacz wiersze «Pełny dostęp».'; return }
        Invoke-HTRowAction -Module $m -Name 'Włączenie automapowania' -Summary 'Pełny dostęp zostanie nadany ponownie z automapowaniem (skrzynka pojawi się w Outlooku)' -Rows $full -Label { param($r) "$($r.__target.PrimarySmtpAddress) - $($r.Użytkownik)" } -Action { param($r) Set-HTMailboxAutoMapping -Identity $r.__target.PrimarySmtpAddress -User $r.Użytkownik -Enabled $true; 'Pełny dostęp z automapowaniem' }
    }
}
#endregion

#region Sale i zasoby
Register-HTModule -Workspace 'Exchange' -Category 'Sale i zasoby' -Key 'exo.booking' -Title 'Ustawienia rezerwacji' -Icon 'E787' `
    -Description 'Sale konferencyjne i zasoby (np. auta, projektory): automatyczne przyjmowanie, konflikty, okno rezerwacji, maks. czas, kto może rezerwować, delegaci, prywatność tematów. Zaznacz sale na liście (szukaj: room).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż ustawienia' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Ustawienia rezerwacji' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTRoomBookingSettings -Identity $t.PrimarySmtpAddress -RecipientTypeDetails "$($t.RecipientTypeDetails)" }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Zmień ustawienia…' -Icon 'E70F' -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $current = if ($targets.Count -eq 1) { (Get-HTRoomBookingSettings -Identity $targets[0].PrimarySmtpAddress -RecipientTypeDetails "$($targets[0].RecipientTypeDetails)").__settings } else { $null }
        $keep = '(bez zmian)'
        $boolField = { param($name, $label) @{ Name = $name; Label = $label; Type = 'Combo'; Options = @($keep, 'Tak', 'Nie'); Default = $(if ($current) { if ($current.$name) { 'Tak' } else { 'Nie' } } else { $keep }) } }
        $form = Show-HTFormDialog -Title 'Ustawienia rezerwacji' -Description $(if ($targets.Count -eq 1) { Get-HTMailboxLabel $targets[0] } else { "Sal i zasobów: $($targets.Count) - zmienione zostaną tylko ustawione pola" }) -Icon 'E787' -Width 620 -Fields @(
            @{ Name = 'AutomateProcessing'; Label = 'Przetwarzanie zaproszeń'; Type = 'Combo'; Options = @($keep, 'AutoAccept', 'AutoUpdate', 'None'); Default = $(if ($current) { "$($current.AutomateProcessing)" } else { $keep }) }
            (& $boolField 'AllowConflicts' 'Zezwalaj na konflikty')
            @{ Name = 'BookingWindowInDays'; Label = 'Okno rezerwacji (dni, puste - bez zmian)'; Default = $(if ($current) { "$($current.BookingWindowInDays)" } else { '' }) }
            @{ Name = 'MaximumDurationInMinutes'; Label = 'Maks. czas spotkania (minuty, puste - bez zmian)'; Default = $(if ($current) { "$($current.MaximumDurationInMinutes)" } else { '' }) }
            (& $boolField 'AllowRecurringMeetings' 'Spotkania cykliczne')
            (& $boolField 'ScheduleOnlyDuringWorkHours' 'Tylko w godzinach pracy')
            (& $boolField 'AllBookInPolicy' 'Wszyscy mogą rezerwować')
            @{ Name = 'BookInPolicy'; Label = 'Tylko wybrani mogą rezerwować (adresy, jeden w linii; «-» czyści)'; Type = 'Multiline'; Height = 50; Default = $(if ($current) { @($current.BookInPolicy | ForEach-Object { "$_" }) -join "`r`n" } else { '' }) }
            @{ Name = 'ResourceDelegates'; Label = 'Delegaci zatwierdzający (adresy, jeden w linii; «-» czyści)'; Type = 'Multiline'; Height = 50; Default = $(if ($current) { @($current.ResourceDelegates | ForEach-Object { "$_" }) -join "`r`n" } else { '' }) }
            (& $boolField 'AddOrganizerToSubject' 'Organizator w temacie')
            (& $boolField 'DeleteSubject' 'Usuwaj temat spotkania')
            (& $boolField 'DeleteComments' 'Usuwaj treść zaproszenia')
            (& $boolField 'RemovePrivateProperty' 'Usuwaj oznaczenie «prywatne»')
            (& $boolField 'ProcessExternalMeetingMessages' 'Przyjmuj zaproszenia spoza organizacji')
        )
        if (-not $form) { return }
        $settings = @{}
        foreach ($k in $form.Keys) {
            $v = $form[$k]
            if ($v -eq $keep) { continue }
            switch -Regex ($k) {
                '^(BookingWindowInDays|MaximumDurationInMinutes)$' { $n = 0; if ("$v".Trim() -and [int]::TryParse("$v".Trim(), [ref]$n)) { if ($current -and [int]$current.$k -eq $n) { continue }; $settings[$k] = $n } }
                '^(BookInPolicy|ResourceDelegates)$' {
                    $text = "$v".Trim()
                    if ($text -eq '-') { $settings[$k] = $null }
                    elseif ($text) { $list = @(Split-HTInputList $text); if ($current -and (@($current.$k | ForEach-Object { "$_" }) -join ',') -eq ($list -join ',')) { continue }; $settings[$k] = $list }
                }
                '^AutomateProcessing$' { if (-not $current -or "$($current.AutomateProcessing)" -ne $v) { $settings[$k] = $v } }
                default { $b = ($v -eq 'Tak'); if (-not $current -or [bool]$current.$k -ne $b) { $settings[$k] = $b } }
            }
        }
        if ($settings.Count -eq 0) { Show-HTToast 'Brak zmian.' 'info'; return }
        Invoke-HTTargetAction -Module $m -Name 'Ustawienia rezerwacji' -Summary @(ConvertTo-HTChangeSummary -Settings $settings) -Targets $targets -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            Set-HTRoomBookingSettings -Identity $t.PrimarySmtpAddress -Settings $settings
            "Zmieniono: $(@($settings.Keys) -join ', ')"
        }
    } | Out-Null
}
#endregion

#region Przepływ poczty: reguły transportu, lista dozwolonych i zablokowanych
Register-HTModule -Workspace 'Organization' -Category 'Poczta (Exchange)' -Key 'exo.transport' -Title 'Reguły transportu' -Icon 'E71C' -Service 'Exchange' `
    -Description 'Reguły przepływu poczty organizacji: kolejność, stan, tryb (wymuszanie / test) i opis warunków i akcji. Prawy przycisk - włączenie lub wyłączenie reguły.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz reguły' -Icon 'E72C' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Reguły transportu' -ScriptBlock { Get-HTTransportRules } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Centrum administracyjne Exchange' -Icon 'E8A7' -OnClick { param($m) Start-Process 'https://admin.exchange.microsoft.com/#/transportrules' } | Out-Null
    Add-HTRowAction -Module $m -Text 'Włącz regułę' -Icon 'E73E' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Włączenie reguły transportu' -Rows $rows -Confirm 'Włączyć zaznaczone reguły?' -Label { param($r) $r.Reguła } -Action { param($r) Set-HTTransportRuleState -Identity $r.Id -Enabled $true; 'Włączono' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Wyłącz regułę' -Icon 'E711' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Wyłączenie reguły transportu' -Rows $rows -Danger -Confirm 'Wyłączyć zaznaczone reguły? Reguły (np. zastrzeżenia, podpisy, blokady) przestaną działać dla całej organizacji.' -Label { param($r) $r.Reguła } -Action {
            param($r)
            Set-HTTransportRuleState -Identity $r.Id -Enabled $false
            Register-HTUndo -Operation 'Wyłączenie reguły transportu' -Object $r.Reguła -Kind 'TransportRule' -Data @{ Identity = $r.Id }
            'Wyłączono'
        } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'Organization' -Category 'Poczta (Exchange)' -Key 'exo.tabl' -Title 'Dozwoleni i zablokowani' -Icon 'E8F8' -Service 'Exchange' `
    -Description 'Lista dozwolonych i zablokowanych (Tenant Allow/Block List): nadawcy i domeny, adresy URL, pliki. Szybkie zablokowanie spamera lub domeny phishingowej. Żółte - wpisy zezwalające.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz listę' -Icon 'E72C' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Dozwoleni i zablokowani' -ScriptBlock { Get-HTTenantAllowBlockList } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Dodaj wpisy…' -Create -NoRowMenu -Icon 'E710' -OnClick {
        param($m)
        $form = Show-HTFormDialog -Title 'Lista dozwolonych i zablokowanych' -Icon 'E8F8' -OkText 'Dodaj' -Fields @(
            @{ Name = 'Type'; Label = 'Rodzaj'; Type = 'Combo'; Options = @('Nadawca / domena', 'Adres URL', 'Plik (SHA256)') }
            @{ Name = 'Action'; Label = 'Akcja'; Type = 'Combo'; Options = @('Blokuj', 'Zezwalaj') }
            @{ Name = 'Entries'; Label = 'Wartości (jedna w linii, np. spam@domena.com, domena.com, *.domena.com/*)'; Type = 'Multiline'; Required = $true; Height = 80 }
            @{ Name = 'Days'; Label = 'Ważność (dni, 0 - bez wygaśnięcia; zezwolenia: maks. 30 lub 45 od ostatniego użycia)'; Type = 'Number'; Default = 30; Min = 0; Max = 365 }
            @{ Name = 'Notes'; Label = 'Notatka (np. numer zgłoszenia)' }
        )
        if (-not $form) { return }
        $type = switch ($form.Type) { 'Adres URL' { 'Url' } 'Plik (SHA256)' { 'FileHash' } default { 'Sender' } }
        $action = if ($form.Action -eq 'Zezwalaj') { 'Allow' } else { 'Block' }
        $entries = @(Split-HTInputList $form.Entries)
        if (-not (Assert-HTWriteAllowed -Operation 'Lista dozwolonych i zablokowanych')) { return }
        try {
            Add-HTTenantAllowBlockItem -ListType $type -Entries $entries -Action $action -Days ([int]$form.Days) -Notes $form.Notes
            Add-HTOperationRecord -Operation "Lista $(if ($action -eq 'Block') { 'zablokowanych' } else { 'dozwolonych' }): $($form.Type)" -Object ($entries -join ', ') -Details $form.Notes -Module $m.Title
            Write-Log -Message "Dodano do listy ($type, $action): $($entries -join ', ')" -Type 'Info&Notification'
            Invoke-HTModulePrimary $m
        }
        catch { Show-HTError 'Nie dodano wpisów.' $_ }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń wpis' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie wpisu z listy' -Rows $rows -Danger -Confirm 'Usunąć zaznaczone wpisy z listy dozwolonych i zablokowanych?' -Label { param($r) "$($r.Akcja): $($r.Wartość)" } -Action { param($r) Remove-HTTenantAllowBlockItem -ListType $r.__type -Ids @($r.Id); 'Usunięto' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Raporty: skrzynki współdzielone i licencje
Register-HTModule -Workspace 'Organization' -Category 'Raporty' -Key 'exo.rep.shared' -Title 'Współdzielone a licencje' -Icon 'E8EC' -Service 'Exchange' `
    -Description 'Skrzynki współdzielone z niepotrzebną licencją (do 50 GB, bez archiwum i blokady) i bez wymaganej licencji (ponad 50 GB, archiwum, Litigation Hold). Licencje - po połączeniu z Microsoft 365.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Generuj raport' -Icon 'E9D2' -Primary -OnClick {
        param($m)
        if (-not $Global:ConnectedToGraphAPI) { Show-HTToast 'Bez połączenia z Microsoft 365 raport nie pokaże licencji.' 'warn' 6 }
        Invoke-HTQuery -Module $m -Name 'Skrzynki współdzielone a licencje' -ScriptBlock {
            Get-HTSharedMailboxLicenseReport -OnProgress { param($i, $total, $name) if ($i % 5 -eq 0 -or $i -eq $total) { Set-HTProgress -Value $i -Maximum $total -Text "Skrzynki współdzielone [$i/$total] $name" } } |
                Sort-Object @{ Expression = { switch ($_.__flag) { 'crit' { 0 } 'warn' { 1 } default { 2 } } } }, Skrzynka
        }
    } | Out-Null
}
#endregion

#region Edytor ustawień (wspólny dla skrzynek i grup)
function Show-HTSettingsEditor {
    <#
        Okno z sekcjami do zmiany ustawień: bieżące wartości (-Current, jedna pozycja) albo «bez zmian» (wiele pozycji).
        Błędne wpisy - komunikat i ponowne otwarcie z wpisanymi wartościami; na końcu potwierdzenie listy zmian.
        Zwraca zmiany (Get-HTMailboxSettingChanges) albo $null.
    #>
    param(
        [Parameter(Mandatory)][string]$Title,
        [string]$Description = '',
        [Parameter(Mandatory)][object[]]$Definitions,
        [System.Collections.IDictionary]$Current = $null,
        [hashtable]$Options = @{},
        [string[]]$Objects = @(),
        [string]$Icon = 'E713'
    )
    $values = $null
    while ($true) {
        $fields = @(New-HTMailboxSettingsFormFields -Current $Current -Options $Options -Values $values -Definitions $Definitions)
        $form = Show-HTFormDialog -Title $Title -Description $Description -Fields $fields -Icon $Icon -Width 960 -MaxHeight 520 -Sections -OkText 'Dalej'
        if (-not $form) { return $null }
        $values = $form
        $r = Get-HTMailboxSettingChanges -Form $form -Current $Current -Definitions $Definitions
        if (@($r.Errors).Count) { Show-HTWarning -Title $Title -Text ("Popraw wartości:`n`n" + (@($r.Errors) -join "`n")); continue }
        if (@($r.Changes).Count -eq 0) { Show-HTToast 'Brak zmian.' 'info'; return $null }
        $items = @($r.Changes | ForEach-Object { "$($_.Label): $($_.Display)" })
        # Potwierdzenie z listą zmian i obiektów (wywołujący wykonuje zmiany z -NoConfirm)
        if (Confirm-HTChange -Name $Title -Labels $Objects -Summary $items -Confirm "Zapisać zmiany ($($items.Count))? «Anuluj» wraca do formularza.") { return @($r.Changes) }
    }
}

function Get-HTMailboxSettingOptions {
    # Listy wartości formularza (strefy czasowe, zasady przechowywania) - pobierane raz na moduł
    param([Parameter(Mandatory)][hashtable]$Module)
    if (-not $Module.Data.SettingOptions) {
        $retention = @()
        try { $retention = @(Get-HTRetentionPolicyNames) } catch { Write-Log -Message "Zasady przechowywania: $($_.Exception.Message)" -Type 'Warn' }
        $Module.Data.SettingOptions = @{ TimeZones = @(Get-HTTimeZoneOptions); RetentionPolicies = $retention }
    }
    return $Module.Data.SettingOptions
}

function Get-HTMailboxSectionKeys {
    # Sekcje ustawień skrzynek (bez sekcji grup)
    $sections = Get-HTMailboxSettingSections
    return @($sections.Keys | Where-Object { @(Get-HTMailboxSettingDefinitions -Sections $_).Count -gt 0 })
}

function Get-HTExchangeDomainOptions {
    param([Parameter(Mandatory)][hashtable]$Module)
    if (-not $Module.Data.Domains) { $Module.Data.Domains = @(Get-HTAcceptedDomainNames) }
    return @($Module.Data.Domains)
}
#endregion

#region Ustawienia skrzynki (atrybuty), wzorzec i CSV
Register-HTModule -Workspace 'Exchange' -Category 'Skrzynka' -Key 'exo.settings' -Title 'Ustawienia skrzynki' -Icon 'E713' `
    -Description 'Kilkadziesiąt ustawień w sekcjach: nazwa i atrybuty niestandardowe, limity rozmiaru, dostarczanie, protokoły (OWA, Outlook mobile, IMAP, POP, SMTP AUTH), język i strefa czasowa, godziny pracy, Focused Inbox, wiadomości-śmieci, retencja i inspekcja. Wiele skrzynek naraz - zmieniane są tylko wypełnione pola. Kopiowanie ustawień ze skrzynki wzorcowej.' -Build {
    param($m)
    $sections = Get-HTMailboxSettingSections
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Edytuj ustawienia…' -Icon 'E70F' -Primary -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        if (-not (Assert-HTConnection -Service 'Exchange')) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Ustawienia skrzynki')) { return }
        $current = $null
        Set-HTBusy -Busy $true -Text 'Odczyt ustawień skrzynki…'
        try {
            $options = Get-HTMailboxSettingOptions -Module $m
            if ($targets.Count -eq 1) { $current = Get-HTMailboxSettings -Identity $targets[0].PrimarySmtpAddress }
        }
        catch { Set-HTBusy -Busy $false -Text 'Błąd'; Show-HTError 'Nie odczytano ustawień skrzynki.' $_; return }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        $desc = "Skrzynek: $($targets.Count) - zmienione zostaną tylko wypełnione pola («(bez zmian)» i puste pola pozostają)."
        if ($current) {
            $desc = "$(Get-HTMailboxLabel $targets[0]) • $($current['__Type'])"
            if ($current['__DirSynced']) { $desc += ' • synchronizowana z AD: nazwę, alias i biuro zmienia się w AD' }
            $errs = @($current['__Errors'] | Where-Object { $_ })
            if ($errs.Count) { $desc += " • nie odczytano: $(@($errs | ForEach-Object { ($_ -split ':')[0] }) -join ', ') (te pola - bez zmian)" }
        }
        $changes = Show-HTSettingsEditor -Title 'Ustawienia skrzynki' -Description $desc -Definitions @(Get-HTMailboxSettingDefinitions) -Current $current -Options $options -Objects @($targets | ForEach-Object { Get-HTMailboxLabel $_ }) -Icon 'E715'
        if (-not $changes) { return }
        $plan = ConvertTo-HTMailboxSettingPlan -Changes @($changes)
        Invoke-HTTargetAction -Module $m -Name 'Ustawienia skrzynki' -Targets $targets -NoConfirm -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Invoke-HTMailboxSettingPlan -Identity $t.PrimarySmtpAddress -Plan $plan }
    } | Out-Null
    Add-HTLabel -Parent $row -Text 'Sekcja:' | Out-Null
    $m.C.Section = Add-HTComboBox -Parent $row -Width 210 -Items (@('Wszystkie sekcje') + @(Get-HTMailboxSectionKeys | ForEach-Object { $sections[$_].Title }))
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż ustawienia' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $title = Get-HTComboText $m.C.Section
        $all = Get-HTMailboxSettingSections
        $chosen = @(Get-HTMailboxSectionKeys | Where-Object { $all[$_].Title -eq $title })
        if ($chosen.Count -eq 0) { $chosen = @(Get-HTMailboxSectionKeys) }
        Invoke-HTQuery -Module $m -Name 'Ustawienia skrzynek' -ScriptBlock {
            if ($targets.Count -eq 1) {
                $s = Get-HTMailboxSettings -Identity $targets[0].PrimarySmtpAddress -Sections $chosen
                foreach ($d in @(Get-HTMailboxSettingDefinitions -Sections $chosen)) {
                    if ($d.Type -eq 'Flag' -or -not $s.Contains($d.Key)) { continue }
                    [PSCustomObject]@{ Sekcja = $all[$d.Section].Title; Ustawienie = $d.Label; Wartość = (ConvertTo-HTMailboxSettingDisplay -Definition $d -Value $s[$d.Key]); Parametr = $d.Param }
                }
                foreach ($e in @($s['__Errors'] | Where-Object { $_ })) { [PSCustomObject]@{ Sekcja = 'Błąd odczytu'; Ustawienie = $e; Wartość = ''; Parametr = ''; __flag = 'warn' } }
                return
            }
            $i = 0
            foreach ($t in $targets) {
                $i++
                Set-HTProgress -Value $i -Maximum $targets.Count -Text "Ustawienia skrzynek [$i/$($targets.Count)] $($t.PrimarySmtpAddress)"
                try { ConvertTo-HTMailboxSettingsRow -Identity $t.PrimarySmtpAddress -Settings (Get-HTMailboxSettings -Identity $t.PrimarySmtpAddress -Sections $chosen) -Sections $chosen }
                catch { [PSCustomObject]@{ Skrzynka = $t.PrimarySmtpAddress; 'Błędy odczytu' = $_.Exception.Message; __flag = 'crit' } }
            }
        }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Wzorzec'
    Add-HTButton -Parent $row2 -Module $m -Text 'Kopiuj ze skrzynki wzorcowej…' -Icon 'E8C8' -Danger -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $all = Get-HTMailboxSettingSections
        $keys = @(Get-HTMailboxSectionKeys)
        $fields = @(
            @{ Name = 'Source'; Label = 'Skrzynka wzorcowa (adres e-mail)'; Required = $true; Validation = 'Email' }
            @{ Type = 'Info'; Label = 'Kopiowane są ustawienia zaznaczonych sekcji, które różnią się od wzorca (bez nazwy i aliasu). Puste wartości wzorca czyszczą wartości skrzynek docelowych.' }
            @{ Type = 'Header'; Label = 'Sekcje' }
        )
        foreach ($k in $keys) { $fields += @{ Name = "S_$k"; Label = $all[$k].Title; Type = 'Check'; Default = ($k -notin 'General', 'Custom') } }
        $form = Show-HTFormDialog -Title 'Kopiuj ustawienia ze skrzynki wzorcowej' -Description "Skrzynki docelowe: $($targets.Count)" -Icon 'E8C8' -OkText 'Dalej' -Fields $fields
        if (-not $form) { return }
        $chosen = @($keys | Where-Object { $form["S_$_"] })
        if ($chosen.Count -eq 0) { Show-HTWarning 'Zaznacz co najmniej jedną sekcję.'; return }
        $source = [string]$form.Source
        if (-not (Assert-HTConnection -Service 'Exchange')) { return }
        Set-HTBusy -Busy $true -Text "Odczyt ustawień wzorca $source…"
        try { $src = Get-HTMailboxSettings -Identity $source -Sections $chosen }
        catch { Set-HTBusy -Busy $false -Text 'Błąd'; Show-HTError "Nie odczytano ustawień skrzynki $source." $_; return }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        $copy = Get-HTMailboxSettingCopyForm -Source $src -Sections $chosen
        $list = @($targets | Where-Object { [string]$_.PrimarySmtpAddress -ine $source })
        if ($list.Count -eq 0) { Show-HTWarning 'Zaznacz skrzynki docelowe inne niż wzorzec.'; return }
        Invoke-HTTargetAction -Module $m -Name 'Kopiowanie ustawień' -Targets $list -Label { param($t) Get-HTMailboxLabel $t } `
            -Confirm "Skopiować ustawienia skrzynki $source (sekcje: $(@($chosen | ForEach-Object { $all[$_].Title }) -join ', ')) do wybranych skrzynek? Zmienione zostaną tylko ustawienia, które różnią się od wzorca." -Action {
            param($t)
            $cur = Get-HTMailboxSettings -Identity $t.PrimarySmtpAddress -Sections $chosen
            $r = Get-HTMailboxSettingChanges -Form $copy -Current $cur
            if (@($r.Errors).Count) { throw (@($r.Errors) -join '; ') }
            if (@($r.Changes).Count -eq 0) { return 'Bez zmian - ustawienia jak we wzorcu' }
            $result = Invoke-HTMailboxSettingPlan -Identity $t.PrimarySmtpAddress -Plan (ConvertTo-HTMailboxSettingPlan -Changes @($r.Changes))
            "$result [$(@($r.Changes | ForEach-Object { $_.Label }) -join ', ')]"
        }
    } | Out-Null
    Add-HTLabel -Parent $row2 -Hint -Text 'Np. nowa skrzynka działu jak istniejąca: język, strefa, limity, protokoły, kopie wysłanych, godziny pracy.' | Out-Null
}

Register-HTModule -Workspace 'Exchange' -Category 'Skrzynka' -Key 'exo.settings.csv' -Title 'Masowa zmiana ustawień (CSV)' -Icon 'E8F4' `
    -Description 'Ustawienia wielu skrzynek z pliku CSV: kolumna «Skrzynka» i kolumny ustawień (np. Office, CustomAttribute1, ProhibitSendQuota, Language, ImapEnabled). Puste pole - bez zmian. Najpierw sprawdzenie pliku (podgląd zmian i błędów), potem zapis poprawnych wierszy.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Zapisz szablon CSV' -Icon 'E74E' -OnClick {
        param($m)
        $path = Select-HTSaveFile -Title 'Szablon CSV ustawień skrzynek' -Filter 'CSV (*.csv)|*.csv' -FileName 'Ustawienia_skrzynek.csv' -DefaultExt '.csv'
        if (-not $path) { return }
        [System.IO.File]::WriteAllText($path, (Get-HTMailboxSettingsCsvTemplate), (New-Object System.Text.UTF8Encoding($true)))
        Show-HTToast 'Zapisano szablon - usuń niepotrzebne kolumny; opis wartości: «Opis kolumn».' 'ok' 8
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Opis kolumn' -Icon 'E946' -OnClick { param($m) Show-HTDataViewer -Title 'Kolumny pliku CSV - ustawienia skrzynek' -Data @(Get-HTMailboxSettingsCsvColumnHelp) -ExportName 'kolumny_ustawien_skrzynek' -Icon 'E946' } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Wczytaj i sprawdź plik…' -Icon 'E8E5' -Primary -OnClick {
        param($m)
        $path = Select-HTOpenFile -Title 'Plik CSV z ustawieniami skrzynek' -Filter 'CSV (*.csv)|*.csv'
        if (-not $path) { return }
        $m.Data.Csv = New-Object System.Collections.Generic.List[object]
        $m.Data.CsvUnknown = @()
        Invoke-HTQuery -Module $m -Name 'Sprawdzenie pliku CSV' -Service '' -ScriptBlock {
            $rows = @(Import-HTCsvFile -Path $path)
            if ($rows.Count) { $m.Data.CsvUnknown = @(Get-HTMailboxSettingsCsvUnknownColumns -Columns @($rows[0].PSObject.Properties.Name)) }
            $n = 0
            foreach ($r in $rows) {
                $n++
                $p = ConvertFrom-HTMailboxSettingsCsvRow -Row $r
                $m.Data.Csv.Add($p)
                [PSCustomObject]@{
                    Lp        = $n
                    Skrzynka  = $p.Identity
                    Zmiany    = @($p.Changes).Count
                    Status    = $(if ($p.Valid) { 'Do zmiany' } else { 'Błąd' })
                    Szczegóły = $(if ($p.Valid) { @($p.Changes | ForEach-Object { "$($_.Label): $($_.Display)" }) -join '; ' } else { @($p.Errors) -join '; ' })
                    __flag    = $(if ($p.Valid) { '' } else { 'crit' })
                }
            }
        }
        if (@($m.Data.CsvUnknown).Count) { Show-HTWarning -Title 'Nieznane kolumny' -Text "Kolumny pominięte (literówka?): $(@($m.Data.CsvUnknown) -join ', '). Nazwy kolumn - przycisk «Opis kolumn»." }
        $bad = @($m.Data.Csv | Where-Object { -not $_.Valid }).Count
        if ($m.Data.Csv.Count) { Show-HTToast "Wierszy: $($m.Data.Csv.Count), z błędami: $bad." $(if ($bad) { 'warn' } else { 'ok' }) 6 }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Zapisz poprawne wiersze' -Icon 'E74E' -Danger -OnClick {
        param($m)
        $valid = @($m.Data.Csv | Where-Object { $_.Valid })
        if ($valid.Count -eq 0) { Show-HTWarning 'Najpierw wczytaj i sprawdź plik CSV (brak poprawnych wierszy).'; return }
        Invoke-HTTargetAction -Module $m -Name 'Ustawienia z pliku CSV' -Targets $valid -Label { param($t) $t.Identity } -Confirm "Zapisać zmiany ustawień dla $($valid.Count) skrzynek z pliku?" -Action {
            param($t)
            Invoke-HTMailboxSettingPlan -Identity $t.Identity -Plan (ConvertTo-HTMailboxSettingPlan -Changes @($t.Changes))
        }
        $m.Data.Csv = $null
    } | Out-Null
}
#endregion

#region Nowe skrzynki współdzielone, sale i zasoby
Register-HTModule -Workspace 'Organization' -Category 'Tworzenie' -Key 'exo.newmailbox' -Title 'Nowa skrzynka współdzielona / sala' -Icon 'E710' -Service 'Exchange' `
    -Description 'Tworzenie skrzynek współdzielonych, sal konferencyjnych i zasobów - pojedynczo albo wiele naraz - z pełnym dostępem i «Wyślij jako» dla osób, kopiami wiadomości wysłanych przez delegatów, danymi sali (pojemność, budynek, piętro, miasto) i listą sal. Skrzynka współdzielona do 50 GB nie wymaga licencji.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz skrzynki…' -Create -NoRowMenu -Icon 'E710' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'Exchange')) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Nowa skrzynka')) { return }
        $roomLists = @()
        Set-HTBusy -Busy $true -Text 'Domeny i listy sal…'
        try {
            $domains = @(Get-HTExchangeDomainOptions -Module $m)
            try { $roomLists = @(Get-HTRoomLists | ForEach-Object { $_.Adres }) } catch { $roomLists = @() }
        }
        catch { Set-HTBusy -Busy $false -Text 'Błąd'; Show-HTError 'Nie odczytano domen akceptowanych.' $_; return }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        $types = [ordered]@{ 'Skrzynka współdzielona' = 'Shared'; 'Sala konferencyjna' = 'Room'; 'Zasób (sprzęt, samochód)' = 'Equipment' }
        $prev = @{}
        $get = { param($k, $d) if ($prev.Contains($k)) { $prev[$k] } else { $d } }
        while ($true) {
            $form = Show-HTFormDialog -Title 'Nowe skrzynki' -Icon 'E710' -OkText 'Dalej' -Width 660 -MaxHeight 600 -Fields @(
                @{ Name = 'Type'; Label = 'Rodzaj'; Type = 'Combo'; Options = @($types.Keys); Default = (& $get 'Type' 'Skrzynka współdzielona') }
                @{ Name = 'Domain'; Label = 'Domena adresów (gdy adres nie jest podany)'; Type = 'Combo'; Options = $domains; Default = (& $get 'Domain' $domains[0]) }
                @{ Name = 'Lines'; Label = 'Skrzynki - jedna w linii: Nazwa wyświetlana; adres e-mail (adres opcjonalny)'; Type = 'Multiline'; Height = 90; Required = $true; Default = (& $get 'Lines' ''); Hint = 'Np. «Biuro Zarządu» albo «Faktury; faktury@firma.pl». Adres z nazwy - bez polskich znaków, spacje zamieniane na kropki.' }
                @{ Type = 'Header'; Label = 'Dostęp' }
                @{ Name = 'FullAccess'; Label = 'Pełny dostęp (adresy osób, jeden w linii)'; Type = 'Multiline'; Height = 60; Default = (& $get 'FullAccess' '') }
                @{ Name = 'SendAsSame'; Label = '«Wyślij jako» dla tych samych osób'; Type = 'Check'; Default = (& $get 'SendAsSame' $true) }
                @{ Name = 'AutoMap'; Label = 'Automatyczne dodanie skrzynki w Outlooku (AutoMapping)'; Type = 'Check'; Default = (& $get 'AutoMap' $true) }
                @{ Name = 'CopySent'; Label = 'Kopia wiadomości wysłanych przez delegatów w «Elementach wysłanych» skrzynki (współdzielone)'; Type = 'Check'; Default = (& $get 'CopySent' $true) }
                @{ Name = 'Hidden'; Label = 'Ukryj w książce adresowej (GAL)'; Type = 'Check'; Default = (& $get 'Hidden' $false) }
                @{ Type = 'Header'; Label = 'Sala lub zasób' }
                @{ Name = 'Capacity'; Label = 'Pojemność sali (osób, 0 - nie ustawiaj)'; Type = 'Number'; Min = 0; Max = 10000; Default = (& $get 'Capacity' 0) }
                @{ Name = 'Building'; Label = 'Budynek'; Default = (& $get 'Building' '') }
                @{ Name = 'Floor'; Label = 'Piętro (liczba)'; Default = (& $get 'Floor' '') }
                @{ Name = 'City'; Label = 'Miasto'; Default = (& $get 'City' '') }
                @{ Name = 'RoomList'; Label = 'Lista sal (opcjonalnie - adres istniejącej listy)'; Type = 'Combo'; Editable = $true; Options = $roomLists; Default = (& $get 'RoomList' '') }
            )
            if (-not $form) { return }
            $prev = $form
            $entries = @(ConvertFrom-HTNewMailboxLines -Text $form.Lines -Domain $form.Domain -Domains $domains)
            $problems = @($entries | Where-Object { -not $_.Valid } | ForEach-Object { "$($_.DisplayName): $(@($_.Errors) -join ', ')" })
            $floor = 0
            if ($form.Floor -and -not [int]::TryParse([string]$form.Floor, [ref]$floor)) { $problems += 'Piętro musi być liczbą.' }
            if ($entries.Count -eq 0) { $problems += 'Wpisz co najmniej jedną skrzynkę.' }
            if ($problems.Count -eq 0) { break }
            Show-HTWarning -Title 'Nowe skrzynki' -Text ("Popraw dane:`n`n" + ($problems -join "`n"))
        }
        $type = $types[$form.Type]
        $members = @(Split-HTInputList $form.FullAccess)
        $place = @{}
        if ($type -ne 'Shared') {
            if ($form.Building) { $place.Building = [string]$form.Building }
            if ($form.Floor) { $place.Floor = $floor }
            if ($form.City) { $place.City = [string]$form.City }
        }
        $capacity = if ($type -eq 'Room') { [int]$form.Capacity } else { 0 }
        Invoke-HTTargetAction -Module $m -Name 'Tworzenie skrzynek' -Targets $entries -Label { param($t) "$($t.DisplayName) <$($t.Address)>" } -Confirm "Utworzyć skrzynki ($($form.Type)): $($entries.Count)?" -Action {
            param($t)
            $address = New-HTResourceMailbox -Type $type -DisplayName $t.DisplayName -Address $t.Address -Alias $t.Alias -Capacity $capacity
            $notes = @(Set-HTNewMailboxSetup -Identity $address -FullAccess $members -SendAs $(if ($form.SendAsSame) { $members } else { @() }) -AutoMapping ([bool]$form.AutoMap) `
                    -CopySent ([bool]$form.CopySent -and $type -eq 'Shared') -Hidden ([bool]$form.Hidden) -Place $place -RoomList $(if ($type -ne 'Shared') { [string]$form.RoomList } else { '' }))
            $status = if (@($notes | Where-Object { $_ -match 'błąd' }).Count) { 'Utworzono z uwagami' } else { 'OK' }
            @{ Status = $status; Szczegóły = "Utworzono $address$(if ($notes.Count) { '; ' + ($notes -join '; ') })" }
        }
        Show-HTToast 'Nowe skrzynki pojawią się na liście po lewej po odświeżeniu (replikacja trwa do kilku minut).' 'info' 8
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nowa lista sal…' -Create -NoRowMenu -Icon 'E8FD' -ToolTip 'Lista sal grupuje sale (np. budynek) w wyszukiwarce sal Outlooka' -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'Exchange')) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Nowa lista sal')) { return }
        $form = Show-HTFormDialog -Title 'Nowa lista sal' -Icon 'E8FD' -OkText 'Utwórz' -Fields @(
            @{ Name = 'Name'; Label = 'Nazwa (np. Warszawa - Budynek A)'; Required = $true }
            @{ Name = 'Address'; Label = 'Adres e-mail listy'; Required = $true; Validation = 'Email' }
        )
        if (-not $form) { return }
        Invoke-HTTargetAction -Module $m -Name 'Nowa lista sal' -Targets @($form) -Label { param($t) $t.Address } -Action { param($t) "Utworzono: $(New-HTRoomList -DisplayName $t.Name -Address $t.Address)" }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Sale dodasz do istniejącej listy polem «Lista sal».' | Out-Null
}
#endregion

#region Grupy: nowa grupa dystrybucyjna, grupy dynamiczne, kontakty
function New-HTDistributionGroupInteractive {
    # Nowa grupa dystrybucyjna (formularz) - przestrzeń Exchange > Grupy dystrybucyjne
    param([Parameter(Mandatory)][hashtable]$Module)
    if (-not (Assert-HTConnection -Service 'Exchange')) { return }
    if (-not (Assert-HTWriteAllowed -Operation 'Nowa grupa dystrybucyjna')) { return }
    Set-HTBusy -Busy $true -Text 'Domeny akceptowane…'
    try { $domains = @(Get-HTExchangeDomainOptions -Module $Module) }
    catch { Set-HTBusy -Busy $false -Text 'Błąd'; Show-HTError 'Nie odczytano domen akceptowanych.' $_; return }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
    $prev = @{}
    $get = { param($k, $d) if ($prev.Contains($k)) { $prev[$k] } else { $d } }
    while ($true) {
        $form = Show-HTFormDialog -Title 'Nowa grupa dystrybucyjna' -Icon 'E902' -OkText 'Utwórz' -Width 620 -Fields @(
            @{ Name = 'Name'; Label = 'Nazwa wyświetlana'; Required = $true; Default = (& $get 'Name' '') }
            @{ Name = 'Address'; Label = 'Adres e-mail (puste - z nazwy i domeny)'; Default = (& $get 'Address' '') }
            @{ Name = 'Domain'; Label = 'Domena'; Type = 'Combo'; Options = $domains; Default = (& $get 'Domain' $domains[0]) }
            @{ Name = 'Type'; Label = 'Rodzaj'; Type = 'Combo'; Options = @('Dystrybucyjna', 'Zabezpieczeń (z pocztą)'); Default = (& $get 'Type' 'Dystrybucyjna'); Hint = 'Grupa zabezpieczeń może też nadawać uprawnienia (np. do skrzynek i witryn SharePoint).' }
            @{ Name = 'Owners'; Label = 'Właściciele (adresy, jeden w linii; puste - Ty)'; Type = 'Multiline'; Height = 50; Default = (& $get 'Owners' '') }
            @{ Name = 'Members'; Label = 'Członkowie (adresy, jeden w linii)'; Type = 'Multiline'; Height = 80; Default = (& $get 'Members' '') }
            @{ Name = 'Internal'; Label = 'Przyjmuj wiadomości tylko z organizacji'; Type = 'Check'; Default = (& $get 'Internal' $true) }
            @{ Name = 'Join'; Label = 'Dołączanie do grupy'; Type = 'Combo'; Options = @('Closed', 'Open', 'ApprovalRequired'); Default = (& $get 'Join' 'Closed'); Hint = 'Closed - dodają właściciele, Open - każdy sam, ApprovalRequired - za zgodą właściciela.' }
            @{ Name = 'Hidden'; Label = 'Ukryj w książce adresowej'; Type = 'Check'; Default = (& $get 'Hidden' $false) }
        )
        if (-not $form) { return }
        $prev = $form
        $entry = @(ConvertFrom-HTNewMailboxLines -Text "$($form.Name); $($form.Address)" -Domain $form.Domain -Domains $domains)[0]
        if ($entry -and $entry.Valid) { break }
        Show-HTWarning -Title 'Nowa grupa' -Text "Popraw dane: $(if ($entry) { @($entry.Errors) -join ', ' } else { 'brak nazwy' })"
    }
    $type = if ($form.Type -like 'Zabezpiecze*') { 'Security' } else { 'Distribution' }
    Invoke-HTTargetAction -Module $Module -Name 'Nowa grupa dystrybucyjna' -Targets @($entry) -Label { param($t) "$($t.DisplayName) <$($t.Address)>" } -Action {
        param($t)
        $address = New-HTMailDistributionGroup -DisplayName $t.DisplayName -Address $t.Address -Type $type -Owners @(Split-HTInputList $form.Owners) -Members @(Split-HTInputList $form.Members) `
            -InternalOnly ([bool]$form.Internal) -JoinRestriction $form.Join -Hidden ([bool]$form.Hidden)
        "Utworzono $address ($(if ($type -eq 'Security') { 'zabezpieczeń' } else { 'dystrybucyjna' }), członków: $(@(Split-HTInputList $form.Members).Count))"
    }
}

#region Kreator reguł grup dynamicznych
$script:FilterBuilderXaml = @'
<StackPanel>
  <Grid Margin="0,0,0,10">
    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="12"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
    <StackPanel Grid.Column="0">
      <TextBlock Text="Odbiorcy" Foreground="#8791A5" FontSize="12" Margin="0,0,0,4"/>
      <ComboBox x:Name="fbType"/>
    </StackPanel>
    <StackPanel Grid.Column="2">
      <TextBlock Text="Łączenie warunków" Foreground="#8791A5" FontSize="12" Margin="0,0,0,4"/>
      <ComboBox x:Name="fbJoin"/>
    </StackPanel>
  </Grid>
  <TextBlock Text="Warunki (atrybut, porównanie, wartość; * - dowolny ciąg znaków)" Foreground="#8791A5" FontSize="12" Margin="0,0,0,4"/>
  <StackPanel x:Name="fbRows"/>
  <StackPanel x:Name="fbAddHost" Orientation="Horizontal" Margin="0,4,0,10"/>
  <Grid Margin="0,0,0,4">
    <TextBlock Text="Filtr (OPATH) - budowany z warunków" Foreground="#8791A5" FontSize="12" VerticalAlignment="Center"/>
    <CheckBox x:Name="fbManual" Content="Edytuj ręcznie (zaawansowane)" HorizontalAlignment="Right"/>
  </Grid>
  <TextBox x:Name="fbFilter" Style="{StaticResource MultiText}" Height="78" TextWrapping="Wrap" IsReadOnly="True" FontFamily="Consolas" FontSize="12"/>
  <StackPanel x:Name="fbTestHost" Orientation="Horizontal" Margin="0,8,0,6"/>
  <TextBlock x:Name="fbInfo" Foreground="#AEB6C4" TextWrapping="Wrap" Margin="0,0,0,6"/>
  <TextBox x:Name="fbPreview" Style="{StaticResource MultiText}" Height="150" IsReadOnly="True" TextWrapping="NoWrap" Visibility="Collapsed"/>
</StackPanel>
'@

$script:FilterBuilderEvents = @{
    Changed = { param($s, $e) $w = [System.Windows.Window]::GetWindow($s); if ($w) { Update-HTFilterBuilderText -Window $w } }
    Add     = { param($s, $e) $w = [System.Windows.Window]::GetWindow($s); Add-HTFilterBuilderRow -Window $w; Update-HTFilterBuilderText -Window $w }
    Remove  = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        [void]$w.FindName('fbRows').Children.Remove($s.Tag)
        Update-HTFilterBuilderText -Window $w
    }
    Manual  = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        if (-not $w) { return }
        Set-HTFilterBuilderManual -Window $w -Manual ($s.IsChecked -eq $true)
        if ($s.IsChecked -ne $true) { Update-HTFilterBuilderText -Window $w }
    }
    Test    = { param($s, $e) $w = [System.Windows.Window]::GetWindow($s); Invoke-HTFilterBuilderTest -Window $w }
}

function Set-HTFilterBuilderManual {
    # Edycja ręczna filtra: warunki nieaktywne, pole filtra edytowalne
    param([Parameter(Mandatory)]$Window, [bool]$Manual)
    $Window.FindName('fbFilter').IsReadOnly = -not $Manual
    foreach ($n in 'fbRows', 'fbAddHost', 'fbType', 'fbJoin') { $Window.FindName($n).IsEnabled = -not $Manual }
}

function Add-HTFilterBuilderRow {
    # Wiersz warunku: atrybut (lista albo nazwa atrybutu), porównanie, wartość, usuń
    param([Parameter(Mandatory)]$Window, $Condition = $null)
    $opts = $Window.Tag.FB.Options
    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = '0,0,0,6'
    foreach ($w in @('2*', '1.5*', '2*', 'Auto')) {
        $c = New-Object System.Windows.Controls.ColumnDefinition
        $c.Width = (New-Object System.Windows.GridLengthConverter).ConvertFromString($w)
        [void]$grid.ColumnDefinitions.Add($c)
    }
    $attr = New-Object System.Windows.Controls.ComboBox
    $attr.IsEditable = $true
    foreach ($p in @($opts.Properties)) { [void]$attr.Items.Add($p) }
    $attr.Text = $(if ($Condition -and $Condition.Property) { [string]$Condition.Property } else { 'Dział' })
    $attr.Margin = '0,0,6,0'
    $attr.ToolTip = 'Atrybut z listy albo nazwa atrybutu Exchange (np. CustomAttribute7)'
    $op = New-Object System.Windows.Controls.ComboBox
    $keys = @($opts.Operators.Keys)
    foreach ($k in $keys) { [void]$op.Items.Add([string]$opts.Operators[$k]) }
    $op.SelectedIndex = [Math]::Max(0, $keys.IndexOf($(if ($Condition -and $Condition.Operator) { [string]$Condition.Operator } else { 'eq' })))
    $op.Margin = '0,0,6,0'
    $value = New-Object System.Windows.Controls.TextBox
    $value.Text = $(if ($Condition) { [string]$Condition.Value } else { '' })
    $value.Margin = '0,0,6,0'
    $remove = New-HTButton -Icon 'E711' -Ghost -ToolTip 'Usuń warunek'
    $remove.Tag = $grid
    [System.Windows.Controls.Grid]::SetColumn($op, 1)
    [System.Windows.Controls.Grid]::SetColumn($value, 2)
    [System.Windows.Controls.Grid]::SetColumn($remove, 3)
    foreach ($el in $attr, $op, $value, $remove) { [void]$grid.Children.Add($el) }
    $grid.Tag = @{ Attr = $attr; Op = $op; Value = $value; Keys = $keys }
    $attr.add_SelectionChanged($script:FilterBuilderEvents.Changed)
    $attr.AddHandler([System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent, [System.Windows.Controls.TextChangedEventHandler]$script:FilterBuilderEvents.Changed)
    $op.add_SelectionChanged($script:FilterBuilderEvents.Changed)
    $value.add_TextChanged($script:FilterBuilderEvents.Changed)
    $remove.add_Click($script:FilterBuilderEvents.Remove)
    [void]$Window.FindName('fbRows').Children.Add($grid)
}

function Get-HTFilterBuilderConditions {
    param([Parameter(Mandatory)]$Window)
    foreach ($row in @($Window.FindName('fbRows').Children)) {
        $t = $row.Tag
        $key = if ($t.Op.SelectedIndex -ge 0) { $t.Keys[$t.Op.SelectedIndex] } else { 'eq' }
        # Porównanie bez wartości (puste / niepuste) - pole wartości nieaktywne
        $t.Value.IsEnabled = $key -notin 'empty', 'notempty'
        @{ Property = ([string]$t.Attr.Text).Trim(); Operator = $key; Value = [string]$t.Value.Text }
    }
}

function Update-HTFilterBuilderText {
    # Filtr z warunków (poza edycją ręczną); wynik poprzedniego testu znika
    param([Parameter(Mandatory)]$Window)
    $info = $Window.FindName('fbInfo')
    $Window.FindName('fbPreview').Visibility = 'Collapsed'
    $info.Text = ''
    if ($Window.FindName('fbManual').IsChecked -eq $true) { return }
    $conditions = @(Get-HTFilterBuilderConditions -Window $Window)
    $join = if ($Window.FindName('fbJoin').SelectedIndex -eq 1) { 'or' } else { 'and' }
    try { $Window.FindName('fbFilter').Text = ConvertTo-HTRecipientFilter -Conditions $conditions -RecipientType ([string]$Window.FindName('fbType').SelectedItem) -Join $join }
    catch { $info.Text = "Popraw warunek: $($_.Exception.Message)" }
}

function Invoke-HTFilterBuilderTest {
    # Test filtra: liczba i lista odbiorców, którzy trafią do grupy (przed zapisem)
    param([Parameter(Mandatory)]$Window)
    $filter = ([string]$Window.FindName('fbFilter').Text).Trim()
    $info = $Window.FindName('fbInfo')
    $preview = $Window.FindName('fbPreview')
    if (-not $filter) { $info.Text = 'Filtr jest pusty - dodaj warunek.'; return }
    if (-not (Assert-HTConnection -Service 'Exchange')) { return }
    Set-HTBusy -Busy $true -Text 'Test filtra grupy dynamicznej…'
    try {
        $r = Get-HTRecipientFilterPreview -Filter $filter -Max 200
        $items = @($r.Items)
        $info.Text = if ($items.Count -eq 0) { 'Do grupy nie trafi nikt - sprawdź warunki (wielkość liter nie ma znaczenia, * - dowolny ciąg znaków).' } else { "Do grupy trafi: $($items.Count)$(if ($r.More) { '+ (pokazano pierwszych 200)' }) odbiorców." }
        $preview.Text = (@($items | ForEach-Object { "$($_.Nazwa) <$($_.Adres)> - $($_.Typ)" }) -join "`r`n")
        $preview.Visibility = $(if ($items.Count) { 'Visible' } else { 'Collapsed' })
        Add-HTOperationRecord -Kind Check -Operation 'Test filtra grupy dynamicznej' -Object $filter -Details "odbiorców: $($items.Count)$(if ($r.More) { '+' })" -Module 'Grupy dynamiczne'
    }
    catch {
        $preview.Visibility = 'Collapsed'
        $info.Text = "Błąd filtra: $($_.Exception.Message)"
    }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
}

function Show-HTDynamicFilterBuilder {
    <#
        Kreator reguły grupy dynamicznej: rodzaj odbiorców, warunki (atrybut, porównanie, wartość) łączone AND / OR,
        filtr OPATH na bieżąco, test (kto trafi do grupy) i edycja ręczna. -Filter: istniejący filtr (rozkładany na warunki,
        gdy to możliwe). Zwraca filtr albo $null.
    #>
    param([Parameter(Mandatory)][string]$Title, [string]$Filter = '', [string]$OkText = 'Zapisz', [string]$Subtitle = '')
    $opts = Get-HTDynamicFilterOptions
    if (-not $Subtitle) { $Subtitle = 'Warunki wybierasz z listy - program buduje filtr. «Testuj» pokazuje, kto trafi do grupy, zanim zapiszesz.' }
    $w = New-HTDialog -Title $Title -Subtitle $Subtitle -Body $script:FilterBuilderXaml -Icon 'E71C' -OkText $OkText -Width 860 -Validate {
        param($w)
        if (-not ([string]$w.FindName('fbFilter').Text).Trim()) { Show-HTWarning 'Filtr jest pusty - dodaj co najmniej jeden warunek.' -Title 'Grupa dynamiczna'; return $false }
        if ([string]$w.FindName('fbInfo').Text -like 'Popraw warunek*') { Show-HTWarning ([string]$w.FindName('fbInfo').Text) -Title 'Grupa dynamiczna'; return $false }
        return $true
    }
    $w.Tag.FB = @{ Options = $opts }
    $type = $w.FindName('fbType')
    foreach ($t in @($opts.Types)) { [void]$type.Items.Add($t) }
    $join = $w.FindName('fbJoin')
    foreach ($j in 'Wszystkie warunki muszą być spełnione (AND)', 'Wystarczy dowolny warunek (OR)') { [void]$join.Items.Add($j) }
    $join.SelectedIndex = 0
    $manual = $w.FindName('fbManual')
    $parsed = if ($Filter) { ConvertFrom-HTRecipientFilter $Filter } else { $null }
    if ($parsed -and $parsed.Parsed) {
        $type.SelectedItem = $parsed.RecipientType
        if ($parsed.Join -eq 'or') { $join.SelectedIndex = 1 }
        foreach ($c in @($parsed.Conditions)) { Add-HTFilterBuilderRow -Window $w -Condition $c }
    }
    else { $type.SelectedIndex = 0 }
    if ($w.FindName('fbRows').Children.Count -eq 0 -and -not ($Filter -and -not $parsed.Parsed)) { Add-HTFilterBuilderRow -Window $w }
    $add = New-HTButton -Text 'Dodaj warunek' -Icon 'E710' -Create
    $add.add_Click($script:FilterBuilderEvents.Add)
    [void]$w.FindName('fbAddHost').Children.Add($add)
    $test = New-HTButton -Text 'Testuj - kto trafi do grupy' -Icon 'E716'
    $test.add_Click($script:FilterBuilderEvents.Test)
    [void]$w.FindName('fbTestHost').Children.Add($test)
    $type.add_SelectionChanged($script:FilterBuilderEvents.Changed)
    $join.add_SelectionChanged($script:FilterBuilderEvents.Changed)
    if ($Filter -and -not $parsed.Parsed) {
        # Filtr spoza kreatora (np. zagnieżdżone warunki) - edycja ręczna; wyłączenie buduje nowy filtr z warunków
        $manual.IsChecked = $true
        $w.FindName('fbFilter').Text = $Filter
        Set-HTFilterBuilderManual -Window $w -Manual $true
        $w.FindName('fbInfo').Text = 'Tego filtra nie da się rozłożyć na warunki kreatora - edytuj go ręcznie albo wyłącz «Edytuj ręcznie», żeby zbudować nowy z warunków.'
    }
    else { Update-HTFilterBuilderText -Window $w }
    $manual.add_Checked($script:FilterBuilderEvents.Manual)
    $manual.add_Unchecked($script:FilterBuilderEvents.Manual)
    if (-not (Invoke-HTDialog $w)) { return $null }
    return ([string]$w.FindName('fbFilter').Text).Trim()
}
#endregion

function New-HTDynamicGroupInteractive {
    # Nowa grupa dynamiczna: dane grupy (krok 1) i warunki w kreatorze reguł z testem (krok 2) - wyniki w module -Module
    param([Parameter(Mandatory)][hashtable]$Module)
    if (-not (Assert-HTConnection -Service 'Exchange')) { return }
    if (-not (Assert-HTWriteAllowed -Operation 'Nowa grupa dynamiczna')) { return }
    try { $domains = @(Get-HTExchangeDomainOptions -Module $Module) } catch { Show-HTError 'Nie odczytano domen akceptowanych.' $_; return }
    $form = Show-HTFormDialog -Title 'Nowa grupa dynamiczna' -Description 'Krok 1 z 2: dane grupy. W kolejnym kroku - warunki członkostwa (kreator z testem).' -Icon 'E71C' -OkText 'Dalej' -Width 620 -Fields @(
        @{ Name = 'Name'; Label = 'Nazwa wyświetlana'; Required = $true }
        @{ Name = 'Address'; Label = 'Adres e-mail (puste - z nazwy i domeny)' }
        @{ Name = 'Domain'; Label = 'Domena'; Type = 'Combo'; Options = $domains }
        @{ Name = 'Owner'; Label = 'Właściciel (adres, opcjonalnie)' }
    )
    if (-not $form) { return }
    $entry = @(ConvertFrom-HTNewMailboxLines -Text "$($form.Name); $($form.Address)" -Domain $form.Domain -Domains $domains)[0]
    if (-not $entry -or -not $entry.Valid) { Show-HTWarning "Popraw nazwę lub adres: $(if ($entry) { @($entry.Errors) -join ', ' })"; return }
    $filter = Show-HTDynamicFilterBuilder -Title "Warunki grupy: $($form.Name)" -OkText 'Dalej' -Subtitle 'Krok 2 z 2: kto ma należeć do grupy. «Testuj» pokazuje członków, zanim utworzysz grupę.'
    if (-not $filter) { return }
    Invoke-HTTargetAction -Module $Module -Name 'Nowa grupa dynamiczna' -Targets @($entry) -Label { param($t) "$($t.DisplayName) <$($t.Address)>" } -Confirm "Utworzyć grupę dynamiczną z filtrem:`n$filter" -Action {
        param($t)
        "Utworzono $(New-HTDynamicGroup -DisplayName $t.DisplayName -Address $t.Address -Filter $filter -Owner ([string]$form.Owner)) - członkowie są wyliczani okresowo (w nowej grupie do 24 h)"
    }
}

Register-HTModule -Workspace 'Groups' -Category 'Grupy dynamiczne (Exchange)' -Key 'exo.dyn' -Title 'Grupy dynamiczne' -Icon 'E71C' -Service 'Exchange' `
    -Description 'Grupy dystrybucyjne z członkami wyliczanymi z atrybutów (np. wszyscy z działu Sprzedaż w Warszawie): lista z filtrem, podgląd członków, nowa grupa z warunków, zmiana filtra i usunięcie (prawy przycisk).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż grupy' -Icon 'E71C' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Grupy dynamiczne' -ScriptBlock { Get-HTDynamicGroups } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nowa grupa dynamiczna…' -Create -NoRowMenu -Icon 'E710' -OnClick { param($m) New-HTDynamicGroupInteractive -Module $m } | Out-Null
    Add-HTRowAction -Module $m -Text 'Podgląd członków' -Icon 'E716' -Action {
        param($m, $rows)
        $g = @($rows | Where-Object { $_.Identity })[0]
        if (-not $g) { return }
        Set-HTBusy -Busy $true -Text "Członkowie $($g.Nazwa)…"
        try { $members = @(Get-HTDynamicGroupMembers -Identity $g.Identity) }
        catch { Set-HTBusy -Busy $false -Text 'Błąd'; Show-HTError 'Nie pobrano członków grupy.' $_; return }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        Show-HTDataViewer -Title "Członkowie: $($g.Nazwa)" -Description "$($members.Count) członków • filtr: $($g.Filtr)" -Data $members -ExportName "czlonkowie_$($g.Nazwa)"
    }
    Add-HTRowAction -Module $m -Text 'Zmień filtr…' -Icon 'E70F' -Danger -Action {
        param($m, $rows)
        $g = @($rows | Where-Object { $_.Identity })[0]
        if (-not $g) { return }
        $filter = Show-HTDynamicFilterBuilder -Title "Filtr grupy: $($g.Nazwa)" -Filter $g.Filtr -OkText 'Zapisz'
        if (-not $filter -or $filter -eq $g.Filtr) { return }
        Invoke-HTRowAction -Module $m -Name 'Zmiana filtra grupy dynamicznej' -Rows @($g) -Label { param($r) $r.Nazwa } -Action { param($r) Set-HTDynamicGroupFilter -Identity $r.Identity -Filter $filter; 'Filtr zmieniony' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Usuń grupę' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie grupy dynamicznej' -Rows @($rows | Where-Object { $_.Identity }) -Danger -TypeToConfirm 'USUŃ' -Confirm 'Usunąć zaznaczone grupy dynamiczne?' -Label { param($r) "$($r.Nazwa) <$($r.Identity)>" } `
            -Action { param($r) Remove-HTDynamicGroup -Identity $r.Identity; 'Usunięto' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'Organization' -Category 'Poczta (Exchange)' -Key 'exo.contacts' -Title 'Kontakty zewnętrzne' -Icon 'E77B' -Service 'Exchange' `
    -Description 'Kontakty pocztowe (osoby spoza firmy w książce adresowej, cel przekierowań i członkowie grup): lista z firmą i telefonem, tworzenie wielu naraz, edycja, ukrywanie w GAL i usuwanie (prawy przycisk).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż kontakty' -Icon 'E77B' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Kontakty zewnętrzne' -ScriptBlock { Get-HTMailContacts } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nowe kontakty…' -Create -NoRowMenu -Icon 'E710' -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'Exchange')) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Nowe kontakty')) { return }
        $form = Show-HTFormDialog -Title 'Nowe kontakty' -Icon 'E77B' -OkText 'Dalej' -Width 640 -Fields @(
            @{ Name = 'Lines'; Label = 'Kontakty - jeden w linii: Nazwa; e-mail; firma; telefon (firma i telefon opcjonalne)'; Type = 'Multiline'; Height = 140; Required = $true; Hint = 'Np. «Jan Kowalski; jan.kowalski@partner.pl; Partner sp. z o.o.; +48 600 000 000». Można wkleić kolumny z Excela (tabulator).' }
            @{ Name = 'Hidden'; Label = 'Ukryj w książce adresowej (np. kontakty tylko do przekierowań)'; Type = 'Check' }
        )
        if (-not $form) { return }
        $entries = @(ConvertFrom-HTContactLines -Text $form.Lines)
        $bad = @($entries | Where-Object { -not $_.Valid })
        if ($bad.Count -or $entries.Count -eq 0) { Show-HTWarning -Title 'Nowe kontakty' -Text ("Popraw dane:`n`n" + (@($bad | ForEach-Object { "$($_.DisplayName): $(@($_.Errors) -join ', ')" }) -join "`n")); return }
        Invoke-HTTargetAction -Module $m -Name 'Nowe kontakty' -Targets $entries -Label { param($t) "$($t.DisplayName) <$($t.Email)>" } -Confirm "Utworzyć kontakty: $($entries.Count)?" -Action {
            param($t)
            New-HTMailContact -DisplayName $t.DisplayName -Email $t.Email -Company $t.Company -Phone $t.Phone -Hidden ([bool]$form.Hidden) | Out-Null
            'Utworzono'
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Edytuj…' -Icon 'E70F' -Danger -Action {
        param($m, $rows)
        $c = @($rows | Where-Object { $_.Identity })[0]
        if (-not $c) { return }
        $form = Show-HTFormDialog -Title "Kontakt: $($c.Nazwa)" -Icon 'E77B' -Fields @(
            @{ Name = 'DisplayName'; Label = 'Nazwa wyświetlana'; Required = $true; Default = $c.Nazwa }
            @{ Name = 'Email'; Label = 'Adres e-mail'; Required = $true; Validation = 'Email'; Default = $c.'Adres e-mail' }
            @{ Name = 'Company'; Label = 'Firma'; Default = $c.Firma }
            @{ Name = 'Title'; Label = 'Stanowisko'; Default = $c.Stanowisko }
            @{ Name = 'Phone'; Label = 'Telefon'; Default = $c.Telefon }
        )
        if (-not $form) { return }
        # Tylko zmienione pola; wyczyszczone - «-»
        $diff = { param($new, $old) if ([string]$new -ceq [string]$old) { '' } elseif (-not $new) { '-' } else { [string]$new } }
        $params = @{ Identity = $c.Identity; DisplayName = (& $diff $form.DisplayName $c.Nazwa); Email = (& $diff $form.Email $c.'Adres e-mail'); Company = (& $diff $form.Company $c.Firma); Title = (& $diff $form.Title $c.Stanowisko); Phone = (& $diff $form.Phone $c.Telefon) }
        $changed = [ordered]@{}
        foreach ($k in 'DisplayName', 'Email', 'Company', 'Title', 'Phone') { if ($params[$k]) { $changed[$k] = $params[$k] } }
        if ($changed.Count -eq 0) { Show-HTToast 'Brak zmian.' 'info'; return }
        Invoke-HTRowAction -Module $m -Name 'Zmiana kontaktu' -Summary @(ConvertTo-HTChangeSummary -Settings $changed -Labels @{ DisplayName = 'Nazwa'; Email = 'Adres e-mail'; Company = 'Firma'; Title = 'Stanowisko'; Phone = 'Telefon' }) -Rows @($c) -Label { param($r) $r.Nazwa } -Action { param($r) Set-HTMailContactDetails @params; 'Zapisano' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Ukryj w GAL' -Icon 'ED1A' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Ukrycie kontaktu w GAL' -Summary 'Kontakt ukryty w książce adresowej (GAL): tak' -Rows @($rows | Where-Object { $_.Identity }) -Label { param($r) $r.Nazwa } -Action { param($r) Set-HTMailContactHidden -Identity $r.Identity -Hidden $true; 'Ukryty' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Pokaż w GAL' -Icon 'E7B3' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Pokazanie kontaktu w GAL' -Summary 'Kontakt ukryty w książce adresowej (GAL): nie' -Rows @($rows | Where-Object { $_.Identity }) -Label { param($r) $r.Nazwa } -Action { param($r) Set-HTMailContactHidden -Identity $r.Identity -Hidden $false; 'Widoczny' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Usuń kontakt' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie kontaktu' -Rows @($rows | Where-Object { $_.Identity }) -Danger -Confirm 'Usunąć zaznaczone kontakty? Przekierowania i członkostwo w grupach z ich udziałem przestaną działać.' -Label { param($r) "$($r.Nazwa) <$($r.'Adres e-mail')>" } `
            -Action { param($r) Remove-HTMailContact -Identity $r.Identity; 'Usunięto' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Uprawnienia: foldery skrzynki, kopiowanie dostępu
Register-HTModule -Workspace 'Exchange' -Category 'Uprawnienia' -Key 'exo.folders' -Title 'Uprawnienia do folderów' -Icon 'E8B7' `
    -Description 'Dostęp do wybranych folderów skrzynki (np. Skrzynka odbiorcza\Faktury) zamiast całej skrzynki: lista folderów, kto ma dostęp, nadawanie poziomu (Reviewer, Editor…) także podfolderom, z widocznością folderów nadrzędnych (bez niej Outlook nie pokaże podfolderu) i odbieranie (prawy przycisk).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż foldery' -Icon 'E8B7' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Foldery skrzynki' -Single -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            $folders = @(Get-HTMailboxFolders -Identity $t.PrimarySmtpAddress)
            $m.Data.FolderPaths = @($folders | ForEach-Object { $_.__path })
            $folders
        }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Zaznacz foldery w wynikach i kliknij prawym przyciskiem. Uprawnienia do całej skrzynki - moduł «Uprawnienia do skrzynki».' | Out-Null
    Add-HTRowAction -Module $m -Text 'Kto ma dostęp do folderu' -Icon 'E8A1' -Action {
        param($m, $rows)
        $f = @($rows | Where-Object { $_.__path })[0]
        if (-not $f) { return }
        Set-HTBusy -Busy $true -Text "Uprawnienia folderu $($f.__path)…"
        try { $perms = @(Get-HTMailboxFolderPermissionRows -Mailbox $f.Skrzynka -Path $f.__path) }
        catch { Set-HTBusy -Busy $false -Text 'Błąd'; Show-HTError 'Nie odczytano uprawnień folderu.' $_; return }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        Show-HTDataViewer -Title "Uprawnienia: $($f.Folder)" -Description $f.Skrzynka -Data $perms -ExportName 'uprawnienia_folderu' -Icon 'E8D7'
    }
    Add-HTRowAction -Module $m -Text 'Nadaj uprawnienia…' -Icon 'E8FA' -Create -Action {
        param($m, $rows)
        $folders = @($rows | Where-Object { $_.__path })
        if ($folders.Count -eq 0) { return }
        $mailbox = [string]$folders[0].Skrzynka
        $form = Show-HTFormDialog -Title 'Uprawnienia do folderów' -Description "$mailbox • folderów: $($folders.Count)" -Icon 'E8D7' -OkText 'Nadaj' -Fields @(
            @{ Name = 'Users'; Label = 'Użytkownicy (adresy, jeden w linii)'; Type = 'Multiline'; Height = 60; Required = $true }
            @{ Name = 'Rights'; Label = 'Poziom uprawnień'; Type = 'Combo'; Options = @(Get-HTFolderAccessRights); Default = 'Reviewer'; Hint = 'Reviewer - odczyt, Author - odczyt i tworzenie, Editor - pełna edycja, Owner - także uprawnienia, FolderVisible - tylko widoczność folderu.' }
            @{ Name = 'Sub'; Label = 'Także wszystkie podfoldery'; Type = 'Check'; Default = $true }
            @{ Name = 'Visible'; Label = 'Widoczność folderów nadrzędnych (FolderVisible) - wymagana, by Outlook pokazał folder'; Type = 'Check'; Default = $true }
        )
        if (-not $form) { return }
        $users = @(Split-HTInputList $form.Users)
        $paths = @($folders | ForEach-Object { $_.__path })
        $all = @($m.Data.FolderPaths)
        Invoke-HTRowAction -Module $m -Name 'Uprawnienia do folderów' -Rows $users -Label { param($u) $u } -Confirm "Nadać $($form.Rights) do folderów ($(@($paths) -join ', '))$(if ($form.Sub) { ' z podfolderami' })?" -Action {
            param($u)
            Grant-HTMailboxFolderAccess -Mailbox $mailbox -Paths $paths -User $u -AccessRights $form.Rights -IncludeSubfolders:([bool]$form.Sub) -AllPaths $all -ParentVisibility:([bool]$form.Visible)
        }
    }
    Add-HTRowAction -Module $m -Text 'Odbierz uprawnienia…' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $folders = @($rows | Where-Object { $_.__path })
        if ($folders.Count -eq 0) { return }
        $mailbox = [string]$folders[0].Skrzynka
        $form = Show-HTFormDialog -Title 'Odbierz uprawnienia do folderów' -Description "$mailbox • folderów: $($folders.Count)" -Icon 'E74D' -OkText 'Odbierz' -Danger -Fields @(
            @{ Name = 'Users'; Label = 'Użytkownicy (adresy, jeden w linii)'; Type = 'Multiline'; Height = 60; Required = $true }
            @{ Name = 'Sub'; Label = 'Także wszystkie podfoldery'; Type = 'Check'; Default = $true }
        )
        if (-not $form) { return }
        $paths = @($folders | ForEach-Object { $_.__path })
        $all = @($m.Data.FolderPaths)
        Invoke-HTRowAction -Module $m -Name 'Odebranie uprawnień do folderów' -Summary @("Skrzynka: $mailbox", "Foldery: $($folders.Count)$(if ($form.Sub) { ' wraz z podfolderami' })") -Rows @(Split-HTInputList $form.Users) -Danger -Label { param($u) $u } -Action {
            param($u)
            Revoke-HTMailboxFolderAccess -Mailbox $mailbox -Paths $paths -User $u -IncludeSubfolders:([bool]$form.Sub) -AllPaths $all
        }
    }
}

Register-HTModule -Workspace 'Exchange' -Category 'Uprawnienia' -Key 'exo.copyaccess' -Title 'Kopiowanie dostępu (następca)' -Icon 'E8C8' -Service 'Exchange' `
    -Description 'Cały dostęp pracownika do skrzynek innych osób (pełny dostęp, wyślij jako, wyślij w imieniu), grup i kalendarzy - jedną listą. Nadanie zaznaczonych uprawnień następcy lub zastępcy, albo odebranie ich odchodzącemu (prawy przycisk). Przegląd wszystkich skrzynek może potrwać kilka minut.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Pracownik'
    $m.C.User = Add-HTTextBox -Parent $row -Width 280 -Placeholder 'adres e-mail (puste - zaznaczona skrzynka)'
    Add-HTAddressPicker -Parent $row -Module $m -TextBox $m.C.User | Out-Null
    $m.C.Groups = Add-HTCheckBox -Parent $row -Text 'Grupy' -Checked $true
    $m.C.Calendars = Add-HTCheckBox -Parent $row -Text 'Kalendarze innych skrzynek (wolno)'
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż dostęp' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        $user = $m.C.User.Text.Trim()
        if (-not $user) {
            $t = @(Get-HTTargets -Module $m -Single)[0]
            if (-not $t) { return }
            $user = [string]$t.PrimarySmtpAddress
        }
        $groups = Test-HTChecked $m.C.Groups
        $calendars = Test-HTChecked $m.C.Calendars
        $m.Data.SourceUser = $user
        Invoke-HTQuery -Module $m -Name "Dostęp: $user" -ScriptBlock {
            Get-HTUserAccessForCopy -User $user -IncludeGroups:$groups -IncludeCalendars:$calendars -OnProgress { param($i, $total, $name) if ($i % 5 -eq 0 -or $i -eq $total) { Set-HTProgress -Value $i -Maximum $total -Text "Sprawdzanie [$i/$total] $name" } }
        }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Następca'
    $m.C.Target = Add-HTTextBox -Parent $row2 -Width 380 -Placeholder 'adresy osób, które mają dostać dostęp (kilka - przecinek)'
    Add-HTAddressPicker -Parent $row2 -Module $m -TextBox $m.C.Target -Multiple | Out-Null
    $m.C.AutoMap = Add-HTCheckBox -Parent $row2 -Text 'AutoMapping' -Checked $true
    Add-HTButton -Parent $row2 -Module $m -Text 'Nadaj zaznaczone uprawnienia' -Icon 'E8FA' -Create -OnClick {
        param($m)
        $targetUsers = @(Split-HTInputList $m.C.Target.Text)
        if ($targetUsers.Count -eq 0) { Show-HTWarning 'Wpisz adresy osób, które mają dostać dostęp.'; return }
        $items = @(Get-HTResultSelection -Module $m | Where-Object { $_.__kind })
        if ($items.Count -eq 0) {
            $items = @(Get-HTResultSelection -Module $m -AllVisible | Where-Object { $_.__kind })
            if ($items.Count -eq 0) { Show-HTWarning 'Najpierw kliknij «Pokaż dostęp».'; return }
        }
        $autoMap = Test-HTChecked $m.C.AutoMap
        $pairs = @(foreach ($u in $targetUsers) { foreach ($it in $items) { @{ Target = $u; Item = $it } } })
        Invoke-HTRowAction -Module $m -Name 'Kopiowanie dostępu' -Rows $pairs -Confirm "Nadać $($items.Count) uprawnień (zaznaczone wiersze, a gdy żaden - wszystkie widoczne) osobom: $($targetUsers -join ', ')?" `
            -Label { param($p) "$($p.Target): $($p.Item.Rodzaj) $($p.Item.Obiekt)" } -Action { param($p) Copy-HTUserAccessItem -Item $p.Item -TargetUser $p.Target -AutoMapping $autoMap }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Odbierz pracownikowi' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $user = [string]$m.Data.SourceUser
        if (-not $user) { return }
        Invoke-HTRowAction -Module $m -Name 'Odebranie dostępu' -Rows @($rows | Where-Object { $_.__kind }) -Danger -Confirm "Odebrać użytkownikowi $user zaznaczone uprawnienia i członkostwa?" `
            -Label { param($r) "$($r.Rodzaj): $($r.Obiekt)" } -Action { param($r) Remove-HTUserAccessItem -Item $r -User $user } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Raporty: kontrola konfiguracji organizacji
Register-HTModule -Workspace 'Organization' -Category 'Raporty' -Key 'exo.rep.config' -Title 'Kontrola konfiguracji' -Icon 'E9D9' -Service 'Exchange' `
    -Description 'Przegląd ustawień organizacji z oceną: nowoczesne uwierzytelnianie, inspekcja skrzynek i dziennik Purview, SMTP AUTH, automatyczne przekazywanie poczty na zewnątrz, DKIM domen, oznaczanie nadawców zewnętrznych, porady pocztowe, wyjątki filtrowania spamu. Z gotowym poleceniem naprawy.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź konfigurację' -Icon 'E9D9' -Primary -OnClick {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Kontrola konfiguracji Exchange' -ScriptBlock {
            Get-HTExchangeConfigFindings -Data (Get-HTExchangeConfigData) | Sort-Object -Stable @{ Expression = { switch ($_.Ocena) { 'Ryzyko' { 0 } 'Uwaga' { 1 } 'Nie sprawdzono' { 2 } 'OK' { 3 } default { 4 } } } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Centrum administracyjne Exchange' -Icon 'E8A7' -OnClick { param($m) Start-Process 'https://admin.exchange.microsoft.com' } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Część kontroli wymaga ról z dostępem do zasad ochrony (np. Security Reader) - brak dostępu: «Nie sprawdzono».' | Out-Null
}
#endregion
