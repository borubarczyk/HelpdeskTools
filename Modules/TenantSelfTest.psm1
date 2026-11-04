# Autotest funkcji programu na prawdziwym tenancie (Organizacja > Diagnostyka > «Autotest funkcji»).
# Testy odczytu niczego nie zmieniają. Testy zapisu tworzą obiekty tymczasowe z prefiksem «HT-Autotest-» (grupy, konto
# gościa w domenie example.com, grupy pocztowe, grupa i folder SharePoint), sprawdzają operację i od razu je usuwają
# (grupy i konta - także z kosza katalogu). Pozostałości po przerwanym teście: Get-HTSelfTestLeftovers.
# Moduł nie zależy od interfejsu: test { param($ctx) } zwraca tekst szczegółów (OK), hashtablę @{ Status = 'Uwaga';
# Szczegóły = '…' } albo rzuca wyjątek (Błąd); Skip-HTSelfTest 'powód' - test pominięty.

$script:SelfTestPrefix = 'HT-Autotest-'
$script:SelfTestSkip = 'HTSELFTEST-SKIP:'
$script:SelfTests = New-Object System.Collections.Generic.List[hashtable]
$script:LastSelfTest = $null
$script:SelfTestServiceNames = [ordered]@{ Lokalnie = 'Ten komputer'; Graph = 'Microsoft 365 (Graph)'; Exchange = 'Exchange Online'; SharePoint = 'SharePoint (PnP)'; AD = 'Active Directory' }

#region Rejestr i uruchamianie testów
function Get-HTSelfTestPrefix { return $script:SelfTestPrefix }

function Register-HTSelfTest {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Lokalnie', 'Graph', 'Exchange', 'SharePoint', 'AD')][string]$Service,
        [ValidateSet('Read', 'Write')][string]$Mode = 'Read',
        [string]$Area = '',
        [string]$Description = '',
        # Długi test (np. zespół Teams - replikacja do kilku minut) - uruchamiany tylko na życzenie
        [switch]$Slow,
        # Moduły programu sprawdzane tym testem (klucze Register-HTModule) - widok «Pokrycie testami»
        [string[]]$Modules = @(),
        [Parameter(Mandatory)][scriptblock]$Test
    )
    $definition = @{ Key = $Key; Name = $Name; Service = $Service; Mode = $Mode; Area = $Area; Description = $Description; Slow = [bool]$Slow; Modules = @($Modules); Test = $Test }
    for ($i = 0; $i -lt $script:SelfTests.Count; $i++) {
        if ($script:SelfTests[$i].Key -eq $Key) { $script:SelfTests[$i] = $definition; return }
    }
    $script:SelfTests.Add($definition)
}

function Get-HTSelfTests {
    # Testy do uruchomienia: -Service - tylko te usługi, -IncludeWrite - także testy zapisu, -IncludeSlow - także długie
    param([string[]]$Service = @(), [switch]$IncludeWrite, [switch]$IncludeSlow, [string[]]$Key = @())
    return @($script:SelfTests | Where-Object {
            (-not @($Key).Count -or @($Key) -contains $_.Key) -and
            (-not @($Service).Count -or @($Service) -contains $_.Service) -and
            ($IncludeWrite -or $_.Mode -eq 'Read') -and
            ($IncludeSlow -or -not $_.Slow)
        })
}

function Get-HTSelfTestServiceName {
    param([string]$Service)
    if ($script:SelfTestServiceNames.Contains($Service)) { return $script:SelfTestServiceNames[$Service] }
    return $Service
}

function Skip-HTSelfTest {
    # Test pominięty (np. brak skrzynki, brak licencji P1) - nie liczy się jako błąd
    param([Parameter(Mandatory)][string]$Reason)
    throw "$($script:SelfTestSkip)$Reason"
}

function Assert-HTSelfTest {
    param([Parameter(Mandatory)][AllowNull()][object]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Add-HTSelfTestCleanup {
    # Sprzątanie po teście (wykonywane po teście w odwrotnej kolejności - także gdy test się nie powiódł)
    param([Parameter(Mandatory)][hashtable]$Context, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Action)
    $Context.Cleanup.Add(@{ Name = $Name; Action = $Action })
}

function Get-HTSelfTestName {
    # Nazwa obiektu testowego: HT-Autotest-<data-godzina>-<rodzaj>
    param([Parameter(Mandatory)][hashtable]$Context, [Parameter(Mandatory)][string]$Suffix)
    return "$($script:SelfTestPrefix)$($Context.Stamp)-$Suffix"
}

function Wait-HTSelfTestCondition {
    # Ponawia sprawdzenie - zmiany w Microsoft 365 replikują się zwykle od kilku do kilkudziesięciu sekund
    param([Parameter(Mandatory)][hashtable]$Context, [Parameter(Mandatory)][scriptblock]$Condition, [int]$TimeoutSeconds = 60, [int]$IntervalSeconds = 5, [string]$Message = 'Przekroczono czas oczekiwania')
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ($true) {
        $last = ''
        try {
            $result = & $Condition
            if ($result) { return $result }
        }
        catch { $last = $_.Exception.Message }
        if ((Get-Date) -ge $deadline) { throw "$Message$(if ($last) { " ($last)" })" }
        & $Context.Sleep $IntervalSeconds
    }
}

function New-HTSelfTestContext {
    param([scriptblock]$Sleep = { param($Seconds) Start-Sleep -Seconds $Seconds })
    return @{
        Prefix  = $script:SelfTestPrefix
        Stamp   = (Get-Date).ToString('yyyyMMdd-HHmmss')
        Data    = @{}
        Cleanup = New-Object System.Collections.Generic.List[hashtable]
        Sleep   = $Sleep
    }
}

function Invoke-HTSelfTestCleanup {
    # Sprzątanie testu; zwraca listę błędów sprzątania (obiekt mógł zostać - «Pozostałości po testach»)
    param([Parameter(Mandatory)][hashtable]$Context)
    $errors = New-Object System.Collections.Generic.List[string]
    for ($i = $Context.Cleanup.Count - 1; $i -ge 0; $i--) {
        $c = $Context.Cleanup[$i]
        try { & $c.Action | Out-Null }
        catch { $errors.Add("$($c.Name): $($_.Exception.Message)") }
    }
    $Context.Cleanup.Clear()
    return $errors.ToArray()
}

function Invoke-HTSelfTest {
    <#
        Uruchamia testy po kolei i zwraca wiersze: Test, Usługa, Rodzaj, Status (OK / Uwaga / Błąd / Pominięto), Czas (s),
        Szczegóły. -Connected: usługi połączone (test niepołączonej usługi - «Pominięto»). -OnResult { param($row) } -
        wiersz zaraz po teście; -OnStart { param($test, $index, $total) }; -ShouldStop { } - przerwanie przed kolejnym testem.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Tests,
        [hashtable]$Connected = @{},
        [hashtable]$Context = $null,
        [scriptblock]$OnStart = $null,
        [scriptblock]$OnResult = $null,
        [scriptblock]$ShouldStop = $null
    )
    if ($null -eq $Context) { $Context = New-HTSelfTestContext }
    $done = New-Object System.Collections.Generic.List[object]
    $script:LastSelfTest = @{ Started = (Get-Date); Rows = $done }
    $total = @($Tests).Count
    $index = 0
    foreach ($t in @($Tests)) {
        $index++
        if ($ShouldStop -and (& $ShouldStop)) { break }
        if ($OnStart) { & $OnStart $t $index $total }
        $status = 'OK'
        $details = ''
        $started = Get-Date
        if ($t.Service -ne 'Lokalnie' -and -not $Connected[$t.Service]) {
            $status = 'Pominięto'
            $details = "Brak połączenia: $(Get-HTSelfTestServiceName $t.Service)"
        }
        else {
            try {
                $result = & $t.Test $Context
                if ($result -is [System.Collections.IDictionary]) {
                    if ($result.Contains('Status')) { $status = [string]$result.Status }
                    $details = [string]$result['Szczegóły']
                }
                elseif ($null -ne $result) { $details = (@($result | ForEach-Object { [string]$_ }) -join ' ') }
            }
            catch {
                $message = [string]$_.Exception.Message
                if ($message.StartsWith($script:SelfTestSkip)) { $status = 'Pominięto'; $details = $message.Substring($script:SelfTestSkip.Length) }
                else { $status = 'Błąd'; $details = $(if (Get-Command -Name Compress-HTErrorText -ErrorAction Ignore) { Compress-HTErrorText -Text $message } else { $message }) }
            }
            $cleanupErrors = @(Invoke-HTSelfTestCleanup -Context $Context)
            if ($cleanupErrors.Count) {
                if ($status -in 'OK', 'Uwaga') { $status = 'Błąd' }
                $details = (@($details, "Sprzątanie nieudane - obiekt testowy mógł zostać (przycisk «Pozostałości po testach»): $($cleanupErrors -join '; ')") | Where-Object { $_ }) -join ' | '
            }
        }
        $row = [PSCustomObject][ordered]@{
            Test      = $t.Name
            Usługa    = Get-HTSelfTestServiceName $t.Service
            Rodzaj    = $(if ($t.Mode -eq 'Write') { 'zapis (obiekt testowy)' } else { 'odczyt' })
            Obszar    = $t.Area
            Status    = $status
            'Czas (s)' = [Math]::Round(((Get-Date) - $started).TotalSeconds, 1)
            Szczegóły = $details
            Klucz     = $t.Key
            __flag    = $(switch ($status) { 'Błąd' { 'crit' } 'Uwaga' { 'warn' } 'Pominięto' { 'muted' } default { '' } })
        }
        $done.Add($row)
        if ($OnResult) { & $OnResult $row }
        $row
    }
}

function Get-HTSelfTestReport {
    # Wynik ostatniego autotestu w tej sesji (do «Zgłoś problem»): podsumowanie i testy z błędem / uwagą; pusty - nie uruchamiano
    if (-not $script:LastSelfTest) { return @() }
    $rows = $script:LastSelfTest.Rows.ToArray()
    "$($script:LastSelfTest.Started.ToString('yyyy-MM-dd HH:mm')): testów $($rows.Count) - $(Get-HTSelfTestSummary -Rows $rows)"
    foreach ($r in @($rows | Where-Object { $_.Status -in 'Błąd', 'Uwaga' })) { "$($r.Status): $($r.Test) [$($r.Usługa)] - $($r.Szczegóły)" }
}

function Get-HTSelfTestSummary {
    # Podsumowanie wyników (do paska stanu i raportu): «OK: 20, uwagi: 2, błędy: 1, pominięte: 3»
    param([AllowEmptyCollection()][object[]]$Rows = @())
    $count = { param($s) @($Rows | Where-Object { $_.Status -eq $s }).Count }
    return "OK: $(& $count 'OK'), uwagi: $(& $count 'Uwaga'), błędy: $(& $count 'Błąd'), pominięte: $(& $count 'Pominięto')"
}
#endregion

#region Pokrycie modułów testami
function Get-HTSelfTestCoverage {
    <#
        Pokrycie modułów programu testami: przegląd sekcji (przycisk odczytu w module) i testy zapisu (-Modules testów).
        -Modules: opisy modułów @{ Key; Workspace; Category; Title; HasRead; ChangeCount }. Pokrycie: pełne (odczyt i - gdy
        moduł ma przyciski zmian - test zapisu), tylko odczyt (zmiany bez testu zapisu), brak (ani odczytu, ani testu).
    #>
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Modules)
    $byModule = @{}
    foreach ($t in $script:SelfTests) {
        foreach ($k in @($t.Modules | Where-Object { $_ })) {
            if (-not $byModule.ContainsKey($k)) { $byModule[$k] = New-Object System.Collections.Generic.List[string] }
            $byModule[$k].Add([string]$t.Name)
        }
    }
    foreach ($m in @($Modules)) {
        $writes = if ($byModule.ContainsKey([string]$m.Key)) { @($byModule[[string]$m.Key]) } else { @() }
        $state = if (-not $m.HasRead -and -not $writes.Count) { 'brak' } elseif ($m.ChangeCount -gt 0 -and -not $writes.Count) { 'tylko odczyt' } else { 'pełne' }
        [PSCustomObject][ordered]@{
            Przestrzeń         = $m.Workspace
            Kategoria          = $m.Category
            Moduł              = $m.Title
            'Przegląd odczytu' = $(if ($m.HasRead) { 'tak' } else { 'nie - bez przycisku odczytu' })
            'Przyciski zmian'  = [int]$m.ChangeCount
            'Testy zapisu'     = ($writes -join '; ')
            Pokrycie           = $state
            Klucz              = $m.Key
            __flag             = $(switch ($state) { 'brak' { 'crit' } 'tylko odczyt' { 'warn' } default { '' } })
        }
    }
}
#endregion

#region Pozostałości po testach (obiekty HT-Autotest-*)
function Get-HTSelfTestLeftovers {
    # Obiekty testowe, które zostały (np. po przerwaniu programu w trakcie testu): grupy, konta gości, grupy pocztowe
    param([hashtable]$Connected = @{})
    $prefix = $script:SelfTestPrefix
    if ($Connected.Graph) {
        $filter = [uri]::EscapeDataString("startswith(displayName,'$prefix')")
        foreach ($g in @(Invoke-HTGraphRequest -Uri "groups?`$filter=$filter&`$select=id,displayName,mail,groupTypes" -All)) {
            [PSCustomObject]@{ Obiekt = $g.displayName; Rodzaj = 'Grupa (Entra ID)'; Usługa = 'Graph'; Adres = [string]$g.mail; Id = $g.id; __kind = 'Group' }
        }
        foreach ($g in @(Invoke-HTGraphRequest -Uri "directory/deletedItems/microsoft.graph.group?`$filter=$filter&`$select=id,displayName,mail" -All)) {
            [PSCustomObject]@{ Obiekt = $g.displayName; Rodzaj = 'Grupa w koszu katalogu'; Usługa = 'Graph'; Adres = [string]$g.mail; Id = $g.id; __kind = 'DeletedItem' }
        }
        foreach ($u in @(Invoke-HTGraphRequest -Uri "users?`$filter=$filter&`$select=id,displayName,mail,userPrincipalName" -All)) {
            [PSCustomObject]@{ Obiekt = $u.displayName; Rodzaj = 'Konto (gość testowy)'; Usługa = 'Graph'; Adres = [string]$u.mail; Id = $u.id; __kind = 'User' }
        }
        foreach ($u in @(Invoke-HTGraphRequest -Uri "directory/deletedItems/microsoft.graph.user?`$filter=$filter&`$select=id,displayName,mail" -All)) {
            [PSCustomObject]@{ Obiekt = $u.displayName; Rodzaj = 'Konto w koszu katalogu'; Usługa = 'Graph'; Adres = [string]$u.mail; Id = $u.id; __kind = 'DeletedItem' }
        }
    }
    if ($Connected.Exchange) {
        foreach ($g in @(Get-DistributionGroup -Filter "Name -like '$prefix*'" -ResultSize Unlimited -ErrorAction Stop)) {
            [PSCustomObject]@{ Obiekt = $g.DisplayName; Rodzaj = 'Grupa dystrybucyjna'; Usługa = 'Exchange'; Adres = "$($g.PrimarySmtpAddress)"; Id = "$($g.PrimarySmtpAddress)"; __kind = 'DistributionGroup' }
        }
        foreach ($mb in @(Get-EXOMailbox -Filter "Name -like '$prefix*'" -ResultSize Unlimited -ErrorAction Stop)) {
            [PSCustomObject]@{ Obiekt = $mb.DisplayName; Rodzaj = 'Skrzynka'; Usługa = 'Exchange'; Adres = "$($mb.PrimarySmtpAddress)"; Id = "$($mb.PrimarySmtpAddress)"; __kind = 'Mailbox' }
        }
        foreach ($g in @(Get-DynamicDistributionGroup -Filter "Name -like '$prefix*'" -ResultSize Unlimited -ErrorAction Stop)) {
            [PSCustomObject]@{ Obiekt = $g.DisplayName; Rodzaj = 'Grupa dynamiczna'; Usługa = 'Exchange'; Adres = "$($g.PrimarySmtpAddress)"; Id = "$($g.PrimarySmtpAddress)"; __kind = 'DynamicGroup' }
        }
    }
    if ($Connected.SharePoint) {
        foreach ($g in @(Get-HTSPGroups | Where-Object { ([string]$_.Title).StartsWith($prefix) })) {
            [PSCustomObject]@{ Obiekt = $g.Title; Rodzaj = 'Grupa SharePoint (połączona witryna)'; Usługa = 'SharePoint'; Adres = ''; Id = [string]$g.Title; __kind = 'SPGroup' }
        }
    }
}

function Remove-HTSelfTestLeftover {
    # Usunięcie pozostałości testu (tylko obiekty z prefiksem HT-Autotest-)
    param([Parameter(Mandatory)][object]$Item)
    if (-not ([string]$Item.Obiekt).StartsWith($script:SelfTestPrefix)) { throw "To nie jest obiekt testowy (nazwa nie zaczyna się od $($script:SelfTestPrefix))." }
    switch ([string]$Item.__kind) {
        'Group' { Remove-HTM365Group -Id $Item.Id; try { Remove-HTM365DeletedGroup -Id $Item.Id } catch { Write-Verbose "Kosz katalogu: $($_.Exception.Message)" } }
        'User' { Remove-HTM365User -Id $Item.Id; try { Remove-HTM365DeletedUser -Id $Item.Id } catch { Write-Verbose "Kosz katalogu: $($_.Exception.Message)" } }
        'DeletedItem' { Invoke-HTGraphRequest -Uri "directory/deletedItems/$($Item.Id)" -Method DELETE | Out-Null }
        'DistributionGroup' { Remove-HTMailDistributionGroup -Identity $Item.Id }
        'DynamicGroup' { Remove-HTDynamicGroup -Identity $Item.Id }
        'Mailbox' { Remove-Mailbox -Identity $Item.Id -Confirm:$false -ErrorAction Stop }
        'SPGroup' { Remove-HTSPGroup -Group $Item.Id }
        default { throw "Nieznany rodzaj obiektu: $($Item.__kind)" }
    }
}
#endregion

#region Pomocniki testów
function Get-HTSelfTestMe {
    # Zalogowane konto Microsoft Graph (Id, UPN) - właściciel i członek obiektów testowych
    param([Parameter(Mandatory)][hashtable]$Context)
    if ($Context.Data.Me) { return $Context.Data.Me }
    $mg = Get-MgContext
    if (-not $mg -or -not $mg.Account) { Skip-HTSelfTest 'Połączenie aplikacji (bez konta użytkownika) - test wymaga zalogowanego konta.' }
    $u = Resolve-HTM365User -Identity ([string]$mg.Account)
    $Context.Data.Me = [PSCustomObject]@{ Id = [string]$u.id; UserPrincipalName = [string]$u.userPrincipalName; DisplayName = [string]$u.displayName; Mail = [string]$u.mail }
    return $Context.Data.Me
}

function Get-HTSelfTestMailbox {
    # Pierwsza skrzynka użytkownika (zalogowanego konta, a gdy go nie ma - dowolna) do testów Exchange
    param([Parameter(Mandatory)][hashtable]$Context)
    if ($Context.Data.Mailbox) { return $Context.Data.Mailbox }
    $mailboxes = @(Get-EXOMailbox -RecipientTypeDetails UserMailbox -ResultSize 20 -ErrorAction Stop | Where-Object { -not (Test-HTSystemMailbox $_) })
    if (-not $mailboxes.Count) { Skip-HTSelfTest 'Brak skrzynek użytkowników w tenancie.' }
    $me = $null
    try { $me = [string](Get-MgContext).Account } catch { Write-Verbose $_ }
    $pick = @($mailboxes | Where-Object { $me -and ("$($_.UserPrincipalName)" -ieq $me -or "$($_.PrimarySmtpAddress)" -ieq $me) })[0]
    if (-not $pick) { $pick = $mailboxes[0] }
    $Context.Data.Mailbox = [string]$pick.PrimarySmtpAddress
    return $Context.Data.Mailbox
}

function Get-HTSelfTestDomain {
    # Domena akceptowana Exchange (domyślna) do adresów grup testowych
    param([Parameter(Mandatory)][hashtable]$Context)
    if ($Context.Data.Domain) { return $Context.Data.Domain }
    $d = @(Get-AcceptedDomain -ErrorAction Stop | Sort-Object { -not $_.Default })[0]
    if (-not $d) { throw 'Brak domen akceptowanych w Exchange.' }
    $Context.Data.Domain = [string]$d.DomainName
    return $Context.Data.Domain
}
#endregion

#region Testy: ten komputer
Register-HTSelfTest -Key 'local.modules' -Name 'Moduły PowerShell i ich wersje' -Service 'Lokalnie' -Area 'Instalacja' `
    -Description 'Wersje modułów (wczytanych, a gdy nie są wczytane - najnowszych zainstalowanych) względem wersji sprawdzonych z programem.' -Test {
    $checks = foreach ($n in @((Get-HTModuleRequirements).Keys)) {
        $m = @(Get-Module -Name $n | Sort-Object Version -Descending)[0]
        if (-not $m) { $m = @(Get-Module -ListAvailable -Name $n | Sort-Object Version -Descending)[0] }
        Test-HTModuleVersion -Name $n -Version $(if ($m) { $m.Version } else { $null })
    }
    $text = "PowerShell $($PSVersionTable.PSVersion); $(@($checks | ForEach-Object { $_.Text }) -join '; ')"
    if (@($checks | Where-Object { $_.Status -ne 'OK' }).Count) { return @{ Status = 'Uwaga'; Szczegóły = $text } }
    return $text
}

Register-HTSelfTest -Key 'local.config' -Name 'Plik ustawień' -Service 'Lokalnie' -Area 'Instalacja' -Test {
    $path = [string]$Global:ConfigPath
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { return @{ Status = 'Uwaga'; Szczegóły = "Brak pliku ustawień ($path) - zostanie utworzony przy zapisie ustawień." } }
    $null = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $scopes = @($Global:GraphScopes).Count
    return "Ustawienia poprawne: $path; uprawnień Graph: $scopes"
}

Register-HTSelfTest -Key 'local.password' -Name 'Generator haseł' -Service 'Lokalnie' -Area 'Konta' -Test {
    $p = New-Password -Length 14 -StartWithLetter $true
    Assert-HTSelfTest ($p.Length -ge 8) "Za krótkie hasło: $($p.Length) znaków"
    Assert-HTSelfTest ($p -cmatch '[A-Z]' -and $p -cmatch '[a-z]' -and $p -match '\d') 'Hasło nie spełnia wymagań złożoności (wielkie i małe litery, cyfry)'
    return "Wygenerowano hasło o długości $($p.Length) (nie zapisano)"
}
#endregion

#region Testy: Microsoft 365 (Graph) - odczyt
Register-HTSelfTest -Key 'graph.context' -Name 'Połączenie i uprawnienia Graph' -Service 'Graph' -Area 'Połączenie' -Test {
    $mg = Get-MgContext
    Assert-HTSelfTest $mg 'Brak kontekstu Microsoft Graph (Get-MgContext)'
    if ("$($mg.AuthType)" -eq 'AppOnly') { return "Połączenie aplikacji (AppOnly), tenant $($mg.TenantId)" }
    $missing = @(@($Global:GraphScopes) | Where-Object { $_ -and @($mg.Scopes) -notcontains $_ })
    $text = "Konto $($mg.Account), tenant $($mg.TenantId), uprawnień: $(@($mg.Scopes).Count)"
    if ($missing.Count) { return @{ Status = 'Uwaga'; Szczegóły = "$text. Brak zgody na: $($missing -join ', ') - połącz ponownie z Microsoft 365 (zgoda administratora)." } }
    return $text
}

Register-HTSelfTest -Key 'graph.users' -Name 'Lista kont i szczegóły konta' -Service 'Graph' -Area 'Konta' -Test {
    param($ctx)
    $users = @(Get-HTM365Users)
    Assert-HTSelfTest $users.Count 'Lista kont jest pusta'
    $me = Get-HTSelfTestMe -Context $ctx
    $detail = Get-HTM365UserDetail -Id $me.Id
    Assert-HTSelfTest ([string]$detail['UPN'] -eq $me.UserPrincipalName) "Szczegóły konta nie zgadzają się z kontem (UPN: «$($detail['UPN'])», oczekiwano $($me.UserPrincipalName))"
    # Sekcje szczegółów z liczbą w nazwie, np. «Licencje (2)», «Metody MFA (3)», «Grupy (5)»
    $sections = @($detail.Keys | Where-Object { $_ -match '^(Licencje|Metody MFA|Grupy) \(\d+\)$' })
    return "Kont: $($users.Count); szczegóły $($me.UserPrincipalName): $($sections -join ', ')"
}

Register-HTSelfTest -Key 'graph.licenses' -Name 'Licencje tenanta' -Service 'Graph' -Area 'Licencje' -Test {
    $skus = @(Get-HTSubscribedSkus -Force)
    if (-not $skus.Count) { return @{ Status = 'Uwaga'; Szczegóły = 'Brak subskrypcji w tenancie' } }
    $names = @($skus | Select-Object -First 5 | ForEach-Object { "$(Get-HTSkuFriendlyName $_.SkuPartNumber) ($($_.Consumed)/$($_.Enabled))" })
    return "Subskrypcji: $($skus.Count): $($names -join ', ')$(if ($skus.Count -gt 5) { '…' })"
}

Register-HTSelfTest -Key 'graph.groups' -Name 'Grupy, członkowie i właściciele' -Service 'Graph' -Area 'Grupy' -Test {
    $groups = @(Get-HTM365Groups)
    if (-not $groups.Count) { return @{ Status = 'Uwaga'; Szczegóły = 'Brak grup w tenancie' } }
    $g = @($groups | Where-Object { $_.Type -ne 'Dystrybucyjna' })[0]
    if (-not $g) { $g = $groups[0] }
    $members = @(Get-HTM365GroupMembers -Id $g.Id)
    $owners = @(Get-HTM365GroupOwners -Id $g.Id)
    $licenses = @(Get-HTM365GroupLicenses -Id $g.Id)
    return "Grup: $($groups.Count) (Microsoft 365: $(@($groups | Where-Object { $_.Type -eq 'Microsoft 365' }).Count), zespołów: $(@($groups | Where-Object IsTeam).Count)); «$($g.DisplayName)»: członków $($members.Count), właścicieli $($owners.Count), licencji grupowych $($licenses.Count)"
}

Register-HTSelfTest -Key 'graph.deleted' -Name 'Usunięte grupy i konta (kosz katalogu)' -Service 'Graph' -Area 'Grupy' -Test {
    $groups = @(Get-HTM365DeletedGroups)
    $users = @(Get-HTM365DeletedUsers)
    return "Usuniętych grup: $($groups.Count), kont: $($users.Count)"
}

Register-HTSelfTest -Key 'graph.hygiene' -Name 'Grupy do uporządkowania' -Service 'Graph' -Area 'Grupy' -Test {
    $rows = @(Get-HTM365GroupHygiene)
    return "Grup bez właściciela lub członków: $($rows.Count)"
}

Register-HTSelfTest -Key 'graph.licerr' -Name 'Błędy licencji grupowych' -Service 'Graph' -Area 'Licencje' -Test {
    $rows = @(Get-HTGroupLicenseErrors)
    if ($rows.Count) { return @{ Status = 'Uwaga'; Szczegóły = "Użytkowników z błędem licencji grupowej: $($rows.Count) (Organizacja > Licencje > Błędy licencji grupowych)" } }
    return 'Brak błędów licencji grupowych'
}

Register-HTSelfTest -Key 'graph.domains' -Name 'Domeny i rekordy DNS' -Service 'Graph' -Area 'Domeny' -Test {
    $domains = @(Get-HTM365DomainDetails)
    Assert-HTSelfTest $domains.Count 'Brak domen'
    $default = @($domains | Where-Object Domyślna)[0]
    Assert-HTSelfTest $default 'Brak domeny domyślnej'
    $records = @(Get-HTM365DomainDnsRecords -Domain $default.Domena)
    $unverified = @($domains | Where-Object { -not $_.Zweryfikowana })
    $text = "Domen: $($domains.Count), domyślna: $($default.Domena), rekordów usług domeny domyślnej: $($records.Count)"
    if ($unverified.Count) { return @{ Status = 'Uwaga'; Szczegóły = "$text; niezweryfikowane: $(@($unverified | ForEach-Object Domena) -join ', ')" } }
    return $text
}

Register-HTSelfTest -Key 'graph.guests' -Name 'Konta gości' -Service 'Graph' -Area 'Goście' -Test {
    $guests = @(Get-HTM365GuestUsers)
    return "Gości: $($guests.Count), oczekujących na przyjęcie zaproszenia: $(@($guests | Where-Object { $_.'Stan zaproszenia' -eq 'PendingAcceptance' }).Count)"
}

Register-HTSelfTest -Key 'graph.teams' -Name 'Zespoły Teams i kanały' -Service 'Graph' -Area 'Teams' -Test {
    $teams = @(Get-HTTeamsOverview -NoActivity)
    if (-not $teams.Count) { return @{ Status = 'Uwaga'; Szczegóły = 'Brak zespołów Teams w tenancie' } }
    $channels = @(Get-HTTeamChannels -TeamId $teams[0].Id -TeamName $teams[0].Zespół)
    return "Zespołów: $($teams.Count), bez właściciela: $(@($teams | Where-Object { $_.Właściciele -eq 0 }).Count); «$($teams[0].Zespół)»: kanałów $($channels.Count)"
}

Register-HTSelfTest -Key 'graph.signins' -Name 'Logowania (dziennik Entra ID)' -Service 'Graph' -Area 'Bezpieczeństwo' -Test {
    param($ctx)
    $me = Get-HTSelfTestMe -Context $ctx
    try { $rows = @(Get-HTM365SignIns -UserId $me.Id -Top 5) }
    catch {
        if ("$($_.Exception.Message)" -match 'Premium|P1|license|licencj|Authentication_RequestFromNonPremiumTenant') { Skip-HTSelfTest 'Dziennik logowań wymaga licencji Entra ID P1.' }
        throw
    }
    return "Ostatnich logowań $($me.UserPrincipalName): $($rows.Count)"
}

Register-HTSelfTest -Key 'graph.health' -Name 'Kondycja usług Microsoft 365' -Service 'Graph' -Area 'Organizacja' -Test {
    $rows = @(Get-HTM365ServiceHealth)
    return "Usług: $(@($rows).Count)"
}

Register-HTSelfTest -Key 'graph.sites' -Name 'Witryny SharePoint (wyszukiwanie Graph)' -Service 'Graph' -Area 'SharePoint' -Test {
    $sites = @(Find-HTSPSites -Search '*')
    if (-not $sites.Count) { return @{ Status = 'Uwaga'; Szczegóły = 'Nie znaleziono witryn (Sites.Read.All?)' } }
    return "Witryn: $($sites.Count)"
}

Register-HTSelfTest -Key 'graph.intune' -Name 'Urządzenia Intune' -Service 'Graph' -Area 'Intune' -Test {
    try { $s = Get-HTIntuneSummary }
    catch {
        if ("$($_.Exception.Message)" -match 'Forbidden|403|license|licencj|not.*enabled') { Skip-HTSelfTest "Intune niedostępny w tenancie albo brak uprawnień: $($_.Exception.Message)" }
        throw
    }
    return "Urządzeń zarządzanych: $($s.Total)"
}
#endregion

#region Testy: Microsoft 365 (Graph) - zapis na obiektach testowych
Register-HTSelfTest -Key 'graph.w.secgroup' -Modules @('grp.manage', 'grp.members', 'grp.owners', 'org.newgroup', 'grp.details') -Name 'Grupa zabezpieczeń: utwórz, zmień, członkowie, usuń' -Service 'Graph' -Mode 'Write' -Area 'Grupy' -Test {
    param($ctx)
    $me = Get-HTSelfTestMe -Context $ctx
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'Grupa'
    $g = New-HTM365Group -DisplayName $name -Type Security -Description 'Autotest Helpdesk Tools - do usunięcia' -OwnerIds @($me.Id)
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie grupy $name" -Action {
        Remove-HTM365Group -Id $g.Id
        try { Remove-HTM365DeletedGroup -Id $g.Id } catch { Write-Verbose "Kosz katalogu: $($_.Exception.Message)" }
    }.GetNewClosure()
    $steps = @('utworzono')
    Set-HTM365Group -Id $g.Id -Changes ([ordered]@{ description = 'Autotest - zmieniony opis' })
    Wait-HTSelfTestCondition -Context $ctx -Message 'Nie widać zmienionego opisu' -Condition { (Invoke-HTGraphRequest -Uri "groups/$($g.Id)?`$select=description").description -eq 'Autotest - zmieniony opis' } | Out-Null
    $steps += 'opis zmieniony'
    Add-HTM365GroupMember -GroupId $g.Id -MemberId $me.Id
    Wait-HTSelfTestCondition -Context $ctx -Message 'Nie widać nowego członka' -Condition { @(Get-HTM365GroupMembers -Id $g.Id | Where-Object { $_.Id -eq $me.Id }).Count } | Out-Null
    $steps += 'członek dodany'
    Remove-HTM365GroupMember -GroupId $g.Id -MemberId $me.Id
    Wait-HTSelfTestCondition -Context $ctx -Message 'Członek nadal w grupie' -Condition { -not @(Get-HTM365GroupMembers -Id $g.Id | Where-Object { $_.Id -eq $me.Id }).Count } | Out-Null
    $steps += 'członek usunięty'
    Assert-HTSelfTest (@(Get-HTM365GroupOwners -Id $g.Id | Where-Object { $_.Id -eq $me.Id }).Count) 'Brak właściciela ustawionego przy tworzeniu'
    $steps += 'właściciel OK'
    return "$name - $($steps -join ', '); grupa usuwana po teście"
}

Register-HTSelfTest -Key 'graph.w.grouplicense' -Modules @('grp.licenses') -Name 'Licencja grupowa: przypisz i usuń (grupa bez członków)' -Service 'Graph' -Mode 'Write' -Area 'Licencje' -Test {
    param($ctx)
    $sku = @(Get-HTSubscribedSkus -Force | Where-Object { $_.Status -eq 'Enabled' -and $_.Enabled -gt 0 } | Sort-Object Available -Descending)[0]
    if (-not $sku) { Skip-HTSelfTest 'Brak aktywnych subskrypcji do testu licencji grupowej.' }
    $me = Get-HTSelfTestMe -Context $ctx
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'Licencja'
    $g = New-HTM365Group -DisplayName $name -Type Security -Description 'Autotest Helpdesk Tools - do usunięcia' -OwnerIds @($me.Id)
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie grupy $name" -Action {
        Remove-HTM365Group -Id $g.Id
        try { Remove-HTM365DeletedGroup -Id $g.Id } catch { Write-Verbose "Kosz katalogu: $($_.Exception.Message)" }
    }.GetNewClosure()
    Wait-HTSelfTestCondition -Context $ctx -Message 'Nowa grupa niewidoczna' -Condition { Invoke-HTGraphRequest -Uri "groups/$($g.Id)?`$select=id" } | Out-Null
    Set-HTM365GroupLicense -Id $g.Id -AddSkuIds @([string]$sku.SkuId)
    Wait-HTSelfTestCondition -Context $ctx -Message 'Licencja nie jest widoczna na grupie' -Condition { @(Get-HTM365GroupLicenses -Id $g.Id | Where-Object { $_.SkuId -eq [string]$sku.SkuId }).Count } | Out-Null
    Set-HTM365GroupLicense -Id $g.Id -RemoveSkuIds @([string]$sku.SkuId)
    Wait-HTSelfTestCondition -Context $ctx -Message 'Licencja nadal na grupie' -Condition { -not @(Get-HTM365GroupLicenses -Id $g.Id).Count } | Out-Null
    return "$name - przypisano i usunięto $(Get-HTSkuFriendlyName $sku.SkuPartNumber) (grupa bez członków - licencje nie są zużywane)"
}

Register-HTSelfTest -Key 'graph.w.guest' -Modules @('org.guest') -Name 'Zaproszenie gościa bez e-maila (example.com)' -Service 'Graph' -Mode 'Write' -Area 'Goście' -Test {
    param($ctx)
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'Gosc'
    $email = "$($name.ToLowerInvariant())@example.com"
    try { $inv = New-HTM365GuestInvitation -Email $email -DisplayName $name -SendInvitation $false }
    catch {
        if ("$($_.Exception.Message)" -match '(?i)invitations? not allowed|not allowed for your company|domain.*(block|not allowed|denied)|collaboration|B2B|współpracy') { Skip-HTSelfTest "Zaproszenia gości są wyłączone albo ograniczone w tym tenancie (Entra ID > Identities zewnętrzne > Ustawienia współpracy zewnętrznej). $($_.Exception.Message)" }
        throw
    }
    Assert-HTSelfTest $inv.UserId 'Zaproszenie nie zwróciło konta gościa'
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie gościa $email" -Action {
        Remove-HTM365User -Id $inv.UserId
        try { Remove-HTM365DeletedUser -Id $inv.UserId } catch { Write-Verbose "Kosz katalogu: $($_.Exception.Message)" }
    }.GetNewClosure()
    Assert-HTSelfTest $inv.RedeemUrl 'Brak linku do przyjęcia zaproszenia'
    Wait-HTSelfTestCondition -Context $ctx -Message 'Konto gościa niewidoczne' -Condition { (Invoke-HTGraphRequest -Uri "users/$($inv.UserId)?`$select=userType").userType -eq 'Guest' } | Out-Null
    return "Zaproszono $email (bez wysyłki e-maila), stan: $($inv.Status); konto gościa usuwane po teście"
}

Register-HTSelfTest -Key 'graph.w.team' -Modules @('grp.team', 'm365.teams') -Name 'Grupa Microsoft 365 → zespół Teams → kanał' -Service 'Graph' -Mode 'Write' -Area 'Teams' -Slow `
    -Description 'Replikacja grupy do Teams trwa do kilku minut.' -Test {
    param($ctx)
    $me = Get-HTSelfTestMe -Context $ctx
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'Zespol'
    $g = New-HTM365Group -DisplayName $name -Type Microsoft365 -Visibility Private -Description 'Autotest Helpdesk Tools - do usunięcia' -OwnerIds @($me.Id) -MemberIds @($me.Id)
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie grupy $name" -Action {
        Remove-HTM365Group -Id $g.Id
        try { Remove-HTM365DeletedGroup -Id $g.Id } catch { Write-Verbose "Kosz katalogu: $($_.Exception.Message)" }
    }.GetNewClosure()
    Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 300 -IntervalSeconds 15 -Message 'Nie utworzono zespołu z grupy (replikacja)' -Condition {
        # Poprzednia próba mogła utworzyć zespół mimo błędu (409 - zespół już jest)
        try { New-HTTeamFromGroup -GroupId $g.Id -Retries 1 } catch { if ("$($_.Exception.Message)" -match 'Conflict|already exist') { $true } else { throw } }
    } | Out-Null
    $channelName = 'Autotest'
    $channel = Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 180 -IntervalSeconds 15 -Message 'Nie utworzono kanału' -Condition { New-HTTeamChannel -TeamId $g.Id -DisplayName $channelName -Description 'Kanał testowy' }
    $channels = @(Get-HTTeamChannels -TeamId $g.Id -TeamName $name)
    Assert-HTSelfTest (@($channels | Where-Object { $_.Kanał -eq $channelName }).Count) 'Nowy kanał nie jest widoczny na liście'
    Assert-HTSelfTest (@($channels | Where-Object IsGeneral).Count) 'Brak kanału ogólnego'
    Remove-HTTeamChannel -TeamId $g.Id -ChannelId ([string]$channel.id)
    return "$name - zespół utworzony, kanał dodany i usunięty (kanałów: $($channels.Count)); grupa usuwana po teście"
}
#endregion

#region Testy: Exchange Online
Register-HTSelfTest -Key 'exo.mailboxes' -Name 'Skrzynki i szczegóły skrzynki' -Service 'Exchange' -Area 'Poczta' -Test {
    param($ctx)
    $address = Get-HTSelfTestMailbox -Context $ctx
    $detail = Get-HTMailboxDetail -Identity $address
    Assert-HTSelfTest $detail 'Brak szczegółów skrzynki'
    $auto = Get-HTMailboxAutoReply -Identity $address
    $perm = @(Get-HTMailboxPermissions -Identity $address)
    return "Skrzynka $($address): autoodpowiedź $($auto.AutoReplyState), uprawnień: $($perm.Count)"
}

Register-HTSelfTest -Key 'exo.trace' -Name 'Śledzenie wiadomości (48 h)' -Service 'Exchange' -Area 'Poczta' -Test {
    param($ctx)
    $address = Get-HTSelfTestMailbox -Context $ctx
    $rows = @(Get-HTMessageTrace -Address $address -Direction Received -Days 2)
    return "Wiadomości odebranych przez $address w 48 h: $($rows.Count)"
}

Register-HTSelfTest -Key 'exo.groups' -Name 'Grupy dystrybucyjne i dynamiczne' -Service 'Exchange' -Area 'Grupy' -Test {
    $dist = @(Get-DistributionGroup -ResultSize 50 -ErrorAction Stop)
    $dyn = @(Get-HTDynamicGroups)
    $preview = Get-HTRecipientFilterPreview -Filter "(RecipientTypeDetails -eq 'UserMailbox')" -Max 5
    return "Grup dystrybucyjnych (do 50): $($dist.Count), dynamicznych: $($dyn.Count); test filtra: $(@($preview.Items).Count)$(if ($preview.More) { '+' }) skrzynek"
}

Register-HTSelfTest -Key 'exo.config' -Name 'Konfiguracja organizacji Exchange' -Service 'Exchange' -Area 'Poczta' -Test {
    $domains = @(Get-AcceptedDomain -ErrorAction Stop)
    $org = Get-OrganizationConfig -ErrorAction Stop
    return "Domen akceptowanych: $($domains.Count); organizacja: $($org.DisplayName)"
}

Register-HTSelfTest -Key 'exo.w.distgroup' -Modules @('exo.dl', 'org.newgroup') -Name 'Grupa dystrybucyjna: utwórz, członek, usuń' -Service 'Exchange' -Mode 'Write' -Area 'Grupy' -Test {
    param($ctx)
    $member = Get-HTSelfTestMailbox -Context $ctx
    $domain = Get-HTSelfTestDomain -Context $ctx
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'DL'
    $address = "$($name.ToLowerInvariant())@$domain"
    $created = New-HTMailDistributionGroup -DisplayName $name -Address $address -Type Distribution -Owners @($member) -InternalOnly $true -Hidden $true
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie grupy $created" -Action { Remove-HTMailDistributionGroup -Identity $created }.GetNewClosure()
    Invoke-HTWithRetry { Add-HTDistributionGroupMember -Group $created -Member $member }
    Wait-HTSelfTestCondition -Context $ctx -Message 'Członek nie jest widoczny w grupie' -Condition { @(Get-HTDistributionGroupMembers -Identity $created | Where-Object { $_.Adres -ieq $member }).Count } | Out-Null
    Remove-HTDistributionGroupMember -Group $created -Member $member
    return "$created - utworzono (ukryta w GAL), członek $member dodany i usunięty; grupa usuwana po teście"
}

Register-HTSelfTest -Key 'exo.w.dyngroup' -Modules @('exo.dyn', 'org.newgroup') -Name 'Grupa dynamiczna: utwórz z filtrem, członkowie, usuń' -Service 'Exchange' -Mode 'Write' -Area 'Grupy' -Test {
    param($ctx)
    $domain = Get-HTSelfTestDomain -Context $ctx
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'DDG'
    $filter = ConvertTo-HTRecipientFilter -RecipientType 'Skrzynki użytkowników' -Conditions @(@{ Property = 'Department'; Operator = 'eq'; Value = $name })
    $created = New-HTDynamicGroup -DisplayName $name -Address "$($name.ToLowerInvariant())@$domain" -Filter $filter
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie grupy $created" -Action { Remove-HTDynamicGroup -Identity $created }.GetNewClosure()
    Invoke-HTWithRetry { Set-DynamicDistributionGroup -Identity $created -HiddenFromAddressListsEnabled $true -Confirm:$false -ErrorAction Stop }
    $members = @(Get-HTDynamicGroupMembers -Identity $created)
    return "$created - filtr: $filter; członków: $($members.Count) (oczekiwane 0); grupa usuwana po teście"
}
#endregion

#region Testy zapisu: konto i skrzynka współdzielona
Register-HTSelfTest -Key 'graph.w.user' -Name 'Konto: utwórz, dane, hasło, blokada, przełożony, usuń' -Service 'Graph' -Mode 'Write' -Area 'Konta' `
    -Modules @('m365.new', 'm365.edit', 'm365.password', 'm365.block', 'm365.manager', 'm365.details', 'm365.deleted') -Test {
    param($ctx)
    $me = Get-HTSelfTestMe -Context $ctx
    $domain = @(Get-HTM365Domains)[0]
    if (-not $domain) { throw 'Brak zweryfikowanej domeny do UPN konta testowego' }
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'Konto'
    $upn = "$($name.ToLowerInvariant())@$domain"
    $u = New-HTM365User -DisplayName $name -UserPrincipalName $upn -Password (New-Password -Length 16 -StartWithLetter $true) -AccountEnabled $false -UsageLocation 'PL' -Department 'HT-Autotest'
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie konta $upn" -Action {
        Remove-HTM365User -Id $u.id
        try { Remove-HTM365DeletedUser -Id $u.id } catch { Write-Verbose "Kosz katalogu: $($_.Exception.Message)" }
    }.GetNewClosure()
    $steps = @('utworzono (zablokowane)')
    Wait-HTSelfTestCondition -Context $ctx -Message 'Nowe konto niewidoczne' -Condition { Invoke-HTGraphRequest -Uri "users/$($u.id)?`$select=id" } | Out-Null
    Set-HTM365UserContact -Id $u.id -Properties @{ jobTitle = 'Autotest'; city = 'Warszawa' }
    Wait-HTSelfTestCondition -Context $ctx -Message 'Dane kontaktowe nie zapisały się' -Condition { (Invoke-HTGraphRequest -Uri "users/$($u.id)?`$select=jobTitle").jobTitle -eq 'Autotest' } | Out-Null
    $steps += 'dane kontaktowe'
    Reset-HTM365UserPassword -Id $u.id -Password (New-Password -Length 16 -StartWithLetter $true) -ForceChange $true
    $steps += 'reset hasła'
    Set-HTM365UserEnabled -Id $u.id -Enabled $false -RevokeSessions $true
    Assert-HTSelfTest (-not (Invoke-HTGraphRequest -Uri "users/$($u.id)?`$select=accountEnabled").accountEnabled) 'Konto nie jest zablokowane'
    $steps += 'blokada z wylogowaniem'
    Set-HTM365UserManager -Id $u.id -ManagerId $me.Id
    Wait-HTSelfTestCondition -Context $ctx -Message 'Przełożony nie zapisał się' -Condition { [string](Get-HTM365UserManager -Id $u.id).id -eq $me.Id } | Out-Null
    Remove-HTM365UserManager -Id $u.id
    $steps += 'przełożony ustawiony i usunięty'
    $detail = Get-HTM365UserDetail -Id $u.id
    Assert-HTSelfTest ([string]$detail['UPN'] -eq $upn) 'Szczegóły nowego konta nie zgadzają się'
    $steps += 'szczegóły'
    return "$upn - $($steps -join ', '); konto usuwane po teście (także z kosza)"
}

Register-HTSelfTest -Key 'exo.w.shared' -Name 'Skrzynka współdzielona: uprawnienia z listy, kopie wysłanych, autoodpowiedź, usuń' -Service 'Exchange' -Mode 'Write' -Area 'Poczta' `
    -Modules @('exo.newmailbox', 'exo.perms', 'exo.autoreply', 'exo.details', 'exo.settings') -Test {
    param($ctx)
    $member = Get-HTSelfTestMailbox -Context $ctx
    $domain = Get-HTSelfTestDomain -Context $ctx
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'SM'
    $address = New-HTResourceMailbox -Type Shared -DisplayName $name -Address "$($name.ToLowerInvariant())@$domain"
    $state = @{ ObjectId = '' }
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie skrzynki $address" -Action {
        Remove-Mailbox -Identity $address -Confirm:$false -ErrorAction Stop
        # Konto skrzynki trafia do kosza katalogu - trwałe usunięcie, gdy jest połączenie z Microsoft 365
        if ($state.ObjectId -and $Global:ConnectedToGraphAPI) { try { Remove-HTM365DeletedUser -Id $state.ObjectId } catch { Write-Verbose "Kosz katalogu: $($_.Exception.Message)" } }
    }.GetNewClosure()
    $mbx = Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 180 -IntervalSeconds 10 -Message 'Nowa skrzynka niewidoczna' -Condition { Get-EXOMailbox -Identity $address -ErrorAction Stop }
    $state.ObjectId = [string]$mbx.ExternalDirectoryObjectId
    Invoke-HTWithRetry { Set-HTMailboxHiddenFromGAL -Identity $address -Hidden $true }
    $steps = @('utworzono (ukryta w GAL)')
    $entry = @(ConvertFrom-HTMailboxPermissionLines -Text "$member; pełny, jako, w imieniu; nie")[0]
    Assert-HTSelfTest (-not $entry.Problem) "Lista uprawnień: $($entry.Problem)"
    Invoke-HTWithRetry { Add-HTMailboxPermission -Identity $address -User $member -Type $entry.Types -AutoMapping $entry.AutoMapping }
    $types = Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 90 -Message 'Nie widać wszystkich uprawnień' -Condition {
        $t = @(Get-HTMailboxPermissions -Identity $address | ForEach-Object { $_.Type } | Select-Object -Unique)
        if ($t -contains 'FullAccess' -and $t -contains 'SendAs' -and $t -contains 'SendOnBehalf') { $t }
    }
    $steps += "uprawnienia z listy: $(@($types) -join ', ') (bez automapowania)"
    Set-HTMailboxSentItemsCopy -Identity $address
    $copy = Wait-HTSelfTestCondition -Context $ctx -Message 'Kopie wysłanych nie włączyły się' -Condition { $c = Get-HTMailboxSentItemsCopy -Identity $address; if ($c.'Kopia wysłanych «jako»' -and $c.'Kopia wysłanych «w imieniu»') { $c } }
    $steps += 'kopie wysłanych przez delegatów'
    Set-HTMailboxAutoReply -Identity $address -State Enabled -InternalMessage 'Autotest Helpdesk Tools' -ExternalMessage 'Autotest Helpdesk Tools'
    Assert-HTSelfTest ("$((Get-HTMailboxAutoReply -Identity $address).AutoReplyState)" -eq 'Enabled') 'Autoodpowiedź nie włączyła się'
    Clear-HTMailboxAutoReply -Identity $address
    Assert-HTSelfTest ("$((Get-HTMailboxAutoReply -Identity $address).AutoReplyState)" -eq 'Disabled') 'Autoodpowiedź nie wyłączyła się'
    $steps += 'autoodpowiedź włączona i wyczyszczona'
    foreach ($t in 'SendOnBehalf', 'SendAs', 'FullAccess') { Remove-HTMailboxPermission -Identity $address -User $member -Type $t }
    $steps += 'uprawnienia odebrane'
    return "$address - $($steps -join ', '); skrzynka usuwana po teście"
}
#endregion

#region Testy: SharePoint (połączona witryna)
Register-HTSelfTest -Key 'spo.site' -Name 'Witryna, biblioteki i uprawnienia' -Service 'SharePoint' -Area 'SharePoint' -Test {
    $info = Get-HTSPSiteInfo
    $libraries = @(Get-HTSPLibraries)
    $groups = @(Get-HTSPGroups)
    $perms = if ($libraries.Count) { @(Get-HTSPPermissions -Node $libraries[0]) } else { @() }
    return "$($info.'Tytuł') ($($info.Adres)): bibliotek $($libraries.Count), grup $($groups.Count), uprawnień biblioteki «$(if ($libraries.Count) { $libraries[0].Title })»: $($perms.Count)"
}

Register-HTSelfTest -Key 'spo.w.group' -Modules @('sp.groups') -Name 'Grupa SharePoint: utwórz i usuń' -Service 'SharePoint' -Mode 'Write' -Area 'SharePoint' -Test {
    param($ctx)
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'SP'
    New-HTSPGroup -Title $name -Description 'Autotest Helpdesk Tools - do usunięcia' | Out-Null
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie grupy $name" -Action { Remove-HTSPGroup -Group $name }.GetNewClosure()
    Assert-HTSelfTest (@(Get-HTSPGroups | Where-Object { $_.Title -eq $name }).Count) 'Nowa grupa nie jest widoczna'
    return "$name - utworzono w połączonej witrynie; grupa usuwana po teście"
}

Register-HTSelfTest -Key 'spo.w.folder' -Modules @('sp.newfolder', 'sp.perms') -Name 'Folder w bibliotece: utwórz i usuń' -Service 'SharePoint' -Mode 'Write' -Area 'SharePoint' -Test {
    param($ctx)
    $library = @(Get-HTSPLibraries | Sort-Object @{ Expression = { -not ([string]$_.ServerRelativeUrl -match '/Shared Documents$') } })[0]
    if (-not $library) { Skip-HTSelfTest 'Brak biblioteki dokumentów w połączonej witrynie.' }
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'Folder'
    $folder = New-HTSPFolder -ParentNode $library -Name $name
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie folderu $name" -Action { Remove-HTSPFolder -Node $folder -Permanent }.GetNewClosure()
    Assert-HTSelfTest (@(Get-HTSPSubFolders -ServerRelativeUrl $library.ServerRelativeUrl -ListTitle $library.ListTitle -ListId (Get-HTSPListId -Node $library) | Where-Object { $_.Title -eq $name }).Count) 'Nowy folder nie jest widoczny'
    return "$($folder.ServerRelativeUrl) - utworzono w «$($library.Title)»; folder usuwany po teście (bez kosza)"
}
#endregion

#region Testy: Active Directory
Register-HTSelfTest -Key 'ad.domain' -Name 'Domena Active Directory' -Service 'AD' -Area 'Active Directory' -Test {
    $d = Get-ADDomain -ErrorAction Stop
    $users = @(Get-ADUser -Filter * -ResultSetSize 5 -ErrorAction Stop)
    return "Domena $($d.DNSRoot) (poziom $($d.DomainMode)), odczyt kont: $($users.Count)"
}
#endregion
