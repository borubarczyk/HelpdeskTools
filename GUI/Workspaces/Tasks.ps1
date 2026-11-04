# Przestrzeń robocza: Zadania - zadania zaplanowane (uprawnienia tymczasowe, zaplanowany offboarding), checklisty
# on/offboardingu, migawki konfiguracji i porównanie, cofanie zmian, historia obiektu oraz raporty zaplanowane bez okna

Register-HTWorkspace -Key 'Tasks' -Title 'Zadania' -Icon 'E823' `
    -Description 'Uprawnienia tymczasowe, zaplanowany offboarding, checklisty, migawki i porównanie konfiguracji, cofanie zmian, historia obiektu i raporty zaplanowane' `
    -Categories @('Zadania zaplanowane', 'Checklisty', 'Zmiany i historia', 'Automatyzacja')

#region Wykonawca zadań zaplanowanych (co minutę, gdy program działa)
$script:JobScheduler = @{ Timer = $null; Notified = @{} }

function Invoke-HTJobSchedulerTick {
    if ((Test-HTLocked) -or $HT_UI.BusyDepth -gt 0) { return }
    $due = @(Get-HTDueJobs)
    if (-not $due.Count) { return }
    # Odebranie dostępu do OneDrive wymaga logowania do SharePoint - tylko na żądanie (Wykonaj teraz)
    foreach ($job in @($due | Where-Object { $_.Type -eq 'RevokeOneDriveAccess' })) {
        if ($script:JobScheduler.Notified.ContainsKey($job.Id)) { continue }
        $script:JobScheduler.Notified[$job.Id] = $true
        Write-Log -Message "Zadanie «Odebranie dostępu do OneDrive» ($($job.Object)) czeka na wykonanie - Zadania > Zadania zaplanowane > «Wykonaj teraz»." -Type 'Warn&Notification'
    }
    if (-not @($due | Where-Object { $_.Type -ne 'RevokeOneDriveAccess' }).Count) { return }
    if (-not (Test-HTWriteAllowed)) { return }
    $results = @(Invoke-HTDueJobs -ExcludeType @('RevokeOneDriveAccess'))
    foreach ($r in $results) {
        if ($r.Status -eq 'Oczekuje') {
            if (-not $script:JobScheduler.Notified.ContainsKey($r.Id)) { $script:JobScheduler.Notified[$r.Id] = $true; Show-HTToast "Zadanie «$($r.Zadanie)» ($($r.Obiekt)) czeka na połączenie: $($r.Wynik)" 'warn' 8 }
            continue
        }
        Show-HTToast "Zadanie «$($r.Zadanie)» ($($r.Obiekt)): $($r.Status)" $(if ($r.Status -eq 'OK') { 'ok' } else { 'crit' }) 8
    }
    $m = $HT_UI.ActiveModule
    if ($m -and $m.Key -eq 'tasks.jobs') { Update-HTJobsView -Module $m }
}

function Start-HTJobScheduler {
    if ($script:JobScheduler.Timer) { return }
    $t = New-Object System.Windows.Threading.DispatcherTimer
    $t.Interval = [TimeSpan]::FromSeconds(60)
    $t.add_Tick({ try { Invoke-HTJobSchedulerTick } catch { Write-Log -Message "Zadania zaplanowane: $($_.Exception.Message)" -Type 'Warn' } })
    $t.Start()
    $script:JobScheduler.Timer = $t
    $pending = @(Get-HTJobs -Pending).Count
    if ($pending) { Write-Log -Message "Zadania zaplanowane: oczekujących $pending (wykonywane, gdy program działa i jest połączony z usługą)." -Type 'Info' }
}

function Stop-HTJobScheduler {
    if ($script:JobScheduler.Timer) { $script:JobScheduler.Timer.Stop(); $script:JobScheduler.Timer = $null }
}
#endregion

#region Zadania zaplanowane
function Update-HTJobsView {
    param([Parameter(Mandatory)][hashtable]$Module)
    $types = Get-HTJobTypes
    $showAll = Test-HTChecked $Module.C.All
    Invoke-HTQuery -Module $Module -Name 'Zadania zaplanowane' -ScriptBlock {
        foreach ($j in @(Get-HTJobs | Sort-Object { [datetime]$_.RunAt })) {
            if (-not $showAll -and $j.Status -notin 'Zaplanowane', 'Oczekuje na połączenie', 'Błąd') { continue }
            [PSCustomObject]@{
                Termin     = ([datetime]$j.RunAt)
                Zadanie    = $types[[string]$j.Type].Title
                Obiekt     = $j.Object
                Opis       = $j.Description
                Stan       = $j.Status
                Wynik      = $j.Result
                Wykonano   = $(if ($j.Executed) { [datetime]$j.Executed } else { $null })
                Zaplanował = $j.CreatedBy
                Id         = $j.Id
                __job      = $j
                __flag     = switch ($j.Status) { 'Błąd' { 'crit' } 'Oczekuje na połączenie' { 'warn' } 'Wykonane' { 'muted' } 'Anulowane' { 'muted' } default { '' } }
            }
        }
    }
}

function Invoke-HTJobNow {
    # Wykonanie zadania na żądanie (z połączeniem SharePoint dla OneDrive)
    param([Parameter(Mandatory)]$Job)
    $sp = $null
    if ($Job.Type -eq 'RevokeOneDriveAccess') { $sp = Connect-HTPnPReturn -Url $Job.Data.SiteUrl }
    $missing = @(Get-HTJobMissingServices -Job $Job)
    if ($missing.Count) { throw "Brak połączenia: $($missing -join ', ')" }
    $title = (Get-HTJobTypes)[[string]$Job.Type].Title
    try {
        $result = Invoke-HTJob -Job $Job -SharePointConnection $sp
        Update-HTJob -Id $Job.Id -Changes @{ Status = 'Wykonane'; Executed = (Get-Date).ToString('o'); Result = [string]$result }
        [void](Send-HTTeamsMessage -Event 'Jobs' -Title "Wykonano zadanie: $title" -Text ([string]$Job.Description) -Tone 'ok' -Facts ([ordered]@{ Obiekt = $Job.Object; Wynik = $result }))
        return $result
    }
    catch {
        Update-HTJob -Id $Job.Id -Changes @{ Status = 'Błąd'; Executed = (Get-Date).ToString('o'); Result = $_.Exception.Message }
        throw
    }
}

Register-HTModule -Workspace 'Tasks' -Category 'Zadania zaplanowane' -Key 'tasks.jobs' -Title 'Zadania zaplanowane' -Icon 'E823' `
    -Description 'Zaplanowane odebrania uprawnień tymczasowych i zaplanowane offboardingi. Program wykonuje je co minutę, gdy jest uruchomiony i połączony z usługą (albo HelpdeskToolsRunner.ps1 -RunJobs z Harmonogramu Windows).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.All = Add-HTCheckBox -Parent $row -Text 'Także wykonane i anulowane'
    Add-HTButton -Parent $row -Module $m -Text 'Odśwież' -Icon 'E72C' -Primary -OnClick { param($m) Update-HTJobsView -Module $m } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Wykonaj zaległe teraz' -Icon 'E768' -OnClick {
        param($m)
        if (-not (Assert-HTWriteAllowed -Operation 'Zadania zaplanowane')) { return }
        $results = @(Invoke-HTDueJobs -ExcludeType @('RevokeOneDriveAccess'))
        Show-HTToast "Wykonano zadań: $(@($results | Where-Object { $_.Status -eq 'OK' }).Count), błędów: $(@($results | Where-Object { $_.Status -eq 'Błąd' }).Count), oczekuje: $(@($results | Where-Object { $_.Status -eq 'Oczekuje' }).Count)." 'info' 6
        Update-HTJobsView -Module $m
    } | Out-Null
    $m.OnShow = { param($m) Update-HTJobsView -Module $m }
    Add-HTRowAction -Module $m -Text 'Wykonaj teraz' -Icon 'E768' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Wykonanie zadania' -Rows @($rows | Where-Object { $_.__job.Status -in 'Zaplanowane', 'Oczekuje na połączenie', 'Błąd' }) -Confirm 'Wykonać zaznaczone zadania teraz?' -Label { param($r) "$($r.Zadanie): $($r.Obiekt)" } -Action { param($r) Invoke-HTJobNow -Job $r.__job } -Refresh { param($m) Update-HTJobsView -Module $m }
    }
    Add-HTRowAction -Module $m -Text 'Zmień termin…' -Icon 'E787' -Action {
        param($m, $rows)
        $form = Show-HTFormDialog -Title 'Nowy termin' -Icon 'E787' -OkText 'Zmień' -Fields @(@{ Name = 'When'; Label = 'Termin (RRRR-MM-DD GG:MM)'; Type = 'Date'; Default = (Get-Date).AddDays(1).ToString('yyyy-MM-dd 08:00') })
        if (-not $form -or -not $form.When) { return }
        foreach ($r in $rows) { Update-HTJob -Id $r.Id -Changes @{ RunAt = ([datetime]$form.When).ToString('o'); Status = 'Zaplanowane'; Result = '' } }
        Update-HTJobsView -Module $m
    }
    Add-HTRowAction -Module $m -Text 'Anuluj zadanie' -Icon 'E711' -Danger -Action {
        param($m, $rows)
        if (-not (Show-HTConfirm -Title 'Anulowanie zadań' -Message 'Anulować zaznaczone zadania? Uprawnienia tymczasowe nie zostaną wtedy odebrane automatycznie.' -Items @($rows | ForEach-Object { "$($_.Zadanie): $($_.Obiekt)" }))) { return }
        foreach ($r in $rows) { Update-HTJob -Id $r.Id -Changes @{ Status = 'Anulowane'; Result = "Anulowano ($env:USERNAME)" }; Add-HTOperationRecord -Operation 'Anulowanie zadania' -Object $r.Obiekt -Details $r.Zadanie -Module 'Zadania' }
        Update-HTJobsView -Module $m
    }
    Add-HTRowAction -Module $m -Text 'Usuń z listy' -Icon 'E74D' -Action {
        param($m, $rows)
        if (-not (Show-HTConfirm -Title 'Usuwanie zadań' -Message 'Usunąć zaznaczone zadania z listy?')) { return }
        foreach ($r in $rows) { Remove-HTJob -Id $r.Id }
        Update-HTJobsView -Module $m
    }
}

Register-HTModule -Workspace 'Tasks' -Category 'Zadania zaplanowane' -Key 'tasks.temp' -Title 'Uprawnienia tymczasowe' -Icon 'E916' `
    -Description 'Dostęp na określony czas: członkostwo w grupie (np. dostęp do aplikacji lub zespołu na czas projektu) albo pełny dostęp / wyślij jako do skrzynki (zastępstwo urlopowe). Uprawnienie jest nadawane od razu, a jego odebranie trafia do zadań zaplanowanych.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Członkostwo w grupie…' -Icon 'E902' -Primary -Create -NoRowMenu -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'Graph')) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Uprawnienia tymczasowe')) { return }
        $users = @(Select-HTM365User -Title 'Użytkownicy' -Prompt 'Kto ma otrzymać tymczasowe członkostwo?' -Multi)
        if (-not $users.Count) { return }
        $groups = @(Get-HTM365Groups | Where-Object { (Test-HTM365GroupManageable -Group $_) -and $_.Type -notin 'Dystrybucyjna', 'Zabezpieczeń (mail)' })
        $columns = @(@{ Text = 'Grupa'; Property = 'DisplayName' }, @{ Text = 'Typ'; Property = 'Type' }, @{ Text = 'E-mail'; Property = 'Mail' }, @{ Text = 'Opis'; Property = 'Description' })
        $selected = @(Show-HTSelectionDialog -Title 'Grupy' -Prompt 'Grupy zabezpieczeń i Microsoft 365 (bez dynamicznych i synchronizowanych z AD).' -Items $groups -Columns $columns -MultiSelect -Icon 'E902')
        if (-not $selected.Count) { return }
        $form = Show-HTFormDialog -Title 'Czas trwania' -Icon 'E916' -OkText 'Nadaj' -Description "$($users.Count) kont × $($selected.Count) grup" -Fields @(
            @{ Name = 'Until'; Label = 'Odebranie członkostwa (RRRR-MM-DD GG:MM)'; Type = 'Date'; Default = (Get-Date).AddDays(7).ToString('yyyy-MM-dd 17:00') }
            @{ Name = 'Reason'; Label = 'Powód (np. numer zgłoszenia)' }
        )
        if (-not $form -or -not $form.Until) { return }
        $until = [datetime]$form.Until
        if ($until -le (Get-Date)) { Show-HTWarning 'Termin odebrania musi być w przyszłości.'; return }
        $pairs = @(foreach ($u in $users) { foreach ($g in $selected) { [PSCustomObject]@{ User = $u; Group = $g; Label = "$(Get-HTM365Label $u) → $($g.DisplayName)" } } })
        Invoke-HTTargetAction -Module $m -Name 'Członkostwo tymczasowe' -Targets $pairs -Label { param($p) $p.Label } -Action {
            param($p)
            try { Add-HTM365GroupMember -GroupId $p.Group.Id -MemberId $p.User.Id }
            catch { if ("$($_.Exception.Message)" -notmatch 'already exist') { throw } }
            [void](New-HTScheduledJob -Type 'RemoveGroupMember' -RunAt $until -Object $p.Label -Description $form.Reason -Data @{ GroupId = $p.Group.Id; GroupName = $p.Group.DisplayName; UserId = $p.User.Id; UserLabel = (Get-HTM365Label $p.User) })
            "Dodano do $($until.ToString('yyyy-MM-dd HH:mm'))"
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Dostęp do skrzynki…' -Icon 'E715' -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'Exchange')) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Uprawnienia tymczasowe')) { return }
        $form = Show-HTFormDialog -Title 'Tymczasowy dostęp do skrzynki' -Icon 'E715' -OkText 'Nadaj' -Fields @(
            @{ Name = 'Mailbox'; Label = 'Skrzynki (adresy, jeden w linii)'; Type = 'Multiline'; Required = $true; Height = 50 }
            @{ Name = 'Users'; Label = 'Dla użytkowników (adresy, jeden w linii)'; Type = 'Multiline'; Required = $true; Height = 50 }
            @{ Name = 'Full'; Label = 'Pełny dostęp'; Type = 'Check'; Default = $true }
            @{ Name = 'AutoMap'; Label = 'Automatyczne dodanie w Outlooku'; Type = 'Check'; Default = $true }
            @{ Name = 'SendAs'; Label = 'Wyślij jako'; Type = 'Check' }
            @{ Name = 'Until'; Label = 'Odebranie dostępu (RRRR-MM-DD GG:MM)'; Type = 'Date'; Default = (Get-Date).AddDays(14).ToString('yyyy-MM-dd 17:00') }
            @{ Name = 'Reason'; Label = 'Powód (np. zastępstwo urlopowe, numer zgłoszenia)' }
        )
        if (-not $form -or -not $form.Until) { return }
        $until = [datetime]$form.Until
        if ($until -le (Get-Date)) { Show-HTWarning 'Termin odebrania musi być w przyszłości.'; return }
        $types = @()
        if ($form.Full) { $types += 'FullAccess' }
        if ($form.SendAs) { $types += 'SendAs' }
        if (-not $types.Count) { Show-HTWarning 'Wybierz rodzaj dostępu.'; return }
        $pairs = @(foreach ($mb in @(Split-HTInputList $form.Mailbox)) { foreach ($u in @(Split-HTInputList $form.Users)) { [PSCustomObject]@{ Mailbox = $mb; User = $u; Label = "$u → $mb" } } })
        Invoke-HTTargetAction -Module $m -Name 'Tymczasowy dostęp do skrzynki' -Targets $pairs -Label { param($p) $p.Label } -Action {
            param($p)
            Add-HTMailboxPermission -Identity $p.Mailbox -User $p.User -Type $types -AutoMapping $form.AutoMap
            [void](New-HTScheduledJob -Type 'RemoveMailboxPermission' -RunAt $until -Object $p.Label -Description $form.Reason -Data @{ Identity = $p.Mailbox; User = $p.User; Type = $types })
            "$($types -join ', ') do $($until.ToString('yyyy-MM-dd HH:mm'))"
        }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Lista i terminy: «Zadania zaplanowane». Program musi działać w terminie (albo Harmonogram Windows z HelpdeskToolsRunner.ps1 -RunJobs).' | Out-Null
}

Register-HTModule -Workspace 'Tasks' -Category 'Zadania zaplanowane' -Key 'tasks.offboard' -Title 'Zaplanowany offboarding' -Icon 'E8F8' `
    -Description 'Offboarding w wybranym terminie (np. ostatni dzień pracy o 17:00): kopia ustawień konta, blokada i wylogowanie, losowe hasło, autoodpowiedź i przekierowanie, skrzynka współdzielona, ukrycie w GAL, grupy i licencje.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Zaplanuj offboarding…' -Icon 'E8F8' -Primary -Danger -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'Graph')) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Zaplanowany offboarding')) { return }
        $user = Select-HTM365User -Title 'Zaplanowany offboarding' -Prompt 'Konto odchodzącego pracownika.'
        if (-not $user) { return }
        $form = Show-HTFormDialog -Title "Offboarding: $(Get-HTM365Label $user)" -Icon 'E8F8' -OkText 'Zaplanuj' -Danger -Width 620 -Fields @(
            @{ Name = 'When'; Label = 'Termin (RRRR-MM-DD GG:MM)'; Type = 'Date'; Default = (Get-Date).AddDays(1).ToString('yyyy-MM-dd 17:00') }
            @{ Type = 'Header'; Label = 'Kroki' }
            @{ Name = 'Backup'; Label = "Kopia ustawień konta do pliku przed zmianami (do przywrócenia konta; folder: $(Get-HTAccountBackupDirectory))"; Type = 'Check'; Default = $true }
            @{ Name = 'Block'; Label = 'Zablokuj logowanie i unieważnij sesje'; Type = 'Check'; Default = $true }
            @{ Name = 'Password'; Label = 'Losowe hasło'; Type = 'Check'; Default = $true }
            @{ Name = 'AutoReply'; Label = 'Autoodpowiedź - ta sama treść dla osób z firmy i spoza firmy (opcjonalnie, wymaga połączenia z Exchange w terminie)'; Type = 'Multiline'; Height = 50 }
            @{ Name = 'Forward'; Label = 'Przekieruj pocztę do (opcjonalnie)'; Validation = 'Email' }
            @{ Type = 'Buttons'; Buttons = @(@{ Text = 'Wybierz z tenanta…'; Icon = 'E716'; OnClick = { param($w) $address = Select-HTRecipientAddress; if ($address) { $w.Tag.Controls['Forward'].Control.Text = $address } } }) }
            @{ Name = 'Shared'; Label = 'Konwertuj na skrzynkę współdzieloną'; Type = 'Check'; Default = $true }
            @{ Name = 'Hide'; Label = 'Ukryj w książce adresowej'; Type = 'Check'; Default = $true }
            @{ Name = 'Groups'; Label = 'Usuń z grup'; Type = 'Check'; Default = $true }
            @{ Name = 'Licenses'; Label = 'Usuń licencje'; Type = 'Check'; Default = $false }
        )
        if (-not $form -or -not $form.When) { return }
        $when = [datetime]$form.When
        if (-not (Confirm-HTChange -Name 'Zaplanowany offboarding' -Labels @(Get-HTM365Label $user) -Danger -Confirm "Zaplanować offboarding na $($when.ToString('yyyy-MM-dd HH:mm'))? Kroki wykonają się automatycznie w tym terminie.")) { return }
        $steps = @{ Backup = [bool]$form.Backup; Block = [bool]$form.Block; Password = [bool]$form.Password; AutoReply = [string]$form.AutoReply; Forward = [string]$form.Forward; Shared = [bool]$form.Shared; Hide = [bool]$form.Hide; Groups = [bool]$form.Groups; Licenses = [bool]$form.Licenses }
        $job = New-HTScheduledJob -Type 'Offboarding' -RunAt $when -Object (Get-HTM365Label $user) -Description "Zaplanowany offboarding" -Data @{ UserId = $user.Id; Label = (Get-HTM365Label $user); Steps = $steps }
        Add-HTOperationRecord -Operation 'Zaplanowanie offboardingu' -Object (Get-HTM365Label $user) -Details $when.ToString('yyyy-MM-dd HH:mm') -Module $m.Title
        [void](Send-HTTeamsMessage -Event 'Offboarding' -Title 'Zaplanowano offboarding' -Tone 'warn' -Facts ([ordered]@{ Konto = (Get-HTM365Label $user); Termin = $when.ToString('yyyy-MM-dd HH:mm'); Zaplanował = $job.CreatedBy }))
        Show-HTToast "Zaplanowano offboarding na $($when.ToString('yyyy-MM-dd HH:mm'))." 'ok' 6
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Kroki pocztowe wymagają połączenia z Exchange w chwili wykonania. Dostęp przełożonego do OneDrive: Microsoft 365 > OneDrive odchodzącego.' | Out-Null
}
#endregion

#region Checklisty
$script:ChecklistEvents = @{
    Toggle = {
        param($s, $e)
        $tag = $s.Tag
        if ($tag.Updating) { return }
        try {
            $done = ($s.IsChecked -eq $true)
            $completed = Set-HTChecklistStep -Id $tag.Id -Index $tag.Index -Done $done
            Add-HTOperationRecord -Operation "Checklista: $($tag.Template)" -Object $tag.Subject -Status $(if ($done) { 'OK' } else { 'Cofnięto' }) -Details $tag.Text -Module 'Checklisty'
            if ($completed) {
                Show-HTToast "Checklista ukończona: $($tag.Subject)" 'ok' 6
                [void](Send-HTTeamsMessage -Event 'Checklists' -Title "Ukończono checklistę: $($tag.Template)" -Tone 'ok' -Facts ([ordered]@{ Osoba = $tag.Subject; Ukończył = "$env:USERNAME" }))
            }
        }
        catch { Show-HTError 'Nie zapisano kroku.' $_ }
    }
    Auto   = {
        param($s, $e)
        $tag = $s.Tag
        try {
            if (-not (Assert-HTWriteAllowed -Operation 'Krok automatyczny checklisty')) { return }
            if (-not $tag.SubjectId) { Show-HTWarning 'Checklista nie jest powiązana z kontem Microsoft 365.'; return }
            if (-not (Assert-HTConnection -Service 'Graph')) { return }
            Set-HTBusy -Busy $true -Text "$($tag.Text)…"
            try { $result = Invoke-HTChecklistAutoStep -Auto $tag.Auto -UserId $tag.SubjectId -Upn $tag.Subject }
            finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
            Add-HTOperationRecord -Operation $tag.Text -Object $tag.Subject -Details $result -Module 'Checklisty'
            [void](Set-HTChecklistStep -Id $tag.Id -Index $tag.Index -Done $true -Note $result)
            $tag.CheckBox.Tag.Updating = $true
            $tag.CheckBox.IsChecked = $true
            $tag.CheckBox.Tag.Updating = $false
            $tag.Info.Text = $result
            $s.IsEnabled = $false
            $c = @(Get-HTChecklists | Where-Object { $_.Id -eq $tag.Id })[0]
            if ($c -and $c.Completed) { [void](Send-HTTeamsMessage -Event 'Checklists' -Title "Ukończono checklistę: $($tag.Template)" -Tone 'ok' -Facts ([ordered]@{ Osoba = $tag.Subject })) }
            Show-HTToast $result 'ok'
        }
        catch { Show-HTError "Nie wykonano kroku: $($tag.Text)" $_ }
    }
}

function Show-HTChecklistWindow {
    param([Parameter(Mandatory)]$Checklist)
    $w = New-HTDialog -Title "Checklista: $($Checklist.Subject)" -Subtitle "$($Checklist.Template)$(if ($Checklist.Due) { " • termin: $(([datetime]$Checklist.Due).ToString('yyyy-MM-dd'))" })" -Body '<ScrollViewer MaxHeight="520" VerticalScrollBarVisibility="Auto"><StackPanel x:Name="clHost" Margin="0,0,6,0"/></ScrollViewer>' -Icon 'E9D5' -OkText 'Zamknij' -NoCancel -Width 760
    $hostPanel = $w.FindName('clHost')
    $auto = Get-HTChecklistAutoSteps
    $i = 0
    foreach ($step in @($Checklist.Steps)) {
        $grid = New-Object System.Windows.Controls.Grid
        $grid.Margin = '0,0,0,8'
        foreach ($width in '*', 'Auto') {
            $cd = New-Object System.Windows.Controls.ColumnDefinition
            $cd.Width = if ($width -eq '*') { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::Auto }
            [void]$grid.ColumnDefinitions.Add($cd)
        }
        $texts = New-Object System.Windows.Controls.StackPanel
        $cb = New-Object System.Windows.Controls.CheckBox
        $label = New-Object System.Windows.Controls.TextBlock
        $label.Text = [string]$step.Text
        $label.TextWrapping = 'Wrap'
        $cb.Content = $label
        $cb.IsChecked = [bool]$step.Done
        $info = New-Object System.Windows.Controls.TextBlock
        $info.Foreground = Get-HTBrush '#7B8496'
        $info.FontSize = 11.5
        $info.Margin = '26,2,0,0'
        $info.TextWrapping = 'Wrap'
        $info.Text = (@($(if ($step.Done) { "wykonano $(if ($step.DoneAt) { ([datetime]$step.DoneAt).ToString('yyyy-MM-dd HH:mm') }) $($step.DoneBy)" }), [string]$step.Note) | Where-Object { "$_".Trim() }) -join ' • '
        $cb.Tag = @{ Id = $Checklist.Id; Index = $i; Text = [string]$step.Text; Template = [string]$Checklist.Template; Subject = [string]$Checklist.Subject; Updating = $false }
        $cb.add_Checked($script:ChecklistEvents.Toggle)
        $cb.add_Unchecked($script:ChecklistEvents.Toggle)
        [void]$texts.Children.Add($cb)
        [void]$texts.Children.Add($info)
        [void]$grid.Children.Add($texts)
        if ($step.Auto) {
            $b = New-HTButton -Text 'Wykonaj' -Icon 'E768' -ToolTip "Krok automatyczny: $($auto[[string]$step.Auto])"
            $b.Margin = '12,0,0,0'
            $b.VerticalAlignment = 'Top'
            $b.IsEnabled = -not [bool]$step.Done
            $b.Tag = @{ Id = $Checklist.Id; Index = $i; Text = [string]$step.Text; Auto = [string]$step.Auto; Subject = [string]$Checklist.Subject; SubjectId = [string]$Checklist.SubjectId; Template = [string]$Checklist.Template; CheckBox = $cb; Info = $info }
            $b.add_Click($script:ChecklistEvents.Auto)
            [System.Windows.Controls.Grid]::SetColumn($b, 1)
            [void]$grid.Children.Add($b)
        }
        [void]$hostPanel.Children.Add($grid)
        $i++
    }
    [void](Invoke-HTDialog $w)
}

function Update-HTChecklistsView {
    param([Parameter(Mandatory)][hashtable]$Module)
    $all = Test-HTChecked $Module.C.All
    Invoke-HTQuery -Module $Module -Name 'Checklisty' -ScriptBlock {
        foreach ($c in @(Get-HTChecklists | Sort-Object { [datetime]$_.Created } -Descending)) {
            if (-not $all -and $c.Completed) { continue }
            $p = Get-HTChecklistProgress -Checklist $c
            $overdue = $c.Due -and -not $c.Completed -and ([datetime]$c.Due) -lt (Get-Date)
            [PSCustomObject]@{
                Osoba      = $c.Subject
                Checklista = $c.Template
                Rodzaj     = $c.Kind
                Postęp     = "$($p.Done) / $($p.Total) ($($p.Percent)%)"
                Termin     = $(if ($c.Due) { ([datetime]$c.Due) } else { $null })
                Ukończono  = $(if ($c.Completed) { [datetime]$c.Completed } else { $null })
                Utworzono  = [datetime]$c.Created
                Utworzył   = $c.CreatedBy
                Id         = $c.Id
                __checklist = $c
                __flag     = if ($overdue) { 'crit' } elseif ($c.Completed) { 'muted' } else { '' }
            }
        }
    }
}

Register-HTModule -Workspace 'Tasks' -Category 'Checklisty' -Key 'tasks.checklists' -Title 'Checklisty on/offboardingu' -Icon 'E9D5' `
    -Description 'Lista kroków dla nowego i odchodzącego pracownika z postępem i terminem: kroki ręczne (sprzęt, systemy dziedzinowe) i automatyczne (blokada, grupy, licencje, skrzynka). Szablony do edycji. Ukończenie - powiadomienie Teams.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.All = Add-HTCheckBox -Parent $row -Text 'Także ukończone'
    Add-HTButton -Parent $row -Module $m -Text 'Nowa checklista…' -Create -NoRowMenu -Icon 'E710' -Primary -OnClick {
        param($m)
        $templates = @(Get-HTChecklistTemplates)
        $choice = Show-HTChoiceDialog -Title 'Nowa checklista' -Prompt 'Wybierz szablon.' -Icon 'E9D5' -Choices @($templates | ForEach-Object { @{ Key = $_.Id; Text = $_.Name; Icon = $(if ($_.Kind -eq 'Offboarding') { 'E8F8' } else { 'E8FA' }); Description = "$(@($_.Steps).Count) kroków • $($_.Kind)" } })
        $template = @($templates | Where-Object { $_.Id -eq $choice })[0]
        if (-not $template) { return }
        $subject = ''
        $subjectId = ''
        if ($Global:ConnectedToGraphAPI -and (Show-HTConfirm -Title 'Konto' -ConfirmText 'Wybierz konto' -Message 'Powiązać checklistę z kontem Microsoft 365? (kroki automatyczne - blokada, grupy, licencje - działają tylko dla powiązanego konta)')) {
            $u = Select-HTM365User -Title 'Konto' -Prompt "Checklista: $($template.Name)"
            if ($u) { $subject = Get-HTM365Label $u; $subjectId = $u.Id }
        }
        if (-not $subject) {
            $subject = Show-InputBox -Title 'Osoba' -Prompt 'Imię i nazwisko lub adres osoby:' -Icon 'E77B'
            if (-not $subject) { return }
        }
        $form = Show-HTFormDialog -Title 'Termin' -Icon 'E787' -OkText 'Utwórz' -Fields @(@{ Name = 'Due'; Label = 'Termin wykonania (opcjonalnie)'; Type = 'Date'; Optional = $true })
        if ($null -eq $form) { return }
        [void](New-HTChecklist -Template $template -Subject $subject -SubjectId $subjectId -Due $form.Due)
        Add-HTOperationRecord -Operation 'Nowa checklista' -Object $subject -Details $template.Name -Module 'Checklisty'
        Update-HTChecklistsView -Module $m
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Szablony…' -Icon 'E70F' -OnClick {
        param($m)
        $templates = @(Get-HTChecklistTemplates)
        $choices = @($templates | ForEach-Object { @{ Key = $_.Id; Text = $_.Name; Icon = 'E70F'; Description = "$(@($_.Steps).Count) kroków • $($_.Kind)" } }) + @(@{ Key = '__new'; Text = 'Nowy szablon…'; Icon = 'E710'; Style = 'Create' })
        $choice = Show-HTChoiceDialog -Title 'Szablony checklist' -Prompt 'Wybierz szablon do edycji.' -Icon 'E70F' -Choices $choices
        if (-not $choice) { return }
        $template = if ($choice -eq '__new') { [ordered]@{ Id = [guid]::NewGuid().ToString('N'); Name = ''; Kind = 'Onboarding'; Steps = @() } } else { @($templates | Where-Object { $_.Id -eq $choice })[0] }
        $keys = (@((Get-HTChecklistAutoSteps).GetEnumerator() | ForEach-Object { "$($_.Key) - $($_.Value)" }) -join '; ')
        $form = Show-HTFormDialog -Title 'Szablon checklisty' -Icon 'E70F' -Width 680 -Fields @(
            @{ Name = 'Name'; Label = 'Nazwa'; Required = $true; Default = [string]$template.Name }
            @{ Name = 'Kind'; Label = 'Rodzaj'; Type = 'Combo'; Options = @('Onboarding', 'Offboarding', 'Inne'); Default = [string]$template.Kind }
            @{ Name = 'Steps'; Label = 'Kroki (jeden w linii; automatyczny: [auto:Nazwa] Opis)'; Type = 'Multiline'; Required = $true; Height = 220; Default = (ConvertTo-HTChecklistText -Steps @($template.Steps)) }
            @{ Type = 'Info'; Label = "Kroki automatyczne: $keys." }
            @{ Name = 'Delete'; Label = 'Usuń ten szablon'; Type = 'Check'; Default = $false }
        )
        if (-not $form) { return }
        $others = @($templates | Where-Object { $_.Id -ne $template.Id })
        if ($form.Delete) { Save-HTChecklistTemplates -Templates $others; Show-HTToast 'Usunięto szablon.' 'ok'; return }
        $template.Name = $form.Name
        $template.Kind = $form.Kind
        $template.Steps = @(ConvertFrom-HTChecklistText -Text $form.Steps)
        Save-HTChecklistTemplates -Templates @($others + @($template))
        Show-HTToast "Zapisano szablon «$($form.Name)»." 'ok'
    } | Out-Null
    $m.OnShow = { param($m) Update-HTChecklistsView -Module $m }
    Add-HTRowAction -Module $m -Text 'Otwórz checklistę' -Icon 'E9D5' -Action {
        param($m, $rows)
        $c = @($rows)[0].__checklist
        $fresh = @(Get-HTChecklists | Where-Object { $_.Id -eq $c.Id })[0]
        if ($fresh) { Show-HTChecklistWindow -Checklist $fresh }
        Update-HTChecklistsView -Module $m
    }
    Add-HTRowAction -Module $m -Text 'Usuń checklistę' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        if (-not (Show-HTConfirm -Title 'Usuwanie checklist' -Message 'Usunąć zaznaczone checklisty?' -Items @($rows | ForEach-Object { "$($_.Osoba) - $($_.Checklista)" }))) { return }
        foreach ($r in $rows) { Remove-HTChecklist -Id $r.Id }
        Update-HTChecklistsView -Module $m
    }
}
#endregion

#region Migawki, cofanie zmian, historia obiektu
Register-HTModule -Workspace 'Tasks' -Category 'Zmiany i historia' -Key 'tasks.snapshots' -Title 'Migawki i porównanie' -Icon 'E722' `
    -Description 'Zapis stanu konfiguracji (role administracyjne, dostęp warunkowy, członkowie grup, licencje, przekierowania skrzynek, sekrety aplikacji) i porównanie: co zostało dodane, usunięte i zmienione od migawki.' -Build {
    param($m)
    $defs = Get-HTSnapshotDefinitions
    $m.Data.Kinds = @($defs.Keys)
    $row = Add-HTToolbarRow -Module $m
    $m.C.Kind = Add-HTComboBox -Parent $row -Width 300 -Items @($defs.Keys | ForEach-Object { $defs[$_].Title })
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz migawkę' -Icon 'E722' -Primary -OnClick {
        param($m)
        $kind = $m.Data.Kinds[$m.C.Kind.SelectedIndex]
        $def = (Get-HTSnapshotDefinitions)[$kind]
        if (-not (Assert-HTConnection -Service $def.Service)) { return }
        Invoke-HTQuery -Module $m -Name "Migawka: $($def.Title)" -Background:($def.Service -eq 'Graph') -Arguments @{ Kind = $kind } -ScriptBlock {
            param($a)
            $path = New-HTSnapshot -Kind $a.Kind
            Get-HTSnapshots -Kind $a.Kind | Select-Object -First 10 | ForEach-Object { [PSCustomObject]@{ Migawka = $_.Data; Plik = $_.Plik; 'Rozmiar (KB)' = $_.'Rozmiar (KB)'; Nowa = ($_.Ścieżka -eq $path); Ścieżka = $_.Ścieżka } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Porównaj z bieżącym stanem…' -Icon 'E8AB' -OnClick {
        param($m)
        $kind = $m.Data.Kinds[$m.C.Kind.SelectedIndex]
        $def = (Get-HTSnapshotDefinitions)[$kind]
        $list = @(Get-HTSnapshots -Kind $kind)
        if (-not $list.Count) { Show-HTWarning 'Brak migawek tego rodzaju - najpierw utwórz migawkę.'; return }
        $selected = @(Show-HTSelectionDialog -Title 'Migawka' -Prompt 'Porównaj bieżący stan z migawką:' -Items $list -Columns @(@{ Text = 'Data'; Property = 'Data' }, @{ Text = 'Plik'; Property = 'Plik' }, @{ Text = 'Rozmiar (KB)'; Property = 'Rozmiar (KB)' }) -Icon 'E722')[0]
        if (-not $selected) { return }
        if (-not (Assert-HTConnection -Service $def.Service)) { return }
        Invoke-HTQuery -Module $m -Name "Zmiany od $($selected.Data.ToString('yyyy-MM-dd HH:mm')): $($def.Title)" -Background:($def.Service -eq 'Graph') -Arguments @{ Kind = $kind; Path = $selected.Ścieżka } -ScriptBlock {
            param($a)
            $old = @((Read-HTSnapshot -Path $a.Path).Records)
            Compare-HTSnapshot -Old $old -New @(Get-HTSnapshotRecords -Kind $a.Kind)
        }
        if ($m.Table.Rows.Count -eq 0) { Show-HTToast 'Brak zmian od wybranej migawki.' 'ok' }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Porównaj dwie migawki…' -Icon 'E8F1' -OnClick {
        param($m)
        $kind = $m.Data.Kinds[$m.C.Kind.SelectedIndex]
        $list = @(Get-HTSnapshots -Kind $kind)
        if ($list.Count -lt 2) { Show-HTWarning 'Potrzebne są co najmniej dwie migawki tego rodzaju.'; return }
        $selected = @(Show-HTSelectionDialog -Title 'Dwie migawki' -Prompt 'Zaznacz dwie migawki do porównania.' -Items $list -Columns @(@{ Text = 'Data'; Property = 'Data' }, @{ Text = 'Plik'; Property = 'Plik' }) -MultiSelect -Icon 'E722')
        if ($selected.Count -ne 2) { if ($selected.Count) { Show-HTWarning 'Zaznacz dokładnie dwie migawki.' }; return }
        $ordered = @($selected | Sort-Object Data)
        Invoke-HTQuery -Module $m -Name "Zmiany $($ordered[0].Data.ToString('yyyy-MM-dd')) → $($ordered[1].Data.ToString('yyyy-MM-dd'))" -Service '' -ScriptBlock {
            Compare-HTSnapshot -Old @((Read-HTSnapshot -Path $ordered[0].Ścieżka).Records) -New @((Read-HTSnapshot -Path $ordered[1].Ścieżka).Records)
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Folder migawek' -Icon 'E838' -OnClick {
        param($m)
        $dir = Get-HTSnapshotDirectory -Kind $m.Data.Kinds[$m.C.Kind.SelectedIndex]
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $dir)
    } | Out-Null
}

function Update-HTUndoView {
    param([Parameter(Mandatory)][hashtable]$Module)
    $kinds = Get-HTUndoKinds
    $all = Test-HTChecked $Module.C.All
    Invoke-HTQuery -Module $Module -Name 'Zmiany do cofnięcia' -Service '' -ScriptBlock {
        foreach ($r in @(Get-HTUndoRecords)) {
            if (-not $all -and $r.Undone) { continue }
            $k = $kinds[[string]$r.Kind]
            [PSCustomObject]@{
                Czas        = [datetime]$r.Time
                Operacja    = $r.Operation
                Obiekt      = $r.Object
                Cofnięcie   = $k.Title
                Wymaga      = $k.Service
                Konto       = $r.Account
                Stan        = $(if ($r.Undone) { "cofnięto $(([datetime]$r.Undone).ToString('yyyy-MM-dd HH:mm'))" } else { 'do cofnięcia' })
                Wynik       = $r.UndoResult
                Id          = $r.Id
                __flag      = if ($r.Undone) { 'muted' } else { '' }
            }
        }
    }
}

Register-HTModule -Workspace 'Tasks' -Category 'Zmiany i historia' -Key 'tasks.undo' -Title 'Cofanie zmian' -Icon 'E7A7' `
    -Description 'Zmiany wykonane w programie, które można odwrócić jednym kliknięciem: blokada konta, usunięcie licencji lub z grupy, przełożony, uprawnienia do skrzynek, reguły transportu, archiwizacja zespołu, urządzenia i izolacja.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.All = Add-HTCheckBox -Parent $row -Text 'Także cofnięte'
    Add-HTButton -Parent $row -Module $m -Text 'Odśwież' -Icon 'E72C' -Primary -OnClick { param($m) Update-HTUndoView -Module $m } | Out-Null
    $m.OnShow = { param($m) Update-HTUndoView -Module $m }
    Add-HTRowAction -Module $m -Text 'Cofnij zmianę' -Icon 'E7A7' -Danger -Action {
        param($m, $rows)
        $items = @($rows | Where-Object { $_.Stan -eq 'do cofnięcia' })
        foreach ($service in @($items | ForEach-Object { $_.Wymaga } | Select-Object -Unique)) {
            if ($service -in 'Graph', 'Exchange' -and -not (Assert-HTConnection -Service $service)) { return }
        }
        Invoke-HTRowAction -Module $m -Name 'Cofnięcie zmiany' -Rows $items -Confirm 'Cofnąć zaznaczone zmiany?' -Label { param($r) "$($r.Operacja): $($r.Obiekt)" } -Action { param($r) Invoke-HTUndo -Id $r.Id } -Refresh { param($m) Update-HTUndoView -Module $m }
    }
}

function Find-HTObjectHistory {
    # Wpisy dziennika (pliki z -Days dni), operacje tej sesji i rejestr zmian dotyczące obiektu
    param([Parameter(Mandatory)][string]$Text, [int]$Days = 30)
    $since = (Get-Date).Date.AddDays(-$Days)
    foreach ($f in @(Get-HTLogFiles | Where-Object { $_.Date -ge $since })) {
        foreach ($e in @(Read-HTLogFile -Path $f.Path -Text $Text)) {
            [PSCustomObject]@{ Czas = $e.Czas; Źródło = 'dziennik'; Poziom = $e.Poziom; Konto = $e.Konto; Opis = $e.Komunikat; __flag = $e.__flag }
        }
    }
    foreach ($r in @(Get-HTOperationRecords -Object $Text)) {
        [PSCustomObject]@{ Czas = $r.Time.ToString('yyyy-MM-dd HH:mm:ss'); Źródło = 'ta sesja'; Poziom = $r.Status; Konto = $r.Account; Opis = "$(if ((Get-HTOperationKind $r) -eq 'Check') { 'Sprawdzenie: ' })$($r.Operation): $($r.Object) $(if ($r.Details) { "- $($r.Details)" })"; __flag = $(if ($r.Status -ne 'OK') { 'warn' } else { '' }) }
    }
    foreach ($u in @(Get-HTUndoRecords | Where-Object { "$($_.Object)".IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0 })) {
        [PSCustomObject]@{ Czas = ([datetime]$u.Time).ToString('yyyy-MM-dd HH:mm:ss'); Źródło = 'rejestr zmian'; Poziom = $(if ($u.Undone) { 'cofnięto' } else { 'zmiana' }); Konto = $u.Account; Opis = "$($u.Operation): $($u.Object)"; __flag = '' }
    }
}

Register-HTModule -Workspace 'Tasks' -Category 'Zmiany i historia' -Key 'tasks.history' -Title 'Historia obiektu' -Icon 'E81C' `
    -Description 'Wszystko, co program zrobił z kontem, skrzynką, grupą lub urządzeniem: wpisy dziennika z ostatnich dni (kto, kiedy, co), operacje tej sesji i rejestr zmian.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.Text = Add-HTTextBox -Parent $row -Width 320 -Placeholder 'UPN, adres, nazwa grupy lub urządzenia'
    Add-HTLabel -Parent $row -Text 'Dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 30 -Minimum 1 -Maximum 365
    Add-HTButton -Parent $row -Module $m -Text 'Szukaj' -Icon 'E721' -Primary -OnClick {
        param($m)
        $text = $m.C.Text.Text.Trim()
        if ($text.Length -lt 3) { Show-HTWarning 'Wpisz co najmniej 3 znaki.'; return }
        $days = Get-HTNum $m.C.Days
        Invoke-HTQuery -Module $m -Name "Historia: $text" -Service '' -ScriptBlock { Find-HTObjectHistory -Text $text -Days $days | Sort-Object Czas -Descending }
    } | Out-Null
}
#endregion

#region Raporty zaplanowane (bez okna)
function Get-HTAutomationStatusRows {
    $cfg = $Global:HTConfig
    $thumb = [string]$cfg.AutomationCertificateThumbprint
    $cert = if ($thumb) { Get-ChildItem -Path "Cert:\CurrentUser\My\$thumb" -ErrorAction SilentlyContinue } else { $null }
    $task = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like 'Helpdesk Tools*' })
    @(
        [PSCustomObject]@{ Ustawienie = 'Aplikacja automatyzacji (Client ID)'; Wartość = $(if ($cfg.AutomationClientId) { $cfg.AutomationClientId } else { '(brak - «Utwórz aplikację»)' }); __flag = $(if (-not $cfg.AutomationClientId) { 'warn' } else { '' }) }
        [PSCustomObject]@{ Ustawienie = 'Tenant ID'; Wartość = [string]$cfg.AutomationTenantId; __flag = '' }
        [PSCustomObject]@{ Ustawienie = 'Certyfikat'; Wartość = $(if ($cert) { "$thumb (ważny do $($cert.NotAfter.ToString('yyyy-MM-dd')))" } elseif ($thumb) { "$thumb - brak w magazynie CurrentUser\My" } else { '(brak)' }); __flag = $(if (-not $cert) { 'warn' } elseif ($cert.NotAfter -lt (Get-Date).AddDays(30)) { 'warn' } else { '' }) }
        [PSCustomObject]@{ Ustawienie = 'Organizacja Exchange'; Wartość = [string]$cfg.AutomationOrganization; __flag = '' }
        [PSCustomObject]@{ Ustawienie = 'Nadawca raportów'; Wartość = $(if ($cfg.ReportSender) { $cfg.ReportSender } else { '(brak - Ustawienia > Teams i e-mail)' }); __flag = $(if (-not $cfg.ReportSender) { 'warn' } else { '' }) }
        foreach ($t in $task) { [PSCustomObject]@{ Ustawienie = "Zadanie Harmonogramu: $($t.TaskName)"; Wartość = "$($t.State) • $(($t.Actions | Select-Object -First 1).Arguments)"; __flag = '' } }
    )
}

Register-HTModule -Workspace 'Tasks' -Category 'Automatyzacja' -Key 'tasks.reports' -Title 'Raporty zaplanowane' -Icon 'E9D2' `
    -Description 'Raporty e-mailem (Excel) i zadania zaplanowane bez otwierania programu: aplikacja automatyzacji z certyfikatem, HelpdeskToolsRunner.ps1 i zadanie Harmonogramu Windows.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Stan konfiguracji' -Icon 'E946' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Automatyzacja' -Service '' -ScriptBlock { Get-HTAutomationStatusRows } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz aplikację automatyzacji…' -Create -NoRowMenu -Icon 'E8D7' -OnClick {
        param($m)
        if (-not (Assert-HTWriteAllowed -Operation 'Aplikacja automatyzacji')) { return }
        $form = Show-HTFormDialog -Title 'Aplikacja automatyzacji' -Icon 'E8D7' -OkText 'Utwórz' -Description 'Rejestracja aplikacji z certyfikatem (magazyn CurrentUser\My), uprawnieniami aplikacji Microsoft Graph (odczyt raportów, Mail.Send, zarządzanie grupami i kontami dla zadań) i Exchange.ManageAsApp. Wymaga roli Global Administrator.' -Fields @(
            @{ Name = 'Name'; Label = 'Nazwa aplikacji'; Default = 'Helpdesk Tools - automatyzacja'; Required = $true }
            @{ Name = 'Years'; Label = 'Ważność certyfikatu (lata)'; Type = 'Number'; Default = 2; Min = 1; Max = 5 }
            @{ Name = 'UserAdmin'; Label = 'Rola User Administrator (zaplanowany offboarding bez okna)'; Type = 'Check'; Default = $false }
        )
        if (-not $form) { return }
        if (-not (Assert-HTGraphScopes -Scopes @('Application.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All', 'RoleManagement.ReadWrite.Directory') -Feature 'Tworzenie aplikacji automatyzacji')) { return }
        Set-HTBusy -Busy $true -Text 'Tworzenie aplikacji automatyzacji…'
        try { $app = New-HTAutomationApp -DisplayName $form.Name -CertificateYears ([int]$form.Years) -UserAdministrator:([bool]$form.UserAdmin) }
        catch { Show-HTError 'Nie utworzono aplikacji.' $_; return }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        foreach ($pair in @(@('AutomationClientId', $app.ClientId), @('AutomationTenantId', $app.TenantId), @('AutomationCertificateThumbprint', $app.Thumbprint), @('AutomationOrganization', $app.Organization))) { Set-HTConfigValue -Name $pair[0] -Value $pair[1] }
        Add-HTOperationRecord -Operation 'Utworzenie aplikacji automatyzacji' -Object $form.Name -Details "Client ID $($app.ClientId)" -Module $m.Title
        Show-HTMessage -Title 'Aplikacja automatyzacji' -Tone 'ok' -Text "Utworzono aplikację.`nClient ID: $($app.ClientId)`nCertyfikat: $($app.Thumbprint) (do $($app.Expires.ToString('yyyy-MM-dd')))`nUprawnień z zgodą: $($app.Granted)`n`nUstawienia zapisano. Uprawnienia mogą zacząć działać po kilku minutach."
        Invoke-HTModulePrimary $m
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Zaplanuj raporty…' -Create -NoRowMenu -Icon 'E787' -OnClick {
        param($m)
        $catalog = Get-HTHeadlessReports
        $items = @($catalog.Keys | ForEach-Object { [PSCustomObject]@{ Raport = $catalog[$_].Title; Nazwa = $_; Usługa = $catalog[$_].Service } })
        $selected = @(Show-HTSelectionDialog -Title 'Raporty' -Prompt 'Raporty wysyłane e-mailem (Excel).' -Items $items -MultiSelect -Icon 'E9D2')
        $kinds = Get-HTSnapshotDefinitions
        $form = Show-HTFormDialog -Title 'Raporty zaplanowane' -Icon 'E787' -OkText 'Utwórz zadanie' -Width 620 -Fields @(
            @{ Name = 'To'; Label = 'Odbiorcy (adresy, przecinek lub nowa linia)'; Type = 'Multiline'; Height = 50; Required = ($selected.Count -gt 0) }
            @{ Name = 'Schedule'; Label = 'Częstotliwość'; Type = 'Combo'; Options = @('Weekly', 'Daily', 'Hourly') }
            @{ Name = 'Day'; Label = 'Dzień tygodnia (Weekly)'; Type = 'Combo'; Options = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday') }
            @{ Name = 'Time'; Label = 'Godzina (GG:MM)'; Default = '07:30' }
            @{ Name = 'Jobs'; Label = 'Wykonuj zadania zaplanowane (uprawnienia tymczasowe, offboarding)'; Type = 'Check'; Default = $true }
            @{ Name = 'Snapshots'; Label = "Migawki ze zmianami (nazwy po przecinku: $(@($kinds.Keys) -join ', '))"; Default = 'AdminRoles,ConditionalAccess' }
            @{ Name = 'Name'; Label = 'Nazwa zadania Harmonogramu Windows'; Default = 'Helpdesk Tools - raporty' }
        )
        if (-not $form) { return }
        if ($form.Time -notmatch '^\d{2}:\d{2}$') { Show-HTWarning 'Godzina w formacie GG:MM.'; return }
        $runner = Join-Path (Split-Path -Parent $Global:HTScriptPath) 'HelpdeskToolsRunner.ps1'
        try {
            $name = New-HTRunnerScheduledTask -RunnerPath $runner -TaskName $form.Name -Reports @($selected | ForEach-Object { $_.Nazwa }) -To @(Split-HTInputList $form.To) -RunJobs:([bool]$form.Jobs) -Snapshots @(Split-HTInputList $form.Snapshots | Where-Object { $kinds.Contains($_) }) -Schedule $form.Schedule -DayOfWeek $form.Day -Time $form.Time
            Add-HTOperationRecord -Operation 'Zadanie Harmonogramu Windows' -Object $name -Details "$($form.Schedule) $($form.Time)" -Module $m.Title
            Show-HTToast "Utworzono zadanie Harmonogramu «$name»." 'ok' 6
            Invoke-HTModulePrimary $m
        }
        catch { Show-HTError 'Nie utworzono zadania Harmonogramu Windows.' $_ }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Uruchom test' -Icon 'E768' -OnClick {
        param($m)
        $runner = Join-Path (Split-Path -Parent $Global:HTScriptPath) 'HelpdeskToolsRunner.ps1'
        $report = @((Get-HTHeadlessReports).Keys)[0]
        $to = Show-InputBox -Title 'Test raportów' -Prompt "Adres do wysyłki testowej (raport «$report»; puste - bez wysyłki, tylko połączenie):" -AllowEmpty -Icon 'E768'
        if ($null -eq $to) { return }
        $runArgs = @('-NoProfile', '-File', "`"$runner`"", '-Report', $report)
        if ($to) { $runArgs += @('-To', $to) }
        Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $runArgs -WindowStyle Hidden
        Show-HTToast 'Uruchomiono test w tle - wynik w dzienniku (Pulpit > Dziennik programu).' 'info' 6
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń zadanie Harmonogramu' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        foreach ($r in @($rows | Where-Object { $_.Ustawienie -like 'Zadanie Harmonogramu:*' })) {
            $name = $r.Ustawienie -replace '^Zadanie Harmonogramu:\s*', ''
            if (Show-HTConfirm -Title 'Harmonogram Windows' -Message "Usunąć zadanie «$name»?") { Unregister-ScheduledTask -TaskName $name -Confirm:$false; Add-HTOperationRecord -Operation 'Usunięcie zadania Harmonogramu' -Object $name -Module $m.Title }
        }
        Invoke-HTModulePrimary $m
    }
}
#endregion

Register-HTPaletteAction -Text 'Historia obiektu' -Icon 'E81C' -Description 'Dziennik, operacje tej sesji i rejestr zmian dotyczące obiektu' -NeedsQuery -Action {
    param($q)
    Show-HTDataViewer -Title "Historia: $q" -Data @(Find-HTObjectHistory -Text $q -Days 90 | Sort-Object Czas -Descending) -ExportName 'historia' -Icon 'E81C'
}
Register-HTPaletteAction -Text 'Cofnij ostatnią zmianę' -Icon 'E7A7' -Description 'Przestrzeń Zadania > Cofanie zmian' -Keywords 'undo cofnij przywróć' -Action { param($q) Show-HTModule -Key 'tasks.undo' }
Register-HTPaletteAction -Text 'Zaplanuj offboarding' -Icon 'E8F8' -Description 'Offboarding w wybranym terminie' -Keywords 'odejście pracownik termin' -Action { param($q) Show-HTModule -Key 'tasks.offboard' }
Register-HTPaletteAction -Text 'Uprawnienia tymczasowe' -Icon 'E916' -Description 'Członkostwo lub dostęp do skrzynki na określony czas' -Keywords 'zastępstwo urlop czasowe' -Action { param($q) Show-HTModule -Key 'tasks.temp' }
