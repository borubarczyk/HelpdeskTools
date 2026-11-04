# Przestrzeń «Organizacja»: rzeczy, które nie dotyczą zaznaczonego konta ani skrzynki - tworzenie nowych obiektów
# (konta, skrzynki współdzielone i sale, grupy, kontakty), przepływ poczty, licencje i raporty organizacji.
# Moduły z innych plików są tu rejestrowane parametrem -Workspace 'Organization' (klucze bez zmian - ulubione działają).

Register-HTWorkspace -Key 'Organization' -Title 'Organizacja' -Icon 'E821' `
    -Description 'Tworzenie kont, skrzynek, grup, witryn i kontaktów, zaproszenia gości, przepływ poczty, licencje, domeny, raporty i autotest funkcji - bez wybierania obiektu z listy' `
    -Categories @('Tworzenie', 'Poczta (Exchange)', 'Licencje', 'Domeny', 'Raporty', 'Diagnostyka')

Register-HTModule -Workspace 'Organization' -Category 'Tworzenie' -Key 'org.newgroup' -Title 'Nowa grupa' -Icon 'E902' `
    -Description 'Nowa grupa dowolnego rodzaju: zabezpieczeń albo Microsoft 365 (Entra ID - uprawnienia, Teams, licencje grupowe), dystrybucyjna, dynamiczna (członkowie z atrybutów, kreator z testem) albo grupa SharePoint połączonej witryny.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Microsoft 365'
    Add-HTButton -Parent $row -Module $m -Text 'Zabezpieczeń / Microsoft 365…' -Icon 'E902' -Create -NoRowMenu -ToolTip 'Grupa Entra ID: zabezpieczeń (uprawnienia, aplikacje, licencje grupowe) albo Microsoft 365 (poczta, kalendarz, Teams, witryna)' -OnClick {
        param($m)
        $g = New-HTM365GroupInteractive
        if ($g) {
            Add-HTResultRows -Module $m -Objects @([PSCustomObject]@{ Grupa = $g.DisplayName; Rodzaj = $g.Type; 'E-mail' = $g.Mail; Status = 'OK'; Szczegóły = 'Utworzono - lista: Grupy i zespoły' })
            $panel = Get-HTPanel 'm365groups'
            if ($panel -and $panel.Objects.Count) { Invoke-HTPanelLoad -Panel $panel -Quiet }
        }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Członkowie, właściciele, edycja i usuwanie grup: przestrzeń «Grupy i zespoły».' | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Exchange'
    Add-HTButton -Parent $row2 -Module $m -Text 'Dystrybucyjna…' -Icon 'E716' -Create -NoRowMenu -ToolTip 'Lista dystrybucyjna (adres e-mail grupy, członkowie, kto może pisać)' -OnClick { param($m) New-HTDistributionGroupInteractive -Module $m } | Out-Null
    Add-HTButton -Parent $row2 -Module $m -Text 'Dynamiczna…' -Icon 'E71C' -Create -NoRowMenu -ToolTip 'Członkowie wyliczani z atrybutów (np. wszyscy z działu Sprzedaż) - kreator reguł z testem' -OnClick { param($m) New-HTDynamicGroupInteractive -Module $m } | Out-Null
    $row3 = Add-HTToolbarRow -Module $m -Title 'SharePoint'
    Add-HTButton -Parent $row3 -Module $m -Text 'Grupa SharePoint witryny…' -Icon 'E8F1' -Create -NoRowMenu -ToolTip 'Grupa w połączonej witrynie SharePoint (np. do uprawnień folderów)' -OnClick {
        param($m)
        $title = New-HTSPGroupInteractive
        if ($title) { Add-HTResultRows -Module $m -Objects @([PSCustomObject]@{ Grupa = $title; Rodzaj = 'SharePoint'; 'E-mail' = ''; Status = 'OK'; Szczegóły = 'Utworzono w połączonej witrynie' }) }
    } | Out-Null
}

#region Zaproszenie gościa (B2B)
function Select-HTGuestGroups {
    # Wybór grup Microsoft 365 / zabezpieczeń dla gości (bez dynamicznych, z AD i pocztowych - te przez Exchange)
    param([Parameter(Mandatory)]$Window)
    $groups = @(Get-HTPanelObjects -Key 'm365groups' | Where-Object { $_.Type -in 'Microsoft 365', 'Zabezpieczeń' -and (Test-HTM365GroupManageable -Group $_) })
    $columns = @(@{ Text = 'Nazwa'; Property = 'DisplayName' }, @{ Text = 'Typ'; Property = 'Type' }, @{ Text = 'E-mail'; Property = 'Mail' }, @{ Text = 'Zespół Teams'; Property = 'IsTeam' })
    $selected = @(Show-HTSelectionDialog -Title 'Grupy dla gości' -Prompt 'Grupy Microsoft 365 (np. zespoły Teams) i zabezpieczeń (np. uprawnienia SharePoint), do których trafią goście.' -Items ($groups | Sort-Object DisplayName) -Columns $columns -MultiSelect -Icon 'E902')
    if (-not @($selected | Where-Object { $_ }).Count) { return }
    $box = $Window.Tag.Controls['Groups'].Control
    $box.Text = (@(Split-HTInputList $box.Text) + @($selected | Where-Object { $_ } | ForEach-Object { [string]$_.DisplayName }) | Select-Object -Unique) -join "`r`n"
}

function Invoke-HTGuestInviteInteractive {
    <#
        Zaproszenie gości: lista adresów (z nazwami), e-mail z zaproszeniem albo sam link do przekazania, wiadomość, kopia,
        strona po przyjęciu i grupy (Microsoft 365 / zabezpieczeń), do których goście trafią od razu po zaproszeniu.
    #>
    param([Parameter(Mandatory)][hashtable]$Module)
    if (-not (Assert-HTConnection -Service 'Graph')) { return }
    $prev = @{}
    $get = { param($k, $d) if ($prev.Contains($k)) { $prev[$k] } else { $d } }
    while ($true) {
        $form = Show-HTFormDialog -Title 'Zaproszenie gości (B2B)' -Icon 'E8FA' -OkText 'Dalej' -Width 680 -MaxHeight 700 `
            -Description 'Goście dostają konto w tenancie (do Teams, SharePoint, aplikacji) i logują się własnym kontem służbowym, Microsoft albo kodem z e-maila.' -Fields @(
            @{ Name = 'List'; Label = 'Goście - jeden w linii: adres albo «adres; Imię Nazwisko»'; Type = 'Multiline'; Height = 110; Required = $true; Default = (& $get 'List' '') }
            @{ Name = 'Send'; Label = 'Wyślij e-mail z zaproszeniem (bez tego - link do przyjęcia w wynikach, do przekazania samemu)'; Type = 'Check'; Default = (& $get 'Send' $true) }
            @{ Name = 'Message'; Label = 'Wiadomość w zaproszeniu (opcjonalnie)'; Type = 'Multiline'; Height = 60; Default = (& $get 'Message' '') }
            @{ Name = 'Cc'; Label = 'Kopia zaproszenia do (jeden adres, opcjonalnie)'; Default = (& $get 'Cc' '') }
            @{ Name = 'Redirect'; Label = 'Strona po przyjęciu zaproszenia'; Default = (& $get 'Redirect' 'https://myapps.microsoft.com'); Hint = 'Np. adres witryny SharePoint albo https://teams.microsoft.com' }
            @{ Name = 'Groups'; Label = 'Dodaj do grup (nazwy, jedna w linii; opcjonalnie)'; Type = 'Multiline'; Height = 50; Default = (& $get 'Groups' '') }
            @{ Type = 'Buttons'; Buttons = @(@{ Text = 'Wybierz grupy…'; Icon = 'E902'; OnClick = { param($w) Select-HTGuestGroups -Window $w } }) }
        )
        if (-not $form) { return }
        $prev = $form
        $guests = @(ConvertFrom-HTGuestInviteList ([string]$form.List))
        $bad = @($guests | Where-Object { $_.Problem })
        $cc = ([string]$form.Cc).Trim()
        $redirect = ([string]$form.Redirect).Trim()
        $groupNames = @(Split-HTInputList ([string]$form.Groups))
        $problems = @($bad | ForEach-Object { "$($_.Line) - $($_.Problem)" })
        if (-not $guests.Count) { $problems += 'Podaj co najmniej jeden adres.' }
        if ($cc -and -not (Test-HTEmailAddress $cc)) { $problems += "Kopia do: niepoprawny adres «$cc»." }
        if ($redirect -and $redirect -notmatch '^https?://') { $problems += 'Strona po przyjęciu musi zaczynać się od https://.' }
        $groups = @()
        if (-not $problems.Count -and $groupNames.Count) {
            $all = @(Get-HTPanelObjects -Key 'm365groups')
            foreach ($n in $groupNames) {
                $g = @($all | Where-Object { $_.DisplayName -ieq $n -or ($_.Mail -and $_.Mail -ieq $n) })
                if ($g.Count -ne 1) { $problems += "Grupa «$n»: $(if ($g.Count) { 'kilka grup o tej nazwie - wybierz przyciskiem' } else { 'nie znaleziono' })." }
                elseif ($g[0].Type -notin 'Microsoft 365', 'Zabezpieczeń' -or -not (Test-HTM365GroupManageable -Group $g[0])) { $problems += "Grupa «$n»: gości można tu dodać tylko do grup Microsoft 365 i zabezpieczeń (bez dynamicznych i z AD)." }
                else { $groups += $g[0] }
            }
        }
        if (-not $problems.Count) { break }
        Show-HTWarning ("Popraw formularz:`n`n" + ($problems -join "`n")) -Title 'Zaproszenie gości'
    }
    $send = [bool]$form.Send
    $summary = @(
        "E-mail z zaproszeniem: $(if ($send) { 'tak' } else { 'nie - link do przyjęcia w kolumnie «Link zaproszenia»' })"
        $(if ($cc) { "Kopia do: $cc" })
        "Strona po przyjęciu: $(if ($redirect) { $redirect } else { 'https://myapps.microsoft.com' })"
        $(if ($groups.Count) { "Grupy: $(@($groups | ForEach-Object { $_.DisplayName }) -join ', ')" })
    ) | Where-Object { $_ }
    $message = [string]$form.Message
    Invoke-HTTargetAction -Module $Module -Name 'Zaproszenie gościa' -Service 'Graph' -Targets $guests -Label { param($t) if ($t.DisplayName) { "$($t.DisplayName) <$($t.Email)>" } else { $t.Email } } -Summary $summary -Action {
        param($t)
        $inv = New-HTM365GuestInvitation -Email $t.Email -DisplayName $t.DisplayName -SendInvitation $send -Message $message -CcRecipients @($cc) -RedirectUrl $redirect
        $added = @(); $errors = @()
        foreach ($g in $groups) {
            # Świeże konto gościa może jeszcze nie być widoczne dla grup (replikacja) - kilka prób
            for ($try = 1; ; $try++) {
                try { Add-HTM365GroupMember -GroupId $g.Id -MemberId $inv.UserId; $added += $g.DisplayName; break }
                catch {
                    $text = "$($_.Exception.Message)"
                    if ($text -match 'already exist') { $added += $g.DisplayName; break }
                    if ($try -lt 4 -and $text -match 'does not exist|not found|NotFound') { Start-Sleep -Seconds 5; continue }
                    $errors += "$($g.DisplayName): $text"; break
                }
            }
        }
        [ordered]@{
            Status              = $(if ($errors) { 'Błąd (częściowo)' } else { 'OK' })
            Nazwa               = $(if ($inv.DisplayName) { $inv.DisplayName } else { $t.DisplayName })
            'E-mail'            = $inv.Email
            'Stan zaproszenia'  = $inv.Status
            'Link zaproszenia'  = $inv.RedeemUrl
            Grupy               = ($added -join ', ')
            Szczegóły           = $(if ($errors) { $errors -join '; ' } elseif ($send) { 'Wysłano e-mail z zaproszeniem' } else { 'Bez e-maila - przekaż link zaproszenia' })
            Id                  = $inv.UserId
        }
    }
}

Register-HTModule -Workspace 'Organization' -Category 'Tworzenie' -Key 'org.guest' -Title 'Zaproszenie gościa' -Icon 'E8FA' -Service 'Graph' `
    -Description 'Zaproszenie osób spoza firmy (B2B): konto gościa do Teams, SharePoint i aplikacji, e-mail z zaproszeniem albo link do przekazania samemu, od razu dodanie do grup. Lista gości ze stanem zaproszenia; prawy przycisk - ponowne zaproszenie, kopiowanie linku, usunięcie konta.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż gości' -Icon 'E8D4' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Konta gości' -ScriptBlock { Get-HTM365GuestUsers } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Zaproś gości…' -Icon 'E8FA' -Create -NoRowMenu -ToolTip 'Zaproszenie jednej albo wielu osób (lista adresów), opcjonalnie od razu do grup Microsoft 365 / zespołów Teams' -OnClick { param($m) Invoke-HTGuestInviteInteractive -Module $m } | Out-Null
    Add-HTRowAction -Module $m -Text 'Kopiuj link zaproszenia' -Icon 'E8C8' -Action {
        param($m, $rows)
        $links = @($rows | ForEach-Object { $_.'Link zaproszenia' } | Where-Object { $_ })
        if (-not $links.Count) { Show-HTWarning 'Zaznaczone wiersze nie mają linku zaproszenia (link jest w wynikach zaproszenia; dla istniejących gości - «Wyślij zaproszenie ponownie» bez e-maila).' -Title 'Link zaproszenia'; return }
        Set-HTClipboard ($links -join "`r`n")
        Show-HTToast "Skopiowano linków: $($links.Count)." 'ok'
    }
    Add-HTRowAction -Module $m -Text 'Wyślij zaproszenie ponownie' -Icon 'E715' -Create -Action {
        param($m, $rows)
        $rows = @($rows | Where-Object { $_.'E-mail' })
        if (-not $rows.Count) { Show-HTWarning 'Zaznacz gości z adresem e-mail.' -Title 'Ponowne zaproszenie'; return }
        $form = Show-HTFormDialog -Title 'Ponowne zaproszenie' -Icon 'E715' -OkText 'Dalej' -Width 560 -Fields @(
            @{ Name = 'Send'; Label = 'Wyślij e-mail z zaproszeniem (bez tego - nowy link w wynikach)'; Type = 'Check'; Default = $true }
            @{ Name = 'Message'; Label = 'Wiadomość (opcjonalnie)'; Type = 'Multiline'; Height = 60 }
        )
        if (-not $form) { return }
        $send = [bool]$form.Send
        $message = [string]$form.Message
        Invoke-HTRowAction -Module $m -Name 'Ponowne zaproszenie gościa' -Rows $rows -Label { param($r) $r.'E-mail' } -Action {
            param($r)
            $inv = New-HTM365GuestInvitation -Email $r.'E-mail' -SendInvitation $send -Message $message
            "Stan: $($inv.Status)$(if (-not $send) { "; link: $($inv.RedeemUrl)" })"
        }
    }
    Add-HTRowAction -Module $m -Text 'Usuń konto gościa' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $rows = @($rows | Where-Object { $_.Id })
        if (-not $rows.Count) { return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie konta gościa' -Rows $rows -Danger -Confirm 'Usunąć zaznaczone konta gości? Stracą dostęp do zespołów, witryn i aplikacji (konto można przywrócić przez 30 dni - Microsoft 365 > Usunięte konta).' -Label { param($r) "$($r.Nazwa) <$($r.'E-mail')>" } `
            -Action { param($r) Remove-HTM365User -Id $r.Id; 'Usunięto (do przywrócenia przez 30 dni)' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Domeny
function Show-HTDomainDnsRecords {
    # Rekordy DNS domen (weryfikacja dla niezweryfikowanych, usługi dla pozostałych), opcjonalnie z porównaniem z publicznym DNS
    param([Parameter(Mandatory)][hashtable]$Module, [AllowEmptyCollection()][object[]]$Rows = @())
    $domains = @($Rows | Where-Object { $_.Domena -and $null -ne $_.Zweryfikowana } | ForEach-Object { [PSCustomObject]@{ Domena = [string]$_.Domena; Zweryfikowana = [bool]$_.Zweryfikowana } })
    if (-not $domains.Count) { Show-HTWarning 'Najpierw «Pokaż domeny» i zaznacz domeny na liście.' -Title 'Rekordy DNS'; return }
    $check = Test-HTChecked $Module.C.CheckDns
    Invoke-HTQuery -Module $Module -Name 'Rekordy DNS domen' -Object (@($domains | ForEach-Object { $_.Domena }) -join ', ') -ScriptBlock {
        foreach ($d in $domains) {
            foreach ($r in @(Get-HTM365DomainDnsRecords -Domain $d.Domena -Verification:(-not $d.Zweryfikowana))) {
                if ($check) {
                    $state = Test-HTDomainDnsRecord -Row $r
                    $r | Add-Member -NotePropertyName 'Stan' -NotePropertyValue $state.Stan
                    $r | Add-Member -NotePropertyName 'W DNS' -NotePropertyValue $state.'W DNS'
                    if ($state.Stan -in 'Brak', 'Inna wartość') { $r.__flag = $(if ($r.Opcjonalny) { 'warn' } else { 'crit' }) }
                }
                $r
            }
        }
    }
}

Register-HTModule -Workspace 'Organization' -Category 'Domeny' -Key 'org.domains' -Title 'Domeny tenanta' -Icon 'E774' -Service 'Graph' `
    -Description 'Domeny tenanta: weryfikacja, domyślna, usługi (poczta, Teams, Intune), uwierzytelnianie. Rekordy DNS, które trzeba ustawić u dostawcy domeny (weryfikacja albo usługi), ze sprawdzeniem w publicznym DNS. Prawy przycisk - weryfikacja domeny.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż domeny' -Icon 'E774' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Domeny tenanta' -ScriptBlock { Get-HTM365DomainDetails } } | Out-Null
    $m.C.CheckDns = Add-HTCheckBox -Parent $row -Text 'Sprawdź rekordy w publicznym DNS' -Checked $true -ToolTip 'Porównanie z tym, co jest w DNS (Resolve-DnsName) - widać brakujące i błędne rekordy'
    Add-HTButton -Parent $row -Module $m -Text 'Rekordy DNS' -Icon 'E8A1' -ToolTip 'Rekordy DNS zaznaczonych domen (bez zaznaczenia - wszystkich na liście): weryfikacja albo usługi' -OnClick {
        param($m)
        $rows = @(Get-HTResultSelection -Module $m | Where-Object { $_.Domena -and $null -ne $_.Zweryfikowana })
        if (-not $rows.Count) { $rows = @(Get-HTResultSelection -Module $m -AllVisible | Where-Object { $_.Domena -and $null -ne $_.Zweryfikowana }) }
        Show-HTDomainDnsRecords -Module $m -Rows $rows
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Rekordy DNS' -Icon 'E8A1' -Action { param($m, $rows) Show-HTDomainDnsRecords -Module $m -Rows $rows }
    Add-HTRowAction -Module $m -Text 'Zweryfikuj domenę' -Icon 'E73E' -Create -Action {
        param($m, $rows)
        $rows = @($rows | Where-Object { $_.Domena -and $_.Zweryfikowana -eq $false })
        if (-not $rows.Count) { Show-HTWarning 'Zaznacz niezweryfikowane domeny (po dodaniu rekordu TXT u dostawcy domeny - «Rekordy DNS»).' -Title 'Weryfikacja domeny'; return }
        if (-not (Assert-HTGraphScopes -Scopes @('Domain.ReadWrite.All') -Feature 'Weryfikacja domeny')) { return }
        Invoke-HTRowAction -Module $m -Name 'Weryfikacja domeny' -Rows $rows -Label { param($r) $r.Domena } -Action {
            param($r)
            $d = Invoke-HTM365DomainVerify -Domain $r.Domena
            if (-not $d.Zweryfikowana) { throw 'Domena nadal niezweryfikowana - sprawdź rekord TXT (zmiany w DNS mogą trwać do kilku godzin).' }
            'Zweryfikowano'
        } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Autotest funkcji (diagnostyka na tenancie)
function Invoke-HTSelfTestSweep {
    <#
        Przegląd wszystkich sekcji: w każdym module wybranych przestrzeni przycisk odczytu na przykładowym obiekcie
        (własne konto, własna skrzynka, zespół, biblioteka «Dokumenty» - albo pierwszy na liście). Okna są przechwytywane,
        więc nic się nie zmienia. Wiersze trafiają do tabeli modułu autotestu i do -Results.
    #>
    param([Parameter(Mandatory)][hashtable]$Module, [System.Collections.Generic.List[object]]$Results, [string[]]$Workspaces = @())
    $me = ''
    try { $me = [string](Get-MgContext).Account } catch { Write-Verbose $_ }
    if (-not $me -and $Global:ConnectedToExchange) { try { $me = [string]@(Get-ConnectionInformation)[0].UserPrincipalName } catch { Write-Verbose $_ } }
    $prefs = @{
        m365users  = { param($o) $me -and [string]$o.UserPrincipalName -ieq $me }.GetNewClosure()
        mailboxes  = { param($o) $me -and ([string]$o.UserPrincipalName -ieq $me -or [string]$o.PrimarySmtpAddress -ieq $me) }.GetNewClosure()
        m365groups = { param($o) [bool]$o.IsTeam }
        spTree     = { param($o) [string]$o.ServerRelativeUrl -match '/Shared( |%20)Documents$' }
    }
    # Pomijane: sam autotest i połączenie z inną witryną (przełącza połączenie SharePoint)
    Invoke-HTModuleSweep -Workspaces $Workspaces -ExcludeKeys @('org.selftest', 'sites.connect') -Preferences $prefs -ShouldStop { Test-HTStopRequested } `
        -OnStart { param($d, $i, $n) Set-HTProgress -Value $i -Maximum $n -Text "Przegląd sekcji [$i/$n] $($d.Title)"; Update-HTUi } `
        -OnResult { param($r) if ($null -ne $Results) { $Results.Add($r) }; Add-HTResultRows -Module $Module -Objects @($r); Write-Log -Message "Przegląd sekcji: $($r.Test) - $($r.Status) $($r.Szczegóły)" -Type $(if ($r.Status -eq 'Błąd') { 'Warn' } else { 'Debug' }); Update-HTUi } | Out-Null
}

function Get-HTModuleCoverageInfo {
    # Opisy modułów do pokrycia testami: czy jest przycisk odczytu i ile przycisków zmian (moduły budowane bez pokazywania)
    foreach ($d in @(Get-HTModuleDefinitions)) {
        $m = Get-HTModuleInstance -Key $d.Key
        $changes = if ($m) { @($m.ChangeButtons).Count + @($m.RowActions | Where-Object { $_.Danger }).Count } else { 0 }
        [PSCustomObject]@{ Key = $d.Key; Workspace = (Get-HTWorkspaceTitle $d.Workspace); Category = $d.Category; Title = $d.Title; HasRead = [bool]($m -and $m.PrimaryButton); ChangeCount = $changes }
    }
}

function Get-HTSelfTestConnected {
    return @{ Graph = (Test-HTConnection -Service 'Graph'); Exchange = (Test-HTConnection -Service 'Exchange'); SharePoint = (Test-HTConnection -Service 'SharePoint'); AD = (Test-HTConnection -Service 'AD') }
}

Register-HTModule -Workspace 'Organization' -Category 'Diagnostyka' -Key 'org.selftest' -Title 'Autotest funkcji' -Icon 'E9D9' `
    -Description 'Sprawdza po kolei funkcje programu na połączonym tenancie zamiast ręcznego klikania: testy odczytu (bez zmian) oraz - po zaznaczeniu - testy zapisu na obiektach tymczasowych «HT-Autotest-…» (grupy, gość example.com, grupy pocztowe, grupa i folder SharePoint), usuwanych od razu po teście. Wynik do skopiowania albo eksportu do zgłoszenia.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.Graph = Add-HTCheckBox -Parent $row -Text 'Microsoft 365 (Graph)' -Checked $true
    $m.C.Exchange = Add-HTCheckBox -Parent $row -Text 'Exchange Online' -Checked $true
    $m.C.SharePoint = Add-HTCheckBox -Parent $row -Text 'SharePoint (połączona witryna)' -Checked $true
    $m.C.Local = Add-HTCheckBox -Parent $row -Text 'Ten komputer' -Checked $true
    $m.C.AD = Add-HTCheckBox -Parent $row -Text 'Active Directory' -Checked $false
    $row2 = Add-HTToolbarRow -Module $m
    $m.C.Write = Add-HTCheckBox -Parent $row2 -Text 'Testy zapisu na obiektach testowych (tworzone i usuwane)' -Checked $false -ToolTip 'Tworzy obiekty «HT-Autotest-…», sprawdza zmianę i od razu je usuwa (także z kosza katalogu). Wymaga uprawnień do zmian.'
    $m.C.Slow = Add-HTCheckBox -Parent $row2 -Text 'Także długie (zespół Teams - do 5 min)' -Checked $false
    $m.C.Sweep = Add-HTCheckBox -Parent $row2 -Text 'Wszystkie sekcje: przycisk odczytu w każdym module' -Checked $true -ToolTip 'Po testach - przegląd każdego modułu połączonych przestrzeni na przykładowym obiekcie (własne konto, skrzynka, zespół…). Okna są przechwytywane, nic się nie zmienia.'
    $row3 = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row3 -Module $m -Text 'Uruchom autotest' -Icon 'E768' -Primary -OnClick {
        param($m)
        $services = @()
        if (Test-HTChecked $m.C.Graph) { $services += 'Graph' }
        if (Test-HTChecked $m.C.Exchange) { $services += 'Exchange' }
        if (Test-HTChecked $m.C.SharePoint) { $services += 'SharePoint' }
        if (Test-HTChecked $m.C.Local) { $services += 'Lokalnie' }
        if (Test-HTChecked $m.C.AD) { $services += 'AD' }
        $write = Test-HTChecked $m.C.Write
        $tests = @(Get-HTSelfTests -Service $services -IncludeWrite:$write -IncludeSlow:(Test-HTChecked $m.C.Slow))
        if (-not $tests.Count) { Show-HTWarning 'Zaznacz co najmniej jeden zakres testów.' -Title 'Autotest'; return }
        $connected = Get-HTSelfTestConnected
        $notConnected = @($services | Where-Object { $_ -ne 'Lokalnie' -and -not $connected[$_] } | ForEach-Object { Get-HTSelfTestServiceName $_ })
        if ($write) {
            $writeTests = @($tests | Where-Object { $_.Mode -eq 'Write' -and ($_.Service -eq 'Lokalnie' -or $connected[$_.Service]) })
            if ($writeTests.Count) {
                if (-not (Assert-HTWriteAllowed -Operation 'Autotest - testy zapisu')) { return }
                $labels = @($writeTests | ForEach-Object { "$($_.Name) ($(Get-HTSelfTestServiceName $_.Service))" })
                if (-not (Confirm-HTChange -Name 'Autotest - testy zapisu' -Labels $labels -Summary @("Obiekty tymczasowe: $(Get-HTSelfTestPrefix)<data>-… - tworzone, sprawdzane i usuwane w tym samym teście", 'Pozostałości po przerwanym teście: przycisk «Pozostałości po testach»') -Confirm "Uruchomić testy zapisu ($($writeTests.Count))? Program utworzy i od razu usunie obiekty testowe w tenancie.")) { return }
            }
        }
        if ($notConnected.Count) { Show-HTToast "Bez połączenia (testy pominięte): $($notConnected -join ', ')." 'warn' 6 }
        Reset-HTResults -Module $m
        Set-HTBusy -Busy $true -Text 'Autotest…'
        Start-HTStoppable
        $results = New-Object System.Collections.Generic.List[object]
        try {
            $ctx = New-HTSelfTestContext -Sleep { param($Seconds) $end = (Get-Date).AddSeconds($Seconds); while ((Get-Date) -lt $end) { Update-HTUi; Start-Sleep -Milliseconds 150 } }
            Invoke-HTSelfTest -Tests $tests -Connected $connected -Context $ctx -ShouldStop { Test-HTStopRequested } `
                -OnStart { param($t, $i, $n) Set-HTProgress -Value $i -Maximum $n -Text "Autotest [$i/$n] $($t.Name)"; Update-HTUi } `
                -OnResult { param($r) $results.Add($r); Add-HTResultRows -Module $m -Objects @($r); Write-Log -Message "Autotest: $($r.Test) - $($r.Status) $($r.Szczegóły)" -Type $(if ($r.Status -eq 'Błąd') { 'Warn' } else { 'Info' }); Update-HTUi } | Out-Null
        }
        finally {
            Stop-HTStoppable
            Set-HTBusy -Busy $false -Text "Autotest: $(Get-HTSelfTestSummary -Rows $results.ToArray())"
        }
        if ((Test-HTChecked $m.C.Sweep) -and -not (Test-HTStopRequested)) {
            $workspaces = @(Get-HTModuleDefinitions | ForEach-Object { $_.Workspace } | Select-Object -Unique)
            Set-HTBusy -Busy $true -Text 'Przegląd wszystkich sekcji…'
            Start-HTStoppable
            try { Invoke-HTSelfTestSweep -Module $m -Results $results -Workspaces $workspaces }
            finally { Stop-HTStoppable; Set-HTBusy -Busy $false -Text "Autotest: $(Get-HTSelfTestSummary -Rows $results.ToArray())" }
        }
        $summary = Get-HTSelfTestSummary -Rows $results.ToArray()
        Add-HTCheckRecord -Module $m -Name 'Autotest funkcji' -Object (@($services | ForEach-Object { Get-HTSelfTestServiceName $_ }) -join ', ') -Details $summary
        $failed = @($results | Where-Object { $_.Status -eq 'Błąd' }).Count
        Show-HTToast "Autotest: $summary." $(if ($failed) { 'warn' } else { 'ok' }) 8
    } | Out-Null
    Add-HTButton -Parent $row3 -Module $m -Text 'Przegląd wybranych sekcji…' -Icon 'E8A9' -ToolTip 'Przycisk odczytu w każdym module wybranych przestrzeni (bez testów funkcji) - okna przechwytywane, bez zmian' -OnClick {
        param($m)
        $items = @(Get-HTModuleDefinitions | Group-Object Workspace | ForEach-Object { [PSCustomObject]@{ Przestrzeń = (Get-HTWorkspaceTitle $_.Name); Moduły = $_.Count; Klucz = $_.Name } })
        $picked = @(Show-HTSelectionDialog -Title 'Przegląd sekcji' -Prompt 'Przestrzenie do przeglądu - w każdym module przycisk odczytu na przykładowym obiekcie.' -Items $items -MultiSelect -Icon 'E8A9' | Where-Object { $_ })
        if (-not $picked.Count) { return }
        Reset-HTResults -Module $m
        $results = New-Object System.Collections.Generic.List[object]
        Set-HTBusy -Busy $true -Text 'Przegląd sekcji…'
        Start-HTStoppable
        try { Invoke-HTSelfTestSweep -Module $m -Results $results -Workspaces @($picked | ForEach-Object { $_.Klucz }) }
        finally { Stop-HTStoppable; Set-HTBusy -Busy $false -Text "Przegląd sekcji: $(Get-HTSelfTestSummary -Rows $results.ToArray())" }
        $summary = Get-HTSelfTestSummary -Rows $results.ToArray()
        Add-HTCheckRecord -Module $m -Name 'Przegląd sekcji' -Object (@($picked | ForEach-Object { $_.Przestrzeń }) -join ', ') -Details $summary
        Show-HTToast "Przegląd sekcji: $summary." $(if (@($results | Where-Object { $_.Status -eq 'Błąd' }).Count) { 'warn' } else { 'ok' }) 8
    } | Out-Null
    Add-HTButton -Parent $row3 -Module $m -Text 'Pokrycie testami' -Icon 'E9D2' -ToolTip 'Każdy moduł programu: czy ma przycisk odczytu (przegląd sekcji), ile ma przycisków zmian, które testy zapisu go sprawdzają, a gdy zmian nie da się bezpiecznie przetestować - dlaczego' -OnClick {
        param($m)
        Set-HTBusy -Busy $true -Text 'Pokrycie testami…'
        try { $info = @(Get-HTModuleCoverageInfo) }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        Invoke-HTQuery -Module $m -Name 'Pokrycie testami' -Service '' -Record None -ScriptBlock { Get-HTSelfTestCoverage -Modules $info }
    } | Out-Null
    Add-HTButton -Parent $row3 -Module $m -Text 'Lista testów' -Icon 'E8FD' -OnClick {
        param($m)
        $rows = @(Get-HTSelfTests -IncludeWrite -IncludeSlow | ForEach-Object { [PSCustomObject]@{ Test = $_.Name; Usługa = Get-HTSelfTestServiceName $_.Service; Rodzaj = $(if ($_.Mode -eq 'Write') { 'zapis' } else { 'odczyt' }); Obszar = $_.Area; Długi = $_.Slow; 'Sprawdzane moduły' = (@($_.Modules) -join ', '); Opis = $_.Description; Klucz = $_.Key } })
        Show-HTDataViewer -Title 'Testy autotestu' -Data $rows -Description 'Testy odczytu niczego nie zmieniają. Testy zapisu tworzą obiekty «HT-Autotest-…» i usuwają je po sprawdzeniu.' -ExportName 'autotest_lista' -Icon 'E8FD'
    } | Out-Null
    Add-HTButton -Parent $row3 -Module $m -Text 'Pozostałości po testach' -Icon 'E721' -ToolTip 'Obiekty «HT-Autotest-…», które zostały w tenancie (np. po zamknięciu programu w trakcie testu)' -OnClick {
        param($m)
        $connected = Get-HTSelfTestConnected
        Invoke-HTQuery -Module $m -Name 'Pozostałości autotestu' -Service '' -ScriptBlock { Get-HTSelfTestLeftovers -Connected $connected }
        if (-not $m.Table.Rows.Count) { Show-HTToast 'Brak pozostałości po testach.' 'ok' }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń pozostałości' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $prefix = Get-HTSelfTestPrefix
        $rows = @($rows | Where-Object { $_.__kind -and ([string]$_.Obiekt).StartsWith($prefix) })
        if (-not $rows.Count) { Show-HTWarning "Zaznacz pozostałości autotestu (obiekty «$prefix…» z listy «Pozostałości po testach»)." -Title 'Pozostałości'; return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie pozostałości autotestu' -Rows $rows -Confirm 'Usunąć zaznaczone obiekty testowe (także z kosza katalogu)?' -Label { param($r) "$($r.Rodzaj): $($r.Obiekt)" } `
            -Action { param($r) Remove-HTSelfTestLeftover -Item $r; 'Usunięto' }
    }
    Add-HTLabel -Parent $row3 -Hint -Text 'Wyniki: prawy przycisk / eksport. Błąd - kliknij dwukrotnie wiersz, szczegóły także w dzienniku.' | Out-Null
}
#endregion
