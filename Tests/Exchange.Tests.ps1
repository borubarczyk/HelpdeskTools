BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    New-HTTestStub -Name "Set-MailboxAutoReplyConfiguration" -Parameters "Identity", "AutoReplyState", "InternalMessage", "ExternalMessage", "ExternalAudience", "StartTime", "EndTime"
    New-HTTestStub -Name "Set-Mailbox" -Parameters "Identity", "ForwardingSmtpAddress", "ForwardingAddress", "DeliverToMailboxAndForward", "Confirm"
    Import-HTTestModule -Name "Utils", "MailboxesExchangeOnline"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Konwersja treści autoodpowiedzi" {
    It "zamienia tekst na HTML z kodowaniem znaków i nowymi liniami" {
        ConvertTo-HTAutoReplyHtml "Jestem na urlopie <do 10.05>`r`nPozdrawiam" | Should -Be "Jestem na urlopie &lt;do 10.05&gt;<br>Pozdrawiam"
    }
    It "nie zmienia treści, która jest już HTML" {
        ConvertTo-HTAutoReplyHtml "<p>Tekst</p>" | Should -Be "<p>Tekst</p>"
    }
    It "zamienia HTML z powrotem na tekst" {
        ConvertFrom-HTAutoReplyHtml "<html><body>Linia 1<br>Linia &amp; 2</body></html>" | Should -Be "Linia 1`r`nLinia & 2"
    }
}

Describe "Set-HTMailboxAutoReply" {
    BeforeEach { Mock -ModuleName MailboxesExchangeOnline Set-MailboxAutoReplyConfiguration { } }

    It "wymaga dat dla trybu Scheduled" {
        { Set-HTMailboxAutoReply -Identity "a@b.pl" -State Scheduled -InternalMessage "x" } | Should -Throw
    }
    It "odrzuca datę końca wcześniejszą niż początek" {
        { Set-HTMailboxAutoReply -Identity "a@b.pl" -State Scheduled -InternalMessage "x" -StartTime (Get-Date) -EndTime (Get-Date).AddDays(-1) } | Should -Throw
    }
    It "używa treści wewnętrznej jako zewnętrznej, gdy brak zewnętrznej" {
        Set-HTMailboxAutoReply -Identity "a@b.pl" -State Enabled -InternalMessage "Urlop"
        Should -Invoke -ModuleName MailboxesExchangeOnline Set-MailboxAutoReplyConfiguration -Times 1 -ParameterFilter { $ExternalMessage -eq "Urlop" -and $AutoReplyState -eq "Enabled" }
    }
    It "wyłącza autoodpowiedź bez wysyłania treści" {
        Set-HTMailboxAutoReply -Identity "a@b.pl" -State Disabled
        Should -Invoke -ModuleName MailboxesExchangeOnline Set-MailboxAutoReplyConfiguration -Times 1 -ParameterFilter { $AutoReplyState -eq "Disabled" -and -not $PSBoundParameters.ContainsKey("InternalMessage") }
    }
}

Describe "Set-HTMailboxForwarding" {
    BeforeEach { Mock -ModuleName MailboxesExchangeOnline Set-Mailbox { } }
    It "ustawia przekierowanie SMTP" {
        Set-HTMailboxForwarding -Identity "a@b.pl" -ForwardTo "c@d.pl" -KeepCopy $true
        Should -Invoke -ModuleName MailboxesExchangeOnline Set-Mailbox -ParameterFilter { $ForwardingSmtpAddress -eq "smtp:c@d.pl" -and $DeliverToMailboxAndForward -eq $true }
    }
    It "czyści przekierowanie dla pustego adresu" {
        Set-HTMailboxForwarding -Identity "a@b.pl" -ForwardTo ""
        Should -Invoke -ModuleName MailboxesExchangeOnline Set-Mailbox -ParameterFilter { $null -eq $ForwardingSmtpAddress -and $DeliverToMailboxAndForward -eq $false }
    }
}

Describe "ConvertFrom-HTExchangeSize" {
    It "odczytuje liczbę bajtów z opisu rozmiaru Exchange" {
        ConvertFrom-HTExchangeSize "1.234 GB (1,325,000,000 bytes)" | Should -Be 1325000000
        ConvertFrom-HTExchangeSize "49.5 GB (53 150 220 288 bytes)" | Should -Be 53150220288
        ConvertFrom-HTExchangeSize "Unlimited" | Should -BeNullOrEmpty
        ConvertFrom-HTExchangeSize $null | Should -BeNullOrEmpty
        ConvertFrom-HTExchangeSize "1024" | Should -Be 1024
    }
}

Describe "Adresy e-mail skrzynki" {
    BeforeAll { New-HTTestStub -Name "Set-Mailbox" -Parameters "Identity", "EmailAddresses", "Confirm" }
    It "nie pozwala usunąć adresu głównego" {
        { Remove-HTMailboxAddress -Identity "a@x.pl" -Value "SMTP:a@x.pl" } | Should -Throw "*głównego*"
    }
    It "odrzuca nieprawidłowy alias" {
        { Add-HTMailboxAddress -Identity "a@x.pl" -Address "zly-adres" } | Should -Throw "*Nieprawidłowy*"
    }
}

Describe "Skrzynki systemowe (DiscoverySearchMailbox)" {
    BeforeAll {
        New-HTTestStub -Name "Get-EXOMailbox" -Parameters "ResultSize", "Properties", "RecipientTypeDetails", "ErrorAction"
    }
    BeforeEach {
        Mock -ModuleName MailboxesExchangeOnline Get-EXOMailbox {
            @(
                [PSCustomObject]@{ DisplayName = 'Jan'; PrimarySmtpAddress = 'jan@firma.pl'; Name = 'jan'; RecipientTypeDetails = 'UserMailbox' }
                [PSCustomObject]@{ DisplayName = 'Discovery Search Mailbox'; PrimarySmtpAddress = 'DiscoverySearchMailbox{D919BA05}@firma.onmicrosoft.com'; Name = 'DiscoverySearchMailbox{D919BA05}'; RecipientTypeDetails = 'DiscoveryMailbox' }
            )
        }
    }
    AfterEach { $Global:ShowSystemMailboxes = $null }

    It "domyślnie ukrywa skrzynkę eDiscovery na liście skrzynek i w podsumowaniu" {
        $Global:ShowSystemMailboxes = $false
        @(Get-HTMailboxes).PrimarySmtpAddress | Should -Be @('jan@firma.pl')
        (Get-HTMailboxSummary).Total | Should -Be 1
    }
    It "rozpoznaje skrzynki systemowe po typie, aliasie i nazwie wyświetlanej" {
        Test-HTSystemMailbox ([PSCustomObject]@{ RecipientTypeDetails = 'ArbitrationMailbox'; PrimarySmtpAddress = 'SystemMailbox{1f05a927}@x.pl' }) | Should -BeTrue
        Test-HTSystemMailbox ([PSCustomObject]@{ RecipientTypeDetails = 'UserMailbox'; Alias = 'DiscoverySearchMailbox{D919BA05}' }) | Should -BeTrue
        Test-HTSystemMailbox ([PSCustomObject]@{ RecipientTypeDetails = 'UserMailbox'; DisplayName = 'Discovery Search Mailbox' }) | Should -BeTrue
        Test-HTSystemMailbox ([PSCustomObject]@{ RecipientTypeDetails = 'SharedMailbox'; PrimarySmtpAddress = 'discovery@firma.pl'; DisplayName = 'Dział Discovery' }) | Should -BeFalse
    }
    It "pokazuje ją po włączeniu ustawienia albo z -IncludeSystem" {
        @(Get-HTMailboxes -IncludeSystem).Count | Should -Be 2
        $Global:ShowSystemMailboxes = $true
        @(Get-HTMailboxes).Count | Should -Be 2
    }
    AfterAll { Remove-Item -LiteralPath Function:Get-EXOMailbox -ErrorAction SilentlyContinue }
}

Describe "Zestawienie skrzynki (wiersz = skrzynka)" {
    It "zamienia okres i rozmiar Exchange na czytelny tekst" {
        ConvertTo-HTDaysText "14.00:00:00" | Should -Be "14 dni"
        ConvertTo-HTDaysText ([TimeSpan]::FromDays(1)) | Should -Be "1 dzień"
        ConvertTo-HTShortSize "93.99 MB (98,558,115 bytes)" | Should -Be "93.99 MB"
        ConvertTo-HTShortSize "Unlimited" | Should -Be "Unlimited"
    }
    It "buduje jeden wiersz ze szczegółów skrzynki i zachowuje szczegóły do podglądu" {
        $detail = [ordered]@{
            "Nazwa wyświetlana" = "Jan"; "Adres główny" = "jan@firma.pl"; "Typ skrzynki" = "UserMailbox"; "Ukryta w GAL" = $false
            "Rozmiar i limity" = [ordered]@{ "Rozmiar" = "93.99 MB (98,558,115 bytes)"; "Liczba elementów" = 730; "Limit (zakaz wysyłania)" = "99 GB (106,300,440,576 bytes)"; "Archiwum" = "Brak"; "Litigation Hold" = $false }
            "Przekierowanie" = [ordered]@{ "Przekieruj do" = "ktos@zewn.pl"; "Zachowaj kopię" = $true }
            "Autoodpowiedź" = [ordered]@{ "Stan" = "Scheduled" }
            "Adresy (3)" = [ordered]@{ "Aliasy" = @("SIP:jan@firma.pl", "SMTP:jan@firma.pl", "smtp:j@firma.pl") }
            "Wysyłanie w imieniu" = [ordered]@{ "Użytkownicy" = @("anna") }
        }
        $row = ConvertTo-HTMailboxSummaryRow -Detail $detail
        $row.Rozmiar | Should -Be "93.99 MB"
        $row.Limit | Should -Be "99 GB"
        $row.Przekierowanie | Should -Be "ktos@zewn.pl (z kopią)"
        $row.'Autoodpowiedź' | Should -Be "Zaplanowana"
        $row.'Adresy SMTP' | Should -Be 2
        $row.'W imieniu' | Should -Be 1
        $row.__flag | Should -Be "warn"
        $row.__detail | Should -Be $detail
    }
}

Describe "Uprawnienia do skrzynki z listy (różne rodzaje dla różnych osób)" {
    It "linie: uprawnienia, automapowanie, domyślne, błędy i powtórzenia" {
        $text = "jan@firma.pl; pełny, jako; tak`r`nanna@firma.pl; Full; nie`r`npiotr@firma.pl; w imieniu`r`newa@firma.pl`r`n# komentarz`r`nmarek@firma.pl; wszystkie; bez`r`nzly adres; full`r`nx@firma.pl; cos`r`njan@firma.pl; jako"
        $r = @(ConvertFrom-HTMailboxPermissionLines -Text $text -DefaultTypes @('FullAccess') -DefaultAutoMapping $true)
        $r.Count | Should -Be 8
        $r[0].Types | Should -Be @('FullAccess', 'SendAs')
        $r[0].AutoMapping | Should -BeTrue
        $r[1].Types | Should -Be @('FullAccess')
        $r[1].AutoMapping | Should -BeFalse
        $r[2].Types | Should -Be @('SendOnBehalf')
        $r[3].Types | Should -Be @('FullAccess')
        $r[4].Types | Should -Be @('FullAccess', 'SendAs', 'SendOnBehalf')
        $r[4].AutoMapping | Should -BeFalse
        $r[5].Problem | Should -Match 'niepoprawny adres'
        $r[6].Problem | Should -Match 'nieznane uprawnienie'
        $r[7].Problem | Should -Match 'powtórzona'
        @($r | Select-Object -First 5 | Where-Object { $_.Problem }).Count | Should -Be 0
    }
    It "linia bez uprawnień i bez domyślnych - błąd «brak uprawnień»" {
        (@(ConvertFrom-HTMailboxPermissionLines -Text 'jan@firma.pl' -DefaultTypes @())[0]).Problem | Should -Match 'brak uprawnień'
    }
    It "opis uprawnień do podsumowania" {
        Get-HTMailboxPermissionLabel -Types @('FullAccess', 'SendAs') -AutoMapping $false | Should -Be 'pełny dostęp (bez automapowania), wyślij jako'
    }
    It "plik CSV (średnik albo przecinek) zamieniany na linie listy" {
        $path = Join-Path $TestDrive 'uprawnienia.csv'
        Set-Content -LiteralPath $path -Encoding utf8 -Value @('Uzytkownik;Uprawnienia;Automapowanie', 'jan@firma.pl;pełny,jako;nie', 'anna@firma.pl;;', ';pełny;tak')
        $lines = @(ConvertFrom-HTMailboxPermissionCsv -Path $path)
        $lines | Should -Be @('jan@firma.pl; pełny,jako; nie', 'anna@firma.pl')
        $r = @(ConvertFrom-HTMailboxPermissionLines -Text ($lines -join "`n"))
        $r[0].Types | Should -Be @('FullAccess', 'SendAs')
        $r[0].AutoMapping | Should -BeFalse
    }
}

Describe "Kopie wiadomości wysłanych przez delegatów" {
    BeforeAll {
        New-HTTestStub -Name "Set-Mailbox" -Parameters "Identity", "ForwardingSmtpAddress", "ForwardingAddress", "DeliverToMailboxAndForward", "Confirm", "MessageCopyForSentAsEnabled", "MessageCopyForSendOnBehalfEnabled", "GrantSendOnBehalfTo"
        New-HTTestStub -Name "Get-EXOMailbox" -Parameters "Identity", "Properties"
    }
    It "ustawia obie kopie (domyślnie włączone) i odczytuje stan" {
        Mock -ModuleName MailboxesExchangeOnline Set-Mailbox { }
        Set-HTMailboxSentItemsCopy -Identity 'biuro@firma.pl'
        Should -Invoke -ModuleName MailboxesExchangeOnline Set-Mailbox -Times 1 -ParameterFilter { $Identity -eq 'biuro@firma.pl' -and $MessageCopyForSentAsEnabled -eq $true -and $MessageCopyForSendOnBehalfEnabled -eq $true }
        Mock -ModuleName MailboxesExchangeOnline Get-EXOMailbox { [PSCustomObject]@{ PrimarySmtpAddress = 'biuro@firma.pl'; RecipientTypeDetails = 'SharedMailbox'; MessageCopyForSentAsEnabled = $true; MessageCopyForSendOnBehalfEnabled = $false } }
        $s = Get-HTMailboxSentItemsCopy -Identity 'biuro@firma.pl'
        $s.'Kopia wysłanych «jako»' | Should -BeTrue
        $s.'Kopia wysłanych «w imieniu»' | Should -BeFalse
        $s.__flag | Should -Be 'warn'
    }
}
