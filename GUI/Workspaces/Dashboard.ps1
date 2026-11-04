# Przestrzeń robocza: Pulpit - stan usług, licencje, kondycja Microsoft 365

Register-HTWorkspace -Key 'Dashboard' -Title 'Pulpit' -Icon 'E80F' -Description 'Stan połączonych usług, licencje, kondycja Microsoft 365 i komunikaty' -Categories @('Przegląd', 'Microsoft 365', 'Program')

$script:DashboardTiles = @(
    @{ Key = 'Users'; Label = 'Użytkownicy M365'; Icon = 'E716' }
    @{ Key = 'Licenses'; Label = 'Licencje'; Icon = 'E8EC' }
    @{ Key = 'Intune'; Label = 'Urządzenia Intune'; Icon = 'E7F8' }
    @{ Key = 'Mailboxes'; Label = 'Skrzynki'; Icon = 'E715' }
    @{ Key = 'SharePoint'; Label = 'SharePoint'; Icon = 'E8F1' }
    @{ Key = 'AD'; Label = 'Zablokowane konta AD'; Icon = 'E72E'; OnPremises = $true }
)
# Kafelek Active Directory tylko przy włączonych funkcjach lokalnych (Ustawienia > Funkcje lokalne)
$script:DashboardTiles = @($script:DashboardTiles | Where-Object { -not $_.OnPremises -or $Global:ShowOnPremises })

function Update-HTDashboard {
    param([Parameter(Mandatory)][hashtable]$Module)
    Invoke-HTQuery -Module $Module -Name 'Odświeżanie pulpitu' -Service '' -ScriptBlock {
        $stats = Get-HTDashboardStats
        $states = @{ Ok = @{ Tone = ''; Text = 'OK'; Flag = '' }; Warn = @{ Tone = 'warn'; Text = 'Uwaga'; Flag = 'warn' }; Error = @{ Tone = 'crit'; Text = 'Błąd'; Flag = 'crit' }; Off = @{ Tone = 'off'; Text = 'Niepołączono'; Flag = 'muted' } }
        foreach ($tile in $script:DashboardTiles) {
            $value = $stats[$tile.Key]
            if (-not $value) { continue }
            $state = $states[[string]$value.State]
            Set-HTStatTile -Module $Module -Key $tile.Key -Value $value.Value -Tone $state.Tone -Label $(if ($value.Note) { "$($tile.Label) • $($value.Note)" } else { $tile.Label })
            [PSCustomObject]@{ Obszar = $tile.Label; Wartość = $value.Value; Szczegóły = $value.Note; Stan = $state.Text; __flag = $state.Flag }
        }
        foreach ($alert in @($stats.AlertList)) {
            [PSCustomObject]@{ Obszar = 'Alert'; Wartość = ''; Szczegóły = $alert; Stan = 'Uwaga'; __flag = 'warn' }
        }
        $Module.Data.Updated = $stats.Updated
        $Module.View_.resultHint.Text = "Aktualizacja: $($stats.Updated.ToString('HH:mm:ss'))"
    }
}

Register-HTModule -Workspace 'Dashboard' -Category 'Przegląd' -Key 'dash.overview' -Title 'Przegląd' -Icon 'E80F' `
    -Description 'Najważniejsze liczby ze wszystkich połączonych usług oraz wykryte problemy (brak licencji, niezgodne urządzenia, zablokowane konta).' -Build {
    param($m)
    foreach ($t in $script:DashboardTiles) { Add-HTStatTile -Module $m -Key $t.Key -Label $t.Label -Icon $t.Icon | Out-Null }
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Odśwież' -Icon 'E72C' -Primary -OnClick { param($m) Update-HTDashboard -Module $m } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Połącz usługi przyciskami w prawym górnym rogu - pulpit pokaże dane z każdej połączonej usługi.' | Out-Null
    # Ulubione moduły - szybkie przejście z pulpitu (odświeżane przy każdym otwarciu pulpitu)
    $m.C.Favorites = Add-HTToolbarRow -Module $m -Title 'Ulubione'
    $m.EmptyText = 'Brak danych'
    $m.OnShow = {
        param($m)
        Update-HTDashboardFavorites -Module $m
        if (-not $m.Data.Updated) { Update-HTDashboard -Module $m }
    }
}

function Update-HTDashboardFavorites {
    # Przyciski ulubionych modułów na pulpicie (gwiazdka: prawy przycisk na module w nawigacji > «Dodaj do ulubionych»)
    param([Parameter(Mandatory)][hashtable]$Module)
    $panel = $Module.C.Favorites
    if (-not $panel) { return }
    $panel.Children.Clear()
    $keys = @((Get-HTUiState).Favorites | Where-Object { $_ })
    $added = 0
    foreach ($key in $keys) {
        $definition = Get-HTModuleDefinition $key
        if (-not $definition -or -not (Test-HTModuleAllowed $key)) { continue }
        $b = New-HTButton -Text $definition.Title -Icon $definition.Icon -ToolTip $(if ($definition.Description) { $definition.Description } else { $definition.Title })
        $b.Margin = '0,0,8,6'
        $b.Tag = $key
        $b.add_Click({ param($s, $e) Invoke-HTUiAction -Module $null -Action { param($m, $k) Show-HTModule -Key $k } -Source ([string]$s.Tag) })
        [void]$panel.Children.Add($b)
        $added++
    }
    if ($added -eq 0) {
        $hint = New-Object System.Windows.Controls.TextBlock
        $hint.Text = 'Brak ulubionych - prawy przycisk na module w nawigacji > «Dodaj do ulubionych». Ulubione są też na początku palety Ctrl+K.'
        $hint.Foreground = Get-HTBrush '#7B8496'
        $hint.TextWrapping = 'Wrap'
        $hint.Margin = '0,4,0,6'
        [void]$panel.Children.Add($hint)
    }
}

Register-HTModule -Workspace 'Dashboard' -Category 'Microsoft 365' -Key 'dash.licenses' -Title 'Licencje' -Icon 'E8EC' -Service 'Graph' `
    -Description 'Subskrypcje w tenancie: przypisane, dostępne i wyczerpane licencje. Prawy przycisk - lista użytkowników z licencją.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz licencje' -Icon 'E72C' -Primary -OnClick {
        param($m)
        # Oficjalne nazwy licencji Microsoft (pobierane raz na 30 dni, potem z pliku)
        [void](Get-HTLicenseCatalog)
        Invoke-HTQuery -Module $m -Name 'Licencje' -ScriptBlock {
            foreach ($sku in @(Get-HTSubscribedSkus -Force | Sort-Object SkuPartNumber)) {
                [PSCustomObject]@{
                    Licencja    = Get-HTSkuFriendlyName $sku.SkuPartNumber
                    'Co zawiera' = Get-HTSkuDescription -ServicePlans @($sku.ServicePlans)
                    SKU         = $sku.SkuPartNumber
                    Zakupione   = $sku.Enabled
                    Przypisane  = $sku.Consumed
                    Dostępne    = $sku.Available
                    Stan        = $sku.Status
                    SkuId       = "$($sku.SkuId)"
                    'Plany usług' = (@(Get-HTServicePlanNames -ServicePlans @($sku.ServicePlans)) -join "`n")
                    __flag      = if ($sku.Status -ne 'Enabled') { 'muted' } elseif ($sku.Enabled -gt 0 -and $sku.Available -le 0) { 'warn' } else { '' }
                }
            }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Odśwież nazwy licencji' -Icon 'E895' -ToolTip 'Pobierz aktualną listę nazw licencji Microsoft (download.microsoft.com)' -OnClick {
        param($m)
        Set-HTBusy -Busy $true -Text 'Pobieranie listy nazw licencji…'
        try { $catalog = Get-HTLicenseCatalog -Refresh } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        if ($catalog) { Show-HTToast "Lista nazw licencji: $($catalog.Products.Count) pozycji." 'ok'; Invoke-HTModulePrimary $m }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Dwuklik na licencji - pełna lista planów usług. Nazwy z oficjalnej listy Microsoft, najpopularniejsze po polsku.' | Out-Null
    Add-HTRowAction -Module $m -Text 'Pokaż użytkowników z licencją' -Icon 'E716' -Action {
        param($m, $rows)
        $sku = @($rows)[0]
        Set-HTBusy -Busy $true -Text "Użytkownicy z licencją $($sku.SKU)…"
        try { $users = @(Get-HTSkuUsers -SkuId $sku.SkuId) } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        Show-HTDataViewer -Title "Licencja: $($sku.Licencja)" -Description "$($users.Count) użytkowników" -Data $users -ExportName "licencja_$($sku.SKU)"
    }
}

Register-HTModule -Workspace 'Dashboard' -Category 'Microsoft 365' -Key 'dash.health' -Title 'Kondycja usług' -Icon 'E95E' -Service 'Graph' `
    -Description 'Stan usług Microsoft 365 i otwarte incydenty (wymaga uprawnienia ServiceHealth.Read.All).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź' -Icon 'E72C' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Kondycja usług' -ScriptBlock { Get-HTM365ServiceHealth } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Centrum administracyjne' -Icon 'E8A7' -OnClick { param($m) Start-Process 'https://admin.microsoft.com/Adminportal/Home#/servicehealth' } | Out-Null
}

Register-HTModule -Workspace 'Dashboard' -Category 'Microsoft 365' -Key 'dash.messages' -Title 'Centrum wiadomości' -Icon 'E789' -Service 'Graph' `
    -Description 'Zapowiedzi zmian i komunikaty Microsoft (Message Center). Wiersze z terminem działania są wyróżnione.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Okres'
    Add-HTLabel -Parent $row -Text 'Ostatnie dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 30 -Minimum 1 -Maximum 365
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz' -Icon 'E72C' -Primary -OnClick {
        param($m)
        $days = Get-HTNum $m.C.Days
        Invoke-HTQuery -Module $m -Name 'Centrum wiadomości' -ScriptBlock { Get-HTM365MessageCenter -Days $days }
    } | Out-Null
}

Register-HTModule -Workspace 'Dashboard' -Category 'Program' -Key 'dash.env' -Title 'Moduły i środowisko' -Icon 'E90F' -Service '' `
    -Description 'Weryfikacja pakietów: wersje PowerShell, .NET i modułów względem wersji sprawdzonych z programem, zgodność z tym PowerShell i konflikty bibliotek. Prawy przycisk - instalacja sprawdzonej, zgodnej albo najnowszej wersji (w sprawdzonej wersji głównej).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź' -Icon 'E9D9' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Weryfikacja modułów' -ScriptBlock { Get-HTEnvironmentReport } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Uruchom ponownie' -Icon 'E72C' -ToolTip 'Nowa sesja PowerShell - rozwiązuje konflikty bibliotek między modułami' -OnClick {
        param($m)
        if (Show-HTConfirm -Title 'Ponowne uruchomienie' -ConfirmText 'Uruchom ponownie' -Message 'Uruchomić program ponownie? Połączenia z usługami zostaną zakończone (po starcie trzeba wpisać PIN).') { Restart-HTApplication }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Folder dziennika' -Icon 'E838' -OnClick { param($m) $d = Get-HTLogDirectory; if ($d -and (Test-Path $d)) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $d) } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Folder eksportu' -Icon 'E838' -OnClick { param($m) Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f (Get-HTExportDirectory)) } | Out-Null
    $m.OnShow = { param($m) if ($m.Table.Rows.Count -eq 0) { Invoke-HTQuery -Module $m -Name 'Weryfikacja modułów' -ScriptBlock { Get-HTEnvironmentReport } } }
    Add-HTRowAction -Module $m -Text 'Zainstaluj sprawdzoną wersję' -Icon 'E73E' -Action {
        param($m, $rows)
        $req = Get-HTModuleRequirements
        $rows = @($rows | Where-Object { $_.Moduł -and $req.Contains([string]$_.Moduł) })
        if (-not $rows.Count) { Show-HTWarning 'Zaznacz moduły Microsoft Graph, Exchange Online albo PnP.PowerShell.' -Title 'Sprawdzona wersja'; return }
        Invoke-HTRowAction -Module $m -Name 'Instalacja sprawdzonej wersji modułu' -Service '' -Rows $rows -Label { param($r) "$($r.Moduł) $($req[[string]$r.Moduł].Tested)" } `
            -Confirm 'Zainstalować wersje sprawdzone z programem (obok obecnych - inne skrypty mogą dalej używać swoich)? Program użyje ich przy następnym połączeniu; moduł już wczytany w tej sesji - po ponownym uruchomieniu.' `
            -Action { param($r) "Zainstalowano $(Install-HTTestedModule -Name $r.Moduł)" } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Zainstaluj wersję zgodną z tym PowerShell' -Icon 'E896' -Action {
        param($m, $rows)
        foreach ($r in @($rows | Where-Object { $_.Moduł })) {
            Set-HTBusy -Busy $true -Text "Szukanie zgodnej wersji $($r.Moduł)…"
            try { $v = Install-HTCompatibleModule -Name $r.Moduł -OnProgress { param($text) Set-HTStatus -Text $text; Update-HTUi } }
            catch { $v = $null; Write-Log -Message "Instalacja $($r.Moduł): $($_.Exception.Message)" -Type 'Error' }
            finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
            if ($v) { Show-HTToast "Zainstalowano $($r.Moduł) $v." 'ok' } else { Show-HTWarning -Title $r.Moduł -Text 'Nie znaleziono zgodnej wersji wśród ostatnich wydań - zaktualizuj PowerShell (https://aka.ms/powershell).' }
        }
        Invoke-HTModulePrimary $m
    }
    Add-HTRowAction -Module $m -Text 'Zaktualizuj do najnowszej sprawdzonej wersji głównej' -Icon 'E777' -Action {
        param($m, $rows)
        $scope = if (Test-HTIsAdministrator) { 'AllUsers' } else { 'CurrentUser' }
        $req = Get-HTModuleRequirements
        Invoke-HTRowAction -Module $m -Name 'Aktualizacja modułu' -Service '' -Rows @($rows | Where-Object { $_.Moduł }) -Confirm "Zainstalować najnowsze wersje z PowerShell Gallery ($scope) w sprawdzonej wersji głównej (np. PnP 3.x, nie 4.x)? Najnowsza wersja może wymagać nowszego PowerShell - program wtedy użyje starszej zgodnej." `
            -Label { param($r) $r.Moduł } -Action {
            param($r)
            $limit = $req[[string]$r.Moduł]
            if ($limit) { Install-Module -Name $r.Moduł -MaximumVersion "$($limit.MaxMajor).999.999" -Scope $scope -Repository PSGallery -Force -AllowClobber -AcceptLicense -ErrorAction Stop }
            else { Install-Module -Name $r.Moduł -Scope $scope -Repository PSGallery -Force -AllowClobber -AcceptLicense -ErrorAction Stop }
            Restore-HTSkippedModulePaths | Out-Null
            'Zaktualizowano'
        } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

function Update-HTLogFileList {
    # Dni z plikami dziennika w liście wyboru (najnowsze pierwsze); wybór zostaje, jeśli plik nadal jest
    param([Parameter(Mandatory)][hashtable]$Module)
    $combo = $Module.C.Day
    $previous = [string]$combo.SelectedItem
    $Module.Data.LogFiles = @(Get-HTLogFiles)
    $combo.Items.Clear()
    foreach ($f in $Module.Data.LogFiles) { [void]$combo.Items.Add(('{0:yyyy-MM-dd}  •  {1}  ({2} KB)' -f $f.Date, $f.Name, $f.SizeKB)) }
    if ($combo.Items.Count -eq 0) { return }
    $index = [Math]::Max(0, $combo.Items.IndexOf($previous))
    $combo.SelectedIndex = $index
}

Register-HTModule -Workspace 'Dashboard' -Category 'Program' -Key 'dash.tenants' -Title 'Profile tenantów' -Icon 'E716' -Service '' `
    -Description 'Zapisane tenanty (klienci GDAP i własne): Microsoft 365, Exchange, SharePoint z Client ID PnP. Dwuklik - połącz; import i eksport CSV. Bez haseł.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Profile'
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż profile' -Icon 'E72C' -Primary -OnClick {
        param($m)
        $defaultClientId = "$($Global:LastUsedClientID)"
        Invoke-HTQuery -Module $m -Name 'Profile tenantów' -Service '' -ScriptBlock { foreach ($p in @(Find-HTTenantProfiles -Profiles (Get-HTTenantProfiles))) { ConvertTo-HTTenantProfileRow -TenantProfile $p -DefaultClientId $defaultClientId } }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Dodaj profil…' -Create -NoRowMenu -Icon 'E710' -OnClick {
        param($m)
        $edited = Edit-HTTenantProfile -New
        if ($edited) { Save-HTTenantProfile -TenantProfile $edited; Show-HTToast "Zapisano profil «$($edited.Name)»." 'ok'; Invoke-HTModulePrimary $m }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Plik CSV'
    Add-HTButton -Parent $row2 -Module $m -Text 'Import z CSV…' -Create -NoRowMenu -Icon 'E8B5' -OnClick { param($m) if (Import-HTTenantProfilesInteractive) { Invoke-HTModulePrimary $m } } | Out-Null
    Add-HTButton -Parent $row2 -Module $m -Text 'Eksport do CSV…' -Icon 'EDE1' -OnClick { param($m) Export-HTTenantProfilesInteractive } | Out-Null
    Add-HTButton -Parent $row2 -Module $m -Text 'Zapisz szablon CSV' -Icon 'E74E' -OnClick {
        param($m)
        $path = Select-HTSaveFile -Title 'Szablon CSV profili tenantów' -Filter 'CSV (*.csv)|*.csv' -FileName 'Profile_tenantow_szablon.csv' -DefaultExt '.csv'
        if (-not $path) { return }
        [System.IO.File]::WriteAllText($path, (Get-HTTenantProfilesCsvTemplate) + "`r`n", [System.Text.UTF8Encoding]::new($true))
        Show-HTToast 'Zapisano szablon: kolumny Nazwa i Tenant (albo Organizacja Exchange) są wymagane, pozostałe - opcjonalne.' 'ok' 8
    } | Out-Null
    Add-HTLabel -Parent $row2 -Hint -Text 'Separator ; albo ,. Usługi: Microsoft 365, Exchange, SharePoint. GDAP: Tak/Nie. Client ID PnP - aplikacja w tenancie klienta.' | Out-Null
    $m.ResultHint = 'Dwuklik - połącz; prawy przycisk - edycja, duplikat, usunięcie'
    $m.EmptyText = 'Brak profili - «Dodaj profil…» albo «Import z CSV…»'
    $m.RowDoubleClick = {
        param($m, $row)
        $item = Get-HTObjectValue $row '__obj'
        if (-not $item -or -not $item.__profile) { return }
        $services = Select-HTTenantServices -TenantProfile $item.__profile
        if ($services) { [void](Connect-HTTenantProfile -TenantProfile $item.__profile -Services $services); Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Połącz…' -Icon 'E716' -Action {
        param($m, $rows)
        $tp = @($rows | Where-Object { $_.__profile } | Select-Object -First 1)[0]
        if (-not $tp) { return }
        $services = Select-HTTenantServices -TenantProfile $tp.__profile
        if ($services) { [void](Connect-HTTenantProfile -TenantProfile $tp.__profile -Services $services); Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Edytuj…' -Icon 'E70F' -Action {
        param($m, $rows)
        $tp = @($rows | Where-Object { $_.__profile } | Select-Object -First 1)[0]
        if (-not $tp) { return }
        $edited = Edit-HTTenantProfile -TenantProfile $tp.__profile
        if ($edited) { Save-HTTenantProfile -TenantProfile $edited -OriginalName $tp.__profile.Name; Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Duplikuj…' -Icon 'E8C8' -Action {
        param($m, $rows)
        $tp = @($rows | Where-Object { $_.__profile } | Select-Object -First 1)[0]
        if (-not $tp) { return }
        $copy = ConvertTo-HTTenantProfile $tp.__profile
        $copy.Name = "$($copy.Name) (kopia)"
        $copy.LastUsed = ''
        $edited = Edit-HTTenantProfile -TenantProfile $copy -New -Title 'Kopia profilu'
        if ($edited) { Save-HTTenantProfile -TenantProfile $edited; Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Usuń profile' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $names = @($rows | Where-Object { $_.__profile } | ForEach-Object { $_.__profile.Name })
        if (-not $names.Count) { return }
        if (-not (Show-HTConfirm -Title 'Usuń profile' -Message 'Usunąć zaznaczone profile tenantów?' -Items $names -Danger -ConfirmText 'Usuń')) { return }
        Set-HTTenantProfiles -Profiles @(Get-HTTenantProfiles | Where-Object { $names -notcontains $_.Name })
        Write-Log -Message "Usunięto profile tenantów: $($names -join ', ')." -Type 'Info'
        Invoke-HTModulePrimary $m
    }
    $m.OnShow = { param($m) Invoke-HTModulePrimary $m }
}

Register-HTModule -Workspace 'Dashboard' -Category 'Program' -Key 'dash.log' -Title 'Dziennik programu' -Icon 'E81C' -Service '' `
    -Description 'Wpisy dziennika z wybranego dnia (pliki z 30 dni): poziom, konto MFA, komunikat. Filtry kolumn (lejki w nagłówkach), eksport do CSV lub raportu HTML.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Plik'
    $m.C.Day = Add-HTComboBox -Parent $row -Width 360
    Add-HTButton -Parent $row -Module $m -Text 'Odśwież listę' -Icon 'E72C' -OnClick { param($m) Update-HTLogFileList -Module $m } | Out-Null
    $row = Add-HTToolbarRow -Module $m -Title 'Wpisy'
    $m.C.Level = Add-HTComboBox -Parent $row -Items @('Wszystkie', 'Ostrzeżenia i błędy', 'Tylko błędy') -Width 180
    $m.C.Text = Add-HTTextBox -Parent $row -Width 240 -Placeholder 'Fragment komunikatu lub konto…'
    Add-HTButton -Parent $row -Module $m -Text 'Wczytaj' -Icon 'E8E5' -Primary -OnClick {
        param($m)
        $i = $m.C.Day.SelectedIndex
        if ($i -lt 0 -or $i -ge @($m.Data.LogFiles).Count) { Show-HTWarning 'Brak plików dziennika.'; return }
        $file = $m.Data.LogFiles[$i]
        $level = @('All', 'Problems', 'Error')[[Math]::Max(0, $m.C.Level.SelectedIndex)]
        $text = $m.C.Text.Text.Trim()
        Invoke-HTQuery -Module $m -Name "Dziennik $('{0:yyyy-MM-dd}' -f $file.Date)" -ScriptBlock { Read-HTLogFile -Path $file.Path -Level $level -Text $text }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Otwórz plik' -Icon 'E8A7' -OnClick {
        param($m)
        $i = $m.C.Day.SelectedIndex
        if ($i -ge 0 -and $i -lt @($m.Data.LogFiles).Count) { Start-Process -FilePath 'notepad.exe' -ArgumentList ('"{0}"' -f $m.Data.LogFiles[$i].Path) }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Folder dziennika' -Icon 'E838' -OnClick { param($m) $d = Get-HTLogDirectory; if ($d -and (Test-Path $d)) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $d) } } | Out-Null
    $m.EmptyText = 'Wybierz dzień i kliknij «Wczytaj»'
    $m.OnShow = { param($m) Update-HTLogFileList -Module $m }
}
