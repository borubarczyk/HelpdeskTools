# SharePoint (PnP, połączona witryna): masowe tworzenie struktury folderów i bibliotek z uprawnieniami (składnia
# tekstowa z wcięciami i szablony), nowe biblioteki i ich ustawienia, kolumny, uprawnienia witryny i administratorzy
# kolekcji, dostęp użytkownika w witrynie, grupy SharePoint, wyewidencjonowane pliki, wyszukiwanie, kopiowanie
# i przenoszenie, wysyłanie folderu z dysku oraz nowe witryny. Węzeł (Node): @{ Title; ServerRelativeUrl; ListTitle; IsLibrary }.
# Funkcje bez wywołań PnP (parsery, poziomy uprawnień, nazwy) są testowane w Tests/SharePointStructure.Tests.ps1.

#region Nazwy, poziomy uprawnień i podmioty
$script:SPRoleAliases = @{
    'pełna kontrola' = 'Administrator'; 'pelna kontrola' = 'Administrator'; 'full control' = 'Administrator'; 'full' = 'Administrator'
    'właściciel' = 'Administrator'; 'wlasciciel' = 'Administrator'; 'owner' = 'Administrator'; 'administrator' = 'Administrator'
    'edycja' = 'Editor'; 'edit' = 'Editor'; 'editor' = 'Editor'; 'edytor' = 'Editor'
    'współtworzenie' = 'Contributor'; 'wspoltworzenie' = 'Contributor'; 'contribute' = 'Contributor'; 'contributor' = 'Contributor'
    'odczyt' = 'Reader'; 'read' = 'Reader'; 'reader' = 'Reader'; 'czytelnik' = 'Reader'
    'projektowanie' = 'WebDesigner'; 'design' = 'WebDesigner'; 'designer' = 'WebDesigner'
}
$script:SPAssociatedGroups = @{
    '@właściciele' = 'Owner'; '@wlasciciele' = 'Owner'; '@owners' = 'Owner'
    '@członkowie' = 'Member'; '@czlonkowie' = 'Member'; '@members' = 'Member'
    '@odwiedzający' = 'Visitor'; '@odwiedzajacy' = 'Visitor'; '@visitors' = 'Visitor'
}
$script:SPReservedNames = @('.lock', 'CON', 'PRN', 'AUX', 'NUL', 'COM0', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT0', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9', 'desktop.ini', 'Forms')

function Test-HTSPItemName {
    # Komunikat o błędzie nazwy folderu / pliku SharePoint albo pusty tekst (nazwa poprawna)
    param ([AllowEmptyString()][AllowNull()][string]$Name)
    $n = [string]$Name
    if (-not $n.Trim()) { return 'pusta nazwa' }
    if ($n -ne $n.Trim()) { return 'spacja na początku lub końcu nazwy' }
    if ($n -match '["*:<>?/\\|]') { return 'niedozwolone znaki: " * : < > ? / \ |' }
    if ($n.EndsWith('.')) { return 'nazwa nie może kończyć się kropką' }
    if ($n.StartsWith('~$')) { return 'nazwa nie może zaczynać się od ~$' }
    if ($n -match '_vti_') { return 'nazwa nie może zawierać _vti_' }
    if (@($script:SPReservedNames | Where-Object { $_ -ieq $n }).Count) { return "nazwa zastrzeżona ($n)" }
    if ($n.Length -gt 250) { return 'nazwa dłuższa niż 250 znaków' }
    return ''
}

function ConvertTo-HTSPUrlName {
    # Nazwa do adresu URL (biblioteki, witryny): bez polskich znaków, spacji i znaków specjalnych («Dokumenty Zarządu» -> DokumentyZarzadu)
    param ([AllowEmptyString()][AllowNull()][string]$Title, [int]$MaxLength = 50)
    $ascii = ConvertTo-HTAsciiName ([string]$Title)
    $words = @($ascii -split '[^A-Za-z0-9]+' | Where-Object { $_ })
    $name = ($words | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join ''
    if ($name.Length -gt $MaxLength) { $name = $name.Substring(0, $MaxLength) }
    return $name
}

function Resolve-HTSPRoleName {
    <#
        Nazwa poziomu uprawnień witryny dla wpisu użytkownika: dokładna nazwa (np. «Edycja», «Contribute») albo
        alias (Pełna kontrola/Full, Edycja/Edit, Współtworzenie/Contribute, Odczyt/Read, Projektowanie/Design) -
        dopasowany po rodzaju poziomu (RoleTypeKind), więc działa w witrynach w każdym języku.
        -Definitions: @(@{ Name; RoleTypeKind }) z Get-HTSPRoleDefinitionList.
    #>
    param ([Parameter(Mandatory)][string]$Role, [Parameter(Mandatory)][object[]]$Definitions)
    $r = $Role.Trim()
    $exact = @($Definitions | Where-Object { [string]$_.Name -ieq $r })[0]
    if ($exact) { return [string]$exact.Name }
    $kind = $script:SPRoleAliases[$r.ToLowerInvariant()]
    if ($kind) {
        $byKind = @($Definitions | Where-Object { [string]$_.RoleTypeKind -eq $kind })[0]
        if ($byKind) { return [string]$byKind.Name }
    }
    throw "Nieznany poziom uprawnień «$r» (dostępne: $(@($Definitions | ForEach-Object { $_.Name }) -join ', '))"
}

function Resolve-HTSPPrincipal {
    <#
        Podmiot uprawnień: grupa witryny przez alias (@Właściciele, @Członkowie, @Odwiedzający), grupa SharePoint
        po nazwie albo użytkownik / grupa zabezpieczeń (adres e-mail lub login). -Resolver z Get-HTSPPrincipalResolver.
        Zwraca @{ Kind = 'Group'|'User'; Name }.
    #>
    param ([Parameter(Mandatory)][string]$Principal, [Parameter(Mandatory)][hashtable]$Resolver)
    $p = $Principal.Trim()
    $assoc = $script:SPAssociatedGroups[$p.ToLowerInvariant()]
    if ($assoc) {
        $name = $Resolver.Associated[$assoc]
        if (-not $name) { throw "Witryna nie ma przypisanej grupy dla $p" }
        return @{ Kind = 'Group'; Name = [string]$name }
    }
    $group = @($Resolver.Groups | Where-Object { [string]$_ -ieq $p })[0]
    if ($group) { return @{ Kind = 'Group'; Name = [string]$group } }
    return @{ Kind = 'User'; Name = $p }
}

function Test-HTSPPrincipalMatch {
    # Czy przypisanie (Principal - nazwa, LoginName - login) dotyczy podmiotu (nazwa grupy, adres e-mail albo login)
    param ([Parameter(Mandatory)][object]$Assignment, [Parameter(Mandatory)][string]$Principal)
    $p = $Principal.Trim()
    $login = [string]$Assignment.LoginName
    return ([string]$Assignment.Principal -ieq $p) -or ($login -ieq $p) -or ($login -like "*|$p") -or ([string]$Assignment.Email -ieq $p)
}

function ConvertTo-HTSPPrincipalText {
    # Podmiot przypisania do zapisu w składni struktury: grupa - nazwa, użytkownik - adres z loginu (i:0#.f|membership|adres)
    param ([Parameter(Mandatory)][object]$Assignment)
    if ([string]$Assignment.PrincipalType -eq 'SharePointGroup') { return [string]$Assignment.Principal }
    $login = [string]$Assignment.LoginName
    if ($login -match '\|membership\|(.+)$') { return $Matches[1] }
    if ($login) { return $login }
    return [string]$Assignment.Principal
}
#endregion

#region Składnia struktury folderów
function ConvertFrom-HTSPPermissionSpec {
    <#
        Uprawnienia po «|» w linii struktury: «Zarząd=Pełna kontrola; jan@firma.pl=Odczyt; -anna@firma.pl».
        «!» na początku - bez kopiowania obecnych uprawnień. Zwraca @{ Grants = @(@{ Principal; Role }); Removes; Copy; Errors }.
    #>
    param ([AllowEmptyString()][AllowNull()][string]$Text)
    $t = ([string]$Text).Trim()
    $copy = $true
    if ($t.StartsWith('!')) { $copy = $false; $t = $t.Substring(1).Trim() }
    $grants = New-Object System.Collections.Generic.List[object]
    $removes = New-Object System.Collections.Generic.List[string]
    $errors = New-Object System.Collections.Generic.List[string]
    foreach ($part in @($t -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
        if ($part.StartsWith('-')) {
            $who = $part.Substring(1).Trim()
            if ($who) { $removes.Add($who) } else { $errors.Add("pusty podmiot w «$part»") }
            continue
        }
        $pair = $part -split '=', 2
        if ($pair.Count -ne 2 -or -not $pair[0].Trim() -or -not $pair[1].Trim()) { $errors.Add("«$part» - zapis: podmiot=poziom (np. jan@firma.pl=Edycja)"); continue }
        $grants.Add(@{ Principal = $pair[0].Trim(); Role = $pair[1].Trim() })
    }
    return @{ Grants = $grants.ToArray(); Removes = $removes.ToArray(); Copy = $copy; Errors = $errors.ToArray() }
}

function ConvertFrom-HTSPStructureText {
    <#
        Struktura folderów z tekstu. Każda linia to folder; wcięcie (spacje albo tabulator) - folder podrzędny;
        «a/b/c» - kilka poziomów naraz. Po «|» - uprawnienia (ConvertFrom-HTSPPermissionSpec), «#» - komentarz.
          Projekty
              2026
                  Umowy | Zarząd=Pełna kontrola; jan@firma.pl=Odczyt
              Archiwum |! @Właściciele=Pełna kontrola
          Kadry/Umowy/2026
        Zwraca @{ Items = @(@{ Path; Name; Level; Grants; Removes; Break; Copy; Line }); Errors } - foldery nadrzędne
        przed podrzędnymi, ścieżki rozdzielone «/».
    #>
    param ([AllowEmptyString()][AllowNull()][string]$Text, [int]$TabSize = 4)
    $items = [ordered]@{}
    $errors = New-Object System.Collections.Generic.List[string]
    $stack = New-Object System.Collections.Generic.List[object]
    $lineNo = 0
    foreach ($raw in @(([string]$Text) -split "`r?`n")) {
        $lineNo++
        $expanded = $raw.Replace("`t", (' ' * $TabSize))
        $content = $expanded.Trim()
        if (-not $content -or $content.StartsWith('#')) { continue }
        $indent = $expanded.Length - $expanded.TrimStart().Length
        $pathPart = $content
        $specPart = $null
        $bar = $content.IndexOf('|')
        if ($bar -ge 0) { $pathPart = $content.Substring(0, $bar).Trim(); $specPart = $content.Substring($bar + 1) }
        $segments = @($pathPart -split '[/\\]' | ForEach-Object { $_.Trim() })
        if (-not $pathPart -or @($segments | Where-Object { -not $_ }).Count) { $errors.Add("linia $($lineNo): pusta nazwa folderu"); continue }
        $bad = @($segments | ForEach-Object { $e = Test-HTSPItemName $_; if ($e) { "«$_» - $e" } })
        if ($bad.Count) { $errors.Add("linia $($lineNo): $($bad -join '; ')"); continue }
        $spec = $null
        if ($null -ne $specPart) {
            $spec = ConvertFrom-HTSPPermissionSpec -Text $specPart
            foreach ($e in $spec.Errors) { $errors.Add("linia $($lineNo): $e") }
        }
        while ($stack.Count -and $stack[$stack.Count - 1].Indent -ge $indent) { $stack.RemoveAt($stack.Count - 1) }
        $parent = if ($stack.Count) { [string]$stack[$stack.Count - 1].Path } else { '' }
        $path = $parent
        for ($i = 0; $i -lt $segments.Count; $i++) {
            $path = if ($path) { "$path/$($segments[$i])" } else { $segments[$i] }
            $key = $path.ToLowerInvariant()
            if (-not $items.Contains($key)) {
                $items[$key] = @{ Path = $path; Name = $segments[$i]; Level = @($path -split '/').Count - 1; Grants = @(); Removes = @(); Break = $false; Copy = $true; Line = $lineNo }
            }
            if ($i -eq $segments.Count - 1 -and $spec) {
                $item = $items[$key]
                $item.Break = $true
                $item.Copy = $item.Copy -and $spec.Copy
                $item.Grants = @($item.Grants) + @($spec.Grants)
                $item.Removes = @($item.Removes) + @($spec.Removes)
            }
        }
        $stack.Add(@{ Indent = $indent; Path = $path })
    }
    return @{ Items = @($items.Values); Errors = $errors.ToArray() }
}

function ConvertTo-HTSPStructureLine {
    # Linia składni struktury: wcięcie (4 spacje na poziom), nazwa i uprawnienia (z «!» - dokładnie te uprawnienia)
    param ([Parameter(Mandatory)][string]$Name, [int]$Level = 0, [AllowEmptyCollection()][object[]]$Grants = @(), [switch]$Unique)
    $line = (' ' * (4 * $Level)) + $Name
    if ($Unique) {
        $spec = @($Grants | ForEach-Object { "$($_.Principal)=$($_.Role)" }) -join '; '
        $line += " |! $spec".TrimEnd()
    }
    return $line
}

$script:BuiltInStructureTemplates = @(
    @{ Name = 'Projekt'; BuiltIn = $true; Text = "01 Umowy`r`n02 Korespondencja`r`n03 Dokumentacja`r`n    Projektowa`r`n    Odbiorowa`r`n04 Faktury`r`n05 Protokoły`r`n06 Archiwum" }
    @{ Name = 'Klient'; BuiltIn = $true; Text = "Oferty`r`nUmowy`r`nZamówienia`r`nFaktury`r`nKorespondencja`r`nReklamacje" }
    @{ Name = 'Dział'; BuiltIn = $true; Text = "Wspólne | @Członkowie=Edycja`r`nProcedury | @Członkowie=Odczyt`r`nSzablony`r`nSpotkania`r`nArchiwum" }
    @{ Name = 'Rok - miesiące'; BuiltIn = $true; Text = "01 Styczeń`r`n02 Luty`r`n03 Marzec`r`n04 Kwiecień`r`n05 Maj`r`n06 Czerwiec`r`n07 Lipiec`r`n08 Sierpień`r`n09 Wrzesień`r`n10 Październik`r`n11 Listopad`r`n12 Grudzień" }
    @{ Name = 'Poufne (przykład uprawnień)'; BuiltIn = $true; Text = "# Zamień adresy i grupy na własne`r`nKadry |! @Właściciele=Pełna kontrola; kadry@firma.pl=Edycja`r`n    Umowy`r`n    Wnioski urlopowe`r`nZarząd |! @Właściciele=Pełna kontrola; zarzad@firma.pl=Edycja`r`nWspólne | @Członkowie=Edycja" }
    @{ Name = 'Witryna działu (biblioteki)'; BuiltIn = $true; Text = "# Tryb «witryna»: pierwszy poziom to biblioteki`r`nDokumenty działu`r`n    Procedury`r`n    Szablony`r`nProjekty`r`n    Archiwum`r`nPoufne |! @Właściciele=Pełna kontrola" }
)

function Get-HTSPStructureTemplates {
    # Szablony struktur: wbudowane i zapisane (SPStructureTemplates.json w katalogu konfiguracji; zapisany zastępuje wbudowany o tej nazwie)
    $saved = @(Read-HTJsonList -Path (Get-HTAutomationFile 'SPStructureTemplates.json'))
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($t in $script:BuiltInStructureTemplates) { if (-not @($saved | Where-Object { $_.Name -ieq $t.Name }).Count) { $result.Add($t) } }
    foreach ($t in $saved) { if ($t.Name) { $result.Add(@{ Name = [string]$t.Name; Text = [string]$t.Text; BuiltIn = $false }) } }
    return @($result | Sort-Object { $_.Name })
}

function Save-HTSPStructureTemplate {
    param ([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Text)
    $path = Get-HTAutomationFile 'SPStructureTemplates.json'
    $items = @(Read-HTJsonList -Path $path | Where-Object { $_.Name -ine $Name })
    $items += [ordered]@{ Name = $Name.Trim(); Text = $Text; Saved = (Get-Date).ToString('o'); By = "$env:USERNAME" }
    Write-HTJsonList -Path $path -Items @($items | Sort-Object { $_.Name })
}

function Remove-HTSPStructureTemplate {
    param ([Parameter(Mandatory)][string]$Name)
    $path = Get-HTAutomationFile 'SPStructureTemplates.json'
    Write-HTJsonList -Path $path -Items @(Read-HTJsonList -Path $path | Where-Object { $_.Name -ine $Name })
}
#endregion

#region Kolumny bibliotek (składnia)
$script:SPColumnTypes = [ordered]@{
    'tekst' = 'Text'; 'text' = 'Text'; 'jeden wiersz' = 'Text'
    'tekst wielowierszowy' = 'Note'; 'wiele wierszy' = 'Note'; 'notatka' = 'Note'; 'note' = 'Note'; 'opis' = 'Note'
    'liczba' = 'Number'; 'number' = 'Number'
    'data' = 'DateTime'; 'date' = 'DateTime'; 'data i godzina' = 'DateTime'; 'datetime' = 'DateTime'
    'wybór' = 'Choice'; 'wybor' = 'Choice'; 'choice' = 'Choice'; 'lista' = 'Choice'
    'wielokrotny wybór' = 'MultiChoice'; 'wielokrotny wybor' = 'MultiChoice'; 'multichoice' = 'MultiChoice'
    'osoba' = 'User'; 'użytkownik' = 'User'; 'uzytkownik' = 'User'; 'user' = 'User'; 'person' = 'User'
    'tak/nie' = 'Boolean'; 'taknie' = 'Boolean'; 'boolean' = 'Boolean'; 'bool' = 'Boolean'; 'yes/no' = 'Boolean'
    'waluta' = 'Currency'; 'kwota' = 'Currency'; 'currency' = 'Currency'
    'link' = 'URL'; 'url' = 'URL'; 'hiperłącze' = 'URL'; 'hiperlacze' = 'URL'
}

function ConvertFrom-HTSPColumnSpec {
    <#
        Kolumny z tekstu - jedna w linii: «Nazwa: Typ [opcja 1, opcja 2] *» (* - wymagana; bez typu - tekst).
        Typy: Tekst, Tekst wielowierszowy, Liczba, Data, Wybór [..], Wielokrotny wybór [..], Osoba, Tak/Nie, Waluta, Link.
        Zwraca wpisy @{ DisplayName; InternalName; Type; Choices; Required; Errors; Valid }.
    #>
    param ([AllowEmptyString()][AllowNull()][string]$Text)
    $seen = New-Object System.Collections.Generic.List[string]
    foreach ($line in @(([string]$Text) -split "`r?`n")) {
        $l = $line.Trim()
        if (-not $l -or $l.StartsWith('#')) { continue }
        $errors = New-Object System.Collections.Generic.List[string]
        $required = $l.EndsWith('*')
        if ($required) { $l = $l.TrimEnd('*').Trim() }
        $choices = @()
        if ($l -match '\[(.*)\]\s*$') {
            $choices = @($Matches[1] -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $l = $l.Substring(0, $l.LastIndexOf('[')).Trim()
        }
        $name = $l
        $typeText = 'tekst'
        $colon = $l.LastIndexOf(':')
        if ($colon -gt 0) { $name = $l.Substring(0, $colon).Trim(); $typeText = $l.Substring($colon + 1).Trim() }
        $type = $script:SPColumnTypes[$typeText.ToLowerInvariant()]
        if (-not $type) { $errors.Add("nieznany typ «$typeText» (np. Tekst, Liczba, Data, Wybór [a, b], Osoba, Tak/Nie)"); $type = '' }
        if (-not $name) { $errors.Add('brak nazwy kolumny') }
        if ($type -in 'Choice', 'MultiChoice' -and $choices.Count -eq 0) { $errors.Add('podaj opcje wyboru w nawiasie: [opcja 1, opcja 2]') }
        $internal = ConvertTo-HTSPUrlName -Title $name -MaxLength 32
        if ($internal -match '^\d') { $internal = "Pole$internal" }
        if ($name -and -not $internal) { $errors.Add('nazwa musi zawierać litery lub cyfry') }
        if ($internal -and $seen.Contains($internal.ToLowerInvariant())) { $errors.Add('kolumna powtarza się na liście') }
        if ($internal) { $seen.Add($internal.ToLowerInvariant()) }
        @{ DisplayName = $name; InternalName = $internal; Type = $type; Choices = $choices; Required = $required; Errors = $errors.ToArray(); Valid = ($errors.Count -eq 0) }
    }
}
#endregion

#region Ustawienia bibliotek (formularz i zmiany)
$script:SPKeep = '(bez zmian)'
$script:LibrarySettingDefs = @(
    @{ Key = 'Title'; Label = 'Nazwa biblioteki'; Type = 'Text'; SingleOnly = $true }
    @{ Key = 'Description'; Label = 'Opis'; Type = 'Text' }
    @{ Key = 'EnableVersioning'; Label = 'Historia wersji'; Type = 'Bool' }
    @{ Key = 'MajorVersions'; Label = 'Limit wersji głównych (100-50000)'; Type = 'Int'; Min = 100; Max = 50000; Read = 'MajorVersionLimit' }
    @{ Key = 'EnableMinorVersions'; Label = 'Wersje pomocnicze (robocze, np. 1.1)'; Type = 'Bool' }
    @{ Key = 'ForceCheckout'; Label = 'Wymagaj wyewidencjonowania przed edycją'; Type = 'Bool' }
    @{ Key = 'EnableModeration'; Label = 'Zatwierdzanie zawartości'; Type = 'Bool' }
    @{ Key = 'OnQuickLaunch'; Label = 'Pokaż w menu witryny'; Type = 'Bool' }
    @{ Key = 'NoCrawl'; Label = 'Wyklucz z wyszukiwania'; Type = 'Bool' }
    @{ Key = 'Hidden'; Label = 'Ukryta (niewidoczna w zawartości witryny)'; Type = 'Bool' }
)

function New-HTSPLibrarySettingsFields {
    # Pola formularza ustawień bibliotek: jedna biblioteka - bieżące wartości, wiele - «(bez zmian)»; -Values - wpisane wcześniej
    param ([System.Collections.IDictionary]$Current = $null, [System.Collections.IDictionary]$Values = $null)
    $keep = $script:SPKeep
    foreach ($d in $script:LibrarySettingDefs) {
        if ($d.SingleOnly -and -not $Current) { continue }
        $cur = if ($Current) { $Current[$d.Key] } else { $null }
        $f = switch ($d.Type) {
            'Bool' { @{ Name = $d.Key; Label = $d.Label; Type = 'Combo'; Options = $(if ($Current) { @('Tak', 'Nie') } else { @($keep, 'Tak', 'Nie') }); Default = $(if ($Current) { if ($cur) { 'Tak' } else { 'Nie' } } else { $keep }) } }
            'Int' { @{ Name = $d.Key; Label = $d.Label; Default = $(if ($Current) { [string]$cur } else { '' }); Placeholder = $(if ($Current) { '' } else { $keep }) } }
            default { @{ Name = $d.Key; Label = $d.Label; Default = $(if ($Current) { [string]$cur } else { '' }); Placeholder = $(if ($Current) { '' } else { $keep }); Required = [bool]$d.SingleOnly } }
        }
        if ($Values -and $Values.Contains($d.Key)) { $f.Default = $Values[$d.Key] }
        $f
    }
}

function Get-HTSPLibrarySettingChanges {
    # Zmiany ustawień biblioteki: @{ Settings = @{ Klucz = wartość }; Display = @(); Errors = @() }
    param ([Parameter(Mandatory)][System.Collections.IDictionary]$Form, [System.Collections.IDictionary]$Current = $null)
    $settings = [ordered]@{}
    $display = New-Object System.Collections.Generic.List[string]
    $errors = New-Object System.Collections.Generic.List[string]
    foreach ($d in $script:LibrarySettingDefs) {
        if (-not $Form.Contains($d.Key)) { continue }
        $text = ([string]$Form[$d.Key]).Trim()
        if ($text -eq $script:SPKeep -or (-not $text -and $d.Type -ne 'Text')) { continue }
        if (-not $text -and -not $Current) { continue }
        $value = $null
        if ($d.Type -eq 'Bool') { $value = ($text -eq 'Tak') }
        elseif ($d.Type -eq 'Int') {
            $n = 0
            if (-not [int]::TryParse($text, [ref]$n) -or $n -lt $d.Min -or $n -gt $d.Max) { $errors.Add("$($d.Label): podaj liczbę od $($d.Min) do $($d.Max)"); continue }
            $value = $n
        }
        else {
            if ($d.SingleOnly -and -not $text) { $errors.Add("$($d.Label): pole wymagane"); continue }
            $value = $text
        }
        if ($Current -and [string]$Current[$d.Key] -ceq [string]$value) { continue }
        $settings[$d.Key] = $value
        $display.Add("$($d.Label): $(if ($value -is [bool]) { if ($value) { 'Tak' } else { 'Nie' } } else { $value })")
    }
    return @{ Settings = $settings; Display = $display.ToArray(); Errors = $errors.ToArray() }
}
#endregion

#region Poziomy uprawnień i grupy witryny (PnP)
function Get-HTSPRoleDefinitionList {
    return @(Get-PnPRoleDefinition -ErrorAction Stop | Where-Object { -not $_.Hidden } | ForEach-Object { @{ Name = [string]$_.Name; RoleTypeKind = [string]$_.RoleTypeKind } })
}

function Get-HTSPPrincipalResolver {
    # Grupy witryny (nazwy) i grupy przypisane (właściciele, członkowie, odwiedzający) do rozpoznawania podmiotów
    $groups = @(Get-PnPGroup -ErrorAction Stop | ForEach-Object { [string]$_.Title })
    $assoc = @{}
    foreach ($pair in @(@('Owner', 'AssociatedOwnerGroup'), @('Member', 'AssociatedMemberGroup'), @('Visitor', 'AssociatedVisitorGroup'))) {
        try {
            $params = @{ ErrorAction = 'Stop' }
            $params[$pair[1]] = $true
            $g = Get-PnPGroup @params
            if ($g) { $assoc[$pair[0]] = [string]$g.Title }
        }
        catch { Write-Log -Message "Grupa przypisana witryny ($($pair[0])): $($_.Exception.Message)" -Type 'Warn' }
    }
    return @{ Groups = $groups; Associated = $assoc }
}

function Set-HTSPNodeAccess {
    <#
        Uprawnienia węzła: przerwanie dziedziczenia (gdy jeszcze dziedziczy; -CopyExisting - z kopią obecnych uprawnień),
        nadanie (-Grants @(@{ Principal; Role })) i odebranie (-Removes) dostępu. Zwraca opis.
    #>
    param (
        [Parameter(Mandatory)][object]$Node,
        [AllowEmptyCollection()][object[]]$Grants = @(),
        [AllowEmptyCollection()][string[]]$Removes = @(),
        [bool]$CopyExisting = $true,
        [object[]]$Roles,
        [hashtable]$Resolver
    )
    if (-not $Roles) { $Roles = @(Get-HTSPRoleDefinitionList) }
    if (-not $Resolver) { $Resolver = Get-HTSPPrincipalResolver }
    $notes = New-Object System.Collections.Generic.List[string]
    if (-not (Test-HTSPUniquePermissions -Node $Node)) {
        Set-HTSPInheritance -Node $Node -Inherit $false -CopyExisting $CopyExisting
        $notes.Add($(if ($CopyExisting) { 'przerwano dziedziczenie (z kopią uprawnień)' } else { 'przerwano dziedziczenie (bez kopii)' }))
    }
    foreach ($g in @($Grants | Where-Object { $_ })) {
        $p = Resolve-HTSPPrincipal -Principal $g.Principal -Resolver $Resolver
        $role = Resolve-HTSPRoleName -Role $g.Role -Definitions $Roles
        Grant-HTSPPermission -Node $Node -Principal $p.Name -PrincipalType $(if ($p.Kind -eq 'Group') { 'SharePointGroup' } else { 'User' }) -Role $role
        $notes.Add("$($p.Name)=$role")
    }
    foreach ($r in @($Removes | Where-Object { $_ })) {
        $p = Resolve-HTSPPrincipal -Principal $r -Resolver $Resolver
        $notes.Add("-$($p.Name): $(Remove-HTSPPrincipalAccess -Node $Node -Principal $p.Name)")
    }
    return ($notes -join '; ')
}

function Remove-HTSPPrincipalAccess {
    # Odebranie wszystkich poziomów uprawnień podmiotu do węzła; brak uprawnień nie jest błędem
    param ([Parameter(Mandatory)][object]$Node, [Parameter(Mandatory)][string]$Principal)
    $match = @(Get-HTSPPermissions -Node $Node | Where-Object { Test-HTSPPrincipalMatch -Assignment $_ -Principal $Principal })
    if ($match.Count -eq 0) { return 'brak uprawnień' }
    foreach ($a in $match) { Revoke-HTSPPermission -Node $Node -Assignment $a }
    return "odebrano: $(@($match | ForEach-Object { $_.Roles }) -join ', ')"
}

function Set-HTSPPermissionLevel {
    # Zmiana poziomu uprawnień przypisania (odebranie obecnych poziomów i nadanie nowego)
    param ([Parameter(Mandatory)][object]$Node, [Parameter(Mandatory)][object]$Assignment, [Parameter(Mandatory)][string]$Role)
    $isGroup = [string]$Assignment.PrincipalType -eq 'SharePointGroup'
    Revoke-HTSPPermission -Node $Node -Assignment $Assignment
    Grant-HTSPPermission -Node $Node -Principal $(if ($isGroup) { [string]$Assignment.Principal } else { [string]$Assignment.LoginName }) -PrincipalType $(if ($isGroup) { 'SharePointGroup' } else { 'User' }) -Role $Role
}

function Set-HTSPGroupWebRole {
    # Poziom uprawnień grupy SharePoint do całej witryny (nadanie albo odebranie)
    param ([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][string]$Role, [switch]$Remove)
    if ($Remove) { Set-PnPGroupPermissions -Identity $Group -RemoveRole $Role -ErrorAction Stop }
    else { Set-PnPGroupPermissions -Identity $Group -AddRole $Role -ErrorAction Stop }
}

function Get-HTSPGroupOptions {
    # Bieżące ustawienia grupy SharePoint (klucze jak parametry Set-PnPGroup)
    param ([Parameter(Mandatory)][string]$Group)
    $g = Get-PnPGroup -Identity $Group -ErrorAction Stop
    return [ordered]@{
        Owner                          = [string]$g.OwnerTitle
        Description                    = [string]$g.Description
        AllowMembersEditMembership     = [bool]$g.AllowMembersEditMembership
        OnlyAllowMembersViewMembership = [bool]$g.OnlyAllowMembersViewMembership
        AllowRequestToJoinLeave        = [bool]$g.AllowRequestToJoinLeave
        AutoAcceptRequestToJoinLeave   = [bool]$g.AutoAcceptRequestToJoinLeave
    }
}

function Set-HTSPGroupOptions {
    # Ustawienia grupy SharePoint: nazwa, opis, właściciel, kto widzi i zmienia członków, prośby o dołączenie
    param ([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][hashtable]$Settings)
    $params = @{ Identity = $Group; ErrorAction = 'Stop' }
    foreach ($k in $Settings.Keys) { $params[$k] = $Settings[$k] }
    Set-PnPGroup @params
}

function Remove-HTSPGroup {
    param ([Parameter(Mandatory)][string]$Group)
    Remove-PnPGroup -Identity $Group -Force -ErrorAction Stop
}
#endregion

#region Uprawnienia witryny i administratorzy kolekcji (PnP)
function Get-HTSPWebPermissions {
    # Przypisania uprawnień całej witryny (bez «Ograniczony dostęp»)
    $web = Get-PnPWeb -Includes RoleAssignments -ErrorAction Stop
    $limited = @('Limited Access', 'Ograniczony dostęp', 'Web-Only Limited Access')
    foreach ($a in $web.RoleAssignments) {
        Get-PnPProperty -ClientObject $a -Property Member, RoleDefinitionBindings | Out-Null
        $roles = @($a.RoleDefinitionBindings | ForEach-Object { $_.Name } | Where-Object { $limited -notcontains $_ })
        if ($roles.Count -eq 0) { continue }
        [PSCustomObject]@{ Principal = $a.Member.Title; LoginName = $a.Member.LoginName; PrincipalType = "$($a.Member.PrincipalType)"; Roles = $roles -join ', '; Email = $(try { $a.Member.Email } catch { '' }) }
    }
}

function Grant-HTSPWebPermission {
    param ([Parameter(Mandatory)][string]$Principal, [Parameter(Mandatory)][ValidateSet('User', 'SharePointGroup')][string]$PrincipalType, [Parameter(Mandatory)][string]$Role)
    if ($PrincipalType -eq 'SharePointGroup') { Set-PnPWebPermission -Group $Principal -AddRole $Role -ErrorAction Stop }
    else { Set-PnPWebPermission -User $Principal -AddRole $Role -ErrorAction Stop }
}

function Revoke-HTSPWebPermission {
    param ([Parameter(Mandatory)][object]$Assignment)
    $isGroup = [string]$Assignment.PrincipalType -eq 'SharePointGroup'
    foreach ($role in @(([string]$Assignment.Roles) -split ',\s*' | Where-Object { $_ })) {
        if ($isGroup) { Set-PnPWebPermission -Group $Assignment.Principal -RemoveRole $role -ErrorAction Stop }
        else { Set-PnPWebPermission -User $Assignment.LoginName -RemoveRole $role -ErrorAction Stop }
    }
}

function Get-HTSPSiteAdmins {
    return @(Get-PnPSiteCollectionAdmin -ErrorAction Stop | ForEach-Object { [PSCustomObject]@{ Principal = $_.Title; Email = $_.Email; LoginName = $_.LoginName; PrincipalType = "$($_.PrincipalType)" } })
}

function Add-HTSPSiteAdmin {
    param ([Parameter(Mandatory)][string[]]$Users)
    Add-PnPSiteCollectionAdmin -Owners @($Users) -ErrorAction Stop
}

function Remove-HTSPSiteAdmin {
    param ([Parameter(Mandatory)][string]$User)
    Remove-PnPSiteCollectionAdmin -Owners @($User) -ErrorAction Stop
}

function Get-HTSPUserAccessReport {
    <#
        Gdzie użytkownik ma dostęp w połączonej witrynie: administrator kolekcji, członkostwo w grupach SharePoint,
        uprawnienia witryny i bibliotek / folderów z unikalnymi uprawnieniami (do -Depth poziomów) - bezpośrednio
        albo przez grupę SharePoint. Dostęp przez grupy Entra ID nie jest rozwijany.
        Wiersze: Obiekt, Ścieżka, Uprawnienia, Przez, __kind (Admin|GroupMember|Web|Node), __node, __assignment, __group.
    #>
    param ([Parameter(Mandatory)][string]$Login, [ValidateRange(0, 10)][int]$Depth = 2, [scriptblock]$OnProgress)
    $memberOf = New-Object System.Collections.Generic.List[string]
    foreach ($g in @(Get-PnPGroup -ErrorAction Stop)) {
        try {
            $hit = @(Get-PnPGroupMember -Group $g.Title -ErrorAction Stop | Where-Object { Test-HTSPPrincipalMatch -Assignment @{ Principal = $_.Title; LoginName = $_.LoginName; Email = $_.Email } -Principal $Login })
            if ($hit.Count) { $memberOf.Add([string]$g.Title) }
        }
        catch { Write-Log -Message "Członkowie grupy $($g.Title): $($_.Exception.Message)" -Type 'Warn' }
    }
    $url = (Get-PnPWeb -ErrorAction Stop).ServerRelativeUrl
    try {
        foreach ($a in @(Get-HTSPSiteAdmins | Where-Object { Test-HTSPPrincipalMatch -Assignment $_ -Principal $Login })) {
            [PSCustomObject]@{ Obiekt = 'Kolekcja witryn'; Ścieżka = $url; Uprawnienia = 'Administrator kolekcji witryn'; Przez = 'bezpośrednio'; __kind = 'Admin'; __node = $null; __assignment = $a; __group = ''; __flag = 'warn' }
        }
    }
    catch { Write-Log -Message "Administratorzy kolekcji: $($_.Exception.Message)" -Type 'Warn' }
    foreach ($g in $memberOf) { [PSCustomObject]@{ Obiekt = 'Grupa SharePoint'; Ścieżka = $g; Uprawnienia = '(członek)'; Przez = $g; __kind = 'GroupMember'; __node = $null; __assignment = $null; __group = $g; __flag = '' } }
    $describe = {
        param($a)
        if (Test-HTSPPrincipalMatch -Assignment $a -Principal $Login) { return 'bezpośrednio' }
        if ([string]$a.PrincipalType -eq 'SharePointGroup' -and $memberOf.Contains([string]$a.Principal)) { return "grupa: $($a.Principal)" }
        return ''
    }
    foreach ($a in @(Get-HTSPWebPermissions)) {
        $via = & $describe $a
        if ($via) { [PSCustomObject]@{ Obiekt = 'Witryna'; Ścieżka = $url; Uprawnienia = $a.Roles; Przez = $via; __kind = 'Web'; __node = $null; __assignment = $a; __group = $(if ($via -like 'grupa:*') { $a.Principal } else { '' }); __flag = '' } }
    }
    foreach ($entry in @(Get-HTSPUniqueNodes -Depth $Depth -OnProgress $OnProgress)) {
        if ($entry.Error) { continue }
        foreach ($a in @($entry.Permissions)) {
            $via = & $describe $a
            if (-not $via) { continue }
            [PSCustomObject]@{ Obiekt = $(if ($entry.Node.IsLibrary) { 'Biblioteka' } else { 'Folder' }); Ścieżka = $entry.Node.ServerRelativeUrl; Uprawnienia = $a.Roles; Przez = $via; __kind = 'Node'; __node = $entry.Node; __assignment = $a; __group = $(if ($via -like 'grupa:*') { $a.Principal } else { '' }); __flag = '' }
        }
    }
}
#endregion

#region Biblioteki i kolumny (PnP)
function New-HTSPLibrary {
    <#
        Nowa biblioteka dokumentów (albo lista): adres bez polskich znaków (-Url, domyślnie z nazwy), menu witryny,
        historia wersji z limitem, wersje pomocnicze, wymagane wyewidencjonowanie, zatwierdzanie. Zwraca węzeł biblioteki.
    #>
    param (
        [Parameter(Mandatory)][string]$Title,
        [ValidateSet('DocumentLibrary', 'GenericList')][string]$Template = 'DocumentLibrary',
        [string]$Url = '',
        [string]$Description = '',
        [bool]$OnQuickLaunch = $true,
        [bool]$Versioning = $true,
        [int]$MajorVersions = 0,
        [bool]$MinorVersions = $false,
        [bool]$ForceCheckout = $false,
        [bool]$Approval = $false
    )
    $urlName = if ($Url) { $Url } else { ConvertTo-HTSPUrlName -Title $Title }
    $params = @{ Title = $Title; Template = $Template; ErrorAction = 'Stop' }
    if ($urlName) { $params.Url = $(if ($Template -eq 'GenericList') { "Lists/$urlName" } else { $urlName }) }
    if ($OnQuickLaunch) { $params.OnQuickLaunch = $true }
    if ($Versioning) { $params.EnableVersioning = $true }
    $list = New-PnPList @params
    $set = @{}
    if ($Description) { $set.Description = $Description }
    if ($Versioning -and $MajorVersions -gt 0) { $set.MajorVersions = $MajorVersions }
    if ($MinorVersions) { $set.EnableMinorVersions = $true }
    if ($ForceCheckout) { $set.ForceCheckout = $true }
    if ($Approval) { $set.EnableModeration = $true }
    if ($set.Count) { Set-PnPList -Identity $Title @set -ErrorAction Stop | Out-Null }
    $root = Get-PnPProperty -ClientObject $list -Property RootFolder
    # IsLibrary - obiekt uprawnień na poziomie listy (także dla zwykłej listy)
    return [PSCustomObject]@{ Title = [string]$list.Title; ServerRelativeUrl = [string]$root.ServerRelativeUrl; ListTitle = [string]$list.Title; ListId = [string]$list.Id; IsLibrary = $true; ItemCount = 0 }
}

function Get-HTSPLibrarySettings {
    # Ustawienia biblioteki: wiersz do tabeli i wartości (__values) do formularza
    param ([Parameter(Mandatory)][object]$Node)
    $list = Get-PnPList -Identity (Get-HTSPListRef -Node $Node) -ErrorAction Stop
    Get-PnPProperty -ClientObject $list -Property Title, Description, EnableVersioning, MajorVersionLimit, EnableMinorVersions, ForceCheckout, EnableModeration, OnQuickLaunch, NoCrawl, Hidden, ItemCount, Created, LastItemUserModifiedDate, HasUniqueRoleAssignments | Out-Null
    $values = [ordered]@{
        Title = [string]$list.Title; Description = [string]$list.Description; EnableVersioning = [bool]$list.EnableVersioning; MajorVersions = [int]$list.MajorVersionLimit
        EnableMinorVersions = [bool]$list.EnableMinorVersions; ForceCheckout = [bool]$list.ForceCheckout; EnableModeration = [bool]$list.EnableModeration
        OnQuickLaunch = [bool]$list.OnQuickLaunch; NoCrawl = [bool]$list.NoCrawl; Hidden = [bool]$list.Hidden
    }
    $yes = { param($b) if ($b) { 'Tak' } else { 'Nie' } }
    return [PSCustomObject]@{
        Biblioteka                = $values.Title
        Elementy                  = $list.ItemCount
        'Historia wersji'         = (& $yes $values.EnableVersioning)
        'Limit wersji'            = $(if ($values.EnableVersioning) { $values.MajorVersions } else { '' })
        'Wersje pomocnicze'       = (& $yes $values.EnableMinorVersions)
        'Wymagane wyewidencjonowanie' = (& $yes $values.ForceCheckout)
        Zatwierdzanie             = (& $yes $values.EnableModeration)
        'W menu witryny'          = (& $yes $values.OnQuickLaunch)
        'Wykluczona z wyszukiwania' = (& $yes $values.NoCrawl)
        'Unikalne uprawnienia'    = (& $yes $list.HasUniqueRoleAssignments)
        Utworzono                 = $list.Created
        'Ostatnia zmiana'         = $list.LastItemUserModifiedDate
        Opis                      = $values.Description
        __values                  = $values
        __flag                    = $(if (-not $values.EnableVersioning -or $values.NoCrawl) { 'warn' } else { '' })
    }
}

function Set-HTSPLibrarySettings {
    # Zapis ustawień (klucze jak w Get-HTSPLibrarySettingChanges); menu witryny i wyszukiwanie - osobno (CSOM / przełącznik)
    param ([Parameter(Mandatory)][object]$Node, [Parameter(Mandatory)][System.Collections.IDictionary]$Settings)
    $set = @{}
    foreach ($k in $Settings.Keys) { if ($k -notin 'OnQuickLaunch', 'NoCrawl') { $set[$k] = $Settings[$k] } }
    if ($Settings.Contains('NoCrawl')) { $set.NoCrawl = [bool]$Settings['NoCrawl'] }
    if ($set.Count) { Set-PnPList -Identity (Get-HTSPListRef -Node $Node) @set -ErrorAction Stop | Out-Null }
    if ($Settings.Contains('OnQuickLaunch')) {
        # Po zmianie nazwy - nowy tytuł (identyfikator listy się nie zmienia)
        $ref = if (Get-HTSPListId -Node $Node) { Get-HTSPListRef -Node $Node } elseif ($Settings.Contains('Title')) { [string]$Settings['Title'] } else { $Node.ListTitle }
        $list = Get-PnPList -Identity $ref -ErrorAction Stop
        $list.OnQuickLaunch = [bool]$Settings['OnQuickLaunch']
        $list.Update()
        Invoke-PnPQuery -ErrorAction Stop
    }
    return "Zmieniono: $(@($Settings.Keys) -join ', ')"
}

function Remove-HTSPLibrary {
    # Usunięcie biblioteki do kosza witryny (przywrócenie: SharePoint > Kosz witryny)
    param ([Parameter(Mandatory)][object]$Node)
    Remove-PnPList -Identity (Get-HTSPListRef -Node $Node) -Recycle -Force -ErrorAction Stop | Out-Null
}

function Get-HTSPLibraryColumns {
    # Kolumny dodane do biblioteki (bez systemowych i ukrytych)
    param ([Parameter(Mandatory)][object]$Node)
    foreach ($f in @(Get-PnPField -List (Get-HTSPListRef -Node $Node) -ErrorAction Stop)) {
        if ($f.Hidden -or $f.ReadOnlyField -or $f.FromBaseType -or -not $f.CanBeDeleted) { continue }
        $choices = if ($f.PSObject.Properties['Choices']) { @($f.Choices) -join ', ' } else { '' }
        [PSCustomObject]@{ Kolumna = $f.Title; 'Nazwa wewnętrzna' = $f.InternalName; Typ = $f.TypeDisplayName; Wymagana = [bool]$f.Required; Opcje = $choices; Grupa = $f.Group; __id = [string]$f.Id; __list = (Get-HTSPListRef -Node $Node) }
    }
}

function Add-HTSPLibraryColumn {
    # Nowa kolumna biblioteki z ConvertFrom-HTSPColumnSpec (dodawana do widoku domyślnego)
    param ([Parameter(Mandatory)][object]$Node, [Parameter(Mandatory)][hashtable]$Column)
    $params = @{ List = (Get-HTSPListRef -Node $Node); DisplayName = $Column.DisplayName; InternalName = $Column.InternalName; Type = $Column.Type; AddToDefaultView = $true; ErrorAction = 'Stop' }
    if ($Column.Required) { $params.Required = $true }
    if ($Column.Type -in 'Choice', 'MultiChoice') { $params.Choices = @($Column.Choices) }
    Add-PnPField @params | Out-Null
}

function Remove-HTSPLibraryColumn {
    param ([Parameter(Mandatory)][string]$ListTitle, [Parameter(Mandatory)][string]$Field)
    Remove-PnPField -List $ListTitle -Identity $Field -Force -ErrorAction Stop
}
#endregion

#region Struktura folderów: odczyt i wykonanie (PnP)
function Get-HTSPFolderTreeText {
    <#
        Struktura folderów węzła (bez plików) w składni struktury - do zapisania jako szablon albo powielenia
        w innych miejscach. -IncludePermissions - foldery z unikalnymi uprawnieniami dostają «|! podmiot=poziom».
        Bez -Node - cała witryna (pierwszy poziom - biblioteki).
    #>
    param ([object]$Node, [ValidateRange(0, 10)][int]$Depth = 3, [switch]$IncludePermissions, [scriptblock]$OnProgress)
    $lines = New-Object System.Collections.Generic.List[string]
    $walk = $null
    $walk = {
        param($n, [int]$level)
        if ($OnProgress) { & $OnProgress $n.ServerRelativeUrl }
        $grants = @()
        $unique = $false
        if ($IncludePermissions) {
            try {
                if (Test-HTSPUniquePermissions -Node $n) {
                    $unique = $true
                    $grants = @(Get-HTSPPermissions -Node $n | ForEach-Object { $who = ConvertTo-HTSPPrincipalText -Assignment $_; foreach ($r in @(([string]$_.Roles) -split ',\s*')) { @{ Principal = $who; Role = $r } } })
                }
            }
            catch { Write-Log -Message "Uprawnienia $($n.ServerRelativeUrl): $($_.Exception.Message)" -Type 'Warn' }
        }
        if ($level -ge 0) { $lines.Add((ConvertTo-HTSPStructureLine -Name $n.Title -Level $level -Grants $grants -Unique:$unique)) }
        if ($level -ge $Depth) { return }
        foreach ($child in @(Get-HTSPSubFolders -ServerRelativeUrl $n.ServerRelativeUrl -ListTitle $n.ListTitle -ListId (Get-HTSPListId -Node $n))) { & $walk $child ($level + 1) }
    }
    if ($Node) { foreach ($child in @(Get-HTSPSubFolders -ServerRelativeUrl $Node.ServerRelativeUrl -ListTitle $Node.ListTitle -ListId (Get-HTSPListId -Node $Node))) { & $walk $child 0 } }
    else { foreach ($lib in @(Get-HTSPLibraries)) { & $walk $lib 0 } }
    return ($lines -join "`r`n")
}

function Invoke-HTSPStructure {
    <#
        Utworzenie struktury (Items z ConvertFrom-HTSPStructureText) w węźle -BaseNode (biblioteka albo folder), a bez niego
        w witrynie - pierwszy poziom to biblioteki (tworzone, gdy ich brak). Istniejące foldery są pomijane (uprawnienia
        z linii są dla nich uzupełniane). -WhatIf - tylko podgląd. Najpierw sprawdzane są poziomy uprawnień.
        Wiersze: Lokalizacja, Ścieżka, Element, Akcja, Status, Szczegóły. OnProgress: { param($Index, $Total, $Path) }.
    #>
    param ([Parameter(Mandatory)][object[]]$Items, [object]$BaseNode, [switch]$WhatIf, [scriptblock]$OnProgress)
    $roles = @(Get-HTSPRoleDefinitionList)
    $resolver = Get-HTSPPrincipalResolver
    $problems = New-Object System.Collections.Generic.List[string]
    foreach ($it in $Items) {
        foreach ($g in @($it.Grants)) {
            try { $null = Resolve-HTSPRoleName -Role $g.Role -Definitions $roles } catch { $problems.Add("$($it.Path): $($_.Exception.Message)") }
            try { $null = Resolve-HTSPPrincipal -Principal $g.Principal -Resolver $resolver } catch { $problems.Add("$($it.Path): $($_.Exception.Message)") }
        }
    }
    if ($problems.Count) { throw "Popraw uprawnienia w strukturze: $(@($problems | Select-Object -Unique) -join '; ')" }
    $webUrl = Get-HTSPWebUrl
    $location = if ($BaseNode) { [string]$BaseNode.ServerRelativeUrl } else { 'witryna' }
    $libraries = @{}
    if (-not $BaseNode) { foreach ($l in @(Get-HTSPLibraries)) { $libraries[$l.Title.ToLowerInvariant()] = $l } }
    $i = 0
    foreach ($it in $Items) {
        $i++
        if ($OnProgress) { & $OnProgress $i $Items.Count $it.Path }
        $segments = @(([string]$it.Path) -split '/')
        $row = [ordered]@{ Lokalizacja = $location; Ścieżka = $it.Path; Element = 'Folder'; Akcja = ''; Status = 'OK'; Szczegóły = '' }
        try {
            $node = $null
            if (-not $BaseNode -and $segments.Count -eq 1) {
                $row.Element = 'Biblioteka'
                $key = $segments[0].ToLowerInvariant()
                if ($libraries.ContainsKey($key)) { $row.Akcja = 'Istnieje' }
                elseif ($WhatIf) { $row.Akcja = 'Utworzy bibliotekę' }
                else { $libraries[$key] = New-HTSPLibrary -Title $segments[0]; $row.Akcja = 'Utworzono bibliotekę' }
                $node = $libraries[$key]
            }
            else {
                if ($BaseNode) {
                    $listTitle = [string]$BaseNode.ListTitle
                    $base = ConvertTo-HTSPSiteRelativeUrl -ServerRelativeUrl $BaseNode.ServerRelativeUrl -WebUrl $webUrl
                    $relative = $it.Path
                }
                else {
                    $lib = $libraries[$segments[0].ToLowerInvariant()]
                    if (-not $lib) {
                        if (-not $WhatIf) { throw "Brak biblioteki $($segments[0])" }
                        $lib = @{ Title = $segments[0]; ListTitle = $segments[0]; ServerRelativeUrl = "$webUrl/$(ConvertTo-HTSPUrlName -Title $segments[0])" }
                    }
                    $listTitle = [string]$lib.ListTitle
                    $base = ConvertTo-HTSPSiteRelativeUrl -ServerRelativeUrl $lib.ServerRelativeUrl -WebUrl $webUrl
                    $relative = ($segments | Select-Object -Skip 1) -join '/'
                }
                $siteRelative = "$base/$relative"
                $exists = $true
                try { Get-PnPFolder -Url $siteRelative -ErrorAction Stop | Out-Null } catch { $exists = $false }
                if ($exists) { $row.Akcja = 'Istnieje' }
                elseif ($WhatIf) { $row.Akcja = 'Utworzy folder' }
                else { Resolve-PnPFolder -SiteRelativePath $siteRelative -ErrorAction Stop | Out-Null; $row.Akcja = 'Utworzono folder' }
                $node = @{ Title = $segments[-1]; ListTitle = $listTitle; IsLibrary = $false; ServerRelativeUrl = "$webUrl/$siteRelative" }
            }
            if ($it.Break) {
                $planned = @(@($it.Grants | ForEach-Object { "$($_.Principal)=$($_.Role)" }) + @($it.Removes | ForEach-Object { "-$_" })) -join '; '
                if ($WhatIf) { $row.Szczegóły = "Uprawnienia$(if (-not $it.Copy) { ' (bez kopii obecnych)' }): $planned" }
                elseif ($row.Akcja -eq 'Utworzy folder') { $row.Szczegóły = $planned }
                else { $row.Szczegóły = Set-HTSPNodeAccess -Node $node -Grants @($it.Grants) -Removes @($it.Removes) -CopyExisting ([bool]$it.Copy) -Roles $roles -Resolver $resolver }
            }
        }
        catch { $row.Status = 'Błąd'; $row.Szczegóły = $_.Exception.Message; $row['__flag'] = 'crit' }
        if ($WhatIf -and $row.Status -eq 'OK') { $row.Status = 'Podgląd' }
        if ($row.Akcja -eq 'Istnieje' -and $row.Status -ne 'Błąd' -and -not $it.Break) { $row['__flag'] = 'muted' }
        [PSCustomObject]$row
    }
}
#endregion

#region Pliki: wyewidencjonowane, wyszukiwanie, kopiowanie i przenoszenie, wysyłanie z dysku (PnP)
function Get-HTSPListFileItems {
    # Pliki biblioteki (stronicowanie - działa ponad progiem 5000 elementów), opcjonalnie tylko w folderze węzła
    param ([Parameter(Mandatory)][object]$Node, [string[]]$Fields = @(), [int]$MaxItems = 50000)
    $all = @('FileLeafRef', 'FileRef', 'FSObjType') + @($Fields) | Select-Object -Unique
    $prefix = if ($Node.IsLibrary) { '' } else { ([string]$Node.ServerRelativeUrl).TrimEnd('/') + '/' }
    $count = 0
    foreach ($item in @(Get-PnPListItem -List (Get-HTSPListRef -Node $Node) -PageSize 2000 -Fields $all -ErrorAction Stop)) {
        $v = $item.FieldValues
        if ([string]$v.FSObjType -ne '0') { continue }
        if ($prefix -and -not ([string]$v.FileRef).StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $count++
        if ($count -gt $MaxItems) { break }
        $v
    }
}

function Get-HTSPCheckedOutFiles {
    # Pliki wyewidencjonowane (zablokowane do edycji przez inną osobę) i pliki bez wersji zaewidencjonowanej
    param ([Parameter(Mandatory)][object]$Node)
    foreach ($v in @(Get-HTSPListFileItems -Node $Node -Fields @('CheckoutUser', 'Modified', 'File_x0020_Size'))) {
        $co = $v.CheckoutUser
        if (-not $co) { continue }
        $who = if ($co.LookupValue) { "$($co.LookupValue)$(if ($co.Email) { " <$($co.Email)>" })" } else { [string]$co }
        [PSCustomObject]@{ Plik = $v.FileLeafRef; Folder = ([string]$v.FileRef).Substring(0, ([string]$v.FileRef).LastIndexOf('/')); Wyewidencjonował = $who; Zmieniono = $v.Modified; Rozmiar = (Format-HTBytes $v.File_x0020_Size); Stan = 'Wyewidencjonowany'; __url = [string]$v.FileRef; __list = (Get-HTSPListRef -Node $Node); __kind = 'CheckedOut' }
    }
    try {
        $list = Get-PnPList -Identity (Get-HTSPListRef -Node $Node) -ErrorAction Stop
        $files = $list.GetCheckedOutFiles()
        $ctx = Get-PnPContext
        $ctx.Load($files)
        Invoke-PnPQuery -ErrorAction Stop
        $prefix = if ($Node.IsLibrary) { '' } else { ([string]$Node.ServerRelativeUrl).TrimEnd('/') + '/' }
        foreach ($f in $files) {
            $path = [string]$f.ServerRelativePath.DecodedUrl
            if ($prefix -and -not $path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            $by = ''
            try { $by = [string](Get-PnPProperty -ClientObject $f -Property CheckedOutBy).Title } catch { $by = [string]$f.CheckedOutById }
            [PSCustomObject]@{ Plik = $path.Substring($path.LastIndexOf('/') + 1); Folder = $path.Substring(0, $path.LastIndexOf('/')); Wyewidencjonował = $by; Zmieniono = $null; Rozmiar = ''; Stan = 'Bez wersji zaewidencjonowanej (widzi go tylko ta osoba)'; __url = $path; __list = (Get-HTSPListRef -Node $Node); __kind = 'NoVersion'; __flag = 'warn' }
        }
    }
    catch { Write-Log -Message "Pliki bez wersji zaewidencjonowanej ($($Node.ListTitle)): $($_.Exception.Message)" -Type 'Warn' }
}

function Submit-HTSPFileCheckIn {
    param ([Parameter(Mandatory)][string]$Url, [string]$Comment = 'Zaewidencjonowano przez Helpdesk Tools')
    Set-PnPFileCheckedIn -Url $Url -CheckinType MajorCheckIn -Comment $Comment -ErrorAction Stop
}

function Undo-HTSPFileCheckOut {
    # Odrzucenie wyewidencjonowania (zmiany osoby, która wyewidencjonowała plik, zostaną utracone)
    param ([Parameter(Mandatory)][string]$Url)
    Undo-PnPFileCheckedOut -Url $Url -ErrorAction Stop
}

function Invoke-HTSPCheckOutTakeover {
    # Przejęcie pliku bez wersji zaewidencjonowanej (potem można go zaewidencjonować)
    param ([Parameter(Mandatory)][string]$ListTitle, [Parameter(Mandatory)][string]$Url)
    $list = Get-PnPList -Identity $ListTitle -ErrorAction Stop
    $files = $list.GetCheckedOutFiles()
    $ctx = Get-PnPContext
    $ctx.Load($files)
    Invoke-PnPQuery -ErrorAction Stop
    $file = @($files | Where-Object { [string]$_.ServerRelativePath.DecodedUrl -ieq $Url })[0]
    if (-not $file) { throw "Nie znaleziono pliku $Url na liście plików bez wersji zaewidencjonowanej." }
    $file.TakeOverCheckOut()
    Invoke-PnPQuery -ErrorAction Stop
}

function Find-HTSPFiles {
    # Pliki, których nazwa zawiera tekst (albo pasuje do wzorca z * i ?), w bibliotece lub folderze węzła
    param ([Parameter(Mandatory)][object]$Node, [Parameter(Mandatory)][string]$Pattern, [int]$MaxResults = 2000)
    $like = if ($Pattern -match '[\*\?]') { $Pattern } else { "*$Pattern*" }
    $found = 0
    foreach ($v in @(Get-HTSPListFileItems -Node $Node -Fields @('Modified', 'Editor', 'File_x0020_Size'))) {
        if ([string]$v.FileLeafRef -notlike $like) { continue }
        $found++
        if ($found -gt $MaxResults) { Write-Log -Message "Wyszukiwanie plików: pokazano pierwsze $MaxResults wyników." -Type 'Warn'; break }
        $ref = [string]$v.FileRef
        [PSCustomObject]@{ Nazwa = $v.FileLeafRef; Folder = $ref.Substring(0, $ref.LastIndexOf('/')); Zmieniono = $v.Modified; Zmienił = $(if ($v.Editor) { $v.Editor.LookupValue } else { '' }); Rozmiar = (Format-HTBytes $v.File_x0020_Size); ServerRelativeUrl = $ref }
    }
}

function ConvertTo-HTSPServerRelativeUrl {
    <#
        Adres docelowy wpisany przez użytkownika jako adres względny serwera: pełny adres (https://…/sites/x/Dokumenty/A),
        adres względny serwera (/sites/x/Dokumenty/A) albo względny witryny (Dokumenty/A - względem -WebUrl).
    #>
    param ([Parameter(Mandatory)][string]$Url, [AllowEmptyString()][string]$WebUrl = '')
    $u = $Url.Trim()
    if ($u -match '^https?://') { return ([uri]::UnescapeDataString(([uri]$u).AbsolutePath)).TrimEnd('/') }
    if ($u.StartsWith('/')) { return $u.TrimEnd('/') }
    return ("$($WebUrl.TrimEnd('/'))/$($u.TrimStart('/'))").TrimEnd('/')
}

function Copy-HTSPItem {
    # Kopiowanie albo przenoszenie (-Move) pliku lub folderu do folderu docelowego (także w innej witrynie)
    param ([Parameter(Mandatory)][string]$SourceUrl, [Parameter(Mandatory)][string]$TargetFolderUrl, [switch]$Move, [switch]$Overwrite, [switch]$IgnoreVersionHistory)
    $params = @{ SourceUrl = $SourceUrl; TargetUrl = $TargetFolderUrl; Force = $true; ErrorAction = 'Stop' }
    if ($Overwrite) { $params.Overwrite = $true }
    if ($IgnoreVersionHistory) { $params.IgnoreVersionHistory = $true }
    if ($Move) { Move-PnPFile @params | Out-Null } else { Copy-PnPFile @params | Out-Null }
}

function Send-HTSPLocalFolder {
    <#
        Wysłanie folderu z dysku (z podfolderami) do biblioteki / folderu węzła: tworzy folder o tej samej nazwie i całą
        strukturę, -SkipExisting pomija pliki, które już są w SharePoint. Wiersze: Plik, Rozmiar, Status, Szczegóły.
        OnProgress: { param($Index, $Total, $Name) }.
    #>
    param ([Parameter(Mandatory)][string]$LocalPath, [Parameter(Mandatory)][object]$TargetNode, [switch]$SkipExisting, [scriptblock]$OnProgress)
    $root = (Resolve-Path -LiteralPath $LocalPath -ErrorAction Stop).ProviderPath.TrimEnd('\', '/')
    $rootName = Split-Path -Path $root -Leaf
    $nameError = Test-HTSPItemName $rootName
    if ($nameError) { throw "Nazwa folderu «$rootName»: $nameError" }
    $base = (ConvertTo-HTSPSiteRelativeUrl -ServerRelativeUrl $TargetNode.ServerRelativeUrl) + "/$rootName"
    $relativeOf = { param($full) $full.Substring($root.Length).TrimStart('\', '/').Replace('\', '/') }
    $folders = @(Get-ChildItem -LiteralPath $root -Recurse -Directory -ErrorAction Stop | Sort-Object { $_.FullName.Length })
    Resolve-PnPFolder -SiteRelativePath $base -ErrorAction Stop | Out-Null
    foreach ($d in $folders) {
        $rel = & $relativeOf $d.FullName
        $bad = @($rel -split '/' | Where-Object { Test-HTSPItemName $_ })
        if ($bad.Count) { [PSCustomObject]@{ Plik = "$rel/"; Rozmiar = ''; Status = 'Błąd'; Szczegóły = "Nazwa folderu: $(Test-HTSPItemName $bad[0])"; __flag = 'crit' }; continue }
        Resolve-PnPFolder -SiteRelativePath "$base/$rel" -ErrorAction Stop | Out-Null
    }
    $files = @(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction Stop)
    $existing = @{}
    $i = 0
    foreach ($f in $files) {
        $i++
        $rel = & $relativeOf $f.FullName
        if ($OnProgress) { & $OnProgress $i $files.Count $rel }
        $dirRel = if ($rel.Contains('/')) { $rel.Substring(0, $rel.LastIndexOf('/')) } else { '' }
        $folder = if ($dirRel) { "$base/$dirRel" } else { $base }
        $row = [ordered]@{ Plik = $rel; Rozmiar = (Format-HTBytes $f.Length); Status = 'Wysłano'; Szczegóły = '' }
        try {
            $bad = @($rel -split '/' | ForEach-Object { Test-HTSPItemName $_ } | Where-Object { $_ })
            if ($bad.Count) { throw "nazwa: $($bad[0])" }
            if ($SkipExisting) {
                if (-not $existing.ContainsKey($folder)) {
                    $names = @()
                    try { $names = @(Get-PnPFolderItem -FolderSiteRelativeUrl $folder -ItemType File -ErrorAction Stop | ForEach-Object { [string]$_.Name }) } catch { $names = @() }
                    $existing[$folder] = $names
                }
                if (@($existing[$folder] | Where-Object { $_ -ieq $f.Name }).Count) { $row.Status = 'Pominięto'; $row.Szczegóły = 'plik już istnieje'; $row['__flag'] = 'muted'; [PSCustomObject]$row; continue }
            }
            Add-PnPFile -Path $f.FullName -Folder $folder -ErrorAction Stop | Out-Null
        }
        catch { $row.Status = 'Błąd'; $row.Szczegóły = $_.Exception.Message; $row['__flag'] = 'crit' }
        [PSCustomObject]$row
    }
}
#endregion

#region Nowa witryna (PnP)
function New-HTSPSite {
    <#
        Nowa witryna w tenancie połączonej witryny: Team (z grupą Microsoft 365 i Teams-gotowa), TeamNoGroup (zespołu bez
        grupy) albo Communication (komunikacyjna). Adres: https://<tenant>.sharepoint.com/sites/<Alias>. Zwraca adres witryny.
    #>
    param (
        [Parameter(Mandatory)][ValidateSet('Team', 'TeamNoGroup', 'Communication')][string]$Type,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Alias,
        [string]$Description = '',
        [AllowEmptyCollection()][string[]]$Owners = @(),
        [bool]$IsPublic = $false,
        [int]$Lcid = 1045
    )
    if ($Alias -notmatch '^[A-Za-z0-9][A-Za-z0-9\-_]*$') { throw "Alias witryny może zawierać tylko litery bez polskich znaków, cyfry, myślnik i podkreślenie: $Alias" }
    $hostName = ([uri](Get-PnPConnection -ErrorAction Stop).Url).Host
    $url = "https://$hostName/sites/$Alias"
    $owners = @($Owners | Where-Object { $_ })
    $params = @{ Title = $Title; Lcid = $Lcid; ErrorAction = 'Stop' }
    switch ($Type) {
        'Team' {
            $params.Type = 'TeamSite'
            $params.Alias = $Alias
            # Opis przyjmuje tylko witryna zespołu z grupą (opis grupy Microsoft 365)
            if ($Description) { $params.Description = $Description }
            if ($IsPublic) { $params.IsPublic = $true }
            if ($owners.Count) { $params.Owners = $owners }
        }
        'TeamNoGroup' {
            $params.Type = 'TeamSiteWithoutMicrosoft365Group'
            $params.Url = $url
            if ($owners.Count) { $params.Owner = $owners[0] }
        }
        'Communication' {
            $params.Type = 'CommunicationSite'
            $params.Url = $url
            if ($owners.Count) { $params.Owner = $owners[0] }
        }
    }
    $result = New-PnPSite @params
    return $(if ($result) { [string]$result } else { $url })
}
#endregion
