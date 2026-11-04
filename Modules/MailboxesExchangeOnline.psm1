# Skrzynki pocztowe Exchange Online (moduł ExchangeOnlineManagement v3)

# Skrzynki systemowe Exchange (DiscoverySearchMailbox - eDiscovery i inne skrzynki usług) - domyślnie ukrywane na listach i w raportach
$script:SystemMailboxTypes = @('DiscoveryMailbox', 'ArbitrationMailbox', 'AuditLogMailbox', 'AuxAuditLogMailbox', 'MonitoringMailbox', 'SupervisoryReviewPolicyMailbox')
function Test-HTSystemMailbox {
    param ($Mailbox)
    if (-not $Mailbox) { return $false }
    if ($script:SystemMailboxTypes -contains "$($Mailbox.RecipientTypeDetails)") { return $true }
    foreach ($p in 'Name', 'Alias', 'PrimarySmtpAddress', 'UserPrincipalName', 'Identity') {
        $v = $Mailbox.PSObject.Properties[$p]
        if ($v -and "$($v.Value)" -like 'DiscoverySearchMailbox*') { return $true }
    }
    return ("$($Mailbox.DisplayName)" -eq 'Discovery Search Mailbox')
}

# Czy pomijać skrzynki systemowe (Ustawienia > Microsoft 365 i Exchange > «Pokazuj skrzynki systemowe»)
function Test-HTHideSystemMailboxes { return (-not $Global:ShowSystemMailboxes) }

# Stan skrzynki do kopii konta przed offboardingiem (typ, GAL, przekierowanie, autoodpowiedź)
function Get-HTMailboxBackupInfo {
    param ([Parameter(Mandatory)][string]$Identity)
    $m = Get-EXOMailbox -Identity $Identity -Properties HiddenFromAddressListsEnabled, ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward -ErrorAction Stop
    $auto = $null
    try { $auto = Get-MailboxAutoReplyConfiguration -Identity $Identity -ErrorAction Stop } catch { Write-Verbose $_ }
    return [ordered]@{
        Type           = "$($m.RecipientTypeDetails)"
        HiddenFromGAL  = [bool]$m.HiddenFromAddressListsEnabled
        ForwardTo      = $(if ($m.ForwardingSmtpAddress) { "$($m.ForwardingSmtpAddress)" -replace '^smtp:', '' } elseif ($m.ForwardingAddress) { "$($m.ForwardingAddress)" } else { '' })
        KeepCopy       = [bool]$m.DeliverToMailboxAndForward
        AutoReplyState = $(if ($auto) { "$($auto.AutoReplyState)" } else { '' })
    }
}

# Lista skrzynek
function Get-HTMailboxes {
    param ([string[]]$RecipientTypeDetails, [switch]$IncludeSystem)
    $params = @{
        ResultSize  = "Unlimited"
        Properties  = @("HiddenFromAddressListsEnabled", "ArchiveStatus", "ForwardingSmtpAddress", "ForwardingAddress", "WhenCreated")
        ErrorAction = "Stop"
    }
    if ($RecipientTypeDetails) { $params.RecipientTypeDetails = $RecipientTypeDetails }

    $hideSystem = (-not $IncludeSystem) -and (Test-HTHideSystemMailboxes)
    $all = @(Get-EXOMailbox @params)
    if ($hideSystem) {
        $hidden = @($all | Where-Object { Test-HTSystemMailbox $_ })
        if ($hidden.Count) {
            Write-Log -Message "Ukryto skrzynki systemowe: $($hidden.Count) ($(@($hidden | ForEach-Object { "$($_.PrimarySmtpAddress)" }) -join ', ')) - pokazanie: Ustawienia > Microsoft 365 i Exchange." -Type 'Info'
            $all = @($all | Where-Object { -not (Test-HTSystemMailbox $_) })
        }
    }
    return @($all | ForEach-Object {
            [PSCustomObject]@{
                Identity             = "$($_.PrimarySmtpAddress)"
                ObjectId             = $_.ExternalDirectoryObjectId
                DisplayName          = $_.DisplayName
                PrimarySmtpAddress   = "$($_.PrimarySmtpAddress)"
                UserPrincipalName    = $_.UserPrincipalName
                RecipientTypeDetails = "$($_.RecipientTypeDetails)"
                HiddenFromGAL        = [bool]$_.HiddenFromAddressListsEnabled
                Archive              = ("$($_.ArchiveStatus)" -eq "Active")
                Forwarding           = if ($_.ForwardingSmtpAddress) { "$($_.ForwardingSmtpAddress)" -replace '^smtp:', '' } elseif ($_.ForwardingAddress) { "$($_.ForwardingAddress)" } else { "" }
                WhenCreated          = $_.WhenCreated
            }
        } | Sort-Object DisplayName)
}

# Szczegóły skrzynki
function Get-HTMailboxDetail {
    param ([Parameter(Mandatory)][string]$Identity)

    $mbx = Get-EXOMailbox -Identity $Identity -PropertySets All -ErrorAction Stop
    $stats = $null
    try { $stats = Get-EXOMailboxStatistics -Identity $Identity -Properties LastLogonTime -ErrorAction Stop } catch { }
    $archiveStats = $null
    if ("$($mbx.ArchiveStatus)" -eq "Active") {
        try { $archiveStats = Get-EXOMailboxStatistics -Identity $Identity -Archive -ErrorAction Stop } catch { }
    }
    $autoReply = $null
    try { $autoReply = Get-MailboxAutoReplyConfiguration -Identity $Identity -ErrorAction Stop } catch { }

    $forward = if ($mbx.ForwardingSmtpAddress) { "$($mbx.ForwardingSmtpAddress)" -replace '^smtp:', '' } elseif ($mbx.ForwardingAddress) { "$($mbx.ForwardingAddress)" } else { "(brak)" }

    return [ordered]@{
        "Nazwa wyświetlana"   = $mbx.DisplayName
        "Adres główny"        = "$($mbx.PrimarySmtpAddress)"
        "UPN"                 = $mbx.UserPrincipalName
        "Typ skrzynki"        = "$($mbx.RecipientTypeDetails)"
        "Ukryta w GAL"        = [bool]$mbx.HiddenFromAddressListsEnabled
        "Utworzono"           = $mbx.WhenCreated
        "Rozmiar i limity"    = [ordered]@{
            "Rozmiar"                    = if ($stats) { "$($stats.TotalItemSize)" } else { "" }
            "Liczba elementów"           = if ($stats) { $stats.ItemCount } else { "" }
            "Ostatnie logowanie"         = if ($stats) { $stats.LastLogonTime } else { "" }
            "Limit (zakaz wysyłania)"    = "$($mbx.ProhibitSendQuota)"
            "Limit (ostrzeżenie)"        = "$($mbx.IssueWarningQuota)"
            "Archiwum"                   = switch ("$($mbx.ArchiveStatus)") { 'Active' { 'Aktywne' } { $_ -in '', 'None' } { 'Brak' } default { $_ } }
            "Rozmiar archiwum"           = if ($archiveStats) { "$($archiveStats.TotalItemSize)" } else { "" }
            "Litigation Hold"            = [bool]$mbx.LitigationHoldEnabled
            "Retencja elementów usuniętych" = ConvertTo-HTDaysText $mbx.RetainDeletedItemsFor
        }
        "Przekierowanie"      = [ordered]@{
            "Przekieruj do"          = $forward
            "Zachowaj kopię"         = [bool]$mbx.DeliverToMailboxAndForward
        }
        "Autoodpowiedź"       = [ordered]@{
            "Stan"          = if ($autoReply) { "$($autoReply.AutoReplyState)" } else { "" }
            "Od"            = if ($autoReply -and "$($autoReply.AutoReplyState)" -eq "Scheduled") { $autoReply.StartTime } else { "" }
            "Do"            = if ($autoReply -and "$($autoReply.AutoReplyState)" -eq "Scheduled") { $autoReply.EndTime } else { "" }
            "Odbiorcy zewn." = if ($autoReply) { "$($autoReply.ExternalAudience)" } else { "" }
        }
        "Adresy ($(@($mbx.EmailAddresses).Count))" = [ordered]@{
            "Aliasy" = @($mbx.EmailAddresses | ForEach-Object { "$_" } | Sort-Object)
        }
        "Wysyłanie w imieniu" = [ordered]@{
            "Użytkownicy" = @($mbx.GrantSendOnBehalfTo | ForEach-Object { "$_" })
        }
    }
}

# Okres z Exchange (TimeSpan albo tekst «14.00:00:00») jako liczba dni
function ConvertTo-HTDaysText {
    param ([AllowNull()][object]$Value)
    if ($null -eq $Value -or "$Value" -eq '') { return '' }
    $span = [TimeSpan]::Zero
    if ($Value -is [TimeSpan]) { $span = $Value }
    elseif (-not [TimeSpan]::TryParse("$Value", [System.Globalization.CultureInfo]::InvariantCulture, [ref]$span)) { return "$Value" }
    if ($span.TotalHours % 24 -ne 0) { return "$Value" }
    $days = [int]$span.TotalDays
    return $(if ($days -eq 1) { '1 dzień' } else { "$days dni" })
}

# Rozmiar z Exchange bez liczby bajtów («93.99 MB (98,558,115 bytes)» -> «93.99 MB»)
function ConvertTo-HTShortSize {
    param ([AllowNull()][object]$Value)
    return ("$Value" -replace '\s*\([\d,\.\s]+bytes\)\s*$', '').Trim()
}

<#
    Zestawienie skrzynki w jednym wierszu (moduł «Szczegóły skrzynki», widok «Skrzynki»). -Detail: wynik
    Get-HTMailboxDetail; pełne szczegóły zostają w __detail (dwuklik na wierszu).
#>
function ConvertTo-HTMailboxSummaryRow {
    param ([Parameter(Mandatory)][System.Collections.IDictionary]$Detail)
    $size = $Detail['Rozmiar i limity']
    $forward = $Detail['Przekierowanie']
    $auto = $Detail['Autoodpowiedź']
    $aliasKey = @($Detail.Keys | Where-Object { "$_" -like 'Adresy*' })[0]
    $aliases = if ($aliasKey) { @($Detail[$aliasKey]['Aliasy'] | Where-Object { $_ -and "$_" -notmatch '^(SIP|SPO|X500|X400):' }) } else { @() }
    $delegates = @($Detail['Wysyłanie w imieniu']['Użytkownicy'] | Where-Object { $_ })
    $forwardTo = [string]$forward['Przekieruj do']
    if ($forwardTo -eq '(brak)') { $forwardTo = '' }
    $autoState = switch ([string]$auto['Stan']) { 'Enabled' { 'Włączona' } 'Scheduled' { 'Zaplanowana' } 'Disabled' { 'Wyłączona' } default { $_ } }
    return [PSCustomObject]@{
        Skrzynka              = $Detail['Nazwa wyświetlana']
        Adres                 = $Detail['Adres główny']
        Typ                   = $Detail['Typ skrzynki']
        Rozmiar               = ConvertTo-HTShortSize $size['Rozmiar']
        Elementy              = $size['Liczba elementów']
        'Limit'               = ConvertTo-HTShortSize $size['Limit (zakaz wysyłania)']
        'Ostatnie logowanie'  = $size['Ostatnie logowanie']
        Archiwum              = $size['Archiwum']
        'Litigation Hold'     = $size['Litigation Hold']
        Przekierowanie        = $(if ($forwardTo -and $forward['Zachowaj kopię']) { "$forwardTo (z kopią)" } else { $forwardTo })
        'Autoodpowiedź'       = $autoState
        'Ukryta w GAL'        = $Detail['Ukryta w GAL']
        'Adresy SMTP'         = @($aliases | Where-Object { "$_" -match '^smtp:' }).Count
        'W imieniu'           = $delegates.Count
        __detail              = $Detail
        __flag                = $(if ($forwardTo) { 'warn' } elseif ($autoState -in 'Włączona', 'Zaplanowana') { 'info' } else { '' })
    }
}

# Uprawnienia do skrzynki (FullAccess, SendAs, SendOnBehalf)
function Get-HTMailboxPermissions {
    param ([Parameter(Mandatory)][string]$Identity)

    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($p in (Get-EXOMailboxPermission -Identity $Identity -ErrorAction Stop)) {
        if ($p.IsInherited -or "$($p.User)" -match '^NT AUTHORITY\\|^S-1-5-') { continue }
        $rows.Add([PSCustomObject]@{
                Type        = "FullAccess"
                User        = "$($p.User)"
                AccessRights = ($p.AccessRights -join ", ")
            })
    }

    foreach ($p in (Get-EXORecipientPermission -Identity $Identity -ErrorAction Stop)) {
        if ($p.IsInherited -or "$($p.Trustee)" -match '^NT AUTHORITY\\|^S-1-5-') { continue }
        $rows.Add([PSCustomObject]@{
                Type        = "SendAs"
                User        = "$($p.Trustee)"
                AccessRights = ($p.AccessRights -join ", ")
            })
    }

    $mbx = Get-EXOMailbox -Identity $Identity -Properties GrantSendOnBehalfTo -ErrorAction Stop
    foreach ($user in @($mbx.GrantSendOnBehalfTo)) {
        if (-not $user) { continue }
        $rows.Add([PSCustomObject]@{
                Type        = "SendOnBehalf"
                User        = "$user"
                AccessRights = "SendOnBehalf"
            })
    }

    return $rows.ToArray()
}

# Nadanie uprawnień
function Add-HTMailboxPermission {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$User,
        [Parameter(Mandatory)][ValidateSet("FullAccess", "SendAs", "SendOnBehalf")][string[]]$Type,
        [bool]$AutoMapping = $true
    )
    foreach ($t in $Type) {
        switch ($t) {
            "FullAccess" { Add-MailboxPermission -Identity $Identity -User $User -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -Confirm:$false -ErrorAction Stop | Out-Null }
            "SendAs" { Add-RecipientPermission -Identity $Identity -Trustee $User -AccessRights SendAs -Confirm:$false -ErrorAction Stop | Out-Null }
            "SendOnBehalf" { Set-Mailbox -Identity $Identity -GrantSendOnBehalfTo @{ Add = $User } -Confirm:$false -ErrorAction Stop }
        }
    }
}

# Odebranie uprawnień
#region Uprawnienia z listy (różne rodzaje dla różnych osób) i kopie wysłanych przez delegatów
$script:MailboxPermissionTokens = [ordered]@{
    FullAccess   = @('full', 'fullaccess', 'fa', 'pelny', 'pełny', 'pelnydostep', 'pełnydostęp', 'pd', 'dostep', 'dostęp')
    SendAs       = @('sendas', 'sa', 'jako', 'wyslijjako', 'wyślijjako', 'wj')
    SendOnBehalf = @('sendonbehalf', 'onbehalf', 'sob', 'wimieniu', 'imieniu', 'wyslijwimieniu', 'wyślijwimieniu', 'wi')
}

function ConvertFrom-HTMailboxPermissionType {
    # Rodzaj uprawnienia z tekstu (np. «pełny», «Full», «jako», «w imieniu») albo $null
    param([AllowEmptyString()][string]$Token)
    $t = ($Token.ToLowerInvariant() -replace '[\s\-_«»"'']', '')
    if (-not $t) { return $null }
    if ($t -in 'all', 'wszystkie', 'komplet') { return @('FullAccess', 'SendAs', 'SendOnBehalf') }
    foreach ($k in $script:MailboxPermissionTokens.Keys) { if ($script:MailboxPermissionTokens[$k] -contains $t) { return $k } }
    return $null
}

function ConvertFrom-HTMailboxPermissionLines {
    <#
        Lista osób z uprawnieniami, jedna w linii: «adres; uprawnienia; automapowanie», np.
          jan@firma.pl; pełny, jako; tak
          anna@firma.pl; pełny; nie
          piotr@firma.pl; w imieniu
          ewa@firma.pl                      <- uprawnienia i automapowanie domyślne (-DefaultTypes, -DefaultAutoMapping)
        Uprawnienia: pełny (Full / FullAccess), jako (SendAs), w imieniu (SendOnBehalf), wszystkie. Automapowanie: tak / nie
        (dotyczy pełnego dostępu - czy skrzynka sama pojawi się w Outlooku). Zwraca User, Types, AutoMapping, Problem, Line.
    #>
    param([AllowNull()][AllowEmptyString()][string]$Text, [string[]]$DefaultTypes = @('FullAccess'), [bool]$DefaultAutoMapping = $true)
    $seen = @{}
    foreach ($line in @(([string]$Text) -split '\r?\n')) {
        $l = $line.Trim()
        if (-not $l -or $l.StartsWith('#')) { continue }
        $parts = @($l -split '\s*[;\t]\s*')
        $user = $parts[0].Trim()
        $problems = @()
        if (-not $user -or $user -match '\s') { $problems += 'niepoprawny adres' }
        $types = @()
        if ($parts.Count -gt 1 -and $parts[1].Trim()) {
            foreach ($tok in @($parts[1] -split '\s*[,+/]\s*' | Where-Object { $_.Trim() })) {
                $t = ConvertFrom-HTMailboxPermissionType $tok
                if ($t) { $types += $t } else { $problems += "nieznane uprawnienie «$($tok.Trim())»" }
            }
        }
        else { $types = @($DefaultTypes) }
        $types = @($types | Select-Object -Unique)
        if (-not $types.Count -and -not $problems.Count) { $problems += 'brak uprawnień' }
        $auto = $DefaultAutoMapping
        if ($parts.Count -gt 2 -and $parts[2].Trim()) {
            switch -Regex ($parts[2].Trim().ToLowerInvariant()) {
                '^(tak|t|yes|y|1|true|auto|z|automap.*)$' { $auto = $true; break }
                '^(nie|n|no|0|false|bez)$' { $auto = $false; break }
                default { $problems += "automapowanie «$($parts[2].Trim())» - wpisz tak albo nie" }
            }
        }
        $key = $user.ToLowerInvariant()
        if ($user -and $seen.ContainsKey($key)) { $problems += 'osoba powtórzona na liście' }
        elseif ($user) { $seen[$key] = $true }
        [PSCustomObject]@{ User = $user; Types = @($types); AutoMapping = [bool]$auto; Problem = ($problems -join '; '); Line = $l }
    }
}

function Get-HTMailboxPermissionLabel {
    # Opis uprawnień do podsumowania, np. «pełny dostęp (bez automapowania), wyślij jako»
    param([string[]]$Types = @(), [bool]$AutoMapping = $true)
    @(foreach ($t in $Types) {
            switch ($t) {
                'FullAccess' { "pełny dostęp$(if (-not $AutoMapping) { ' (bez automapowania)' })" }
                'SendAs' { 'wyślij jako' }
                'SendOnBehalf' { 'wyślij w imieniu' }
            }
        }) -join ', '
}

function ConvertFrom-HTMailboxPermissionCsv {
    # Plik CSV (kolumny: Uzytkownik / Email / User, Uprawnienia / Permissions, Automapowanie / AutoMapping) -> linie listy
    param([Parameter(Mandatory)][string]$Path)
    $rows = @(Import-Csv -LiteralPath $Path -Delimiter $(if ((Get-Content -LiteralPath $Path -TotalCount 1) -match ';') { ';' } else { ',' }))
    foreach ($r in $rows) {
        $get = { param([string[]]$Names) foreach ($n in $Names) { $p = $r.PSObject.Properties | Where-Object { $_.Name -ieq $n } | Select-Object -First 1; if ($p -and "$($p.Value)".Trim()) { return "$($p.Value)".Trim() } }; '' }
        $user = & $get @('Uzytkownik', 'Użytkownik', 'Email', 'E-mail', 'User', 'Adres', 'UPN')
        if (-not $user) { continue }
        $perm = (& $get @('Uprawnienia', 'Permissions', 'Rodzaj', 'Type')) -replace ';', ','
        $auto = & $get @('Automapowanie', 'AutoMapping', 'Automap')
        (@($user, $perm, $auto) -join '; ').TrimEnd(' ', ';')
    }
}

function Get-HTMailboxSentItemsCopy {
    # Czy wiadomości wysłane przez delegatów («jako» / «w imieniu») trafiają też do Elementów wysłanych tej skrzynki
    param([Parameter(Mandatory)][string]$Identity)
    $m = Get-EXOMailbox -Identity $Identity -Properties MessageCopyForSentAsEnabled, MessageCopyForSendOnBehalfEnabled, RecipientTypeDetails -ErrorAction Stop
    return [PSCustomObject]@{
        Skrzynka                    = "$($m.PrimarySmtpAddress)"
        Typ                         = "$($m.RecipientTypeDetails)"
        'Kopia wysłanych «jako»'     = [bool]$m.MessageCopyForSentAsEnabled
        'Kopia wysłanych «w imieniu»' = [bool]$m.MessageCopyForSendOnBehalfEnabled
        __flag                      = $(if (-not $m.MessageCopyForSentAsEnabled -or -not $m.MessageCopyForSendOnBehalfEnabled) { 'warn' } else { '' })
    }
}

function Set-HTMailboxSentItemsCopy {
    # Kopie wiadomości wysłanych przez delegatów w Elementach wysłanych skrzynki (współdzielonej albo użytkownika)
    param([Parameter(Mandatory)][string]$Identity, [bool]$SentAs = $true, [bool]$SendOnBehalf = $true)
    Set-Mailbox -Identity $Identity -MessageCopyForSentAsEnabled $SentAs -MessageCopyForSendOnBehalfEnabled $SendOnBehalf -Confirm:$false -ErrorAction Stop
}
#endregion

function Remove-HTMailboxPermission {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$User,
        [Parameter(Mandatory)][ValidateSet("FullAccess", "SendAs", "SendOnBehalf")][string]$Type
    )
    switch ($Type) {
        "FullAccess" { Remove-MailboxPermission -Identity $Identity -User $User -AccessRights FullAccess -InheritanceType All -Confirm:$false -ErrorAction Stop }
        "SendAs" { Remove-RecipientPermission -Identity $Identity -Trustee $User -AccessRights SendAs -Confirm:$false -ErrorAction Stop }
        "SendOnBehalf" { Set-Mailbox -Identity $Identity -GrantSendOnBehalfTo @{ Remove = $User } -Confirm:$false -ErrorAction Stop }
    }
}

# Konwersja typu skrzynki
# Typ, widoczność w GAL i archiwum skrzynki - przegląd przed zmianą (moduł «Typ i widoczność»)
function Get-HTMailboxTypeInfo {
    param ([Parameter(Mandatory)][string]$Identity, [string]$TargetType = '')
    $mbx = Get-EXOMailbox -Identity $Identity -Properties HiddenFromAddressListsEnabled, ArchiveStatus, AutoExpandingArchiveEnabled, LitigationHoldEnabled -ErrorAction Stop
    $names = @{ UserMailbox = 'Użytkownika'; SharedMailbox = 'Współdzielona'; RoomMailbox = 'Sala'; EquipmentMailbox = 'Zasób'; DiscoveryMailbox = 'Systemowa (eDiscovery)' }
    $typeMap = @{ Regular = 'UserMailbox'; Shared = 'SharedMailbox'; Room = 'RoomMailbox'; Equipment = 'EquipmentMailbox' }
    $type = "$($mbx.RecipientTypeDetails)"
    $differs = $TargetType -and $typeMap[$TargetType] -and $typeMap[$TargetType] -ne $type
    return [PSCustomObject]@{
        Skrzynka               = $mbx.DisplayName
        Typ                    = $(if ($names[$type]) { $names[$type] } else { $type })
        'Typ (Exchange)'       = $type
        'Ukryta w GAL'         = [bool]$mbx.HiddenFromAddressListsEnabled
        Archiwum               = $(if ("$($mbx.ArchiveStatus)" -eq 'Active') { 'Aktywne' } else { 'Brak' })
        'Archiwum rozszerzane' = [bool]$mbx.AutoExpandingArchiveEnabled
        'Litigation Hold'      = [bool]$mbx.LitigationHoldEnabled
        __address              = "$($mbx.PrimarySmtpAddress)"
        __flag                 = $(if ($differs) { 'warn' } else { '' })
    }
}

function Convert-HTMailboxType {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][ValidateSet("Regular", "Shared", "Room", "Equipment")][string]$Type
    )
    Set-Mailbox -Identity $Identity -Type $Type -Confirm:$false -ErrorAction Stop
}

# Aktualna konfiguracja autoodpowiedzi
function Get-HTMailboxAutoReply {
    param ([Parameter(Mandatory)][string]$Identity)
    return Get-MailboxAutoReplyConfiguration -Identity $Identity -ErrorAction Stop
}

# Ustawienie autoodpowiedzi
function Set-HTMailboxAutoReply {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][ValidateSet("Disabled", "Enabled", "Scheduled")][string]$State,
        [string]$InternalMessage,
        [string]$ExternalMessage,
        [ValidateSet("None", "Known", "All")][string]$ExternalAudience = "All",
        [Nullable[datetime]]$StartTime,
        [Nullable[datetime]]$EndTime
    )

    $params = @{
        Identity       = $Identity
        AutoReplyState = $State
        ErrorAction    = "Stop"
    }
    if ($State -ne "Disabled") {
        $params.InternalMessage = ConvertTo-HTAutoReplyHtml $InternalMessage
        $params.ExternalMessage = ConvertTo-HTAutoReplyHtml $(if ($ExternalMessage) { $ExternalMessage } else { $InternalMessage })
        $params.ExternalAudience = $ExternalAudience
    }
    if ($State -eq "Scheduled") {
        if (-not $StartTime -or -not $EndTime) { throw "Dla trybu zaplanowanego wymagane są daty rozpoczęcia i zakończenia." }
        if ($EndTime -le $StartTime) { throw "Data zakończenia musi być późniejsza niż data rozpoczęcia." }
        $params.StartTime = $StartTime
        $params.EndTime = $EndTime
    }
    Set-MailboxAutoReplyConfiguration @params
}

function Clear-HTMailboxAutoReply {
    # Wyczyszczenie autoodpowiedzi niezależnie od stanu: wyłączenie i usunięcie treści (wewnętrznej i zewnętrznej) oraz terminów
    param ([Parameter(Mandatory)][string]$Identity)
    Set-MailboxAutoReplyConfiguration -Identity $Identity -AutoReplyState Disabled -InternalMessage $null -ExternalMessage $null -ErrorAction Stop
}

# Zamiana zwykłego tekstu na prosty HTML (zachowanie nowych linii)
function ConvertTo-HTAutoReplyHtml {
    param ([AllowEmptyString()][AllowNull()][string]$Text)
    if (-not $Text) { return "" }
    if ($Text -match '<(html|body|p|br|div)\b') { return $Text }
    $encoded = [System.Net.WebUtility]::HtmlEncode($Text)
    return ($encoded -replace "`r?`n", "<br>")
}

# Zamiana HTML autoodpowiedzi na zwykły tekst (do edycji)
function ConvertFrom-HTAutoReplyHtml {
    param ([AllowEmptyString()][AllowNull()][string]$Html)
    if (-not $Html) { return "" }
    $text = $Html -replace '(?i)<br\s*/?>', "`r`n" -replace '(?i)</(p|div)>', "`r`n" -replace '<[^>]+>', ''
    return ([System.Net.WebUtility]::HtmlDecode($text)).Trim()
}

# Ukrycie / pokazanie w globalnej liście adresów
function Set-HTMailboxHiddenFromGAL {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][bool]$Hidden
    )
    Set-Mailbox -Identity $Identity -HiddenFromAddressListsEnabled $Hidden -Confirm:$false -ErrorAction Stop
}

# Włączenie archiwum (opcjonalnie auto-rozszerzalnego)
function Enable-HTMailboxArchive {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [switch]$AutoExpanding
    )
    $mbx = Get-EXOMailbox -Identity $Identity -Properties ArchiveStatus -ErrorAction Stop
    if ("$($mbx.ArchiveStatus)" -ne "Active") {
        Enable-Mailbox -Identity $Identity -Archive -Confirm:$false -ErrorAction Stop | Out-Null
    }
    if ($AutoExpanding) {
        Enable-Mailbox -Identity $Identity -AutoExpandingArchive -Confirm:$false -ErrorAction Stop | Out-Null
    }
}

# Ustawienie / usunięcie przekierowania
function Set-HTMailboxForwarding {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [AllowEmptyString()][string]$ForwardTo,
        [bool]$KeepCopy = $true
    )
    if ([string]::IsNullOrWhiteSpace($ForwardTo)) {
        Set-Mailbox -Identity $Identity -ForwardingSmtpAddress $null -ForwardingAddress $null -DeliverToMailboxAndForward $false -Confirm:$false -ErrorAction Stop
    }
    else {
        Set-Mailbox -Identity $Identity -ForwardingSmtpAddress "smtp:$ForwardTo" -DeliverToMailboxAndForward $KeepCopy -Confirm:$false -ErrorAction Stop
    }
}

# Nazwa folderu kalendarza (zależna od języka skrzynki)
function Get-HTCalendarFolderIdentity {
    param ([Parameter(Mandatory)][string]$Identity)
    $folder = Get-EXOMailboxFolderStatistics -Identity $Identity -FolderScope Calendar -ErrorAction Stop |
        Where-Object { $_.FolderType -eq "Calendar" } | Select-Object -First 1
    $name = if ($folder) { $folder.Name } else { "Calendar" }
    return "$($Identity):\$name"
}

# Uprawnienia do kalendarza
function Get-HTCalendarPermissions {
    param ([Parameter(Mandatory)][string]$Identity)
    $folderId = Get-HTCalendarFolderIdentity -Identity $Identity
    return @(Get-EXOMailboxFolderPermission -Identity $folderId -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Folder       = $folderId
                User         = "$($_.User)"
                AccessRights = ($_.AccessRights -join ", ")
                SharingPermissionFlags = "$($_.SharingPermissionFlags)"
            }
        })
}

# Nadanie / zmiana uprawnień do kalendarza
function Set-HTCalendarPermission {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$User,
        [Parameter(Mandatory)][ValidateSet("Reviewer", "LimitedDetails", "AvailabilityOnly", "Author", "Editor", "PublishingEditor", "Owner", "None")][string]$AccessRights
    )
    $folderId = Get-HTCalendarFolderIdentity -Identity $Identity
    $existing = Get-EXOMailboxFolderPermission -Identity $folderId -User $User -ErrorAction SilentlyContinue
    if ($existing) {
        Set-MailboxFolderPermission -Identity $folderId -User $User -AccessRights $AccessRights -Confirm:$false -ErrorAction Stop | Out-Null
    }
    else {
        Add-MailboxFolderPermission -Identity $folderId -User $User -AccessRights $AccessRights -Confirm:$false -ErrorAction Stop | Out-Null
    }
}

# Usunięcie uprawnień do kalendarza
function Remove-HTCalendarPermission {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$User
    )
    $folderId = Get-HTCalendarFolderIdentity -Identity $Identity
    Remove-MailboxFolderPermission -Identity $folderId -User $User -Confirm:$false -ErrorAction Stop
}

# Reguły skrzynki odbiorczej
function Get-HTInboxRules {
    param ([Parameter(Mandatory)][string]$Identity)
    return @(Get-InboxRule -Mailbox $Identity -ErrorAction Stop | ForEach-Object {
            $forwards = @($_.ForwardTo) + @($_.RedirectTo) + @($_.ForwardAsAttachmentTo) | Where-Object { $_ }
            [PSCustomObject]@{
                Name           = $_.Name
                Enabled        = [bool]$_.Enabled
                Priority       = $_.Priority
                ForwardTo      = ($_.ForwardTo -join ", ")
                RedirectTo     = ($_.RedirectTo -join ", ")
                MoveToFolder   = "$($_.MoveToFolder)"
                DeleteMessage  = [bool]$_.DeleteMessage
                Description    = ("$($_.Description)" -replace "`r?`n", " ")
                RuleIdentity   = "$($_.Identity)"
                __flag         = if ($forwards.Count -gt 0 -or $_.DeleteMessage) { "warn" } elseif (-not $_.Enabled) { "muted" } else { "" }
            }
        })
}

# Śledzenie wiadomości (ostatnie dni)
function Get-HTMessageTrace {
    param (
        [Parameter(Mandatory)][string]$Address,
        [ValidateSet("Received", "Sent")][string]$Direction = "Received",
        [ValidateRange(1, 10)][int]$Days = 2
    )

    $params = @{
        StartDate   = (Get-Date).AddDays(-$Days)
        EndDate     = Get-Date
        ErrorAction = "Stop"
    }
    if ($Direction -eq "Received") { $params.RecipientAddress = $Address } else { $params.SenderAddress = $Address }

    $command = if (Get-Command Get-MessageTraceV2 -ErrorAction SilentlyContinue) { "Get-MessageTraceV2" } else { "Get-MessageTrace" }
    if ($command -eq "Get-MessageTraceV2") { $params.ResultSize = 1000 } else { $params.PageSize = 1000 }

    return @(& $command @params | ForEach-Object {
            [PSCustomObject]@{
                Received  = $_.Received
                Sender    = $_.SenderAddress
                Recipient = $_.RecipientAddress
                Subject   = $_.Subject
                Status    = "$($_.Status)"
                Size      = $_.Size
            }
        })
}

# Urządzenia mobilne powiązane ze skrzynką
function Get-HTMailboxMobileDevices {
    param ([Parameter(Mandatory)][string]$Identity)
    return @(Get-EXOMobileDeviceStatistics -Mailbox $Identity -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Device        = $_.DeviceFriendlyName
                Model         = $_.DeviceModel
                OS            = $_.DeviceOS
                ClientType    = "$($_.ClientType)"
                AccessState   = "$($_.DeviceAccessState)"
                LastSync      = $_.LastSuccessSync
                DeviceId      = $_.DeviceId
                DeviceIdentity = "$($_.Identity)"
            }
        })
}

# Liczba skrzynek wg typu (Dashboard)
function Get-HTMailboxSummary {
    $hideSystem = Test-HTHideSystemMailboxes
    $all = @(Get-EXOMailbox -ResultSize Unlimited -ErrorAction Stop | Where-Object { -not ($hideSystem -and (Test-HTSystemMailbox $_)) })
    $byType = $all | Group-Object RecipientTypeDetails
    return [PSCustomObject]@{
        Total  = $all.Count
        User   = [int](($byType | Where-Object Name -eq "UserMailbox").Count)
        Shared = [int](($byType | Where-Object Name -eq "SharedMailbox").Count)
        Other  = $all.Count - [int](($byType | Where-Object Name -eq "UserMailbox").Count) - [int](($byType | Where-Object Name -eq "SharedMailbox").Count)
    }
}

#region Reguły skrzynki i urządzenia mobilne
function Disable-HTInboxRule {
    param ([Parameter(Mandatory)][string]$Mailbox, [Parameter(Mandatory)][string]$Identity)
    Disable-InboxRule -Mailbox $Mailbox -Identity $Identity -Confirm:$false -ErrorAction Stop
}

function Remove-HTInboxRule {
    param ([Parameter(Mandatory)][string]$Mailbox, [Parameter(Mandatory)][string]$Identity)
    Remove-InboxRule -Mailbox $Mailbox -Identity $Identity -Confirm:$false -ErrorAction Stop
}

# Usunięcie powiązania urządzenia mobilnego ze skrzynką (urządzenie musi ponownie się zsynchronizować)
function Remove-HTMailboxMobileDevice {
    param ([Parameter(Mandatory)][string]$Identity)
    Remove-MobileDevice -Identity $Identity -Confirm:$false -ErrorAction Stop
}
#endregion

#region Rozmiary i statystyki
# Rozmiar z Exchange ("1.2 GB (1,288,490,188 bytes)") na liczbę bajtów; $null dla "Unlimited" i pustych
function ConvertFrom-HTExchangeSize {
    param ([AllowNull()][object]$Value)
    if ($null -eq $Value) { return $null }
    $text = "$Value"
    if ($text -match '\(([\d,\.\s ]+)\s*bytes\)') { return [long](($matches[1]) -replace '[^\d]', '') }
    if ($text -match '^\d+$') { return [long]$text }
    return $null
}

# Statystyki skrzynki: rozmiar, liczba elementów, wykorzystanie limitu, aktywność
function Get-HTMailboxUsage {
    param ([Parameter(Mandatory)][string]$Identity)
    $mbx = Get-EXOMailbox -Identity $Identity -Properties ProhibitSendQuota, ArchiveStatus, LitigationHoldEnabled, RetainDeletedItemsFor -ErrorAction Stop
    $stats = Get-EXOMailboxStatistics -Identity $Identity -Properties LastLogonTime, LastUserActionTime -ErrorAction Stop
    $size = ConvertFrom-HTExchangeSize $stats.TotalItemSize
    $deleted = ConvertFrom-HTExchangeSize $stats.TotalDeletedItemSize
    $quota = ConvertFrom-HTExchangeSize $mbx.ProhibitSendQuota
    $archive = $null
    if ("$($mbx.ArchiveStatus)" -eq "Active") {
        try { $archive = ConvertFrom-HTExchangeSize (Get-EXOMailboxStatistics -Identity $Identity -Archive -ErrorAction Stop).TotalItemSize } catch { $archive = $null }
    }
    $percent = if ($size -and $quota) { [Math]::Round(100 * $size / $quota, 1) } else { $null }
    $lastActivity = @($stats.LastUserActionTime, $stats.LastLogonTime) | Where-Object { $_ } | Sort-Object -Descending | Select-Object -First 1
    return [PSCustomObject]@{
        Skrzynka              = $mbx.DisplayName
        Adres                 = "$($mbx.PrimarySmtpAddress)"
        Typ                   = "$($mbx.RecipientTypeDetails)"
        "Rozmiar (MB)"        = if ($null -ne $size) { [Math]::Round($size / 1MB, 1) } else { $null }
        Elementy              = $stats.ItemCount
        "Usunięte (MB)"       = if ($null -ne $deleted) { [Math]::Round($deleted / 1MB, 1) } else { $null }
        "Limit (GB)"          = if ($quota) { [Math]::Round($quota / 1GB, 1) } else { "bez limitu" }
        "Wykorzystanie %"     = $percent
        "Archiwum (MB)"       = if ($null -ne $archive) { [Math]::Round($archive / 1MB, 1) } else { $null }
        "Ostatnia aktywność"  = $lastActivity
        "Dni bez aktywności"  = Get-HTDaysSince $lastActivity
        "Litigation Hold"     = [bool]$mbx.LitigationHoldEnabled
        __flag                = if ($percent -ge 95) { "crit" } elseif ($percent -ge 85) { "warn" } else { "" }
    }
}
#endregion

#region Dostęp użytkownika do skrzynek
# Skrzynki, do których użytkownik ma FullAccess / SendAs / SendOnBehalf.
# OnProgress: { param($Index, $Total, $Name) } - przegląd wszystkich skrzynek może potrwać.
function Get-HTUserMailboxAccess {
    param (
        [Parameter(Mandatory)][string]$User,
        [scriptblock]$OnProgress
    )
    $recipient = Get-EXORecipient -Identity $User -ErrorAction Stop
    $ids = @("$($recipient.PrimarySmtpAddress)", "$($recipient.Name)", "$($recipient.DisplayName)", "$($recipient.Alias)", "$($recipient.ExternalDirectoryObjectId)") +
        @($recipient.EmailAddresses | ForEach-Object { "$_" -replace '^smtp:', '' }) | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() }
    $upn = (Get-EXOMailbox -Identity $User -ErrorAction SilentlyContinue).UserPrincipalName
    if ($upn) { $ids += $upn.ToLowerInvariant() }
    $ids = @($ids | Select-Object -Unique)
    $result = New-Object System.Collections.Generic.List[object]

    $hideSystem = Test-HTHideSystemMailboxes
    $mailboxes = @(Get-EXOMailbox -ResultSize Unlimited -Properties GrantSendOnBehalfTo -ErrorAction Stop | Where-Object { -not ($hideSystem -and (Test-HTSystemMailbox $_)) })
    $i = 0
    foreach ($mbx in $mailboxes) {
        $i++
        if ($OnProgress) { & $OnProgress $i $mailboxes.Count $mbx.DisplayName }
        $address = "$($mbx.PrimarySmtpAddress)"
        try {
            foreach ($p in @(Get-EXOMailboxPermission -Identity $address -ErrorAction Stop)) {
                if ($p.IsInherited) { continue }
                if ($ids -contains "$($p.User)".ToLowerInvariant()) {
                    $result.Add([PSCustomObject]@{ Skrzynka = $mbx.DisplayName; Adres = $address; Typ = "$($mbx.RecipientTypeDetails)"; Uprawnienie = "FullAccess" })
                }
            }
        }
        catch { Write-Log -Message "Uprawnienia skrzynki $($address): $($_.Exception.Message)" -Type "Warn" }
        foreach ($delegate in @($mbx.GrantSendOnBehalfTo)) {
            if ($delegate -and $ids -contains "$delegate".ToLowerInvariant()) {
                $result.Add([PSCustomObject]@{ Skrzynka = $mbx.DisplayName; Adres = $address; Typ = "$($mbx.RecipientTypeDetails)"; Uprawnienie = "SendOnBehalf" })
            }
        }
    }

    $sendAs = @()
    try { $sendAs = @(Get-EXORecipientPermission -Trustee $User -ResultSize Unlimited -ErrorAction Stop) }
    catch { $sendAs = @(Get-RecipientPermission -Trustee $User -ResultSize Unlimited -ErrorAction Stop) }
    foreach ($p in $sendAs) {
        if ($p.IsInherited -or @($p.AccessRights) -notcontains "SendAs") { continue }
        $result.Add([PSCustomObject]@{ Skrzynka = "$($p.Identity)"; Adres = "$($p.Identity)"; Typ = ""; Uprawnienie = "SendAs" })
    }
    return $result.ToArray()
}
#endregion

#region Adresy e-mail (aliasy)
function Get-HTMailboxAddresses {
    param ([Parameter(Mandatory)][string]$Identity)
    $mbx = Get-EXOMailbox -Identity $Identity -Properties EmailAddresses -ErrorAction Stop
    return @($mbx.EmailAddresses | ForEach-Object {
            $value = "$_"
            $prefix = ($value -split ':', 2)[0]
            [PSCustomObject]@{
                Adres     = ($value -split ':', 2)[1]
                Typ       = $prefix.ToUpperInvariant()
                Główny    = ($prefix -ceq "SMTP")
                Wartość   = $value
                __flag    = if ($prefix -ceq "SMTP") { "" } elseif ($prefix -notmatch '^smtp$') { "muted" } else { "" }
            }
        } | Sort-Object @{ Expression = { -not $_.Główny } }, Typ, Adres)
}

function Add-HTMailboxAddress {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$Address
    )
    if (-not (Test-HTInputValue -Value $Address -ValidationType Email)) { throw "Nieprawidłowy adres e-mail: $Address" }
    Set-Mailbox -Identity $Identity -EmailAddresses @{ Add = "smtp:$Address" } -Confirm:$false -ErrorAction Stop
}

function Remove-HTMailboxAddress {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$Value
    )
    if ($Value -cmatch '^SMTP:') { throw "Nie można usunąć adresu głównego ($Value)." }
    Set-Mailbox -Identity $Identity -EmailAddresses @{ Remove = $Value } -Confirm:$false -ErrorAction Stop
}
#endregion

#region Zgodność: Litigation Hold, retencja, kwarantanna, odzyskiwanie elementów
function Set-HTMailboxLitigationHold {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][bool]$Enabled,
        [int]$DurationDays = 0
    )
    $params = @{ Identity = $Identity; LitigationHoldEnabled = $Enabled; Confirm = $false; ErrorAction = "Stop" }
    if ($Enabled) { $params.LitigationHoldDuration = if ($DurationDays -gt 0) { $DurationDays } else { "Unlimited" } }
    Set-Mailbox @params
}

function Set-HTMailboxRetainDeletedItems {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][ValidateRange(1, 30)][int]$Days
    )
    Set-Mailbox -Identity $Identity -RetainDeletedItemsFor $Days -Confirm:$false -ErrorAction Stop
}

# Wiadomości w kwarantannie (opcjonalnie dla wskazanych odbiorców)
function Get-HTQuarantineMessages {
    param (
        [string[]]$Recipients = @(),
        [ValidateRange(1, 30)][int]$Days = 7,
        [string]$SenderAddress
    )
    $params = @{
        StartReceivedDate = (Get-Date).AddDays(-$Days)
        EndReceivedDate   = Get-Date
        PageSize          = 1000
        ErrorAction       = "Stop"
    }
    if ($Recipients.Count -gt 0) { $params.RecipientAddress = $Recipients }
    if ($SenderAddress) { $params.SenderAddress = $SenderAddress }
    return @(Get-QuarantineMessage @params | ForEach-Object {
            [PSCustomObject]@{
                Odebrano       = $_.ReceivedTime
                Nadawca        = $_.SenderAddress
                Odbiorca       = (@($_.RecipientAddress) -join ", ")
                Temat          = $_.Subject
                Powód          = "$($_.QuarantineTypes)"
                Kierunek       = "$($_.Direction)"
                Zwolniona      = "$($_.ReleaseStatus)"
                Wygasa         = $_.Expires
                Identity       = "$($_.Identity)"
                __flag         = if ("$($_.QuarantineTypes)" -match 'Malware|HighConfPhish') { "crit" } elseif ("$($_.ReleaseStatus)" -eq "Released") { "muted" } else { "" }
            }
        } | Sort-Object Odebrano -Descending)
}

function Invoke-HTQuarantineRelease {
    param ([Parameter(Mandatory)][string]$Identity, [switch]$AllowSender)
    $params = @{ Identity = $Identity; ReleaseToAll = $true; ErrorAction = "Stop" }
    if ($AllowSender) { $params.AllowSender = $true }
    Release-QuarantineMessage @params
}

function Remove-HTQuarantineMessage {
    param ([Parameter(Mandatory)][string]$Identity)
    Delete-QuarantineMessage -Identity $Identity -Confirm:$false -ErrorAction Stop
}

# Treść wiadomości z kwarantanny (zwykły tekst)
function Get-HTQuarantinePreview {
    param ([Parameter(Mandatory)][string]$Identity)
    $preview = Preview-QuarantineMessage -Identity $Identity -ErrorAction Stop
    $body = "$($preview.Body)" -replace '(?i)<br\s*/?>', "`n" -replace '(?i)</(p|div|tr)>', "`n" -replace '<[^>]+>', ''
    $text = [System.Net.WebUtility]::HtmlDecode($body) -replace "(`r?`n\s*){3,}", "`n`n"
    return "Od: $($preview.Sender)`nDo: $(@($preview.To) -join ', ')`nTemat: $($preview.Subject)`nData: $($preview.ReceivedTime)`n`n$($text.Trim())"
}

# Elementy możliwe do odzyskania (Recoverable Items) - wymaga roli Mailbox Import Export
function Get-HTRecoverableItems {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [ValidateRange(1, 90)][int]$Days = 14,
        [string]$SubjectContains
    )
    $params = @{
        Identity        = $Identity
        FilterStartTime = (Get-Date).AddDays(-$Days)
        FilterEndTime   = (Get-Date).AddDays(1)
        ResultSize      = 1000
        ErrorAction     = "Stop"
    }
    if ($SubjectContains) { $params.SubjectContains = $SubjectContains }
    return @(Get-RecoverableItems @params | ForEach-Object {
            [PSCustomObject]@{
                Temat     = $_.Subject
                Typ       = $_.ItemClass
                Usunięto  = $_.LastModifiedTime
                Folder    = $_.LastParentPath
                EntryID   = $_.EntryID
                Skrzynka  = $Identity
            }
        } | Sort-Object Usunięto -Descending)
}

function Restore-HTRecoverableItem {
    param ([Parameter(Mandatory)][string]$Identity, [Parameter(Mandatory)][string]$EntryID)
    Restore-RecoverableItems -Identity $Identity -EntryID $EntryID -ErrorAction Stop | Out-Null
}
#endregion

#region Grupy dystrybucyjne
function Get-HTDistributionGroups {
    return @(Get-DistributionGroup -ResultSize Unlimited -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Nazwa                 = $_.DisplayName
                Adres                 = "$($_.PrimarySmtpAddress)"
                Typ                   = "$($_.RecipientTypeDetails)"
                Właściciele           = (@($_.ManagedBy) -join ", ")
                "Tylko wewnętrzni nadawcy" = [bool]$_.RequireSenderAuthenticationEnabled
                "Ukryta w GAL"        = [bool]$_.HiddenFromAddressListsEnabled
                "Synchronizowana z AD" = [bool]$_.IsDirSynced
                Identity              = "$($_.PrimarySmtpAddress)"
            }
        } | Sort-Object Nazwa)
}

function Get-HTDistributionGroupMembers {
    param ([Parameter(Mandatory)][string]$Identity)
    return @(Get-DistributionGroupMember -Identity $Identity -ResultSize Unlimited -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Nazwa = $_.DisplayName
                Adres = "$($_.PrimarySmtpAddress)"
                Typ   = "$($_.RecipientTypeDetails)"
            }
        } | Sort-Object Nazwa)
}

# Grupy dystrybucyjne i zabezpieczeń z pocztą, do których należy odbiorca
function Get-HTRecipientGroups {
    param ([Parameter(Mandatory)][string]$Identity)
    $dn = (Get-Recipient -Identity $Identity -ErrorAction Stop).DistinguishedName
    $escaped = $dn.Replace("'", "''")
    return @(Get-Recipient -Filter "Members -eq '$escaped'" -ResultSize Unlimited -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Grupa = $_.DisplayName
                Adres = "$($_.PrimarySmtpAddress)"
                Typ   = "$($_.RecipientTypeDetails)"
            }
        } | Sort-Object Grupa)
}

function Add-HTDistributionGroupMember {
    param ([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][string]$Member)
    Add-DistributionGroupMember -Identity $Group -Member $Member -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop
}

function Remove-HTDistributionGroupMember {
    param ([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][string]$Member)
    Remove-DistributionGroupMember -Identity $Group -Member $Member -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop
}
#endregion

#region Raport przekierowań poza organizację
# Przekierowania skrzynek (ForwardingSmtpAddress) i reguł skrzynek do adresów spoza domen akceptowanych.
function Get-HTExternalForwardingReport {
    param (
        [switch]$IncludeInboxRules,
        [scriptblock]$OnProgress
    )
    $domains = @(Get-AcceptedDomain -ErrorAction Stop | ForEach-Object { "$($_.DomainName)".ToLowerInvariant() })
    $isExternal = {
        param($Address)
        $clean = ("$Address" -replace '^(smtp|SMTP):', '').Trim().Trim('"')
        if ($clean -notmatch '@([^@\]\s>]+)') { return $false }
        return $domains -notcontains $matches[1].ToLowerInvariant()
    }
    $hideSystem = Test-HTHideSystemMailboxes
    $mailboxes = @(Get-EXOMailbox -ResultSize Unlimited -Properties ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward -ErrorAction Stop | Where-Object { -not ($hideSystem -and (Test-HTSystemMailbox $_)) })
    $i = 0
    foreach ($mbx in $mailboxes) {
        $i++
        $address = "$($mbx.PrimarySmtpAddress)"
        if ($mbx.ForwardingSmtpAddress) {
            $target = "$($mbx.ForwardingSmtpAddress)" -replace '^smtp:', ''
            $external = & $isExternal $target
            [PSCustomObject]@{
                Skrzynka       = $mbx.DisplayName
                Adres          = $address
                Źródło         = "Przekierowanie skrzynki"
                "Przekierowuje do" = $target
                Zewnętrzne     = $external
                "Kopia w skrzynce" = [bool]$mbx.DeliverToMailboxAndForward
                __flag         = if ($external) { "crit" } else { "" }
            }
        }
        elseif ($mbx.ForwardingAddress) {
            [PSCustomObject]@{
                Skrzynka       = $mbx.DisplayName
                Adres          = $address
                Źródło         = "Przekierowanie skrzynki (kontakt/odbiorca)"
                "Przekierowuje do" = "$($mbx.ForwardingAddress)"
                Zewnętrzne     = $false
                "Kopia w skrzynce" = [bool]$mbx.DeliverToMailboxAndForward
                __flag         = "warn"
            }
        }
        if (-not $IncludeInboxRules) { continue }
        if ($OnProgress) { & $OnProgress $i $mailboxes.Count $mbx.DisplayName }
        try {
            foreach ($rule in @(Get-InboxRule -Mailbox $address -ErrorAction Stop)) {
                $targets = @($rule.ForwardTo) + @($rule.RedirectTo) + @($rule.ForwardAsAttachmentTo) | Where-Object { $_ }
                if ($targets.Count -eq 0) { continue }
                $text = @($targets | ForEach-Object { "$_" })
                $external = @($text | Where-Object { & $isExternal $_ }).Count -gt 0
                [PSCustomObject]@{
                    Skrzynka       = $mbx.DisplayName
                    Adres          = $address
                    Źródło         = "Reguła: $($rule.Name)$(if (-not $rule.Enabled) { ' (wyłączona)' })"
                    "Przekierowuje do" = ($text -join "; ")
                    Zewnętrzne     = $external
                    "Kopia w skrzynce" = -not [bool]$rule.RedirectTo
                    __flag         = if ($external -and $rule.Enabled) { "crit" } elseif ($external) { "warn" } else { "" }
                }
            }
        }
        catch { Write-Log -Message "Reguły skrzynki $($address): $($_.Exception.Message)" -Type "Warn" }
    }
}
#endregion

#region Reguły transportu (przepływ poczty)
function Get-HTTransportRules {
    foreach ($r in @(Get-TransportRule -ResultSize Unlimited -ErrorAction Stop | Sort-Object Priority)) {
        [PSCustomObject]@{
            Priorytet   = $r.Priority
            Reguła      = $r.Name
            Stan        = "$($r.State)"
            Tryb        = "$($r.Mode)"
            Opis        = ([string]$r.Description).Trim()
            Ważność     = "$($r.SetAuditSeverity)"
            Zmieniono   = $r.WhenChanged
            Komentarz   = $r.Comments
            Id          = "$($r.Guid)"
            __flag      = if ("$($r.State)" -ne 'Enabled') { 'muted' } elseif ("$($r.Mode)" -ne 'Enforce') { 'warn' } else { '' }
        }
    }
}

function Set-HTTransportRuleState {
    param ([Parameter(Mandatory)][string]$Identity, [Parameter(Mandatory)][bool]$Enabled)
    if ($Enabled) { Enable-TransportRule -Identity $Identity -Confirm:$false -ErrorAction Stop }
    else { Disable-TransportRule -Identity $Identity -Confirm:$false -ErrorAction Stop }
}
#endregion

#region Lista dozwolonych i zablokowanych (Tenant Allow/Block List)
function Get-HTTenantAllowBlockList {
    param ([ValidateSet('Sender', 'Url', 'FileHash', 'IP')][string[]]$ListType = @('Sender', 'Url', 'FileHash'))
    $names = @{ Sender = 'Nadawca / domena'; Url = 'Adres URL'; FileHash = 'Plik (SHA256)'; IP = 'Adres IP' }
    foreach ($type in $ListType) {
        $items = @()
        try { $items = @(Get-TenantAllowBlockListItems -ListType $type -ErrorAction Stop) }
        catch { Write-Log -Message "Lista dozwolonych i zablokowanych ($type): $($_.Exception.Message)" -Type 'Warn'; continue }
        foreach ($i in $items) {
            $expires = if ($i.ExpirationDate) { $i.ExpirationDate } else { $null }
            $left = if ($expires) { [int][Math]::Floor(([datetime]$expires - (Get-Date)).TotalDays) } else { $null }
            [PSCustomObject]@{
                Lista       = $names[$type]
                Wartość     = $i.Value
                Akcja       = $(if ($i.Action -eq 'Block') { 'Blokuj' } elseif ($i.Action -eq 'Allow') { 'Zezwalaj' } else { [string]$i.Action })
                Wygasa      = $(if ($expires) { $expires } else { 'nigdy' })
                'Dni do wygaśnięcia' = $left
                Notatka     = $i.Notes
                Zmieniono   = $i.LastModifiedDateTime
                Zmienił     = $i.ModifiedBy
                Id          = $i.Identity
                __type      = $type
                __flag      = if ($i.Action -eq 'Allow') { 'warn' } elseif ($null -ne $left -and $left -le 3) { 'muted' } else { '' }
            }
        }
    }
}

function Add-HTTenantAllowBlockItem {
    # Nowe wpisy listy (blokada albo zezwolenie); -Days 0 - bez wygaśnięcia (dla zezwoleń Microsoft wymaga daty wygaśnięcia)
    param (
        [Parameter(Mandatory)][ValidateSet('Sender', 'Url', 'FileHash', 'IP')][string]$ListType,
        [Parameter(Mandatory)][string[]]$Entries,
        [ValidateSet('Block', 'Allow')][string]$Action = 'Block',
        [int]$Days = 30,
        [string]$Notes = ''
    )
    $params = @{ ListType = $ListType; Entries = @($Entries); ErrorAction = 'Stop' }
    if ($Action -eq 'Block') { $params.Block = $true } else { $params.Allow = $true }
    if ($Days -gt 0) { $params.ExpirationDate = (Get-Date).AddDays($Days) } else { $params.NoExpiration = $true }
    if ($Notes) { $params.Notes = $Notes }
    New-TenantAllowBlockListItems @params | Out-Null
}

function Remove-HTTenantAllowBlockItem {
    param ([Parameter(Mandatory)][string]$ListType, [Parameter(Mandatory)][string[]]$Ids)
    Remove-TenantAllowBlockListItems -ListType $ListType -Ids $Ids -ErrorAction Stop | Out-Null
}
#endregion

#region Sale i zasoby: ustawienia rezerwacji (Calendar Processing)
$script:BookingFields = [ordered]@{
    AutomateProcessing              = 'Przetwarzanie (AutoAccept / AutoUpdate / None)'
    AllowConflicts                  = 'Zezwalaj na konflikty'
    BookingWindowInDays             = 'Okno rezerwacji (dni)'
    MaximumDurationInMinutes        = 'Maks. czas spotkania (min)'
    AllowRecurringMeetings          = 'Spotkania cykliczne'
    EnforceSchedulingHorizon        = 'Odrzucaj cykliczne poza oknem rezerwacji'
    ScheduleOnlyDuringWorkHours     = 'Tylko w godzinach pracy'
    AllBookInPolicy                 = 'Wszyscy mogą rezerwować'
    AllRequestInPolicy              = 'Wszyscy mogą prosić o rezerwację'
    ResourceDelegates               = 'Delegaci (zatwierdzanie)'
    AddOrganizerToSubject           = 'Organizator w temacie'
    DeleteSubject                   = 'Usuwaj temat'
    DeleteComments                  = 'Usuwaj treść zaproszenia'
    RemovePrivateProperty           = 'Usuwaj oznaczenie «prywatne»'
    ProcessExternalMeetingMessages  = 'Przyjmuj zaproszenia z zewnątrz'
    AddAdditionalResponse           = 'Dodatkowa odpowiedź'
    AdditionalResponse              = 'Treść dodatkowej odpowiedzi'
}

function Get-HTRoomBookingSettings {
    param ([Parameter(Mandatory)][string]$Identity)
    $cp = Get-CalendarProcessing -Identity $Identity -ErrorAction Stop
    $place = $null
    try { $place = Get-Place -Identity $Identity -ErrorAction Stop } catch { $place = $null }
    $o = [ordered]@{ Sala = $Identity }
    if ($place) { $o['Pojemność'] = $place.Capacity; $o['Budynek'] = $place.Building; $o['Piętro'] = $place.Floor }
    foreach ($k in $script:BookingFields.Keys) {
        $v = $cp.$k
        $o[$script:BookingFields[$k]] = if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { (@($v | ForEach-Object { "$_" }) -join ', ') } else { $v }
    }
    $o['__settings'] = $cp
    $o['__flag'] = if ("$($cp.AutomateProcessing)" -ne 'AutoAccept') { 'warn' } else { '' }
    return [PSCustomObject]$o
}

function Set-HTRoomBookingSettings {
    # -Settings: nazwy parametrów Set-CalendarProcessing -> wartości (puste listy delegatów czyści)
    param ([Parameter(Mandatory)][string]$Identity, [Parameter(Mandatory)][hashtable]$Settings)
    $params = @{ Identity = $Identity; Confirm = $false; ErrorAction = 'Stop' }
    foreach ($k in $Settings.Keys) { $params[$k] = $Settings[$k] }
    Set-CalendarProcessing @params
}
#endregion

#region Pełny raport dostępu do skrzynki i automapowanie
function Get-HTMailboxAccessReport {
    <#
        Kto ma dostęp do skrzynki: pełny dostęp, wyślij jako, wyślij w imieniu oraz uprawnienia do folderów.
        -Folders: Standard (główny folder, Skrzynka odbiorcza, Kalendarz, Kontakty) albo All (wszystkie foldery - dłużej).
    #>
    param ([Parameter(Mandatory)][string]$Identity, [ValidateSet('None', 'Standard', 'All')][string]$Folders = 'Standard')
    $names = @{ FullAccess = 'Pełny dostęp'; SendAs = 'Wyślij jako'; SendOnBehalf = 'Wyślij w imieniu' }
    foreach ($p in @(Get-HTMailboxPermissions -Identity $Identity)) {
        [PSCustomObject]@{ Rodzaj = $names[$p.Type]; Folder = '(cała skrzynka)'; Użytkownik = $p.User; Prawa = $p.AccessRights; __type = $p.Type; __folder = ''; __flag = $(if ($p.Type -eq 'FullAccess') { 'warn' } else { '' }) }
    }
    if ($Folders -eq 'None') { return }
    $folderPaths = New-Object System.Collections.Generic.List[string]
    $stats = @(Get-EXOMailboxFolderStatistics -Identity $Identity -ErrorAction Stop)
    foreach ($f in $stats) {
        $type = [string]$f.FolderType
        if ($Folders -eq 'Standard' -and $type -notin @('Root', 'Inbox', 'Calendar', 'Contacts')) { continue }
        if ($Folders -eq 'All' -and $type -in @('RecoverableItemsRoot', 'RecoverableItemsDeletions', 'RecoverableItemsPurges', 'RecoverableItemsVersions', 'Audits', 'CalendarLogging', 'SyncIssues', 'Conflicts', 'LocalFailures', 'ServerFailures', 'RecoverableItemsSubstrateHolds', 'RecoverableItemsDiscoveryHolds', 'RecoverableItemsMigratedMessages')) { continue }
        $path = if ($type -eq 'Root') { '\' } else { ([string]$f.FolderPath).Replace('/', '\') }
        if ($path -and -not $folderPaths.Contains($path)) { $folderPaths.Add($path) }
    }
    foreach ($path in $folderPaths) {
        $id = if ($path -eq '\') { "$($Identity):\" } else { "$($Identity):$path" }
        try {
            foreach ($fp in @(Get-EXOMailboxFolderPermission -Identity $id -ErrorAction Stop)) {
                $user = [string]$fp.User
                $rights = @($fp.AccessRights) -join ', '
                if ($user -in 'Default', 'Anonymous' -and $rights -in 'None', 'AvailabilityOnly') { continue }
                [PSCustomObject]@{ Rodzaj = 'Folder'; Folder = $path; Użytkownik = $user; Prawa = $rights; __type = 'Folder'; __folder = $id; __flag = $(if ($user -in 'Default', 'Anonymous') { 'warn' } else { '' }) }
            }
        }
        catch { Write-Log -Message "Uprawnienia folderu $($id): $($_.Exception.Message)" -Type 'Warn' }
    }
}

function Remove-HTMailboxFolderPermissionEntry {
    param ([Parameter(Mandatory)][string]$FolderIdentity, [Parameter(Mandatory)][string]$User)
    Remove-MailboxFolderPermission -Identity $FolderIdentity -User $User -Confirm:$false -ErrorAction Stop
}

function Set-HTMailboxAutoMapping {
    # Automapowanie (dodanie skrzynki w Outlooku) zapisuje się przy nadaniu pełnego dostępu - zmiana: odebranie i ponowne nadanie
    param ([Parameter(Mandatory)][string]$Identity, [Parameter(Mandatory)][string]$User, [Parameter(Mandatory)][bool]$Enabled)
    Remove-MailboxPermission -Identity $Identity -User $User -AccessRights FullAccess -InheritanceType All -Confirm:$false -ErrorAction Stop
    Add-MailboxPermission -Identity $Identity -User $User -AccessRights FullAccess -InheritanceType All -AutoMapping $Enabled -Confirm:$false -ErrorAction Stop | Out-Null
}
#endregion

#region Skrzynki współdzielone a licencje
function Get-HTSharedMailboxAdvice {
    <#
        Zalecenie licencyjne skrzynki współdzielonej: bez licencji do 50 GB; licencja wymagana powyżej 50 GB,
        dla archiwum online i Litigation Hold (Exchange Online Plan 2 / dodatek archiwum).
    #>
    param ([AllowNull()][object]$SizeGB, [bool]$Licensed, [bool]$Archive = $false, [bool]$Hold = $false)
    $size = if ($null -ne $SizeGB -and "$SizeGB" -ne '') { [double]$SizeGB } else { 0 }
    $needs = @()
    if ($size -gt 50) { $needs += 'rozmiar ponad 50 GB' }
    if ($Archive) { $needs += 'archiwum online' }
    if ($Hold) { $needs += 'Litigation Hold' }
    if (-not $Licensed -and $needs.Count) { return @{ Advice = "Wymaga licencji: $($needs -join ', ')"; Flag = 'crit' } }
    if ($Licensed -and -not $needs.Count) { return @{ Advice = 'Licencja prawdopodobnie zbędna (do 50 GB bez archiwum i blokady - bez licencji)'; Flag = 'warn' } }
    if ($Licensed) { return @{ Advice = "Licencja potrzebna ($($needs -join ', '))"; Flag = '' } }
    if ($size -gt 45) { return @{ Advice = 'Blisko limitu 50 GB - zaplanuj licencję lub archiwizację'; Flag = 'warn' } }
    return @{ Advice = 'OK (bez licencji)'; Flag = '' }
}

function Get-HTSharedMailboxLicenseReport {
    # Skrzynki współdzielone: rozmiar, archiwum, blokada i licencje (Microsoft Graph, gdy połączono) z zaleceniem
    param ([scriptblock]$OnProgress)
    $mailboxes = @(Get-EXOMailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited -Properties ArchiveStatus, LitigationHoldEnabled, ExternalDirectoryObjectId -ErrorAction Stop)
    $licenses = @{}
    if ($Global:ConnectedToGraphAPI -and $mailboxes.Count) {
        try {
            $skuNames = Get-HTSkuNameMap
            $batch = Invoke-HTGraphBatch -Requests @($mailboxes | Where-Object { $_.ExternalDirectoryObjectId } | ForEach-Object { @{ Id = [string]$_.ExternalDirectoryObjectId; Url = "users/$($_.ExternalDirectoryObjectId)?`$select=assignedLicenses" } })
            foreach ($k in $batch.Keys) {
                if ($batch[$k].Status -lt 300) { $licenses[$k] = @($batch[$k].Body.assignedLicenses | ForEach-Object { Get-HTSkuFriendlyName ($skuNames["$($_.skuId)"] ?? "$($_.skuId)") }) }
            }
        }
        catch { Write-Log -Message "Licencje skrzynek współdzielonych (Graph): $($_.Exception.Message)" -Type 'Warn' }
    }
    $i = 0
    foreach ($mbx in $mailboxes) {
        $i++
        if ($OnProgress) { & $OnProgress $i $mailboxes.Count $mbx.DisplayName }
        $size = $null
        try { $size = ConvertFrom-HTExchangeSize (Get-EXOMailboxStatistics -Identity "$($mbx.PrimarySmtpAddress)" -ErrorAction Stop).TotalItemSize } catch { Write-Log -Message "Rozmiar $($mbx.PrimarySmtpAddress): $($_.Exception.Message)" -Type 'Warn' }
        $sizeGB = if ($null -ne $size) { [Math]::Round($size / 1GB, 2) } else { $null }
        $known = $licenses.ContainsKey([string]$mbx.ExternalDirectoryObjectId)
        $lic = if ($known) { @($licenses[[string]$mbx.ExternalDirectoryObjectId]) } else { @() }
        $advice = Get-HTSharedMailboxAdvice -SizeGB $sizeGB -Licensed ($lic.Count -gt 0) -Archive ("$($mbx.ArchiveStatus)" -eq 'Active') -Hold ([bool]$mbx.LitigationHoldEnabled)
        [PSCustomObject]@{
            Skrzynka          = $mbx.DisplayName
            Adres             = "$($mbx.PrimarySmtpAddress)"
            'Rozmiar (GB)'    = $sizeGB
            Archiwum          = ("$($mbx.ArchiveStatus)" -eq 'Active')
            'Litigation Hold' = [bool]$mbx.LitigationHoldEnabled
            Licencje          = $(if ($known) { $lic -join ', ' } else { '(połącz z Microsoft 365)' })
            Zalecenie         = $advice.Advice
            Id                = [string]$mbx.ExternalDirectoryObjectId
            __flag            = $advice.Flag
        }
    }
}
#endregion
