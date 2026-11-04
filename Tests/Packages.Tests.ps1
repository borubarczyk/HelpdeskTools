BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "ModulesConnection"
    Initialize-HTTestEnvironment -Root $TestDrive

    # Kompilacja testowej biblioteki o podanej nazwie i wersji (kompilator Roslyn dostarczany z PowerShell)
    Add-Type -AssemblyName Microsoft.CodeAnalysis, Microsoft.CodeAnalysis.CSharp
    function New-TestAssembly {
        param([string]$Directory, [string]$Name, [string]$Version, [string]$Code, [string[]]$References = @())
        New-Item -ItemType Directory -Path $Directory -Force | Out-Null
        $path = Join-Path $Directory "$Name.dll"
        $source = "[assembly: System.Reflection.AssemblyVersion(""$Version"")]`n$Code"
        $tree = [Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree]::ParseText($source)
        $refs = New-Object 'System.Collections.Generic.List[Microsoft.CodeAnalysis.MetadataReference]'
        foreach ($r in @([object].Assembly.Location, (Join-Path $PSHOME "System.Runtime.dll")) + $References) { $refs.Add([Microsoft.CodeAnalysis.MetadataReference]::CreateFromFile($r)) }
        $options = [Microsoft.CodeAnalysis.CSharp.CSharpCompilationOptions]::new([Microsoft.CodeAnalysis.OutputKind]::DynamicallyLinkedLibrary)
        $compilation = [Microsoft.CodeAnalysis.CSharp.CSharpCompilation]::Create($Name, [Microsoft.CodeAnalysis.SyntaxTree[]]@($tree), $refs, $options)
        $stream = [System.IO.File]::Create($path)
        try { $result = $compilation.Emit($stream) } finally { $stream.Dispose() }
        if (-not $result.Success) { throw (($result.Diagnostics | ForEach-Object { $_.ToString() }) -join "`n") }
        return $path
    }
    $libCode = 'namespace HTShared { public static class Lib { public static int Value() { return 1; } } }'
    $script:Root = Join-Path $TestDrive "packages"
    $newLib = New-TestAssembly -Directory (Join-Path $script:Root "lib2") -Name "HT.Shared" -Version "2.0.0.0" -Code $libCode
    New-TestAssembly -Directory (Join-Path $script:Root "runtimeOld") -Name "HT.Shared" -Version "1.0.0.0" -Code $libCode | Out-Null
    New-TestAssembly -Directory (Join-Path $script:Root "runtimeNew") -Name "HT.Shared" -Version "2.0.0.0" -Code $libCode | Out-Null
    # «Moduł», który wymaga nowszej biblioteki (jak moduł zbudowany pod nowszy .NET)
    $script:ModuleDir = Join-Path $script:Root "Module\1.0.0"
    New-TestAssembly -Directory $script:ModuleDir -Name "HT.Consumer" -Version "1.0.0.0" -References $newLib `
        -Code 'namespace HTConsumer { public static class C { public static int Use() { return HTShared.Lib.Value(); } } }' | Out-Null
    # Biblioteka dla Windows PowerShell (.NET Framework) - powinna być pominięta
    New-Item -ItemType Directory -Path (Join-Path $script:ModuleDir "netFramework") -Force | Out-Null
    Copy-Item (Join-Path $script:ModuleDir "HT.Consumer.dll") (Join-Path $script:ModuleDir "netFramework\HT.Framework.dll")
    $script:MsalLib = New-TestAssembly -Directory (Join-Path $script:Root "msal") -Name "Microsoft.Identity.Client" -Version "4.70.0.0" `
        -Code 'namespace HTMsal { public static class M { public static int Value() { return 2; } } }'
}

Describe "Get-HTAssemblyInfo" {
    It "odczytuje nazwę, wersję i odwołania bez ładowania biblioteki" {
        $info = Get-HTAssemblyInfo -Path (Join-Path $script:ModuleDir "HT.Consumer.dll")
        $info.Name | Should -Be "HT.Consumer"
        ($info.References | Where-Object Name -eq "HT.Shared").Version | Should -Be ([version]"2.0.0.0")
    }
    It "zwraca null dla pliku, który nie jest biblioteką .NET" {
        $path = Join-Path $TestDrive "native.dll"
        [System.IO.File]::WriteAllBytes($path, [byte[]](1..64))
        Get-HTAssemblyInfo -Path $path | Should -BeNullOrEmpty
    }
}

Describe "Test-HTModuleCompatibility" {
    It "wykrywa moduł wymagający nowszej biblioteki niż dostarczona z PowerShell" {
        $r = Test-HTModuleCompatibility -ModuleBase $script:ModuleDir -RuntimeDirectory (Join-Path $script:Root "runtimeOld") -SkipLoadedCheck
        $r.Compatible | Should -BeFalse
        $r.RuntimeIssues[0].Assembly | Should -Be "HT.Shared"
        $r.RuntimeIssues[0].Required | Should -Be ([version]"2.0.0.0")
        $r.RuntimeIssues[0].Available | Should -Be ([version]"1.0.0.0")
    }
    It "uznaje moduł za zgodny, gdy PowerShell ma wymaganą wersję" {
        (Test-HTModuleCompatibility -ModuleBase $script:ModuleDir -RuntimeDirectory (Join-Path $script:Root "runtimeNew") -SkipLoadedCheck).Compatible | Should -BeTrue
    }
    It "zgłasza konflikt z biblioteką współdzieloną załadowaną przez inny moduł" {
        $dir = Join-Path $script:Root "ConflictModule"
        New-TestAssembly -Directory $dir -Name "HT.Auth" -Version "1.0.0.0" -References $script:MsalLib `
            -Code 'namespace HTAuth { public static class A { public static int Use() { return HTMsal.M.Value(); } } }' | Out-Null
        $loaded = @([PSCustomObject]@{ Name = "Microsoft.Identity.Client"; Version = [version]"4.60.0.0"; Location = "C:\Modules\Other\Microsoft.Identity.Client.dll" })
        $r = Test-HTModuleCompatibility -ModuleBase $dir -RuntimeDirectory (Join-Path $script:Root "runtimeNew") -LoadedAssemblies $loaded
        $r.Compatible | Should -BeTrue
        $r.LoadedIssues[0].Assembly | Should -Be "Microsoft.Identity.Client"
        $r.LoadedIssues[0].Available | Should -Be ([version]"4.60.0.0")
    }
}

Describe "ConvertFrom-HTAssemblyLoadError" {
    It "rozpoznaje moduł wymagający nowszego .NET (System.Text.Json 10)" {
        $err = [System.IO.FileNotFoundException]::new("Could not load file or assembly 'System.Text.Json, Version=99.0.0.0, Culture=neutral, PublicKeyToken=cc7b13ffcd2ddd51'. The system cannot find the file specified.")
        $problem = ConvertFrom-HTAssemblyLoadError -ErrorRecord $err -Module "Microsoft.Graph.Authentication"
        $problem.Data["HTKind"] | Should -Be "Runtime"
        $problem.Data["HTModule"] | Should -Be "Microsoft.Graph.Authentication"
        $problem.Message | Should -Match "System.Text.Json"
    }
    It "zwraca null dla innych błędów" {
        ConvertFrom-HTAssemblyLoadError -ErrorRecord ([System.Exception]::new("AADSTS50076: MFA required")) -Module "X" | Should -BeNullOrEmpty
    }
}

Describe "Resolve-HTModuleVersion" {
    It "zgłasza brak modułu" {
        (Resolve-HTModuleVersion -Name "HT.Nieistniejacy.Modul").Status | Should -Be "Missing"
    }
    It "wybiera najnowszą wersję ze sprawdzonego zakresu, nawet gdy zainstalowana jest nowsza wersja główna" {
        Mock -ModuleName ModulesConnection Get-Module {
            if ($ListAvailable) { @([PSCustomObject]@{ Name = 'PnP.PowerShell'; Version = [version]'4.1.0'; ModuleBase = 'C:\m\4.1.0'; Path = 'C:\m\4.1.0\PnP.psd1' }, [PSCustomObject]@{ Name = 'PnP.PowerShell'; Version = [version]'3.4.1'; ModuleBase = 'C:\m\3.4.1'; Path = 'C:\m\3.4.1\PnP.psd1' }, [PSCustomObject]@{ Name = 'PnP.PowerShell'; Version = [version]'2.12.0'; ModuleBase = 'C:\m\2.12.0'; Path = 'C:\m\2.12.0\PnP.psd1' }) }
        }
        Mock -ModuleName ModulesConnection Test-HTModuleCompatibility { [PSCustomObject]@{ Compatible = $true; RuntimeIssues = @(); LoadedIssues = @() } }
        $r = Resolve-HTModuleVersion -Name 'PnP.PowerShell'
        $r.Status | Should -Be 'Compatible'
        "$($r.Module.Version)" | Should -Be '3.4.1'
    }
    It "gdy w zakresie nie ma wersji - używa zainstalowanej spoza zakresu" {
        Mock -ModuleName ModulesConnection Get-Module { if ($ListAvailable) { @([PSCustomObject]@{ Name = 'PnP.PowerShell'; Version = [version]'2.12.0'; ModuleBase = 'C:\m\2.12.0'; Path = 'C:\m\2.12.0\PnP.psd1' }) } }
        Mock -ModuleName ModulesConnection Test-HTModuleCompatibility { [PSCustomObject]@{ Compatible = $true; RuntimeIssues = @(); LoadedIssues = @() } }
        "$((Resolve-HTModuleVersion -Name 'PnP.PowerShell').Module.Version)" | Should -Be '2.12.0'
    }
}

Describe "Wymagane wersje modułów" {
    It "każdy moduł ma wersję minimalną, maksymalną wersję główną i testowaną w zakresie" {
        $req = Get-HTModuleRequirements
        foreach ($name in 'Microsoft.Graph.Authentication', 'ExchangeOnlineManagement', 'PnP.PowerShell') {
            $req.Contains($name) | Should -BeTrue -Because $name
            Test-HTModuleVersionSupported -Name $name -Version $req[$name].Tested | Should -BeTrue -Because $name
        }
    }
    It "zakres: minimalna wersja, wersja główna, przyrostek wydania wstępnego, moduł bez wymagań" {
        Test-HTModuleVersionSupported -Name 'ExchangeOnlineManagement' -Version '3.7.2' | Should -BeTrue
        Test-HTModuleVersionSupported -Name 'ExchangeOnlineManagement' -Version '3.7.1' | Should -BeFalse
        Test-HTModuleVersionSupported -Name 'PnP.PowerShell' -Version '4.0.0' | Should -BeFalse
        Test-HTModuleVersionSupported -Name 'Microsoft.Graph.Authentication' -Version '2.41.1-preview' | Should -BeTrue
        Test-HTModuleVersionSupported -Name 'HT.Inny' -Version '0.1' | Should -BeTrue
        Test-HTModuleVersionSupported -Name 'PnP.PowerShell' -Version $null | Should -BeFalse
    }
    It "ocena wersji: OK, starsza, nowsza wersja główna, brak" {
        (Test-HTModuleVersion -Name 'PnP.PowerShell' -Version '3.4.1').Status | Should -Be 'OK'
        (Test-HTModuleVersion -Name 'PnP.PowerShell' -Version '3.2.0').Text | Should -Match 'testowana 3.4.1'
        (Test-HTModuleVersion -Name 'PnP.PowerShell' -Version '2.12.0').Text | Should -Match 'starsza'
        (Test-HTModuleVersion -Name 'PnP.PowerShell' -Version '4.0.1').Text | Should -Match 'nowsza wersja główna'
        (Test-HTModuleVersion -Name 'ExchangeOnlineManagement' -Version $null).Status | Should -Be 'Uwaga'
    }
    It "instalacja: sprawdzona wersja; gdy jej nie ma w galerii - najnowsza z wersji głównej" {
        if (-not (Get-Command -Name Install-Module -ErrorAction Ignore)) { New-HTTestStub -Name 'Install-Module' -Parameters 'Name', 'Scope', 'Repository', 'RequiredVersion', 'MinimumVersion', 'MaximumVersion' -Switches 'Force', 'AllowClobber', 'AcceptLicense' }
        Mock -ModuleName ModulesConnection Write-Log { }
        Mock -ModuleName ModulesConnection Restore-HTSkippedModulePaths { }
        Mock -ModuleName ModulesConnection Install-Module { }
        Install-HTTestedModule -Name 'PnP.PowerShell' -Scope 'CurrentUser' | Should -Be ([version](Get-HTModuleRequirements)['PnP.PowerShell'].Tested)
        Should -Invoke -ModuleName ModulesConnection Install-Module -Times 1 -ParameterFilter { $RequiredVersion -eq (Get-HTModuleRequirements)['PnP.PowerShell'].Tested }
        Mock -ModuleName ModulesConnection Install-Module { if ($RequiredVersion) { throw 'No match was found' } }
        Mock -ModuleName ModulesConnection Get-Module { if ($ListAvailable) { @([PSCustomObject]@{ Name = 'PnP.PowerShell'; Version = [version]'3.9.0' }) } }
        Install-HTTestedModule -Name 'PnP.PowerShell' -Scope 'CurrentUser' | Should -Be ([version]'3.9.0')
        Should -Invoke -ModuleName ModulesConnection Install-Module -Times 1 -ParameterFilter { $MaximumVersion -eq '3.999.999' }
    }
}

Describe "Moduły w OneDrive (pliki tylko w chmurze)" {
    It "rozpoznaje atrybuty plików tylko w chmurze" {
        Test-HTCloudOnlyAttributes ([System.IO.FileAttributes]::Archive) | Should -BeFalse
        Test-HTCloudOnlyAttributes ([System.IO.FileAttributes]::Offline) | Should -BeTrue
        Test-HTCloudOnlyAttributes (0x400000 -bor 0x20) | Should -BeTrue
        Test-HTCloudOnlyAttributes 0x40000 | Should -BeTrue
    }
    It "rozpoznaje błąd niedziałającego dostawcy plików w chmurze i ścieżkę pliku" {
        $text = "Dostawca plików w chmurze nie jest uruchomiony. : 'C:\Users\jan\OneDrive\Documents\PowerShell\Modules\PackageManagement\1.4.8.1\PackageManagement.format.ps1xml'."
        Test-HTCloudFileError $text | Should -BeTrue
        Test-HTCloudFileError 'The cloud file provider is not running.' | Should -BeTrue
        Test-HTCloudFileError ([System.ComponentModel.Win32Exception]::new(0x16A)) | Should -BeTrue
        Test-HTCloudFileError 'Access is denied.' | Should -BeFalse
        Get-HTErrorFilePath $text | Should -Be 'C:\Users\jan\OneDrive\Documents\PowerShell\Modules\PackageManagement\1.4.8.1\PackageManagement.format.ps1xml'
    }
    It "wskazuje folder modułów z PSModulePath dla pliku i rozpoznaje folder OneDrive" {
        $paths = @('C:\Users\jan\OneDrive\Documents\PowerShell\Modules', 'C:\Program Files\PowerShell\Modules', 'C:\Program Files\PowerShell\7\Modules')
        Get-HTModulePathOfFile -File 'C:\Users\jan\OneDrive\Documents\PowerShell\Modules\PackageManagement\1.4.8.1\x.ps1xml' -Paths $paths | Should -Be $paths[0]
        Get-HTModulePathOfFile -File 'C:\Program Files\PowerShell\7\Modules\PowerShellGet\PSGet.psd1' -Paths $paths | Should -Be $paths[2]
        Get-HTModulePathOfFile -File 'D:\inne\plik.txt' -Paths $paths | Should -Be ''
        Test-HTOneDrivePath 'C:\Users\jan\OneDrive - Firma sp. z o.o.\Dokumenty\PowerShell\Modules' | Should -BeTrue
        Test-HTOneDrivePath 'C:\Users\jan\OneDrive\Documents\PowerShell\Modules' | Should -BeTrue
        Test-HTOneDrivePath 'C:\Program Files\PowerShell\Modules' | Should -BeFalse
    }
    It "pomija w sesji folder modułów z pliku z komunikatu błędu" {
        $sep = [System.IO.Path]::PathSeparator
        $saved = $env:PSModulePath
        try {
            $one = Join-Path $TestDrive 'OneDrive\Documents\PowerShell\Modules'
            $other = Join-Path $TestDrive 'Program Files\PowerShell\Modules'
            $env:PSModulePath = @($one, $other) -join $sep
            $removed = @(Repair-HTModulePath -File (Join-Path $one 'PackageManagement\1.4.8.1\PackageManagement.format.ps1xml') -NoDetection)
            $removed | Should -Be @($one)
            $env:PSModulePath | Should -Be $other
            $global:HTSkippedModulePaths | Should -Contain $one
            @(Repair-HTModulePath -File 'D:\inny.txt' -NoDetection).Count | Should -Be 0
        }
        finally { $env:PSModulePath = $saved }
    }
    It "zapamiętuje pominięty folder w konfiguracji i pomija go ponownie, gdy wróci do PSModulePath" {
        Import-HTTestModule -Name "Config"
        $sep = [System.IO.Path]::PathSeparator
        $saved = $env:PSModulePath
        $savedConfig = $Global:HTConfig
        try {
            $Global:HTConfig = (Merge-HTConfig -Config $null).Config
            $global:HTSkippedModulePaths = @()
            $one = Join-Path $TestDrive 'OneDrive2\Documents\PowerShell\Modules'
            $other = Join-Path $TestDrive 'Program Files2\PowerShell\Modules'
            $env:PSModulePath = @($one, $other) -join $sep
            @(Repair-HTModulePath -Path $one -NoDetection).Count | Should -Be 1
            @(Get-HTSavedSkippedModulePaths) | Should -Be @($one)
            # Install-Module / nowy proces PowerShell dopisuje folder z powrotem
            $global:HTSkippedModulePaths = @()
            $env:PSModulePath = @($one, $other) -join $sep
            @(Restore-HTSkippedModulePaths) | Should -Be @($one)
            $env:PSModulePath | Should -Be $other
            # Bez zmian, gdy folderu nie ma w PSModulePath
            @(Restore-HTSkippedModulePaths).Count | Should -Be 0
            Clear-HTSkippedModulePaths
            @(Get-HTSavedSkippedModulePaths).Count | Should -Be 0
        }
        finally {
            $env:PSModulePath = $saved
            $Global:HTConfig = $savedConfig
            $global:HTSkippedModulePaths = @()
        }
    }
}

Describe "Biblioteki załadowane w procesie" {
    It "zwraca biblioteki domyślnego kontekstu, bez bibliotek z izolowanego kontekstu modułu" {
        $lib = New-TestAssembly -Directory (Join-Path $script:Root "isolated") -Name "HT.IsolatedLib" -Version "1.0.0.0" -Code 'namespace HTIsolated { public static class I { public static int Value() { return 3; } } }'
        $alc = [System.Runtime.Loader.AssemblyLoadContext]::new("HTTestIsolated", $true)
        try {
            # Z pamięci, nie z pliku - plik załadowany z dysku jest zablokowany w Windows i Pester nie usunie TestDrive
            $isolated = $alc.LoadFromStream([System.IO.MemoryStream]::new([System.IO.File]::ReadAllBytes($lib)))
            $isolated.GetName().Name | Should -Be "HT.IsolatedLib"
            @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq "HT.IsolatedLib" }).Count | Should -BeGreaterThan 0
            $loaded = @(Get-HTLoadedAssemblies)
            @($loaded | Where-Object { $_.Name -eq "System.Management.Automation" }).Count | Should -Be 1
            @($loaded | Where-Object { $_.Name -eq "HT.IsolatedLib" }).Count | Should -Be 0
        }
        finally { $alc.Unload() }
    }
    It "przy kilku wersjach biblioteki porównuje z najnowszą" {
        $dir = Join-Path $script:Root "ConflictModule2"
        New-TestAssembly -Directory $dir -Name "HT.Auth2" -Version "1.0.0.0" -References $script:MsalLib `
            -Code 'namespace HTAuth2 { public static class A { public static int Use() { return HTMsal.M.Value(); } } }' | Out-Null
        $loaded = @(
            [PSCustomObject]@{ Name = "Microsoft.Identity.Client"; Version = [version]"4.90.0.0"; Location = "C:\Modules\Graph\Microsoft.Identity.Client.dll" }
            [PSCustomObject]@{ Name = "Microsoft.Identity.Client"; Version = [version]"4.60.0.0"; Location = "C:\Modules\Exo\Microsoft.Identity.Client.dll" }
        )
        $r = Test-HTModuleCompatibility -ModuleBase $dir -RuntimeDirectory (Join-Path $script:Root "runtimeNew") -LoadedAssemblies $loaded
        $r.LoadedIssues.Count | Should -Be 0
    }
}

Describe "Microsoft Graph: logowanie i rozłączanie" {
    AfterEach {
        Remove-Item -Path Function:\global:Disconnect-MgGraph, Function:\global:Connect-MgGraph -ErrorAction SilentlyContinue
    }
    It "logowanie trzyma tokeny tylko w pamięci procesu (bez czyszczenia pamięci MSAL przy rozłączaniu)" {
        $p = Get-HTGraphConnectParams -Scopes 'User.Read.All', 'Group.Read.All' -TenantId 'contoso.onmicrosoft.com'
        $p.ContextScope | Should -Be 'Process'
        $p.TenantId | Should -Be 'contoso.onmicrosoft.com'
        @($p.Scopes).Count | Should -Be 2
        $p.NoWelcome | Should -BeTrue
        $p.ErrorAction | Should -Be 'Stop'
        (Get-HTGraphConnectParams -Scopes 'User.Read.All').ContainsKey('TenantId') | Should -BeFalse
    }
    It "pomija -ContextScope, gdy polecenie go nie ma" {
        function global:Connect-MgGraph { [CmdletBinding()] param([string[]]$Scopes, [string]$TenantId, [switch]$NoWelcome) }
        (Get-HTGraphConnectParams -Scopes 'User.Read.All').ContainsKey('ContextScope') | Should -BeFalse
    }
    It "ostrzeżenie przy rozłączaniu trafia do dziennika, nie do konsoli" {
        function global:Disconnect-MgGraph {
            [CmdletBinding()] param()
            Write-Warning 'Failed to clear the persisted MSAL token cache during Disconnect-MgGraph: The authority (including the tenant ID) must be in a well-formed URI format.'
            [PSCustomObject]@{ Account = 'admin@contoso.onmicrosoft.com' }
        }
        Mock -ModuleName ModulesConnection Write-Log { }
        $out = Disconnect-HTGraph 3>&1
        @($out).Count | Should -Be 0
        Should -Invoke -ModuleName ModulesConnection Write-Log -Times 1 -ParameterFilter { $Message -like '*MSAL token cache*' -and $Type -eq 'Info' }
    }
    It "błąd rozłączania jest przekazywany dalej (obsługuje go Set-Connections)" {
        function global:Disconnect-MgGraph { [CmdletBinding()] param() throw 'No application to sign out from.' }
        { Disconnect-HTGraph } | Should -Throw '*No application*'
    }
}
