BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    New-HTTestStub -Name "Invoke-MgGraphRequest" -Parameters "Uri", "Method", "Body", "Headers", "OutputType", "ContentType"
    New-HTTestStub -Name "Get-MgContext"
    Import-HTTestModule -Name "Utils", "ModulesConnection", "GraphAPIM365Users", "GraphAPIIntune"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Resolve-HTGraphUri" {
    It "buduje adres v1.0 i beta" {
        Resolve-HTGraphUri -Uri "users" | Should -Be "https://graph.microsoft.com/v1.0/users"
        Resolve-HTGraphUri -Uri "/users" -Beta | Should -Be "https://graph.microsoft.com/beta/users"
        Resolve-HTGraphUri -Uri "https://graph.microsoft.com/v1.0/me" | Should -Be "https://graph.microsoft.com/v1.0/me"
    }
}

Describe "Invoke-HTGraphRequest" {
    It "pobiera wszystkie strony wyników (-All)" {
        Mock -ModuleName ModulesConnection Invoke-MgGraphRequest {
            if ($Uri -like "*page2*") {
                [PSCustomObject]@{ value = @([PSCustomObject]@{ id = 3 }) }
            }
            else {
                [PSCustomObject]@{ value = @([PSCustomObject]@{ id = 1 }, [PSCustomObject]@{ id = 2 }); '@odata.nextLink' = "https://graph.microsoft.com/v1.0/users?page2" }
            }
        }
        $result = Invoke-HTGraphRequest -Uri "users" -All
        $result.id | Should -Be @(1, 2, 3)
        Should -Invoke -ModuleName ModulesConnection Invoke-MgGraphRequest -Times 2 -Exactly
    }
    It "zwraca kolekcję 'value' dla pojedynczego zapytania" {
        Mock -ModuleName ModulesConnection Invoke-MgGraphRequest { [PSCustomObject]@{ value = @([PSCustomObject]@{ id = "a" }) } }
        (Invoke-HTGraphRequest -Uri "groups").id | Should -Be "a"
    }
    It "wysyła treść jako JSON i nagłówek ConsistencyLevel" {
        Mock -ModuleName ModulesConnection Invoke-MgGraphRequest { }
        Invoke-HTGraphRequest -Uri "users/1" -Method PATCH -Body @{ accountEnabled = $false } -ConsistencyLevelEventual
        Should -Invoke -ModuleName ModulesConnection Invoke-MgGraphRequest -ParameterFilter {
            $Method -eq "PATCH" -and $Body -eq '{"accountEnabled":false}' -and $ContentType -eq "application/json" -and $Headers.ConsistencyLevel -eq "eventual"
        }
    }
}

Describe "ConvertTo-HTM365GroupObject" {
    It "rozpoznaje typ grupy <Expected>" -TestCases @(
        @{ Group = @{ groupTypes = @("Unified"); securityEnabled = $false; mailEnabled = $true }; Expected = "Microsoft 365" }
        @{ Group = @{ groupTypes = @(); securityEnabled = $true; mailEnabled = $false }; Expected = "Zabezpieczeń" }
        @{ Group = @{ groupTypes = @(); securityEnabled = $true; mailEnabled = $true }; Expected = "Zabezpieczeń (mail)" }
        @{ Group = @{ groupTypes = @(); securityEnabled = $false; mailEnabled = $true }; Expected = "Dystrybucyjna" }
    ) {
        param($Group, $Expected)
        (ConvertTo-HTM365GroupObject -Group ([PSCustomObject]$Group)).Type | Should -Be $Expected
    }
    It "oznacza grupy dynamiczne jako niezarządzalne" {
        $group = ConvertTo-HTM365GroupObject -Group ([PSCustomObject]@{ groupTypes = @("DynamicMembership"); securityEnabled = $true })
        Test-HTM365GroupManageable -Group $group | Should -BeFalse
    }
}

Describe "Add-HTM365PhoneMethod" {
    It "normalizuje numer '<Number>' do '<Expected>'" -TestCases @(
        @{ Number = "600 100 200"; Expected = "+48 600100200" }
        @{ Number = "+48600100200"; Expected = "+48 600100200" }
        @{ Number = "+1 4255551234"; Expected = "+1 4255551234" }
        @{ Number = "+14255551234"; Expected = "+1 4255551234" }
        @{ Number = "+420 601 123 456"; Expected = "+420 601123456" }
        @{ Number = "(600) 100-200"; Expected = "+48 600100200" }
    ) {
        param($Number, $Expected)
        Mock -ModuleName GraphAPIM365Users Invoke-HTGraphRequest { }
        Add-HTM365PhoneMethod -UserId "u1" -PhoneNumber $Number | Should -Be $Expected
        Should -Invoke -ModuleName GraphAPIM365Users Invoke-HTGraphRequest -ParameterFilter { $Body.phoneNumber -eq $Expected -and $Method -eq "POST" }
    }
}

Describe "Set-HTM365UserLicense" {
    It "ustawia lokalizację użycia przed przypisaniem licencji" {
        $Global:DefaultUsageLocation = "PL"
        Mock -ModuleName GraphAPIM365Users Invoke-HTGraphRequest { if ($Method -eq "GET" -or -not $Method) { [PSCustomObject]@{ usageLocation = $null } } }
        Set-HTM365UserLicense -Id "u1" -AddSkuIds @("sku-1")
        Should -Invoke -ModuleName GraphAPIM365Users Invoke-HTGraphRequest -ParameterFilter { $Method -eq "PATCH" -and $Body.usageLocation -eq "PL" }
        Should -Invoke -ModuleName GraphAPIM365Users Invoke-HTGraphRequest -ParameterFilter { $Uri -eq "users/u1/assignLicense" -and $Body.addLicenses[0].skuId -eq "sku-1" }
    }
}

Describe "Get-HTIntuneLapsPassword" {
    It "dekoduje najnowsze hasło z Base64" {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("Tajne!123"))
        Mock -ModuleName GraphAPIIntune Invoke-HTGraphRequest {
            [PSCustomObject]@{
                refreshDateTime = "2024-01-01T00:00:00Z"
                credentials     = @(
                    [PSCustomObject]@{ accountName = "admin"; passwordBase64 = "c3RhcmU="; backupDateTime = "2023-01-01T00:00:00Z" }
                    [PSCustomObject]@{ accountName = "admin"; passwordBase64 = $encoded; backupDateTime = "2024-01-01T00:00:00Z" }
                )
            }
        }
        $result = Get-HTIntuneLapsPassword -AzureADDeviceId "d1"
        $result.Password | Should -Be "Tajne!123"
        Should -Invoke -ModuleName GraphAPIIntune Invoke-HTGraphRequest -ParameterFilter { $Headers["ocp-client-name"] -eq "HelpdeskTools" }
    }
}

Describe "Rename-HTIntuneDevice" {
    It "odrzuca nieprawidłowe nazwy" {
        Mock -ModuleName GraphAPIIntune Invoke-HTGraphRequest { }
        { Rename-HTIntuneDevice -Id "1" -NewName "zła nazwa" } | Should -Throw
        { Rename-HTIntuneDevice -Id "1" -NewName "NAZWA-DLUZSZA-NIZ-15" } | Should -Throw
        Should -Invoke -ModuleName GraphAPIIntune Invoke-HTGraphRequest -Times 0 -Exactly
    }
    It "wysyła akcję setDeviceName do API beta" {
        Mock -ModuleName GraphAPIIntune Invoke-HTGraphRequest { }
        Rename-HTIntuneDevice -Id "1" -NewName "PC-KSIEGOWOSC1"
        Should -Invoke -ModuleName GraphAPIIntune Invoke-HTGraphRequest -ParameterFilter { $Beta -and $Uri -like "*/setDeviceName" -and $Body.deviceName -eq "PC-KSIEGOWOSC1" }
    }
}

Describe "Get-HTSkuFriendlyName" {
    BeforeAll {
        $Global:HTTestLicensePath = Join-Path $TestDrive 'brak\LicenseNames.json'
        Mock -ModuleName GraphAPIM365Users Get-HTLicenseCatalogPath { $Global:HTTestLicensePath }
        [void](Get-HTLicenseCatalog -Refresh -NoDownload)
    }
    It "zwraca nazwę handlową znanej licencji i SKU dla nieznanej" {
        Get-HTSkuFriendlyName "SPB" | Should -Be "Microsoft 365 Business Premium"
        Get-HTSkuFriendlyName "NIEZNANA_SKU" | Should -Be "NIEZNANA_SKU"
        Get-HTSkuFriendlyName "" | Should -Be ""
    }
}

Describe "Nazwy licencji z oficjalnej listy Microsoft" {
    BeforeAll {
        $Global:HTTestLicensePath = Join-Path $TestDrive 'licencje\LicenseNames.json'
        Mock -ModuleName GraphAPIM365Users Get-HTLicenseCatalogPath { $Global:HTTestLicensePath }
        $Global:HTTestLicenseRows = @(
            [PSCustomObject]@{ Product_Display_Name = 'Microsoft 365 E5 Developer (without Windows and Audio Conferencing)'; String_Id = 'DEVELOPERPACK_E5'; GUID = 'c42b9cae-ea4f-4ab7-9717-81576235ccac'; Service_Plan_Name = 'EXCHANGE_S_ENTERPRISE'; Service_Plan_Id = 'efb87545-963c-4e0d-99df-69c6916d9eb0'; Service_Plans_Included_Friendly_Names = 'Exchange Online (Plan 2)' }
            [PSCustomObject]@{ Product_Display_Name = 'Microsoft 365 E5 Developer (without Windows and Audio Conferencing)'; String_Id = 'DEVELOPERPACK_E5'; GUID = 'c42b9cae-ea4f-4ab7-9717-81576235ccac'; Service_Plan_Name = 'TEAMS1'; Service_Plan_Id = '57ff2da0-773e-42df-b2af-ffb7a2317929'; Service_Plans_Included_Friendly_Names = 'Microsoft Teams' }
            [PSCustomObject]@{ Product_Display_Name = 'Rights Management Adhoc'; String_Id = 'RIGHTSMANAGEMENT_ADHOC'; GUID = '8c4ce438-32a7-4ac5-91a6-e22ae08d9c8b'; Service_Plan_Name = 'RMS_S_ADHOC'; Service_Plan_Id = '7a39d7dd-e456-4e09-842a-0204ee08187b'; Service_Plans_Included_Friendly_Names = 'Rights Management Adhoc' }
            [PSCustomObject]@{ Product_Display_Name = ''; String_Id = ''; GUID = ''; Service_Plan_Name = ''; Service_Plan_Id = ''; Service_Plans_Included_Friendly_Names = '' }
        )
        # Pobranie listy: atrapa zapisuje CSV z ponad 50 licencjami (mniejszy plik program odrzuca jako błędny)
        $Global:HTTestLicenseCsv = @($Global:HTTestLicenseRows) + @(1..60 | ForEach-Object { [PSCustomObject]@{ Product_Display_Name = "Produkt $_"; String_Id = "SKU_$_"; GUID = [guid]::NewGuid().ToString(); Service_Plan_Name = "PLAN_$_"; Service_Plan_Id = [guid]::NewGuid().ToString(); Service_Plans_Included_Friendly_Names = "Plan $_" } })
        Mock -ModuleName GraphAPIM365Users Invoke-WebRequest { $Global:HTTestLicenseCsv | Export-Csv -LiteralPath $OutFile -NoTypeInformation -Encoding utf8 }
    }
    It "zamienia wiersze CSV na słowniki licencji i planów usług (pierwsza nazwa wygrywa, puste pomijane)" {
        $c = ConvertFrom-HTLicenseCatalogCsv -Rows $Global:HTTestLicenseRows
        $c.Products.Count | Should -Be 2
        $c.Products['DEVELOPERPACK_E5'] | Should -Be 'Microsoft 365 E5 Developer (without Windows and Audio Conferencing)'
        $c.Plans['TEAMS1'] | Should -Be 'Microsoft Teams'
        $c.Plans.Count | Should -Be 3
        $c.Updated | Should -Not -BeNullOrEmpty
    }
    It "pobiera listę, zapisuje plik i używa go do nazw: polska nazwa > lista Microsoft > kod SKU" {
        $catalog = Get-HTLicenseCatalog -Refresh
        $catalog.Products.Count | Should -Be 62
        Test-Path -LiteralPath $Global:HTTestLicensePath | Should -BeTrue
        Should -Invoke -ModuleName GraphAPIM365Users Invoke-WebRequest -Times 1 -Exactly
        Get-HTSkuFriendlyName 'DEVELOPERPACK_E5' | Should -Be 'Microsoft 365 E5 Developer (bez Windows i Audio Conferencing)'
        Get-HTSkuFriendlyName 'RIGHTSMANAGEMENT_ADHOC' | Should -Be 'Rights Management Adhoc'
        Get-HTSkuFriendlyName 'SKU_7' | Should -Be 'Produkt 7'
        Get-HTSkuFriendlyName 'CALKIEM_NOWA' | Should -Be 'CALKIEM_NOWA'
        @(Get-HTServicePlanNames -ServicePlans @('TEAMS1', 'EXCHANGE_S_ENTERPRISE', 'NIEZNANY_PLAN')) | Should -Be @('Exchange Online (Plan 2)', 'Microsoft Teams', 'NIEZNANY_PLAN')
    }
    It "odczytuje zapisaną listę bez pobierania (świeża lista)" {
        $catalog = Get-HTLicenseCatalog -Refresh -NoDownload
        $catalog.Products['SKU_1'] | Should -Be 'Produkt 1'
        Should -Invoke -ModuleName GraphAPIM365Users Invoke-WebRequest -Times 0 -Exactly
    }
    It "opisuje zawartość licencji z planów usług" {
        Get-HTSkuDescription -ServicePlans @('TEAMS1', 'EXCHANGE_S_ENTERPRISE', 'SHAREPOINTENTERPRISE', 'OFFICESUBSCRIPTION', 'INTUNE_A', 'AAD_PREMIUM') | Should -Be 'poczta Exchange, SharePoint i OneDrive, Teams, aplikacje Office na komputer, Intune, Entra ID P1'
        Get-HTSkuDescription -ServicePlans @('POWERAPPS_DEV', 'FLOW_DEV', 'DYN365_CDS_DEV_VIRAL') | Should -Be 'Power Apps, Power Automate, Dynamics 365'
        Get-HTSkuDescription -ServicePlans @() | Should -Be ''
    }
}

Describe "Get-HTM365InactiveUsers" {
    BeforeAll {
        $now = Get-Date
        Mock -ModuleName GraphAPIM365Users Get-HTSkuNameMap { @{} }
        Mock -ModuleName GraphAPIM365Users Invoke-HTGraphRequest {
            @(
                [PSCustomObject]@{ id = "1"; displayName = "Aktywny"; userPrincipalName = "a@x.pl"; accountEnabled = $true; userType = "Member"; createdDateTime = $now.AddDays(-400).ToString("o"); assignedLicenses = @(); signInActivity = [PSCustomObject]@{ lastSignInDateTime = $now.AddDays(-5).ToString("o") } }
                [PSCustomObject]@{ id = "2"; displayName = "Stary"; userPrincipalName = "s@x.pl"; accountEnabled = $true; userType = "Member"; createdDateTime = $now.AddDays(-400).ToString("o"); assignedLicenses = @([PSCustomObject]@{ skuId = "abc" }); signInActivity = [PSCustomObject]@{ lastSignInDateTime = $now.AddDays(-200).ToString("o"); lastNonInteractiveSignInDateTime = $now.AddDays(-150).ToString("o") } }
                [PSCustomObject]@{ id = "3"; displayName = "Nigdy"; userPrincipalName = "n@x.pl"; accountEnabled = $true; userType = "Member"; createdDateTime = $now.AddDays(-100).ToString("o"); assignedLicenses = @(); signInActivity = $null }
                [PSCustomObject]@{ id = "4"; displayName = "Nowy"; userPrincipalName = "w@x.pl"; accountEnabled = $true; userType = "Member"; createdDateTime = $now.AddDays(-2).ToString("o"); assignedLicenses = @(); signInActivity = $null }
                [PSCustomObject]@{ id = "5"; displayName = "Wyłączony"; userPrincipalName = "d@x.pl"; accountEnabled = $false; userType = "Member"; createdDateTime = $now.AddDays(-400).ToString("o"); assignedLicenses = @(); signInActivity = $null }
                [PSCustomObject]@{ id = "6"; displayName = "On-Premises Directory Synchronization Service Account"; userPrincipalName = "Sync_SRV01_38f6b1312bc0@x.onmicrosoft.com"; accountEnabled = $true; userType = "Member"; createdDateTime = $now.AddDays(-400).ToString("o"); assignedLicenses = @(); signInActivity = $null }
            )
        }
    }
    AfterEach { $Global:ShowSystemMailboxes = $null }
    It "zwraca konta bez logowania od N dni (z uwzględnieniem logowań nieinteraktywnych)" {
        $result = @(Get-HTM365InactiveUsers -Days 90)
        $result.UPN | Should -Be @("s@x.pl", "n@x.pl")
        ($result | Where-Object UPN -eq "s@x.pl").'Dni bez logowania' | Should -Be 150
        ($result | Where-Object UPN -eq "s@x.pl").__flag | Should -Be "warn"
        ($result | Where-Object UPN -eq "n@x.pl").'Dni bez logowania' | Should -Be "nigdy"
    }
    It "uwzględnia wyłączone konta na żądanie" {
        @(Get-HTM365InactiveUsers -Days 90 -IncludeDisabled).UPN | Should -Contain "d@x.pl"
    }
    It "pomija konto synchronizacji Entra Connect, chyba że włączono konta systemowe" {
        @(Get-HTM365InactiveUsers -Days 90).UPN | Should -Not -Contain "Sync_SRV01_38f6b1312bc0@x.onmicrosoft.com"
        $Global:ShowSystemMailboxes = $true
        @(Get-HTM365InactiveUsers -Days 90).UPN | Should -Contain "Sync_SRV01_38f6b1312bc0@x.onmicrosoft.com"
    }
    It "ukrywa konta systemowe na liście kont (z wpisem w dzienniku), -IncludeSystem pokazuje wszystkie" {
        @(Get-HTM365Users).UserPrincipalName | Should -Not -Contain "Sync_SRV01_38f6b1312bc0@x.onmicrosoft.com"
        @(Get-HTM365Users).Count | Should -Be 5
        @(Get-HTM365Users -IncludeSystem).Count | Should -Be 6
    }
    It "rozpoznaje konta systemowe" {
        Test-HTSystemAccount ([PSCustomObject]@{ displayName = 'Jan'; userPrincipalName = 'sync_jan@x.pl' }) | Should -BeFalse
        Test-HTSystemAccount ([PSCustomObject]@{ displayName = 'Jan'; userPrincipalName = 'ADToAADSyncServiceAccount@x.onmicrosoft.com' }) | Should -BeTrue
        Test-HTSystemAccount ([PSCustomObject]@{ displayName = 'On-Premises Directory Synchronization Service Account'; userPrincipalName = 'x@x.pl' }) | Should -BeTrue
    }
}

Describe "Akcje zdalne Intune" {
    It "wysyła żądanie skanowania Defender z treścią quickScan" {
        Mock -ModuleName GraphAPIIntune Invoke-HTGraphRequest { }
        Invoke-HTIntuneDeviceAction -Id "dev1" -Action QuickScan | Should -Be "Szybkie skanowanie Defender"
        Should -Invoke -ModuleName GraphAPIIntune Invoke-HTGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -eq "deviceManagement/managedDevices/dev1/windowsDefenderScan" -and $Method -eq "POST" -and $Body.quickScan -eq $true }
    }
    It "rotacja kluczy BitLocker używa API beta" {
        Mock -ModuleName GraphAPIIntune Invoke-HTGraphRequest { }
        Invoke-HTIntuneDeviceAction -Id "dev1" -Action RotateBitLocker | Out-Null
        Should -Invoke -ModuleName GraphAPIIntune Invoke-HTGraphRequest -Times 1 -Exactly -ParameterFilter { $Beta -and $Uri -like "*rotateBitLockerKeys" }
    }
}

Describe "Logowanie w przeglądarce" {
    It "Exchange: dodaje -DisableWAM, gdy moduł go obsługuje" {
        New-HTTestStub -Name "Connect-ExchangeOnline" -Parameters "ShowBanner", "ShowProgress", "DisableWAM"
        $params = Get-HTExchangeConnectParams
        $params.DisableWAM | Should -BeTrue
        $params.ShowBanner | Should -BeFalse
    }
    It "Exchange: bez -DisableWAM dla starszego modułu" {
        New-HTTestStub -Name "Connect-ExchangeOnline" -Parameters "ShowBanner"
        (Get-HTExchangeConnectParams).ContainsKey("DisableWAM") | Should -BeFalse
    }
    It "Graph: wyłącza logowanie WAM" {
        New-HTTestStub -Name "Set-MgGraphOption" -Parameters "DisableLoginByWAM"
        Mock -ModuleName ModulesConnection Set-MgGraphOption { }
        Disable-HTGraphWam
        Should -Invoke -ModuleName ModulesConnection Set-MgGraphOption -Times 1 -Exactly -ParameterFilter { $DisableLoginByWAM -eq $true }
    }
    AfterAll { Remove-Item -LiteralPath Function:Connect-ExchangeOnline, Function:Set-MgGraphOption -ErrorAction SilentlyContinue }
}

Describe "Błędy Microsoft Graph" {
    BeforeAll {
        $script:graphError = {
            param([string]$Body)
            $er = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('Response status code does not indicate success: BadRequest (Bad Request).'), 'InvokeGraphHttpResponseException', 'InvalidOperation', $null)
            $er.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($Body)
            $er
        }
    }

    It "odczytuje kod i komunikat z odpowiedzi HTTP zapisanej w ErrorDetails" {
        $body = "GET https://graph.microsoft.com/v1.0/sites?`$search=*`nHTTP/1.1 400 Bad Request`nContent-Type: application/json`n`n{`"error`":{`"code`":`"invalidRequest`",`"message`":`"Syntax error: character '*' is not valid`"}}"
        Get-HTGraphErrorDetail -ErrorRecord (& $script:graphError $body) | Should -Be "invalidRequest: Syntax error: character '*' is not valid"
    }

    It "rozpakowuje komunikat zagnieżdżony jako JSON" {
        $body = '{"error":{"code":"BadRequest","message":"{\"error\":{\"message\":\"Region is required\"}}"}}'
        Get-HTGraphErrorDetail -ErrorRecord (& $script:graphError $body) | Should -Be "BadRequest: Region is required"
    }

    It "zwraca pusty tekst bez JSON-a błędu" {
        Get-HTGraphErrorDetail -ErrorRecord (& $script:graphError "HTTP/1.1 500") | Should -Be ""
        Get-HTGraphErrorDetail -ErrorRecord $null | Should -Be ""
    }

    It "dopisuje przyczynę do komunikatu wyjątku Invoke-HTGraphRequest" {
        $global:HTTestGraphError = & $script:graphError '{"error":{"code":"Request_ResourceNotFound","message":"Resource does not exist."}}'
        Mock -ModuleName ModulesConnection Invoke-MgGraphRequest { throw $global:HTTestGraphError }
        $message = $null
        try { Invoke-HTGraphRequest -Uri "users/x" } catch { $message = $_.Exception.Message }
        $message | Should -Match "BadRequest \(Bad Request\)\. Request_ResourceNotFound: Resource does not exist\."
        Remove-Variable -Name HTTestGraphError -Scope Global -ErrorAction SilentlyContinue
    }
}

Describe "Wyszukiwanie witryn SharePoint" {
    BeforeAll {
        Import-HTTestModule -Name "GraphAPISharePoint"
    }

    It "buduje zapytanie KQL <Expected> dla <Search>" -TestCases @(
        @{ Search = '*'; Expected = '(contentclass:STS_Site OR contentclass:STS_Web)' }
        @{ Search = ''; Expected = '(contentclass:STS_Site OR contentclass:STS_Web)' }
        @{ Search = 'Dział kadr'; Expected = '(Dział* kadr*) AND (contentclass:STS_Site OR contentclass:STS_Web)' }
        @{ Search = 'a "b" title:c OR and'; Expected = '(a* b* title* c* and*) AND (contentclass:STS_Site OR contentclass:STS_Web)' }
    ) {
        param($Search, $Expected)
        ConvertTo-HTSiteSearchQuery -Search $Search | Should -BeExactly $Expected
    }

    It "pobiera witryny przez Microsoft Search API (POST), stronami, bez OneDrive i duplikatów" {
        Mock -ModuleName GraphAPISharePoint Invoke-HTGraphRequest {
            $hits = if ($Body.requests[0].from -eq 0) {
                @(
                    [PSCustomObject]@{ resource = [PSCustomObject]@{ id = 's1'; displayName = 'Kadry'; webUrl = 'https://firma.sharepoint.com/sites/Kadry' } }
                    [PSCustomObject]@{ resource = [PSCustomObject]@{ id = 'p1'; name = 'Jan'; webUrl = 'https://firma-my.sharepoint.com/personal/jan_firma_pl' } }
                )
            }
            else {
                @(
                    [PSCustomObject]@{ resource = [PSCustomObject]@{ id = 's2'; webUrl = 'https://firma.sharepoint.com/sites/Dzia%C5%82%20IT/'; description = 'Opis IT' } }
                    [PSCustomObject]@{ resource = [PSCustomObject]@{ id = 's1'; displayName = 'Kadry'; webUrl = 'https://firma.sharepoint.com/sites/kadry/' } }
                )
            }
            @([PSCustomObject]@{ hitsContainers = @([PSCustomObject]@{ hits = $hits; moreResultsAvailable = ($Body.requests[0].from -eq 0) }) })
        }
        $sites = @(Find-HTSPSites -Search '*')
        $sites.Count | Should -Be 2
        $sites[0].Nazwa | Should -Be 'Dział IT'
        $sites[0].Opis | Should -Be 'Opis IT'
        $sites[1].Nazwa | Should -Be 'Kadry'
        Should -Invoke -ModuleName GraphAPISharePoint Invoke-HTGraphRequest -Times 2 -Exactly -ParameterFilter {
            $Uri -eq 'search/query' -and $Method -eq 'POST' -and $Body.requests[0].entityTypes -contains 'site' -and $Body.requests[0].query.queryString -like '*contentclass:STS_Site*'
        }
        Should -Invoke -ModuleName GraphAPISharePoint Invoke-HTGraphRequest -Times 0 -Exactly -ParameterFilter { $Uri -like 'sites?*search=*' }
    }

    It "przy logowaniu aplikacji używa sites/getAllSites i filtruje po nazwie" {
        Mock -ModuleName GraphAPISharePoint Get-MgContext { [PSCustomObject]@{ AuthType = 'AppOnly' } }
        Mock -ModuleName GraphAPISharePoint Invoke-HTGraphRequest {
            @(
                [PSCustomObject]@{ id = 'a'; displayName = 'Projekty'; webUrl = 'https://firma.sharepoint.com/sites/Projekty' }
                [PSCustomObject]@{ id = 'b'; displayName = 'Kadry'; webUrl = 'https://firma.sharepoint.com/sites/Kadry' }
                [PSCustomObject]@{ id = 'c'; name = 'Jan'; webUrl = 'https://firma-my.sharepoint.com/personal/jan'; isPersonalSite = $true }
            )
        }
        $sites = @(Find-HTSPSites -Search 'proj')
        $sites.Count | Should -Be 1
        $sites[0].Id | Should -Be 'a'
        Should -Invoke -ModuleName GraphAPISharePoint Invoke-HTGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -eq 'sites/getAllSites' -and $All }
    }
}

Describe "Usuwanie licencji bezpośrednich po jednej" {
    It "usuwa pozostałe licencje, gdy jedna nie jest przypisana bezpośrednio, i opisuje błąd po polsku" {
        Mock -ModuleName GraphAPIM365Users Set-HTM365UserLicense {
            if ($RemoveSkuIds -contains 'sku-b') { throw 'Response status code does not indicate success: BadRequest (Bad Request). Request_BadRequest: User does not have a corresponding license.' }
        }
        $result = Remove-HTM365DirectLicenses -Id 'u1' -SkuIds @('sku-a', 'sku-b', 'sku-a') -Names @{ 'sku-a' = 'Licencja A'; 'sku-b' = 'Licencja B' }
        @($result.Removed) | Should -Be @('sku-a')
        @($result.Failed).Count | Should -Be 1
        $result.Failed[0].Name | Should -Be 'Licencja B'
        $result.Failed[0].Error | Should -Match 'nie jest przypisana bezpośrednio'
        Should -Invoke -ModuleName GraphAPIM365Users Set-HTM365UserLicense -Times 2 -Exactly
    }
}

Describe "Nowe grupy Microsoft 365 i zabezpieczeń" {
    It "tworzy alias poczty z nazwy bez polskich znaków i spacji" {
        ConvertTo-HTMailNickname 'Dział Księgowości (Kraków)' | Should -Be 'DzialKsiegowosciKrakow'
        ConvertTo-HTMailNickname 'sp_zarzad.uprawnienia' | Should -Be 'sp_zarzad.uprawnienia'
    }
    It "grupa zabezpieczeń: bez poczty, zabezpieczenia włączone, właściciele i członkowie w żądaniu" {
        $r = Get-HTM365GroupCreateBody -DisplayName 'SP Zarząd' -Type Security -Description 'Uprawnienia witryny' -OwnerIds @('o1') -MemberIds @('u1', 'u2', 'u1')
        $r.Body.mailEnabled | Should -BeFalse
        $r.Body.securityEnabled | Should -BeTrue
        @($r.Body.groupTypes).Count | Should -Be 0
        $r.Body.mailNickname | Should -Be 'SPZarzad'
        $r.Body['owners@odata.bind'] | Should -Be @('https://graph.microsoft.com/v1.0/users/o1')
        @($r.Body['members@odata.bind']).Count | Should -Be 2
    }
    It "grupa Microsoft 365: poczta, typ Unified i widoczność; ponad 20 członków - reszta osobno" {
        $members = @(1..25 | ForEach-Object { "u$_" })
        $r = Get-HTM365GroupCreateBody -DisplayName 'Projekt X' -Type Microsoft365 -Visibility Public -MailNickname 'projektx' -MemberIds $members
        $r.Body.groupTypes | Should -Be @('Unified')
        $r.Body.mailEnabled | Should -BeTrue
        $r.Body.visibility | Should -Be 'Public'
        $r.Body.mailNickname | Should -Be 'projektx'
        @($r.Body['members@odata.bind']).Count | Should -Be 20
        $r.ExtraMembers | Should -Be @('u21', 'u22', 'u23', 'u24', 'u25')
    }
    It "login grupy do uprawnień SharePoint zależy od typu grupy" {
        Get-HTSPGroupClaim ([PSCustomObject]@{ Id = 'g-1'; Type = 'Microsoft 365' }) | Should -Be 'c:0o.c|federateddirectoryclaimprovider|g-1'
        Get-HTSPGroupClaim ([PSCustomObject]@{ Id = 'g-2'; Type = 'Zabezpieczeń' }) | Should -Be 'c:0t.c|tenant|g-2'
    }
}

Describe "Grupy jako obiekty" {
    It "rozpoznaje członków: użytkownik, gość, grupa, urządzenie; zablokowane wyszarzone" {
        $u = ConvertTo-HTM365DirectoryObjectRow ([PSCustomObject]@{ '@odata.type' = '#microsoft.graph.user'; id = 'u1'; displayName = 'Jan'; userPrincipalName = 'jan@firma.pl'; userType = 'Member'; accountEnabled = $false })
        $u.Rodzaj | Should -Be 'Użytkownik'
        $u.Adres | Should -Be 'jan@firma.pl'
        $u.__flag | Should -Be 'muted'
        (ConvertTo-HTM365DirectoryObjectRow ([PSCustomObject]@{ '@odata.type' = '#microsoft.graph.user'; id = 'g'; displayName = 'Gość'; mail = 'x@zew.pl'; userType = 'Guest'; accountEnabled = $true })).Rodzaj | Should -Be 'Gość'
        (ConvertTo-HTM365DirectoryObjectRow ([PSCustomObject]@{ '@odata.type' = '#microsoft.graph.group'; id = 'g2'; displayName = 'Zagnieżdżona' })).Rodzaj | Should -Be 'Grupa'
        (ConvertTo-HTM365DirectoryObjectRow ([PSCustomObject]@{ '@odata.type' = '#microsoft.graph.device'; id = 'd'; displayName = 'PC-1' })).Rodzaj | Should -Be 'Urządzenie'
    }
    It "zmiany grupy: tylko różniące się pola, widoczność tylko dla Microsoft 365, opis nieprzekazany - bez zmian" {
        $g = [PSCustomObject]@{ DisplayName = 'Projekt'; Description = 'Opis'; Type = 'Microsoft 365'; Visibility = 'Private' }
        $c = Get-HTM365GroupChanges -Group $g -DisplayName 'Projekt X' -Visibility 'Public'
        $c.displayName | Should -Be 'Projekt X'
        $c.visibility | Should -Be 'Public'
        $c.Contains('description') | Should -BeFalse
        (Get-HTM365GroupChanges -Group $g -DisplayName 'Projekt' -Description '').Contains('description') | Should -BeTrue
        $sec = [PSCustomObject]@{ DisplayName = 'SG'; Description = ''; Type = 'Zabezpieczeń'; Visibility = '' }
        (Get-HTM365GroupChanges -Group $sec -DisplayName 'SG' -Visibility 'Public').Count | Should -Be 0
    }
    It "właścicieli grup pocztowych i z AD nie zmienia się przez Graph" {
        Test-HTM365GroupOwnersEditable ([PSCustomObject]@{ Type = 'Microsoft 365'; Synced = $false }) | Should -BeTrue
        Test-HTM365GroupOwnersEditable ([PSCustomObject]@{ Type = 'Dystrybucyjna'; Synced = $false }) | Should -BeFalse
        Test-HTM365GroupOwnersEditable ([PSCustomObject]@{ Type = 'Zabezpieczeń'; Synced = $true }) | Should -BeFalse
    }
    It "rozpoznaje zespół Teams i dane grupy" {
        $g = ConvertTo-HTM365GroupObject ([PSCustomObject]@{ id = 'g'; displayName = 'Zespół'; groupTypes = @('Unified'); mailEnabled = $true; securityEnabled = $false; resourceProvisioningOptions = @('Team'); visibility = 'Private'; mailNickname = 'zespol' })
        $g.IsTeam | Should -BeTrue
        $g.Type | Should -Be 'Microsoft 365'
        $g.Visibility | Should -Be 'Private'
    }
}

Describe "Zaproszenia gości (B2B)" {
    It "lista gości: adres, «adres; nazwa», «Nazwa <adres>», błędne i powtórzone adresy" {
        $r = @(ConvertFrom-HTGuestInviteList "jan@zew.pl`r`nanna@firma.com; Anna Nowak`r`nPiotr Kowal <piotr@x.org>`r`nzly-adres`r`nJAN@zew.pl`r`n`r`n")
        $r.Count | Should -Be 5
        $r[0].Email | Should -Be 'jan@zew.pl'
        $r[0].Problem | Should -Be ''
        $r[1].DisplayName | Should -Be 'Anna Nowak'
        $r[2].Email | Should -Be 'piotr@x.org'
        $r[2].DisplayName | Should -Be 'Piotr Kowal'
        $r[3].Problem | Should -Be 'Niepoprawny adres e-mail'
        $r[4].Problem | Should -Be 'Adres powtórzony na liście'
    }
    It "zaproszenie z e-mailem: wiadomość, język polski, tylko jedna kopia (limit Graph)" {
        $b = Get-HTGuestInvitationBody -Email ' jan@zew.pl ' -DisplayName 'Jan' -Message 'Witaj' -CcRecipients @('a@firma.pl', 'b@firma.pl')
        $b.invitedUserEmailAddress | Should -Be 'jan@zew.pl'
        $b.invitedUserDisplayName | Should -Be 'Jan'
        $b.sendInvitationMessage | Should -BeTrue
        $b.inviteRedirectUrl | Should -Be 'https://myapps.microsoft.com'
        $b.invitedUserMessageInfo.customizedMessageBody | Should -Be 'Witaj'
        $b.invitedUserMessageInfo.messageLanguage | Should -Be 'pl-PL'
        @($b.invitedUserMessageInfo.ccRecipients).Count | Should -Be 1
        $b.invitedUserMessageInfo.ccRecipients[0].emailAddress.address | Should -Be 'a@firma.pl'
    }
    It "bez e-maila: bez treści wiadomości, własna strona po przyjęciu" {
        $b = Get-HTGuestInvitationBody -Email 'jan@zew.pl' -SendInvitation $false -Message 'x' -RedirectUrl 'https://firma.sharepoint.com/sites/x'
        $b.sendInvitationMessage | Should -BeFalse
        $b.Contains('invitedUserMessageInfo') | Should -BeFalse
        $b.inviteRedirectUrl | Should -Be 'https://firma.sharepoint.com/sites/x'
    }
    It "zaproszenie zwraca konto gościa i link do przyjęcia" {
        Mock -ModuleName GraphAPIM365Users Invoke-HTGraphRequest { [PSCustomObject]@{ invitedUserEmailAddress = 'jan@zew.pl'; status = 'PendingAcceptance'; inviteRedeemUrl = 'https://login/redeem'; invitedUser = [PSCustomObject]@{ id = 'u-1' } } }
        $r = New-HTM365GuestInvitation -Email 'jan@zew.pl' -SendInvitation $false
        $r.UserId | Should -Be 'u-1'
        $r.RedeemUrl | Should -Be 'https://login/redeem'
        $r.Status | Should -Be 'PendingAcceptance'
        Should -Invoke -ModuleName GraphAPIM365Users Invoke-HTGraphRequest -Times 1 -ParameterFilter { $Uri -eq 'invitations' -and $Method -eq 'POST' -and $Body.sendInvitationMessage -eq $false }
    }
}

Describe "Licencje grupowe" {
    It "licencje tylko dla grup zabezpieczeń i grup Microsoft 365 z zabezpieczeniami" {
        Test-HTM365GroupLicensable ([PSCustomObject]@{ Type = 'Zabezpieczeń' }) | Should -BeTrue
        Test-HTM365GroupLicensable ([PSCustomObject]@{ Type = 'Zabezpieczeń (mail)' }) | Should -BeTrue
        Test-HTM365GroupLicensable ([PSCustomObject]@{ Type = 'Dystrybucyjna' }) | Should -BeFalse
        Test-HTM365GroupLicensable ([PSCustomObject]@{ Type = 'Microsoft 365'; SecurityEnabled = $false }) | Should -BeFalse
        Test-HTM365GroupLicensable ([PSCustomObject]@{ Type = 'Microsoft 365'; SecurityEnabled = $true }) | Should -BeTrue
    }
    It "obiekt grupy ma SecurityEnabled" {
        (ConvertTo-HTM365GroupObject ([PSCustomObject]@{ id = 'g'; displayName = 'G'; groupTypes = @('Unified'); securityEnabled = $true; mailEnabled = $true })).SecurityEnabled | Should -BeTrue
    }
    It "treść przypisania: dodawane SKU bez powtórzeń, usuwane osobno" {
        $b = Get-HTGroupLicenseBody -AddSkuIds @('s1', 's1', 's2') -RemoveSkuIds @('s3')
        @($b.addLicenses).Count | Should -Be 2
        $b.addLicenses[0].skuId | Should -Be 's1'
        @($b.addLicenses[0].disabledPlans).Count | Should -Be 0
        $b.removeLicenses | Should -Be @('s3')
    }
    It "bez zmian nie wysyła żądania; zmiana - POST assignLicense grupy" {
        Mock -ModuleName GraphAPIM365Users Invoke-HTGraphRequest { }
        Set-HTM365GroupLicense -Id 'g1'
        Should -Invoke -ModuleName GraphAPIM365Users Invoke-HTGraphRequest -Times 0 -Exactly
        Set-HTM365GroupLicense -Id 'g1' -AddSkuIds @('s1')
        Should -Invoke -ModuleName GraphAPIM365Users Invoke-HTGraphRequest -Times 1 -ParameterFilter { $Uri -eq 'groups/g1/assignLicense' -and $Method -eq 'POST' }
    }
}

Describe "Domeny tenanta" {
    It "wiersz domeny: usługi po polsku, niezweryfikowana na czerwono z podpowiedzią" {
        $r = ConvertTo-HTDomainRow ([PSCustomObject]@{ id = 'firma.pl'; isVerified = $false; isDefault = $false; isInitial = $false; authenticationType = 'Managed'; supportedServices = @() })
        $r.Zweryfikowana | Should -BeFalse
        $r.__flag | Should -Be 'crit'
        $r.Uwagi | Should -Match 'niezweryfikowana'
        $ok = ConvertTo-HTDomainRow ([PSCustomObject]@{ id = 'firma.pl'; isVerified = $true; isDefault = $true; authenticationType = 'Managed'; supportedServices = @('Email', 'OfficeCommunicationsOnline') })
        $ok.Usługi | Should -Be 'poczta, Teams (Skype)'
        $ok.Uwierzytelnianie | Should -Be 'w chmurze'
        $ok.__flag | Should -Be ''
    }
    It "rekordy DNS: wartość zależnie od typu (TXT, MX, CNAME, SRV)" {
        (ConvertTo-HTDomainDnsRow ([PSCustomObject]@{ recordType = 'Txt'; label = 'firma.pl'; text = 'MS=ms123'; ttl = 3600 })).Wartość | Should -Be 'MS=ms123'
        $mx = ConvertTo-HTDomainDnsRow ([PSCustomObject]@{ recordType = 'Mx'; label = 'firma.pl'; mailExchange = 'firma-pl.mail.protection.outlook.com'; preference = 0; supportedService = 'Email' })
        $mx.Typ | Should -Be 'MX'
        $mx.Priorytet | Should -Be 0
        $mx.Usługa | Should -Be 'poczta'
        (ConvertTo-HTDomainDnsRow ([PSCustomObject]@{ recordType = 'CName'; label = 'autodiscover.firma.pl'; canonicalName = 'autodiscover.outlook.com' })).Wartość | Should -Be 'autodiscover.outlook.com'
        $srv = ConvertTo-HTDomainDnsRow ([PSCustomObject]@{ recordType = 'Srv'; label = 'firma.pl'; service = '_sip'; protocol = '_tls'; priority = 100; weight = 1; port = 443; nameTarget = 'sipdir.online.lync.com' })
        $srv.Nazwa | Should -Be '_sip._tls.firma.pl'
        $srv.Wartość | Should -Be '100 1 443 sipdir.online.lync.com'
    }
    It "porównanie z DNS: bez wielkości liter, kropki na końcu i cudzysłowów" {
        Compare-HTDnsRecordValue -Expected 'Autodiscover.Outlook.com' -Actual @('autodiscover.outlook.com.') | Should -BeTrue
        Compare-HTDnsRecordValue -Expected 'MS=ms123' -Actual @('"MS=ms123"', 'v=spf1') | Should -BeTrue
        Compare-HTDnsRecordValue -Expected 'MS=ms123' -Actual @('MS=ms999') | Should -BeFalse
        Compare-HTDnsRecordValue -Expected '' -Actual @('x') | Should -BeFalse
    }
}

Describe "Informacje o witrynie SharePoint (PnP 3.x)" {
    BeforeAll {
        Import-HTTestModule -Name "GraphAPISharePoint"
        # Atrapy z walidacją -Includes jak w PnP.PowerShell 3.x (fragment listy właściwości Site / Web)
        function global:Get-PnPSite { param([ValidateSet('Usage', 'Owner', 'Url', 'ServerRelativeUrl', 'ReadOnly', 'WriteLocked', 'RootWeb', 'Id')][string[]]$Includes, $ErrorAction)
            [PSCustomObject]@{ Url = 'https://firma.sharepoint.com/sites/Kadry'; ReadOnly = $false; WriteLocked = $false; Owner = [PSCustomObject]@{ Title = 'Anna'; Email = 'anna@firma.pl' }; Usage = [PSCustomObject]@{ Storage = 1GB; StoragePercentageUsed = 0.25 } } }
        function global:Get-PnPWeb { param([ValidateSet('Created', 'LastItemModifiedDate', 'Language', 'WebTemplate', 'Description', 'Title', 'RoleAssignments')][string[]]$Includes, $ErrorAction)
            [PSCustomObject]@{ Title = 'Kadry'; Description = ''; WebTemplate = 'GROUP'; Created = (Get-Date '2025-01-01'); LastItemModifiedDate = (Get-Date '2026-10-01') } }
        function global:Get-PnPSiteCollectionAdmin { param($ErrorAction) [PSCustomObject]@{ Title = 'Admin'; Email = 'admin@firma.pl' } }
    }
    AfterAll {
        foreach ($n in 'Get-PnPSite', 'Get-PnPWeb', 'Get-PnPSiteCollectionAdmin', 'Get-PnPTenantSite') { Remove-Item -LiteralPath "Function:$n" -ErrorAction SilentlyContinue }
    }
    It "bez roli administratora SharePoint - opis zamiast limitu i udostępniania, bez błędu" {
        function global:Get-PnPTenantSite { param($Identity, $ErrorAction) throw 'Access denied' }
        $info = Get-HTSPSiteInfo
        $info.'Tytuł' | Should -Be 'Kadry'
        $info.Magazyn.Limit | Should -Match 'administratora'
        $info.Magazyn.'Procent limitu' | Should -Match '25'
        $info.'Udostępnianie zewnętrzne' | Should -Match 'administratora'
    }
    It "z rolą administratora - limit, blokada i udostępnianie z witryny w tenancie" {
        function global:Get-PnPTenantSite { param($Identity, $ErrorAction) [PSCustomObject]@{ StorageQuota = 1024; LockState = 'Unlock'; SharingCapability = 'ExternalUserSharingOnly' } }
        $info = Get-HTSPSiteInfo
        $info.Magazyn.Limit | Should -Be (Format-HTBytes (1024 * 1MB))
        $info.'Stan blokady' | Should -Be 'Unlock'
        $info.'Udostępnianie zewnętrzne' | Should -Be 'ExternalUserSharingOnly'
    }
}
