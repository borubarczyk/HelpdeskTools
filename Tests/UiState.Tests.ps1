BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "UiState"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Zapamiętany stan interfejsu" {
    BeforeEach {
        $Global:ConfigDir = Join-Path $TestDrive ("ui_" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $Global:ConfigDir -Force | Out-Null
        [void](Get-HTUiState -Reload)
    }

    It "domyślne wartości bez pliku" {
        $s = Get-HTUiState -Reload
        @($s.Favorites).Count | Should -Be 0
        $s.LogHeight | Should -Be 200
    }
    It "ulubione: dodanie, sprawdzenie i usunięcie z zapisem do pliku" {
        Set-HTFavoriteModule -Key "m365.details" -Favorite $true
        Test-HTFavoriteModule "m365.details" | Should -BeTrue
        $reloaded = Get-HTUiState -Reload
        @($reloaded.Favorites) | Should -Contain "m365.details"
        Set-HTFavoriteModule -Key "m365.details" -Favorite $false
        Test-HTFavoriteModule "m365.details" | Should -BeFalse
    }
    It "ostatnie moduły: najnowszy pierwszy, bez powtórzeń, maks. 12" {
        foreach ($i in 1..15) { Add-HTRecentModule -Key "mod$i" -Workspace "WS" }
        Add-HTRecentModule -Key "mod10" -Workspace "WS"
        $s = Get-HTUiState -Reload
        @($s.Recent)[0] | Should -Be "mod10"
        @($s.Recent).Count | Should -Be 12
        @($s.Recent | Where-Object { $_ -eq "mod10" }).Count | Should -Be 1
        $s.LastModules["WS"] | Should -Be "mod10"
        $s.LastWorkspace | Should -Be "WS"
    }
    It "ukryte kolumny modułu" {
        Set-HTModuleHiddenColumns -Key "exo.usage" -Columns @("Id", "Elementy")
        $h = @(Get-HTModuleHiddenColumns "exo.usage")
        $h | Should -Contain "Elementy"
        $h.Count | Should -Be 2
    }
    It "zapisane widoki filtrów: zapis, nadpisanie tej samej nazwy i usunięcie" {
        $filters = [ordered]@{ Stan = @{ Values = (New-Object 'System.Collections.Generic.HashSet[string]' (, [string[]]@('Błąd'))); Op = ''; Text = '' } }
        $preset = ConvertTo-HTFilterPreset -Name "Błędy" -Text "kowalski" -ColumnFilters $filters -Hidden @("Id")
        $preset.Name | Should -Be "Błędy"
        @($preset.Filters).Count | Should -Be 1
        Save-HTFilterPreset -Key "m1" -Preset $preset
        Save-HTFilterPreset -Key "m1" -Preset (ConvertTo-HTFilterPreset -Name "Błędy" -Text "nowak" -ColumnFilters @{} -Hidden @())
        $list = @(Get-HTFilterPresets "m1")
        $list.Count | Should -Be 1
        $list[0].Text | Should -Be "nowak"
        Remove-HTFilterPreset -Key "m1" -Name "Błędy"
        @(Get-HTFilterPresets "m1").Count | Should -Be 0
    }
}

Describe "Dodatkowe kolumny modułu" {
    It "zapis, odczyt po ponownym wczytaniu i usunięcie" {
        Set-HTModuleExtraColumns -Key 'm365.rep.mfa' -Columns @('M365User|jobTitle', 'M365User|jobTitle', 'M365User|createdDateTime')
        Get-HTUiState -Reload | Out-Null
        @(Get-HTModuleExtraColumns 'm365.rep.mfa') | Should -Be @('M365User|jobTitle', 'M365User|createdDateTime')
        Set-HTModuleExtraColumns -Key 'm365.rep.mfa' -Columns @()
        @(Get-HTModuleExtraColumns 'm365.rep.mfa').Count | Should -Be 0
    }
}
