# Zapamiętane ustawienia interfejsu między uruchomieniami (plik UiState.json w katalogu konfiguracji):
# ulubione i ostatnio otwierane moduły, ostatni moduł w przestrzeniach, ukryte kolumny i zapisane widoki filtrów
# (filtr tekstowy, filtry kolumn, ukryte kolumny) dla modułów, położenie i rozmiar okna, wysokość dziennika.
# Moduł nie zależy od interfejsu - zapis i odczyt zwykłych wartości.

$script:UiState = $null
$script:RecentLimit = 12

function Get-HTUiStateFile {
    if (-not $Global:ConfigDir) { return $null }
    return (Join-Path $Global:ConfigDir 'UiState.json')
}

function New-HTUiStateDefault {
    return @{
        Favorites     = @()
        Recent        = @()
        LastWorkspace = ''
        LastModules   = @{}
        HiddenColumns = @{}
        ExtraColumns  = @{}
        FilterPresets = @{}
        Window        = @{}
        LogHeight     = 200
        DetailVisible = $true
    }
}

function Get-HTUiState {
    # Stan wczytywany raz (przy błędzie pliku - wartości domyślne, plik zostaje nadpisany przy najbliższym zapisie)
    param ([switch]$Reload)
    if ($script:UiState -and -not $Reload) { return $script:UiState }
    $state = New-HTUiStateDefault
    $path = Get-HTUiStateFile
    if ($path -and (Test-Path -LiteralPath $path)) {
        try {
            $raw = [System.IO.File]::ReadAllText($path)
            if ($raw.Trim()) {
                $loaded = ConvertFrom-Json -InputObject $raw -AsHashtable -ErrorAction Stop
                foreach ($k in @($loaded.Keys)) { if ($state.ContainsKey($k) -and $null -ne $loaded[$k]) { $state[$k] = $loaded[$k] } }
            }
        }
        catch { Write-Log -Message "Nie odczytano zapamiętanych ustawień interfejsu ($path): $($_.Exception.Message)" -Type "Warn" }
    }
    foreach ($k in 'Favorites', 'Recent') { $state[$k] = @($state[$k] | Where-Object { $_ } | ForEach-Object { [string]$_ }) }
    foreach ($k in 'LastModules', 'HiddenColumns', 'ExtraColumns', 'FilterPresets', 'Window') { if ($state[$k] -isnot [System.Collections.IDictionary]) { $state[$k] = @{} } }
    $script:UiState = $state
    return $state
}

function Save-HTUiState {
    $path = Get-HTUiStateFile
    if (-not $path -or -not $script:UiState) { return }
    try {
        $dir = Split-Path -Parent $path
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $tmp = $path + '.tmp'
        [System.IO.File]::WriteAllText($tmp, (ConvertTo-Json -InputObject $script:UiState -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $tmp -Destination $path -Force
    }
    catch { Write-Log -Message "Nie zapisano ustawień interfejsu: $($_.Exception.Message)" -Type "Warn" }
}

function Set-HTUiStateValue {
    param ([Parameter(Mandatory)][string]$Name, [AllowNull()][object]$Value, [switch]$NoSave)
    $state = Get-HTUiState
    $state[$Name] = $Value
    if (-not $NoSave) { Save-HTUiState }
}

#region Ulubione i ostatnio otwierane
function Test-HTFavoriteModule([string]$Key) { return (@((Get-HTUiState).Favorites) -contains $Key) }

function Set-HTFavoriteModule {
    param ([Parameter(Mandatory)][string]$Key, [bool]$Favorite = $true)
    $state = Get-HTUiState
    $list = @($state.Favorites | Where-Object { $_ -ne $Key })
    if ($Favorite) { $list += $Key }
    $state.Favorites = $list
    Save-HTUiState
}

# Zwinięte kategorie nawigacji (klucz: przestrzeń|kategoria)
function Test-HTNavCategoryCollapsed([string]$Key) { return (@((Get-HTUiState)['CollapsedCategories']) -contains $Key) }

function Set-HTNavCategoryCollapsed {
    param ([Parameter(Mandatory)][string]$Key, [bool]$Collapsed = $true)
    $state = Get-HTUiState
    $list = @(@($state['CollapsedCategories']) | Where-Object { $_ -and $_ -ne $Key })
    if ($Collapsed) { $list += $Key }
    $state['CollapsedCategories'] = $list
    Save-HTUiState
}

function Add-HTRecentModule {
    # Moduł na początek listy ostatnio otwieranych (bez zapisu przy każdym otwarciu tego samego modułu)
    param ([Parameter(Mandatory)][string]$Key, [string]$Workspace = '')
    $state = Get-HTUiState
    $changed = (@($state.Recent)[0] -ne $Key) -or ($Workspace -and [string]$state.LastModules[$Workspace] -ne $Key)
    $state.Recent = @(@($Key) + @($state.Recent | Where-Object { $_ -ne $Key }) | Select-Object -First $script:RecentLimit)
    if ($Workspace) {
        $state.LastModules[$Workspace] = $Key
        $state.LastWorkspace = $Workspace
    }
    if ($changed) { Save-HTUiState }
}
#endregion

#region Kolumny i widoki filtrów modułów
function Get-HTModuleHiddenColumns([string]$Key) {
    $h = (Get-HTUiState).HiddenColumns
    if ($h.Contains($Key)) { return @($h[$Key] | ForEach-Object { [string]$_ }) }
    return @()
}

# Dodatkowe kolumny z danymi modułu («Źródło|atrybut», ExtraColumns.psm1) - dopisywane po każdym odświeżeniu wyników
function Get-HTModuleExtraColumns([string]$Key) {
    $state = Get-HTUiState
    if (-not $state.Contains('ExtraColumns') -or -not $state['ExtraColumns']) { return @() }
    $h = $state['ExtraColumns']
    if ($h.Contains($Key)) { return @($h[$Key] | ForEach-Object { [string]$_ } | Where-Object { $_ }) }
    return @()
}

function Set-HTModuleExtraColumns {
    param ([Parameter(Mandatory)][string]$Key, [AllowEmptyCollection()][string[]]$Columns = @())
    $state = Get-HTUiState
    if (-not $state.Contains('ExtraColumns') -or $state['ExtraColumns'] -isnot [System.Collections.IDictionary]) { $state['ExtraColumns'] = @{} }
    $list = @($Columns | Where-Object { $_ } | Select-Object -Unique)
    if ($list.Count) { $state['ExtraColumns'][$Key] = $list } else { [void]$state['ExtraColumns'].Remove($Key) }
    Save-HTUiState
}

function Set-HTModuleHiddenColumns {
    param ([Parameter(Mandatory)][string]$Key, [string[]]$Columns = @())
    $h = (Get-HTUiState).HiddenColumns
    $list = @($Columns | Where-Object { $_ } | Select-Object -Unique)
    if ($list.Count) { $h[$Key] = $list } else { [void]$h.Remove($Key) }
    Save-HTUiState
}

function Get-HTFilterPresets([string]$Key) {
    # Zapisane widoki modułu: @{ Name; Text; Filters = @(@{ Column; Values; Op; Text }); Hidden = @() }
    $p = (Get-HTUiState).FilterPresets
    if ($p.Contains($Key)) { return @($p[$Key]) }
    return @()
}

function Save-HTFilterPreset {
    param ([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][hashtable]$Preset)
    if (-not $Preset.Name) { throw 'Podaj nazwę widoku.' }
    $p = (Get-HTUiState).FilterPresets
    $list = @(Get-HTFilterPresets $Key | Where-Object { $_.Name -ne $Preset.Name })
    $p[$Key] = @($list + @($Preset))
    Save-HTUiState
}

function Remove-HTFilterPreset {
    param ([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Name)
    $p = (Get-HTUiState).FilterPresets
    $list = @(Get-HTFilterPresets $Key | Where-Object { $_.Name -ne $Name })
    if ($list.Count) { $p[$Key] = $list } else { [void]$p.Remove($Key) }
    Save-HTUiState
}

function ConvertTo-HTFilterPreset {
    # Widok z bieżącego stanu modułu (filtr tekstowy, filtry kolumn, ukryte kolumny)
    param ([Parameter(Mandatory)][string]$Name, [string]$Text = '', [System.Collections.IDictionary]$ColumnFilters = @{}, [string[]]$Hidden = @())
    $filters = foreach ($col in @($ColumnFilters.Keys)) {
        $f = $ColumnFilters[$col]
        @{ Column = [string]$col; Values = $(if ($null -ne $f.Values) { @($f.Values | ForEach-Object { [string]$_ }) } else { $null }); Op = [string]$f.Op; Text = [string]$f.Text }
    }
    return @{ Name = $Name; Text = $Text; Filters = @($filters); Hidden = @($Hidden) }
}
#endregion
