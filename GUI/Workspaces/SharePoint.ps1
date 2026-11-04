# Przestrzeń robocza: SharePoint - biblioteki i foldery witryny (PnP.PowerShell)

Register-HTWorkspace -Key 'SharePoint' -Title 'SharePoint' -Icon 'E8F1' -Panel 'spTree' -Service 'SharePoint' `
    -Description 'Połączona witryna SharePoint (PnP): uprawnienia bibliotek, folderów i witryny, struktura folderów i biblioteki, grupy, pliki, kosz, raporty, nowe witryny' `
    -Categories @('Uprawnienia', 'Struktura', 'Zawartość', 'Witryna', 'Raporty')

$panel = New-HTTargetPanel -Key 'spTree' -Title 'Biblioteki i foldery' -Tree -EmptyIcon 'E8F1' -EmptyText 'Połącz z witryną SharePoint (przycisk w prawym górnym rogu).' -Describe { param($n) @{ Key = $n.ServerRelativeUrl; Title = $n.Title } }
Add-HTPanelLoader -Panel $panel -Service 'SharePoint' -Text 'Wczytaj biblioteki' -Loader {
    param($p)
    $p.pTree.Items.Clear()
    foreach ($lib in @(Get-HTSPLibraries)) { [void]$p.pTree.Items.Add((New-HTTreeItem -Item $lib -Text "$($lib.Title) ($($lib.ItemCount))" -Icon 'E8F1' -Lazy)) }
} | Out-Null
Add-HTPanelHint -Panel $panel -Text 'Rozwiń bibliotekę, aby zobaczyć foldery. Pole wyboru - obiekt operacji (albo kliknięty element).' | Out-Null

$script:SPTreeEvents = @{
    Expanded = {
        param($s, $e)
        try {
            $node = $e.OriginalSource
            if (-not ($node -is [System.Windows.Controls.TreeViewItem])) { return }
            if ($node.Items.Count -ne 1 -or $node.Items[0].Tag -ne '__placeholder__') { return }
            $node.Items.Clear()
            Set-HTBusy -Busy $true -Text "Wczytywanie folderów: $($node.Tag.Title)…"
            try {
                foreach ($folder in @(Get-HTSPSubFolders -ServerRelativeUrl $node.Tag.ServerRelativeUrl -ListTitle $node.Tag.ListTitle -ListId (Get-HTSPListId -Node $node.Tag))) {
                    [void]$node.Items.Add((New-HTTreeItem -Item $folder -Text $folder.Title -Icon 'E8B7' -Lazy))
                }
            }
            finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        }
        catch {
            Write-Log -Message "Wczytywanie folderów: $($_.Exception.Message)" -Type 'Error'
            Show-HTError 'Nie udało się wczytać folderów.' $_
        }
    }
    Checked  = {
        param($s, $e)
        try { if ($e.OriginalSource -is [System.Windows.Controls.CheckBox]) { Update-HTTargetCount (Get-HTPanel 'spTree') } } catch { Write-Verbose $_ }
    }
}
$panel.pTree.AddHandler([System.Windows.Controls.TreeViewItem]::ExpandedEvent, [System.Windows.RoutedEventHandler]$script:SPTreeEvents.Expanded)
$panel.pTree.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]$script:SPTreeEvents.Checked)

function Get-HTSPNodeLabel { param($n) [string]$n.ServerRelativeUrl }

#region Uprawnienia
#region Podmioty uprawnień: grupy SharePoint i grupy Microsoft 365 / zabezpieczeń (Entra ID)
$script:SPPrincipalTypes = @('Użytkownik lub grupa zabezpieczeń (e-mail)', 'Grupa SharePoint', 'Grupa Microsoft 365 / zabezpieczeń (Entra ID)')
$script:SPEntraGroups = @{}

function New-HTSPGroupInteractive {
    # Nowa grupa SharePoint witryny (formularz, potwierdzenie, utworzenie, wpis do podsumowania). Zwraca nazwę albo $null.
    if (-not (Assert-HTConnection -Service 'SharePoint')) { return $null }
    if (-not (Assert-HTWriteAllowed -Operation 'Nowa grupa SharePoint')) { return $null }
    $none = '(bez uprawnień do witryny)'
    $roles = @($none) + @(Get-HTSPRoleDefinitions)
    $form = Show-HTFormDialog -Title 'Nowa grupa SharePoint' -Icon 'E902' -OkText 'Utwórz' -Fields @(
        @{ Name = 'Title'; Label = 'Nazwa'; Required = $true }
        @{ Name = 'Description'; Label = 'Opis' }
        @{ Name = 'Role'; Label = 'Poziom uprawnień grupy do całej witryny'; Type = 'Combo'; Options = $roles; Hint = 'Bez uprawnień - grupę można potem dodać do wybranych bibliotek i folderów (np. w strukturze folderów).' }
        @{ Name = 'Members'; Label = 'Członkowie (e-mail, jeden w linii)'; Type = 'Multiline'; Height = 80 }
    )
    if (-not $form) { return $null }
    $title = ([string]$form.Title).Trim()
    if (-not (Confirm-HTChange -Name 'Nowa grupa SharePoint' -Labels @($title) -Summary @(Get-HTPendingFormSummary) -Confirm "Utworzyć grupę SharePoint $title?")) { return $null }
    Set-HTBusy -Busy $true -Text "Tworzenie grupy $title…"
    try {
        $members = @(Split-HTInputList $form.Members)
        New-HTSPGroup -Title $title -Description $form.Description -Members $members | Out-Null
        if ($form.Role -and $form.Role -ne $none) { Set-HTSPGroupWebRole -Group $title -Role $form.Role }
        $details = "członków: $($members.Count)$(if ($form.Role -and $form.Role -ne $none) { ", witryna: $($form.Role)" })"
        Add-HTOperationRecord -Operation 'Nowa grupa SharePoint' -Object $title -Details $details -Module 'Grupy SharePoint'
        Show-HTToast "Utworzono grupę SharePoint $title." 'ok'
        return $title
    }
    catch {
        Add-HTOperationRecord -Operation 'Nowa grupa SharePoint' -Object $title -Status 'Błąd' -Details $_.Exception.Message -Module 'Grupy SharePoint'
        Show-HTError -Text "Nie utworzono grupy SharePoint $title." -ErrorObject $_
        return $null
    }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
}

function Add-HTSPFormPrincipal {
    # Podmiot dopisany do formularza uprawnień; zmiana rodzaju podmiotu zastępuje wcześniej wpisane podmioty
    param([Parameter(Mandatory)]$Window, [Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Type)
    $typeBox = $Window.Tag.Controls['Type'].Control
    $box = $Window.Tag.Controls['Principal'].Control
    $sameType = [string]$typeBox.SelectedItem -eq $Type
    $typeBox.SelectedItem = $Type
    $current = if ($sameType) { @(([string]$box.Text) -split '[;\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) } else { @() }
    $box.Text = (@($current) + $Text | Select-Object -Unique) -join '; '
}

function Select-HTSPEntraGroups {
    # Wybór grup Microsoft 365 / zabezpieczeń (Entra ID) do formularza uprawnień SharePoint
    param([Parameter(Mandatory)]$Window)
    if (-not (Assert-HTConnection -Service 'Graph')) { return }
    Set-HTBusy -Busy $true -Text 'Pobieranie grup Microsoft 365…'
    try { $groups = @(Get-HTM365Groups | Where-Object { $_.Type -ne 'Dystrybucyjna' }) } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
    $columns = @(@{ Text = 'Nazwa'; Property = 'DisplayName' }, @{ Text = 'Typ'; Property = 'Type' }, @{ Text = 'E-mail'; Property = 'Mail' }, @{ Text = 'Opis'; Property = 'Description' })
    $selected = @(Show-HTSelectionDialog -Title 'Grupy Microsoft 365 / zabezpieczeń' -Prompt 'Grupy, które dostaną uprawnienia (członkowie grupy - także przyszli - mają dostęp).' -Items $groups -Columns $columns -MultiSelect -Icon 'E902')
    foreach ($g in @($selected | Where-Object { $_ })) {
        $script:SPEntraGroups[([string]$g.DisplayName).ToLowerInvariant()] = $g
        Add-HTSPFormPrincipal -Window $Window -Text ([string]$g.DisplayName) -Type $script:SPPrincipalTypes[2]
    }
}

function Get-HTSPPrincipalFormFields {
    # Pola formularza uprawnień: rodzaj podmiotu, podmioty, przyciski wyboru i tworzenia grup
    param([string[]]$SharePointGroups = @(), [string]$Label = 'Podmiot (e-mail, login albo nazwa grupy; kilka - średnik)')
    @{ Name = 'Type'; Label = 'Rodzaj podmiotu'; Type = 'Combo'; Options = $script:SPPrincipalTypes }
    @{ Name = 'Principal'; Label = $Label; Type = 'Combo'; Editable = $true; Options = $SharePointGroups; Required = $true }
    @{ Type = 'Buttons'; Buttons = @(
            @{ Text = 'Grupa z Microsoft 365…'; Icon = 'E902'; ToolTip = 'Grupa zabezpieczeń albo Microsoft 365 z tenanta (Entra ID)'; OnClick = { param($w) Select-HTSPEntraGroups -Window $w } }
            @{ Text = 'Nowa grupa Microsoft 365…'; Icon = 'E710'; Create = $true; ToolTip = 'Utwórz grupę zabezpieczeń albo Microsoft 365 i nadaj jej uprawnienia'; OnClick = {
                    param($w)
                    $g = New-HTM365GroupInteractive
                    if ($g) { $script:SPEntraGroups[([string]$g.DisplayName).ToLowerInvariant()] = $g; Add-HTSPFormPrincipal -Window $w -Text ([string]$g.DisplayName) -Type $script:SPPrincipalTypes[2] }
                }
            }
            @{ Text = 'Nowa grupa SharePoint…'; Icon = 'E710'; Create = $true; ToolTip = 'Utwórz grupę SharePoint witryny i nadaj jej uprawnienia'; OnClick = {
                    param($w)
                    $title = New-HTSPGroupInteractive
                    if ($title) { Add-HTSPFormPrincipal -Window $w -Text $title -Type $script:SPPrincipalTypes[1] }
                }
            }
        )
    }
}

function Resolve-HTSPFormPrincipals {
    <#
        Podmioty z formularza uprawnień: @{ Type (User / SharePointGroup); Items = @(@{ Name; Login }) }. Grupy Entra ID
        (trzeci rodzaj) - login grupy (Get-HTSPGroupClaim) z wybranych w formularzu albo wyszukane po nazwie.
    #>
    param([Parameter(Mandatory)]$Form)
    $names = @(([string]$Form.Principal) -split '[;\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $kind = [string]$Form.Type
    if ($kind -eq $script:SPPrincipalTypes[1]) { return @{ Type = 'SharePointGroup'; Items = @($names | ForEach-Object { @{ Name = $_; Login = $_ } }) } }
    if ($kind -ne $script:SPPrincipalTypes[2]) { return @{ Type = 'User'; Items = @($names | ForEach-Object { @{ Name = $_; Login = $_ } }) } }
    $all = $null
    $items = foreach ($n in $names) {
        $g = $script:SPEntraGroups[$n.ToLowerInvariant()]
        if (-not $g) {
            if (-not $Global:ConnectedToGraphAPI) { throw "Grupa «$n»: połącz się z Microsoft 365 albo wybierz grupę przyciskiem «Grupa z Microsoft 365…»." }
            if ($null -eq $all) { $all = @(Get-HTM365Groups) }
            $found = @($all | Where-Object { [string]$_.DisplayName -ieq $n })
            if ($found.Count -eq 0) { throw "Nie znaleziono grupy Microsoft 365 / zabezpieczeń «$n»." }
            if ($found.Count -gt 1) { throw "Kilka grup o nazwie «$n» - wybierz właściwą przyciskiem «Grupa z Microsoft 365…»." }
            $g = $found[0]
        }
        @{ Name = $n; Login = (Get-HTSPGroupClaim -Group $g) }
    }
    return @{ Type = 'User'; Items = @($items) }
}
#endregion

Register-HTModule -Workspace 'SharePoint' -Category 'Uprawnienia' -Key 'sp.perms' -Title 'Uprawnienia' -Icon 'E8D7' `
    -Description 'Kto ma dostęp do biblioteki / folderu i czy uprawnienia są dziedziczone. Nadawanie i odbieranie uprawnień, zarządzanie dziedziczeniem.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż uprawnienia' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Uprawnienia' -AlwaysShowObject -Label { param($t) Get-HTSPNodeLabel $t } -Action {
            param($t)
            foreach ($p in @(Get-HTSPPermissions -Node $t)) {
                [PSCustomObject]@{ Podmiot = $p.Principal; Typ = $p.PrincipalType; Uprawnienia = $p.Roles; Unikalne = $p.Unique; Login = $p.LoginName; __assignment = $p }
            }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nadaj uprawnienia…' -Icon 'E8FA' -Create -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        Set-HTBusy -Busy $true -Text 'Pobieranie poziomów uprawnień…'
        try {
            $roles = @(Get-HTSPRoleDefinitions)
            $groups = @(Get-HTSPGroups | ForEach-Object { $_.Title })
        }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        $form = Show-HTFormDialog -Title 'Nadaj uprawnienia' -Description "Obiekty: $($targets.Count). Nadanie uprawnień obiektowi z dziedziczeniem przerywa dziedziczenie." -Icon 'E8D7' -OkText 'Nadaj' -Width 640 -Fields @(
            @(Get-HTSPPrincipalFormFields -SharePointGroups $groups)
            @{ Name = 'Role'; Label = 'Poziom uprawnień'; Type = 'Combo'; Options = $roles }
        )
        if (-not $form) { return }
        try { $resolved = Resolve-HTSPFormPrincipals -Form $form } catch { Show-HTWarning $_.Exception.Message -Title 'Nadaj uprawnienia'; return }
        $type = $resolved.Type
        $principals = @($resolved.Items)
        Invoke-HTTargetAction -Module $m -Name 'Nadanie uprawnień' -Targets $targets -Label { param($t) Get-HTSPNodeLabel $t } -Action {
            param($t)
            foreach ($p in $principals) { Grant-HTSPPermission -Node $t -Principal $p.Login -PrincipalType $type -Role $form.Role }
            "$(@($principals | ForEach-Object { $_.Name }) -join ', '): $($form.Role)"
        }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Dziedziczenie'
    $m.C.Copy = Add-HTCheckBox -Parent $row2 -Text 'Kopiuj obecne uprawnienia' -Checked $true
    Add-HTButton -Parent $row2 -Module $m -Text 'Przerwij dziedziczenie' -Icon 'E71A' -Danger -OnClick {
        param($m)
        $copy = Test-HTChecked $m.C.Copy
        Invoke-HTTargetAction -Module $m -Name 'Przerwanie dziedziczenia' -Confirm 'Przerwać dziedziczenie uprawnień wybranych obiektów?' -Label { param($t) Get-HTSPNodeLabel $t } -Action { param($t) Set-HTSPInheritance -Node $t -Inherit $false -CopyExisting $copy; 'Uprawnienia unikalne' }
    } | Out-Null
    Add-HTButton -Parent $row2 -Module $m -Text 'Przywróć dziedziczenie' -Icon 'E777' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Przywrócenie dziedziczenia' -Danger -Confirm 'Przywrócić dziedziczenie? Unikalne uprawnienia wybranych obiektów zostaną usunięte.' -Label { param($t) Get-HTSPNodeLabel $t } -Action { param($t) Set-HTSPInheritance -Node $t -Inherit $true; 'Dziedziczone' }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Odbierz uprawnienia' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Odebranie uprawnień' -Rows @($rows | Where-Object { $_.__assignment }) -Danger -Confirm 'Odebrać zaznaczone uprawnienia?' -Label { param($r) "$($r.Obiekt): $($r.Podmiot) ($($r.Uprawnienia))" } `
            -Action { param($r) Revoke-HTSPPermission -Node $r.__target -Assignment $r.__assignment } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Zmień poziom uprawnień…' -Icon 'E70F' -Danger -Action {
        param($m, $rows)
        $sel = @($rows | Where-Object { $_.__assignment })
        if ($sel.Count -eq 0) { return }
        $roles = @(Get-HTSPRoleDefinitions)
        $form = Show-HTFormDialog -Title 'Zmień poziom uprawnień' -Description "Przypisań: $($sel.Count) - obecne poziomy zostaną zastąpione wybranym" -Icon 'E8D7' -OkText 'Zmień' -Fields @(@{ Name = 'Role'; Label = 'Nowy poziom uprawnień'; Type = 'Combo'; Options = $roles })
        if (-not $form) { return }
        Invoke-HTRowAction -Module $m -Name 'Zmiana poziomu uprawnień' -Rows $sel -Label { param($r) "$($r.Obiekt): $($r.Podmiot)" } -Action {
            param($r)
            Set-HTSPPermissionLevel -Node $r.__target -Assignment $r.__assignment -Role $form.Role
            "$($r.Uprawnienia) -> $($form.Role)"
        } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Zawartość
Register-HTModule -Workspace 'SharePoint' -Category 'Zawartość' -Key 'sp.files' -Title 'Pliki' -Icon 'E8A5' `
    -Description 'Pliki w zaznaczonej bibliotece / folderze: rozmiar i daty. Prawy przycisk - otwarcie w przeglądarce.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż pliki' -Icon 'E8A5' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Pliki' -Label { param($t) Get-HTSPNodeLabel $t } -Action { param($t) Get-HTSPFolderFiles -Node $t }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Otwórz folder w przeglądarce' -Icon 'E8A7' -OnClick {
        param($m)
        foreach ($t in @(Get-HTTargets -Module $m | Select-Object -First 3)) { Start-Process (Get-HTSPAbsoluteUrl -ServerRelativeUrl $t.ServerRelativeUrl) }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Otwórz w przeglądarce' -Icon 'E8A7' -Action {
        param($m, $rows)
        foreach ($r in @($rows | Select-Object -First 5)) { Start-Process (Get-HTSPAbsoluteUrl -ServerRelativeUrl $r.ServerRelativeUrl) }
    }
    Add-HTRowAction -Module $m -Text 'Kopiuj / przenieś do…' -Icon 'E8C8' -Action {
        param($m, $rows)
        Invoke-HTSPCopyInteractive -Module $m -Items @($rows | Where-Object { $_.ServerRelativeUrl } | ForEach-Object { @{ Label = $_.Nazwa; Url = $_.ServerRelativeUrl } })
    }
}

Register-HTModule -Workspace 'SharePoint' -Category 'Zawartość' -Key 'sp.newfolder' -Title 'Foldery: nowy i usuwanie' -Icon 'E8F4' `
    -Description 'Tworzy folder w zaznaczonej bibliotece lub folderze (po utworzeniu można nadać mu osobne uprawnienia) i usuwa zaznaczone foldery z zawartością do kosza witryny. Kilka folderów: pola wyboru w drzewie, Shift + kliknięcie - zakres.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Nazwa folderu'
    $m.C.Name = Add-HTTextBox -Parent $row -Width 280
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz' -Create -NoRowMenu -Icon 'E8F4' -Primary -OnClick {
        param($m)
        $name = $m.C.Name.Text.Trim()
        if (-not $name) { Show-HTWarning 'Podaj nazwę folderu.'; return }
        $t = @(Get-HTTargets -Module $m -Single)[0]
        if (-not $t) { return }
        Invoke-HTTargetAction -Module $m -Name 'Nowy folder' -Summary "Nowy folder: $name" -Targets @($t) -Label { param($t) Get-HTSPNodeLabel $t } -Action {
            param($t)
            $folder = New-HTSPFolder -ParentNode $t -Name $name
            "Utworzono: $($folder.ServerRelativeUrl)"
        }
        $m.C.Name.Text = ''
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row2 -Module $m -Text 'Usuń zaznaczone foldery…' -Icon 'E74D' -Danger -ToolTip 'Foldery zaznaczone w drzewie (z zawartością) - do kosza witryny, przywrócenie do 93 dni' -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if (-not $targets.Count) { return }
        $folders = @($targets | Where-Object { -not $_.IsLibrary })
        $libs = @($targets | Where-Object { $_.IsLibrary })
        if ($libs.Count) { Show-HTWarning "Pominięto biblioteki ($($libs.Count)): $(@($libs | ForEach-Object { $_.Title }) -join ', ') - biblioteki usuwa się w Struktura > Ustawienia bibliotek > «Usuń biblioteki…»." -Title 'Usuń foldery' }
        if (-not $folders.Count) { return }
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie folderu' -Targets $folders -Danger -TypeToConfirm 'USUŃ' -Label { param($t) Get-HTSPNodeLabel $t } `
            -Confirm 'Usunąć zaznaczone foldery razem z zawartością (pliki i podfoldery)? Trafią do kosza witryny - przywrócenie: Zawartość > Kosz witryny (do 93 dni).' -Action {
            param($t)
            Remove-HTSPFolder -Node $t
            $p = Get-HTPanel 'spTree'
            if ($p) { Remove-HTTreeItem -Panel $p -Item $t }
            'Przeniesiono do kosza witryny'
        }
    } | Out-Null
    Add-HTLabel -Parent $row2 -Hint -Text 'Kilka folderów: pola wyboru w drzewie po lewej (Shift + kliknięcie - zakres na tym samym poziomie).' | Out-Null
}

Register-HTModule -Workspace 'SharePoint' -Category 'Zawartość' -Key 'sp.recycle' -Title 'Kosz witryny' -Icon 'E74D' -Service 'SharePoint' `
    -Description 'Usunięte pliki i foldery (kosz witryny i kosz zbiorczy, do 93 dni). Przywracanie - np. po przypadkowym usunięciu folderu przez użytkownika.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Filtr'
    Add-HTLabel -Parent $row -Text 'Ostatnie dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 30 -Minimum 1 -Maximum 93
    $m.C.By = Add-HTTextBox -Parent $row -Width 220 -Placeholder 'Usunięte przez (opcjonalnie)'
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż kosz' -Icon 'E72C' -Primary -OnClick {
        param($m)
        $days = Get-HTNum $m.C.Days
        $by = $m.C.By.Text.Trim()
        Invoke-HTQuery -Module $m -Name 'Kosz witryny' -ScriptBlock { Get-HTSPRecycleBinItems -Days $days -DeletedBy $by }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Przywróć' -Icon 'E777' -Create -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Przywrócenie z kosza' -Rows $rows -Confirm 'Przywrócić zaznaczone elementy do pierwotnej lokalizacji?' -Label { param($r) "$($r.Lokalizacja)/$($r.Nazwa)" } `
            -Action { param($r) Restore-HTSPRecycleBinItem -Id $r.Id } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Usuń trwale' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Trwałe usunięcie' -Rows $rows -Danger -TypeToConfirm 'USUŃ' -Confirm 'Trwale usunąć zaznaczone elementy z kosza?' -Label { param($r) "$($r.Lokalizacja)/$($r.Nazwa)" } `
            -Action { param($r) Clear-HTSPRecycleBinItem -Id $r.Id } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Witryna
Register-HTModule -Workspace 'SharePoint' -Category 'Witryna' -Key 'sp.groups' -Title 'Grupy SharePoint' -Icon 'E902' -Service 'SharePoint' `
    -Description 'Grupy witryny (Właściciele, Członkowie, Odwiedzający i własne): członkowie, dodawanie i usuwanie, nowe grupy.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż grupy' -Icon 'E902' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Grupy SharePoint' -ScriptBlock { Get-HTSPGroups | ForEach-Object { [PSCustomObject]@{ Nazwa = $_.Title; Właściciel = $_.Owner; Opis = $_.Description; Id = $_.Id } } } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nowa grupa…' -Create -NoRowMenu -Icon 'E710' -OnClick {
        param($m)
        if (New-HTSPGroupInteractive) { Invoke-HTModulePrimary $m }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Członkowie' -Icon 'E716' -Action {
        param($m, $rows)
        $g = @($rows)[0]
        $members = @(Get-HTSPGroupMembers -Group $g.Nazwa)
        Show-HTDataViewer -Title "Członkowie: $($g.Nazwa)" -Description "$($members.Count) członków" -Data $members -ExportName "sp_$($g.Nazwa)"
    }
    Add-HTRowAction -Module $m -Text 'Dodaj członków…' -Icon 'E8FA' -Create -Action {
        param($m, $rows)
        $g = @($rows)[0]
        $text = Show-InputBox -Title "Dodaj do: $($g.Nazwa)" -Prompt 'Adresy e-mail lub loginy (jeden w linii):' -Multiline -Icon 'E8FA'
        $logins = @(Split-HTInputList $text)
        if ($logins.Count -eq 0) { return }
        Invoke-HTRowAction -Module $m -Name "Dodanie do $($g.Nazwa)" -Summary "Grupa SharePoint: $($g.Nazwa)" -Rows $logins -Label { param($r) $r } -Action { param($r) Add-HTSPGroupMember -Group $g.Nazwa -LoginName $r }
    }
    Add-HTRowAction -Module $m -Text 'Usuń członków…' -Icon 'E738' -Danger -Action {
        param($m, $rows)
        $g = @($rows)[0]
        $members = @(Get-HTSPGroupMembers -Group $g.Nazwa)
        $selected = @(Show-HTSelectionDialog -Title "Usuń z: $($g.Nazwa)" -Items $members -MultiSelect -OkText 'Usuń')
        if ($selected.Count -eq 0) { return }
        Invoke-HTRowAction -Module $m -Name "Usunięcie z $($g.Nazwa)" -Rows $selected -Danger -Confirm 'Usunąć wybranych członków z grupy?' -Label { param($r) $r.Title } -Action { param($r) Remove-HTSPGroupMember -Group $g.Nazwa -LoginName $r.LoginName }
    }
    Add-HTRowAction -Module $m -Text 'Uprawnienia grupy do witryny…' -Icon 'E8D7' -Danger -Action {
        param($m, $rows)
        $groups = @($rows | Where-Object { $_.Nazwa -and $_.Id })
        if ($groups.Count -eq 0) { return }
        $form = Show-HTFormDialog -Title 'Uprawnienia grupy do witryny' -Description "Grupy: $(@($groups | ForEach-Object { $_.Nazwa }) -join ', ')" -Icon 'E8D7' -Fields @(
            @{ Name = 'Action'; Label = 'Operacja'; Type = 'Combo'; Options = @('Nadaj poziom', 'Odbierz poziom') }
            @{ Name = 'Role'; Label = 'Poziom uprawnień'; Type = 'Combo'; Options = @(Get-HTSPRoleDefinitions) }
        )
        if (-not $form) { return }
        $remove = $form.Action -eq 'Odbierz poziom'
        Invoke-HTRowAction -Module $m -Name 'Uprawnienia grupy do witryny' -Rows $groups -Label { param($r) $r.Nazwa } -Action { param($r) Set-HTSPGroupWebRole -Group $r.Nazwa -Role $form.Role -Remove:$remove; "$(if ($remove) { 'Odebrano' } else { 'Nadano' }): $($form.Role)" }
    }
    Add-HTRowAction -Module $m -Text 'Ustawienia grupy…' -Icon 'E713' -Danger -Action {
        param($m, $rows)
        $g = @($rows | Where-Object { $_.Nazwa -and $_.Id })[0]
        if (-not $g) { return }
        try { $cur = Get-HTSPGroupOptions -Group $g.Nazwa } catch { Show-HTError 'Nie odczytano ustawień grupy.' $_; return }
        $yes = { param($b) if ($b) { 'Tak' } else { 'Nie' } }
        $form = Show-HTFormDialog -Title "Grupa: $($g.Nazwa)" -Icon 'E902' -Width 600 -Fields @(
            @{ Name = 'Owner'; Label = 'Właściciel grupy (e-mail albo nazwa grupy SharePoint)'; Default = $cur.Owner }
            @{ Name = 'Description'; Label = 'Opis'; Default = $cur.Description }
            @{ Name = 'OnlyAllowMembersViewMembership'; Label = 'Członków grupy widzą tylko jej członkowie'; Type = 'Combo'; Options = @('Tak', 'Nie'); Default = (& $yes $cur.OnlyAllowMembersViewMembership) }
            @{ Name = 'AllowMembersEditMembership'; Label = 'Członkowie mogą zmieniać skład grupy'; Type = 'Combo'; Options = @('Tak', 'Nie'); Default = (& $yes $cur.AllowMembersEditMembership) }
            @{ Name = 'AllowRequestToJoinLeave'; Label = 'Prośby o dołączenie i opuszczenie grupy'; Type = 'Combo'; Options = @('Tak', 'Nie'); Default = (& $yes $cur.AllowRequestToJoinLeave) }
            @{ Name = 'AutoAcceptRequestToJoinLeave'; Label = 'Automatycznie akceptuj prośby'; Type = 'Combo'; Options = @('Tak', 'Nie'); Default = (& $yes $cur.AutoAcceptRequestToJoinLeave) }
        )
        if (-not $form) { return }
        $settings = @{}
        foreach ($k in $form.Keys) {
            $v = if ($form[$k] -in 'Tak', 'Nie') { $form[$k] -eq 'Tak' } else { [string]$form[$k] }
            if ([string]$v -cne [string]$cur[$k]) { $settings[$k] = $v }
        }
        if ($settings.Count -eq 0) { Show-HTToast 'Brak zmian.' 'info'; return }
        Invoke-HTRowAction -Module $m -Name 'Ustawienia grupy SharePoint' -Summary @(ConvertTo-HTChangeSummary -Settings $settings) -Rows @($g) -Label { param($r) $r.Nazwa } -Action { param($r) Set-HTSPGroupOptions -Group $r.Nazwa -Settings $settings; "Zmieniono: $(@($settings.Keys) -join ', ')" } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Usuń grupę' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie grupy SharePoint' -Rows @($rows | Where-Object { $_.Nazwa -and $_.Id }) -Danger -TypeToConfirm 'USUŃ' -Confirm 'Usunąć zaznaczone grupy? Ich członkowie stracą dostęp nadany przez te grupy (w całej witrynie).' `
            -Label { param($r) $r.Nazwa } -Action { param($r) Remove-HTSPGroup -Group $r.Nazwa; 'Usunięto' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'SharePoint' -Category 'Witryna' -Key 'sp.site' -Title 'Informacje o witrynie' -Icon 'E946' -Service 'SharePoint' `
    -Description 'Adres, właściciel, administratorzy kolekcji, wykorzystanie miejsca i limit, daty utworzenia i ostatniej zmiany.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż' -Icon 'E946' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Informacje o witrynie' -ScriptBlock { ConvertTo-HTDetailRows -Data (Get-HTSPSiteInfo) } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Otwórz witrynę' -Icon 'E8A7' -OnClick { param($m) if (Assert-HTConnection -Service 'SharePoint') { Start-Process (Get-PnPConnection).Url } } | Out-Null
}

Register-HTModule -Workspace 'SharePoint' -Category 'Witryna' -Key 'sp.app' -Title 'Aplikacja PnP (Client ID)' -Icon 'E8D7' -Service '' `
    -Description 'PnP PowerShell wymaga własnej rejestracji aplikacji w Entra ID. Tu utworzysz ją jednym kliknięciem (Client ID zapisze się w ustawieniach) i wygenerujesz klucz tajny.' -Build {
    param($m)
    $m.SecretColumns = @('Wartość')
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz Client ID…' -Create -NoRowMenu -Icon 'E710' -Primary -OnClick {
        param($m)
        $site = if ($Global:ConnectedToSharepointPnP) { (Get-PnPConnection).Url } else { $Global:DefaultSharepointSite }
        $result = Show-HTPnPAppRegistrationDialog -SiteUrl $site
        if ($result) {
            Reset-HTResults -Module $m
            Add-HTResultRows -Module $m -Objects @(
                [PSCustomObject]@{ Pole = 'Aplikacja'; Wartość = $result.DisplayName }
                [PSCustomObject]@{ Pole = 'Client ID'; Wartość = $result.ClientId }
                [PSCustomObject]@{ Pole = 'Tenant'; Wartość = $result.TenantId }
                [PSCustomObject]@{ Pole = 'Zgoda administratora'; Wartość = $result.ConsentGranted }
            )
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nowy klucz tajny…' -Create -NoRowMenu -Icon 'E8D7' -ToolTip 'Client secret dla istniejącej aplikacji (Microsoft Graph)' -OnClick { param($m) Show-HTAppSecretDialog } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Bieżący Client ID' -Icon 'E946' -OnClick {
        param($m)
        Reset-HTResults -Module $m
        Add-HTResultRows -Module $m -Objects @(
            [PSCustomObject]@{ Pole = 'Client ID (ustawienia)'; Wartość = "$($Global:LastUsedClientID)" }
            [PSCustomObject]@{ Pole = 'Zapamiętywanie Client ID'; Wartość = [bool]$Global:LogClientIDForPnP }
            [PSCustomObject]@{ Pole = 'Domyślna witryna'; Wartość = "$($Global:DefaultSharepointSite)" }
        )
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Rejestracje aplikacji (Entra)' -Icon 'E8A7' -OnClick { param($m) Start-Process 'https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade' } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Przeglądanie witryn bez Client ID: przestrzeń «Witryny».' | Out-Null
}
#endregion

#region Raporty
Register-HTModule -Workspace 'SharePoint' -Category 'Raporty' -Key 'sp.rep.unique' -Title 'Unikalne uprawnienia' -Icon 'E9D2' -Service 'SharePoint' `
    -Description 'Audyt: biblioteki i foldery z przerwanym dziedziczeniem oraz ich uprawnienia (wyróżnione - dostęp dla wszystkich). Zaznaczone węzły lub cała witryna.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Głębokość folderów:' | Out-Null
    $m.C.Depth = Add-HTNumeric -Parent $row -Value 2 -Minimum 0 -Maximum 10
    $m.C.Scope = Add-HTSegmented -Parent $row -Items @('Cała witryna', 'Zaznaczone węzły')
    Add-HTButton -Parent $row -Module $m -Text 'Generuj raport' -Icon 'E9D2' -Primary -OnClick {
        param($m)
        $depth = Get-HTNum $m.C.Depth
        $nodes = $null
        if ((Get-HTSegmentIndex $m.C.Scope) -eq 1) {
            $nodes = @(Get-HTTargets -Module $m)
            if ($nodes.Count -eq 0) { return }
        }
        Invoke-HTQuery -Module $m -Name 'Raport unikalnych uprawnień' -ScriptBlock {
            Get-HTSPUniquePermissionsReport -Depth $depth -Nodes $nodes -OnProgress { param($path) Set-HTStatus -Text "Sprawdzanie: $path"; Update-HTUi }
        }
    } | Out-Null
}
#endregion

#region Wersje plików
Register-HTModule -Workspace 'SharePoint' -Category 'Zawartość' -Key 'sp.versions' -Title 'Stare wersje plików' -Icon 'E81C' -Service 'SharePoint' `
    -Description 'Pliki z dużą liczbą wersji w zaznaczonych bibliotekach lub folderach i miejsce zajmowane przez wersje. Prawy przycisk - usunięcie najstarszych wersji (zostaje N najnowszych). Przycinanie w całej witrynie - zadanie SharePoint.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Zostaw wersji:' | Out-Null
    $m.C.Keep = Add-HTNumeric -Parent $row -Value 50 -Minimum 1 -Maximum 500
    Add-HTButton -Parent $row -Module $m -Text 'Szukaj plików' -Icon 'E721' -Primary -OnClick {
        param($m)
        $keep = Get-HTNum $m.C.Keep
        Invoke-HTTargetQuery -Module $m -Name 'Wersje plików' -Label { param($t) Get-HTSPNodeLabel $t } -Action {
            param($t)
            Get-HTFileVersionUsage -ListTitle (Get-HTSPListRef -Node $t) -FolderServerRelativeUrl $(if ($t.IsLibrary) { '' } else { $t.ServerRelativeUrl }) -Keep $keep | Sort-Object 'Do odzyskania (MB)' -Descending
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Przytnij w całej witrynie…' -Icon 'E74D' -Danger -OnClick {
            param($m)
            if (-not (Test-HTVersionTrimJobAvailable)) { Show-HTWarning 'Przycinanie wersji w całej witrynie wymaga PnP.PowerShell 2.12 lub nowszego (New-PnPSiteFileVersionBatchDeleteJob).'; return }
            $keep = Get-HTNum $m.C.Keep
            if (-not (Assert-HTWriteAllowed -Operation 'Przycinanie wersji')) { return }
            if (-not (Show-HTConfirm -Danger -Title 'Przycinanie wersji' -TypeToConfirm 'WERSJE' -Message "Zlecić SharePoint usunięcie starszych wersji wszystkich plików w połączonej witrynie (zostanie $keep wersji głównych)? Operacji nie można cofnąć; zadanie działa w tle po stronie SharePoint.")) { return }
            try {
                Start-HTVersionTrimJob -Keep $keep
                Add-HTOperationRecord -Operation 'Przycinanie wersji w witrynie' -Object "$((Get-PnPConnection).Url)" -Details "Zostaw $keep wersji" -Module $m.Title
                Show-HTToast 'Zlecono zadanie przycinania wersji (stan: Get-PnPSiteFileVersionBatchDeleteJobStatus).' 'ok' 8
            }
            catch { Show-HTError 'Nie zlecono zadania.' $_ }
        } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń najstarsze wersje' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $keep = Get-HTNum $m.C.Keep
        $files = @($rows | Where-Object { $_.Ścieżka })
        Invoke-HTRowAction -Module $m -Name 'Usunięcie starych wersji' -Rows $files -Danger -Confirm "Usunąć starsze wersje zaznaczonych plików (zostanie $keep najnowszych)? Usunięte wersje trafią do kosza witryny." -Label { param($r) $r.Plik } -Action { param($r) Remove-HTOldFileVersions -FileServerRelativeUrl $r.Ścieżka -Keep $keep }
    }
}
#endregion

#region Wspólne: kopiowanie i przenoszenie, pomoc składni struktury
function Invoke-HTSPCopyInteractive {
    # Kopiowanie albo przenoszenie plików / folderów (-Items @(@{ Label; Url })) do folderu docelowego
    param([Parameter(Mandatory)][hashtable]$Module, [object[]]$Items = @())
    $Items = @($Items | Where-Object { $_ })
    if ($Items.Count -eq 0) { return }
    if (-not (Assert-HTConnection -Service 'SharePoint')) { return }
    $libraries = @()
    try { $libraries = @(Get-HTSPLibraries | ForEach-Object { $_.ServerRelativeUrl }) } catch { $libraries = @() }
    $form = Show-HTFormDialog -Title 'Kopiuj lub przenieś' -Description "Elementów: $($Items.Count)" -Icon 'E8C8' -OkText 'Dalej' -Width 640 -Fields @(
        @{ Name = 'Operation'; Label = 'Operacja'; Type = 'Combo'; Options = @('Kopiuj', 'Przenieś') }
        @{ Name = 'Target'; Label = 'Folder docelowy'; Type = 'Combo'; Editable = $true; Options = $libraries; Required = $true; Hint = 'Biblioteka z listy, ścieżka (np. /sites/witryna/Dokumenty/Archiwum, Dokumenty/Archiwum) albo pełny adres folderu - także w innej witrynie tego tenantu.' }
        @{ Name = 'Overwrite'; Label = 'Zastąp istniejące elementy o tej samej nazwie'; Type = 'Check' }
        @{ Name = 'NoHistory'; Label = 'Bez historii wersji (tylko bieżąca wersja - szybciej)'; Type = 'Check' }
    )
    if (-not $form) { return }
    $webUrl = Get-HTSPWebUrl
    $target = ConvertTo-HTSPServerRelativeUrl -Url $form.Target -WebUrl $webUrl
    $move = $form.Operation -eq 'Przenieś'
    Invoke-HTRowAction -Module $Module -Name "$($form.Operation) do $target" -Rows $Items -Label { param($r) $r.Label } -Confirm "$($form.Operation) $($Items.Count) elementów do $($target)?$(if ($move) { ' Przeniesione elementy znikną z obecnego miejsca (linki do nich przestaną działać).' })" -Action {
        param($r)
        Copy-HTSPItem -SourceUrl $r.Url -TargetFolderUrl $target -Move:$move -Overwrite:([bool]$form.Overwrite) -IgnoreVersionHistory:([bool]$form.NoHistory)
        "$($form.Operation): $($r.Url) -> $target"
    }
}

$script:SPStructureHelp = @'
STRUKTURA FOLDERÓW - SKŁADNIA

Każda linia to folder. Wcięcie (4 spacje albo Tab) oznacza folder podrzędny.
Ścieżka a/b/c tworzy kilka poziomów w jednej linii. Linie zaczynające się od # są komentarzami.

    Projekty
        2026
            Umowy
            Faktury
        Archiwum
    Kadry/Umowy/2026

UPRAWNIENIA - po znaku | w tej samej linii:

    Umowy | Zarząd=Pełna kontrola; jan.kowalski@firma.pl=Odczyt
    Kadry |! @Właściciele=Pełna kontrola; kadry@firma.pl=Edycja
    Wspólne | @Członkowie=Edycja; -anna.nowak@firma.pl

  |   przerywa dziedziczenie z KOPIĄ obecnych uprawnień i dodaje podane
  |!  przerywa dziedziczenie BEZ kopii - dostęp mają tylko podane osoby i grupy (oraz administratorzy witryny)
  -kto  odbiera dostęp (np. -anna.nowak@firma.pl)

  Podmiot: adres e-mail osoby albo grupy zabezpieczeń, nazwa grupy SharePoint
           albo grupa witryny: @Właściciele, @Członkowie, @Odwiedzający
  Poziom:  nazwa z witryny albo skrót: Pełna kontrola (Full), Edycja (Edit),
           Współtworzenie (Contribute), Odczyt (Read), Projektowanie (Design)

Istniejące foldery są pomijane, ale uprawnienia z ich linii są uzupełniane - tak można też
masowo nadać uprawnienia do istniejących folderów.

GDZIE:
  W zaznaczonych bibliotekach / folderach - ta sama struktura w każdym zaznaczonym miejscu
                                            (np. w folderze każdego klienta)
  W witrynie - pierwszy poziom to biblioteki (tworzone, gdy ich brak), dalej foldery

WZORZEC: «Odczytaj z podświetlonego folderu» przepisuje strukturę klikniętego w drzewie folderu
(np. wzorcowego projektu) - potem zaznacz polami wyboru miejsca docelowe i utwórz ją tam.
'@

function Show-HTSPStructureHelp { Show-HTTextDialog -Title 'Struktura folderów - składnia' -Text $script:SPStructureHelp }
#endregion

#region Struktura: struktura folderów, nowe biblioteki, ustawienia bibliotek, kolumny, szablony
function Show-HTSPStructureDialog {
    # Okno struktury folderów: szablony, odczyt wzorca z drzewa, zapis szablonu, podgląd albo utworzenie
    param([Parameter(Mandatory)][hashtable]$Module)
    if (-not (Assert-HTConnection -Service 'SharePoint')) { return }
    $siteMode = (Get-HTSegmentIndex $Module.C.Mode) -eq 1
    $targets = @()
    if (-not $siteMode) { $targets = @(Get-HTTargets -Module $Module); if ($targets.Count -eq 0) { return } }
    $templates = @(Get-HTSPStructureTemplates)
    $text = [string]$Module.Data.StructureText
    $preview = $true
    while ($true) {
        $form = Show-HTFormDialog -Title 'Struktura folderów' -Description $(if ($siteMode) { 'W witrynie - pierwszy poziom to biblioteki (tworzone, gdy ich brak)' } else { "W: $(@($targets | ForEach-Object { $_.ServerRelativeUrl }) -join ', ')" }) -Icon 'E8B7' -OkText 'Dalej' -Width 820 -MaxHeight 660 -Fields @(
            @{ Name = 'Template'; Label = 'Szablon'; Type = 'Combo'; Options = @($templates | ForEach-Object { $_.Name }) }
            @{ Type = 'Buttons'; Buttons = @(
                    @{ Text = 'Wstaw szablon'; Icon = 'E8C8'; ToolTip = 'Zastępuje tekst poniżej strukturą wybranego szablonu'; OnClick = {
                            param($w)
                            $name = [string]$w.Tag.Controls['Template'].Control.SelectedItem
                            $t = @(Get-HTSPStructureTemplates | Where-Object { $_.Name -eq $name })[0]
                            if ($t) { $w.Tag.Controls['Tree'].Control.Text = [string]$t.Text }
                        }
                    }
                    @{ Text = 'Odczytaj z podświetlonego folderu'; Icon = 'E8B7'; ToolTip = 'Struktura folderu klikniętego w drzewie po lewej (wzorzec); w trybie witryny bez podświetlenia - cała witryna'; OnClick = {
                            param($w)
                            $p = Get-HTPanel 'spTree'
                            $node = if ($p -and $p.pTree.SelectedItem) { $p.pTree.SelectedItem.Tag } else { $null }
                            if (-not $node -and (Get-HTSegmentIndex $script:SPStructureModule.C.Mode) -ne 1) { Show-HTWarning 'Kliknij w drzewie po lewej folder wzorcowy (podświetlenie), a polami wyboru zaznacz miejsca docelowe.'; return }
                            $perms = $w.Tag.Controls['Perms'].Control.IsChecked -eq $true
                            Set-HTBusy -Busy $true -Text 'Odczyt struktury folderów…'
                            try { $txt = Get-HTSPFolderTreeText -Node $node -Depth 6 -IncludePermissions:$perms -OnProgress { param($path) Set-HTStatus -Text "Odczyt: $path"; Update-HTUi } }
                            catch { Set-HTBusy -Busy $false -Text 'Błąd'; Show-HTError 'Nie odczytano struktury folderów.' $_; return }
                            finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
                            if (-not $txt) { Show-HTToast 'Folder nie ma podfolderów.' 'info'; return }
                            $w.Tag.Controls['Tree'].Control.Text = $txt
                        }
                    }
                    @{ Text = 'Zapisz jako szablon…'; Icon = 'E74E'; OnClick = {
                            param($w)
                            $txt = [string]$w.Tag.Controls['Tree'].Control.Text
                            if (-not $txt.Trim()) { Show-HTWarning 'Wpisz strukturę do zapisania.'; return }
                            $parsed = ConvertFrom-HTSPStructureText -Text $txt
                            if (@($parsed.Errors).Count) { Show-HTWarning -Title 'Szablon' -Text ("Popraw strukturę przed zapisaniem:`n`n" + (@($parsed.Errors) -join "`n")); return }
                            $name = Show-InputBox -Title 'Zapisz szablon' -Prompt 'Nazwa szablonu (ta sama nazwa - zastąpienie):' -DefaultText ([string]$w.Tag.Controls['Template'].Control.SelectedItem) -Icon 'E74E'
                            if (-not $name) { return }
                            Save-HTSPStructureTemplate -Name $name -Text $txt
                            $combo = $w.Tag.Controls['Template'].Control
                            if (-not $combo.Items.Contains($name.Trim())) { [void]$combo.Items.Add($name.Trim()) }
                            $combo.SelectedItem = $name.Trim()
                            Show-HTToast "Zapisano szablon «$($name.Trim())»." 'ok'
                        }
                    }
                    @{ Text = 'Składnia'; Icon = 'E897'; OnClick = { param($w) Show-HTSPStructureHelp } }
                ) }
            @{ Name = 'Tree'; Label = 'Foldery - jeden w linii; wcięcie (Tab / 4 spacje) - folder podrzędny; «|» - uprawnienia'; Type = 'Multiline'; Height = 300; Monospace = $true; Required = $true; Default = $text }
            @{ Name = 'Perms'; Label = 'Odczyt z folderu: także unikalne uprawnienia (wolniej)'; Type = 'Check' }
            @{ Name = 'Preview'; Label = 'Najpierw podgląd (bez zmian w SharePoint)'; Type = 'Check'; Default = $preview }
        )
        if (-not $form) { return }
        $text = [string]$form.Tree
        $preview = [bool]$form.Preview
        $Module.Data.StructureText = $text
        $parsed = ConvertFrom-HTSPStructureText -Text $text
        if (@($parsed.Errors).Count) { Show-HTWarning -Title 'Struktura folderów' -Text ("Popraw strukturę:`n`n" + (@($parsed.Errors | Select-Object -First 25) -join "`n")); continue }
        if (@($parsed.Items).Count -eq 0) { Show-HTWarning 'Wpisz co najmniej jeden folder.'; continue }
        break
    }
    $pending = @{ Items = @($parsed.Items); Targets = $targets; SiteMode = $siteMode }
    if ($preview) {
        $Module.Data.PendingStructure = $pending
        Invoke-HTSPStructureRun -Module $Module -Pending $pending -WhatIf
        Show-HTToast 'Podgląd gotowy - sprawdź tabelę i kliknij «Utwórz według podglądu».' 'info' 8
        return
    }
    $where = if ($siteMode) { 'w witrynie' } else { "w $($targets.Count) miejscach" }
    if (-not (Show-HTConfirm -Title 'Struktura folderów' -ConfirmText 'Utwórz' -Message "Utworzyć strukturę ($(@($parsed.Items).Count) pozycji, z uprawnieniami: $(@($parsed.Items | Where-Object { $_.Break }).Count)) $($where)?" -Items @($parsed.Items | Select-Object -First 40 | ForEach-Object { $_.Path }))) { return }
    Invoke-HTSPStructureRun -Module $Module -Pending $pending
}

function Invoke-HTSPStructureRun {
    # Podgląd (-WhatIf) albo utworzenie struktury dla wszystkich miejsc docelowych
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][hashtable]$Pending, [switch]$WhatIf)
    if (-not $WhatIf -and -not (Assert-HTWriteAllowed -Operation 'Struktura folderów')) { return }
    $items = @($Pending.Items)
    $targets = @($Pending.Targets)
    $siteMode = [bool]$Pending.SiteMode
    $name = if ($WhatIf) { 'Podgląd struktury' } else { 'Tworzenie struktury' }
    Invoke-HTQuery -Module $Module -Name $name -ScriptBlock {
        $progress = { param($i, $total, $path) if ($i % 3 -eq 0 -or $i -eq $total) { Set-HTProgress -Value $i -Maximum $total -Text "$name [$i/$total] $path" } }
        if ($siteMode) { Invoke-HTSPStructure -Items $items -WhatIf:$WhatIf -OnProgress $progress }
        else { foreach ($t in $targets) { Invoke-HTSPStructure -Items $items -BaseNode $t -WhatIf:$WhatIf -OnProgress $progress } }
    }
    if ($WhatIf) { return }
    $where = if ($siteMode) { 'witryna' } else { @($targets | ForEach-Object { $_.ServerRelativeUrl }) -join ', ' }
    Add-HTOperationRecord -Operation 'Struktura folderów' -Object $where -Details "pozycji: $($items.Count), z uprawnieniami: $(@($items | Where-Object { $_.Break }).Count)" -Module $Module.Title
    Write-Log -Message "Struktura folderów ($where): pozycji $($items.Count)" -Type 'Info'
    $Module.Data.PendingStructure = $null
    if ($siteMode) { $p = Get-HTPanel 'spTree'; if ($p) { Invoke-HTPanelLoad -Panel $p -Quiet } }
    else { Show-HTToast 'Nowe foldery zobaczysz po ponownym rozwinięciu folderów w drzewie (albo «Wczytaj biblioteki»).' 'info' 8 }
}

Register-HTModule -Workspace 'SharePoint' -Category 'Struktura' -Key 'sp.structure' -Title 'Struktura folderów (masowo)' -Icon 'E8B7' -Service 'SharePoint' `
    -Description 'Wiele folderów naraz z tekstu z wcięciami albo z szablonu - w każdej zaznaczonej bibliotece / folderze (np. ta sama struktura dla każdego klienta) albo w całej witrynie (biblioteki i foldery). Uprawnienia w tej samej linii (np. «Kadry |! @Właściciele=Pełna kontrola; kadry@firma.pl=Edycja»), odczyt struktury folderu wzorcowego, szablony, podgląd przed utworzeniem.' -Build {
    param($m)
    $script:SPStructureModule = $m
    $row = Add-HTToolbarRow -Module $m -Title 'Gdzie'
    $m.C.Mode = Add-HTSegmented -Parent $row -Items @('W zaznaczonych bibliotekach / folderach', 'W witrynie (1. poziom - biblioteki)')
    $row2 = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row2 -Module $m -Text 'Struktura…' -Icon 'E8B7' -Primary -OnClick { param($m) $script:SPStructureModule = $m; Show-HTSPStructureDialog -Module $m } | Out-Null
    Add-HTButton -Parent $row2 -Module $m -Text 'Utwórz według podglądu' -Icon 'E768' -Create -OnClick {
        param($m)
        $pending = $m.Data.PendingStructure
        if (-not $pending) { Show-HTWarning 'Najpierw kliknij «Struktura…» i wykonaj podgląd.'; return }
        if (-not (Show-HTConfirm -Title 'Struktura folderów' -ConfirmText 'Utwórz' -Message "Utworzyć strukturę z podglądu ($(@($pending.Items).Count) pozycji$(if (-not $pending.SiteMode) { ", miejsc: $(@($pending.Targets).Count)" }))?")) { return }
        Invoke-HTSPStructureRun -Module $m -Pending $pending
    } | Out-Null
    Add-HTButton -Parent $row2 -Module $m -Text 'Składnia' -Icon 'E897' -OnClick { param($m) Show-HTSPStructureHelp } | Out-Null
    Add-HTLabel -Parent $row2 -Hint -Text 'Podgląd pokazuje, co powstanie (Istnieje / Utworzy folder / uprawnienia) - bez zmian w SharePoint.' | Out-Null
}

Register-HTModule -Workspace 'SharePoint' -Category 'Struktura' -Key 'sp.newlib' -Title 'Nowa biblioteka' -Icon 'E8F1' -Service 'SharePoint' `
    -Description 'Nowe biblioteki dokumentów albo listy - jedna lub wiele naraz: adres bez polskich znaków, menu witryny, historia wersji z limitem, wersje robocze, wymagane wyewidencjonowanie, zatwierdzanie, kolumny (np. «Klient: Tekst», «Status: Wybór [Nowy, W toku]») i własne uprawnienia.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz biblioteki…' -Create -NoRowMenu -Icon 'E710' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'SharePoint')) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Nowa biblioteka')) { return }
        $prev = @{}
        $get = { param($k, $d) if ($prev.Contains($k)) { $prev[$k] } else { $d } }
        while ($true) {
            $form = Show-HTFormDialog -Title 'Nowe biblioteki' -Icon 'E8F1' -OkText 'Utwórz' -Width 700 -MaxHeight 640 -Fields @(
                @{ Name = 'Names'; Label = 'Nazwy (jedna w linii)'; Type = 'Multiline'; Height = 70; Required = $true; Default = (& $get 'Names' ''); Hint = 'Adres powstaje z nazwy bez polskich znaków i spacji (np. «Dokumenty Zarządu» -> /DokumentyZarzadu).' }
                @{ Name = 'Kind'; Label = 'Rodzaj'; Type = 'Combo'; Options = @('Biblioteka dokumentów', 'Lista'); Default = (& $get 'Kind' 'Biblioteka dokumentów') }
                @{ Name = 'Description'; Label = 'Opis'; Default = (& $get 'Description' '') }
                @{ Name = 'QuickLaunch'; Label = 'Pokaż w menu witryny'; Type = 'Check'; Default = (& $get 'QuickLaunch' $true) }
                @{ Type = 'Header'; Label = 'Wersje i zatwierdzanie' }
                @{ Name = 'Versioning'; Label = 'Historia wersji'; Type = 'Check'; Default = (& $get 'Versioning' $true) }
                @{ Name = 'Major'; Label = 'Limit wersji głównych (100-50000)'; Type = 'Number'; Min = 100; Max = 50000; Default = (& $get 'Major' 500) }
                @{ Name = 'Minor'; Label = 'Wersje pomocnicze (robocze, np. 1.1)'; Type = 'Check'; Default = (& $get 'Minor' $false) }
                @{ Name = 'Checkout'; Label = 'Wymagaj wyewidencjonowania przed edycją'; Type = 'Check'; Default = (& $get 'Checkout' $false) }
                @{ Name = 'Approval'; Label = 'Zatwierdzanie zawartości'; Type = 'Check'; Default = (& $get 'Approval' $false) }
                @{ Type = 'Header'; Label = 'Kolumny i uprawnienia' }
                @{ Name = 'Columns'; Label = 'Kolumny - jedna w linii: Nazwa: Typ [opcje] *'; Type = 'Multiline'; Height = 80; Monospace = $true; Default = (& $get 'Columns' ''); Hint = 'Typy: Tekst, Tekst wielowierszowy, Liczba, Data, Wybór [a, b], Wielokrotny wybór [a, b], Osoba, Tak/Nie, Waluta, Link; * na końcu - wymagana.' }
                @{ Name = 'Permissions'; Label = 'Uprawnienia (puste - dziedziczone z witryny)'; Default = (& $get 'Permissions' ''); Hint = 'Np. «! @Właściciele=Pełna kontrola; kadry@firma.pl=Edycja» - «!» na początku: bez kopiowania uprawnień witryny. @Właściciele, @Członkowie, @Odwiedzający - grupy witryny.' }
            )
            if (-not $form) { return }
            $prev = $form
            $problems = @()
            $names = @(@(([string]$form.Names) -split "`r?`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
            foreach ($n in $names) { $e = Test-HTSPItemName $n; if ($e) { $problems += "$($n): $e" } }
            if ($names.Count -eq 0) { $problems += 'Podaj nazwę biblioteki.' }
            $columns = @(ConvertFrom-HTSPColumnSpec -Text $form.Columns)
            $problems += @($columns | Where-Object { -not $_.Valid } | ForEach-Object { "Kolumna $($_.DisplayName): $(@($_.Errors) -join ', ')" })
            $spec = if (([string]$form.Permissions).Trim()) { ConvertFrom-HTSPPermissionSpec -Text $form.Permissions } else { $null }
            if ($spec) { $problems += @($spec.Errors) }
            if ($problems.Count -eq 0) { break }
            Show-HTWarning -Title 'Nowe biblioteki' -Text ("Popraw dane:`n`n" + ($problems -join "`n"))
        }
        $template = if ($form.Kind -eq 'Lista') { 'GenericList' } else { 'DocumentLibrary' }
        Invoke-HTTargetAction -Module $m -Name 'Nowa biblioteka' -Targets $names -Label { param($t) [string]$t } -Action {
            param($t)
            $lib = New-HTSPLibrary -Title $t -Template $template -Description ([string]$form.Description) -OnQuickLaunch ([bool]$form.QuickLaunch) -Versioning ([bool]$form.Versioning) `
                -MajorVersions ([int]$form.Major) -MinorVersions ([bool]$form.Minor) -ForceCheckout ([bool]$form.Checkout) -Approval ([bool]$form.Approval)
            $notes = @("Utworzono $($lib.ServerRelativeUrl)")
            foreach ($c in $columns) {
                try { Add-HTSPLibraryColumn -Node $lib -Column $c; $notes += "kolumna $($c.DisplayName)" }
                catch { $notes += "kolumna $($c.DisplayName) - błąd: $($_.Exception.Message)" }
            }
            if ($spec) {
                try { $notes += "uprawnienia: $(Set-HTSPNodeAccess -Node $lib -Grants @($spec.Grants) -Removes @($spec.Removes) -CopyExisting ([bool]$spec.Copy))" }
                catch { $notes += "uprawnienia - błąd: $($_.Exception.Message)" }
            }
            @{ Status = $(if (@($notes | Where-Object { $_ -match 'błąd' }).Count) { 'Utworzono z uwagami' } else { 'OK' }); Szczegóły = ($notes -join '; ') }
        }
        $p = Get-HTPanel 'spTree'
        if ($p) { Invoke-HTPanelLoad -Panel $p -Quiet }
    } | Out-Null
}

Register-HTModule -Workspace 'SharePoint' -Category 'Struktura' -Key 'sp.libsettings' -Title 'Ustawienia bibliotek' -Icon 'E713' -Service 'SharePoint' `
    -Description 'Ustawienia zaznaczonych bibliotek: historia wersji i limit wersji, wersje robocze, wymagane wyewidencjonowanie, zatwierdzanie, menu witryny, wyszukiwanie, ukrycie i nazwa. Wiele bibliotek naraz - zmieniane są tylko ustawione pola. Usuwanie bibliotek do kosza witryny.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż ustawienia' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Ustawienia bibliotek' -Label { param($t) Get-HTSPNodeLabel $t } -Action {
            param($t)
            if (-not $t.IsLibrary) { return [PSCustomObject]@{ Biblioteka = $t.ServerRelativeUrl; Opis = 'To folder - zaznacz bibliotekę'; __flag = 'muted' } }
            Get-HTSPLibrarySettings -Node $t
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Zmień ustawienia…' -Icon 'E70F' -Danger -OnClick {
        param($m)
        $libs = @(Get-HTChangeTargets -Module $m | Where-Object { $_.IsLibrary })
        if ($libs.Count -eq 0) { Show-HTWarning 'Zaznacz biblioteki w drzewie po lewej.'; return }
        if (-not (Assert-HTConnection -Service 'SharePoint')) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Ustawienia bibliotek')) { return }
        $current = $null
        if ($libs.Count -eq 1) {
            try { $current = (Get-HTSPLibrarySettings -Node $libs[0]).__values } catch { Show-HTError 'Nie odczytano ustawień biblioteki.' $_; return }
        }
        $values = $null
        while ($true) {
            $form = Show-HTFormDialog -Title 'Ustawienia bibliotek' -Description $(if ($current) { $libs[0].ServerRelativeUrl } else { "Bibliotek: $($libs.Count) - zmienione zostaną tylko ustawione pola" }) -Icon 'E8F1' -OkText 'Dalej' -Width 620 -Fields @(New-HTSPLibrarySettingsFields -Current $current -Values $values)
            if (-not $form) { return }
            $values = $form
            $r = Get-HTSPLibrarySettingChanges -Form $form -Current $current
            if (@($r.Errors).Count) { Show-HTWarning -Title 'Ustawienia bibliotek' -Text (@($r.Errors) -join "`n"); continue }
            if ($r.Settings.Count -eq 0) { Show-HTToast 'Brak zmian.' 'info'; return }
            break
        }
        $settings = $r.Settings
        Invoke-HTTargetAction -Module $m -Name 'Ustawienia bibliotek' -Targets $libs -Label { param($t) Get-HTSPNodeLabel $t } -Confirm "Zapisać zmiany?`n$(@($r.Display) -join "`n")" -Action { param($t) Set-HTSPLibrarySettings -Node $t -Settings $settings }
        if ($settings.Contains('Title') -or $settings.Contains('Hidden')) { $p = Get-HTPanel 'spTree'; if ($p) { Invoke-HTPanelLoad -Panel $p -Quiet } }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Usuń biblioteki…' -Icon 'E74D' -Danger -OnClick {
        param($m)
        $selected = @(Get-HTChangeTargets -Module $m)
        $libs = @($selected | Where-Object { $_.IsLibrary })
        if ($libs.Count -eq 0) {
            $text = if ($selected.Count) { 'Zaznaczone są foldery, nie biblioteki. Foldery usuwa się w Zawartość > «Foldery: nowy i usuwanie» > «Usuń zaznaczone foldery…».' } else { 'Zaznacz biblioteki w drzewie po lewej.' }
            Show-HTWarning $text -Title 'Usuń biblioteki'
            return
        }
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie biblioteki' -Targets $libs -Danger -TypeToConfirm 'USUŃ' -Label { param($t) Get-HTSPNodeLabel $t } `
            -Confirm 'Usunąć wybrane biblioteki razem z całą zawartością? Trafią do kosza witryny (przywrócenie: Zawartość > Kosz witryny, do 93 dni).' -Action { param($t) Remove-HTSPLibrary -Node $t; 'Przeniesiono do kosza' }
        $p = Get-HTPanel 'spTree'
        if ($p) { Invoke-HTPanelLoad -Panel $p -Quiet }
    } | Out-Null
}

Register-HTModule -Workspace 'SharePoint' -Category 'Struktura' -Key 'sp.columns' -Title 'Kolumny bibliotek' -Icon 'E8EC' -Service 'SharePoint' `
    -Description 'Kolumny (metadane) bibliotek: lista kolumn dodanych do biblioteki, dodawanie wielu kolumn do zaznaczonych bibliotek naraz (np. «Klient: Tekst *», «Status: Wybór [Nowy, W toku, Zamknięty]», «Termin: Data») i usuwanie (prawy przycisk).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż kolumny' -Icon 'E8EC' -Primary -OnClick {
        param($m)
        $lists = @(Get-HTTargets -Module $m | Group-Object ListTitle | ForEach-Object { $_.Group[0] })
        if ($lists.Count -eq 0) { return }
        Invoke-HTTargetQuery -Module $m -Name 'Kolumny bibliotek' -AlwaysShowObject -Targets $lists -Label { param($t) $t.ListTitle } -Action {
            param($t)
            $cols = @(Get-HTSPLibraryColumns -Node $t)
            if ($cols.Count -eq 0) { return [PSCustomObject]@{ Kolumna = '(brak dodanych kolumn)'; __flag = 'muted' } }
            $cols
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Dodaj kolumny…' -Icon 'E710' -Create -OnClick {
        param($m)
        $lists = @(Get-HTChangeTargets -Module $m | Group-Object ListTitle | ForEach-Object { $_.Group[0] })
        if ($lists.Count -eq 0) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Kolumny bibliotek')) { return }
        $text = ''
        while ($true) {
            $form = Show-HTFormDialog -Title 'Dodaj kolumny' -Description "Biblioteki: $(@($lists | ForEach-Object { $_.ListTitle }) -join ', ')" -Icon 'E8EC' -OkText 'Dodaj' -Width 640 -Fields @(
                @{ Name = 'Columns'; Label = 'Kolumny - jedna w linii: Nazwa: Typ [opcje] *'; Type = 'Multiline'; Height = 150; Monospace = $true; Required = $true; Default = $text; Hint = 'Typy: Tekst, Tekst wielowierszowy, Liczba, Data, Wybór [a, b], Wielokrotny wybór [a, b], Osoba, Tak/Nie, Waluta, Link; * na końcu - wymagana.' }
            )
            if (-not $form) { return }
            $text = $form.Columns
            $columns = @(ConvertFrom-HTSPColumnSpec -Text $form.Columns)
            $bad = @($columns | Where-Object { -not $_.Valid })
            if ($columns.Count -and -not $bad.Count) { break }
            Show-HTWarning -Title 'Kolumny' -Text ("Popraw:`n`n" + (@($bad | ForEach-Object { "$($_.DisplayName): $(@($_.Errors) -join ', ')" }) -join "`n"))
        }
        Invoke-HTTargetAction -Module $m -Name 'Dodanie kolumn' -Summary "Kolumny ($($columns.Count)): $(@($columns | ForEach-Object { $_.DisplayName }) -join ', ')" -Targets $lists -Label { param($t) $t.ListTitle } -Action {
            param($t)
            $done = @(); $failed = @()
            foreach ($c in $columns) { try { Add-HTSPLibraryColumn -Node $t -Column $c; $done += $c.DisplayName } catch { $failed += "$($c.DisplayName): $($_.Exception.Message)" } }
            if ($failed.Count) { throw "dodano: $($done -join ', '); błędy: $($failed -join '; ')" }
            "Dodano: $($done -join ', ')"
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń kolumnę' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie kolumny' -Rows @($rows | Where-Object { $_.__id }) -Danger -Confirm 'Usunąć zaznaczone kolumny? Wartości zapisane w tych kolumnach zostaną utracone.' -Label { param($r) "$($r.__list): $($r.Kolumna)" } `
            -Action { param($r) Remove-HTSPLibraryColumn -ListTitle $r.__list -Field $r.'Nazwa wewnętrzna'; 'Usunięto' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'SharePoint' -Category 'Struktura' -Key 'sp.templates' -Title 'Szablony struktur' -Icon 'E8A5' -Service '' `
    -Description 'Szablony struktur folderów (wbudowane i zapisane): liczba folderów i uprawnień, podgląd, import i eksport do pliku tekstowego (np. dla innych administratorów), usuwanie zapisanych. Nowe szablony zapisuje się w oknie «Struktura folderów».' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż szablony' -Icon 'E8A5' -Primary -OnClick {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Szablony struktur' -Service '' -ScriptBlock {
            foreach ($t in @(Get-HTSPStructureTemplates)) {
                $p = ConvertFrom-HTSPStructureText -Text $t.Text
                [PSCustomObject]@{
                    Szablon             = $t.Name
                    Rodzaj              = $(if ($t.BuiltIn) { 'wbudowany' } else { 'zapisany' })
                    Folderów            = @($p.Items).Count
                    'Z uprawnieniami'   = @($p.Items | Where-Object { $_.Break }).Count
                    Poziomów            = $(if (@($p.Items).Count) { (@($p.Items | ForEach-Object { $_.Level }) | Measure-Object -Maximum).Maximum + 1 } else { 0 })
                    Błędy               = @($p.Errors).Count
                    __template          = $t
                    __flag              = $(if (@($p.Errors).Count) { 'crit' } else { '' })
                }
            }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Importuj z pliku…' -Create -NoRowMenu -Icon 'E8E5' -OnClick {
        param($m)
        $path = Select-HTOpenFile -Title 'Szablon struktury (plik tekstowy)' -Filter 'Pliki tekstowe (*.txt)|*.txt|Wszystkie pliki (*.*)|*.*'
        if (-not $path) { return }
        $text = [System.IO.File]::ReadAllText($path)
        $parsed = ConvertFrom-HTSPStructureText -Text $text
        if (@($parsed.Errors).Count) { Show-HTWarning -Title 'Import szablonu' -Text ("Plik ma błędy:`n`n" + (@($parsed.Errors | Select-Object -First 20) -join "`n")); return }
        $name = Show-InputBox -Title 'Import szablonu' -Prompt 'Nazwa szablonu:' -DefaultText ([System.IO.Path]::GetFileNameWithoutExtension($path)) -Icon 'E8E5'
        if (-not $name) { return }
        Save-HTSPStructureTemplate -Name $name -Text $text
        Show-HTToast "Zaimportowano szablon «$name» ($(@($parsed.Items).Count) folderów)." 'ok'
        Invoke-HTModulePrimary $m
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Podgląd' -Icon 'E8A1' -Action {
        param($m, $rows)
        $t = @($rows)[0].__template
        if ($t) { Show-HTTextDialog -Title "Szablon: $($t.Name)" -Text ([string]$t.Text) }
    }
    Add-HTRowAction -Module $m -Text 'Eksportuj do pliku…' -Icon 'E74E' -Action {
        param($m, $rows)
        $t = @($rows)[0].__template
        if (-not $t) { return }
        $path = Select-HTSaveFile -Title 'Eksport szablonu' -Filter 'Pliki tekstowe (*.txt)|*.txt' -FileName "$((ConvertTo-HTSPUrlName -Title $t.Name)).txt" -DefaultExt '.txt'
        if (-not $path) { return }
        [System.IO.File]::WriteAllText($path, [string]$t.Text, (New-Object System.Text.UTF8Encoding($true)))
        Show-HTToast "Zapisano: $path" 'ok'
    }
    Add-HTRowAction -Module $m -Text 'Usuń szablon' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $saved = @($rows | Where-Object { $_.__template -and -not $_.__template.BuiltIn })
        if ($saved.Count -eq 0) { Show-HTWarning 'Szablonów wbudowanych nie można usunąć (zapisany szablon o tej samej nazwie je zastępuje).'; return }
        if (-not (Show-HTConfirm -Danger -Title 'Usuń szablon' -Message 'Usunąć zaznaczone szablony?' -Items @($saved | ForEach-Object { $_.Szablon }))) { return }
        foreach ($s in $saved) { Remove-HTSPStructureTemplate -Name $s.Szablon }
        Invoke-HTModulePrimary $m
    }
}
#endregion

#region Uprawnienia: witryna i administratorzy, dostęp użytkownika
Register-HTModule -Workspace 'SharePoint' -Category 'Uprawnienia' -Key 'sp.siteperms' -Title 'Uprawnienia witryny' -Icon 'E83D' -Service 'SharePoint' `
    -Description 'Uprawnienia do całej witryny (osoby, grupy SharePoint i grupy zabezpieczeń) i administratorzy kolekcji witryn: nadawanie, odbieranie (prawy przycisk) i dodawanie administratorów. Wyróżnione - dostęp dla wszystkich i administratorzy.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż uprawnienia' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Uprawnienia witryny' -ScriptBlock {
            foreach ($a in @(Get-HTSPWebPermissions)) {
                [PSCustomObject]@{ Rodzaj = 'Uprawnienia witryny'; Podmiot = $a.Principal; Typ = $a.PrincipalType; Uprawnienia = $a.Roles; Login = $a.LoginName; __assignment = $a; __kind = 'Web'; __flag = $(if ("$($a.LoginName)" -match 'spo-grid-all-users|Everyone|Wszyscy') { 'warn' } else { '' }) }
            }
            try {
                foreach ($a in @(Get-HTSPSiteAdmins)) { [PSCustomObject]@{ Rodzaj = 'Administrator kolekcji'; Podmiot = $a.Principal; Typ = $a.PrincipalType; Uprawnienia = 'administrator (pełny dostęp)'; Login = $a.LoginName; __assignment = $a; __kind = 'Admin'; __flag = 'warn' } }
            }
            catch { [PSCustomObject]@{ Rodzaj = 'Administrator kolekcji'; Podmiot = '(brak uprawnień do odczytu)'; Typ = ''; Uprawnienia = $_.Exception.Message; Login = ''; __flag = 'muted' } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nadaj uprawnienia…' -Create -NoRowMenu -Icon 'E8FA' -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'SharePoint')) { return }
        Set-HTBusy -Busy $true -Text 'Poziomy uprawnień i grupy…'
        try { $roles = @(Get-HTSPRoleDefinitions); $groups = @(Get-HTSPGroups | ForEach-Object { $_.Title }) }
        catch { Set-HTBusy -Busy $false -Text 'Błąd'; Show-HTError 'Nie odczytano poziomów uprawnień.' $_; return }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        $form = Show-HTFormDialog -Title 'Uprawnienia do witryny' -Icon 'E83D' -OkText 'Nadaj' -Width 640 -Fields @(
            @(Get-HTSPPrincipalFormFields -SharePointGroups $groups -Label 'Podmioty (kilka - średnik)')
            @{ Name = 'Role'; Label = 'Poziom uprawnień'; Type = 'Combo'; Options = $roles }
        )
        if (-not $form) { return }
        try { $resolved = Resolve-HTSPFormPrincipals -Form $form } catch { Show-HTWarning $_.Exception.Message -Title 'Uprawnienia do witryny'; return }
        $type = $resolved.Type
        Invoke-HTRowAction -Module $m -Name 'Uprawnienia do witryny' -Rows @($resolved.Items) -Label { param($p) $p.Name } -Action { param($p) Grant-HTSPWebPermission -Principal $p.Login -PrincipalType $type -Role $form.Role; $form.Role } -Refresh { param($m) Invoke-HTModulePrimary $m }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Dodaj administratora kolekcji…' -Create -NoRowMenu -Icon 'E7EF' -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'SharePoint')) { return }
        $users = @(Split-HTInputList (Show-InputBox -Title 'Administrator kolekcji witryn' -Prompt 'Adresy e-mail (jeden w linii). Administrator ma pełny dostęp do całej witryny i jej podwitryn:' -Multiline -Icon 'E7EF'))
        if ($users.Count -eq 0) { return }
        Invoke-HTRowAction -Module $m -Name 'Dodanie administratora kolekcji' -Rows $users -Label { param($u) $u } -Confirm 'Nadać uprawnienia administratora kolekcji witryn?' -Action { param($u) Add-HTSPSiteAdmin -Users @($u); 'Dodano' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Odbierz' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Odebranie uprawnień witryny' -Rows @($rows | Where-Object { $_.__kind }) -Danger -Confirm 'Odebrać zaznaczone uprawnienia do witryny (albo rolę administratora kolekcji)?' -Label { param($r) "$($r.Rodzaj): $($r.Podmiot)" } -Action {
            param($r)
            if ($r.__kind -eq 'Admin') { Remove-HTSPSiteAdmin -User $r.Login; return 'Usunięto administratora' }
            Revoke-HTSPWebPermission -Assignment $r.__assignment
            "Odebrano: $($r.Uprawnienia)"
        } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'SharePoint' -Category 'Uprawnienia' -Key 'sp.useraccess' -Title 'Dostęp użytkownika' -Icon 'E716' -Service 'SharePoint' `
    -Description 'Gdzie w połączonej witrynie osoba ma dostęp: administrator kolekcji, grupy SharePoint, uprawnienia witryny oraz biblioteki i foldery z unikalnymi uprawnieniami - bezpośrednio albo przez grupę. Prawy przycisk - odebranie dostępu albo usunięcie z grupy (np. przy odejściu z firmy).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Osoba'
    $m.C.Login = Add-HTTextBox -Parent $row -Width 300 -Placeholder 'adres e-mail lub login'
    Add-HTLabel -Parent $row -Text 'Głębokość folderów:' | Out-Null
    $m.C.Depth = Add-HTNumeric -Parent $row -Value 2 -Minimum 0 -Maximum 10
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź dostęp' -Icon 'E721' -Primary -OnClick {
        param($m)
        $login = $m.C.Login.Text.Trim()
        if (-not $login) { Show-HTWarning 'Wpisz adres e-mail osoby.'; return }
        $depth = Get-HTNum $m.C.Depth
        $m.Data.Login = $login
        Invoke-HTQuery -Module $m -Name "Dostęp: $login" -ScriptBlock {
            $rows = @(Get-HTSPUserAccessReport -Login $login -Depth $depth -OnProgress { param($path) Set-HTStatus -Text "Sprawdzanie: $path"; Update-HTUi })
            if ($rows.Count -eq 0) { return [PSCustomObject]@{ Obiekt = '(brak dostępu w tej witrynie - poza ewentualnymi grupami Entra ID)'; __flag = 'muted' } }
            $rows
        }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Dostęp przez grupy Entra ID / Microsoft 365 nie jest rozwijany.' | Out-Null
    Add-HTRowAction -Module $m -Text 'Odbierz dostęp / usuń z grupy' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $login = [string]$m.Data.Login
        if (-not $login) { return }
        $sel = @($rows | Where-Object { $_.__kind })
        $groups = @($sel | Where-Object { $_.__group } | ForEach-Object { $_.__group } | Select-Object -Unique)
        $note = if ($groups.Count) { " Usunięcie z grup ($($groups -join ', ')) odbiera dostęp we wszystkich miejscach, w których grupa ma uprawnienia." } else { '' }
        Invoke-HTRowAction -Module $m -Name "Odebranie dostępu ($login)" -Rows $sel -Danger -Confirm "Odebrać osobie $login zaznaczony dostęp?$note" -Label { param($r) "$($r.Obiekt): $($r.Ścieżka) ($($r.Przez))" } -Action {
            param($r)
            if ($r.__group) { Remove-HTSPGroupMember -Group $r.__group -LoginName $login; return "Usunięto z grupy $($r.__group)" }
            switch ($r.__kind) {
                'Admin' { Remove-HTSPSiteAdmin -User ([string]$r.__assignment.LoginName); 'Usunięto administratora kolekcji' }
                'Web' { Revoke-HTSPWebPermission -Assignment $r.__assignment; 'Odebrano uprawnienia witryny' }
                'Node' { Remove-HTSPPrincipalAccess -Node $r.__node -Principal $login }
                default { throw 'Nieobsługiwany wiersz' }
            }
        } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Zawartość: wyewidencjonowane pliki, wyszukiwanie, kopiowanie i przenoszenie, wysyłanie z dysku
Register-HTModule -Workspace 'SharePoint' -Category 'Zawartość' -Key 'sp.checkedout' -Title 'Wyewidencjonowane pliki' -Icon 'E72E' -Service 'SharePoint' `
    -Description '«Plik jest zablokowany do edycji przez…» - pliki wyewidencjonowane w zaznaczonych bibliotekach / folderach i pliki bez zaewidencjonowanej wersji (widoczne tylko dla jednej osoby). Prawy przycisk: zaewidencjonuj, odrzuć wyewidencjonowanie, przejmij plik.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Szukaj wyewidencjonowanych' -Icon 'E721' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Wyewidencjonowane pliki' -Label { param($t) Get-HTSPNodeLabel $t } -Action {
            param($t)
            $files = @(Get-HTSPCheckedOutFiles -Node $t)
            if ($files.Count -eq 0) { return [PSCustomObject]@{ Plik = '(brak wyewidencjonowanych plików)'; __flag = 'muted' } }
            $files
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Zaewidencjonuj' -Icon 'E73E' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Zaewidencjonowanie pliku' -Rows @($rows | Where-Object { $_.__kind -eq 'CheckedOut' }) -Confirm 'Zaewidencjonować zaznaczone pliki (zmiany osoby, która je wyewidencjonowała, zostaną zapisane jako nowa wersja)?' -Label { param($r) $r.__url } `
            -Action { param($r) Submit-HTSPFileCheckIn -Url $r.__url; 'Zaewidencjonowano' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Odrzuć wyewidencjonowanie' -Icon 'E7A7' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Odrzucenie wyewidencjonowania' -Rows @($rows | Where-Object { $_.__kind -eq 'CheckedOut' }) -Danger -Confirm 'Odrzucić wyewidencjonowanie? Niezaewidencjonowane zmiany zostaną utracone - plik wróci do ostatniej wersji.' -Label { param($r) $r.__url } `
            -Action { param($r) Undo-HTSPFileCheckOut -Url $r.__url; 'Odrzucono' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Przejmij plik (bez wersji)' -Icon 'E8FB' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Przejęcie pliku' -Rows @($rows | Where-Object { $_.__kind -eq 'NoVersion' }) -Confirm 'Przejąć zaznaczone pliki? Potem możesz je zaewidencjonować, aby zobaczyli je inni.' -Label { param($r) $r.__url } `
            -Action { param($r) Invoke-HTSPCheckOutTakeover -ListTitle $r.__list -Url $r.__url; 'Przejęto - teraz zaewidencjonuj' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'SharePoint' -Category 'Zawartość' -Key 'sp.find' -Title 'Wyszukiwanie plików' -Icon 'E721' -Service 'SharePoint' `
    -Description 'Pliki po nazwie (fragment albo wzorzec z * i ?) w zaznaczonych bibliotekach / folderach - także w dużych bibliotekach. Prawy przycisk: otwarcie, kopiowanie linku, kopiowanie i przenoszenie.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Nazwa'
    $m.C.Pattern = Add-HTTextBox -Parent $row -Width 300 -Placeholder 'np. umowa, *.pdf, raport_202?_*'
    $m.C.All = Add-HTCheckBox -Parent $row -Text 'We wszystkich bibliotekach'
    Add-HTButton -Parent $row -Module $m -Text 'Szukaj' -Icon 'E721' -Primary -OnClick {
        param($m)
        $pattern = $m.C.Pattern.Text.Trim()
        if (-not $pattern) { Show-HTWarning 'Wpisz fragment nazwy pliku.'; return }
        if (-not (Assert-HTConnection -Service 'SharePoint')) { return }
        $targets = if (Test-HTChecked $m.C.All) { @(Get-HTSPLibraries) } else { @(Get-HTTargets -Module $m) }
        if ($targets.Count -eq 0) { return }
        Invoke-HTTargetQuery -Module $m -Name "Pliki: $pattern" -Targets $targets -Label { param($t) Get-HTSPNodeLabel $t } -Action { param($t) Find-HTSPFiles -Node $t -Pattern $pattern }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Otwórz w przeglądarce' -Icon 'E8A7' -Action { param($m, $rows) foreach ($r in @($rows | Where-Object { $_.ServerRelativeUrl } | Select-Object -First 5)) { Start-Process (Get-HTSPAbsoluteUrl -ServerRelativeUrl $r.ServerRelativeUrl) } }
    Add-HTRowAction -Module $m -Text 'Kopiuj link' -Icon 'E71B' -Action {
        param($m, $rows)
        $links = @($rows | Where-Object { $_.ServerRelativeUrl } | ForEach-Object { Get-HTSPAbsoluteUrl -ServerRelativeUrl $_.ServerRelativeUrl })
        if ($links) { Set-HTClipboard ($links -join "`r`n"); Show-HTToast "Skopiowano linków: $($links.Count)." 'ok' }
    }
    Add-HTRowAction -Module $m -Text 'Kopiuj / przenieś do…' -Icon 'E8C8' -Action {
        param($m, $rows)
        Invoke-HTSPCopyInteractive -Module $m -Items @($rows | Where-Object { $_.ServerRelativeUrl } | ForEach-Object { @{ Label = $_.Nazwa; Url = $_.ServerRelativeUrl } })
    }
}

Register-HTModule -Workspace 'SharePoint' -Category 'Zawartość' -Key 'sp.copymove' -Title 'Kopiuj lub przenieś foldery' -Icon 'E8C8' -Service 'SharePoint' `
    -Description 'Kopiowanie albo przenoszenie zaznaczonych folderów (z zawartością i historią wersji) do innej biblioteki, folderu albo witryny tego tenantu - np. archiwizacja zakończonych projektów. Pliki - prawy przycisk w modułach «Pliki» i «Wyszukiwanie plików».' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Kopiuj / przenieś zaznaczone…' -Icon 'E8C8' -Primary -Create -NoRowMenu -OnClick {
        param($m)
        $folders = @(Get-HTTargets -Module $m | Where-Object { -not $_.IsLibrary })
        if ($folders.Count -eq 0) { Show-HTWarning 'Zaznacz foldery w drzewie po lewej (całe biblioteki kopiuje się przez «Struktura folderów» albo narzędzia migracji).'; return }
        Invoke-HTSPCopyInteractive -Module $m -Items @($folders | ForEach-Object { @{ Label = $_.ServerRelativeUrl; Url = $_.ServerRelativeUrl } })
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Duże foldery kopiują się w tle po stronie SharePoint (do kilku minut).' | Out-Null
}

Register-HTModule -Workspace 'SharePoint' -Category 'Zawartość' -Key 'sp.upload' -Title 'Wyślij folder z dysku' -Icon 'E898' -Service 'SharePoint' `
    -Description 'Wysłanie folderu z komputera (z podfolderami i plikami) do zaznaczonej biblioteki lub folderu - np. przeniesienie danych działu z dysku sieciowego. Nazwy niedozwolone w SharePoint są zgłaszane, istniejące pliki można pominąć.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.Skip = Add-HTCheckBox -Parent $row -Text 'Pomiń pliki, które już są w SharePoint' -Checked $true
    Add-HTButton -Parent $row -Module $m -Text 'Wybierz folder i wyślij…' -Icon 'E898' -Primary -Create -NoRowMenu -OnClick {
        param($m)
        $target = @(Get-HTTargets -Module $m -Single)[0]
        if (-not $target) { return }
        if (-not (Assert-HTConnection -Service 'SharePoint')) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Wysyłanie plików')) { return }
        $local = Select-HTFolder -Title 'Folder do wysłania do SharePoint'
        if (-not $local) { return }
        $files = @(Get-ChildItem -LiteralPath $local -Recurse -File -ErrorAction SilentlyContinue)
        $size = ($files | Measure-Object -Property Length -Sum).Sum
        if (-not (Show-HTConfirm -Title 'Wyślij folder' -ConfirmText 'Wyślij' -Message "Wysłać folder $local ($($files.Count) plików, $(Format-HTBytes $size)) do $($target.ServerRelativeUrl)?")) { return }
        $skip = Test-HTChecked $m.C.Skip
        Invoke-HTQuery -Module $m -Name "Wysyłanie: $(Split-Path $local -Leaf)" -Record None -ScriptBlock {
            Send-HTSPLocalFolder -LocalPath $local -TargetNode $target -SkipExisting:$skip -OnProgress { param($i, $total, $name) Set-HTProgress -Value $i -Maximum $total -Text "Wysyłanie [$i/$total] $name" }
        }
        Add-HTOperationRecord -Operation 'Wysłanie folderu z dysku' -Object "$local -> $($target.ServerRelativeUrl)" -Details "plików: $($files.Count)" -Module $m.Title
        Show-HTToast 'Wysyłanie zakończone - szczegóły w tabeli.' 'ok'
    } | Out-Null
}
#endregion

#region Witryna: nowa witryna
$script:NewSiteDescription = 'Nowa witryna zespołu (z grupą Microsoft 365, gotowa do Teams), witryna zespołu bez grupy albo witryna komunikacyjna: nazwa, adres, właściciele, język, prywatność. Od razu można połączyć się z nią i zastosować szablon struktury (biblioteki, foldery, uprawnienia).'
$script:NewSiteBuild = {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz witrynę…' -Create -NoRowMenu -Icon 'E710' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'SharePoint')) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Nowa witryna')) { return }
        $types = [ordered]@{ 'Witryna zespołu (z grupą Microsoft 365)' = 'Team'; 'Witryna zespołu bez grupy' = 'TeamNoGroup'; 'Witryna komunikacyjna' = 'Communication' }
        $languages = [ordered]@{ 'Polski' = 1045; 'English' = 1033; 'Deutsch' = 1031 }
        $none = '(bez szablonu)'
        $templates = @($none) + @(Get-HTSPStructureTemplates | ForEach-Object { $_.Name })
        $prev = @{}
        $get = { param($k, $d) if ($prev.Contains($k)) { $prev[$k] } else { $d } }
        while ($true) {
            $form = Show-HTFormDialog -Title 'Nowa witryna' -Icon 'E774' -OkText 'Utwórz' -Width 660 -MaxHeight 640 -Fields @(
                @{ Name = 'Type'; Label = 'Rodzaj'; Type = 'Combo'; Options = @($types.Keys); Default = (& $get 'Type' @($types.Keys)[0]) }
                @{ Name = 'Title'; Label = 'Nazwa'; Required = $true; Default = (& $get 'Title' '') }
                @{ Name = 'Alias'; Label = 'Adres (…/sites/<adres>; puste - z nazwy)'; Default = (& $get 'Alias' '') }
                @{ Name = 'Description'; Label = 'Opis (tylko witryna zespołu z grupą Microsoft 365)'; Default = (& $get 'Description' '') }
                @{ Name = 'Owners'; Label = 'Właściciele (adresy, jeden w linii; komunikacyjna - pierwszy)'; Type = 'Multiline'; Height = 50; Default = (& $get 'Owners' '') }
                @{ Name = 'Public'; Label = 'Publiczna (każdy w organizacji może dołączyć) - tylko z grupą Microsoft 365'; Type = 'Check'; Default = (& $get 'Public' $false) }
                @{ Name = 'Language'; Label = 'Język witryny (nie można go później zmienić)'; Type = 'Combo'; Options = @($languages.Keys); Default = (& $get 'Language' 'Polski') }
                @{ Type = 'Header'; Label = 'Po utworzeniu' }
                @{ Name = 'Connect'; Label = 'Połącz z nową witryną'; Type = 'Check'; Default = (& $get 'Connect' $true) }
                @{ Name = 'Template'; Label = 'Szablon struktury (wymaga połączenia)'; Type = 'Combo'; Options = $templates; Default = (& $get 'Template' $none) }
                @{ Name = 'Where'; Label = 'Gdzie zastosować szablon'; Type = 'Combo'; Options = @('W bibliotece domyślnej (Dokumenty)', 'W witrynie (1. poziom - biblioteki)'); Default = (& $get 'Where' 'W bibliotece domyślnej (Dokumenty)') }
            )
            if (-not $form) { return }
            $prev = $form
            $alias = if (([string]$form.Alias).Trim()) { ([string]$form.Alias).Trim() } else { ConvertTo-HTSPUrlName -Title $form.Title }
            if ($alias -match '^[A-Za-z0-9][A-Za-z0-9\-_]*$') { break }
            Show-HTWarning "Adres «$alias» może zawierać tylko litery bez polskich znaków, cyfry, myślnik i podkreślenie."
        }
        $type = $types[$form.Type]
        $lcid = $languages[$form.Language]
        $owners = @(Split-HTInputList $form.Owners)
        if (-not (Confirm-HTChange -Name 'Nowa witryna' -Labels @("/sites/$alias") -Confirm "Utworzyć witrynę «$($form.Title)» ($($form.Type)) pod adresem /sites/$($alias)? Tworzenie trwa do kilku minut.")) { return }
        Reset-HTResults -Module $m
        Set-HTBusy -Busy $true -Text "Tworzenie witryny $($form.Title)… (do kilku minut)"
        try { $url = New-HTSPSite -Type $type -Title $form.Title -Alias $alias -Description ([string]$form.Description) -Owners $owners -IsPublic ([bool]$form.Public) -Lcid $lcid }
        catch {
            Set-HTBusy -Busy $false -Text 'Błąd'
            Add-HTOperationRecord -Operation 'Nowa witryna' -Object $alias -Status 'Błąd' -Details $_.Exception.Message -Module $m.Title
            Show-HTError 'Nie utworzono witryny.' $_
            return
        }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        Add-HTOperationRecord -Operation 'Nowa witryna' -Object $url -Details "$($form.Type), właściciele: $($owners -join ', ')" -Module $m.Title
        Write-Log -Message "Utworzono witrynę $url" -Type 'Info&Notification'
        Show-HTToast "Utworzono witrynę: $url" 'ok' 8
        Add-HTResultRows -Module $m -Objects @([PSCustomObject]@{ Witryna = $form.Title; Adres = $url; Rodzaj = $form.Type; Status = 'Utworzono'; Szczegóły = '' })
        if (-not $form.Connect) { return }
        if (-not (Connect-Module -Name 'PnP.PowerShell' -SiteUrl $url -NoPrompt)) { return }
        Clear-HTPanelItems -Service 'SharePoint'
        $p = Get-HTPanel 'spTree'
        if ($p) { Invoke-HTPanelLoad -Panel $p -Quiet }
        if ($form.Template -eq $none) { return }
        $t = @(Get-HTSPStructureTemplates | Where-Object { $_.Name -eq $form.Template })[0]
        $parsed = ConvertFrom-HTSPStructureText -Text ([string]$t.Text)
        if (@($parsed.Errors).Count) { Show-HTWarning "Szablon «$($form.Template)» ma błędy - nie zastosowano."; return }
        $siteMode = $form.Where -like 'W witrynie*'
        $targets = @()
        if (-not $siteMode) {
            $default = @(Get-HTSPLibraries | Sort-Object @{ Expression = { -not ([string]$_.ServerRelativeUrl -match '/Shared Documents$') } })[0]
            if (-not $default) { Show-HTWarning 'Nie znaleziono biblioteki dokumentów w nowej witrynie.'; return }
            $targets = @($default)
        }
        Invoke-HTSPStructureRun -Module $m -Pending @{ Items = @($parsed.Items); Targets = $targets; SiteMode = $siteMode }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Wymaga połączenia SharePoint (dowolna witryna tenanta) i uprawnień do tworzenia witryn (domyślnie mają je użytkownicy; administrator może to ograniczyć).' | Out-Null
}
Register-HTModule -Workspace 'SharePoint' -Category 'Witryna' -Key 'sp.newsite' -Title 'Nowa witryna' -Icon 'E774' -Service 'SharePoint' -Description $script:NewSiteDescription -Build $script:NewSiteBuild
# Ta sama funkcja w Organizacja > Tworzenie (tworzenie nie dotyczy wybranej witryny)
Register-HTModule -Workspace 'Organization' -Category 'Tworzenie' -Key 'org.newsite' -Title 'Nowa witryna SharePoint' -Icon 'E774' -Service 'SharePoint' -Description $script:NewSiteDescription -Build $script:NewSiteBuild
#endregion
