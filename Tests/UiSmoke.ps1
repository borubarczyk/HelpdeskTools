<#
    Test interfejsu (Windows, pwsh -STA): ładuje moduły i pliki GUI jak HelpdeskTools.ps1, buduje okno główne, wszystkie
    przestrzenie robocze i moduły (bez połączeń z usługami) oraz paletę poleceń. Błędem jest wyjątek, wpis «Error»
    w dzienniku albo okno dialogowe otwarte w czasie budowy modułu (np. komunikat o błędzie).
    Uruchomienie: pwsh -STA -NoProfile -File Tests/UiSmoke.ps1
#>
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { Write-Host 'Test interfejsu wymaga Windows - pominięto.'; return }
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) { throw 'Uruchom w trybie STA: pwsh -STA -File Tests/UiSmoke.ps1' }
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('HelpdeskToolsSmoke_' + [guid]::NewGuid().ToString('N'))
$Global:ConfigDir = Join-Path $temp 'config'
$Global:LogDir = Join-Path $temp 'logs'
$Global:ConfigPath = Join-Path $Global:ConfigDir 'config.json'
$Global:AppVersion = '0.0.0'
$Global:HTScriptPath = Join-Path $root 'HelpdeskTools.ps1'
$Global:IconsPath = Join-Path $root 'Resources/Icons'
$Global:AppIconPath = Join-Path $Global:IconsPath 'Tools.ico'
$Global:ShowNotifications = $false
$Global:ShowOnPremises = $true
$Global:ConnectedToExchange = $false
$Global:ConnectedToGraphAPI = $false
$Global:ConnectedToSharepointPnP = $false
New-Item -ItemType Directory -Path $Global:ConfigDir, $Global:LogDir -Force | Out-Null

# Listy modułów i plików GUI z HelpdeskTools.ps1 (jedno źródło prawdy)
$main = [System.IO.File]::ReadAllText($Global:HTScriptPath)
$moduleBlock = [regex]::Match($main, '(?s)\$moduleNames = @\((.*?)\)').Groups[1].Value
$guiBlock = [regex]::Match($main, '(?s)\$guiFiles = @\((.*?)\)').Groups[1].Value
$moduleNames = @([regex]::Matches($moduleBlock, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$guiFiles = @([regex]::Matches($guiBlock, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }) + @('GUI/Workspaces/ActiveDirectory.ps1')
if ($moduleNames.Count -lt 10 -or $guiFiles.Count -lt 5) { throw 'Nie odczytano list modułów z HelpdeskTools.ps1.' }

foreach ($name in $moduleNames) { Import-Module (Join-Path $root "Modules/$name.psm1") -Force -Global -DisableNameChecking }
$Global:HTConfig = (Merge-HTConfig -Config $null).Config
Apply-HTConfig -Config $Global:HTConfig

$Global:SmokeErrors = New-Object System.Collections.Generic.List[string]
$Global:SmokeDialogs = New-Object System.Collections.Generic.List[string]
Register-HTLogSink -ScriptBlock { param($entry) if ($entry.Type -eq 'Error') { $Global:SmokeErrors.Add([string]$entry.Message) } }

# Okna dialogowe w czasie testu są zamykane od razu (i zgłaszane jako błąd)
$closer = [System.Windows.RoutedEventHandler] {
    param($s, $e)
    if ($HT_UI -and [object]::ReferenceEquals($s, $HT_UI.Window)) { return }
    $sections = $s.FindName('fmNav')
    $Global:SmokeDialogs.Add("$($s.Title): $((@($s.FindName('dlgSubtitle'), $s.FindName('msgText')) | Where-Object { $_ } | ForEach-Object { $_.Text }) -join ' ')$(if ($sections) { " [sekcje: $($sections.Children.Count)]" })")
    $window = $s
    [void]$window.Dispatcher.BeginInvoke([action] { try { $window.DialogResult = $false } catch { $window.Close() } }.GetNewClosure())
}
[System.Windows.EventManager]::RegisterClassHandler([System.Windows.Window], [System.Windows.FrameworkElement]::LoadedEvent, $closer)

foreach ($file in $guiFiles) { . (Join-Path $root $file) }

$failures = New-Object System.Collections.Generic.List[string]
$window = New-HTMainWindow
foreach ($p in $HT_UI.Panels.Values) { [void]$HT_UI.Controls.targetHost.Children.Add($p.Root) }
Initialize-HTNavigation

$built = 0
foreach ($ws in @($HT_UI.Workspaces.Keys)) {
    try { Show-HTWorkspace -Key $ws } catch { $failures.Add("Przestrzeń ${ws}: $($_.Exception.Message)") }
    foreach ($d in @($HT_UI.ModuleDefs | Where-Object { $_.Workspace -eq $ws })) {
        $errorsBefore = $Global:SmokeErrors.Count
        $dialogsBefore = $Global:SmokeDialogs.Count
        try {
            Show-HTModule -Key $d.Key
            $built++
        }
        catch { $failures.Add("Moduł $($d.Key): $($_.Exception.Message)") }
        # Zdarzenia okna (zamknięcie dialogów) przed sprawdzeniem
        $frame = New-Object System.Windows.Threading.DispatcherFrame
        [void][System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Windows.Threading.DispatcherOperationCallback] { param($f) $f.Continue = $false; $null }, $frame)
        [System.Windows.Threading.Dispatcher]::PushFrame($frame)
        for ($i = $errorsBefore; $i -lt $Global:SmokeErrors.Count; $i++) { $failures.Add("Moduł $($d.Key) - dziennik: $($Global:SmokeErrors[$i])") }
        for ($i = $dialogsBefore; $i -lt $Global:SmokeDialogs.Count; $i++) { $failures.Add("Moduł $($d.Key) - okno: $($Global:SmokeDialogs[$i])") }
    }
}

# Okna otwierane na żądanie: Ustawienia (formularz z sekcjami) i paleta poleceń - mają się zbudować bez błędów
foreach ($dialog in @(
        @{ Name = 'Ustawienia'; Open = { [void](Show-HTSettingsDialog) }; Expect = '[sekcje: 9]' }
        @{ Name = 'Paleta poleceń'; Open = { Show-HTCommandPalette }; Expect = '' }
        # Okna z listą (DataTable z New-HTDataTable) - wcześniej błąd «new» przy niepustych danych
        @{ Name = 'Podgląd danych'; Open = { Show-HTDataViewer -Title 'Podgląd danych' -Data @([PSCustomObject]@{ Pole = 'A'; Wartość = 1 }, [PSCustomObject]@{ Pole = 'B'; Wartość = 2 }) }; Expect = '' }
        @{ Name = 'Wybór z listy'; Open = { [void](Show-HTSelectionDialog -Title 'Wybór z listy' -Items @([PSCustomObject]@{ DisplayName = 'Grupa A' }) -Columns @(@{ Text = 'Nazwa'; Property = 'DisplayName' })) }; Expect = '' }
        @{ Name = 'Szczegóły wiersza'; Open = {
                $m = $HT_UI.ActiveModule
                Reset-HTResults -Module $m
                Add-HTResultRows -Module $m -Objects @([PSCustomObject]@{ Obiekt = 'a@firma.pl'; Status = 'OK'; Szczegóły = "Pierwsza linia`nDruga linia" })
                Show-HTRowDetails -Module $m -Row $m.View[0]
            }; Expect = ''
        }
        @{ Name = 'Wybór opcji'; Open = { [void](Show-HTChoiceDialog -Title 'Wybór opcji' -Choices @(@{ Key = 'a'; Text = 'Konto organizacji'; Description = 'Logowanie interaktywne'; Icon = 'E77B' }, @{ Key = 'b'; Text = 'Import z pliku…'; Icon = 'E8B5' })) }; Expect = '' }
        @{ Name = 'Podsumowanie do zgłoszenia'; Open = { Add-HTOperationRecord -Kind Check -Operation 'Uprawnienia witryny' -Object 'https://firma.sharepoint.com/sites/A' -Details 'wyników: 3'; Add-HTOperationRecord -Operation 'Nadanie uprawnień' -Object 'jan@firma.pl'; Show-HTOperationSummaryDialog }; Expect = '' }
        @{ Name = 'Dane do zgłoszenia problemu'; Open = { Show-HTSupportDialog }; Expect = '' }
        @{ Name = 'Kreator reguł (warunki)'; Open = { [void](Show-HTDynamicFilterBuilder -Title 'Kreator reguł (warunki)' -Filter "(RecipientTypeDetails -eq 'UserMailbox') -and ((Department -eq 'IT') -or (City -like 'Warsz*'))") }; Expect = '' }
        @{ Name = 'Kreator reguł (ręcznie)'; Open = { [void](Show-HTDynamicFilterBuilder -Title 'Kreator reguł (ręcznie)' -Filter "((Department -eq 'IT') -and ((City -eq 'A') -or (City -eq 'B')))") }; Expect = '' }
        @{ Name = 'Potwierdzenie zmiany'; Open = { [void](Confirm-HTChange -Name 'Potwierdzenie zmiany' -Labels @('a@firma.pl', 'b@firma.pl') -Summary @('Tryb: Enabled')) }; Expect = '' }
    )) {
    $errorsBefore = $Global:SmokeErrors.Count
    $dialogsBefore = $Global:SmokeDialogs.Count
    try { & $dialog.Open } catch { $failures.Add("$($dialog.Name): $($_.Exception.Message)") }
    if ($Global:SmokeDialogs.Count -ne $dialogsBefore + 1) { $failures.Add("$($dialog.Name): okno nie zostało otwarte") }
    elseif ($dialog.Expect -and $Global:SmokeDialogs[$dialogsBefore] -notlike "*$($dialog.Expect)*") { $failures.Add("$($dialog.Name): oczekiwano $($dialog.Expect), jest: $($Global:SmokeDialogs[$dialogsBefore])") }
    for ($i = $errorsBefore; $i -lt $Global:SmokeErrors.Count; $i++) { $failures.Add("$($dialog.Name) - dziennik: $($Global:SmokeErrors[$i])") }
}

# Przełączniki nad tabelą wyników: podświetlenie, gdy włączone (panel szczegółów, ukryte kolumny, zapisany widok)
try {
    $m = $HT_UI.ActiveModule
    $v = $m.View_
    $detailBefore = $HT_UI.DetailVisible
    $HT_UI.DetailVisible = $true; Update-HTDetailPane -Module $m
    if ($v.btnDetail.Tag -ne 'on') { $failures.Add('Panel szczegółów: przycisk nie jest podświetlony po włączeniu.') }
    $HT_UI.DetailVisible = $false; Update-HTDetailPane -Module $m
    if ($v.btnDetail.Tag) { $failures.Add('Panel szczegółów: przycisk podświetlony po wyłączeniu.') }
    $HT_UI.DetailVisible = $detailBefore; Update-HTDetailPane -Module $m
    Set-HTFilterPresetView -Module $m -Preset @{ Name = 'Test'; Text = 'a@'; Filters = @(); Hidden = @('Status') }
    if ($v.btnColumns.Tag -ne 'on') { $failures.Add('Kolumny: przycisk nie jest podświetlony przy ukrytej kolumnie.') }
    if ($v.btnViews.Tag -ne 'on') { $failures.Add('Zapisane widoki: przycisk nie jest podświetlony po wybraniu widoku.') }
    $m.FilterBox.Text = 'inny'; Update-HTResultFilter -Module $m
    if ($v.btnViews.Tag) { $failures.Add('Zapisane widoki: przycisk podświetlony po ręcznej zmianie filtra.') }
    Set-HTFilterPresetView -Module $m -Preset @{ Name = 'domyślny'; Text = ''; Filters = @(); Hidden = @() }
    if ($v.btnColumns.Tag -or $v.btnViews.Tag) { $failures.Add('Kolumny / widoki: przyciski podświetlone po wyczyszczeniu widoku.') }
}
catch { $failures.Add("Przełączniki nad tabelą: $($_.Exception.Message)") }

# Lista edytowalna (wybór z listy albo własny tekst): wybrana wartość widoczna w polu tekstowym
try {
    $probe = New-HTUiElement -Xaml '<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"><ComboBox x:Name="cb" IsEditable="True" Width="200"/></Grid>'
    $cb = $probe.FindName('cb')
    foreach ($i in 'firma.pl', 'firma.onmicrosoft.com') { [void]$cb.Items.Add($i) }
    [void]$cb.ApplyTemplate()
    $cb.SelectedIndex = 1
    $box = $cb.Template.FindName('PART_EditableTextBox', $cb)
    if (-not $box) { $failures.Add('Lista edytowalna: brak pola tekstowego w szablonie.') }
    elseif ($box.Text -ne 'firma.onmicrosoft.com' -or "$($box.Visibility)" -ne 'Visible') { $failures.Add("Lista edytowalna: pole pokazuje «$($box.Text)» ($($box.Visibility)) zamiast wybranej wartości.") }
}
catch { $failures.Add("Lista edytowalna: $($_.Exception.Message)") }

# Nowe przestrzenie: Organizacja (bez listy po lewej) i Grupy i zespoły (lista grup) z modułami przeniesionymi z Exchange i M365
foreach ($expected in @(@{ Ws = 'Organization'; Keys = @('org.newgroup', 'm365.new', 'exo.newmailbox', 'exo.transport', 'm365.reclaim', 'org.guest', 'org.newsite', 'org.domains', 'org.selftest') }, @{ Ws = 'Groups'; Keys = @('grp.members', 'grp.owners', 'grp.manage', 'm365.teams', 'exo.dyn', 'grp.licenses', 'grp.team') }, @{ Ws = 'SharePoint'; Keys = @('sp.newsite') })) {
    if (-not $HT_UI.Workspaces.Contains($expected.Ws)) { $failures.Add("Brak przestrzeni $($expected.Ws)."); continue }
    foreach ($k in $expected.Keys) { if ((Get-HTModuleDefinition $k).Workspace -ne $expected.Ws) { $failures.Add("Moduł $k nie jest w przestrzeni $($expected.Ws).") } }
}

# Autotest: wszystkie testy z rejestru i - bez połączeń - przebieg tylko testów lokalnych (reszta «Pominięto»)
try {
    $selfRows = @(Invoke-HTSelfTest -Tests @(Get-HTSelfTests -IncludeWrite -IncludeSlow) -Connected @{} -Context (New-HTSelfTestContext -Sleep { param($s) }))
    if ($selfRows.Count -lt 20) { $failures.Add("Autotest: za mało testów ($($selfRows.Count)).") }
    $badSkip = @($selfRows | Where-Object { $_.Usługa -ne 'Ten komputer' -and $_.Status -ne 'Pominięto' })
    if ($badSkip.Count) { $failures.Add("Autotest: testy usług bez połączenia nie zostały pominięte: $(@($badSkip | ForEach-Object Klucz) -join ', ').") }
    $localFail = @($selfRows | Where-Object { $_.Usługa -eq 'Ten komputer' -and $_.Status -eq 'Błąd' })
    if ($localFail.Count) { $failures.Add("Autotest: błędy testów lokalnych: $(@($localFail | ForEach-Object { "$($_.Klucz): $($_.Szczegóły)" }) -join '; ').") }
}
catch { $failures.Add("Autotest: $($_.Exception.Message)") }

# Kopiowanie tabeli (Ctrl+C) z nagłówkami: nazwa kolumny zamiast elementu nagłówka
try {
    $col = New-Object System.Windows.Controls.DataGridTextColumn
    $col.SortMemberPath = 'Status'
    $col.Header = New-HTColumnHeader -Module @{} -Name 'Status'
    $copyArgs = New-Object System.Windows.Controls.DataGridRowClipboardEventArgs($null, 0, 0, $true)
    $copyArgs.ClipboardRowContent.Add((New-Object System.Windows.Controls.DataGridClipboardCellContent($null, $col, $col.Header)))
    & (Get-Module UIComponents) { param($a) & $script:GridCopyEvents.CopyRow $null $a } $copyArgs
    if ([string]$copyArgs.ClipboardRowContent[0].Content -ne 'Status') { $failures.Add("Kopiowanie nagłówków: «$($copyArgs.ClipboardRowContent[0].Content)» zamiast «Status».") }
}
catch { $failures.Add("Kopiowanie nagłówków: $($_.Exception.Message)") }

# Pokrycie testami: każdy moduł opisany, moduły wskazane w testach zapisu istnieją
try {
    $coverage = @(Get-HTSelfTestCoverage -Modules @(Get-HTModuleCoverageInfo))
    if ($coverage.Count -ne @(Get-HTModuleDefinitions).Count) { $failures.Add("Pokrycie testami: $($coverage.Count) wierszy, modułów: $(@(Get-HTModuleDefinitions).Count).") }
    $keys = @(Get-HTModuleDefinitions | ForEach-Object { $_.Key })
    $unknown = @(Get-HTSelfTests -IncludeWrite -IncludeSlow | ForEach-Object { $t = $_; @($t.Modules) | Where-Object { $keys -notcontains $_ } | ForEach-Object { "$($t.Key): $_" } })
    if ($unknown.Count) { $failures.Add("Testy zapisu wskazują nieistniejące moduły: $($unknown -join ', ').") }
    Write-Host "Pokrycie testami: pełne $(@($coverage | Where-Object Pokrycie -eq 'pełne').Count), tylko odczyt $(@($coverage | Where-Object Pokrycie -eq 'tylko odczyt').Count), brak $(@($coverage | Where-Object Pokrycie -eq 'brak').Count)."
}
catch { $failures.Add("Pokrycie testami: $($_.Exception.Message)") }

# Przegląd wszystkich sekcji bez połączeń: moduły usług - pominięte, moduły bez usług - przycisk odczytu naprawdę
try {
    $sweep = @(Invoke-HTModuleSweep -ExcludeKeys @('sites.connect', 'org.selftest'))
    if ($sweep.Count -lt 100) { $failures.Add("Przegląd sekcji: tylko $($sweep.Count) modułów.") }
    foreach ($r in @($sweep | Where-Object { $_.Status -eq 'Błąd' })) { $failures.Add("Przegląd sekcji - $($r.Klucz): $($r.Szczegóły)") }
    if (Test-HTDialogCapture) { $failures.Add('Przegląd sekcji: tryb przechwytywania okien nie został wyłączony.') }
    Write-Host "Przegląd sekcji: $(Get-HTSelfTestSummary -Rows $sweep)"
    foreach ($r in @($sweep | Where-Object { $_.Status -in 'OK', 'Uwaga' })) { Write-Host "  $($r.Status): $($r.Klucz) - $($r.Szczegóły)" }
}
catch { $failures.Add("Przegląd sekcji: $($_.Exception.Message)") }

$palette = @(Get-HTPaletteItems -Query 'licencje')
if ($palette.Count -eq 0) { $failures.Add('Paleta poleceń: brak wyników dla «licencje».') }
if (@(Get-HTPaletteItems -Query '').Count -eq 0) { $failures.Add('Paleta poleceń: brak poleceń bez zapytania.') }

try { $window.Close() } catch { Write-Verbose $_ }
Close-HTBackground
Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Zbudowano modułów: $built w przestrzeniach: $($HT_UI.Workspaces.Count); paleta: $($palette.Count) wyników."
if ($failures.Count) {
    foreach ($f in $failures) { Write-Host "BŁĄD: $f" }
    exit 1
}
Write-Host 'Test interfejsu: OK'
