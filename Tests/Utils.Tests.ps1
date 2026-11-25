BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Write-Log" {
    BeforeEach { Clear-HTLogHistory }

    It "zapisuje wpis w historii z poziomem <Expected> dla typu <Type>" -TestCases @(
        @{ Type = "Info"; Expected = "Info" }
        @{ Type = "Warn"; Expected = "Warn" }
        @{ Type = "Warning"; Expected = "Warn" }
        @{ Type = "Warning&Notification"; Expected = "Warn" }
        @{ Type = "Error&Notification"; Expected = "Error" }
    ) {
        param($Type, $Expected)
        Write-Log -Message "test" -Type $Type
        $entry = @(Get-HTLogHistory)[-1]
        $entry.Type | Should -Be $Expected
        $entry.Message | Should -BeLike "*test"
    }

    It "przyjmuje parametry pozycyjne" {
        Write-Log "pozycyjny" "Error"
        (@(Get-HTLogHistory)[-1]).Type | Should -Be "Error"
    }

    It "dopisuje wpis do pliku logu" {
        Write-Log -Message "do pliku" -Type "Info"
        $content = Get-Content (Get-HTLogFile) -Raw
        $content | Should -Match "\[Info\].*do pliku"
    }

    It "powiadamia zarejestrowanych odbiorców" {
        $script:received = @()
        Register-HTLogSink -ScriptBlock { param($entry) $script:received += $entry.Message }
        Write-Log -Message "odbiorca" -Type "Info"
        $script:received | Should -Contain (@(Get-HTLogHistory)[-1].Message)
    }

    It "tworzy archiwum, gdy plik logu przekroczy limit" {
        $Global:LogFileMaxSizeMB = 0.0001
        try {
            Write-Log -Message ("x" * 500) -Type "Info"
            Write-Log -Message "po rotacji" -Type "Info"
            @(Get-ChildItem (Get-HTLogDirectory) -Filter "HelpdeskTools_*_*.log").Count | Should -BeGreaterThan 0
        }
        finally { $Global:LogFileMaxSizeMB = 5 }
    }
}

Describe "Test-HTLogEntryMatch" {
    BeforeAll { $entry = [PSCustomObject]@{ Time = Get-Date; Type = "Warn"; Message = "⚠️ Brak połączenia z Exchange" } }
    It "filtruje po typie" {
        Test-HTLogEntryMatch -Entry $entry -FilterType "Warn" | Should -BeTrue
        Test-HTLogEntryMatch -Entry $entry -FilterType "Error" | Should -BeFalse
        Test-HTLogEntryMatch -Entry $entry -FilterType "Wszystkie" | Should -BeTrue
    }
    It "filtruje po tekście bez rozróżniania wielkości liter" {
        Test-HTLogEntryMatch -Entry $entry -FilterText "exchange" | Should -BeTrue
        Test-HTLogEntryMatch -Entry $entry -FilterText "graph" | Should -BeFalse
    }
}

Describe "Test-HTInputValue" {
    It "waliduje <Type> '<Value>' jako <Expected>" -TestCases @(
        @{ Type = "Email"; Value = "jan.kowalski@firma.pl"; Expected = $true }
        @{ Type = "Email"; Value = "o'brien@firma.co.uk"; Expected = $true }
        @{ Type = "Email"; Value = "brak-malpy.pl"; Expected = $false }
        @{ Type = "Phone"; Value = "+48 600 100 200"; Expected = $true }
        @{ Type = "Phone"; Value = "12345"; Expected = $false }
        @{ Type = "Url"; Value = "https://firma.sharepoint.com/sites/IT"; Expected = $true }
        @{ Type = "Url"; Value = "firma.sharepoint.com"; Expected = $false }
        @{ Type = "Guid"; Value = "3f2504e0-4f89-11d3-9a0c-0305e82c3301"; Expected = $true }
        @{ Type = "Guid"; Value = "nie-guid"; Expected = $false }
        @{ Type = "Text"; Value = "   "; Expected = $false }
        @{ Type = "Text"; Value = "abc"; Expected = $true }
    ) {
        param($Type, $Value, $Expected)
        Test-HTInputValue -Value $Value -ValidationType $Type | Should -Be $Expected
    }
}

Describe "ConvertTo-HTDisplayValue" {
    It "zamienia wartości logiczne na Tak/Nie" {
        ConvertTo-HTDisplayValue $true | Should -Be "Tak"
        ConvertTo-HTDisplayValue $false | Should -Be "Nie"
    }
    It "formatuje daty" {
        ConvertTo-HTDisplayValue ([datetime]"2024-05-01 13:45:00") | Should -Be "2024-05-01 13:45"
    }
    It "formatuje daty ISO 8601 zapisane jako tekst" {
        ConvertTo-HTDisplayValue "2024-05-01T13:45:00" | Should -Be "2024-05-01 13:45"
    }
    It "łączy tablice" {
        ConvertTo-HTDisplayValue @("a", "b", $true) | Should -Be "a, b, Tak"
    }
    It "zwraca pusty tekst dla null" {
        ConvertTo-HTDisplayValue $null | Should -Be ""
    }
    It "nie zmienia zwykłego tekstu" {
        ConvertTo-HTDisplayValue "Dział IT" | Should -Be "Dział IT"
    }
}

Describe "Split-HTInputList" {
    It "dzieli po nowych liniach, przecinkach i średnikach oraz usuwa duplikaty" {
        $result = Split-HTInputList -Text "a@x.pl`r`nb@x.pl, c@x.pl;a@x.pl`n`n  "
        $result | Should -Be @("a@x.pl", "b@x.pl", "c@x.pl")
    }
    It "zwraca pustą tablicę dla pustego tekstu" {
        @(Split-HTInputList -Text "").Count | Should -Be 0
    }
}

Describe "Pozostałe funkcje pomocnicze" {
    It "Format-HTBytes formatuje rozmiary" {
        Format-HTBytes 1536 | Should -Match "^1[\.,]5 KB$"
        Format-HTBytes $null | Should -Be ""
    }
    It "ConvertTo-HTAsciiName usuwa polskie znaki" {
        ConvertTo-HTAsciiName "Łukasz Żółć-Gęślą" | Should -Be "Lukasz Zolc-Gesla"
    }
    It "Remove-InnerWhitespace usuwa wszystkie spacje" {
        Remove-InnerWhitespace -InputString " +48 600 100 200 " -TrimEnds | Should -Be "+48600100200"
    }
    It "Format-HTLogEntry zwraca linię z czasem i typem" {
        $line = Format-HTLogEntry -Entry ([PSCustomObject]@{ Time = [datetime]"2024-01-02 03:04:05"; Type = "Info"; Message = "x" })
        $line | Should -Be "2024-01-02 03:04:05 [Info] x"
    }
}

Describe "Write-Log - powiadomienia" {
    BeforeEach { Clear-HTLogHistory }
    It "oznacza wpis jako powiadomienie dla typu *&Notification" {
        $Global:ShowNotifications = $true
        Write-Log -Message "z powiadomieniem" -Type "Info&Notification"
        (@(Get-HTLogHistory)[-1]).Notify | Should -BeTrue
        Write-Log -Message "bez" -Type "Info"
        (@(Get-HTLogHistory)[-1]).Notify | Should -BeFalse
    }
    It "nie oznacza powiadomienia, gdy powiadomienia są wyłączone" {
        $Global:ShowNotifications = $false
        try {
            Write-Log -Message "wyłączone" -Type "Error&Notification"
            (@(Get-HTLogHistory)[-1]).Notify | Should -BeFalse
        }
        finally { $Global:ShowNotifications = $true }
    }
}

Describe "Import-HTIdentityFile" {
    It "czyta kolumnę UserPrincipalName z CSV rozdzielanego średnikiem" {
        $path = Join-Path $TestDrive "users.csv"
        "Name;UserPrincipalName`nJan;jan@firma.pl`nAnna;anna@firma.pl`nJan;jan@firma.pl" | Set-Content $path -Encoding utf8
        Import-HTIdentityFile -Path $path | Should -Be @("jan@firma.pl", "anna@firma.pl")
    }
    It "czyta plik tekstowy (jeden identyfikator w linii)" {
        $path = Join-Path $TestDrive "users.txt"
        "a@x.pl`r`nb@x.pl`r`n`r`n" | Set-Content $path -Encoding utf8
        Import-HTIdentityFile -Path $path | Should -Be @("a@x.pl", "b@x.pl")
    }
}

Describe "ConvertTo-HTDetailRows" {
    It "spłaszcza zagnieżdżone sekcje i łączy tablice nowymi liniami" {
        $rows = @(ConvertTo-HTDetailRows -Data ([ordered]@{ Nazwa = "Jan"; Włączone = $true; Konto = [ordered]@{ Grupy = @("A", "B") } }))
        $rows.Count | Should -Be 3
        $rows[0].Sekcja | Should -Be "Ogólne"
        $rows[1].Wartość | Should -Be "Tak"
        $rows[2].Sekcja | Should -Be "Konto"
        $rows[2].Wartość | Should -Be "A`nB"
    }
}

Describe "Get-HTDaysSince" {
    It "liczy dni od daty, tekstu ISO i zwraca null dla braku daty" {
        Get-HTDaysSince ((Get-Date).AddDays(-10)) | Should -Be 10
        Get-HTDaysSince ((Get-Date).ToUniversalTime().AddDays(-3).ToString("yyyy-MM-ddTHH:mm:ssZ")) | Should -Be 3
        Get-HTDaysSince $null | Should -BeNullOrEmpty
        Get-HTDaysSince "nie-data" | Should -BeNullOrEmpty
        Get-HTDaysSince ([datetime]::MinValue) | Should -BeNullOrEmpty
    }
}

Describe "Dziennik z kontem MFA i odczyt pliku dziennika" {
    BeforeEach {
        $Global:LogDir = Join-Path $TestDrive ([guid]::NewGuid().ToString("N"))
        Clear-HTLogHistory
    }
    AfterEach {
        $Global:HTActiveAccount = $null
        $Global:LogDir = $null
    }

    It "dopisuje konto MFA do wpisu w pliku" {
        $Global:HTActiveAccount = "Anna"
        Write-Log -Message "operacja konta" -Type "Warn"
        (@(Get-HTLogHistory)[-1]).Account | Should -Be "Anna"
        Get-Content (Get-HTLogFile) -Raw | Should -Match "\[Warn\] \[konto: Anna\] .*operacja konta"
    }

    It "czyta wpisy z poziomem, kontem i wieloliniowym komunikatem" {
        Write-Log -Message "start" -Type "Info"
        $Global:HTActiveAccount = "Anna"
        Write-Log -Message "błąd`ndruga linia" -Type "Error"
        Write-Log -Message "uwaga" -Type "Warn"
        $rows = @(Read-HTLogFile -Path (Get-HTLogFile))
        $rows.Count | Should -Be 3
        $rows[0].Poziom | Should -Be "Info"
        $rows[0].Komunikat | Should -Be "start"
        $rows[1].Konto | Should -Be "Anna"
        $rows[1].Komunikat | Should -Be "błąd`ndruga linia"
        $rows[1].__flag | Should -Be "crit"
        @(Read-HTLogFile -Path (Get-HTLogFile) -Level Problems).Count | Should -Be 2
        @(Read-HTLogFile -Path (Get-HTLogFile) -Level Error).Count | Should -Be 1
        @(Read-HTLogFile -Path (Get-HTLogFile) -Text "UWAGA").Count | Should -Be 1
        @(Read-HTLogFile -Path (Get-HTLogFile) -Text "anna").Count | Should -Be 2
    }

    It "listuje pliki dziennika od najnowszego" {
        New-Item -ItemType Directory -Path $Global:LogDir -Force | Out-Null
        foreach ($name in "HelpdeskTools_20260101.log", "HelpdeskTools_20260315.log", "inny.log") { Set-Content -Path (Join-Path $Global:LogDir $name) -Value "x" }
        $files = @(Get-HTLogFiles)
        $files.Count | Should -Be 2
        $files[0].Name | Should -Be "HelpdeskTools_20260315.log"
        $files[0].Date | Should -Be ([datetime]"2026-03-15")
    }
}

Describe "Katalog eksportu i zapis w folderze" {
    BeforeAll {
        $script:blocker = Join-Path $TestDrive "plik.txt"
        Set-Content -Path $script:blocker -Value "x"
        $script:savedExport = $Global:ExportPath
        $script:savedLocal = $env:LOCALAPPDATA
    }
    AfterEach {
        $Global:ExportPath = $script:savedExport
        $env:LOCALAPPDATA = $script:savedLocal
    }

    It "tworzy brakujący folder i zgłasza możliwość zapisu" {
        $dir = Join-Path $TestDrive "nowy\podfolder"
        Test-HTWritableDirectory -Path $dir | Should -BeTrue
        Test-Path -LiteralPath $dir | Should -BeTrue
        @(Get-ChildItem -LiteralPath $dir -Force).Count | Should -Be 0
    }

    It "zwraca false, gdy folderu nie da się utworzyć albo ścieżka jest pusta" {
        Test-HTWritableDirectory -Path (Join-Path $script:blocker "pod") | Should -BeFalse
        Test-HTWritableDirectory -Path "" | Should -BeFalse
    }

    It "używa ustawionego folderu eksportu, gdy da się w nim zapisać" {
        $Global:ExportPath = Join-Path $TestDrive "eksport-ok"
        Get-HTExportDirectory | Should -Be $Global:ExportPath
    }

    It "przechodzi na folder lokalny, gdy w folderze eksportu nie da się zapisać" {
        $Global:ExportPath = Join-Path $script:blocker "eksport"
        $env:LOCALAPPDATA = Join-Path $TestDrive "local"
        $dir = Get-HTExportDirectory
        $dir | Should -Be (Join-Path $env:LOCALAPPDATA "HelpdeskTools\Eksport")
        Test-Path -LiteralPath $dir | Should -BeTrue
        @(Get-HTLogHistory | Where-Object { $_.Type -eq "Warn" -and $_.Message -like "*eksport do folderu lokalnego*" }).Count | Should -BeGreaterThan 0
    }

    It "odtwarza folder eksportu usunięty w trakcie pracy" {
        $Global:ExportPath = Join-Path $TestDrive "eksport-usuniety"
        Get-HTExportDirectory | Out-Null
        Remove-Item -LiteralPath $Global:ExportPath -Recurse -Force
        Get-HTExportDirectory | Should -Be $Global:ExportPath
        Test-Path -LiteralPath $Global:ExportPath | Should -BeTrue
    }
}

Describe "Szczegółowy dziennik (debug)" {
    AfterEach { $Global:DebugLogging = $null }
    It "pomija wpisy Debug, gdy szczegółowy dziennik jest wyłączony" {
        $Global:DebugLogging = $false
        $before = @(Get-HTLogHistory).Count
        Write-Log -Message "ukryty" -Type "Debug"
        Write-HTDebug "też ukryty"
        Write-HTDebug { throw "nie powinno się wykonać" }
        @(Get-HTLogHistory).Count | Should -Be $before
    }
    It "zapisuje wpisy Debug w historii i pliku, gdy jest włączony" {
        $Global:DebugLogging = $true
        Write-HTDebug { "Graph GET users - OK ($(1 + 1) ms)" }
        $entry = @(Get-HTLogHistory)[-1]
        $entry.Type | Should -Be "Debug"
        $entry.Message | Should -BeLike "*Graph GET users - OK (2 ms)"
        Get-Content (Get-HTLogFile) -Raw | Should -Match "\[Debug\].*Graph GET users"
        @(Read-HTLogFile -Path (Get-HTLogFile) -Text "Graph GET users")[-1].Poziom | Should -Be "Debug"
    }
}

Describe "Potwierdzenie zmian - treść" {
    It "opisuje pola formularza: pomija puste, «(bez zmian)» i niezaznaczone, maskuje hasła" {
        ConvertTo-HTFormSummaryLine -Field @{ Label = 'Tryb' } -Type Combo -Value 'Scheduled' | Should -Be 'Tryb: Scheduled'
        ConvertTo-HTFormSummaryLine -Field @{ Label = 'Od' } -Type Date -Value ([datetime]'2026-11-02 08:00') | Should -Be 'Od: 2026-11-02 08:00'
        ConvertTo-HTFormSummaryLine -Field @{ Label = 'Wygasa'; DateOnly = $true } -Type Date -Value ([datetime]'2026-12-31') | Should -Be 'Wygasa: 2026-12-31'
        ConvertTo-HTFormSummaryLine -Field @{ Label = 'Jednorazowy' } -Type Check -Value $true | Should -Be 'Jednorazowy - tak'
        ConvertTo-HTFormSummaryLine -Field @{ Label = 'Jednorazowy' } -Type Check -Value $false | Should -Be ''
        ConvertTo-HTFormSummaryLine -Field @{ Label = 'Opis' } -Type Text -Value '  ' | Should -Be ''
        ConvertTo-HTFormSummaryLine -Field @{ Label = 'Język' } -Type Combo -Value '(bez zmian)' | Should -Be ''
        ConvertTo-HTFormSummaryLine -Field @{ Label = 'Hasło' } -Type Password -Value 'Tajne123!' | Should -Be 'Hasło: ••••••'
        ConvertTo-HTFormSummaryLine -Field @{ Label = 'Nowe hasło konta' } -Type Text -Value 'Tajne123!' | Should -Be 'Nowe hasło konta: ••••••'
        ConvertTo-HTFormSummaryLine -Field @{ Label = 'Notatka'; NoSummary = $true } -Type Text -Value 'x' | Should -Be ''
        ConvertTo-HTFormSummaryLine -Field @{ Name = 'Days' } -Type Number -Value 30 | Should -Be 'Days: 30'
    }
    It "skraca wielowierszowe i długie wartości" {
        ConvertTo-HTFormSummaryLine -Field @{ Label = 'Wiadomość wewnętrzna' } -Type Multiline -Value "Jestem na urlopie.`r`nWracam 10.11.`r`n`r`nPozdrawiam" | Should -Be 'Wiadomość wewnętrzna: Jestem na urlopie. … (wierszy: 3)'
        $long = ConvertTo-HTFormSummaryLine -Field @{ Label = 'Opis' } -Type Text -Value ('a' * 200)
        $long.Length | Should -Be ('Opis: '.Length + 90)
        $long | Should -BeLike '*…'
    }
    It "zamienia słownik zmian na linie (tak/nie, listy, wyczyszczenie, etykiety)" {
        $lines = @(ConvertTo-HTChangeSummary -Settings ([ordered]@{ AllowConflicts = $false; BookInPolicy = @('a@x.pl', 'b@x.pl'); ResourceDelegates = $null; Title = 'Kierownik' }) -Labels @{ Title = 'Stanowisko' })
        $lines | Should -Be @('AllowConflicts: nie', 'BookInPolicy: a@x.pl, b@x.pl', 'ResourceDelegates: (wyczyść)', 'Stanowisko: Kierownik')
    }
    It "buduje treść potwierdzenia: operacja, ustawienia, liczba obiektów i wpis do dziennika" {
        $labels = @(1..12 | ForEach-Object { "user$_@firma.pl" })
        $c = Get-HTChangeConfirmation -Name 'Autoodpowiedź' -Labels $labels -Summary @('Tryb: Enabled', '', 'Odbiorcy zewnętrzni: All') -Source 'zaznaczone na liście'
        $c.Message | Should -Match 'Autoodpowiedź'
        $c.Details | Should -Be @('Tryb: Enabled', 'Odbiorcy zewnętrzni: All')
        $c.ItemsHeader | Should -Be 'Dotyczy obiektów (12) - zaznaczone na liście:'
        $c.ConfirmText | Should -Be 'Wykonaj (12)'
        $c.LogText | Should -Match '^«Autoodpowiedź» - obiektów: 12 \(user1@firma.pl, .*user10@firma.pl … \(\+2\)\); Tryb: Enabled; Odbiorcy zewnętrzni: All$'
        $single = Get-HTChangeConfirmation -Name 'Nowy folder' -Labels @('Dokumenty') -Confirm 'Utworzyć folder?'
        $single.Message | Should -Be 'Utworzyć folder?'
        $single.ConfirmText | Should -Be 'Wykonaj'
        $single.ItemsHeader | Should -Be 'Dotyczy obiektów (1):'
    }
}

Describe "Ostrzeżenia poleceń w dzienniku" {
    It "łączy powtórzenia z liczbą i pomija puste" {
        $lines = @(Group-HTWarningMessages -Messages @('Events from Email parameters of this cmdlet are deprecated.', '', 'Inne  ostrzeżenie', 'Events from Email parameters of this cmdlet are deprecated.', "Inne ostrzeżenie`n"))
        $lines | Should -Be @('Events from Email parameters of this cmdlet are deprecated. (×2)', 'Inne ostrzeżenie (×2)')
        @(Group-HTWarningMessages -Messages @()).Count | Should -Be 0
    }
}

Describe "Wybór pól ze szczegółów (Sprawdź stan)" {
    It "wybiera pola także z podsekcji, zmienia nazwy kolumn i zostawia puste brakujące" {
        $detail = [ordered]@{
            'Nazwa'         = 'jan'
            'Włączone'      = $true
            'Konto i hasło' = [ordered]@{ 'Hasło ustawione' = '2026-10-01'; 'Nazwa' = 'inna' }
            'Lokalizacja'   = [ordered]@{ 'DN' = 'CN=jan,OU=IT,DC=firma,DC=pl' }
        }
        $row = Select-HTDetailFields -Detail $detail -Fields 'Nazwa', 'Hasło ustawione', @{ Name = 'DN'; Label = 'Lokalizacja (DN)' }, 'Brak'
        @($row.PSObject.Properties.Name) | Should -Be @('Nazwa', 'Hasło ustawione', 'Lokalizacja (DN)', 'Brak')
        $row.Nazwa | Should -Be 'jan'
        $row.'Hasło ustawione' | Should -Be '2026-10-01'
        $row.'Lokalizacja (DN)' | Should -Be 'CN=jan,OU=IT,DC=firma,DC=pl'
        $row.Brak | Should -BeNullOrEmpty
    }
}

Describe "Blok w wątku w tle (Test-HTBackgroundSafeBlock)" {
    BeforeAll {
        function global:Get-HTGuiOnlyThing { 1 }
        $Global:HTTestForm = @{ X = 1 }
    }
    AfterAll { Remove-Item -LiteralPath Function:Get-HTGuiOnlyThing -ErrorAction SilentlyContinue }
    It "dopuszcza bloki z parametrami, zmiennymi lokalnymi, poleceniami PowerShell i funkcjami modułów puli" {
        Test-HTBackgroundSafeBlock -AllowedModules 'Utils' -ScriptBlock { param($t) Select-HTDetailFields -Detail @{ A = 1 } -Fields 'A' } | Should -BeTrue
        Test-HTBackgroundSafeBlock -AllowedModules 'Utils' -ScriptBlock { param($t) $x = @($t.A | ForEach-Object { $_ }); foreach ($y in $x) { [PSCustomObject]@{ A = $y; U = $env:USERNAME } } } | Should -BeTrue
    }
    It "odrzuca funkcje okna, zmienne z otaczającego kodu, globalne i wywołania dynamiczne" {
        Test-HTBackgroundSafeBlock -AllowedModules 'Utils' -ScriptBlock { param($t) Get-HTGuiOnlyThing } | Should -BeFalse
        Test-HTBackgroundSafeBlock -AllowedModules 'Utils' -ScriptBlock { param($t) $HTTestForm.X } | Should -BeFalse
        Test-HTBackgroundSafeBlock -AllowedModules 'Utils' -ScriptBlock { param($t) $Global:HTTestForm } | Should -BeFalse
        Test-HTBackgroundSafeBlock -AllowedModules 'Utils' -ScriptBlock { param($t) & $t.Run } | Should -BeFalse
        Test-HTBackgroundSafeBlock -ScriptBlock { param($t) Select-HTDetailFields -Detail @{ A = 1 } -Fields 'A' } | Should -BeFalse
    }
}

Describe "Podpowiadanie adresów e-mail" {
    BeforeAll { $Global:HTTestAddresses = @('jan.kowalski@firma.pl', 'jan.nowak@firma.pl', 'anna.zielinska@firma.pl', 'biuro@firma.onmicrosoft.com') }
    AfterAll { Remove-Variable -Name HTTestAddresses -Scope Global -ErrorAction SilentlyContinue }
    It "dopisuje końcówkę jednoznacznego adresu, zachowując wpisany tekst" {
        Get-HTAddressCompletion -Token 'Anna' -Addresses $Global:HTTestAddresses | Should -Be 'Anna.zielinska@firma.pl'
    }
    It "przy kilku adresach dopisuje tylko wspólny początek" {
        Get-HTAddressCompletion -Token 'ja' -Addresses $Global:HTTestAddresses | Should -Be 'jan.'
        Get-HTAddressCompletion -Token 'jan.' -Addresses $Global:HTTestAddresses | Should -Be ''
    }
    It "po @ podpowiada domenę znanych adresów" {
        Get-HTAddressCompletion -Token 'nowy.pracownik@fi' -Addresses $Global:HTTestAddresses | Should -Be 'nowy.pracownik@firma.'
        Get-HTAddressCompletion -Token 'nowy@firma.p' -Addresses $Global:HTTestAddresses | Should -Be 'nowy@firma.pl'
    }
    It "nie podpowiada przy krótkim tekście ani bez dopasowania" {
        Get-HTAddressCompletion -Token 'j' -Addresses $Global:HTTestAddresses | Should -Be ''
        Get-HTAddressCompletion -Token 'xyz' -Addresses $Global:HTTestAddresses | Should -Be ''
    }
}

Describe "Dane do zgłoszenia problemu" {
    It "usuwa sekrety: tokeny, hasła, podpisy w adresach i webhooki" {
        $t = Protect-HTSupportText "Bearer eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abcdefgh password=Tajne123 client_secret: abc.def https://x.blob.core.windows.net/f?sv=1&sig=QWERTY https://prod-1.westeurope.logic.azure.com/workflows/abc"
        $t | Should -Not -Match 'Tajne123'
        $t | Should -Not -Match 'QWERTY'
        $t | Should -Not -Match 'eyJhbGci'
        $t | Should -Not -Match 'abc\.def'
        $t | Should -Match '\[token\]'
        $t | Should -Match 'sig=\[ukryte\]'
        $t | Should -Match '\[adres webhooka\]'
    }
    It "składa sekcje w kolejności, puste sekcje opisuje" {
        $text = Format-HTSupportReport ([ordered]@{ Program = @('Helpdesk Tools 3.12.0'); 'Ostatnie błędy' = @() })
        $text | Should -Match '== Program ==\r\nHelpdesk Tools 3\.12\.0'
        $text | Should -Match '== Ostatnie błędy ==\r\n\(brak\)'
        $text.IndexOf('Program') | Should -BeLessThan $text.IndexOf('Ostatnie')
    }
}

Describe "Skracanie długich komunikatów błędów" {
    It "lista dozwolonych wartości (ValidateSet) zastąpiona kilkoma pierwszymi i liczbą" {
        $items = @(1..300 | ForEach-Object { "Prop$_" }) + @(1..40 | ForEach-Object { "Owner.X$_" })
        $msg = "Cannot validate argument on parameter 'Includes'. The argument ""StorageQuota"" does not belong to the set ""$($items -join ',')"" specified by the ValidateSet attribute."
        $r = Compress-HTErrorText -Text $msg
        $r | Should -Match 'StorageQuota'
        $r | Should -Match 'Prop1, Prop2'
        $r | Should -Match 'wartości: 340'
        $r | Should -Not -Match 'Prop200'
        $r.Length | Should -BeLessThan 400
    }
    It "zwykły komunikat bez zmian, bardzo długi - przycięty z informacją" {
        Compress-HTErrorText -Text 'Brak uprawnień' | Should -Be 'Brak uprawnień'
        $long = Compress-HTErrorText -Text ('x' * 3000) -MaxLength 100
        $long | Should -Match 'skrócono z 3000'
        $long.Length | Should -BeLessThan 140
    }
    It "dziennik zapisuje skrócony komunikat" {
        Clear-HTLogHistory
        $items = @(1..300 | ForEach-Object { "Prop$_" })
        Write-Log -Message "Błąd: argument nie należy do zestawu ""$($items -join ',')"" określonego przez atrybut ValidateSet." -Type 'Error'
        $entry = @(Get-HTLogHistory)[-1]
        $entry.Message | Should -Match 'wartości: 300'
        $entry.Message.Length | Should -BeLessThan 400
    }
}

Describe "Ostrzeżenia poleceń w dzienniku" {
    It "znane, nieszkodliwe ostrzeżenia Exchange - jako informacja; pozostałe - jako ostrzeżenie" {
        Test-HTBenignWarning 'There are more results available than are currently displayed. To view them, increase the value for the ResultSize parameter.' | Should -BeTrue
        Test-HTBenignWarning 'DateFormat "dd.MM.yyyy" isn''t valid for current language setting "pl-PL". Valid formats include "d.MM.yyyy, d MMM yyyy".' | Should -BeTrue
        Test-HTBenignWarning 'Events from Email parameters of this cmdlet are deprecated. Use Get-EventsFromEmailConfiguration instead.' | Should -BeTrue
        Test-HTBenignWarning 'The mailbox is on hold and cannot be removed.' | Should -BeFalse
    }
    It "zapisuje bez powtórzeń, z właściwym rodzajem wpisu" {
        Mock -ModuleName Utils Write-Log { }
        Write-HTCommandWarnings -Where 'Test' -Messages @('Events from Email parameters of this cmdlet are deprecated.', 'Events from Email parameters of this cmdlet are deprecated.', 'Coś poważnego')
        Should -Invoke -ModuleName Utils Write-Log -Times 1 -ParameterFilter { $Type -eq 'Info' -and $Message -like 'Ostrzeżenie (Test): Events*(×2)' }
        Should -Invoke -ModuleName Utils Write-Log -Times 1 -ParameterFilter { $Type -eq 'Warn' -and $Message -eq 'Ostrzeżenie (Test): Coś poważnego' }
    }
}
