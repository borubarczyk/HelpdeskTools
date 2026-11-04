BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "ModulesConnection", "TenantSelfTest"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Autotest: rejestr testów" {
    It "testy mają unikalne klucze, znane usługi i opis obszaru" {
        $all = @(Get-HTSelfTests -IncludeWrite -IncludeSlow)
        $all.Count | Should -BeGreaterThan 20
        @($all | Group-Object Key | Where-Object Count -gt 1) | Should -BeNullOrEmpty
        @($all | Where-Object { -not $_.Area }) | Should -BeNullOrEmpty
    }
    It "domyślnie tylko odczyt; zapis i długie testy na życzenie; filtr usług" {
        @(Get-HTSelfTests | Where-Object { $_.Mode -eq 'Write' }) | Should -BeNullOrEmpty
        @(Get-HTSelfTests -IncludeWrite | Where-Object Slow) | Should -BeNullOrEmpty
        @(Get-HTSelfTests -IncludeWrite -IncludeSlow | Where-Object Slow).Count | Should -BeGreaterThan 0
        @(Get-HTSelfTests -Service 'Exchange' | Where-Object { $_.Service -ne 'Exchange' }) | Should -BeNullOrEmpty
    }
    It "testy zapisu nazywają obiekty prefiksem HT-Autotest- i rejestrują sprzątanie" {
        foreach ($t in @(Get-HTSelfTests -IncludeWrite -IncludeSlow | Where-Object { $_.Mode -eq 'Write' })) {
            $text = $t.Test.ToString()
            $text | Should -Match 'Get-HTSelfTestName' -Because $t.Key
            $text | Should -Match 'Add-HTSelfTestCleanup' -Because $t.Key
        }
    }
}

Describe "Autotest: uruchamianie" {
    BeforeAll {
        Register-HTSelfTest -Key 'zz.ok' -Name 'OK' -Service 'Lokalnie' -Area 'Test' -Test { 'wszystko dobrze' }
        Register-HTSelfTest -Key 'zz.warn' -Name 'Uwaga' -Service 'Lokalnie' -Area 'Test' -Test { @{ Status = 'Uwaga'; Szczegóły = 'brak czegoś' } }
        Register-HTSelfTest -Key 'zz.fail' -Name 'Błąd' -Service 'Lokalnie' -Area 'Test' -Test { throw 'zepsute' }
        Register-HTSelfTest -Key 'zz.skip' -Name 'Pominięty' -Service 'Lokalnie' -Area 'Test' -Test { Skip-HTSelfTest 'brak licencji' }
        Register-HTSelfTest -Key 'zz.graph' -Name 'Graph' -Service 'Graph' -Area 'Test' -Test { throw 'nie powinno się wykonać' }
        Register-HTSelfTest -Key 'zz.cleanup' -Name 'Sprzątanie' -Service 'Lokalnie' -Mode 'Write' -Area 'Test' -Test {
            param($ctx)
            $name = Get-HTSelfTestName -Context $ctx -Suffix 'X'
            $global:HTTestSelfName = $name
            Add-HTSelfTestCleanup -Context $ctx -Name 'pierwsze' -Action { $global:HTTestCleanupOrder += 'pierwsze' }
            Add-HTSelfTestCleanup -Context $ctx -Name 'drugie' -Action { $global:HTTestCleanupOrder += 'drugie' }
            throw 'test przerwany'
        }
        Register-HTSelfTest -Key 'zz.badcleanup' -Name 'Nieudane sprzątanie' -Service 'Lokalnie' -Mode 'Write' -Area 'Test' -Test {
            param($ctx)
            Add-HTSelfTestCleanup -Context $ctx -Name 'usunięcie' -Action { throw 'nie można usunąć' }
            'utworzono'
        }
    }
    It "statusy: OK, Uwaga, Błąd, Pominięto (także bez połączenia z usługą)" {
        $rows = @(Invoke-HTSelfTest -Tests @(Get-HTSelfTests -Key 'zz.ok', 'zz.warn', 'zz.fail', 'zz.skip', 'zz.graph') -Connected @{ Graph = $false })
        $rows.Count | Should -Be 5
        ($rows | Where-Object Klucz -eq 'zz.ok').Status | Should -Be 'OK'
        ($rows | Where-Object Klucz -eq 'zz.ok').Szczegóły | Should -Be 'wszystko dobrze'
        ($rows | Where-Object Klucz -eq 'zz.warn').Status | Should -Be 'Uwaga'
        ($rows | Where-Object Klucz -eq 'zz.warn').__flag | Should -Be 'warn'
        ($rows | Where-Object Klucz -eq 'zz.fail').Status | Should -Be 'Błąd'
        ($rows | Where-Object Klucz -eq 'zz.fail').Szczegóły | Should -Be 'zepsute'
        ($rows | Where-Object Klucz -eq 'zz.skip').Status | Should -Be 'Pominięto'
        ($rows | Where-Object Klucz -eq 'zz.skip').Szczegóły | Should -Be 'brak licencji'
        ($rows | Where-Object Klucz -eq 'zz.graph').Status | Should -Be 'Pominięto'
        ($rows | Where-Object Klucz -eq 'zz.graph').Szczegóły | Should -Match 'Brak połączenia'
        Get-HTSelfTestSummary -Rows $rows | Should -Be 'OK: 1, uwagi: 1, błędy: 1, pominięte: 2'
    }
    It "sprzątanie po teście także po błędzie, w odwrotnej kolejności; nazwa z prefiksem" {
        $global:HTTestCleanupOrder = @()
        $rows = @(Invoke-HTSelfTest -Tests @(Get-HTSelfTests -Key 'zz.cleanup' -IncludeWrite))
        $rows[0].Status | Should -Be 'Błąd'
        $global:HTTestCleanupOrder | Should -Be @('drugie', 'pierwsze')
        $global:HTTestSelfName | Should -Match '^HT-Autotest-\d{8}-\d{6}-X$'
    }
    It "nieudane sprzątanie zamienia OK na Błąd z informacją o pozostałościach" {
        $rows = @(Invoke-HTSelfTest -Tests @(Get-HTSelfTests -Key 'zz.badcleanup' -IncludeWrite))
        $rows[0].Status | Should -Be 'Błąd'
        $rows[0].Szczegóły | Should -Match 'Pozostałości'
        $rows[0].Szczegóły | Should -Match 'nie można usunąć'
    }
    It "wywołania zwrotne: start i wynik każdego testu; przerwanie przed kolejnym testem" {
        $global:HTTestStarted = @()
        $global:HTTestResults = @()
        $rows = @(Invoke-HTSelfTest -Tests @(Get-HTSelfTests -Key 'zz.ok', 'zz.warn') -OnStart { param($t, $i, $n) $global:HTTestStarted += "$i/$n" } -OnResult { param($r) $global:HTTestResults += $r.Klucz })
        $global:HTTestStarted | Should -Be @('1/2', '2/2')
        $global:HTTestResults | Should -Be @('zz.ok', 'zz.warn')
        @(Invoke-HTSelfTest -Tests @(Get-HTSelfTests -Key 'zz.ok', 'zz.warn') -ShouldStop { $true }) | Should -BeNullOrEmpty
    }
    It "oczekiwanie na replikację: ponawia do skutku albo zgłasza przekroczenie czasu" {
        $ctx = New-HTSelfTestContext -Sleep { param($s) }
        $global:HTTestTries = 0
        Wait-HTSelfTestCondition -Context $ctx -IntervalSeconds 0 -Condition { $global:HTTestTries++; $global:HTTestTries -ge 3 } | Should -BeTrue
        $global:HTTestTries | Should -Be 3
        { Wait-HTSelfTestCondition -Context $ctx -TimeoutSeconds 0 -IntervalSeconds 0 -Message 'nie widać' -Condition { throw 'brak' } } | Should -Throw '*nie widać*brak*'
    }
    It "pozostałości: usuwa tylko obiekty z prefiksem HT-Autotest-" {
        { Remove-HTSelfTestLeftover -Item ([PSCustomObject]@{ Obiekt = 'Zarząd'; __kind = 'Group'; Id = 'g1' }) } | Should -Throw '*nie jest obiekt testowy*'
    }
}

Describe "Autotest: raport do zgłoszenia problemu" {
    It "po uruchomieniu - podsumowanie i testy z błędem" {
        Register-HTSelfTest -Key 'zz.r.ok' -Name 'OK' -Service 'Lokalnie' -Area 'Test' -Test { 'ok' }
        Register-HTSelfTest -Key 'zz.r.fail' -Name 'Zepsuty test' -Service 'Lokalnie' -Area 'Test' -Test { throw 'awaria' }
        Invoke-HTSelfTest -Tests @(Get-HTSelfTests -Key 'zz.r.ok', 'zz.r.fail') | Out-Null
        $report = @(Get-HTSelfTestReport)
        $report.Count | Should -Be 2
        $report[0] | Should -Match 'testów 2 - OK: 1, uwagi: 0, błędy: 1'
        $report[1] | Should -Match 'Zepsuty test.*awaria'
    }
}

Describe "Autotest: wersje modułów" {
    It "test modułów korzysta z tabeli wymaganych wersji programu" {
        $t = @(Get-HTSelfTests -Key 'local.modules')[0]
        $t.Test.ToString() | Should -Match 'Get-HTModuleRequirements'
        $row = @(Invoke-HTSelfTest -Tests @($t))[0]
        $row.Status | Should -Not -Be 'Błąd'
    }
}

Describe "Autotest: zgodność z danymi zwracanymi przez program" {
    It "test kont czyta pola szczegółów konta (UPN), a nie nieistniejące właściwości" {
        $text = (@(Get-HTSelfTests -Key 'graph.users')[0]).Test.ToString()
        $text | Should -Match "detail\['UPN'\]"
        $text | Should -Not -Match 'detail\.User\.'
    }
}

Describe "Autotest: pokrycie modułów testami" {
    It "każdy test zapisu wskazuje sprawdzane moduły, a te moduły istnieją w programie" {
        $root = Split-Path -Parent $PSScriptRoot
        $keys = @(Get-ChildItem -Path (Join-Path $root 'GUI') -Recurse -Filter *.ps1 | ForEach-Object { [regex]::Matches((Get-Content -LiteralPath $_.FullName -Raw), "-Key '([a-z0-9\.]+)'") | ForEach-Object { $_.Groups[1].Value } } | Select-Object -Unique)
        foreach ($t in @(Get-HTSelfTests -IncludeWrite -IncludeSlow | Where-Object { $_.Mode -eq 'Write' -and $_.Key -notlike 'zz.*' })) {
            @($t.Modules).Count | Should -BeGreaterThan 0 -Because $t.Key
            foreach ($k in @($t.Modules)) { $keys | Should -Contain $k -Because "$($t.Key) -> $k" }
        }
    }
    It "pokrycie: pełne, tylko odczyt (zmiany bez testu zapisu), brak" {
        Register-HTSelfTest -Key 'zz.cov' -Name 'Test pokrycia' -Service 'Lokalnie' -Mode 'Write' -Area 'Test' -Modules @('mod.a') -Test { 'ok' }
        $rows = @(Get-HTSelfTestCoverage -Modules @(
                [PSCustomObject]@{ Key = 'mod.a'; Workspace = 'W'; Category = 'K'; Title = 'A'; HasRead = $true; ChangeCount = 2 }
                [PSCustomObject]@{ Key = 'mod.b'; Workspace = 'W'; Category = 'K'; Title = 'B'; HasRead = $true; ChangeCount = 1 }
                [PSCustomObject]@{ Key = 'mod.c'; Workspace = 'W'; Category = 'K'; Title = 'C'; HasRead = $false; ChangeCount = 0 }
                [PSCustomObject]@{ Key = 'mod.d'; Workspace = 'W'; Category = 'K'; Title = 'D'; HasRead = $true; ChangeCount = 0 }
            ))
        ($rows | Where-Object Klucz -eq 'mod.a').Pokrycie | Should -Be 'pełne'
        ($rows | Where-Object Klucz -eq 'mod.a').'Testy zapisu' | Should -Match 'Test pokrycia'
        ($rows | Where-Object Klucz -eq 'mod.b').Pokrycie | Should -Be 'tylko odczyt'
        ($rows | Where-Object Klucz -eq 'mod.c').Pokrycie | Should -Be 'brak'
        ($rows | Where-Object Klucz -eq 'mod.d').Pokrycie | Should -Be 'pełne'
    }
}
