<#
.SYNOPSIS
    Helpdesk Tools bez okna: raporty e-mailem, zadania zaplanowane i migawki konfiguracji (np. z Harmonogramu Windows).
.DESCRIPTION
    Logowanie aplikacji automatyzacji certyfikatem (bez użytkownika): Client ID, Tenant ID i odcisk certyfikatu z Ustawień
    (Automatyzacja i Defender) albo z parametrów. Aplikację tworzy przestrzeń «Zadania» > Raporty zaplanowane.
    Wyniki trafiają do dziennika programu (%LOCALAPPDATA%\HelpdeskTools\Logs).
.PARAMETER Report
    Raporty (nazwy rozdzielone przecinkiem), np. nieaktywni,sekrety-aplikacji. Lista: -ListReports.
.PARAMETER To
    Odbiorcy raportów (adresy rozdzielone przecinkiem). Nadawca - skrzynka z Ustawień (ReportSender).
.PARAMETER RunJobs
    Wykonuje zadania zaplanowane (uprawnienia tymczasowe, zaplanowany offboarding), których termin minął.
.PARAMETER Snapshot
    Migawki (rodzaje rozdzielone przecinkiem, np. AdminRoles,ConditionalAccess); zmiany od poprzedniej migawki trafiają do raportu.
.EXAMPLE
    pwsh -File .\HelpdeskToolsRunner.ps1 -Report nieaktywni,administratorzy -To helpdesk@firma.pl
.EXAMPLE
    pwsh -File .\HelpdeskToolsRunner.ps1 -RunJobs -Snapshot AdminRoles,ConditionalAccess -To bezpieczenstwo@firma.pl
.NOTES
    Copyright (c) 2025-2026 Borys Kaleta. Wszelkie prawa zastrzeżone.
    Korzystanie z programu wymaga zgody autora - zob. plik LICENSE.
#>

#Requires -Version 7

param (
    [string]$Report = '',
    [string]$To = '',
    [switch]$RunJobs,
    [string]$Snapshot = '',
    [ValidateSet('xlsx', 'html', 'csv')][string]$Format = 'xlsx',
    [string]$ClientId = '',
    [string]$TenantId = '',
    [string]$CertificateThumbprint = '',
    [string]$Organization = '',
    [string]$From = '',
    [switch]$ListReports
)

$ErrorActionPreference = 'Stop'
$Global:AppVersion = ([regex]::Match((Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'HelpdeskTools.ps1')), '\$Global:AppVersion\s*=\s*"([\d\.]+)"')).Groups[1].Value
$Global:HTScriptPath = Join-Path $PSScriptRoot 'HelpdeskTools.ps1'
$Global:ConfigDir = Join-Path -Path $env:APPDATA -ChildPath 'HelpdeskTools'
$Global:LogDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'HelpdeskTools\Logs'
$Global:ConfigPath = Join-Path -Path $Global:ConfigDir -ChildPath 'config.json'
$Global:ConnectedToGraphAPI = $false
$Global:ConnectedToExchange = $false
$Global:ConnectedToSharepointPnP = $false
$Global:ShowNotifications = $false
$Global:HTActiveAccount = 'automatyzacja'

foreach ($name in 'Utils', 'Security', 'Config', 'Reports', 'Excel', 'Integrations', 'Automation', 'ModulesConnection', 'PasswordGenerator', 'GraphAPIM365Users',
    'GraphAPISecurity', 'GraphAPITeams', 'MailboxesExchangeOnline', 'GraphAPIIntune', 'GraphAPISharePoint', 'SharePointAudit', 'AccountBackup') {
    Import-Module (Join-Path $PSScriptRoot "Modules/$name.psm1") -Force -Global -DisableNameChecking
}
# Moduły PowerShell w OneDrive bez lokalnej kopii plików - folder pomijany (moduły z C:\Program Files\PowerShell\Modules)
try { Repair-HTModulePath | Out-Null } catch { Write-Log -Message "Sprawdzenie folderów modułów: $($_.Exception.Message)" -Type 'Warn' }

if ($ListReports) {
    foreach ($k in (Get-HTHeadlessReports).Keys) { $d = (Get-HTHeadlessReports)[$k]; '{0,-26} {1} ({2})' -f $k, $d.Title, $d.Service }
    ''
    'Migawki: ' + ((Get-HTSnapshotDefinitions).Keys -join ', ')
    return
}

$config = Get-HTConfig -Path $Global:ConfigPath
if ($config) { Apply-HTConfig -Config $config }
$cfg = $Global:HTConfig
if (-not $ClientId) { $ClientId = [string]$cfg.AutomationClientId }
if (-not $TenantId) { $TenantId = [string]$cfg.AutomationTenantId }
if (-not $CertificateThumbprint) { $CertificateThumbprint = [string]$cfg.AutomationCertificateThumbprint }
if (-not $Organization) { $Organization = [string]$cfg.AutomationOrganization }
if (-not $From) { $From = [string]$cfg.ReportSender }

$reports = @($Report -split '[,;\s]+' | Where-Object { $_ })
$snapshots = @($Snapshot -split '[,;\s]+' | Where-Object { $_ })
$recipients = @($To -split '[,;\s]+' | Where-Object { $_ })
$exitCode = 0
Write-Log -Message "Helpdesk Tools (bez okna) $($Global:AppVersion): raporty: $($reports -join ', '); zadania: $([bool]$RunJobs); migawki: $($snapshots -join ', ')" -Type 'Info'

try {
    if (-not $ClientId -or -not $TenantId -or -not $CertificateThumbprint) { throw 'Brak danych aplikacji automatyzacji (Client ID, Tenant ID, odcisk certyfikatu) - Ustawienia > Automatyzacja i Defender albo parametry skryptu.' }
    foreach ($r in $reports) { if (-not (Get-HTHeadlessReports).Contains($r)) { throw "Nieznany raport: $r (lista: -ListReports)" } }
    foreach ($s in $snapshots) { if (-not (Get-HTSnapshotDefinitions).Contains($s)) { throw "Nieznany rodzaj migawki: $s" } }

    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Connect-MgGraph -ClientId $ClientId -TenantId $TenantId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
    $Global:ConnectedToGraphAPI = $true
    Write-Log -Message "Połączono z Microsoft Graph jako aplikacja $ClientId." -Type 'Info'

    $needsExchange = @($reports | Where-Object { (Get-HTHeadlessReports)[$_].Service -eq 'Exchange' }).Count -gt 0 -or
        @($snapshots | Where-Object { (Get-HTSnapshotDefinitions)[$_].Service -eq 'Exchange' }).Count -gt 0 -or
        ($RunJobs -and @(Get-HTDueJobs | Where-Object { $_.Type -eq 'RemoveMailboxPermission' -or ($_.Type -eq 'Offboarding' -and ($_.Data.Steps.Shared -or $_.Data.Steps.Hide -or $_.Data.Steps.AutoReply -or $_.Data.Steps.Forward)) }).Count -gt 0)
    if ($needsExchange) {
        if (-not $Organization) { throw 'Raport lub zadanie wymaga Exchange Online - ustaw domenę organizacji (AutomationOrganization).' }
        Import-Module ExchangeOnlineManagement -ErrorAction Stop
        Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false -ErrorAction Stop
        $Global:ConnectedToExchange = $true
        Write-Log -Message "Połączono z Exchange Online ($Organization) jako aplikacja." -Type 'Info'
    }

    $attachments = New-Object System.Collections.Generic.List[object]
    $summary = New-Object System.Collections.Generic.List[string]

    if ($RunJobs) {
        $spConnection = $null
        $oneDriveJobs = @(Get-HTDueJobs | Where-Object { $_.Type -eq 'RevokeOneDriveAccess' })
        foreach ($job in $oneDriveJobs) {
            # Odebranie dostępu do OneDrive - połączenie PnP aplikacją z certyfikatem (uprawnienie Sites.FullControl.All dla SharePoint)
            try {
                Import-Module PnP.PowerShell -ErrorAction Stop
                $spConnection = Connect-PnPOnline -Url $job.Data.SiteUrl -ClientId $ClientId -Tenant $Organization -Thumbprint $CertificateThumbprint -ReturnConnection -ErrorAction Stop
                $result = Invoke-HTJob -Job $job -SharePointConnection $spConnection
                Update-HTJob -Id $job.Id -Changes @{ Status = 'Wykonane'; Executed = (Get-Date).ToString('o'); Result = [string]$result }
                $summary.Add("Zadanie: odebranie dostępu do OneDrive ($($job.Object)) - OK")
            }
            catch {
                Update-HTJob -Id $job.Id -Changes @{ Status = 'Błąd'; Executed = (Get-Date).ToString('o'); Result = $_.Exception.Message }
                $summary.Add("Zadanie: odebranie dostępu do OneDrive ($($job.Object)) - błąd: $($_.Exception.Message)")
                $exitCode = 2
            }
        }
        $jobResults = @(Invoke-HTDueJobs | Where-Object { $_ })
        foreach ($j in $jobResults) {
            $summary.Add("Zadanie: $($j.Zadanie) ($($j.Obiekt)) - $($j.Status): $($j.Wynik)")
            if ($j.Status -eq 'Błąd') { $exitCode = 2 }
        }
        if (-not $jobResults.Count -and -not $oneDriveJobs.Count) { $summary.Add('Zadania zaplanowane: brak zadań do wykonania.') }
    }

    foreach ($kind in $snapshots) {
        $def = (Get-HTSnapshotDefinitions)[$kind]
        $previous = @(Get-HTSnapshots -Kind $kind)[0]
        $records = @(Get-HTSnapshotRecords -Kind $kind)
        [void](New-HTSnapshot -Kind $kind -Records $records)
        if ($previous) {
            $old = @((Read-HTSnapshot -Path $previous.Ścieżka).Records)
            $changes = @(Compare-HTSnapshot -Old $old -New $records)
            $summary.Add("Migawka «$($def.Title)»: zmian od $($previous.Data.ToString('yyyy-MM-dd HH:mm')): $($changes.Count)")
            if ($changes.Count) {
                $rows = @($changes | ForEach-Object { [ordered]@{ Zmiana = $_.Zmiana; Obiekt = $_.Obiekt; Szczegóły = $_.Szczegóły; __flag = $_.__flag } })
                $reports += "__snapshot_$kind"
                Set-Variable -Name "snapshot_$kind" -Value @{ Title = "Zmiany: $($def.Title)"; Columns = @('Zmiana', 'Obiekt', 'Szczegóły'); Rows = $rows }
            }
        }
        else { $summary.Add("Migawka «$($def.Title)»: pierwsza migawka ($($records.Count) rekordów) - zmiany pojawią się przy kolejnym uruchomieniu.") }
    }

    foreach ($name in $reports) {
        $data = if ($name -like '__snapshot_*') { Get-Variable -Name ($name -replace '^__', '') -ValueOnly } else { Invoke-HTHeadlessReport -Name $name }
        $summary.Add("$($data.Title): wierszy $(@($data.Rows).Count)")
        if (-not $recipients.Count) { continue }
        $safe = ($data.Title -replace '[^\w\-]+', '_')
        $meta = [ordered]@{ Raport = $data.Title; Data = (Get-Date).ToString('yyyy-MM-dd HH:mm'); Wiersze = @($data.Rows).Count; Program = "Helpdesk Tools $($Global:AppVersion) (bez okna)" }
        switch ($Format) {
            'html' {
                $html = ConvertTo-HTHtmlReport -Title $data.Title -Columns $data.Columns -Rows $data.Rows -Meta ("Helpdesk Tools $($Global:AppVersion) • $((Get-Date).ToString('yyyy-MM-dd HH:mm'))")
                $attachments.Add((New-HTMailAttachment -Name "$safe.html" -Bytes ([System.Text.Encoding]::UTF8.GetPreamble() + [System.Text.Encoding]::UTF8.GetBytes($html)) -ContentType 'text/html'))
            }
            'csv' {
                $csv = (@($data.Rows | ForEach-Object { $o = [ordered]@{}; foreach ($c in $data.Columns) { $o[$c] = [string]$_[$c] }; [PSCustomObject]$o }) | ConvertTo-Csv -NoTypeInformation -Delimiter ';') -join "`r`n"
                $attachments.Add((New-HTMailAttachment -Name "$safe.csv" -Bytes ([System.Text.Encoding]::UTF8.GetPreamble() + [System.Text.Encoding]::UTF8.GetBytes($csv)) -ContentType 'text/csv'))
            }
            default {
                $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("HelpdeskTools_" + [guid]::NewGuid().ToString('N') + '.xlsx')
                try {
                    [void](Export-HTXlsx -Path $tmp -Columns $data.Columns -Rows $data.Rows -SheetName $data.Title -Meta $meta)
                    $attachments.Add((New-HTMailAttachment -Name "$safe.xlsx" -Bytes ([System.IO.File]::ReadAllBytes($tmp)) -ContentType 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'))
                }
                finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    foreach ($line in $summary) { Write-Log -Message $line -Type 'Info' }
    if ($recipients.Count -and ($attachments.Count -or $summary.Count)) {
        if (-not $From) { throw 'Brak skrzynki nadawcy raportów (Ustawienia > Teams i e-mail: skrzynka nadawcy raportów zaplanowanych).' }
        $list = (@($summary | ForEach-Object { '<li>' + (ConvertTo-HTHtmlText $_) + '</li>' }) -join '')
        $body = "<div style=`"font:14px Segoe UI,sans-serif`"><p><b>Helpdesk Tools - raport automatyczny</b> ($((Get-Date).ToString('yyyy-MM-dd HH:mm')))</p><ul>$list</ul><p style=`"color:#666`">Szczegóły w załącznikach. Wiadomość wygenerowana automatycznie.</p></div>"
        # Duże raporty - osobne wiadomości (limit ok. 3 MB na wiadomość)
        $batch = New-Object System.Collections.Generic.List[object]
        $size = 0
        $part = 0
        $send = {
            if (-not $batch.Count -and $part -gt 0) { return }
            Send-HTGraphMail -To $recipients -From $From -Subject "Helpdesk Tools - raporty $((Get-Date).ToString('yyyy-MM-dd'))$(if ($part -gt 0) { " (część $($part + 1))" })" -HtmlBody $body -Attachments $batch.ToArray()
        }
        foreach ($a in $attachments) {
            if ($batch.Count -and ($size + $a.Bytes.Length) -gt 2.8MB) { . $send; $part++; $batch.Clear(); $size = 0 }
            $batch.Add($a)
            $size += $a.Bytes.Length
        }
        . $send
        Write-Log -Message "Wysłano raporty do: $($recipients -join ', ')" -Type 'Info'
    }
}
catch {
    Write-Log -Message "Helpdesk Tools (bez okna) - błąd: $($_.Exception.Message)" -Type 'Error'
    Write-Error $_.Exception.Message -ErrorAction Continue
    $exitCode = 1
}
finally {
    try { if ($Global:ConnectedToExchange) { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue } } catch { Write-Verbose $_ }
    try { if ($Global:ConnectedToGraphAPI) { Disconnect-MgGraph -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null } } catch { Write-Verbose $_ }
}
exit $exitCode
