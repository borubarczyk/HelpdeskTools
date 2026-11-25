BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    New-HTTestStub -Name "Invoke-MgGraphRequest" -Parameters "Uri", "Method", "Body", "Headers", "OutputType", "ContentType"
    Import-HTTestModule -Name "Utils", "ModulesConnection", "GraphAPIM365Users", "ExtraColumns"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Dodatkowe kolumny: klucze i dopasowanie wierszy" {
    It "klucz: małe litery, bez «smtp:», adres z «Nazwa <adres>»" {
        @(ConvertTo-HTExtraColumnKey 'SMTP:Jan@Contoso.PL') | Should -Be @('jan@contoso.pl')
        @(ConvertTo-HTExtraColumnKey 'Jan Kowalski <jan@contoso.pl>') | Should -Contain 'jan@contoso.pl'
        @(ConvertTo-HTExtraColumnKey $null).Count | Should -Be 0
        @(ConvertTo-HTExtraColumnKey @('A', 'b')) | Should -Be @('a', 'b')
    }
    It "indeks pomija klucze pasujące do kilku obiektów (np. ta sama nazwa)" {
        $index = New-HTExtraColumnIndex -Items @(
            @{ Keys = @('1', 'Biuro'); Values = @{ x = 'pierwsza' } }
            @{ Keys = @('2', 'Biuro'); Values = @{ x = 'druga' } }
        )
        $index['1'].x | Should -Be 'pierwsza'
        $index.ContainsKey('biuro') | Should -BeFalse
    }
    It "identyfikatory z kolumn tabeli, obiektu wiersza i obiektu docelowego, w kolejności -KeyProperties" {
        $obj = [PSCustomObject]@{ Nazwa = 'Raport'; __target = [PSCustomObject]@{ Id = 'abc'; UserPrincipalName = 'jan@contoso.pl' } }
        $keys = @(Get-HTExtraColumnRowKeys -Values @{ UPN = 'Jan@Contoso.pl' } -Object $obj -KeyProperties @('Id', 'UPN', 'UserPrincipalName'))
        $keys | Should -Be @('abc', 'jan@contoso.pl')
    }
    It "dopasowanie: pierwszy klucz wiersza obecny w indeksie" {
        $index = @{ 'jan@contoso.pl' = @{ jobTitle = 'Księgowy' } }
        (Find-HTExtraColumnValues -Index $index -Keys @('nieznany', 'jan@contoso.pl')).jobTitle | Should -Be 'Księgowy'
        Find-HTExtraColumnValues -Index $index -Keys @('brak') | Should -BeNullOrEmpty
    }
    It "nazwa kolumny z nazwą źródła, gdy tabela ma już taką kolumnę" {
        Get-HTExtraColumnName -Label 'Stanowisko' -SourceTitle 'Konto Active Directory' -Existing @('Nazwa') | Should -Be 'Stanowisko'
        Get-HTExtraColumnName -Label 'Stanowisko' -SourceTitle 'Konto Active Directory' -Existing @('Stanowisko') | Should -Be 'Stanowisko (Konto Active Directory)'
    }
}

Describe "Dodatkowe kolumny: źródła, wybór i pamięć podręczna" {
    It "źródła programu mają klucze i atrybuty; wybór zapisany jako «Źródło|atrybut»" {
        foreach ($k in 'M365User', 'M365Group', 'Mailbox', 'ADUser', 'ADComputer', 'IntuneDevice') {
            $s = Get-HTExtraColumnSource -Key $k
            $s | Should -Not -BeNullOrEmpty -Because $k
            @($s.KeyProperties).Count | Should -BeGreaterThan 0
            $s.Attributes.Count | Should -BeGreaterThan 3
        }
        $c = ConvertFrom-HTExtraColumnSpec 'M365User|createdDateTime'
        $c.Label | Should -Be 'Konto utworzone'
        ConvertFrom-HTExtraColumnSpec 'M365User|brak' | Should -BeNullOrEmpty
        ConvertFrom-HTExtraColumnSpec 'zle' | Should -BeNullOrEmpty
    }
    It "okno wyboru: tylko źródła połączonych usług, usługa modułu na początku" {
        $choices = Get-HTExtraColumnChoices -Services @('Exchange') -PreferService 'Exchange'
        @($choices.Values | Where-Object { $_ -like 'M365User|*' }).Count | Should -Be 0
        @($choices.Values)[0] | Should -BeLike 'Mailbox|*'
        @($choices.Keys)[0] | Should -BeLike 'Skrzynka Exchange › *'
    }
    It "dane źródła zapamiętane; brakujące atrybuty dociągane razem z zapamiętanymi" {
        $script:fetches = New-Object System.Collections.Generic.List[string]
        Register-HTExtraColumnSource -Key 'zzTest' -Title 'Test' -KeyProperties @('UPN') -Attributes ([ordered]@{ a = 'A'; b = 'B' }) -Fetch {
            param([string[]]$Attributes)
            $script:fetches.Add(($Attributes | Sort-Object) -join ',')
            @{ Keys = @('jan@contoso.pl'); Values = @{ a = 1; b = 2 } }
        }
        Clear-HTExtraColumnCache
        (Get-HTExtraColumnData -Source 'zzTest' -Attributes @('a')).Index['jan@contoso.pl'].a | Should -Be 1
        Get-HTExtraColumnData -Source 'zzTest' -Attributes @('a') | Out-Null
        Get-HTExtraColumnData -Source 'zzTest' -Attributes @('b') | Out-Null
        Get-HTExtraColumnData -Source 'zzTest' -Attributes @('a') -Refresh | Out-Null
        @($script:fetches) | Should -Be @('a', 'a,b', 'a')
    }
}

Describe "Dodatkowe kolumny: konto Microsoft 365" {
    It "jedno zapytanie z wybranymi atrybutami i przełożonym; daty jako data, licencje po nazwie" {
        Mock -ModuleName ModulesConnection Invoke-MgGraphRequest {
            if ($Uri -like '*subscribedSkus*') { return [PSCustomObject]@{ value = @([PSCustomObject]@{ skuId = 's1'; skuPartNumber = 'O365_BUSINESS_PREMIUM' }) } }
            [PSCustomObject]@{ value = @([PSCustomObject]@{ id = 'u1'; userPrincipalName = 'jan@contoso.pl'; mail = 'jan@contoso.pl'; proxyAddresses = @('SMTP:jan@contoso.pl', 'smtp:j.k@contoso.pl'); jobTitle = 'Księgowy'; createdDateTime = '2024-03-01T10:00:00Z'; assignedLicenses = @([PSCustomObject]@{ skuId = 's1' }); manager = [PSCustomObject]@{ displayName = 'Anna'; userPrincipalName = 'anna@contoso.pl' } }) }
        }
        Clear-HTExtraColumnCache
        $data = Get-HTExtraColumnData -Source 'M365User' -Attributes @('jobTitle', 'createdDateTime', 'manager', 'assignedLicenses')
        Should -Invoke -ModuleName ModulesConnection Invoke-MgGraphRequest -ParameterFilter { $Uri -like '*users?$select=*jobTitle*createdDateTime*' -and $Uri -like '*$expand=manager*' }
        $v = $data.Index['j.k@contoso.pl']
        $v.jobTitle | Should -Be 'Księgowy'
        $v.createdDateTime | Should -BeOfType [datetime]
        $v.manager | Should -Be 'Anna <anna@contoso.pl>'
        $v.assignedLicenses | Should -Not -BeNullOrEmpty
        $data.Index['u1'].jobTitle | Should -Be 'Księgowy'
    }
}
