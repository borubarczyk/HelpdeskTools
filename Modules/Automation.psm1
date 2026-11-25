# Automatyzacja i historia pracy: dziennik operacji sesji (podsumowanie do zgłoszenia), zadania zaplanowane
# (uprawnienia tymczasowe, zaplanowany offboarding), checklisty, migawki i porównanie, cofanie zmian.
# Pliki danych w katalogu konfiguracji: Jobs.json, Checklists.json, Undo.json, Snapshots\<rodzaj>\*.json.
# Moduł nie zależy od interfejsu.

#region Dziennik operacji (zmiany i sprawdzenia wykonane w tej sesji)
$script:Operations = New-Object System.Collections.Generic.List[object]

function Add-HTOperationRecord {
    <#
        Wpis po operacji: -Kind Change (domyślnie) - zmiana (Invoke-HTTargetAction, Invoke-HTRowAction, offboarding,
        zadania), -Kind Check - sprawdzenie (zapytania i «Sprawdź stan»: co sprawdzono i z jakim wynikiem).
        Powtórzone sprawdzenie (ta sama operacja i obiekt zaraz po poprzednim) zastępuje poprzedni wpis.
    #>
    param (
        [Parameter(Mandatory)][string]$Operation,
        [AllowEmptyString()][string]$Object = '',
        [string]$Status = 'OK',
        [AllowEmptyString()][AllowNull()][string]$Details = '',
        [string]$Module = '',
        [ValidateSet('Change', 'Check')][string]$Kind = 'Change'
    )
    $record = [PSCustomObject]@{
        Time      = Get-Date
        Operation = $Operation
        Object    = $Object
        Status    = $Status
        Details   = [string]$Details
        Module    = $Module
        Account   = [string]$Global:HTActiveAccount
        Kind      = $Kind
    }
    $last = if ($script:Operations.Count) { $script:Operations[$script:Operations.Count - 1] } else { $null }
    if ($Kind -eq 'Check' -and $last -and $last.Kind -eq 'Check' -and $last.Operation -eq $Operation -and $last.Object -eq $Object -and $last.Module -eq $Module) {
        $script:Operations[$script:Operations.Count - 1] = $record
        return
    }
    $script:Operations.Add($record)
    if ($script:Operations.Count -gt 5000) { $script:Operations.RemoveRange(0, 1000) }
}

function Get-HTOperationKind {
    # Rodzaj wpisu (wpisy bez rodzaju - zmiany)
    param ($Record)
    if ($Record -and $Record.PSObject.Properties['Kind'] -and $Record.Kind) { return [string]$Record.Kind }
    return 'Change'
}

function Get-HTOperationRecords {
    # -Object: fragment nazwy obiektu albo operacji (bez rozróżniania wielkości liter); -Kind: Change / Check (puste - wszystkie)
    param ([string]$Object = '', [datetime]$Since = [datetime]::MinValue, [ValidateSet('', 'Change', 'Check')][string]$Kind = '')
    return @($script:Operations | Where-Object {
            $_.Time -ge $Since -and (-not $Kind -or (Get-HTOperationKind $_) -eq $Kind) -and
            (-not $Object -or $_.Object.IndexOf($Object, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or $_.Operation.IndexOf($Object, [StringComparison]::OrdinalIgnoreCase) -ge 0)
        })
}

function Clear-HTOperationRecords { $script:Operations.Clear() }

function Format-HTOperationSummary {
    # Tekst do zgłoszenia (ticketu): data, sprawdzenia (co i z jakim wynikiem), wykonane zmiany, obiekty i wyniki
    param ([AllowEmptyCollection()][object[]]$Records = @(), [string]$Title = '')
    $lines = New-Object System.Collections.Generic.List[string]
    $heading = if ($Title) { $Title } else { 'Wykonane czynności' }
    $lines.Add("$heading (Helpdesk Tools, $((Get-Date).ToString('yyyy-MM-dd')), $env:USERNAME$(if ($Global:HTActiveAccount) { " / $($Global:HTActiveAccount)" }))")
    if (@($Records).Count -eq 0) { $lines.Add('- brak operacji'); return ($lines -join "`r`n") }
    $checks = @($Records | Where-Object { (Get-HTOperationKind $_) -eq 'Check' })
    $changes = @($Records | Where-Object { (Get-HTOperationKind $_) -ne 'Check' })
    if ($checks.Count) {
        $lines.Add('')
        $lines.Add('Sprawdzenia:')
        foreach ($r in $checks) {
            $scope = if ($r.Object) { " ($($r.Object))" } else { '' }
            $result = if ($r.Status -eq 'OK') { $r.Details } elseif ($r.Details) { "$("$($r.Status)".ToLowerInvariant()) - $($r.Details)" } else { "$($r.Status)".ToLowerInvariant() }
            $lines.Add(("  - {0:HH:mm} {1}{2}: {3}" -f $r.Time, $r.Operation, $scope, $result))
        }
        $lines.Add('')
        $lines.Add('Zmiany:')
        if (-not $changes.Count) { $lines.Add('  - brak zmian') }
    }
    foreach ($group in @($changes | Group-Object Operation)) {
        $lines.Add('')
        $lines.Add("$($group.Name):")
        foreach ($r in $group.Group) {
            $result = if ($r.Status -eq 'OK') { 'wykonano' } else { "$($r.Status)".ToLowerInvariant() }
            $detail = if ($r.Details) { " - $($r.Details)" } else { '' }
            $lines.Add(("  - {0:HH:mm} {1}: {2}{3}" -f $r.Time, $r.Object, $result, $detail))
        }
    }
    $failed = @($changes | Where-Object { $_.Status -ne 'OK' -and $_.Status -notlike 'Pominięto*' }).Count
    $lines.Add('')
    if ($checks.Count) { $lines.Add("Razem: zmian: $($changes.Count)$(if ($failed) { " (w tym z błędem: $failed)" }), sprawdzeń: $($checks.Count).") }
    else { $lines.Add("Razem: $($changes.Count) operacji$(if ($failed) { ", w tym z błędem: $failed" }).") }
    return ($lines -join "`r`n")
}
#endregion

#region Pliki danych (JSON w katalogu konfiguracji)
function Get-HTAutomationFile {
    param ([Parameter(Mandatory)][string]$Name)
    $dir = if ($Global:ConfigDir) { $Global:ConfigDir } else { Join-Path ([System.IO.Path]::GetTempPath()) 'HelpdeskTools' }
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return (Join-Path $dir $Name)
}

function Read-HTJsonList {
    # Lista obiektów z pliku JSON (słowniki); brak pliku albo błąd - pusta lista
    param ([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    try {
        $raw = [System.IO.File]::ReadAllText($Path)
        if (-not $raw.Trim()) { return @() }
        return @(ConvertFrom-Json -InputObject $raw -AsHashtable -ErrorAction Stop | Where-Object { $_ })
    }
    catch {
        Write-Log -Message "Nie odczytano pliku $($Path): $($_.Exception.Message)" -Type 'Warn'
        return @()
    }
}

function Write-HTJsonList {
    param ([Parameter(Mandatory)][string]$Path, [AllowEmptyCollection()][object[]]$Items = @())
    $tmp = "$Path.tmp"
    [System.IO.File]::WriteAllText($tmp, (ConvertTo-Json -InputObject @($Items) -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}
#endregion

#region Zadania zaplanowane: uprawnienia tymczasowe, zaplanowany offboarding
<#
    Zadanie: @{ Id; Type; RunAt (ISO 8601); Object; Description; Data; Status; Created; CreatedBy; Executed; Result }.
    Typy: RemoveGroupMember (Data: GroupId, GroupName, UserId, UserLabel), RemoveMailboxPermission (Identity, User, Type),
    RevokeOneDriveAccess (SiteUrl, Users), Offboarding (UserId, Label, Steps). Wykonuje je program (co minutę, gdy jest
    uruchomiony i połączony z usługą) albo HelpdeskToolsRunner.ps1 -RunJobs (zadanie Harmonogramu Windows).
#>
$script:JobTypes = [ordered]@{
    RemoveGroupMember       = @{ Title = 'Usunięcie z grupy'; Services = @('Graph') }
    RemoveMailboxPermission = @{ Title = 'Odebranie uprawnień do skrzynki'; Services = @('Exchange') }
    RevokeOneDriveAccess    = @{ Title = 'Odebranie dostępu do OneDrive'; Services = @('SharePoint') }
    Offboarding             = @{ Title = 'Zaplanowany offboarding'; Services = @('Graph') }
}

function Get-HTJobTypes { return $script:JobTypes }

function Get-HTJobs {
    param ([switch]$Pending)
    $jobs = @(Read-HTJsonList -Path (Get-HTAutomationFile 'Jobs.json'))
    if ($Pending) { return @($jobs | Where-Object { $_.Status -in 'Zaplanowane', 'Oczekuje na połączenie' }) }
    return $jobs
}

function Save-HTJobs {
    param ([AllowEmptyCollection()][object[]]$Jobs = @())
    # Zakończone zadania starsze niż 90 dni nie są przechowywane
    $limit = (Get-Date).AddDays(-90)
    $keep = @($Jobs | Where-Object { $_.Status -in 'Zaplanowane', 'Oczekuje na połączenie' -or -not $_.Executed -or ([datetime]$_.Executed) -gt $limit })
    Write-HTJsonList -Path (Get-HTAutomationFile 'Jobs.json') -Items $keep
}

function New-HTScheduledJob {
    param (
        [Parameter(Mandatory)][ValidateScript({ $script:JobTypes.Contains($_) })][string]$Type,
        [Parameter(Mandatory)][datetime]$RunAt,
        [string]$Object = '',
        [string]$Description = '',
        [hashtable]$Data = @{}
    )
    $job = [ordered]@{
        Id = [guid]::NewGuid().ToString('N'); Type = $Type; RunAt = $RunAt.ToString('o'); Object = $Object; Description = $Description; Data = $Data
        Status = 'Zaplanowane'; Created = (Get-Date).ToString('o'); CreatedBy = "$env:USERNAME$(if ($Global:HTActiveAccount) { " ($($Global:HTActiveAccount))" })"; Executed = $null; Result = ''
    }
    $jobs = @(Get-HTJobs) + @($job)
    Save-HTJobs -Jobs $jobs
    Write-Log -Message "Zaplanowano zadanie: $($script:JobTypes[$Type].Title) - $Object ($($RunAt.ToString('yyyy-MM-dd HH:mm')))" -Type 'Info'
    return $job
}

function Update-HTJob {
    param ([Parameter(Mandatory)][string]$Id, [hashtable]$Changes = @{})
    $jobs = @(Get-HTJobs)
    foreach ($j in $jobs) { if ($j.Id -eq $Id) { foreach ($k in $Changes.Keys) { $j[$k] = $Changes[$k] } } }
    Save-HTJobs -Jobs $jobs
}

function Remove-HTJob {
    param ([Parameter(Mandatory)][string]$Id)
    Save-HTJobs -Jobs @(Get-HTJobs | Where-Object { $_.Id -ne $Id })
}

function Get-HTDueJobs {
    # Zadania, których termin minął (do wykonania)
    param ([datetime]$Now = (Get-Date))
    return @(Get-HTJobs -Pending | Where-Object { [datetime]$_.RunAt -le $Now } | Sort-Object { [datetime]$_.RunAt })
}

function Get-HTJobMissingServices {
    # Usługi wymagane przez zadanie, z którymi nie ma połączenia
    param ([Parameter(Mandatory)]$Job)
    $needed = @($script:JobTypes[[string]$Job.Type].Services)
    if ($Job.Type -eq 'Offboarding' -and ($Job.Data.Steps.Shared -or $Job.Data.Steps.Hide -or $Job.Data.Steps.AutoReply -or $Job.Data.Steps.Forward)) { $needed += 'Exchange' }
    return @($needed | Where-Object {
            switch ($_) {
                'Graph' { -not $Global:ConnectedToGraphAPI }
                'Exchange' { -not $Global:ConnectedToExchange }
                'SharePoint' { $false }
                default { $false }
            }
        })
}

function Invoke-HTJob {
    # Wykonanie zadania; zwraca opis wyniku (wyjątek - błąd zadania)
    param ([Parameter(Mandatory)]$Job, $SharePointConnection = $null)
    $d = $Job.Data
    switch ($Job.Type) {
        'RemoveGroupMember' {
            try { Invoke-HTGraphRequest -Uri "groups/$($d.GroupId)/members/$($d.UserId)/`$ref" -Method DELETE | Out-Null }
            catch { if ("$($_.Exception.Message)" -notmatch 'does not exist|NotFound|404') { throw } }
            return "Usunięto $($d.UserLabel) z grupy $($d.GroupName)"
        }
        'RemoveMailboxPermission' {
            foreach ($t in @($d.Type)) { Remove-HTMailboxPermission -Identity $d.Identity -User $d.User -Type $t }
            return "Odebrano $(@($d.Type) -join ', ') dla $($d.User) do $($d.Identity)"
        }
        'RevokeOneDriveAccess' {
            Revoke-HTOneDriveAccess -SiteUrl $d.SiteUrl -Users @($d.Users) -SiteConnection $SharePointConnection
            return "Odebrano dostęp $(@($d.Users) -join ', ') do $($d.SiteUrl)"
        }
        'Offboarding' {
            $s = $d.Steps
            $done = New-Object System.Collections.Generic.List[string]
            $upn = [string]$d.Label
            # Kopia ustawień konta przed zmianami (do przywrócenia konta) - bez kopii zadanie kończy się błędem, konto bez zmian
            if ($s.Backup) {
                if (-not (Get-Command -Name Save-HTAccountBackup -ErrorAction Ignore)) { throw 'Brak modułu kopii kont (AccountBackup) - konto bez zmian.' }
                try {
                    $backup = Get-HTM365AccountBackup -Id $d.UserId
                    if ($Global:ConnectedToExchange) { try { $backup.Mailbox = Get-HTMailboxBackupInfo -Identity $upn } catch { $backup.MailboxError = $_.Exception.Message } }
                    $path = Save-HTAccountBackup -Backup $backup
                }
                catch { throw "Nie zapisano kopii ustawień konta - konto bez zmian: $($_.Exception.Message)" }
                $done.Add("kopia ustawień ($path)")
            }
            if ($s.Block) { Set-HTM365UserEnabled -Id $d.UserId -Enabled $false -RevokeSessions $true; $done.Add('blokada i wylogowanie') }
            if ($s.Password) { $pw = New-Password -Length 20 -StartWithLetter $true -NoSimilarChars $true; Reset-HTM365UserPassword -Id $d.UserId -Password $pw -ForceChange $true; $done.Add('losowe hasło') }
            if ($Global:ConnectedToExchange) {
                if ($s.AutoReply) { Set-HTMailboxAutoReply -Identity $upn -State Enabled -InternalMessage $s.AutoReply -ExternalMessage $s.AutoReply -ExternalAudience All; $done.Add('autoodpowiedź') }
                if ($s.Forward) { Set-HTMailboxForwarding -Identity $upn -ForwardTo $s.Forward -KeepCopy $true; $done.Add("przekierowanie do $($s.Forward)") }
                if ($s.Shared) { Convert-HTMailboxType -Identity $upn -Type Shared; $done.Add('skrzynka współdzielona') }
                if ($s.Hide) { Set-HTMailboxHiddenFromGAL -Identity $upn -Hidden $true; $done.Add('ukrycie w GAL') }
            }
            if ($s.Groups) {
                $removed = 0
                foreach ($g in @(Get-HTM365UserGroups -Id $d.UserId)) {
                    if (-not (Test-HTM365GroupManageable -Group $g)) { continue }
                    if ($g.Type -in 'Dystrybucyjna', 'Zabezpieczeń (mail)' -and -not $Global:ConnectedToExchange) { continue }
                    try { Remove-HTM365UserFromGroup -Group $g -User ([PSCustomObject]@{ Id = $d.UserId; UserPrincipalName = $upn }); $removed++ } catch { Write-Log -Message "Zaplanowany offboarding $upn - grupa $($g.DisplayName): $($_.Exception.Message)" -Type 'Warn' }
                }
                $done.Add("usunięto z grup: $removed")
            }
            if ($s.Licenses) {
                $ids = @(Get-HTM365UserLicenses -Id $d.UserId | ForEach-Object { "$($_.SkuId)" })
                if ($ids.Count) { Set-HTM365UserLicense -Id $d.UserId -RemoveSkuIds $ids; $done.Add("usunięto licencji: $($ids.Count)") }
            }
            return ($done -join ', ')
        }
        default { throw "Nieznany typ zadania: $($Job.Type)" }
    }
}

function Invoke-HTDueJobs {
    # Wykonanie zadań, których termin minął (zwraca wyniki); zadania bez wymaganego połączenia czekają
    param ([datetime]$Now = (Get-Date), $SharePointConnection = $null, [string[]]$ExcludeType = @())
    foreach ($job in @(Get-HTDueJobs -Now $Now | Where-Object { $ExcludeType -notcontains $_.Type })) {
        $missing = @(Get-HTJobMissingServices -Job $job)
        if ($missing.Count) {
            if ($job.Status -ne 'Oczekuje na połączenie') { Update-HTJob -Id $job.Id -Changes @{ Status = 'Oczekuje na połączenie'; Result = "Brak połączenia: $($missing -join ', ')" } }
            [PSCustomObject]@{ Id = $job.Id; Zadanie = $script:JobTypes[[string]$job.Type].Title; Obiekt = $job.Object; Status = 'Oczekuje'; Wynik = "Brak połączenia: $($missing -join ', ')" }
            continue
        }
        $title = $script:JobTypes[[string]$job.Type].Title
        try {
            $result = Invoke-HTJob -Job $job -SharePointConnection $SharePointConnection
            Update-HTJob -Id $job.Id -Changes @{ Status = 'Wykonane'; Executed = (Get-Date).ToString('o'); Result = [string]$result }
            Add-HTOperationRecord -Operation "Zadanie: $title" -Object $job.Object -Details $result -Module 'Zadania'
            Write-Log -Message "Wykonano zadanie «$title» ($($job.Object)): $result" -Type 'Info&Notification'
            [void](Send-HTTeamsMessage -Event 'Jobs' -Title "Wykonano zadanie: $title" -Text ([string]$job.Description) -Tone 'ok' -Facts ([ordered]@{ Obiekt = $job.Object; Wynik = $result; Zaplanował = $job.CreatedBy }))
            [PSCustomObject]@{ Id = $job.Id; Zadanie = $title; Obiekt = $job.Object; Status = 'OK'; Wynik = $result }
        }
        catch {
            $message = $_.Exception.Message
            Update-HTJob -Id $job.Id -Changes @{ Status = 'Błąd'; Executed = (Get-Date).ToString('o'); Result = $message }
            Add-HTOperationRecord -Operation "Zadanie: $title" -Object $job.Object -Status 'Błąd' -Details $message -Module 'Zadania'
            Write-Log -Message "Zadanie «$title» ($($job.Object)) - błąd: $message" -Type 'Error&Notification'
            [void](Send-HTTeamsMessage -Event 'Jobs' -Title "Błąd zadania: $title" -Text ([string]$job.Description) -Tone 'crit' -Facts ([ordered]@{ Obiekt = $job.Object; Błąd = $message }))
            [PSCustomObject]@{ Id = $job.Id; Zadanie = $title; Obiekt = $job.Object; Status = 'Błąd'; Wynik = $message }
        }
    }
}
#endregion

#region Checklisty on/offboardingu
<#
    Szablon: @{ Id; Name; Kind; Steps = @(@{ Text; Auto }) }; Auto - krok wykonywany przez program dla konta Microsoft 365
    (Block, RevokeSessions, ResetPassword, RemoveGroups, RemoveLicenses, ConvertShared, HideGAL) albo pusty (krok ręczny).
    Checklista: @{ Id; Template; Kind; Subject; SubjectId; Created; CreatedBy; Due; Steps = @(@{ Text; Auto; Done; DoneAt; DoneBy; Note }); Completed }.
#>
$script:ChecklistAutoSteps = [ordered]@{
    Block          = 'Blokada logowania'
    RevokeSessions = 'Unieważnienie sesji'
    ResetPassword  = 'Losowe hasło'
    RemoveGroups   = 'Usunięcie z grup'
    RemoveLicenses = 'Usunięcie licencji'
    ConvertShared  = 'Konwersja skrzynki na współdzieloną'
    HideGAL        = 'Ukrycie w książce adresowej'
}

function Get-HTChecklistAutoSteps { return $script:ChecklistAutoSteps }

function Get-HTDefaultChecklistTemplates {
    return @(
        [ordered]@{ Id = 'onboarding'; Name = 'Onboarding - nowy pracownik'; Kind = 'Onboarding'; Steps = @(
                @{ Text = 'Konto Microsoft 365 utworzone (dane, przełożony, lokalizacja użycia)'; Auto = '' }
                @{ Text = 'Licencja przypisana'; Auto = '' }
                @{ Text = 'Grupy i zespoły działu'; Auto = '' }
                @{ Text = 'Skrzynki współdzielone i kalendarze'; Auto = '' }
                @{ Text = 'Komputer przygotowany (Autopilot / Intune)'; Auto = '' }
                @{ Text = 'Telefon i MFA (Authenticator) skonfigurowane'; Auto = '' }
                @{ Text = 'Dostępy do systemów dziedzinowych'; Auto = '' }
                @{ Text = 'Przekazanie haseł i instrukcji pierwszego logowania'; Auto = '' }
            )
        }
        [ordered]@{ Id = 'offboarding'; Name = 'Offboarding - odejście pracownika'; Kind = 'Offboarding'; Steps = @(
                @{ Text = 'Blokada logowania'; Auto = 'Block' }
                @{ Text = 'Unieważnienie sesji na wszystkich urządzeniach'; Auto = 'RevokeSessions' }
                @{ Text = 'Losowe hasło'; Auto = 'ResetPassword' }
                @{ Text = 'Autoodpowiedź i przekierowanie poczty (Exchange > Poczta)'; Auto = '' }
                @{ Text = 'Konwersja skrzynki na współdzieloną'; Auto = 'ConvertShared' }
                @{ Text = 'Ukrycie w książce adresowej'; Auto = 'HideGAL' }
                @{ Text = 'Dostęp przełożonego do OneDrive (Microsoft 365 > OneDrive odchodzącego)'; Auto = '' }
                @{ Text = 'Usunięcie z grup'; Auto = 'RemoveGroups' }
                @{ Text = 'Usunięcie licencji (po konwersji skrzynki)'; Auto = 'RemoveLicenses' }
                @{ Text = 'Zwrot sprzętu (komputer, telefon, karta)'; Auto = '' }
                @{ Text = 'Wycofanie urządzeń z Intune (Retire / Wipe)'; Auto = '' }
                @{ Text = 'Odebranie dostępów do systemów dziedzinowych'; Auto = '' }
            )
        }
    )
}

function Get-HTChecklistTemplates {
    $path = Get-HTAutomationFile 'ChecklistTemplates.json'
    $items = @(Read-HTJsonList -Path $path)
    if ($items.Count -eq 0) { return @(Get-HTDefaultChecklistTemplates) }
    return $items
}

function Save-HTChecklistTemplates {
    param ([AllowEmptyCollection()][object[]]$Templates = @())
    Write-HTJsonList -Path (Get-HTAutomationFile 'ChecklistTemplates.json') -Items $Templates
}

function ConvertFrom-HTChecklistText {
    # Kroki szablonu z tekstu: jeden krok w linii, krok automatyczny z prefiksem [auto:Nazwa], np. «[auto:Block] Blokada logowania»
    param ([AllowEmptyString()][string]$Text)
    foreach ($line in @($Text -split "`r?`n")) {
        $l = $line.Trim()
        if (-not $l) { continue }
        $auto = ''
        if ($l -match '^\[auto:(\w+)\]\s*(.+)$') {
            if ($script:ChecklistAutoSteps.Contains($Matches[1])) { $auto = $Matches[1] }
            $l = $Matches[2].Trim()
        }
        @{ Text = $l; Auto = $auto }
    }
}

function ConvertTo-HTChecklistText {
    param ([AllowEmptyCollection()][object[]]$Steps = @())
    return (@($Steps | ForEach-Object { if ($_.Auto) { "[auto:$($_.Auto)] $($_.Text)" } else { [string]$_.Text } }) -join "`r`n")
}

function Get-HTChecklists {
    param ([switch]$Open)
    $items = @(Read-HTJsonList -Path (Get-HTAutomationFile 'Checklists.json'))
    if ($Open) { return @($items | Where-Object { -not $_.Completed }) }
    return $items
}

function Save-HTChecklists {
    param ([AllowEmptyCollection()][object[]]$Checklists = @())
    Write-HTJsonList -Path (Get-HTAutomationFile 'Checklists.json') -Items $Checklists
}

function New-HTChecklist {
    param ([Parameter(Mandatory)]$Template, [Parameter(Mandatory)][string]$Subject, [string]$SubjectId = '', $Due = $null)
    $checklist = [ordered]@{
        Id = [guid]::NewGuid().ToString('N'); Template = [string]$Template.Name; Kind = [string]$Template.Kind; Subject = $Subject; SubjectId = $SubjectId
        Created = (Get-Date).ToString('o'); CreatedBy = "$env:USERNAME$(if ($Global:HTActiveAccount) { " ($($Global:HTActiveAccount))" })"; Due = $(if ($Due) { ([datetime]$Due).ToString('o') } else { $null })
        Steps = @(foreach ($s in @($Template.Steps)) { [ordered]@{ Text = [string]$s.Text; Auto = [string]$s.Auto; Done = $false; DoneAt = $null; DoneBy = ''; Note = '' } })
        Completed = $null
    }
    Save-HTChecklists -Checklists (@(Get-HTChecklists) + @($checklist))
    return $checklist
}

function Get-HTChecklistProgress {
    param ([Parameter(Mandatory)]$Checklist)
    $steps = @($Checklist.Steps)
    $done = @($steps | Where-Object { $_.Done }).Count
    return @{ Done = $done; Total = $steps.Count; Percent = $(if ($steps.Count) { [int][Math]::Round(100 * $done / $steps.Count) } else { 100 }) }
}

function Set-HTChecklistStep {
    # Oznaczenie kroku; po wykonaniu wszystkich kroków checklista jest zamykana (zwraca $true, gdy właśnie ukończono)
    param ([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][int]$Index, [bool]$Done = $true, [string]$Note = $null)
    $all = @(Get-HTChecklists)
    $justCompleted = $false
    foreach ($c in $all) {
        if ($c.Id -ne $Id) { continue }
        $step = @($c.Steps)[$Index]
        if (-not $step) { break }
        $step.Done = $Done
        $step.DoneAt = $(if ($Done) { (Get-Date).ToString('o') } else { $null })
        $step.DoneBy = $(if ($Done) { "$env:USERNAME$(if ($Global:HTActiveAccount) { " ($($Global:HTActiveAccount))" })" } else { '' })
        if ($null -ne $Note) { $step.Note = $Note }
        $progress = Get-HTChecklistProgress -Checklist $c
        if ($progress.Done -eq $progress.Total -and -not $c.Completed) { $c.Completed = (Get-Date).ToString('o'); $justCompleted = $true }
        elseif ($progress.Done -lt $progress.Total) { $c.Completed = $null }
    }
    Save-HTChecklists -Checklists $all
    return $justCompleted
}

function Remove-HTChecklist {
    param ([Parameter(Mandatory)][string]$Id)
    Save-HTChecklists -Checklists @(Get-HTChecklists | Where-Object { $_.Id -ne $Id })
}

function Invoke-HTChecklistAutoStep {
    # Krok automatyczny dla konta Microsoft 365 (SubjectId - Id konta, Subject - UPN)
    param ([Parameter(Mandatory)][string]$Auto, [Parameter(Mandatory)][string]$UserId, [string]$Upn = '')
    switch ($Auto) {
        'Block' { Set-HTM365UserEnabled -Id $UserId -Enabled $false -RevokeSessions $false; return 'Logowanie zablokowane' }
        'RevokeSessions' { Revoke-HTM365UserSessions -Id $UserId; return 'Sesje unieważnione' }
        'ResetPassword' { Reset-HTM365UserPassword -Id $UserId -Password (New-Password -Length 20 -StartWithLetter $true -NoSimilarChars $true) -ForceChange $true; return 'Ustawiono losowe hasło' }
        'RemoveGroups' {
            $n = 0
            foreach ($g in @(Get-HTM365UserGroups -Id $UserId)) {
                if (-not (Test-HTM365GroupManageable -Group $g)) { continue }
                if ($g.Type -in 'Dystrybucyjna', 'Zabezpieczeń (mail)' -and -not $Global:ConnectedToExchange) { continue }
                Remove-HTM365UserFromGroup -Group $g -User ([PSCustomObject]@{ Id = $UserId; UserPrincipalName = $Upn })
                $n++
            }
            return "Usunięto z grup: $n"
        }
        'RemoveLicenses' {
            $ids = @(Get-HTM365UserLicenses -Id $UserId | ForEach-Object { "$($_.SkuId)" })
            if ($ids.Count) { Set-HTM365UserLicense -Id $UserId -RemoveSkuIds $ids }
            return "Usunięto licencji: $($ids.Count)"
        }
        'ConvertShared' { if (-not $Global:ConnectedToExchange) { throw 'Wymaga połączenia z Exchange Online.' }; Convert-HTMailboxType -Identity $Upn -Type Shared; return 'Skrzynka współdzielona' }
        'HideGAL' { if (-not $Global:ConnectedToExchange) { throw 'Wymaga połączenia z Exchange Online.' }; Set-HTMailboxHiddenFromGAL -Identity $Upn -Hidden $true; return 'Ukryto w książce adresowej' }
        default { throw "Nieznany krok automatyczny: $Auto" }
    }
}
#endregion

#region Migawki konfiguracji i porównanie
<#
    Migawka: Snapshots\<Rodzaj>\RRRRMMDD_GGmmss.json = @{ Kind; Title; Created; CreatedBy; Tenant; Records = @(@{ Key; ... }) }.
    Porównanie dwóch migawek (albo migawki ze stanem bieżącym): rekordy dodane, usunięte i zmienione (pola przed i po).
#>
$script:SnapshotDefinitions = [ordered]@{
    AdminRoles        = @{ Title = 'Role administracyjne'; Service = 'Graph'; Collect = {
            foreach ($a in @(Get-HTPrivilegedRoleAssignments)) { [ordered]@{ Key = "$($a.Rola)|$(if ($a.UPN) { $a.UPN } else { $a.Członek })|$($a.Przypisanie)"; Rola = $a.Rola; Członek = $a.Członek; UPN = $a.UPN; Przypisanie = $a.Przypisanie; Czas = $a.Czas } }
        }
    }
    ConditionalAccess = @{ Title = 'Zasady dostępu warunkowego'; Service = 'Graph'; Collect = {
            foreach ($p in @(Get-HTConditionalAccessPolicies -Raw)) {
                $json = ConvertTo-Json -InputObject ([ordered]@{ conditions = $p.conditions; grantControls = $p.grantControls; sessionControls = $p.sessionControls }) -Depth 12 -Compress
                $hash = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($json))).Substring(0, 16)
                [ordered]@{ Key = [string]$p.id; Zasada = $p.displayName; Stan = [string]$p.state; Definicja = $hash; Zmieniono = [string]$p.modifiedDateTime }
            }
        }
    }
    GroupMembers      = @{ Title = 'Członkowie grup zabezpieczeń i Microsoft 365'; Service = 'Graph'; Collect = {
            $groups = @(Invoke-HTGraphRequest -Uri 'groups?$select=id,displayName,securityEnabled,groupTypes&$top=999' -All | Where-Object { $_.securityEnabled -or @($_.groupTypes) -contains 'Unified' })
            $batch = Invoke-HTGraphBatch -Requests @($groups | ForEach-Object { @{ Id = $_.id; Url = "groups/$($_.id)/members?`$select=id,displayName,userPrincipalName&`$top=999" } }) -All
            foreach ($g in $groups) {
                $b = $batch[[string]$g.id]
                if (-not $b -or $b.Status -ge 300) { continue }
                foreach ($mbr in @($b.Body.value)) { [ordered]@{ Key = "$($g.displayName)|$(if ($mbr.userPrincipalName) { $mbr.userPrincipalName } else { $mbr.displayName })"; Grupa = $g.displayName; Członek = $mbr.displayName; UPN = $mbr.userPrincipalName } }
            }
        }
    }
    UserLicenses      = @{ Title = 'Licencje użytkowników'; Service = 'Graph'; Collect = {
            $names = Get-HTSkuNameMap
            foreach ($u in @(Invoke-HTGraphRequest -Uri 'users?$select=userPrincipalName,assignedLicenses&$top=999' -All)) {
                foreach ($l in @($u.assignedLicenses)) { $sku = $names["$($l.skuId)"] ?? "$($l.skuId)"; [ordered]@{ Key = "$($u.userPrincipalName)|$sku"; UPN = $u.userPrincipalName; Licencja = $sku } }
            }
        }
    }
    MailboxForwarding = @{ Title = 'Przekierowania skrzynek'; Service = 'Exchange'; Collect = {
            foreach ($mb in @(Get-HTMailboxes)) { if ($mb.Forwarding) { [ordered]@{ Key = $mb.PrimarySmtpAddress; Skrzynka = $mb.DisplayName; 'Przekierowanie' = $mb.Forwarding } } }
        }
    }
    AppCredentials    = @{ Title = 'Sekrety i certyfikaty aplikacji'; Service = 'Graph'; Collect = {
            foreach ($r in @(Get-HTAppCredentialExpiry -IncludeAll -NoServicePrincipals)) { [ordered]@{ Key = "$($r.AppId)|$($r.KeyId)"; Aplikacja = $r.Aplikacja; Poświadczenie = $r.Poświadczenie; Opis = $r.Opis; Wygasa = [string]$r.Wygasa } }
        }
    }
}

function Get-HTSnapshotDefinitions { return $script:SnapshotDefinitions }

function Get-HTSnapshotDirectory {
    param ([Parameter(Mandatory)][string]$Kind)
    $base = Split-Path -Parent (Get-HTAutomationFile 'Snapshots.marker')
    $dir = Join-Path (Join-Path $base 'Snapshots') $Kind
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $dir
}

function Get-HTSnapshotRecords {
    # Bieżący stan danego rodzaju (bez zapisu)
    param ([Parameter(Mandatory)][ValidateScript({ $script:SnapshotDefinitions.Contains($_) })][string]$Kind)
    return @(& $script:SnapshotDefinitions[$Kind].Collect | Where-Object { $_ })
}

function New-HTSnapshot {
    param ([Parameter(Mandatory)][ValidateScript({ $script:SnapshotDefinitions.Contains($_) })][string]$Kind, [AllowEmptyCollection()][object[]]$Records)
    if ($null -eq $Records) { $Records = @(Get-HTSnapshotRecords -Kind $Kind) }
    $tenant = ''
    try { $tenant = [string](Get-MgContext).TenantId } catch { $tenant = '' }
    $snapshot = [ordered]@{ Kind = $Kind; Title = $script:SnapshotDefinitions[$Kind].Title; Created = (Get-Date).ToString('o'); CreatedBy = $env:USERNAME; Tenant = $tenant; Records = @($Records) }
    $path = Join-Path (Get-HTSnapshotDirectory -Kind $Kind) ('{0:yyyyMMdd_HHmmss}.json' -f (Get-Date))
    [System.IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $snapshot -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
    Write-Log -Message "Zapisano migawkę «$($snapshot.Title)» ($(@($Records).Count) rekordów): $path" -Type 'Info'
    return $path
}

function Get-HTSnapshots {
    param ([Parameter(Mandatory)][string]$Kind)
    $dir = Get-HTSnapshotDirectory -Kind $Kind
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*.json' -File | Sort-Object Name -Descending)) {
        $date = [datetime]::MinValue
        [void][datetime]::TryParseExact($f.BaseName, 'yyyyMMdd_HHmmss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$date)
        [PSCustomObject]@{ Data = $date; Plik = $f.Name; 'Rozmiar (KB)' = [Math]::Round($f.Length / 1KB, 1); Ścieżka = $f.FullName }
    }
}

function Read-HTSnapshot {
    param ([Parameter(Mandatory)][string]$Path)
    return (ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($Path)) -AsHashtable -ErrorAction Stop)
}

function Compare-HTSnapshot {
    <#
        Różnice między rekordami (słowniki z kluczem Key): Dodano, Usunięto, Zmieniono (pole: przed → po).
        -Old / -New: listy rekordów (np. Records z migawek albo Get-HTSnapshotRecords).
    #>
    param ([AllowEmptyCollection()][object[]]$Old = @(), [AllowEmptyCollection()][object[]]$New = @())
    $oldMap = [ordered]@{}
    foreach ($r in @($Old)) { if ($r -and $r.Key) { $oldMap[[string]$r.Key] = $r } }
    $newMap = [ordered]@{}
    foreach ($r in @($New)) { if ($r -and $r.Key) { $newMap[[string]$r.Key] = $r } }
    $describe = { param($r) (@($r.Keys | Where-Object { $_ -ne 'Key' } | ForEach-Object { "${_}: $($r[$_])" }) -join '; ') }
    foreach ($k in $newMap.Keys) {
        if (-not $oldMap.Contains($k)) { [PSCustomObject]@{ Zmiana = 'Dodano'; Obiekt = $k; Szczegóły = (& $describe $newMap[$k]); __flag = 'warn' }; continue }
        $o = $oldMap[$k]; $n = $newMap[$k]
        $changes = @(foreach ($f in @(@($n.Keys) + @($o.Keys) | Select-Object -Unique)) {
                if ($f -eq 'Key') { continue }
                if ([string]$o[$f] -ne [string]$n[$f]) { "${f}: $($o[$f]) → $($n[$f])" }
            })
        if ($changes.Count) { [PSCustomObject]@{ Zmiana = 'Zmieniono'; Obiekt = $k; Szczegóły = ($changes -join '; '); __flag = 'warn' } }
    }
    foreach ($k in $oldMap.Keys) {
        if (-not $newMap.Contains($k)) { [PSCustomObject]@{ Zmiana = 'Usunięto'; Obiekt = $k; Szczegóły = (& $describe $oldMap[$k]); __flag = 'crit' } }
    }
}
#endregion

#region Cofanie zmian
<#
    Rejestr zmian możliwych do cofnięcia (Undo.json, ostatnie 500): @{ Id; Time; Operation; Object; Kind; Data; Account; Undone; UndoResult }.
    Rodzaje: License (UserId, SkuIds), TeamArchive (TeamId), UserEnabled (UserId, Enabled), MailboxPermission (Identity, User, Type),
    TransportRule (Identity), EntraDevice (Id), DefenderIsolation (MachineId), GroupMember (GroupId, UserId, Added), Manager (UserId, ManagerId).
#>
$script:UndoKinds = @{
    License           = @{ Title = 'Przywrócenie licencji'; Service = 'Graph' }
    TeamArchive       = @{ Title = 'Przywrócenie zespołu z archiwum'; Service = 'Graph' }
    UserEnabled       = @{ Title = 'Przywrócenie stanu konta'; Service = 'Graph' }
    MailboxPermission = @{ Title = 'Ponowne nadanie uprawnienia do skrzynki'; Service = 'Exchange' }
    TransportRule     = @{ Title = 'Ponowne włączenie reguły transportu'; Service = 'Exchange' }
    EntraDevice       = @{ Title = 'Włączenie urządzenia Entra ID'; Service = 'Graph' }
    DefenderIsolation = @{ Title = 'Zwolnienie urządzenia z izolacji'; Service = 'Defender' }
    GroupMember       = @{ Title = 'Przywrócenie członkostwa w grupie'; Service = 'Graph' }
    Manager           = @{ Title = 'Przywrócenie przełożonego'; Service = 'Graph' }
    PerUserMfa        = @{ Title = 'Przywrócenie MFA na koncie (per-user)'; Service = 'Graph' }
}

function Get-HTUndoKinds { return $script:UndoKinds }

function Register-HTUndo {
    param ([Parameter(Mandatory)][string]$Operation, [string]$Object = '', [Parameter(Mandatory)][ValidateScript({ $script:UndoKinds.ContainsKey($_) })][string]$Kind, [hashtable]$Data = @{})
    try {
        $path = Get-HTAutomationFile 'Undo.json'
        $items = @(Read-HTJsonList -Path $path)
        $items += [ordered]@{ Id = [guid]::NewGuid().ToString('N'); Time = (Get-Date).ToString('o'); Operation = $Operation; Object = $Object; Kind = $Kind; Data = $Data; Account = "$env:USERNAME$(if ($Global:HTActiveAccount) { " ($($Global:HTActiveAccount))" })"; Undone = $null; UndoResult = '' }
        if ($items.Count -gt 500) { $items = @($items | Select-Object -Last 500) }
        Write-HTJsonList -Path $path -Items $items
    }
    catch { Write-Log -Message "Rejestr cofania zmian: $($_.Exception.Message)" -Type 'Warn' }
}

function Get-HTUndoRecords {
    return @(Read-HTJsonList -Path (Get-HTAutomationFile 'Undo.json') | Sort-Object { [datetime]$_.Time } -Descending)
}

function Invoke-HTUndo {
    # Cofnięcie zmiany z rejestru; zwraca opis wyniku
    param ([Parameter(Mandatory)][string]$Id)
    $path = Get-HTAutomationFile 'Undo.json'
    $items = @(Read-HTJsonList -Path $path)
    $rec = @($items | Where-Object { $_.Id -eq $Id })[0]
    if (-not $rec) { throw 'Nie znaleziono wpisu.' }
    if ($rec.Undone) { throw "Zmiana została już cofnięta ($($rec.Undone))." }
    $d = $rec.Data
    $result = switch ($rec.Kind) {
        'License' { Set-HTM365UserLicense -Id $d.UserId -AddSkuIds @($d.SkuIds); "Przywrócono licencji: $(@($d.SkuIds).Count)" }
        'TeamArchive' { Set-HTTeamArchived -TeamId $d.TeamId -Archived $false; 'Przywrócono zespół z archiwum' }
        'UserEnabled' { Set-HTM365UserEnabled -Id $d.UserId -Enabled ([bool]$d.Enabled) -RevokeSessions $false; $(if ($d.Enabled) { 'Odblokowano logowanie' } else { 'Zablokowano logowanie' }) }
        'MailboxPermission' { Add-HTMailboxPermission -Identity $d.Identity -User $d.User -Type @($d.Type); "Nadano ponownie $($d.Type) dla $($d.User)" }
        'TransportRule' { Set-HTTransportRuleState -Identity $d.Identity -Enabled $true; 'Włączono regułę' }
        'EntraDevice' { Set-HTEntraDeviceEnabled -Id $d.Id -Enabled $true; 'Włączono urządzenie' }
        'DefenderIsolation' { Set-HTDefenderIsolation -MachineId $d.MachineId -Isolate $false -Comment "Cofnięcie izolacji - Helpdesk Tools ($env:USERNAME)" }
        'GroupMember' {
            if ($d.Added) { Remove-HTM365GroupMember -GroupId $d.GroupId -MemberId $d.UserId; 'Usunięto z grupy (cofnięcie dodania)' }
            else { Add-HTM365GroupMember -GroupId $d.GroupId -MemberId $d.UserId; 'Dodano ponownie do grupy' }
        }
        'PerUserMfa' { Set-HTM365PerUserMfaState -Id $d.UserId -State ([string]$d.State); "Przywrócono MFA na koncie: $(Get-HTPerUserMfaStateLabel ([string]$d.State))" }
        'Manager' {
            if ($d.ManagerId) { Set-HTM365UserManager -Id $d.UserId -ManagerId $d.ManagerId; 'Przywrócono poprzedniego przełożonego' }
            else { Remove-HTM365UserManager -Id $d.UserId; 'Usunięto przełożonego (wcześniej brak)' }
        }
        default { throw "Nieobsługiwany rodzaj: $($rec.Kind)" }
    }
    foreach ($i in $items) { if ($i.Id -eq $Id) { $i.Undone = (Get-Date).ToString('o'); $i.UndoResult = [string]$result } }
    Write-HTJsonList -Path $path -Items $items
    Add-HTOperationRecord -Operation "Cofnięcie: $($rec.Operation)" -Object $rec.Object -Details $result -Module 'Cofanie zmian'
    Write-Log -Message "Cofnięto zmianę «$($rec.Operation)» ($($rec.Object)): $result" -Type 'Info'
    return $result
}
#endregion

#region Raporty bez okna (HelpdeskToolsRunner.ps1) i zadanie Harmonogramu Windows
$script:HeadlessReports = [ordered]@{
    'nieaktywni'            = @{ Title = 'Nieaktywni użytkownicy'; Service = 'Graph'; Run = { Get-HTM365InactiveUsers -Days $(if ($Global:InactiveDays -gt 0) { $Global:InactiveDays } else { 90 }) } }
    'sekrety-aplikacji'     = @{ Title = 'Wygasające sekrety i certyfikaty aplikacji'; Service = 'Graph'; Run = { Get-HTAppCredentialExpiry -Days 30 } }
    'licencje-do-odzyskania' = @{ Title = 'Licencje do odzyskania'; Service = 'Graph'; Run = { Get-HTReclaimableLicenses -Days $(if ($Global:InactiveDays -gt 0) { $Global:InactiveDays } else { 90 }) } }
    'bledy-licencji'        = @{ Title = 'Błędy licencji grupowych'; Service = 'Graph'; Run = { Get-HTGroupLicenseErrors } }
    'administratorzy'       = @{ Title = 'Administratorzy: MFA i hasła'; Service = 'Graph'; Run = { Get-HTAdminSecurityReport } }
    'zespoly-bez-wlasciciela' = @{ Title = 'Zespoły z uwagami (właściciele, goście)'; Service = 'Graph'; Run = { Get-HTTeamsOverview -OnlyIssues -NoActivity } }
    'urzadzenia-niezgodne'  = @{ Title = 'Niezgodne urządzenia Intune'; Service = 'Graph'; Run = { Get-HTIntuneDevices | Where-Object { $_.ComplianceState -in 'noncompliant', 'inGracePeriod' } | Select-Object DeviceName, UserPrincipalName, OperatingSystem, OsVersion, ComplianceState, LastSync, SerialNumber } }
    'aktualizacje-windows'  = @{ Title = 'Aktualizacje Windows'; Service = 'Graph'; Run = { Get-HTWindowsUpdateStatus | Where-Object { $_.__flag } } }
    'nieaktywne-witryny'    = @{ Title = 'Nieaktywne witryny i bez właściciela'; Service = 'Graph'; Run = { Get-HTInactiveSites -Days 90 } }
    'alerty-defender'       = @{ Title = 'Otwarte alerty Microsoft Defender'; Service = 'Graph'; Run = { Get-HTDefenderAlerts -Days 7 } }
    'przekierowania'        = @{ Title = 'Przekierowania poczty na zewnątrz'; Service = 'Exchange'; Run = { Get-HTExternalForwardingReport } }
    'wspoldzielone-licencje' = @{ Title = 'Skrzynki współdzielone a licencje'; Service = 'Exchange'; Run = { Get-HTSharedMailboxLicenseReport | Where-Object { $_.__flag } } }
}

function Get-HTHeadlessReports { return $script:HeadlessReports }

function Invoke-HTHeadlessReport {
    # Wiersze raportu jako słowniki (kolumny bez pól technicznych __*, z zachowaniem __flag)
    param ([Parameter(Mandatory)][ValidateScript({ $script:HeadlessReports.Contains($_) })][string]$Name)
    $def = $script:HeadlessReports[$Name]
    $objects = @(& $def.Run | Where-Object { $null -ne $_ })
    $columns = New-Object System.Collections.Generic.List[string]
    $rows = foreach ($o in $objects) {
        $d = [ordered]@{}
        foreach ($p in $o.PSObject.Properties) {
            if ($p.Name -like '__*') { continue }
            if (-not $columns.Contains($p.Name)) { $columns.Add($p.Name) }
            $v = $p.Value
            $d[$p.Name] = if ($null -eq $v) { '' } elseif ($v -is [datetime] -or $v -is [bool] -or $v -is [int] -or $v -is [long] -or $v -is [double]) { $v } elseif ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { (@($v) -join ', ') } else { [string]$v }
        }
        $d['__flag'] = [string]$o.__flag
        $d
    }
    return @{ Name = $Name; Title = $def.Title; Columns = $columns.ToArray(); Rows = @($rows) }
}

function New-HTRunnerScheduledTask {
    <#
        Zadanie Harmonogramu Windows uruchamiające HelpdeskToolsRunner.ps1 (raporty e-mailem, zadania zaplanowane, migawki).
        Domyślnie działa, gdy użytkownik jest zalogowany (certyfikat aplikacji i ustawienia w profilu użytkownika).
    #>
    param (
        [Parameter(Mandatory)][string]$RunnerPath,
        [string]$TaskName = 'Helpdesk Tools - raporty',
        [string[]]$Reports = @(),
        [string[]]$To = @(),
        [switch]$RunJobs,
        [string[]]$Snapshots = @(),
        [ValidateSet('Daily', 'Weekly', 'Hourly')][string]$Schedule = 'Weekly',
        [ValidateSet('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')][string]$DayOfWeek = 'Monday',
        [string]$Time = '07:30'
    )
    $pwsh = (Get-Process -Id $PID).Path
    $arguments = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', "`"$RunnerPath`"")
    if ($Reports.Count) { $arguments += @('-Report', "`"$($Reports -join ',')`"") }
    if ($To.Count) { $arguments += @('-To', "`"$($To -join ',')`"") }
    if ($RunJobs) { $arguments += '-RunJobs' }
    if ($Snapshots.Count) { $arguments += @('-Snapshot', "`"$($Snapshots -join ',')`"") }
    $action = New-ScheduledTaskAction -Execute $pwsh -Argument ($arguments -join ' ') -WorkingDirectory (Split-Path -Parent $RunnerPath)
    $at = [datetime]::ParseExact($Time, 'HH:mm', [System.Globalization.CultureInfo]::InvariantCulture)
    $trigger = switch ($Schedule) {
        'Daily' { New-ScheduledTaskTrigger -Daily -At $at }
        'Hourly' { New-ScheduledTaskTrigger -Once -At $at -RepetitionInterval (New-TimeSpan -Hours 1) }
        default { New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $at }
    }
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2) -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Helpdesk Tools: raporty e-mailem, zadania zaplanowane i migawki (HelpdeskToolsRunner.ps1)' -Force | Out-Null
    Write-Log -Message "Utworzono zadanie Harmonogramu Windows «$TaskName» ($Schedule, $Time)." -Type 'Info'
    return $TaskName
}
#endregion

#region Aplikacja automatyzacji (uwierzytelnianie certyfikatem, bez użytkownika)
$script:AutomationGraphRoles = @('User.ReadWrite.All', 'Group.ReadWrite.All', 'GroupMember.ReadWrite.All', 'Directory.Read.All', 'AuditLog.Read.All', 'Reports.Read.All',
    'Application.Read.All', 'Policy.Read.All', 'RoleManagement.Read.Directory', 'DeviceManagementManagedDevices.Read.All', 'Sites.Read.All', 'Mail.Send',
    'SecurityAlert.Read.All', 'Organization.Read.All', 'Team.ReadBasic.All', 'TeamMember.Read.All', 'Files.Read.All')

function New-HTAutomationApp {
    <#
        Rejestracja aplikacji do pracy bez użytkownika (HelpdeskToolsRunner.ps1): certyfikat z podpisem własnym w magazynie
        CurrentUser\My, uprawnienia aplikacji Microsoft Graph i Exchange.ManageAsApp z zgodą administratora oraz rola
        Exchange Administrator. -UserAdministrator: dodatkowo rola User Administrator (zadania offboardingu bez użytkownika).
        Wymaga zalogowania jako Global Administrator / Privileged Role Administrator.
    #>
    param ([string]$DisplayName = 'Helpdesk Tools - automatyzacja', [int]$CertificateYears = 2, [switch]$UserAdministrator)
    $cert = New-SelfSignedCertificate -Subject "CN=$DisplayName" -CertStoreLocation Cert:\CurrentUser\My -KeyExportPolicy NonExportable -KeySpec Signature -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256 -NotAfter (Get-Date).AddYears($CertificateYears) -ErrorAction Stop
    $graphSp = @(Invoke-HTGraphRequest -Uri "servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'&`$select=id,appId,appRoles")[0]
    $exoSp = @(Invoke-HTGraphRequest -Uri "servicePrincipals?`$filter=appId eq '00000002-0000-0ff1-ce00-000000000000'&`$select=id,appId,appRoles")[0]
    $graphRoles = @(foreach ($r in $script:AutomationGraphRoles) { $def = @($graphSp.appRoles | Where-Object { $_.value -eq $r })[0]; if ($def) { $def } else { Write-Log -Message "Uprawnienie aplikacji $r niedostępne - pominięto." -Type 'Warn' } })
    $exoRole = if ($exoSp) { @($exoSp.appRoles | Where-Object { $_.value -eq 'Exchange.ManageAsApp' })[0] } else { $null }
    $required = @(@{ resourceAppId = $graphSp.appId; resourceAccess = @($graphRoles | ForEach-Object { @{ id = $_.id; type = 'Role' } }) })
    if ($exoRole) { $required += @{ resourceAppId = $exoSp.appId; resourceAccess = @(@{ id = $exoRole.id; type = 'Role' }) } }
    $app = Invoke-HTGraphRequest -Uri 'applications' -Method POST -Body @{
        displayName            = $DisplayName
        signInAudience         = 'AzureADMyOrg'
        requiredResourceAccess = $required
        keyCredentials         = @(@{ type = 'AsymmetricX509Cert'; usage = 'Verify'; key = [Convert]::ToBase64String($cert.RawData); displayName = "CN=$DisplayName" })
    }
    $sp = $null
    for ($i = 0; $i -lt 6 -and -not $sp; $i++) {
        try { $sp = Invoke-HTGraphRequest -Uri 'servicePrincipals' -Method POST -Body @{ appId = $app.appId } }
        catch { if ($i -eq 5) { throw }; Start-Sleep -Seconds 4 }
    }
    $granted = 0
    foreach ($r in $graphRoles) {
        try { Invoke-HTGraphRequest -Uri "servicePrincipals/$($graphSp.id)/appRoleAssignedTo" -Method POST -Body @{ principalId = $sp.id; resourceId = $graphSp.id; appRoleId = $r.id } | Out-Null; $granted++ }
        catch { Write-Log -Message "Zgoda dla $($r.value): $($_.Exception.Message)" -Type 'Warn' }
    }
    if ($exoRole) {
        try { Invoke-HTGraphRequest -Uri "servicePrincipals/$($exoSp.id)/appRoleAssignedTo" -Method POST -Body @{ principalId = $sp.id; resourceId = $exoSp.id; appRoleId = $exoRole.id } | Out-Null; $granted++ }
        catch { Write-Log -Message "Zgoda Exchange.ManageAsApp: $($_.Exception.Message)" -Type 'Warn' }
    }
    $roles = @(@{ Name = 'Exchange Administrator'; Template = '29232cdf-9323-42fd-ade2-1d097af3e4de' })
    if ($UserAdministrator) { $roles += @{ Name = 'User Administrator'; Template = 'fe930be7-5e62-47db-91af-98c3a49a38b1' } }
    foreach ($role in $roles) {
        try { Invoke-HTGraphRequest -Uri 'roleManagement/directory/roleAssignments' -Method POST -Body @{ principalId = $sp.id; roleDefinitionId = $role.Template; directoryScopeId = '/' } | Out-Null }
        catch { Write-Log -Message "Rola $($role.Name) dla aplikacji: $($_.Exception.Message)" -Type 'Warn' }
    }
    $org = ''
    try { $org = @(Invoke-HTGraphRequest -Uri 'domains' | Where-Object { $_.isInitial })[0].id } catch { $org = '' }
    Write-Log -Message "Utworzono aplikację automatyzacji «$DisplayName» (Client ID $($app.appId), certyfikat $($cert.Thumbprint), uprawnień: $granted)." -Type 'Info&Notification'
    return [PSCustomObject]@{ ClientId = $app.appId; TenantId = [string](Get-MgContext).TenantId; Thumbprint = $cert.Thumbprint; Organization = $org; Expires = $cert.NotAfter; Granted = $granted }
}
#endregion
