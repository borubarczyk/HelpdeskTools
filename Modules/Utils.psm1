# Funkcje pomocnicze aplikacji Helpdesk Tools: dziennik, eksport do plików, walidacja i formatowanie wartości.
# Moduł nie zależy od interfejsu - powiadomienia (toasty) wyświetla odbiorca logów zarejestrowany przez GUI.

# Historia logów przechowywana w module (dostęp przez Get-HTLogHistory / Clear-HTLogHistory)
$script:LogHistory = [System.Collections.Generic.List[object]]::new()
# Lista funkcji (scriptblocków) wywoływanych po każdym wpisie logu (np. odświeżenie zakładki "Logi")
$script:LogSinks = [System.Collections.Generic.List[scriptblock]]::new()

function Compress-HTErrorText {
    <#
        Skraca bardzo długie komunikaty błędów do czytelnej długości - np. listę setek dozwolonych wartości z błędu walidacji
        parametru (ValidateSet, «does not belong to the set "…"») zastępuje kilkoma pierwszymi i liczbą wszystkich.
    #>
    param([AllowNull()][AllowEmptyString()][string]$Text, [int]$MaxLength = 1500)
    if (-not $Text) { return $Text }
    $result = [regex]::Replace($Text, '(?s)(the set|zestawu|zbioru) "([^"]{200,})"', {
            param($m)
            $all = @($m.Groups[2].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $top = @($all | Where-Object { $_ -notmatch '\.' })
            if (-not $top.Count) { $top = $all }
            '{0} "{1}, … (wartości: {2})"' -f $m.Groups[1].Value, (@($top | Select-Object -First 10) -join ', '), $all.Count
        })
    if ($result.Length -gt $MaxLength) { $result = $result.Substring(0, $MaxLength) + " … (skrócono z $($Text.Length) znaków)" }
    return $result
}

# Funkcja do logowania i zarządzania historią logów w aplikacji Helpdesk Tools
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet("Info", "Warn", "Warning", "Error", "Debug", "Info&Notification", "Warn&Notification", "Warning&Notification", "Error&Notification")]
        [string]$Type = "Info"
    )

    # Wpisy diagnostyczne tylko przy włączonym szczegółowym dzienniku (Ustawienia > Aplikacja)
    if ($Type -eq "Debug" -and -not $Global:DebugLogging) { return }
    # Długie komunikaty błędów (np. pełna lista dozwolonych wartości parametru) - skrócone, żeby dziennik był czytelny
    if ($Message.Length -gt 1500 -or $Message -match '(the set|zestawu|zbioru) "[^"]{200,}"') { $Message = Compress-HTErrorText -Text $Message -MaxLength 4000 }
    $level = switch -Wildcard ($Type) {
        "Info*" { "Info" }
        "Warn*" { "Warn" }
        "Error*" { "Error" }
        "Debug" { "Debug" }
    }
    $icon = switch ($level) {
        "Info" { "ℹ️" }
        "Warn" { "⚠️" }
        "Error" { "❌" }
        "Debug" { "🔧" }
    }

    # Notify: wpis ma być pokazany jako powiadomienie w oknie (o ile powiadomienia są włączone)
    # Account: konto MFA, które odblokowało program (puste - konto podstawowe albo program bez MFA)
    $entry = [PSCustomObject]@{
        Time    = Get-Date
        Type    = $level
        Message = "$icon $Message"
        Notify  = ($Type -like "*&Notification" -and $Global:ShowNotifications -ne $false)
        Account = [string]$Global:HTActiveAccount
    }

    $script:LogHistory.Add($entry)
    # W pliku dziennika konto MFA przy każdym wpisie (kto wykonał operację)
    $fileMessage = if ($entry.Account) { "[konto: $($entry.Account)] $($entry.Message)" } else { $entry.Message }
    Add-LogToFile -Message $fileMessage -Type $level

    foreach ($sink in @($script:LogSinks)) {
        try { & $sink $entry | Out-Null } catch { Write-Verbose "Błąd odbiorcy logów: $_" }
    }
}

# Wpis diagnostyczny (szczegółowy dziennik): zapytania Graph, kroki łączenia, moduły, stos błędów.
# Bez włączonego ustawienia DebugLogging nie robi nic (także nie buduje komunikatu, gdy podano -Message jako blok).
function Write-HTDebug {
    param ([Parameter(Mandatory, Position = 0)][object]$Message)
    if (-not $Global:DebugLogging) { return }
    $text = if ($Message -is [scriptblock]) { try { [string](& $Message) } catch { "(błąd budowania wpisu: $($_.Exception.Message))" } } else { [string]$Message }
    Write-Log -Message $text -Type 'Debug'
}

# Rejestracja funkcji wywoływanej po każdym wpisie logu (np. aktualizacja GUI)
function Register-HTLogSink {
    param ([Parameter(Mandatory)][scriptblock]$ScriptBlock)
    $script:LogSinks.Add($ScriptBlock)
}

# Usuwa wszystkich odbiorców logów (wątek w tle rejestruje własnego - przekazanie wpisów do okna)
function Clear-HTLogSinks {
    $script:LogSinks.Clear()
}

# Zwraca kopię historii logów
function Get-HTLogHistory {
    return @($script:LogHistory)
}

# Czyści historię logów w pamięci (plik logu pozostaje bez zmian)
function Clear-HTLogHistory {
    $script:LogHistory.Clear()
}

# Formatowanie pojedynczego wpisu logu
function Format-HTLogEntry {
    param ([Parameter(Mandatory)][object]$Entry)
    $time = if ($Entry.Time -is [datetime]) { $Entry.Time.ToString("yyyy-MM-dd HH:mm:ss") } else { "$($Entry.Time)" }
    return "$time [$($Entry.Type)] $($Entry.Message)"
}

# Sprawdza, czy wpis logu pasuje do filtra tekstowego i typu
function Test-HTLogEntryMatch {
    param (
        [Parameter(Mandatory)][object]$Entry,
        [string]$FilterText,
        [string]$FilterType = "Wszystkie"
    )
    if ($FilterType -and $FilterType -ne "Wszystkie" -and $Entry.Type -ne $FilterType) { return $false }
    if ($FilterText -and $Entry.Message.IndexOf($FilterText, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
    return $true
}

# Czy w folderze można zapisać plik (folder tworzony w razie potrzeby). Folder w OneDrive z plikami tylko w chmurze
# przy wyłączonym OneDrive nie przyjmuje zapisu («Dostawca plików w chmurze nie jest uruchomiony»).
function Test-HTWritableDirectory {
    param ([AllowEmptyString()][string]$Path)
    if (-not $Path) { return $false }
    try {
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null }
        $probe = Join-Path $Path (".ht_{0}.tmp" -f [guid]::NewGuid().ToString('N'))
        [System.IO.File]::WriteAllText($probe, '')
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch { return $false }
}

$script:ExportDirectoryChecked = @{}

# Domyślny katalog eksportu: ustawienie ExportPath albo Dokumenty\HelpdeskTools\Eksport; gdy nie da się w nim zapisać
# (np. Dokumenty w OneDrive bez działającego OneDrive) - %LOCALAPPDATA%\HelpdeskTools\Eksport
function Get-HTExportDirectory {
    $documents = [Environment]::GetFolderPath("MyDocuments")
    $path = if ($Global:ExportPath) { $Global:ExportPath }
    elseif ($documents) { Join-Path $documents "HelpdeskTools\Eksport" }
    elseif ($Global:ConfigDir) { Join-Path $Global:ConfigDir "Exports" }
    else { [System.IO.Path]::GetTempPath() }

    if (-not $script:ExportDirectoryChecked.ContainsKey($path)) {
        $script:ExportDirectoryChecked[$path] = Test-HTWritableDirectory -Path $path
        if (-not $script:ExportDirectoryChecked[$path]) { Write-Log -Message "Nie można zapisać plików w $path (np. folder OneDrive bez działającego OneDrive) - eksport do folderu lokalnego." -Type 'Warn' }
    }
    if ($script:ExportDirectoryChecked[$path]) {
        # Folder mógł zostać usunięty w trakcie pracy programu
        if (-not (Test-Path -LiteralPath $path)) { try { New-Item -ItemType Directory -Path $path -Force -ErrorAction Stop | Out-Null } catch { $script:ExportDirectoryChecked.Remove($path) } }
        if ($script:ExportDirectoryChecked.ContainsKey($path)) { return $path }
    }
    $local = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "HelpdeskTools\Eksport" } else { Join-Path ([System.IO.Path]::GetTempPath()) "HelpdeskTools\Eksport" }
    if (-not (Test-Path -LiteralPath $local)) { try { New-Item -ItemType Directory -Path $local -Force | Out-Null } catch { return [System.IO.Path]::GetTempPath() } }
    return $local
}

# Katalog dziennika: %LOCALAPPDATA%\HelpdeskTools\Logs (jak w Domain Ops); bez zmiennej LogDir - katalog konfiguracji
function Get-HTLogDirectory {
    if ($Global:LogDir) { return $Global:LogDir }
    return $Global:ConfigDir
}

# Bieżący plik dziennika: jeden plik na dzień (HelpdeskTools_RRRRMMDD.log)
function Get-HTLogFile {
    # Wątki w tle nie zapisują pliku - ich wpisy zapisuje okno programu
    if ($Global:HTNoLogFile) { return $null }
    $dir = Get-HTLogDirectory
    if (-not $dir) { return $null }
    return (Join-Path $dir ("HelpdeskTools_{0:yyyyMMdd}.log" -f (Get-Date)))
}

# Usuwa pliki dziennika starsze niż wskazana liczba dni
function Remove-HTOldLogs {
    param ([int]$Days = 30)
    $dir = Get-HTLogDirectory
    if (-not $dir -or -not (Test-Path $dir)) { return }
    $cutoff = (Get-Date).AddDays(-$Days)
    Get-ChildItem -Path $dir -Filter "HelpdeskTools_*.log" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# Pliki dziennika (najnowsze pierwsze): Date, Path, SizeKB
function Get-HTLogFiles {
    $dir = Get-HTLogDirectory
    if (-not $dir -or -not (Test-Path $dir)) { return @() }
    $files = foreach ($f in Get-ChildItem -Path $dir -Filter "HelpdeskTools_*.log" -File -ErrorAction SilentlyContinue) {
        if ($f.BaseName -notmatch '^HelpdeskTools_(\d{8})') { continue }
        $date = [datetime]::ParseExact($Matches[1], 'yyyyMMdd', [System.Globalization.CultureInfo]::InvariantCulture)
        [PSCustomObject]@{ Date = $date; Path = $f.FullName; Name = $f.Name; SizeKB = [Math]::Round($f.Length / 1KB, 1) }
    }
    return @($files | Sort-Object -Property @{ Expression = { $_.Date }; Descending = $true }, @{ Expression = { $_.Name }; Descending = $true })
}

# Wpisy pliku dziennika jako wiersze tabeli (Czas, Poziom, Konto, Komunikat). Linie bez znacznika czasu (np. wielowierszowy
# komunikat) są dołączane do poprzedniego wpisu. -Level: All | Problems (ostrzeżenia i błędy) | Error; -Text: fragment komunikatu.
function Read-HTLogFile {
    param (
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet("All", "Problems", "Error")][string]$Level = "All",
        [string]$Text = ""
    )
    $pattern = '^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(\w+)\] (?:\[konto: ([^\]]*)\] )?(.*)$'
    $entries = New-Object System.Collections.Generic.List[object]
    $current = $null
    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        if ($line -match $pattern) {
            $message = ($Matches[4] -replace '^(ℹ️|⚠️|❌|🔧)\s*', '')
            $current = [ordered]@{ Czas = $Matches[1]; Poziom = $Matches[2]; Konto = [string]$Matches[3]; Komunikat = $message }
            $entries.Add($current)
        }
        elseif ($current -and $line.Trim()) { $current.Komunikat += "`n" + $line }
    }
    $levelNames = @{ Info = 'Info'; Warn = 'Ostrzeżenie'; Error = 'Błąd'; Debug = 'Debug' }
    foreach ($e in $entries) {
        if ($Level -eq 'Problems' -and $e.Poziom -notin 'Warn', 'Error') { continue }
        if ($Level -eq 'Error' -and $e.Poziom -ne 'Error') { continue }
        if ($Text -and $e.Komunikat.IndexOf($Text, [System.StringComparison]::OrdinalIgnoreCase) -lt 0 -and $e.Konto.IndexOf($Text, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        [PSCustomObject]@{
            Czas      = $e.Czas
            Poziom    = $(if ($levelNames.ContainsKey($e.Poziom)) { $levelNames[$e.Poziom] } else { $e.Poziom })
            Konto     = $e.Konto
            Komunikat = $e.Komunikat
            __flag    = $(switch ($e.Poziom) { 'Error' { 'crit' } 'Warn' { 'warn' } default { '' } })
        }
    }
}

# Funkcja do zapisywania danych do pliku
function Save-ContentToFile {
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Data,

        [Parameter(Mandatory)]
        [ValidateSet("txt", "csv", "json")]
        [string]$Format,

        [string]$Path,

        [string]$Title = "Zapisz plik",
        [string]$DefaultName = "output",
        [string]$DefaultPath
    )

    if (-not $Data -or $Data.Count -eq 0) {
        Write-Log -Message "Brak danych do zapisania!" -Type "Warn"
        return $null
    }

    if (-not $Path) {
        if (-not $DefaultPath) { $DefaultPath = Get-HTExportDirectory }

        $dialog = New-Object Microsoft.Win32.SaveFileDialog
        $dialog.Title = $Title
        $dialog.Filter = switch ($Format) {
            "txt" { "Pliki tekstowe (*.txt)|*.txt" }
            "csv" { "Pliki CSV (*.csv)|*.csv" }
            "json" { "Pliki JSON (*.json)|*.json" }
        }
        $dialog.InitialDirectory = $DefaultPath
        $dialog.FileName = "$($DefaultName)_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').$Format"
        $owner = if ($Global:HT_UI -and $Global:HT_UI.Window -and $Global:HT_UI.Window.IsVisible) { $Global:HT_UI.Window } else { $null }
        $accepted = if ($owner) { $dialog.ShowDialog($owner) } else { $dialog.ShowDialog() }
        if ($accepted -ne $true) {
            Write-Log -Message "Zapis anulowany przez użytkownika." -Type "Warn"
            return $null
        }
        $Path = $dialog.FileName
    }

    try {
        switch ($Format) {
            "txt" { $Data | Out-File -FilePath $Path -Encoding utf8 }
            "csv" { $Data | Export-Csv -Path $Path -NoTypeInformation -Encoding utf8BOM -Delimiter ";" }
            "json" { ConvertTo-Json -InputObject @($Data) -Depth 6 | Out-File -FilePath $Path -Encoding utf8 }
        }
        Write-Log -Message "Zapisano dane do pliku: $Path" -Type "Info&Notification"
        return $Path
    }
    catch {
        Write-Log -Message "Błąd zapisu: $($_.Exception.Message)" -Type "Error&Notification"
        return $null
    }
}

# Funkcja dopisywania logów do pliku (z prostą rotacją)
function Add-LogToFile {
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,

        [ValidateSet("Info", "Warn", "Error", "Debug")]
        [string]$Type = "Info",

        [string]$Path
    )

    if (-not $Path) {
        $Path = Get-HTLogFile
        if (-not $Path) { return }
    }

    try {
        $dir = Split-Path -Path $Path -Parent
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $maxSizeMB = if ($Global:LogFileMaxSizeMB -gt 0) { [double]$Global:LogFileMaxSizeMB } else { 5 }
        if ((Test-Path $Path) -and ((Get-Item $Path).Length -gt ($maxSizeMB * 1MB))) {
            $archive = Join-Path $dir ("{0}_{1}{2}" -f [System.IO.Path]::GetFileNameWithoutExtension($Path), (Get-Date -Format "HHmmss"), [System.IO.Path]::GetExtension($Path))
            Move-Item -Path $Path -Destination $archive -Force
        }

        $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Type] $Message"
        Add-Content -Path $Path -Value $logEntry -Encoding utf8
    }
    catch {
        Write-Verbose "Nie udało się zapisać logu do pliku: $($_.Exception.Message)"
    }
}

# Walidacja wartości wprowadzanej w polach tekstowych
function Test-HTInputValue {
    param (
        [AllowEmptyString()][string]$Value,
        [ValidateSet("Text", "Email", "Phone", "Url", "Upn", "Guid")]
        [string]$ValidationType = "Text"
    )

    switch ($ValidationType) {
        "Email" { return $Value -match '^[\w\.\+\-'']+@[\w\.-]+\.\w{2,}$' }
        "Upn" { return $Value -match '^[\w\.\+\-'']+@[\w\.-]+\.\w{2,}$' }
        "Phone" { return $Value -match '^\+?[0-9\s\-\(\)]{9,}$' }
        "Url" { return $Value -match '^https?://[\w\-\.]+\.\w{2,}(/.*)?$' }
        "Guid" { return $Value -match '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$' }
        default { return -not [string]::IsNullOrWhiteSpace($Value) }
    }
}

# Funkcja do usuwania wewnętrznych białych znaków z ciągu znaków
function Remove-InnerWhitespace {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputString,
        [switch]$TrimEnds # Dodatkowo: czy przyciąć początek/koniec
    )

    $result = $InputString -replace '\s', ''
    if ($TrimEnds) {
        $result = $result.Trim()
    }
    return $result
}

# Konwersja wartości do postaci czytelnej w GUI
function ConvertTo-HTDisplayValue {
    param ([AllowNull()][object]$Value)

    if ($null -eq $Value) { return "" }
    if ($Value -is [bool]) { return $(if ($Value) { "Tak" } else { "Nie" }) }
    if ($Value -is [datetime]) { return $Value.ToString("yyyy-MM-dd HH:mm") }
    if ($Value -is [datetimeoffset]) { return $Value.LocalDateTime.ToString("yyyy-MM-dd HH:mm") }
    if ($Value -is [string]) {
        # Daty ISO 8601 zwracane przez Graph jako tekst
        if ($Value -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}') {
            $parsed = [datetimeoffset]::MinValue
            if ([datetimeoffset]::TryParse($Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                return $parsed.LocalDateTime.ToString("yyyy-MM-dd HH:mm")
            }
        }
        return $Value
    }
    if ($Value -is [System.Collections.IDictionary]) {
        return (@($Value.Keys | ForEach-Object { "$_=$($Value[$_])" }) -join "; ")
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        return (@($Value | ForEach-Object { ConvertTo-HTDisplayValue $_ }) -join ", ")
    }
    return "$Value"
}

# Rozbija tekst (np. wklejoną listę) na unikalne, niepuste wpisy
function Protect-HTSupportText {
    # Tekst do wsparcia bez sekretów: tokeny (JWT), hasła i sekrety «nazwa=wartość», podpisy i klucze w adresach, webhooki
    param([AllowEmptyString()][AllowNull()][string]$Text)
    if (-not $Text) { return '' }
    $t = $Text -replace 'eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]*', '[token]'
    $t = $t -replace '(?i)https?://[^\s"''<>]*(webhook|logic\.azure|powerautomate|environment\.api)[^\s"''<>]*', '[adres webhooka]'
    $t = $t -replace '(?i)([?&](sig|code|token|key|secret|password)=)[^\s&"''<>]+', '$1[ukryte]'
    $t = $t -replace '(?i)\b(password|passwd|hasło|haslo|secret|sekret|client_?secret|token|api_?key)(\s*[:=]\s*)\S+', '$1$2[ukryte]'
    return $t
}

function Format-HTSupportReport {
    # Dane do zgłoszenia problemu z sekcji [ordered]@{ Tytuł = wiersze } (kolejność zachowana), bez sekretów
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Sections)
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($k in $Sections.Keys) {
        if ($lines.Count) { $lines.Add('') }
        $lines.Add("== $k ==")
        $items = @($Sections[$k] | Where-Object { $null -ne $_ })
        if (-not $items.Count) { $lines.Add('(brak)') }
        foreach ($l in $items) { $lines.Add((Protect-HTSupportText ([string]$l))) }
    }
    return ($lines -join "`r`n")
}

function Get-HTAddressCompletion {
    <#
        Podpowiedź końcówki adresu podczas pisania: najdłuższy wspólny początek znanych adresów zaczynających się od -Token
        (bez rozróżniania wielkości liter); po «@» - także sama domena znanych adresów (jan.nowy@fi -> jan.nowy@firma.pl).
        Zwraca -Token z dopisaną końcówką albo '' (brak dopasowania albo nic do dopisania).
    #>
    param([AllowEmptyString()][AllowNull()][string]$Token, [AllowEmptyCollection()][string[]]$Addresses = @(), [int]$MinLength = 2)
    if (-not $Token -or $Token.Length -lt $MinLength) { return '' }
    $common = {
        param([string[]]$Items)
        $prefix = $Items[0]
        foreach ($item in $Items) {
            $i = 0
            while ($i -lt $prefix.Length -and $i -lt $item.Length -and [char]::ToLowerInvariant($prefix[$i]) -eq [char]::ToLowerInvariant($item[$i])) { $i++ }
            $prefix = $prefix.Substring(0, $i)
        }
        return $prefix
    }
    $found = @($Addresses | Where-Object { $_ -and $_.StartsWith($Token, [StringComparison]::OrdinalIgnoreCase) } | Select-Object -Unique)
    if (-not $found.Count -and $Token.Contains('@')) {
        $at = $Token.IndexOf('@')
        $local = $Token.Substring(0, $at + 1)
        $domainPart = $Token.Substring($at + 1)
        $domains = @($Addresses | Where-Object { $_ -and $_.Contains('@') } | ForEach-Object { $_.Substring($_.IndexOf('@') + 1) } | Where-Object { $_.StartsWith($domainPart, [StringComparison]::OrdinalIgnoreCase) } | Select-Object -Unique)
        $found = @($domains | ForEach-Object { $local + $_ })
    }
    if (-not $found.Count) { return '' }
    $prefix = & $common $found
    if ($prefix.Length -le $Token.Length) { return '' }
    return $Token + $prefix.Substring($Token.Length)
}

function Split-HTInputList {
    param ([AllowEmptyString()][AllowNull()][string]$Text)
    if (-not $Text) { return @() }
    return @($Text -split '[\r\n,;\t]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
}

# Formatuje rozmiar w bajtach
function Format-HTBytes {
    param ([AllowNull()][object]$Bytes)
    if ($null -eq $Bytes -or "$Bytes" -eq "") { return "" }
    $value = [double]$Bytes
    $units = @("B", "KB", "MB", "GB", "TB")
    $i = 0
    while ($value -ge 1024 -and $i -lt $units.Count - 1) { $value /= 1024; $i++ }
    return ("{0:N1} {1}" -f $value, $units[$i])
}

# Usuwa polskie i inne znaki diakrytyczne (np. do tworzenia loginów)
function ConvertTo-HTAsciiName {
    param ([AllowEmptyString()][AllowNull()][string]$Text)
    if (-not $Text) { return "" }
    $text = $Text.Replace("ł", "l").Replace("Ł", "L")
    $normalized = $text.Normalize([System.Text.NormalizationForm]::FormD)
    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $normalized.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($char) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($char)
        }
    }
    return $builder.ToString().Normalize([System.Text.NormalizationForm]::FormC)
}

# Odczyt identyfikatorów z pliku CSV (wskazana kolumna) lub TXT (jeden na linię)
function Import-HTIdentityFile {
    param (
        [Parameter(Mandatory)][string]$Path,
        [string]$Column
    )
    if ($Path -match '\.csv$') {
        $firstLine = Get-Content -Path $Path -TotalCount 1 -Encoding utf8
        $delimiter = if ($firstLine -match ';') { ';' } else { ',' }
        $rows = @(Import-Csv -Path $Path -Delimiter $delimiter -Encoding utf8)
        if ($rows.Count -eq 0) { return @() }
        $columns = @($rows[0].PSObject.Properties.Name)
        if (-not $Column) {
            # Kolumna wg priorytetu nazw (identyfikatory przed nazwami wyświetlanymi)
            $priority = "UserPrincipalName", "UPN", "Mail", "Email", "E-mail", "PrimarySmtpAddress", "SamAccountName", "Login", "Identity", "DeviceName", "Name"
            $Column = $priority | Where-Object { $columns -contains $_ } | Select-Object -First 1
            if (-not $Column) { $Column = $columns[0] }
        }
        return @($rows | ForEach-Object { "$($_.$Column)".Trim() } | Where-Object { $_ } | Select-Object -Unique)
    }
    return Split-HTInputList -Text (Get-Content -Path $Path -Raw -Encoding utf8)
}

# Wiersze pliku CSV (separator ; albo , wykrywany z nagłówka, UTF-8); puste wiersze są pomijane
function Import-HTCsvFile {
    param ([Parameter(Mandatory)][string]$Path)
    $first = Get-Content -LiteralPath $Path -TotalCount 1 -Encoding utf8
    $delimiter = if ($first -match ';') { ';' } else { ',' }
    return @(Import-Csv -LiteralPath $Path -Delimiter $delimiter -Encoding utf8 | Where-Object { @($_.PSObject.Properties | Where-Object { "$($_.Value)".Trim() }).Count -gt 0 })
}

# Spłaszcza słownik szczegółów (z zagnieżdżonymi sekcjami) do wierszy Sekcja / Pole / Wartość
function ConvertTo-HTDetailRows {
    param (
        [Parameter(Mandatory)][System.Collections.IDictionary]$Data,
        [string]$Section = "Ogólne"
    )
    foreach ($key in $Data.Keys) {
        $value = $Data[$key]
        if ($value -is [System.Collections.IDictionary]) {
            ConvertTo-HTDetailRows -Data $value -Section ([string]$key)
            continue
        }
        $text = if ($value -is [array]) { (@($value | ForEach-Object { ConvertTo-HTDisplayValue $_ }) -join "`n") } else { ConvertTo-HTDisplayValue $value }
        [PSCustomObject]@{
            Sekcja  = $Section
            Pole    = [string]$key
            Wartość = $text
        }
    }
}

function Select-HTDetailFields {
    <#
        Wybrane pola słownika szczegółów (także z podsekcji) jako jeden wiersz wyników - np. do «Sprawdź stan».
        -Fields: nazwy pól albo @{ Name = 'Pole'; Label = 'Kolumna' }. Pole z sekcji wyższego poziomu ma pierwszeństwo;
        brak pola - pusta wartość.
    #>
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Detail, [Parameter(Mandatory)][object[]]$Fields)
    $flat = @{}
    $queue = New-Object System.Collections.Generic.Queue[System.Collections.IDictionary]
    $queue.Enqueue($Detail)
    while ($queue.Count) {
        $d = $queue.Dequeue()
        foreach ($k in @($d.Keys)) {
            $v = $d[$k]
            if ($v -is [System.Collections.IDictionary]) { $queue.Enqueue($v); continue }
            if (-not $flat.ContainsKey([string]$k)) { $flat[[string]$k] = $v }
        }
    }
    $row = [ordered]@{}
    foreach ($f in $Fields) {
        $name = if ($f -is [System.Collections.IDictionary]) { [string]$f.Name } else { [string]$f }
        $label = if ($f -is [System.Collections.IDictionary] -and $f.Label) { [string]$f.Label } else { $name }
        $row[$label] = if ($flat.ContainsKey($name)) { $flat[$name] } else { $null }
    }
    return [PSCustomObject]$row
}

function Test-HTBackgroundSafeBlock {
    <#
        Czy blok -Action można wykonać w wątku w tle: używa tylko swoich parametrów i zmiennych, zmiennych automatycznych,
        poleceń PowerShell i funkcji modułów z -AllowedModules (pula w tle) - bez funkcji okna (GUI) i zmiennych z otaczającego kodu.
    #>
    param([Parameter(Mandatory)][scriptblock]$ScriptBlock, [string[]]$AllowedModules = @())
    $ast = $ScriptBlock.Ast
    $known = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($n in 'true', 'false', 'null', '_', 'PSItem', 'args', 'input', 'Matches', 'this', 'PSBoundParameters', 'LASTEXITCODE') { [void]$known.Add($n) }
    $find = { param([type]$Type) @($ast.FindAll([Func[System.Management.Automation.Language.Ast, bool]] { param($n) $n -is $Type }.GetNewClosure(), $true)) }
    foreach ($p in (& $find ([System.Management.Automation.Language.ParameterAst]))) { [void]$known.Add($p.Name.VariablePath.UserPath) }
    foreach ($f in (& $find ([System.Management.Automation.Language.ForEachStatementAst]))) { [void]$known.Add($f.Variable.VariablePath.UserPath) }
    foreach ($a in (& $find ([System.Management.Automation.Language.AssignmentStatementAst]))) {
        foreach ($v in @($a.Left.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true))) { [void]$known.Add($v.VariablePath.UserPath) }
    }
    foreach ($v in (& $find ([System.Management.Automation.Language.VariableExpressionAst]))) {
        $path = $v.VariablePath
        if ($path.IsDriveQualified -and $path.DriveName -eq 'env') { continue }
        if (-not $known.Contains($path.UserPath)) { return $false }
    }
    foreach ($c in (& $find ([System.Management.Automation.Language.CommandAst]))) {
        $name = $c.GetCommandName()
        if (-not $name) { return $false }
        $cmd = @(Get-Command -Name $name -ErrorAction SilentlyContinue)[0]
        if ($cmd -and $cmd.CommandType -eq 'Alias') { $cmd = $cmd.ResolvedCommand }
        if (-not $cmd) { return $false }
        if ($cmd.CommandType -eq 'Cmdlet' -and "$($cmd.ModuleName)" -like 'Microsoft.PowerShell.*') { continue }
        if ($cmd.CommandType -eq 'Function' -and $AllowedModules -contains "$($cmd.ModuleName)") { continue }
        return $false
    }
    return $true
}

# Liczba dni od podanej daty (null, gdy brak daty)
function Get-HTDaysSince {
    param ([AllowNull()][object]$Date)
    if ($null -eq $Date -or "$Date" -eq "") { return $null }
    $value = $null
    if ($Date -is [datetime]) { $value = $Date }
    elseif ($Date -is [datetimeoffset]) { $value = $Date.LocalDateTime }
    else {
        $parsed = [datetimeoffset]::MinValue
        if (-not [datetimeoffset]::TryParse("$Date", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) { return $null }
        $value = $parsed.LocalDateTime
    }
    if ($value.Year -lt 1700) { return $null }
    return [int][Math]::Floor(((Get-Date) - $value).TotalDays)
}

#region Potwierdzenie zmian (treść bez interfejsu)
$script:FormSecretLabelPattern = 'hasł|password|secret|sekret|klucz|token|\bpin\b'

function ConvertTo-HTFormSummaryLine {
    <#
        Jedna linia «Etykieta: wartość» do okna potwierdzenia zmiany; pusty tekst - pole pomijane
        (puste, «(bez zmian)», niezaznaczone pole wyboru, pole z NoSummary). Hasła i sekrety są maskowane.
    #>
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Field, [string]$Type = 'Text', $Value)
    if ($Field.NoSummary) { return '' }
    $label = ([string]$Field.Label).Trim().TrimEnd(':', '*', ' ')
    if (-not $label) { $label = [string]$Field.Name }
    switch ($Type) {
        'Check' { if ($Value -eq $true) { return "$label - tak" }; return '' }
        'Date' {
            if ($Value -is [datetime]) { return "${label}: $($Value.ToString($(if ($Field.DateOnly) { 'yyyy-MM-dd' } else { 'yyyy-MM-dd HH:mm' })))" }
            return ''
        }
        'Number' { return "${label}: $Value" }
    }
    $text = [string]$Value
    if (-not $text.Trim() -or $text.Trim() -eq '(bez zmian)') { return '' }
    if ($Type -eq 'Password' -or $Field.Secret -or $label -match $script:FormSecretLabelPattern) { return "${label}: ••••••" }
    $lines = @($text -split '\r?\n' | Where-Object { $_.Trim() })
    $first = $lines[0].Trim()
    if ($first.Length -gt 90) { $first = $first.Substring(0, 89) + '…' }
    elseif ($lines.Count -gt 1) { $first += ' …' }
    if ($lines.Count -gt 1) { $first += " (wierszy: $($lines.Count))" }
    return "${label}: $first"
}

function ConvertTo-HTChangeSummary {
    # Słownik zmian (parametr -> wartość) jako linie «Nazwa: wartość» do potwierdzenia; $null/«-» - wyczyszczenie
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Settings, [hashtable]$Labels = @{})
    foreach ($k in @($Settings.Keys)) {
        $v = $Settings[$k]
        $name = if ($Labels.ContainsKey([string]$k)) { $Labels[[string]$k] } else { [string]$k }
        $text = if ($null -eq $v -or "$v" -eq '-') { '(wyczyść)' }
        elseif ($v -is [bool]) { if ($v) { 'tak' } else { 'nie' } }
        elseif ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { $list = @($v | ForEach-Object { "$_" }); if ($list.Count) { $list -join ', ' } else { '(wyczyść)' } }
        else { [string]$v }
        "${name}: $text"
    }
}

function Get-HTChangeConfirmation {
    <#
        Treść potwierdzenia zmiany (bez interfejsu): @{ Message; Details; ItemsHeader; ConfirmText; LogText }.
        Pokazuje nazwę operacji, co zostanie ustawione (-Summary albo wartości formularza) i liczbę obiektów.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Labels,
        [string]$Confirm = '',
        [string[]]$Summary = @(),
        [string]$Source = ''
    )
    $details = @($Summary | Where-Object { "$_".Trim() })
    $count = $Labels.Count
    $message = if ($Confirm) { $Confirm } else { "Operacja: $Name. Sprawdź, co zostanie zmienione i na których obiektach." }
    $header = "Dotyczy obiektów ($count)" + $(if ($Source) { " - $Source" } else { '' }) + ':'
    $preview = @($Labels | Select-Object -First 10) -join ', '
    if ($count -gt 10) { $preview += " … (+$($count - 10))" }
    $log = "«$Name» - obiektów: $count ($preview)" + $(if ($details.Count) { "; $($details -join '; ')" } else { '' })
    return @{
        Message     = $message
        Details     = $details
        ItemsHeader = $header
        ConfirmText = $(if ($count -gt 1) { "Wykonaj ($count)" } else { 'Wykonaj' })
        LogText     = $log
    }
}
function Group-HTWarningMessages {
    <#
        Ostrzeżenia poleceń do dziennika: bez powtórzeń (kolejność pierwszego wystąpienia), z liczbą powtórzeń «(×N)»
        i bez pustych wierszy (np. Exchange powtarza to samo ostrzeżenie dla każdej skrzynki).
    #>
    param([AllowEmptyCollection()][string[]]$Messages = @())
    $order = New-Object System.Collections.Generic.List[string]
    $counts = @{}
    foreach ($m in $Messages) {
        $text = (([string]$m) -replace '\s+', ' ').Trim()
        if (-not $text) { continue }
        if ($counts.ContainsKey($text)) { $counts[$text]++ } else { $counts[$text] = 1; $order.Add($text) }
    }
    foreach ($text in $order) { if ($counts[$text] -gt 1) { "$text (×$($counts[$text]))" } else { $text } }
}
#endregion
