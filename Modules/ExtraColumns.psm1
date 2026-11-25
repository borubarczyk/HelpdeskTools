<#
    Dodatkowe kolumny w widokach: dane obiektu (konto Microsoft 365, grupa, skrzynka, konto i komputer AD, urządzenie
    Intune) dopisywane do wierszy dowolnego modułu - np. stanowisko albo data utworzenia konta w raporcie, który ich nie
    ma. Źródło zna klucze, po których rozpoznaje obiekt w wierszu (Id, UPN, adres, login…), atrybuty do wyboru i
    zapytanie pobierające wszystkie obiekty naraz (jedno zapytanie na źródło zamiast jednego na wiersz; wynik zapamiętany
    na kilka minut). Moduł bez interfejsu - okno wyboru i dopisywanie kolumn do tabeli są w UIComponents.psm1.
#>

$script:ExtraColumnSources = [ordered]@{}
$script:ExtraColumnCache = @{}
$script:ExtraColumnCacheMinutes = 10

#region Rejestr źródeł
function Register-HTExtraColumnSource {
    <#
        -KeyProperties: nazwy właściwości / kolumn wiersza z identyfikatorem obiektu (sprawdzane w kolumnach tabeli,
        w obiekcie wiersza i w obiekcie docelowym __target). -Attributes: klucz atrybutu -> nazwa kolumny.
        -Fetch { param([string[]]$Attributes) }: obiekty @{ Keys = @(identyfikatory); Values = @{ atrybut = wartość } }.
    #>
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Title,
        [string]$Service = '',
        [Parameter(Mandatory)][string[]]$KeyProperties,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Attributes,
        [Parameter(Mandatory)][scriptblock]$Fetch
    )
    $script:ExtraColumnSources[$Key] = @{ Key = $Key; Title = $Title; Service = $Service; KeyProperties = @($KeyProperties); Attributes = $Attributes; Fetch = $Fetch }
}

function Get-HTExtraColumnSources { return $script:ExtraColumnSources }

function Get-HTExtraColumnSource {
    param([Parameter(Mandatory)][string]$Key)
    if ($script:ExtraColumnSources.Contains($Key)) { return $script:ExtraColumnSources[$Key] }
    return $null
}

function ConvertTo-HTExtraColumnSpec {
    # Zapis wyboru: «Źródło|atrybut»
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Attribute)
    return "$Source|$Attribute"
}

function ConvertFrom-HTExtraColumnSpec {
    # «Źródło|atrybut» -> @{ Source; Attribute; Label } albo $null (nieznane źródło lub atrybut)
    param([AllowEmptyString()][string]$Spec)
    $parts = $Spec -split '\|', 2
    if ($parts.Count -ne 2) { return $null }
    $src = Get-HTExtraColumnSource -Key $parts[0]
    if (-not $src -or -not $src.Attributes.Contains($parts[1])) { return $null }
    return [PSCustomObject]@{ Source = $parts[0]; Attribute = $parts[1]; Label = [string]$src.Attributes[$parts[1]]; SourceTitle = $src.Title; Service = $src.Service }
}

function Get-HTExtraColumnChoices {
    # Pozycje okna wyboru: «Źródło › Kolumna» -> spec; -Services: tylko źródła tych usług (pusta usługa - zawsze)
    param([string[]]$Services = @(), [string]$PreferService = '')
    $sources = @($script:ExtraColumnSources.Values | Where-Object { -not $_.Service -or -not @($Services).Count -or @($Services) -contains $_.Service })
    $sources = @($sources | Sort-Object @{ Expression = { if ($PreferService -and $_.Service -eq $PreferService) { 0 } else { 1 } } })
    $choices = [ordered]@{}
    foreach ($s in $sources) { foreach ($a in $s.Attributes.Keys) { $choices["$($s.Title) › $($s.Attributes[$a])"] = ConvertTo-HTExtraColumnSpec -Source $s.Key -Attribute $a } }
    return $choices
}
#endregion

#region Dopasowanie wierszy do obiektów
function ConvertTo-HTExtraColumnKey {
    # Postać klucza do porównań: małe litery, bez «smtp:», adres z «Nazwa <adres>»
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or $Value -is [System.DBNull]) { return @() }
    $items = if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) { @($Value) } else { @($Value) }
    foreach ($i in $items) {
        $text = ([string]$i).Trim()
        if (-not $text) { continue }
        if ($text -match '<([^<>\s]+@[^<>\s]+)>') { $Matches[1].ToLowerInvariant() }
        $text = $text -replace '^(?i)smtp:', ''
        $text.ToLowerInvariant()
    }
}

function New-HTExtraColumnIndex {
    # Indeks: klucz -> wartości obiektu; klucz pasujący do kilku różnych obiektów (np. ta sama nazwa) - pomijany
    param([AllowEmptyCollection()][object[]]$Items = @())
    $index = @{}
    $ambiguous = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($it in @($Items | Where-Object { $_ })) {
        foreach ($k in @(ConvertTo-HTExtraColumnKey $it.Keys | Select-Object -Unique)) {
            if ($ambiguous.Contains($k)) { continue }
            if ($index.ContainsKey($k) -and -not [object]::ReferenceEquals($index[$k], $it.Values)) { [void]$index.Remove($k); [void]$ambiguous.Add($k); continue }
            $index[$k] = $it.Values
        }
    }
    return $index
}

function Get-HTExtraColumnRowKeys {
    <#
        Identyfikatory obiektu w wierszu: kolumny tabeli (-Values), obiekt wiersza (-Object) i jego obiekt docelowy
        (__target), po nazwach z -KeyProperties (kolejność - priorytet). Zwraca klucze w postaci do porównań.
    #>
    param([System.Collections.IDictionary]$Values = @{}, [AllowNull()][object]$Object = $null, [Parameter(Mandatory)][string[]]$KeyProperties)
    $sources = New-Object System.Collections.Generic.List[object]
    if ($Values) { $sources.Add($Values) }
    if ($null -ne $Object) {
        $sources.Add($Object)
        $target = Get-HTExtraColumnProperty -Object $Object -Name '__target'
        if ($null -ne $target) { $sources.Add($target) }
    }
    $keys = New-Object System.Collections.Generic.List[string]
    foreach ($name in $KeyProperties) {
        foreach ($src in $sources) {
            foreach ($k in @(ConvertTo-HTExtraColumnKey (Get-HTExtraColumnProperty -Object $src -Name $name))) { if (-not $keys.Contains($k)) { $keys.Add($k) } }
        }
    }
    return $keys.ToArray()
}

function Get-HTExtraColumnProperty {
    # Wartość właściwości obiektu albo klucza słownika (bez błędu, gdy jej nie ma)
    param([AllowNull()][object]$Object, [Parameter(Mandatory)][string]$Name)
    if ($null -eq $Object) { return $null }
    $base = if ($Object -is [System.Management.Automation.PSObject]) { $Object.PSObject.BaseObject } else { $Object }
    if ($base -is [System.Collections.IDictionary]) { if ($base.Contains($Name)) { return $base[$Name] }; return $null }
    if ($base -is [System.Data.DataRow]) { if ($base.Table.Columns.Contains($Name)) { return $base[$Name] }; return $null }
    $p = $Object.PSObject.Properties[$Name]
    if ($p) { return $p.Value }
    return $null
}

function Find-HTExtraColumnValues {
    # Wartości obiektu dla wiersza: pierwszy klucz wiersza obecny w indeksie; $null - nie dopasowano
    param([Parameter(Mandatory)][hashtable]$Index, [AllowEmptyCollection()][string[]]$Keys = @())
    foreach ($k in $Keys) { if ($Index.ContainsKey($k)) { return $Index[$k] } }
    return $null
}

function Get-HTExtraColumnName {
    # Nazwa nowej kolumny: etykieta atrybutu, a gdy tabela ma już taką kolumnę (nie dodatkową) - z nazwą źródła
    param([Parameter(Mandatory)][string]$Label, [string]$SourceTitle = '', [string[]]$Existing = @(), [string[]]$Own = @())
    if ($Own -contains $Label -or $Existing -notcontains $Label) { return $Label }
    $short = ($SourceTitle -replace '\s*\(.*\)$', '')
    return "$Label ($short)"
}
#endregion

#region Pobieranie danych (pamięć podręczna)
function Get-HTExtraColumnData {
    <#
        Dane źródła dla atrybutów: indeks klucz -> wartości. Wynik zapamiętany na kilka minut; brakujące atrybuty
        dociągane razem z zapamiętanymi (jedno zapytanie). -Refresh - zawsze od nowa.
    #>
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string[]]$Attributes, [switch]$Refresh)
    $src = Get-HTExtraColumnSource -Key $Source
    if (-not $src) { throw "Nieznane źródło kolumn: $Source" }
    $cached = $script:ExtraColumnCache[$Source]
    $fresh = $cached -and -not $Refresh -and ((Get-Date) - $cached.Time).TotalMinutes -lt $script:ExtraColumnCacheMinutes
    $missing = @($Attributes | Where-Object { -not $fresh -or @($cached.Attributes) -notcontains $_ })
    if ($fresh -and -not $missing.Count) { return $cached }
    $all = @(@($Attributes) + $(if ($fresh) { @($cached.Attributes) } else { @() }) | Select-Object -Unique)
    $items = @(& $src.Fetch $all)
    $entry = @{ Time = Get-Date; Attributes = $all; Index = (New-HTExtraColumnIndex -Items $items); Count = $items.Count }
    $script:ExtraColumnCache[$Source] = $entry
    return $entry
}

function Clear-HTExtraColumnCache { $script:ExtraColumnCache = @{} }

function ConvertTo-HTExtraColumnValue {
    # Wartość do komórki: daty jako data, listy - po przecinku
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [string] -and $Value -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}') { $d = [datetime]::MinValue; if ([datetime]::TryParse($Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$d)) { return $d.ToLocalTime() } }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) { return (@($Value | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ }) -join ', ') }
    return $Value
}
#endregion

#region Źródła: Microsoft 365, Exchange, Active Directory, Intune
Register-HTExtraColumnSource -Key 'M365User' -Title 'Konto Microsoft 365' -Service 'Graph' `
    -KeyProperties @('Id', 'id', 'UserPrincipalName', 'userPrincipalName', 'UPN', 'ExternalDirectoryObjectId', 'Mail', 'mail', 'E-mail', 'Adres', 'PrimarySmtpAddress', 'Konto', 'Użytkownik', 'Członek', 'Skrzynka') `
    -Attributes ([ordered]@{
        jobTitle = 'Stanowisko'; department = 'Dział'; companyName = 'Firma'; officeLocation = 'Biuro'; city = 'Miasto'; country = 'Kraj'
        createdDateTime = 'Konto utworzone'; accountEnabled = 'Logowanie dozwolone'; userType = 'Typ konta'; usageLocation = 'Lokalizacja użycia'
        employeeId = 'Numer pracownika'; employeeType = 'Rodzaj zatrudnienia'; employeeHireDate = 'Data zatrudnienia'; mobilePhone = 'Telefon komórkowy'
        businessPhones = 'Telefon służbowy'; mail = 'E-mail'; manager = 'Przełożony'; assignedLicenses = 'Licencje'; onPremisesSyncEnabled = 'Synchronizowane z AD'
        lastPasswordChangeDateTime = 'Hasło zmienione'; signInActivity = 'Ostatnie logowanie (Entra ID P1)'
    }) -Fetch {
    param([string[]]$Attributes)
    $plain = @($Attributes | Where-Object { $_ -notin 'manager', 'signInActivity' })
    $select = (@('id', 'userPrincipalName', 'mail', 'proxyAddresses') + $plain | Select-Object -Unique) -join ','
    $expand = if ($Attributes -contains 'manager') { '&$expand=manager($select=displayName,userPrincipalName)' } else { '' }
    $users = @(Invoke-HTGraphRequest -Uri "users?`$select=$select&`$top=999$expand" -All)
    $signIns = @{}
    if ($Attributes -contains 'signInActivity') {
        try { foreach ($u in @(Invoke-HTGraphRequest -Uri 'users?$select=id,signInActivity&$top=999' -All)) { if ($u.signInActivity) { $signIns[[string]$u.id] = $u.signInActivity.lastSignInDateTime } } }
        catch { Write-Log -Message "Kolumna «Ostatnie logowanie»: wymaga Entra ID P1 i uprawnienia AuditLog.Read.All - $($_.Exception.Message)" -Type 'Warn' }
    }
    $skuNames = if ($Attributes -contains 'assignedLicenses') { Get-HTSkuNameMap } else { @{} }
    foreach ($u in $users) {
        $values = @{}
        foreach ($a in $Attributes) {
            $values[$a] = switch ($a) {
                'manager' { if ($u.manager) { "$($u.manager.displayName)$(if ($u.manager.userPrincipalName) { " <$($u.manager.userPrincipalName)>" })" } else { $null } }
                'assignedLicenses' { @($u.assignedLicenses | ForEach-Object { Get-HTSkuFriendlyName ($skuNames["$($_.skuId)"] ?? "$($_.skuId)") }) -join ', ' }
                'signInActivity' { ConvertTo-HTExtraColumnValue $signIns[[string]$u.id] }
                default { ConvertTo-HTExtraColumnValue $u.$a }
            }
        }
        @{ Keys = @($u.id, $u.userPrincipalName, $u.mail) + @($u.proxyAddresses); Values = $values }
    }
}

Register-HTExtraColumnSource -Key 'M365Group' -Title 'Grupa Microsoft 365 / Entra ID' -Service 'Graph' `
    -KeyProperties @('Id', 'id', 'GroupId', 'Mail', 'mail', 'E-mail', 'Adres', 'Grupa', 'DisplayName') `
    -Attributes ([ordered]@{
        createdDateTime = 'Grupa utworzona'; description = 'Opis grupy'; mail = 'E-mail grupy'; visibility = 'Widoczność'; groupTypes = 'Rodzaj grupy'
        membershipRule = 'Reguła członkostwa'; securityEnabled = 'Grupa zabezpieczeń'; mailEnabled = 'Grupa pocztowa'; onPremisesSyncEnabled = 'Synchronizowana z AD'
        expirationDateTime = 'Wygasa'
    }) -Fetch {
    param([string[]]$Attributes)
    $select = (@('id', 'displayName', 'mail', 'proxyAddresses') + $Attributes | Select-Object -Unique) -join ','
    foreach ($g in @(Invoke-HTGraphRequest -Uri "groups?`$select=$select&`$top=999" -All)) {
        $values = @{}
        foreach ($a in $Attributes) {
            $values[$a] = if ($a -eq 'groupTypes') { $(if (@($g.groupTypes) -contains 'Unified') { 'Microsoft 365' } elseif ($g.securityEnabled) { 'Zabezpieczeń' } else { 'Dystrybucyjna' }) + $(if (@($g.groupTypes) -contains 'DynamicMembership') { ' (dynamiczna)' } else { '' }) }
            else { ConvertTo-HTExtraColumnValue $g.$a }
        }
        @{ Keys = @($g.id, $g.mail, $g.displayName) + @($g.proxyAddresses); Values = $values }
    }
}

Register-HTExtraColumnSource -Key 'Mailbox' -Title 'Skrzynka Exchange' -Service 'Exchange' `
    -KeyProperties @('PrimarySmtpAddress', 'Adres', 'UserPrincipalName', 'UPN', 'Skrzynka', 'Mail', 'E-mail', 'Identity', 'ExternalDirectoryObjectId', 'Id', 'Alias', 'Użytkownik') `
    -Attributes ([ordered]@{
        RecipientTypeDetails = 'Typ skrzynki'; WhenCreated = 'Skrzynka utworzona'; HiddenFromAddressListsEnabled = 'Ukryta w GAL'; ArchiveStatus = 'Archiwum'
        LitigationHoldEnabled = 'Litigation Hold'; ForwardingSmtpAddress = 'Przekierowanie'; DeliverToMailboxAndForward = 'Przekierowanie z kopią'; Office = 'Biuro (Exchange)'
        ProhibitSendQuota = 'Limit wysyłania'; RetentionPolicy = 'Zasady przechowywania'; MessageCopyForSentAsEnabled = 'Kopie wysłanych «jako»'
        MessageCopyForSendOnBehalfEnabled = 'Kopie wysłanych «w imieniu»'; AuditEnabled = 'Inspekcja skrzynki'
        CustomAttribute1 = 'Atrybut niestandardowy 1'; CustomAttribute2 = 'Atrybut niestandardowy 2'; CustomAttribute3 = 'Atrybut niestandardowy 3'
        CustomAttribute4 = 'Atrybut niestandardowy 4'; CustomAttribute5 = 'Atrybut niestandardowy 5'
    }) -Fetch {
    param([string[]]$Attributes)
    $props = @(@('EmailAddresses', 'Alias', 'ExternalDirectoryObjectId') + $Attributes | Select-Object -Unique)
    foreach ($m in @(Get-EXOMailbox -ResultSize Unlimited -Properties $props -ErrorAction Stop)) {
        $values = @{}
        foreach ($a in $Attributes) { $values[$a] = ConvertTo-HTExtraColumnValue $m.$a }
        @{ Keys = @([string]$m.PrimarySmtpAddress, [string]$m.UserPrincipalName, [string]$m.Alias, [string]$m.ExternalDirectoryObjectId) + @($m.EmailAddresses | ForEach-Object { [string]$_ } | Where-Object { $_ -match '^(?i)smtp:' }); Values = $values }
    }
}

Register-HTExtraColumnSource -Key 'ADUser' -Title 'Konto Active Directory' -Service 'AD' `
    -KeyProperties @('ObjectGUID', 'SamAccountName', 'Login', 'UserPrincipalName', 'UPN', 'DistinguishedName', 'EmailAddress', 'Mail', 'E-mail') `
    -Attributes ([ordered]@{
        Title = 'Stanowisko'; Department = 'Dział'; Company = 'Firma'; Office = 'Biuro'; Manager = 'Przełożony'; whenCreated = 'Konto AD utworzone'
        LastLogonDate = 'Ostatnie logowanie (AD)'; PasswordLastSet = 'Hasło ustawione'; PasswordNeverExpires = 'Hasło nie wygasa'; Enabled = 'Konto włączone'
        AccountExpirationDate = 'Konto wygasa'; Description = 'Opis'; EmailAddress = 'E-mail'; EmployeeID = 'Numer pracownika'; City = 'Miasto'
        MobilePhone = 'Telefon komórkowy'; OfficePhone = 'Telefon służbowy'; CanonicalName = 'Jednostka organizacyjna'
    }) -Fetch {
    param([string[]]$Attributes)
    $props = @(@('UserPrincipalName', 'EmailAddress') + $Attributes | Select-Object -Unique)
    foreach ($u in @(Get-ADUser -Filter * -Properties $props -ErrorAction Stop)) {
        $values = @{}
        foreach ($a in $Attributes) {
            $values[$a] = switch ($a) {
                'Manager' { if ($u.Manager) { (([string]$u.Manager) -split ',(?=[A-Z]+=)')[0] -replace '^CN=', '' -replace '\\,', ',' } else { $null } }
                'CanonicalName' { $cn = [string]$u.CanonicalName; if ($cn.Contains('/')) { $cn.Substring(0, $cn.LastIndexOf('/')) } else { $cn } }
                default { ConvertTo-HTExtraColumnValue $u.$a }
            }
        }
        @{ Keys = @([string]$u.ObjectGUID, [string]$u.SamAccountName, [string]$u.UserPrincipalName, [string]$u.DistinguishedName, [string]$u.EmailAddress); Values = $values }
    }
}

Register-HTExtraColumnSource -Key 'ADComputer' -Title 'Komputer Active Directory' -Service 'AD' `
    -KeyProperties @('ObjectGUID', 'Name', 'Nazwa', 'Komputer', 'SamAccountName', 'DNSHostName', 'DistinguishedName') `
    -Attributes ([ordered]@{
        OperatingSystem = 'System operacyjny'; OperatingSystemVersion = 'Wersja systemu'; whenCreated = 'Komputer dodany'; LastLogonDate = 'Ostatnie logowanie (AD)'
        Description = 'Opis'; IPv4Address = 'Adres IP'; Enabled = 'Konto włączone'; ManagedBy = 'Właściciel'; CanonicalName = 'Jednostka organizacyjna'
    }) -Fetch {
    param([string[]]$Attributes)
    $props = @(@('DNSHostName') + $Attributes | Select-Object -Unique)
    foreach ($c in @(Get-ADComputer -Filter * -Properties $props -ErrorAction Stop)) {
        $values = @{}
        foreach ($a in $Attributes) {
            $values[$a] = switch ($a) {
                'ManagedBy' { if ($c.ManagedBy) { (([string]$c.ManagedBy) -split ',(?=[A-Z]+=)')[0] -replace '^CN=', '' } else { $null } }
                'CanonicalName' { $cn = [string]$c.CanonicalName; if ($cn.Contains('/')) { $cn.Substring(0, $cn.LastIndexOf('/')) } else { $cn } }
                default { ConvertTo-HTExtraColumnValue $c.$a }
            }
        }
        @{ Keys = @([string]$c.ObjectGUID, [string]$c.Name, [string]$c.SamAccountName, [string]$c.DNSHostName, [string]$c.DistinguishedName); Values = $values }
    }
}

Register-HTExtraColumnSource -Key 'IntuneDevice' -Title 'Urządzenie Intune' -Service 'Graph' `
    -KeyProperties @('Id', 'id', 'DeviceId', 'Urządzenie', 'deviceName', 'DeviceName', 'Nazwa', 'serialNumber', 'Numer seryjny', 'AzureAdDeviceId') `
    -Attributes ([ordered]@{
        operatingSystem = 'System'; osVersion = 'Wersja systemu'; complianceState = 'Zgodność'; lastSyncDateTime = 'Ostatnia synchronizacja'; enrolledDateTime = 'Zarejestrowane w Intune'
        model = 'Model'; manufacturer = 'Producent'; serialNumber = 'Numer seryjny'; userPrincipalName = 'Użytkownik urządzenia'; managedDeviceOwnerType = 'Własność'
        isEncrypted = 'Szyfrowanie'; freeStorageSpaceInBytes = 'Wolne miejsce (GB)'
    }) -Fetch {
    param([string[]]$Attributes)
    $select = (@('id', 'deviceName', 'serialNumber', 'azureADDeviceId') + $Attributes | Select-Object -Unique) -join ','
    foreach ($d in @(Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices?`$select=$select&`$top=999" -All)) {
        $values = @{}
        foreach ($a in $Attributes) {
            $values[$a] = if ($a -eq 'freeStorageSpaceInBytes') { if ($d.freeStorageSpaceInBytes) { [Math]::Round([double]$d.freeStorageSpaceInBytes / 1GB, 1) } else { $null } }
            elseif ($a -eq 'managedDeviceOwnerType') { switch ([string]$d.managedDeviceOwnerType) { 'company' { 'Firmowe' } 'personal' { 'Prywatne' } default { [string]$d.managedDeviceOwnerType } } }
            else { ConvertTo-HTExtraColumnValue $d.$a }
        }
        @{ Keys = @([string]$d.id, [string]$d.deviceName, [string]$d.serialNumber, [string]$d.azureADDeviceId); Values = $values }
    }
}
#endregion
