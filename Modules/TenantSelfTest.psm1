# Autotest funkcji programu na prawdziwym tenancie (Organizacja > Diagnostyka > «Autotest funkcji»).
# Testy odczytu niczego nie zmieniają. Testy zapisu tworzą obiekty tymczasowe z prefiksem «HT-Autotest-» (grupy, konto
# gościa w domenie example.com, grupy pocztowe, grupa i folder SharePoint), sprawdzają operację i od razu je usuwają
# (grupy i konta - także z kosza katalogu). Pozostałości po przerwanym teście: Get-HTSelfTestLeftovers.
# Moduł nie zależy od interfejsu: test { param($ctx) } zwraca tekst szczegółów (OK), hashtablę @{ Status = 'Uwaga';
# Szczegóły = '…' } albo rzuca wyjątek (Błąd); Skip-HTSelfTest 'powód' - test pominięty.

$script:SelfTestPrefix = 'HT-Autotest-'
$script:SelfTestSkip = 'HTSELFTEST-SKIP:'
$script:SelfTests = New-Object System.Collections.Generic.List[hashtable]
# Moduły, których zmian nie da się bezpiecznie sprawdzić na obiektach testowych: klucz modułu -> powód
$script:SelfTestExemptions = [ordered]@{}
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

function Test-HTSelfTestLicenseText {
    # Komunikat o braku licencji (funkcja wymaga planu, którego tenant albo obiekt testowy nie ma) - krok jako «Uwaga»
    param([AllowEmptyString()][string]$Text)
    return ($Text -match '(?i)licen[cs]j|\blicens|subscription|not licensed|Exchange Online Plan 2|Exchange Online Archiving|requires a (valid )?(license|plan)')
}

function Invoke-HTSelfTestStep {
    <#
        Krok testu zapisu: błąd kroku nie przerywa testu - kolejne kroki działają dalej, a wynik zbiera
        Complete-HTSelfTestSteps. -Optional - błąd kroku to «Uwaga» (np. funkcja zależna od licencji albo replikacji
        usługi); komunikat o braku licencji jest uwagą także bez -Optional; Skip-HTSelfTest w kroku - krok pominięty.
        Zwraca wynik bloku (po błędzie - nic). Zmienne testu są w bloku widoczne; nie nazywaj ich $Step, $Run, $Optional.
    #>
    param([Parameter(Mandatory)][hashtable]$Context, [Parameter(Mandatory)][string]$Step, [Parameter(Mandatory)][scriptblock]$Run, [switch]$Optional)
    if ($null -eq $Context.Steps) { $Context.Steps = New-Object System.Collections.Generic.List[object] }
    try {
        $stepResult = & $Run
        $Context.Steps.Add([PSCustomObject]@{ Name = $Step; Status = 'OK'; Note = '' })
        return $stepResult
    }
    catch {
        $stepMessage = [string]$_.Exception.Message
        if ($stepMessage.StartsWith($script:SelfTestSkip)) {
            $Context.Steps.Add([PSCustomObject]@{ Name = $Step; Status = 'Pominięto'; Note = $stepMessage.Substring($script:SelfTestSkip.Length) })
            return
        }
        $stepStatus = if ($Optional -or (Test-HTSelfTestLicenseText $stepMessage)) { 'Uwaga' } else { 'Błąd' }
        if (Get-Command -Name Compress-HTErrorText -ErrorAction Ignore) { $stepMessage = Compress-HTErrorText -Text $stepMessage -MaxLength 400 }
        $Context.Steps.Add([PSCustomObject]@{ Name = $Step; Status = $stepStatus; Note = $stepMessage })
    }
}

function Complete-HTSelfTestSteps {
    <#
        Wynik testu z kroków (Invoke-HTSelfTestStep): wszystkie udane - tekst z listą kroków; uwagi albo pominięte -
        Status «Uwaga»; błąd któregoś kroku - wyjątek (Błąd) z listą kroków udanych i nieudanych.
    #>
    param([Parameter(Mandatory)][hashtable]$Context, [string]$Subject = '', [string]$Footer = '')
    $steps = if ($Context.Steps) { @($Context.Steps.ToArray()) } else { @() }
    $Context.Steps = $null
    $ok = @($steps | Where-Object { $_.Status -eq 'OK' } | ForEach-Object { $_.Name })
    $other = @($steps | Where-Object { $_.Status -ne 'OK' } | ForEach-Object { "$($_.Name) - $($_.Status.ToLowerInvariant()): $($_.Note)" })
    $parts = @()
    if ($ok.Count) { $parts += "kroki OK ($($ok.Count)/$($steps.Count)): $($ok -join ', ')" }
    $parts += $other
    $text = (@($Subject, ($parts -join ' | '), $Footer) | Where-Object { $_ }) -join ' - '
    $failed = @($steps | Where-Object { $_.Status -eq 'Błąd' }).Count
    if ($failed) { throw "Kroki z błędem: $failed z $($steps.Count). $text" }
    if (@($steps | Where-Object { $_.Status -ne 'OK' }).Count) { return @{ Status = 'Uwaga'; 'Szczegóły' = $text } }
    return $text
}

function Register-HTSelfTestExemption {
    # Moduły, których zmian nie da się bezpiecznie sprawdzić na obiektach testowych (np. czyszczenie urządzenia,
    # zwolnienie poczty z kwarantanny) - w «Pokryciu testami» z powodem zamiast «tylko odczyt»
    param([Parameter(Mandatory)][string[]]$Modules, [Parameter(Mandatory)][string]$Reason)
    foreach ($k in $Modules) { $script:SelfTestExemptions[$k] = $Reason }
}

function Get-HTSelfTestExemptions { return [ordered]@{} + $script:SelfTestExemptions }

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
        $Context.Steps = $null
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
        moduł ma przyciski zmian - test zapisu), tylko odczyt (zmiany bez testu zapisu), zmiany bez testu (zmian nie da
        się bezpiecznie sprawdzić - powód w kolumnie «Bez testu zapisu»), brak (ani odczytu, ani testu).
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
        $exempt = if (-not $writes.Count -and $m.ChangeCount -gt 0 -and $script:SelfTestExemptions.Contains([string]$m.Key)) { [string]$script:SelfTestExemptions[[string]$m.Key] } else { '' }
        $state = if ($exempt) { 'zmiany bez testu' } elseif (-not $m.HasRead -and -not $writes.Count) { 'brak' } elseif ($m.ChangeCount -gt 0 -and -not $writes.Count) { 'tylko odczyt' } else { 'pełne' }
        [PSCustomObject][ordered]@{
            Przestrzeń         = $m.Workspace
            Kategoria          = $m.Category
            Moduł              = $m.Title
            'Przegląd odczytu' = $(if ($m.HasRead) { 'tak' } else { 'nie - bez przycisku odczytu' })
            'Przyciski zmian'  = [int]$m.ChangeCount
            'Testy zapisu'     = ($writes -join '; ')
            Pokrycie           = $state
            'Bez testu zapisu' = $exempt
            Klucz              = $m.Key
            __flag             = $(switch ($state) { 'brak' { 'crit' } 'tylko odczyt' { 'warn' } 'zmiany bez testu' { 'muted' } default { '' } })
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
        foreach ($c in @(Get-MailContact -Filter "Name -like '$prefix*'" -ResultSize Unlimited -ErrorAction Stop)) {
            [PSCustomObject]@{ Obiekt = $c.DisplayName; Rodzaj = 'Kontakt pocztowy'; Usługa = 'Exchange'; Adres = ([string]$c.ExternalEmailAddress -replace '^(?i)smtp:', ''); Id = [string]$c.Guid; __kind = 'MailContact' }
        }
        foreach ($r in @(Get-TransportRule -ResultSize Unlimited -ErrorAction Stop | Where-Object { ([string]$_.Name).StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) })) {
            [PSCustomObject]@{ Obiekt = $r.Name; Rodzaj = 'Reguła transportu'; Usługa = 'Exchange'; Adres = ''; Id = [string]$r.Guid; __kind = 'TransportRule' }
        }
        try {
            foreach ($i in @(Get-TenantAllowBlockListItems -ListType Sender -ErrorAction Stop | Where-Object { ([string]$_.Value).StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) })) {
                [PSCustomObject]@{ Obiekt = [string]$i.Value; Rodzaj = 'Wpis listy dozwolonych i zablokowanych (nadawca)'; Usługa = 'Exchange'; Adres = [string]$i.Value; Id = [string]$i.Identity; __kind = 'AllowBlockSender' }
            }
        }
        catch { Write-Verbose "Lista dozwolonych i zablokowanych: $($_.Exception.Message)" }
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
    if (-not ([string]$Item.Obiekt).StartsWith($script:SelfTestPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { throw "To nie jest obiekt testowy (nazwa nie zaczyna się od $($script:SelfTestPrefix))." }
    switch ([string]$Item.__kind) {
        'Group' { Remove-HTM365Group -Id $Item.Id; try { Remove-HTM365DeletedGroup -Id $Item.Id } catch { Write-Verbose "Kosz katalogu: $($_.Exception.Message)" } }
        'User' { Remove-HTM365User -Id $Item.Id; try { Remove-HTM365DeletedUser -Id $Item.Id } catch { Write-Verbose "Kosz katalogu: $($_.Exception.Message)" } }
        'DeletedItem' { Invoke-HTGraphRequest -Uri "directory/deletedItems/$($Item.Id)" -Method DELETE | Out-Null }
        'DistributionGroup' { Remove-HTMailDistributionGroup -Identity $Item.Id }
        'DynamicGroup' { Remove-HTDynamicGroup -Identity $Item.Id }
        'Mailbox' { Remove-Mailbox -Identity $Item.Id -Confirm:$false -ErrorAction Stop }
        'MailContact' { Remove-HTMailContact -Identity $Item.Id }
        'TransportRule' { Remove-TransportRule -Identity $Item.Id -Confirm:$false -ErrorAction Stop }
        'AllowBlockSender' { Remove-HTTenantAllowBlockItem -ListType Sender -Ids @($Item.Id) }
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

function Assert-HTSelfTestScopes {
    # Krok wymaga uprawnień Microsoft Graph spoza domyślnych - bez nich pominięty z informacją, jak je dodać
    param([Parameter(Mandatory)][string[]]$Scopes, [string]$Feature = '')
    $mg = Get-MgContext
    if ($mg -and "$($mg.AuthType)" -eq 'AppOnly') { return }
    $missing = @($Scopes | Where-Object { @($mg.Scopes) -notcontains $_ })
    if ($missing.Count) { Skip-HTSelfTest "Połączenie bez uprawnień Microsoft Graph: $($missing -join ', ')$(if ($Feature) { " - użyj raz funkcji «$Feature» (program dopisze uprawnienia) i uruchom autotest ponownie" })." }
}

function Get-HTSelfTestSPUser {
    # Zalogowane konto połączonej witryny SharePoint (LoginName «i:0#.f|membership|…»)
    param([Parameter(Mandatory)][hashtable]$Context)
    if ($Context.Data.SPUser) { return $Context.Data.SPUser }
    $u = Get-PnPProperty -ClientObject (Get-PnPWeb -ErrorAction Stop) -Property CurrentUser
    if (-not $u -or -not $u.LoginName) { Skip-HTSelfTest 'Połączenie SharePoint bez konta użytkownika (aplikacja) - test wymaga zalogowanego konta.' }
    $Context.Data.SPUser = [PSCustomObject]@{ LoginName = [string]$u.LoginName; Email = [string]$u.Email; Title = [string]$u.Title }
    return $Context.Data.SPUser
}

function Get-HTSelfTestSPRoles {
    # Poziomy uprawnień witryny do testów (nazwy w języku witryny): odczyt i współtworzenie
    param([Parameter(Mandatory)][hashtable]$Context)
    if ($Context.Data.SPRoles) { return $Context.Data.SPRoles }
    $defs = @(Get-PnPRoleDefinition -ErrorAction Stop)
    $read = [string]@($defs | Where-Object { "$($_.RoleTypeKind)" -eq 'Reader' })[0].Name
    $edit = [string]@($defs | Where-Object { "$($_.RoleTypeKind)" -eq 'Contributor' })[0].Name
    if (-not $read -or -not $edit) { throw "Brak poziomów uprawnień odczytu i współtworzenia wśród: $(@($defs | ForEach-Object { $_.Name }) -join ', ')" }
    $Context.Data.SPRoles = [PSCustomObject]@{ Read = $read; Edit = $edit }
    return $Context.Data.SPRoles
}

function Invoke-HTSelfTestSettingsForm {
    # Zmiana ustawień skrzynki albo grupy jak w formularzu «Edytuj ustawienia…»: formularz -> zmiany -> plan -> zapis
    param([Parameter(Mandatory)][string]$Identity, [Parameter(Mandatory)][System.Collections.IDictionary]$Form, [object[]]$Definitions = @())
    if (-not @($Definitions).Count) { $Definitions = @(Get-HTMailboxSettingDefinitions | Where-Object { $Form.Contains($_.Key) }) }
    $current = Get-HTMailboxSettings -Identity $Identity -Definitions $Definitions
    $readErrors = @($current['__Errors'] | Where-Object { $_ })
    if ($readErrors.Count) { throw "Odczyt ustawień: $($readErrors -join '; ')" }
    $res = Get-HTMailboxSettingChanges -Form $Form -Current $current -Definitions $Definitions
    if (@($res.Errors).Count) { throw "Formularz: $(@($res.Errors) -join '; ')" }
    if (-not @($res.Changes).Count) { return 'Brak zmian' }
    return Invoke-HTMailboxSettingPlan -Identity $Identity -Plan (ConvertTo-HTMailboxSettingPlan -Changes @($res.Changes))
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
    Invoke-HTSelfTestStep -Context $ctx -Step "zespół i kanał «$channelName» (kanałów: $($channels.Count))" -Run { $true } | Out-Null
    Invoke-HTSelfTestStep -Context $ctx -Step 'właściciel zespołu (już członek - bez błędu)' -Run { Add-HTTeamOwner -GroupId $g.Id -UserId $me.Id }
    Invoke-HTSelfTestStep -Context $ctx -Step 'archiwizacja i przywrócenie zespołu' -Run {
        Assert-HTSelfTestScopes -Scopes @('TeamSettings.ReadWrite.All') -Feature 'Zespoły Teams > Archiwizuj zespół'
        Set-HTTeamArchived -TeamId $g.Id -Archived $true
        Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 120 -IntervalSeconds 10 -Message 'Zespół nie jest zarchiwizowany' -Condition { (Invoke-HTGraphRequest -Uri "teams/$($g.Id)?`$select=isArchived").isArchived } | Out-Null
        Set-HTTeamArchived -TeamId $g.Id -Archived $false
        Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 120 -IntervalSeconds 10 -Message 'Zespół nie wrócił z archiwum' -Condition { -not (Invoke-HTGraphRequest -Uri "teams/$($g.Id)?`$select=isArchived").isArchived } | Out-Null
    }
    return Complete-HTSelfTestSteps -Context $ctx -Subject $name -Footer 'grupa usuwana po teście'
}
Register-HTSelfTest -Key 'graph.w.lifecycle' -Name 'Konta z CSV: MFA, licencje, grupy, porównanie, offboarding z kopią i przywrócenie' -Service 'Graph' -Mode 'Write' -Area 'Konta' `
    -Modules @('m365.bulk', 'm365.mfa', 'm365.licenses', 'm365.reclaim', 'm365.licerr', 'm365.groups', 'm365.compare', 'm365.offboarding') -Test {
    param($ctx)
    $me = Get-HTSelfTestMe -Context $ctx
    $domains = @(Get-HTM365Domains)
    if (-not $domains.Count) { throw 'Brak zweryfikowanej domeny do UPN kont testowych' }
    # Konta jak z pliku CSV («Masowe tworzenie kont»): sprawdzenie wiersza, utworzenie (zablokowane), dane i lokalizacja
    $newUser = {
        param($Suffix)
        $n = Get-HTSelfTestName -Context $ctx -Suffix $Suffix
        $row = [PSCustomObject]@{ Imie = 'HT'; Nazwisko = 'Autotest'; NazwaWyswietlana = $n; Login = $n.ToLowerInvariant(); Domena = $domains[0]; Stanowisko = 'Autotest'; Dzial = 'HT-Autotest'; Firma = ''; TelefonKomorkowy = ''; Biuro = ''; LokalizacjaUzycia = 'PL'; Licencje = ''; Grupy = ''; Przelozony = ''; Haslo = '' }
        $check = Test-HTBulkUserRow -Row $row -Domains $domains
        if (-not $check.Valid) { throw "Wiersz CSV konta $($n): $(@($check.Errors) -join '; ')" }
        $created = New-HTM365User -DisplayName $check.DisplayName -UserPrincipalName $check.Upn -Password (New-Password -Length 16 -StartWithLetter $true) -GivenName 'HT' -Surname 'Autotest' -JobTitle 'Autotest' -Department 'HT-Autotest' -UsageLocation 'PL' -AccountEnabled $false
        $userId = [string]$created.id
        Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie konta $($check.Upn)" -Action {
            Remove-HTM365User -Id $userId
            try { Remove-HTM365DeletedUser -Id $userId } catch { Write-Verbose "Kosz katalogu: $($_.Exception.Message)" }
        }.GetNewClosure()
        [PSCustomObject]@{ Id = $userId; UserPrincipalName = $check.Upn; DisplayName = $n }
    }
    $a = & $newUser 'KontoA'
    $b = & $newUser 'KontoB'
    $groupName = Get-HTSelfTestName -Context $ctx -Suffix 'Grupa'
    $group = New-HTM365Group -DisplayName $groupName -Type Security -Description 'Autotest Helpdesk Tools - do usunięcia'
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie grupy $groupName" -Action { Remove-HTM365Group -Id $group.Id }.GetNewClosure()
    foreach ($u in @($a, $b)) { Wait-HTSelfTestCondition -Context $ctx -Message "Konto $($u.UserPrincipalName) niewidoczne" -Condition { Invoke-HTGraphRequest -Uri "users/$($u.Id)?`$select=id" } | Out-Null }
    $inGroup = { param($UserId) @(Get-HTM365UserGroups -Id $UserId | Where-Object { $_.Id -eq $group.Id }).Count }
    $licenseIds = { @(Get-HTM365UserLicenses -Id $a.Id | ForEach-Object { [string]$_.SkuId }) }
    $state = @{ Sku = $null; BackupPath = '' }

    Invoke-HTSelfTestStep -Context $ctx -Step 'konto z wiersza CSV (stanowisko, lokalizacja użycia)' -Run {
        $u = Invoke-HTGraphRequest -Uri "users/$($a.Id)?`$select=jobTitle,usageLocation,accountEnabled"
        Assert-HTSelfTest ($u.jobTitle -eq 'Autotest' -and $u.usageLocation -eq 'PL' -and -not $u.accountEnabled) "Dane konta: stanowisko $($u.jobTitle), lokalizacja $($u.usageLocation), logowanie $($u.accountEnabled)"
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'lokalizacja użycia i ponowne przetworzenie licencji' -Run {
        Invoke-HTGraphRequest -Uri "users/$($a.Id)" -Method PATCH -Body @{ usageLocation = 'PL' } | Out-Null
        Invoke-HTLicenseReprocess -UserId $a.Id
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'grupy: dodanie konta' -Run {
        Add-HTM365UserToGroup -Group $group -User $a
        Wait-HTSelfTestCondition -Context $ctx -Message 'Konto nie jest widoczne w grupie' -Condition { & $inGroup $a.Id } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'porównanie kont i uzupełnienie brakujących grup' -Run {
        $sa = Get-HTUserAccessSummary -UserId $a.Id
        $sb = Get-HTUserAccessSummary -UserId $b.Id
        $missing = @($sa.__groups | Where-Object { $x = $_.Id; (Test-HTM365GroupManageable -Group $_) -and -not @($sb.__groups | Where-Object { $_.Id -eq $x }).Count })
        Assert-HTSelfTest (@($missing | Where-Object { $_.Id -eq $group.Id }).Count) 'Porównanie nie pokazuje brakującej grupy'
        foreach ($g in @($missing | Where-Object { $_.Id -eq $group.Id })) { Add-HTM365UserToGroup -Group $g -User $b }
        Wait-HTSelfTestCondition -Context $ctx -Message 'Drugie konto nie jest w grupie' -Condition { & $inGroup $b.Id } | Out-Null
        Remove-HTM365UserFromGroup -Group $group -User $b
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'MFA: telefon dodany i usunięty' -Run {
        Add-HTM365PhoneMethod -UserId $a.Id -PhoneNumber '+48 600 000 000' | Out-Null
        $phone = Wait-HTSelfTestCondition -Context $ctx -Message 'Telefon niewidoczny w metodach MFA' -Condition { @(Get-HTM365AuthMethods -Id $a.Id | Where-Object { $_.ApiPath -eq 'phoneMethods' })[0] }
        Remove-HTM365AuthMethod -UserId $a.Id -Method $phone
        Wait-HTSelfTestCondition -Context $ctx -Message 'Telefon nie został usunięty' -Condition { -not @(Get-HTM365AuthMethods -Id $a.Id | Where-Object { $_.ApiPath -eq 'phoneMethods' }).Count } | Out-Null
    }
    # Temporary Access Pass działa tylko przy włączonych zasadach TAP w Entra ID - błąd to uwaga
    Invoke-HTSelfTestStep -Context $ctx -Step 'MFA: Temporary Access Pass' -Optional -Run {
        $tap = New-HTM365TemporaryAccessPass -UserId $a.Id -LifetimeInMinutes 60 -IsUsableOnce $true
        Assert-HTSelfTest $tap.temporaryAccessPass 'Brak kodu Temporary Access Pass'
        $m = Wait-HTSelfTestCondition -Context $ctx -Message 'Kod TAP niewidoczny w metodach' -Condition { @(Get-HTM365AuthMethods -Id $a.Id | Where-Object { $_.ApiPath -eq 'temporaryAccessPassMethods' })[0] }
        Remove-HTM365AuthMethod -UserId $a.Id -Method $m
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'licencja: przypisanie (wolna jednostka)' -Run {
        $sku = @(Get-HTSubscribedSkus -Force | Where-Object { $_.Available -gt 0 -and "$($_.Status)" -eq 'Enabled' } | Sort-Object Available -Descending)[0]
        if (-not $sku) { Skip-HTSelfTest 'Brak wolnych licencji w tenancie' }
        $state.Sku = $sku
        Set-HTM365UserLicense -Id $a.Id -AddSkuIds @([string]$sku.SkuId) -UsageLocation 'PL'
        Wait-HTSelfTestCondition -Context $ctx -Message 'Licencja niewidoczna na koncie' -Condition { (& $licenseIds) -contains [string]$sku.SkuId } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'przełożony' -Run {
        Set-HTM365UserManager -Id $a.Id -ManagerId $me.Id
        Wait-HTSelfTestCondition -Context $ctx -Message 'Przełożony nie zapisał się' -Condition { [string](Get-HTM365UserManager -Id $a.Id).id -eq $me.Id } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'kopia ustawień konta do pliku' -Run {
        $dir = Join-Path ([System.IO.Path]::GetTempPath()) "$(Get-HTSelfTestPrefix)$($ctx.Stamp)"
        Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie folderu kopii $dir" -Action { if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force } }.GetNewClosure()
        $state.BackupPath = Save-HTAccountBackup -Backup (Get-HTM365AccountBackup -Id $a.Id) -Directory $dir
        $read = Read-HTAccountBackup -Path $state.BackupPath
        Assert-HTSelfTest (@($read.Groups | Where-Object { $_.Id -eq $group.Id }).Count) 'Kopia nie zawiera grupy'
        Assert-HTSelfTest ([string]$read.Manager.Id -eq $me.Id) 'Kopia nie zawiera przełożonego'
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'offboarding: blokada, hasło, grupy, przełożony, licencje' -Run {
        Set-HTM365UserEnabled -Id $a.Id -Enabled $false -RevokeSessions $true
        Reset-HTM365UserPassword -Id $a.Id -Password (New-Password -Length 16 -StartWithLetter $true) -ForceChange $true
        foreach ($g in @(Get-HTM365UserGroups -Id $a.Id | Where-Object { Test-HTM365GroupManageable -Group $_ })) { Remove-HTM365UserFromGroup -Group $g -User $a }
        if (Get-HTM365UserManager -Id $a.Id) { Remove-HTM365UserManager -Id $a.Id }
        $ids = @(& $licenseIds)
        if ($ids.Count) { Set-HTM365UserLicense -Id $a.Id -RemoveSkuIds $ids }
        Wait-HTSelfTestCondition -Context $ctx -Message 'Po offboardingu konto nadal ma grupę, przełożonego albo licencje' -Condition { -not (& $inGroup $a.Id) -and -not (Get-HTM365UserManager -Id $a.Id) -and -not @(& $licenseIds).Count } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'przywrócenie z kopii (grupy, przełożony, licencje)' -Run {
        if (-not $state.BackupPath) { Skip-HTSelfTest 'Brak kopii ustawień' }
        $backup = Read-HTAccountBackup -Path $state.BackupPath
        $plan = @(Get-HTAccountRestorePlan -Backup $backup | ForEach-Object { $_.Key })
        foreach ($k in 'Groups', 'Manager') { Assert-HTSelfTest ($plan -contains $k) "Plan przywrócenia bez kroku $k" }
        foreach ($g in @($backup.Groups | Where-Object { -not $_.Dynamic -and -not $_.Synced })) { Add-HTM365UserToGroup -Group ([PSCustomObject]$g) -User $a }
        Set-HTM365UserManager -Id $a.Id -ManagerId ([string]$backup.Manager.Id)
        foreach ($l in @($backup.Licenses | Where-Object { $_.Direct })) { Set-HTM365UserLicense -Id $a.Id -AddSkuIds @([string]$l.SkuId) -UsageLocation ([string]$backup.User.UsageLocation) }
        Wait-HTSelfTestCondition -Context $ctx -Message 'Po przywróceniu brak grupy albo przełożonego' -Condition { (& $inGroup $a.Id) -and (Get-HTM365UserManager -Id $a.Id) } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'licencje do odzyskania: usunięcie licencji bezpośrednich' -Run {
        if (-not $state.Sku) { Skip-HTSelfTest 'Konto nie miało licencji (brak wolnych jednostek)' }
        Wait-HTSelfTestCondition -Context $ctx -Message 'Licencja z kopii nie wróciła' -Condition { (& $licenseIds) -contains [string]$state.Sku.SkuId } | Out-Null
        $res = Remove-HTM365DirectLicenses -Id $a.Id -SkuIds @(& $licenseIds)
        Assert-HTSelfTest (-not @($res.Failed).Count) "Nie usunięto: $(@($res.Failed | ForEach-Object { "$($_.Name): $($_.Error)" }) -join '; ')"
        Wait-HTSelfTestCondition -Context $ctx -Message 'Licencje nadal przypisane' -Condition { -not @(& $licenseIds).Count } | Out-Null
    }
    return Complete-HTSelfTestSteps -Context $ctx -Subject "$($a.UserPrincipalName), $($b.UserPrincipalName), grupa $groupName" -Footer 'konta i grupa usuwane po teście (konta także z kosza)'
}

Register-HTSelfTest -Key 'graph.w.deletedgroup' -Name 'Grupa Microsoft 365: usunięcie, przywrócenie z kosza, usunięcie trwałe' -Service 'Graph' -Mode 'Write' -Area 'Grupy' -Modules @('grp.deleted') -Test {
    param($ctx)
    $me = Get-HTSelfTestMe -Context $ctx
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'M365'
    $g = New-HTM365Group -DisplayName $name -Type Microsoft365 -MailNickname ($name.ToLowerInvariant() -replace '[^a-z0-9]', '') -Description 'Autotest Helpdesk Tools - do usunięcia' -Visibility Private -OwnerIds @($me.Id)
    $state = @{ Purged = $false }
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie grupy $name" -Action {
        if ($state.Purged) { return }
        try { Remove-HTM365Group -Id $g.Id } catch { Write-Verbose "Grupa: $($_.Exception.Message)" }
        Remove-HTM365DeletedGroup -Id $g.Id
    }.GetNewClosure()
    $inBin = { @(Get-HTM365DeletedGroups | Where-Object { $_.Id -eq $g.Id }).Count }
    Wait-HTSelfTestCondition -Context $ctx -Message 'Nowa grupa niewidoczna' -Condition { Invoke-HTGraphRequest -Uri "groups/$($g.Id)?`$select=id" } | Out-Null
    Invoke-HTSelfTestStep -Context $ctx -Step 'usunięcie do kosza' -Run {
        Remove-HTM365Group -Id $g.Id
        Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 90 -Message 'Grupa nie trafiła do kosza katalogu' -Condition $inBin | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'przywrócenie' -Run {
        Restore-HTM365DeletedGroup -Id $g.Id
        Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 90 -Message 'Grupa nie została przywrócona' -Condition { Invoke-HTGraphRequest -Uri "groups/$($g.Id)?`$select=id" } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'usunięcie trwałe z kosza' -Run {
        Remove-HTM365Group -Id $g.Id
        Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 90 -Message 'Grupa nie trafiła ponownie do kosza' -Condition $inBin | Out-Null
        Remove-HTM365DeletedGroup -Id $g.Id
        $state.Purged = $true
        Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 90 -Message 'Grupa nadal w koszu' -Condition { -not (& $inBin) } | Out-Null
    }
    return Complete-HTSelfTestSteps -Context $ctx -Subject $name
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

Register-HTSelfTest -Key 'exo.w.distgroup' -Modules @('exo.dl', 'org.newgroup', 'exo.copyaccess') -Name 'Grupa dystrybucyjna: utwórz, członkowie, ustawienia, kopiowanie dostępu, usuń' -Service 'Exchange' -Mode 'Write' -Area 'Grupy' -Test {
    param($ctx)
    $member = Get-HTSelfTestMailbox -Context $ctx
    $domain = Get-HTSelfTestDomain -Context $ctx
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'DL'
    $address = "$($name.ToLowerInvariant())@$domain"
    $created = New-HTMailDistributionGroup -DisplayName $name -Address $address -Type Distribution -Owners @($member) -InternalOnly $true -Hidden $true
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie grupy $created" -Action { Remove-HTMailDistributionGroup -Identity $created }.GetNewClosure()
    $hasMember = { @(Get-HTDistributionGroupMembers -Identity $created | Where-Object { $_.Adres -ieq $member }).Count }
    Invoke-HTSelfTestStep -Context $ctx -Step 'dodanie zaznaczonej skrzynki' -Run {
        Invoke-HTWithRetry { Add-HTDistributionGroupMember -Group $created -Member $member }
        Wait-HTSelfTestCondition -Context $ctx -Message 'Członek nie jest widoczny w grupie' -Condition $hasMember | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'grupy członka' -Optional -Run {
        Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 90 -Message 'Grupa nie jest widoczna w grupach członka' -Condition { @(Get-HTRecipientGroups -Identity $member | Where-Object { $_.Adres -ieq $created }).Count } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'usunięcie członka' -Run {
        Remove-HTDistributionGroupMember -Group $created -Member $member
        Wait-HTSelfTestCondition -Context $ctx -Message 'Członek nadal jest w grupie' -Condition { -not (& $hasMember) } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'członkowie z listy adresów (z błędnym adresem)' -Run {
        $res = Add-HTDistributionGroupMembers -Group $created -Members @($member, "brak-$($ctx.Stamp)@$domain")
        Assert-HTSelfTest ($res.Added -eq 1) "Dodano $($res.Added) zamiast 1"
        Assert-HTSelfTest (@($res.Errors).Count -eq 1) "Błędny adres nie został zgłoszony (błędów: $(@($res.Errors).Count))"
        Wait-HTSelfTestCondition -Context $ctx -Message 'Członek z listy nie jest widoczny' -Condition $hasMember | Out-Null
        Remove-HTDistributionGroupMember -Group $created -Member $member
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'ustawienia grupy (porada pocztowa)' -Run {
        $defs = @(Get-HTMailboxSettingDefinitions -Group | Where-Object { $_.Key -eq 'MailTip' })
        Assert-HTSelfTest $defs.Count 'Brak ustawienia MailTip grupy'
        Invoke-HTSelfTestSettingsForm -Identity $created -Definitions $defs -Form @{ MailTip = 'Autotest Helpdesk Tools' } | Out-Null
        Wait-HTSelfTestCondition -Context $ctx -Message 'Porada pocztowa grupy nie zapisała się' -Condition { [string](Get-HTMailboxSettings -Identity $created -Definitions $defs)['MailTip'] -eq 'Autotest Helpdesk Tools' } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'kopiowanie dostępu (grupa) i odebranie' -Run {
        $item = [PSCustomObject]@{ Rodzaj = 'Grupa dystrybucyjna'; Obiekt = $created; Nazwa = $name; Prawa = 'członek'; __kind = 'Group'; __identity = $created; __folder = '' }
        Copy-HTUserAccessItem -Item $item -TargetUser $member | Out-Null
        Wait-HTSelfTestCondition -Context $ctx -Message 'Skopiowane członkostwo niewidoczne' -Condition $hasMember | Out-Null
        Remove-HTUserAccessItem -Item $item -User $member | Out-Null
        Wait-HTSelfTestCondition -Context $ctx -Message 'Członkostwo nie zostało odebrane' -Condition { -not (& $hasMember) } | Out-Null
    }
    return Complete-HTSelfTestSteps -Context $ctx -Subject "$created (ukryta w GAL, tylko nadawcy wewnętrzni)" -Footer 'grupa usuwana po teście'
}

Register-HTSelfTest -Key 'exo.w.dyngroup' -Modules @('exo.dyn', 'org.newgroup') -Name 'Grupa dynamiczna: utwórz z filtrem, członkowie, zmiana filtru, usuń' -Service 'Exchange' -Mode 'Write' -Area 'Grupy' -Test {
    param($ctx)
    $domain = Get-HTSelfTestDomain -Context $ctx
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'DDG'
    $filter = ConvertTo-HTRecipientFilter -RecipientType 'Skrzynki użytkowników' -Conditions @(@{ Property = 'Department'; Operator = 'eq'; Value = $name })
    $created = New-HTDynamicGroup -DisplayName $name -Address "$($name.ToLowerInvariant())@$domain" -Filter $filter
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie grupy $created" -Action { Remove-HTDynamicGroup -Identity $created }.GetNewClosure()
    Invoke-HTSelfTestStep -Context $ctx -Step 'ukrycie w GAL' -Run { Invoke-HTWithRetry { Set-DynamicDistributionGroup -Identity $created -HiddenFromAddressListsEnabled $true -Confirm:$false -ErrorAction Stop } }
    Invoke-HTSelfTestStep -Context $ctx -Step 'członkowie (oczekiwane 0)' -Run {
        $members = @(Get-HTDynamicGroupMembers -Identity $created)
        Assert-HTSelfTest ($members.Count -eq 0) "Grupa ma członków: $($members.Count) (filtr: $filter)"
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'zmiana filtru' -Run {
        $newFilter = ConvertTo-HTRecipientFilter -RecipientType 'Skrzynki użytkowników' -Conditions @(@{ Property = 'Department'; Operator = 'eq'; Value = "$name-2" })
        Invoke-HTWithRetry { Set-HTDynamicGroupFilter -Identity $created -Filter $newFilter }
        Wait-HTSelfTestCondition -Context $ctx -Message 'Nowy filtr nie zapisał się' -Condition { [string](Get-DynamicDistributionGroup -Identity $created -ErrorAction Stop).RecipientFilter -like "*$name-2*" } | Out-Null
    }
    return Complete-HTSelfTestSteps -Context $ctx -Subject "$created - filtr: $filter" -Footer 'grupa usuwana po teście'
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

Register-HTSelfTest -Key 'exo.w.shared' -Name 'Skrzynka współdzielona: uprawnienia, kalendarz, foldery, reguły, adresy, ustawienia, typ, usuń' -Service 'Exchange' -Mode 'Write' -Area 'Poczta' `
    -Modules @('exo.newmailbox', 'exo.details', 'exo.type', 'exo.perms', 'exo.access', 'exo.accessreport', 'exo.copyaccess', 'exo.autoreply', 'exo.forward', 'exo.calendar', 'exo.folders', 'exo.rules', 'exo.aliases', 'exo.settings', 'exo.settings.csv', 'exo.hold') -Test {
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
    $typeInfo = { Get-HTMailboxTypeInfo -Identity $address }
    # Nowa skrzynka ma tylko uprawnienia nadane w teście
    $permTypes = { @(Get-HTMailboxPermissions -Identity $address | ForEach-Object { $_.Type } | Select-Object -Unique) }

    Invoke-HTSelfTestStep -Context $ctx -Step 'konfiguracja nowej skrzynki (ukrycie w GAL, kopie wysłanych)' -Run {
        $notes = @(Set-HTNewMailboxSetup -Identity $address -Hidden $true -CopySent $true)
        $bad = @($notes | Where-Object { $_ -match 'błąd' })
        if ($bad.Count) { throw ($bad -join '; ') }
        Wait-HTSelfTestCondition -Context $ctx -Message 'Skrzynka nie jest ukryta w GAL' -Condition { (& $typeInfo).'Ukryta w GAL' } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'szczegóły skrzynki' -Run { Assert-HTSelfTest (Get-HTMailboxDetail -Identity $address) 'Brak szczegółów skrzynki' }
    Invoke-HTSelfTestStep -Context $ctx -Step 'pokaż i ukryj w GAL' -Run {
        Set-HTMailboxHiddenFromGAL -Identity $address -Hidden $false
        Wait-HTSelfTestCondition -Context $ctx -Message 'Skrzynka nadal ukryta w GAL' -Condition { -not (& $typeInfo).'Ukryta w GAL' } | Out-Null
        Set-HTMailboxHiddenFromGAL -Identity $address -Hidden $true
        Wait-HTSelfTestCondition -Context $ctx -Message 'Skrzynka nie wróciła do ukrytych' -Condition { (& $typeInfo).'Ukryta w GAL' } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'uprawnienia z listy (pełny, jako, w imieniu; bez automapowania)' -Run {
        $entry = @(ConvertFrom-HTMailboxPermissionLines -Text "$member; pełny, jako, w imieniu; nie")[0]
        Assert-HTSelfTest (-not $entry.Problem) "Lista uprawnień: $($entry.Problem)"
        Invoke-HTWithRetry { Add-HTMailboxPermission -Identity $address -User $member -Type $entry.Types -AutoMapping $entry.AutoMapping }
        Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 90 -Message 'Nie widać wszystkich uprawnień' -Condition { $t = & $permTypes; ($t -contains 'FullAccess' -and $t -contains 'SendAs' -and $t -contains 'SendOnBehalf') } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'kto ma dostęp do skrzynki' -Run {
        $report = @(Get-HTMailboxAccessReport -Identity $address -Folders None)
        Assert-HTSelfTest (@($report | Where-Object { $_.__type -eq 'FullAccess' }).Count) 'Raport dostępu bez pełnego dostępu'
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'automapowanie: włącz i wyłącz' -Run {
        Set-HTMailboxAutoMapping -Identity $address -User $member -Enabled $true
        Set-HTMailboxAutoMapping -Identity $address -User $member -Enabled $false
        Wait-HTSelfTestCondition -Context $ctx -Message 'Po zmianie automapowania brak pełnego dostępu' -Condition { (& $permTypes) -contains 'FullAccess' } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'kopie wysłanych przez delegatów' -Run {
        Set-HTMailboxSentItemsCopy -Identity $address -SentAs $false -SendOnBehalf $false
        Wait-HTSelfTestCondition -Context $ctx -Message 'Kopie wysłanych nie wyłączyły się' -Condition { $c = Get-HTMailboxSentItemsCopy -Identity $address; (-not $c.'Kopia wysłanych «jako»' -and -not $c.'Kopia wysłanych «w imieniu»') } | Out-Null
        Set-HTMailboxSentItemsCopy -Identity $address
        Wait-HTSelfTestCondition -Context $ctx -Message 'Kopie wysłanych nie włączyły się' -Condition { $c = Get-HTMailboxSentItemsCopy -Identity $address; ($c.'Kopia wysłanych «jako»' -and $c.'Kopia wysłanych «w imieniu»') } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'odebranie uprawnień' -Run {
        foreach ($t in 'SendOnBehalf', 'SendAs', 'FullAccess') { Remove-HTMailboxPermission -Identity $address -User $member -Type $t }
        Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 90 -Message 'Uprawnienia nadal widoczne' -Condition { -not @(& $permTypes).Count } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'kopiowanie dostępu (następca) i odebranie' -Run {
        $calendar = Get-HTCalendarFolderIdentity -Identity $address
        $items = @(
            [PSCustomObject]@{ Rodzaj = 'Pełny dostęp'; Obiekt = $address; Nazwa = $name; Prawa = 'FullAccess'; __kind = 'FullAccess'; __identity = $address; __folder = '' }
            [PSCustomObject]@{ Rodzaj = 'Wyślij jako'; Obiekt = $address; Nazwa = $name; Prawa = 'SendAs'; __kind = 'SendAs'; __identity = $address; __folder = '' }
            [PSCustomObject]@{ Rodzaj = 'Kalendarz'; Obiekt = $address; Nazwa = $name; Prawa = 'Reviewer'; __kind = 'Calendar'; __identity = $address; __folder = $calendar }
        )
        foreach ($i in $items) { Invoke-HTWithRetry { Copy-HTUserAccessItem -Item $i -TargetUser $member -AutoMapping $false | Out-Null } }
        Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 90 -Message 'Skopiowany dostęp niewidoczny' -Condition { $t = & $permTypes; ($t -contains 'FullAccess' -and $t -contains 'SendAs') } | Out-Null
        foreach ($i in $items) { Remove-HTUserAccessItem -Item $i -User $member | Out-Null }
        Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 90 -Message 'Skopiowany dostęp nie został odebrany' -Condition { -not @(& $permTypes).Count } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'kalendarz: nadanie i odebranie' -Run {
        Invoke-HTWithRetry { Set-HTCalendarPermission -Identity $address -User $member -AccessRights Reviewer }
        Wait-HTSelfTestCondition -Context $ctx -Message 'Uprawnienie do kalendarza niewidoczne' -Condition { @(Get-HTCalendarPermissions -Identity $address | Where-Object { $_.AccessRights -match 'Reviewer' }).Count } | Out-Null
        Set-HTCalendarPermission -Identity $address -User $member -AccessRights Editor
        Wait-HTSelfTestCondition -Context $ctx -Message 'Zmiana uprawnienia do kalendarza niewidoczna' -Condition { @(Get-HTCalendarPermissions -Identity $address | Where-Object { $_.AccessRights -match 'Editor' }).Count } | Out-Null
        Remove-HTCalendarPermission -Identity $address -User $member
        Wait-HTSelfTestCondition -Context $ctx -Message 'Uprawnienie do kalendarza nie zostało odebrane' -Condition { -not @(Get-HTCalendarPermissions -Identity $address | Where-Object { $_.AccessRights -match 'Editor' }).Count } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'foldery: nadanie (z widocznością nadrzędnych) i odebranie' -Run {
        $inbox = @(Get-HTMailboxFolders -Identity $address | Where-Object { $_.Typ -eq 'Inbox' })[0]
        if (-not $inbox) { Skip-HTSelfTest 'Skrzynka nie ma jeszcze folderu Skrzynka odbiorcza' }
        Invoke-HTWithRetry { Grant-HTMailboxFolderAccess -Mailbox $address -Paths @($inbox.__path) -User $member -AccessRights Reviewer -ParentVisibility | Out-Null }
        Wait-HTSelfTestCondition -Context $ctx -Message 'Uprawnienie do folderu niewidoczne' -Condition { @(Get-HTMailboxFolderPermissionRows -Mailbox $address -Path $inbox.__path | Where-Object { $_.Prawa -match 'Reviewer' }).Count } | Out-Null
        $report = @(Get-HTMailboxAccessReport -Identity $address -Folders Standard | Where-Object { $_.__type -eq 'Folder' -and $_.Prawa -match 'Reviewer' })
        Assert-HTSelfTest $report.Count 'Raport dostępu nie pokazuje uprawnienia do folderu'
        Remove-HTMailboxFolderPermissionEntry -FolderIdentity $report[0].__folder -User $member
        Revoke-HTMailboxFolderAccess -Mailbox $address -Paths @('\') -User $member | Out-Null
        Wait-HTSelfTestCondition -Context $ctx -Message 'Uprawnienie do folderu nie zostało odebrane' -Condition { -not @(Get-HTMailboxFolderPermissionRows -Mailbox $address -Path $inbox.__path | Where-Object { $_.Prawa -match 'Reviewer' }).Count } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'reguła skrzynki: wyłączenie i usunięcie' -Run {
        $ruleName = "$name-Regula"
        Invoke-HTWithRetry { New-InboxRule -Mailbox $address -Name $ruleName -SubjectContainsWords $ruleName -MarkAsRead $true -Confirm:$false -ErrorAction Stop | Out-Null }
        $rule = Wait-HTSelfTestCondition -Context $ctx -Message 'Reguła niewidoczna' -Condition { @(Get-HTInboxRules -Identity $address | Where-Object { $_.Name -eq $ruleName })[0] }
        Disable-HTInboxRule -Mailbox $address -Identity $rule.RuleIdentity
        Wait-HTSelfTestCondition -Context $ctx -Message 'Reguła nie wyłączyła się' -Condition { @(Get-HTInboxRules -Identity $address | Where-Object { $_.Name -eq $ruleName -and -not $_.Enabled }).Count } | Out-Null
        Remove-HTInboxRule -Mailbox $address -Identity $rule.RuleIdentity
        Wait-HTSelfTestCondition -Context $ctx -Message 'Reguła nie została usunięta' -Condition { -not @(Get-HTInboxRules -Identity $address | Where-Object { $_.Name -eq $ruleName }).Count } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'adresy: alias, adres główny, usunięcie aliasu' -Run {
        $alias = "$($name.ToLowerInvariant())-alias@$domain"
        $primary = { [string](@(Get-HTMailboxAddresses -Identity $address | Where-Object { $_.Główny })[0]).Adres }
        Add-HTMailboxAddress -Identity $address -Address $alias
        Wait-HTSelfTestCondition -Context $ctx -Message 'Alias niewidoczny' -Condition { @(Get-HTMailboxAddresses -Identity $address | Where-Object { $_.Adres -ieq $alias }).Count } | Out-Null
        Set-HTMailboxPrimaryAddress -Identity $address -Address $alias
        Wait-HTSelfTestCondition -Context $ctx -Message 'Adres główny nie zmienił się' -Condition { (& $primary) -ieq $alias } | Out-Null
        Set-HTMailboxPrimaryAddress -Identity $alias -Address $address
        Wait-HTSelfTestCondition -Context $ctx -Message 'Adres główny nie wrócił' -Condition { (& $primary) -ieq $address } | Out-Null
        Remove-HTMailboxAddress -Identity $address -Value "smtp:$alias"
        Wait-HTSelfTestCondition -Context $ctx -Message 'Alias nie został usunięty' -Condition { -not @(Get-HTMailboxAddresses -Identity $address | Where-Object { $_.Adres -ieq $alias }).Count } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'przekierowanie: ustawienie i usunięcie' -Run {
        $target = "$($name.ToLowerInvariant())@example.com"
        $forward = { [string](Get-EXOMailbox -Identity $address -Properties ForwardingSmtpAddress -ErrorAction Stop).ForwardingSmtpAddress }
        Set-HTMailboxForwarding -Identity $address -ForwardTo $target -KeepCopy $true
        Wait-HTSelfTestCondition -Context $ctx -Message 'Przekierowanie nie zapisało się' -Condition { (& $forward) -like "*$target" } | Out-Null
        Set-HTMailboxForwarding -Identity $address -ForwardTo ''
        Wait-HTSelfTestCondition -Context $ctx -Message 'Przekierowanie nie zostało usunięte' -Condition { -not (& $forward) } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'autoodpowiedź: włącz i wyczyść' -Run {
        Set-HTMailboxAutoReply -Identity $address -State Enabled -InternalMessage 'Autotest Helpdesk Tools' -ExternalMessage 'Autotest Helpdesk Tools'
        Assert-HTSelfTest ("$((Get-HTMailboxAutoReply -Identity $address).AutoReplyState)" -eq 'Enabled') 'Autoodpowiedź nie włączyła się'
        Clear-HTMailboxAutoReply -Identity $address
        Assert-HTSelfTest ("$((Get-HTMailboxAutoReply -Identity $address).AutoReplyState)" -eq 'Disabled') 'Autoodpowiedź nie wyłączyła się'
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'ustawienia skrzynki (formularz: porada pocztowa, atrybut)' -Run {
        $form = @{ MailTip = 'Autotest Helpdesk Tools'; CustomAttribute10 = 'HT-Autotest' }
        Invoke-HTSelfTestSettingsForm -Identity $address -Form $form | Out-Null
        $defs = @(Get-HTMailboxSettingDefinitions | Where-Object { $form.Contains($_.Key) })
        Wait-HTSelfTestCondition -Context $ctx -Message 'Ustawienia nie zapisały się' -Condition { $cur = Get-HTMailboxSettings -Identity $address -Definitions $defs; ([string]$cur['MailTip'] -eq $form.MailTip -and [string]$cur['CustomAttribute10'] -eq $form.CustomAttribute10) } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'kopia ustawień kalendarza ze skrzynki wzorcowej' -Run {
        $defs = @(Get-HTMailboxSettingDefinitions -Sections 'Calendar')
        $source = Get-HTMailboxSettings -Identity $member -Sections 'Calendar'
        $form = Get-HTMailboxSettingCopyForm -Source $source -Sections 'Calendar'
        Assert-HTSelfTest $form.Count 'Brak ustawień kalendarza do skopiowania'
        Invoke-HTSelfTestSettingsForm -Identity $address -Form $form -Definitions $defs | Out-Null
        Wait-HTSelfTestCondition -Context $ctx -Message 'Ustawienia kalendarza nie są takie jak we wzorcu' -Condition { [string](Get-HTMailboxSettings -Identity $address -Sections 'Calendar')['WeekStartDay'] -eq [string]$source['WeekStartDay'] } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'ustawienia z wiersza CSV' -Run {
        $row = ConvertFrom-HTMailboxSettingsCsvRow -Row ([PSCustomObject]@{ Skrzynka = $address; CustomAttribute11 = 'HT-Autotest-CSV' })
        Assert-HTSelfTest $row.Valid "Wiersz CSV: $(@($row.Errors) -join '; ')"
        Invoke-HTMailboxSettingPlan -Identity $row.Identity -Plan (ConvertTo-HTMailboxSettingPlan -Changes @($row.Changes)) | Out-Null
        $defs = @(Get-HTMailboxSettingDefinitions | Where-Object { $_.Key -eq 'CustomAttribute11' })
        Wait-HTSelfTestCondition -Context $ctx -Message 'Ustawienie z CSV nie zapisało się' -Condition { [string](Get-HTMailboxSettings -Identity $address -Definitions $defs)['CustomAttribute11'] -eq 'HT-Autotest-CSV' } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'retencja: usunięte elementy 30 dni, Litigation Hold wyłączony' -Run {
        Set-HTMailboxRetainDeletedItems -Identity $address -Days 30
        Wait-HTSelfTestCondition -Context $ctx -Message 'Okres przechowywania nie zapisał się' -Condition { [string](Get-EXOMailbox -Identity $address -Properties RetainDeletedItemsFor -ErrorAction Stop).RetainDeletedItemsFor -like '30.*' } | Out-Null
        # Włączenia Litigation Hold nie testujemy: usunięta skrzynka z blokadą (także opóźnioną po wyłączeniu) staje się nieaktywna
        Set-HTMailboxLitigationHold -Identity $address -Enabled $false
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'archiwum' -Optional -Run {
        Enable-HTMailboxArchive -Identity $address
        Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 120 -IntervalSeconds 10 -Message 'Archiwum nie jest aktywne' -Condition { (& $typeInfo).Archiwum -eq 'Aktywne' } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'zmiana typu: zwykła i z powrotem współdzielona' -Run {
        Invoke-HTWithRetry { Convert-HTMailboxType -Identity $address -Type Regular }
        Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 120 -IntervalSeconds 10 -Message 'Skrzynka nie zmieniła typu na zwykłą' -Condition { (& $typeInfo).'Typ (Exchange)' -eq 'UserMailbox' } | Out-Null
        Invoke-HTWithRetry { Convert-HTMailboxType -Identity $address -Type Shared }
        Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 120 -IntervalSeconds 10 -Message 'Skrzynka nie wróciła do typu współdzielonego' -Condition { (& $typeInfo).'Typ (Exchange)' -eq 'SharedMailbox' } | Out-Null
    }
    return Complete-HTSelfTestSteps -Context $ctx -Subject $address -Footer 'skrzynka usuwana po teście (także z kosza katalogu)'
}

Register-HTSelfTest -Key 'exo.w.room' -Name 'Sala i lista sal: utwórz, konfiguracja, ustawienia rezerwacji, usuń' -Service 'Exchange' -Mode 'Write' -Area 'Poczta' -Modules @('exo.newmailbox', 'exo.booking') -Test {
    param($ctx)
    $domain = Get-HTSelfTestDomain -Context $ctx
    $listName = Get-HTSelfTestName -Context $ctx -Suffix 'Sale'
    $roomList = New-HTRoomList -DisplayName $listName -Address "$($listName.ToLowerInvariant())@$domain"
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie listy sal $roomList" -Action { Remove-HTMailDistributionGroup -Identity $roomList }.GetNewClosure()
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'Sala'
    $room = New-HTResourceMailbox -Type Room -DisplayName $name -Address "$($name.ToLowerInvariant())@$domain" -Capacity 4
    $state = @{ ObjectId = '' }
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie sali $room" -Action {
        Remove-Mailbox -Identity $room -Confirm:$false -ErrorAction Stop
        if ($state.ObjectId -and $Global:ConnectedToGraphAPI) { try { Remove-HTM365DeletedUser -Id $state.ObjectId } catch { Write-Verbose "Kosz katalogu: $($_.Exception.Message)" } }
    }.GetNewClosure()
    $mbx = Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 180 -IntervalSeconds 10 -Message 'Nowa sala niewidoczna' -Condition { Get-EXOMailbox -Identity $room -ErrorAction Stop }
    $state.ObjectId = [string]$mbx.ExternalDirectoryObjectId
    Invoke-HTSelfTestStep -Context $ctx -Step 'lista sal' -Run {
        Wait-HTSelfTestCondition -Context $ctx -Message 'Nowa lista sal niewidoczna' -Condition { @(Get-HTRoomLists | Where-Object { $_.Adres -ieq $roomList }).Count } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'konfiguracja nowej sali (ukrycie w GAL, lista sal)' -Run {
        $notes = @(Set-HTNewMailboxSetup -Identity $room -Hidden $true -RoomList $roomList)
        $bad = @($notes | Where-Object { $_ -match 'błąd' })
        if ($bad.Count) { throw ($bad -join '; ') }
        Wait-HTSelfTestCondition -Context $ctx -Message 'Sala nie jest na liście sal' -Condition { @(Get-HTDistributionGroupMembers -Identity $roomList | Where-Object { $_.Adres -ieq $room }).Count } | Out-Null
    }
    # Usługa Places replikuje nowe sale z opóźnieniem - błąd tego kroku to uwaga, nie błąd programu
    Invoke-HTSelfTestStep -Context $ctx -Step 'dane miejsca (pojemność, budynek, piętro)' -Optional -Run {
        $notes = @(Set-HTNewMailboxSetup -Identity $room -Place @{ Capacity = 6; Building = 'HT-Autotest'; Floor = 1 })
        $bad = @($notes | Where-Object { $_ -match 'błąd' })
        if ($bad.Count) { throw ($bad -join '; ') }
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'ustawienia rezerwacji' -Run {
        Invoke-HTWithRetry { Set-HTRoomBookingSettings -Identity $room -Settings @{ AutomateProcessing = 'AutoAccept'; BookingWindowInDays = 90; AllowConflicts = $false; AddOrganizerToSubject = $true } }
        Wait-HTSelfTestCondition -Context $ctx -Message 'Ustawienia rezerwacji nie zapisały się' -Condition { $b = Get-HTRoomBookingSettings -Identity $room -RecipientTypeDetails 'RoomMailbox'; ([int]$b.__settings.BookingWindowInDays -eq 90 -and "$($b.__settings.AutomateProcessing)" -eq 'AutoAccept') } | Out-Null
    }
    return Complete-HTSelfTestSteps -Context $ctx -Subject "$room (lista sal $roomList)" -Footer 'sala i lista usuwane po teście'
}

Register-HTSelfTest -Key 'exo.w.contact' -Name 'Kontakt pocztowy: utwórz, zmień, ukryj, usuń' -Service 'Exchange' -Mode 'Write' -Area 'Poczta' -Modules @('exo.contacts') -Test {
    param($ctx)
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'Kontakt'
    $email = "$($name.ToLowerInvariant())@example.com"
    $id = New-HTMailContact -DisplayName "$name Test" -Email $email -Company 'HT-Autotest' -Title 'Autotest' -Hidden $true
    $state = @{ Removed = $false }
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie kontaktu $email" -Action { if (-not $state.Removed) { Remove-HTMailContact -Identity $id } }.GetNewClosure()
    $find = { @(Get-HTMailContacts | Where-Object { $_.Identity -eq $id })[0] }
    Invoke-HTSelfTestStep -Context $ctx -Step 'odczyt (firma, ukrycie w GAL)' -Run {
        Wait-HTSelfTestCondition -Context $ctx -Message 'Nowy kontakt niewidoczny albo bez danych' -Condition { $c = & $find; ($c -and $c.Firma -eq 'HT-Autotest' -and $c.'Ukryty w GAL') } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'zmiana danych' -Run {
        Set-HTMailContactDetails -Identity $id -Company 'HT-Autotest-2' -Phone '+48 000 000 000' -Title '-'
        Wait-HTSelfTestCondition -Context $ctx -Message 'Zmienione dane niewidoczne' -Condition { $c = & $find; ($c -and $c.Firma -eq 'HT-Autotest-2' -and -not $c.Stanowisko) } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'pokaż w GAL' -Run {
        Set-HTMailContactHidden -Identity $id -Hidden $false
        Wait-HTSelfTestCondition -Context $ctx -Message 'Kontakt nadal ukryty' -Condition { $c = & $find; ($c -and -not $c.'Ukryty w GAL') } | Out-Null
        Set-HTMailContactHidden -Identity $id -Hidden $true
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'usunięcie' -Run {
        Remove-HTMailContact -Identity $id
        $state.Removed = $true
        Wait-HTSelfTestCondition -Context $ctx -Message 'Kontakt nadal widoczny' -Condition { -not (& $find) } | Out-Null
    }
    return Complete-HTSelfTestSteps -Context $ctx -Subject $email
}

Register-HTSelfTest -Key 'exo.w.transport' -Name 'Reguła transportu (tryb testowy): włącz, wyłącz, usuń' -Service 'Exchange' -Mode 'Write' -Area 'Poczta' -Modules @('exo.transport') -Test {
    param($ctx)
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'Regula'
    # Tryb Audit (test bez działań na poczcie) i warunek na unikatowy temat - reguła nie wpływa na wiadomości
    New-TransportRule -Name $name -SubjectContainsWords $name -SetHeaderName 'X-HT-Autotest' -SetHeaderValue '1' -Mode Audit -Enabled $false -Comments 'Autotest Helpdesk Tools - do usunięcia' -ErrorAction Stop | Out-Null
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie reguły $name" -Action { Remove-TransportRule -Identity $name -Confirm:$false -ErrorAction Stop }.GetNewClosure()
    $find = { @(Get-HTTransportRules | Where-Object { $_.Reguła -eq $name })[0] }
    $rule = $null
    Invoke-HTSelfTestStep -Context $ctx -Step 'lista reguł (wyłączona, tryb testowy)' -Run {
        Wait-HTSelfTestCondition -Context $ctx -Message 'Reguła niewidoczna' -Condition { $r = & $find; ($r -and $r.Stan -eq 'Disabled' -and $r.Tryb -eq 'Audit') } | Out-Null
    }
    $rule = & $find
    Invoke-HTSelfTestStep -Context $ctx -Step 'włączenie' -Run {
        Set-HTTransportRuleState -Identity $rule.Id -Enabled $true
        Wait-HTSelfTestCondition -Context $ctx -Message 'Reguła nie włączyła się' -Condition { (& $find).Stan -eq 'Enabled' } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'wyłączenie' -Run {
        Set-HTTransportRuleState -Identity $rule.Id -Enabled $false
        Wait-HTSelfTestCondition -Context $ctx -Message 'Reguła nie wyłączyła się' -Condition { (& $find).Stan -eq 'Disabled' } | Out-Null
    }
    return Complete-HTSelfTestSteps -Context $ctx -Subject $name -Footer 'reguła usuwana po teście'
}

Register-HTSelfTest -Key 'exo.w.tabl' -Name 'Lista dozwolonych i zablokowanych: blokada nadawcy i usunięcie' -Service 'Exchange' -Mode 'Write' -Area 'Poczta' -Modules @('exo.tabl') -Test {
    param($ctx)
    $sender = "$((Get-HTSelfTestName -Context $ctx -Suffix 'Nadawca').ToLowerInvariant())@example.com"
    $state = @{ Id = ''; Removed = $false }
    $find = { @(Get-HTTenantAllowBlockList -ListType Sender | Where-Object { [string]$_.Wartość -ieq $sender })[0] }
    Add-HTTenantAllowBlockItem -ListType Sender -Entries @($sender) -Action Block -Days 1 -Notes 'Autotest Helpdesk Tools - do usunięcia'
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie wpisu $sender" -Action {
        if ($state.Removed) { return }
        $id = $state.Id
        if (-not $id) { $id = [string](& $find).Id }
        if ($id) { Remove-HTTenantAllowBlockItem -ListType Sender -Ids @($id) }
    }.GetNewClosure()
    Invoke-HTSelfTestStep -Context $ctx -Step 'odczyt wpisu (blokada, 1 dzień)' -Run {
        $item = Wait-HTSelfTestCondition -Context $ctx -Message 'Wpis niewidoczny' -Condition { & $find }
        $state.Id = [string]$item.Id
        Assert-HTSelfTest ($item.Akcja -eq 'Blokuj') "Akcja wpisu: $($item.Akcja)"
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'usunięcie' -Run {
        if (-not $state.Id) { Skip-HTSelfTest 'Brak identyfikatora wpisu' }
        Remove-HTTenantAllowBlockItem -ListType Sender -Ids @($state.Id)
        $state.Removed = $true
        Wait-HTSelfTestCondition -Context $ctx -Message 'Wpis nadal widoczny' -Condition { -not (& $find) } | Out-Null
    }
    return Complete-HTSelfTestSteps -Context $ctx -Subject $sender
}

Register-HTSelfTestExemption -Modules @('exo.mobile') -Reason 'Usunięcie powiązania wymaga prawdziwego telefonu z pocztą - urządzenia nie da się utworzyć testowo.'
Register-HTSelfTestExemption -Modules @('exo.quarantine') -Reason 'Wymaga wiadomości w kwarantannie; zwolnienie dostarczyłoby prawdziwą pocztę do odbiorców.'
Register-HTSelfTestExemption -Modules @('exo.recover') -Reason 'Wymaga usuniętych elementów w skrzynce i roli «Mailbox Import Export»; przywrócenie zmienia zawartość skrzynki użytkownika.'
#endregion

#region Testy: SharePoint (połączona witryna)
Register-HTSelfTest -Key 'spo.site' -Name 'Witryna, biblioteki i uprawnienia' -Service 'SharePoint' -Area 'SharePoint' -Test {
    $info = Get-HTSPSiteInfo
    $libraries = @(Get-HTSPLibraries)
    $groups = @(Get-HTSPGroups)
    $perms = if ($libraries.Count) { @(Get-HTSPPermissions -Node $libraries[0]) } else { @() }
    return "$($info.'Tytuł') ($($info.Adres)): bibliotek $($libraries.Count), grup $($groups.Count), uprawnień biblioteki «$(if ($libraries.Count) { $libraries[0].Title })»: $($perms.Count)"
}

Register-HTSelfTest -Key 'spo.w.group' -Modules @('sp.groups', 'sp.siteperms', 'sp.useraccess') -Name 'Grupa SharePoint: członkowie, ustawienia, uprawnienia witryny, dostęp użytkownika, usuń' -Service 'SharePoint' -Mode 'Write' -Area 'SharePoint' -Test {
    param($ctx)
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'SP'
    New-HTSPGroup -Title $name -Description 'Autotest Helpdesk Tools - do usunięcia' | Out-Null
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie grupy $name" -Action { Remove-HTSPGroup -Group $name }.GetNewClosure()
    $me = Get-HTSelfTestSPUser -Context $ctx
    $roles = Get-HTSelfTestSPRoles -Context $ctx
    $isMember = { @(Get-HTSPGroupMembers -Group $name | Where-Object { $_.LoginName -ieq $me.LoginName }).Count }
    $webAssignment = { @(Get-HTSPWebPermissions | Where-Object { $_.Principal -eq $name })[0] }
    Invoke-HTSelfTestStep -Context $ctx -Step 'nowa grupa na liście' -Run { Assert-HTSelfTest (@(Get-HTSPGroups | Where-Object { $_.Title -eq $name }).Count) 'Nowa grupa nie jest widoczna' }
    Invoke-HTSelfTestStep -Context $ctx -Step 'członek: dodanie i usunięcie' -Run {
        Add-HTSPGroupMember -Group $name -LoginName $me.LoginName
        Wait-HTSelfTestCondition -Context $ctx -Message 'Członek niewidoczny' -Condition $isMember | Out-Null
        Remove-HTSPGroupMember -Group $name -LoginName $me.LoginName
        Wait-HTSelfTestCondition -Context $ctx -Message 'Członek nie został usunięty' -Condition { -not (& $isMember) } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'ustawienia grupy' -Run {
        Set-HTSPGroupOptions -Group $name -Settings @{ Description = 'Autotest Helpdesk Tools 2'; AllowRequestToJoinLeave = $false; OnlyAllowMembersViewMembership = $true }
        $o = Get-HTSPGroupOptions -Group $name
        Assert-HTSelfTest ($o.Description -eq 'Autotest Helpdesk Tools 2' -and $o.OnlyAllowMembersViewMembership) "Ustawienia grupy: opis «$($o.Description)», tylko członkowie widzą członków: $($o.OnlyAllowMembersViewMembership)"
    }
    Invoke-HTSelfTestStep -Context $ctx -Step "uprawnienia grupy do witryny («$($roles.Read)»)" -Run {
        Set-HTSPGroupWebRole -Group $name -Role $roles.Read
        $a = Wait-HTSelfTestCondition -Context $ctx -Message 'Uprawnienie grupy do witryny niewidoczne' -Condition $webAssignment
        Revoke-HTSPWebPermission -Assignment $a
        Wait-HTSelfTestCondition -Context $ctx -Message 'Uprawnienie do witryny nie zostało odebrane' -Condition { -not (& $webAssignment) } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'uprawnienia witryny: nadanie i odebranie (formularz)' -Run {
        Grant-HTSPWebPermission -Principal $name -PrincipalType SharePointGroup -Role $roles.Read
        Wait-HTSelfTestCondition -Context $ctx -Message 'Nadane uprawnienie niewidoczne' -Condition $webAssignment | Out-Null
        Set-HTSPGroupWebRole -Group $name -Role $roles.Read -Remove
        Wait-HTSelfTestCondition -Context $ctx -Message 'Uprawnienie nie zostało odebrane' -Condition { -not (& $webAssignment) } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'dostęp użytkownika: członkostwo w grupie i usunięcie z grupy' -Run {
        Add-HTSPGroupMember -Group $name -LoginName $me.LoginName
        Wait-HTSelfTestCondition -Context $ctx -Message 'Członek niewidoczny' -Condition $isMember | Out-Null
        $row = Wait-HTSelfTestCondition -Context $ctx -Message 'Raport dostępu nie pokazuje członkostwa' -Condition { @(Get-HTSPUserAccessReport -Login $me.LoginName -Depth 0 | Where-Object { $_.__kind -eq 'GroupMember' -and $_.__group -eq $name })[0] }
        Remove-HTSPGroupMember -Group $row.__group -LoginName $me.LoginName
        Wait-HTSelfTestCondition -Context $ctx -Message 'Członek nie został usunięty' -Condition { -not (& $isMember) } | Out-Null
    }
    return Complete-HTSelfTestSteps -Context $ctx -Subject "$name (połączona witryna)" -Footer 'grupa usuwana po teście; administratorów kolekcji test nie zmienia'
}

Register-HTSelfTest -Key 'spo.w.content' -Name 'Biblioteka testowa: ustawienia, kolumny, struktura, wysyłanie, wersje, wyewidencjonowanie, kopiowanie, uprawnienia, kosz' -Service 'SharePoint' -Mode 'Write' -Area 'SharePoint' `
    -Modules @('sp.newlib', 'sp.libsettings', 'sp.columns', 'sp.structure', 'sp.upload', 'sp.files', 'sp.copymove', 'sp.checkedout', 'sp.versions', 'sp.perms', 'sp.recycle', 'sp.newfolder') -Test {
    param($ctx)
    $stampPrefix = "$(Get-HTSelfTestPrefix)$($ctx.Stamp)"
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'Bib'
    $lib = New-HTSPLibrary -Title $name -Description 'Autotest Helpdesk Tools - do usunięcia' -OnQuickLaunch $false -Versioning $true -MajorVersions 100
    $state = @{ Removed = $false }
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie biblioteki $name" -Action {
        if (-not $state.Removed) { Remove-PnPList -Identity $lib.ListId -Force -ErrorAction Stop }
        # Elementy testu w koszu witryny (biblioteka, folder) - usuwane trwale
        foreach ($i in @(Get-HTSPRecycleBinItems -Days 1 | Where-Object { ([string]$_.Nazwa).StartsWith($stampPrefix, [System.StringComparison]::OrdinalIgnoreCase) })) { Clear-HTSPRecycleBinItem -Id $i.Id }
    }.GetNewClosure()
    $local = Join-Path ([System.IO.Path]::GetTempPath()) "$stampPrefix-Wysylka"
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie folderu $local" -Action { if (Test-Path -LiteralPath $local) { Remove-Item -LiteralPath $local -Recurse -Force } }.GetNewClosure()
    $folderNode = { param($Path) [PSCustomObject]@{ Title = (Split-Path -Path $Path -Leaf); ServerRelativeUrl = "$($lib.ServerRelativeUrl)/$Path"; ListTitle = $lib.ListTitle; ListId = $lib.ListId; IsLibrary = $false; ItemCount = 0 } }
    $exists = { param($Url) try { [bool](Get-PnPFolder -Url $Url -ErrorAction Stop) } catch { $false } }
    $fileExists = { param($Url) try { [bool](Get-PnPFile -Url $Url -ErrorAction Stop) } catch { $false } }
    $uploadNode = & $folderNode "Projekty/$(Split-Path -Path $local -Leaf)"
    $fileUrl = "$($uploadNode.ServerRelativeUrl)/plik.txt"

    Invoke-HTSelfTestStep -Context $ctx -Step 'ustawienia biblioteki (opis, limit wersji, menu witryny)' -Run {
        $res = Get-HTSPLibrarySettingChanges -Form @{ Description = 'Autotest Helpdesk Tools 2'; MajorVersions = '150'; OnQuickLaunch = 'Tak' } -Current (Get-HTSPLibrarySettings -Node $lib).__values
        Assert-HTSelfTest (-not @($res.Errors).Count) "Formularz: $(@($res.Errors) -join '; ')"
        Set-HTSPLibrarySettings -Node $lib -Settings $res.Settings | Out-Null
        $v = (Get-HTSPLibrarySettings -Node $lib).__values
        Assert-HTSelfTest ($v.Description -eq 'Autotest Helpdesk Tools 2' -and $v.MajorVersions -eq 150 -and $v.OnQuickLaunch) "Po zmianie: opis «$($v.Description)», limit $($v.MajorVersions), menu witryny $($v.OnQuickLaunch)"
        Set-HTSPLibrarySettings -Node $lib -Settings @{ OnQuickLaunch = $false } | Out-Null
        Assert-HTSelfTest (-not (Get-HTSPLibrarySettings -Node $lib).__values.OnQuickLaunch) 'Biblioteka nie zniknęła z menu witryny'
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'kolumny: dodanie (wybór, wymagana) i usunięcie' -Run {
        $spec = @(ConvertFrom-HTSPColumnSpec -Text 'HT Autotest: Wybór [A, B] *')[0]
        Assert-HTSelfTest $spec.Valid "Kolumna: $(@($spec.Errors) -join '; ')"
        Add-HTSPLibraryColumn -Node $lib -Column $spec
        $col = @(Get-HTSPLibraryColumns -Node $lib | Where-Object { $_.Kolumna -eq 'HT Autotest' })[0]
        Assert-HTSelfTest ($col -and $col.Wymagana -and $col.Opcje -match 'A, B') 'Nowa kolumna niewidoczna albo bez opcji'
        Remove-HTSPLibraryColumn -ListTitle $col.__list -Field $col.'Nazwa wewnętrzna'
        Assert-HTSelfTest (-not @(Get-HTSPLibraryColumns -Node $lib | Where-Object { $_.Kolumna -eq 'HT Autotest' }).Count) 'Kolumna nie została usunięta'
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'struktura folderów z tekstu (podgląd i utworzenie)' -Run {
        $parsed = ConvertFrom-HTSPStructureText -Text "Projekty`n    2026`n    Archiwum`nKadry/Umowy"
        Assert-HTSelfTest (-not @($parsed.Errors).Count) "Struktura: $(@($parsed.Errors) -join '; ')"
        $preview = @(Invoke-HTSPStructure -Items $parsed.Items -BaseNode $lib -WhatIf)
        Assert-HTSelfTest (-not @($preview | Where-Object { $_.Status -like 'Błąd*' }).Count) "Podgląd: $(@($preview | Where-Object { $_.Status -like 'Błąd*' } | ForEach-Object { $_.Szczegóły }) -join '; ')"
        $rows = @(Invoke-HTSPStructure -Items $parsed.Items -BaseNode $lib)
        $bad = @($rows | Where-Object { $_.Status -like 'Błąd*' })
        if ($bad.Count) { throw "Błędy: $(@($bad | ForEach-Object { "$($_.Ścieżka): $($_.Szczegóły)" }) -join '; ')" }
        foreach ($p in 'Projekty/2026', 'Projekty/Archiwum', 'Kadry/Umowy') { Assert-HTSelfTest (& $exists "$($lib.ServerRelativeUrl)/$p") "Brak folderu $p" }
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'wysłanie folderu z dysku (z podfolderem)' -Run {
        New-Item -ItemType Directory -Path (Join-Path $local 'Pod') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $local 'plik.txt') -Value 'Autotest Helpdesk Tools 1' -Encoding utf8
        Set-Content -LiteralPath (Join-Path $local 'Pod\drugi.txt') -Value 'Autotest Helpdesk Tools' -Encoding utf8
        $rows = @(Send-HTSPLocalFolder -LocalPath $local -TargetNode (& $folderNode 'Projekty'))
        $bad = @($rows | Where-Object { $_.Status -ne 'Wysłano' })
        if ($bad.Count -or $rows.Count -ne 2) { throw "Wysłano $(@($rows | Where-Object Status -eq 'Wysłano').Count) z 2: $(@($bad | ForEach-Object { "$($_.Plik): $($_.Szczegóły)" }) -join '; ')" }
        Assert-HTSelfTest (@(Get-HTSPFolderFiles -Node $uploadNode | Where-Object { $_.Nazwa -eq 'plik.txt' }).Count) 'Plik niewidoczny na liście plików folderu'
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'wersje pliku: raport i usunięcie najstarszych' -Run {
        foreach ($n in 2, 3) {
            Set-Content -LiteralPath (Join-Path $local 'plik.txt') -Value "Autotest Helpdesk Tools $n" -Encoding utf8
            Add-PnPFile -Path (Join-Path $local 'plik.txt') -Folder (ConvertTo-HTSPSiteRelativeUrl -ServerRelativeUrl $uploadNode.ServerRelativeUrl) -ErrorAction Stop | Out-Null
        }
        $usage = @(Get-HTFileVersionUsage -ListTitle $lib.ListId -FolderServerRelativeUrl $uploadNode.ServerRelativeUrl -Keep 1 | Where-Object { $_.Plik -eq 'plik.txt' })
        Assert-HTSelfTest $usage.Count 'Raport wersji nie pokazuje pliku z kilkoma wersjami'
        Remove-HTOldFileVersions -FileServerRelativeUrl $fileUrl -Keep 0 | Out-Null
        Assert-HTSelfTest (-not @(Get-PnPFileVersion -Url $fileUrl -ErrorAction Stop).Count) 'Starsze wersje nie zostały usunięte'
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'wyewidencjonowanie: zaewidencjonuj i odrzuć' -Run {
        $checkedOut = { @(Get-HTSPCheckedOutFiles -Node $uploadNode | Where-Object { $_.Plik -eq 'plik.txt' -and $_.__kind -eq 'CheckedOut' }).Count }
        Set-PnPFileCheckedOut -Url $fileUrl -ErrorAction Stop
        Wait-HTSelfTestCondition -Context $ctx -Message 'Wyewidencjonowany plik niewidoczny' -Condition $checkedOut | Out-Null
        Submit-HTSPFileCheckIn -Url $fileUrl -Comment 'Autotest Helpdesk Tools'
        Assert-HTSelfTest (-not (& $checkedOut)) 'Plik nadal wyewidencjonowany po zaewidencjonowaniu'
        Set-PnPFileCheckedOut -Url $fileUrl -ErrorAction Stop
        Undo-HTSPFileCheckOut -Url $fileUrl
        Assert-HTSelfTest (-not (& $checkedOut)) 'Plik nadal wyewidencjonowany po odrzuceniu'
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'kopiowanie i przenoszenie pliku' -Run {
        $copyTarget = "$($lib.ServerRelativeUrl)/Kadry/Umowy"
        $moveTarget = "$($lib.ServerRelativeUrl)/Projekty/Archiwum"
        Copy-HTSPItem -SourceUrl $fileUrl -TargetFolderUrl $copyTarget
        Wait-HTSelfTestCondition -Context $ctx -Message 'Kopia pliku niewidoczna' -Condition { & $fileExists "$copyTarget/plik.txt" } | Out-Null
        Copy-HTSPItem -SourceUrl "$copyTarget/plik.txt" -TargetFolderUrl $moveTarget -Move
        Wait-HTSelfTestCondition -Context $ctx -Message 'Plik nie został przeniesiony' -Condition { (& $fileExists "$moveTarget/plik.txt") -and -not (& $fileExists "$copyTarget/plik.txt") } | Out-Null
        Assert-HTSelfTest (& $fileExists $fileUrl) 'Plik źródłowy zniknął po kopiowaniu'
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'uprawnienia folderu: dziedziczenie, nadanie, zmiana poziomu, odebranie' -Run {
        $roles = Get-HTSelfTestSPRoles -Context $ctx
        $group = "$stampPrefix-Uprawnienia"
        New-HTSPGroup -Title $group -Description 'Autotest Helpdesk Tools - do usunięcia' | Out-Null
        Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie grupy $group" -Action { Remove-HTSPGroup -Group $group }.GetNewClosure()
        $node = & $folderNode 'Projekty/2026'
        $assignment = { @(Get-HTSPPermissions -Node $node | Where-Object { $_.Principal -eq $group })[0] }
        Set-HTSPInheritance -Node $node -Inherit $false -CopyExisting $true
        Grant-HTSPPermission -Node $node -Principal $group -PrincipalType SharePointGroup -Role $roles.Read
        $a = Wait-HTSelfTestCondition -Context $ctx -Message 'Nadane uprawnienie niewidoczne' -Condition $assignment
        Assert-HTSelfTest $a.Unique 'Folder nie ma unikalnych uprawnień'
        Set-HTSPPermissionLevel -Node $node -Assignment $a -Role $roles.Edit
        Wait-HTSelfTestCondition -Context $ctx -Message 'Poziom uprawnień nie zmienił się' -Condition { [string](& $assignment).Roles -eq $roles.Edit } | Out-Null
        Remove-HTSPPrincipalAccess -Node $node -Principal $group | Out-Null
        Assert-HTSelfTest (-not (& $assignment)) 'Uprawnienie nie zostało odebrane'
        Set-HTSPInheritance -Node $node -Inherit $true
        Assert-HTSelfTest (-not @(Get-HTSPPermissions -Node $node | Where-Object { $_.Unique }).Count) 'Folder nadal ma unikalne uprawnienia'
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'folder: do kosza, przywrócenie, usunięcie z kosza' -Run {
        $binName = "$stampPrefix-Kosz"
        $inBin = { @(Get-HTSPRecycleBinItems -Days 1 | Where-Object { $_.Nazwa -eq $binName -and $_.Etap -like '*(1)' })[0] }
        $f = New-HTSPFolder -ParentNode $lib -Name $binName
        Remove-HTSPFolder -Node $f
        $item = Wait-HTSelfTestCondition -Context $ctx -Message 'Folder niewidoczny w koszu witryny' -Condition $inBin
        Restore-HTSPRecycleBinItem -Id $item.Id
        Wait-HTSelfTestCondition -Context $ctx -Message 'Folder nie został przywrócony' -Condition { & $exists $f.ServerRelativeUrl } | Out-Null
        Remove-HTSPFolder -Node $f
        $item = Wait-HTSelfTestCondition -Context $ctx -Message 'Folder niewidoczny w koszu po ponownym usunięciu' -Condition $inBin
        Clear-HTSPRecycleBinItem -Id $item.Id
        Assert-HTSelfTest (-not (& $inBin)) 'Folder nadal w koszu witryny'
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'usunięcie biblioteki do kosza' -Run {
        Remove-HTSPLibrary -Node $lib
        $state.Removed = $true
        Assert-HTSelfTest (-not @(Get-HTSPLibraries | Where-Object { $_.ListId -eq $lib.ListId }).Count) 'Biblioteka nadal widoczna'
    }
    return Complete-HTSelfTestSteps -Context $ctx -Subject "$($lib.ServerRelativeUrl) (połączona witryna)" -Footer 'biblioteka, grupa i pliki lokalne usuwane po teście (także z kosza witryny)'
}

Register-HTSelfTest -Key 'local.sptemplates' -Name 'Szablony struktur folderów: zapis, odczyt, usunięcie' -Service 'Lokalnie' -Mode 'Write' -Area 'SharePoint' -Modules @('sp.templates') -Test {
    param($ctx)
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'Szablon'
    Save-HTSPStructureTemplate -Name $name -Text "Projekty`n    2026"
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie szablonu $name" -Action { Remove-HTSPStructureTemplate -Name $name }.GetNewClosure()
    $t = @(Get-HTSPStructureTemplates | Where-Object { $_.Name -eq $name })[0]
    Assert-HTSelfTest ($t -and $t.Text -match '2026') 'Zapisany szablon niewidoczny'
    Remove-HTSPStructureTemplate -Name $name
    Assert-HTSelfTest (-not @(Get-HTSPStructureTemplates | Where-Object { $_.Name -eq $name }).Count) 'Szablon nie został usunięty'
    return "$name - zapisany w ustawieniach programu i usunięty"
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

#region Testy zapisu: zadania, checklisty, profile tenantów (ten komputer) i zadania zaplanowane w Microsoft 365
Register-HTSelfTest -Key 'local.w.automation' -Name 'Checklisty, zadania zaplanowane i profile tenantów: utwórz, zmień, usuń' -Service 'Lokalnie' -Mode 'Write' -Area 'Zadania' `
    -Modules @('tasks.checklists', 'tasks.jobs', 'tasks.offboard', 'dash.tenants') -Test {
    param($ctx)
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'Zadania'
    Invoke-HTSelfTestStep -Context $ctx -Step 'checklista: utworzenie, kroki, ukończenie, usunięcie' -Run {
        $template = @(Get-HTChecklistTemplates)[0]
        if (-not $template) { throw 'Brak szablonów checklist' }
        $c = New-HTChecklist -Template $template -Subject $name
        $id = [string]$c.Id
        Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie checklisty $name" -Action { Remove-HTChecklist -Id $id }.GetNewClosure()
        $count = @($c.Steps).Count
        Assert-HTSelfTest $count 'Checklista bez kroków'
        $completed = $false
        for ($i = 0; $i -lt $count; $i++) { $completed = Set-HTChecklistStep -Id $id -Index $i -Done $true -Note 'Autotest' }
        Assert-HTSelfTest $completed 'Po wykonaniu wszystkich kroków checklista nie jest ukończona'
        Assert-HTSelfTest (-not @(Get-HTChecklists -Open | Where-Object { $_.Id -eq $id }).Count) 'Ukończona checklista nadal na liście otwartych'
        Remove-HTChecklist -Id $id
        Assert-HTSelfTest (-not @(Get-HTChecklists | Where-Object { $_.Id -eq $id }).Count) 'Checklista nie została usunięta'
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'zadania zaplanowane: utworzenie, anulowanie, usunięcie' -Run {
        foreach ($type in 'RemoveGroupMember', 'Offboarding') {
            $job = New-HTScheduledJob -Type $type -RunAt (Get-Date).AddYears(1) -Object $name -Description 'Autotest Helpdesk Tools - do usunięcia' -Data @{ GroupId = '00000000-0000-0000-0000-000000000000'; UserId = '00000000-0000-0000-0000-000000000000' }
            $id = [string]$job.Id
            Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie zadania $type" -Action { Remove-HTJob -Id $id }.GetNewClosure()
            Assert-HTSelfTest (@(Get-HTJobs -Pending | Where-Object { $_.Id -eq $id }).Count) "Zadanie $type nie czeka na wykonanie"
            Update-HTJob -Id $id -Changes @{ Status = 'Anulowane'; Result = 'Anulowano (autotest)' }
            Assert-HTSelfTest (-not @(Get-HTJobs -Pending | Where-Object { $_.Id -eq $id }).Count) "Anulowane zadanie $type nadal oczekuje"
            Remove-HTJob -Id $id
        }
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'profile tenantów: import z CSV, zapis, usunięcie' -Run {
        $csv = Join-Path ([System.IO.Path]::GetTempPath()) "$name.csv"
        Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie pliku $csv" -Action { if (Test-Path -LiteralPath $csv) { Remove-Item -LiteralPath $csv -Force } }.GetNewClosure()
        $header = @((Get-HTTenantProfilesCsvTemplate) -split "`r?`n")[0]
        Set-Content -LiteralPath $csv -Value @($header, "$name;ht-autotest.onmicrosoft.com;;;Nie;;;Microsoft 365;Autotest Helpdesk Tools") -Encoding utf8
        $import = Import-HTTenantProfilesCsv -Path $csv
        Assert-HTSelfTest (@($import.Profiles).Count -eq 1 -and -not @($import.Errors).Count) "Import: profili $(@($import.Profiles).Count), błędy: $(@($import.Errors) -join '; ')"
        Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie profilu $name" -Action { Set-HTTenantProfiles -Profiles @(Get-HTTenantProfiles | Where-Object { $_.Name -ne $name }) }.GetNewClosure()
        Save-HTTenantProfile -TenantProfile @($import.Profiles)[0] | Out-Null
        Assert-HTSelfTest (@(Get-HTTenantProfiles | Where-Object { $_.Name -eq $name }).Count) 'Zapisany profil niewidoczny'
        Set-HTTenantProfiles -Profiles @(Get-HTTenantProfiles | Where-Object { $_.Name -ne $name })
        Assert-HTSelfTest (-not @(Get-HTTenantProfiles | Where-Object { $_.Name -eq $name }).Count) 'Profil nie został usunięty'
    }
    return Complete-HTSelfTestSteps -Context $ctx -Subject $name -Footer 'obiekty w ustawieniach programu usuwane po teście'
}

Register-HTSelfTest -Key 'graph.w.tasks' -Name 'Członkostwo tymczasowe: dodanie, zadanie usunięcia «Wykonaj teraz», cofnięcie zmiany' -Service 'Graph' -Mode 'Write' -Area 'Zadania' -Modules @('tasks.temp', 'tasks.jobs', 'tasks.undo') -Test {
    param($ctx)
    $me = Get-HTSelfTestMe -Context $ctx
    $name = Get-HTSelfTestName -Context $ctx -Suffix 'Tymczasowa'
    $group = New-HTM365Group -DisplayName $name -Type Security -Description 'Autotest Helpdesk Tools - do usunięcia'
    Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie grupy $name" -Action { Remove-HTM365Group -Id $group.Id }.GetNewClosure()
    $isMember = { @(Invoke-HTGraphRequest -Uri "groups/$($group.Id)/members?`$select=id" -All | Where-Object { $_.id -eq $me.Id }).Count }
    Wait-HTSelfTestCondition -Context $ctx -Message 'Nowa grupa niewidoczna' -Condition { Invoke-HTGraphRequest -Uri "groups/$($group.Id)?`$select=id" } | Out-Null
    Invoke-HTSelfTestStep -Context $ctx -Step 'członkostwo tymczasowe i zadanie usunięcia wykonane od razu' -Run {
        Add-HTM365GroupMember -GroupId $group.Id -MemberId $me.Id
        Wait-HTSelfTestCondition -Context $ctx -Message 'Członek niewidoczny' -Condition $isMember | Out-Null
        $job = New-HTScheduledJob -Type 'RemoveGroupMember' -RunAt (Get-Date).AddHours(1) -Object $name -Description 'Autotest Helpdesk Tools' -Data @{ GroupId = $group.Id; GroupName = $name; UserId = $me.Id; UserLabel = $me.UserPrincipalName }
        $jobId = [string]$job.Id
        Add-HTSelfTestCleanup -Context $ctx -Name "Usunięcie zadania $name" -Action { Remove-HTJob -Id $jobId }.GetNewClosure()
        # Jak «Wykonaj teraz», ale bez powiadomienia w Teams o wykonanym zadaniu
        $stored = @(Get-HTJobs | Where-Object { $_.Id -eq $jobId })[0]
        $result = Invoke-HTJob -Job $stored
        Update-HTJob -Id $jobId -Changes @{ Status = 'Wykonane'; Executed = (Get-Date).ToString('o'); Result = [string]$result }
        Assert-HTSelfTest ([string]@(Get-HTJobs | Where-Object { $_.Id -eq $jobId })[0].Status -eq 'Wykonane') 'Zadanie nie ma stanu «Wykonane»'
        Wait-HTSelfTestCondition -Context $ctx -Message 'Zadanie nie usunęło członka' -Condition { -not (& $isMember) } | Out-Null
    }
    Invoke-HTSelfTestStep -Context $ctx -Step 'cofnięcie zmiany z rejestru (ponowne dodanie do grupy)' -Run {
        Register-HTUndo -Operation 'Autotest: usunięcie z grupy' -Object $name -Kind 'GroupMember' -Data @{ GroupId = $group.Id; UserId = $me.Id; Added = $false }
        $rec = @(Get-HTUndoRecords | Where-Object { $_.Object -eq $name -and -not $_.Undone })[0]
        Assert-HTSelfTest $rec 'Wpis cofania zmian niewidoczny'
        Invoke-HTUndo -Id $rec.Id | Out-Null
        Wait-HTSelfTestCondition -Context $ctx -Message 'Cofnięcie nie dodało członka' -Condition $isMember | Out-Null
        Assert-HTSelfTest (@(Get-HTUndoRecords | Where-Object { $_.Id -eq $rec.Id })[0].Undone) 'Wpis nie jest oznaczony jako cofnięty'
    }
    return Complete-HTSelfTestSteps -Context $ctx -Subject "$name (członek: $($me.UserPrincipalName))" -Footer 'grupa usuwana po teście'
}
#endregion

#region Moduły, których zmian nie da się bezpiecznie sprawdzić na obiektach testowych
Register-HTSelfTestExemption -Modules @('int.primary', 'int.rename', 'int.actions', 'int.wipe', 'int.updates', 'int.remediation', 'int.duplicates') -Reason 'Działa na prawdziwym urządzeniu zarządzanym w Intune (zmiana nazwy, akcje zdalne, wycofanie, czyszczenie) - urządzenia nie da się utworzyć testowo.'
Register-HTSelfTestExemption -Modules @('int.staleentra') -Reason 'Wyłącza albo usuwa prawdziwe urządzenia z Entra ID - urządzenia testowego nie da się zarejestrować bez komputera.'
Register-HTSelfTestExemption -Modules @('int.autopilot') -Reason 'Import wymaga skrótu sprzętowego prawdziwego komputera; zmiany dotyczą zarejestrowanych urządzeń.'
Register-HTSelfTestExemption -Modules @('sec.risky') -Reason 'Wymaga konta oznaczonego przez Entra ID Protection jako ryzykowne - nie da się go wywołać testowo.'
Register-HTSelfTestExemption -Modules @('sec.alerts', 'sec.incidents') -Reason 'Wymaga alertu albo incydentu Microsoft Defender; izolacja z alertu odcina prawdziwe urządzenie.'
Register-HTSelfTestExemption -Modules @('sec.isolate') -Reason 'Izolacja odcina prawdziwe urządzenie od sieci (Microsoft Defender for Endpoint).'
Register-HTSelfTestExemption -Modules @('sec.consents', 'm365.consents') -Reason 'Cofnięcie działa na zgodach nadanych przez użytkowników aplikacjom - zgody testowej nie da się nadać bez logowania do aplikacji.'
Register-HTSelfTestExemption -Modules @('sec.creds') -Reason 'Usuwa sekrety prawdziwych aplikacji; test wymagałby rejestracji aplikacji z uprawnieniami w tenancie.'
Register-HTSelfTestExemption -Modules @('m365.onedrive') -Reason 'Wymaga OneDrive odchodzącego pracownika (konto z licencją i założonym OneDrive).'
Register-HTSelfTestExemption -Modules @('org.domains') -Reason 'Weryfikacja wymaga własnej domeny z rekordem TXT u rejestratora.'
Register-HTSelfTestExemption -Modules @('org.selftest') -Reason 'Narzędzie autotestu - «Usuń pozostałości» usuwa wyłącznie obiekty HT-Autotest-* (sprawdzane testami jednostkowymi).'
Register-HTSelfTestExemption -Modules @('sp.app') -Reason 'Rejestruje aplikację w Entra ID ze zgodą administratora w przeglądarce - zostawiałaby trwałą rejestrację.'
Register-HTSelfTestExemption -Modules @('tasks.reports') -Reason 'Tworzy aplikację automatyzacji z certyfikatem w Entra ID i zadanie w Harmonogramie Windows - trwałe obiekty poza programem.'
Register-HTSelfTestExemption -Modules @('sites.subsites') -Reason 'Dodaje witryny tylko do listy po lewej w programie - bez zmian w Microsoft 365.'
Register-HTSelfTestExemption -Modules @('sites.sharing') -Reason 'Usuwa prawdziwe linki udostępniania plików - test wymagałby udostępnienia pliku osobie spoza testu.'
#endregion

#region Testy: Active Directory
Register-HTSelfTest -Key 'ad.domain' -Name 'Domena Active Directory' -Service 'AD' -Area 'Active Directory' -Test {
    $d = Get-ADDomain -ErrorAction Stop
    $users = @(Get-ADUser -Filter * -ResultSetSize 5 -ErrorAction Stop)
    return "Domena $($d.DNSRoot) (poziom $($d.DomainMode)), odczyt kont: $($users.Count)"
}
#endregion
