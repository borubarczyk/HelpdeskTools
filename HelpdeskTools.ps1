<#
.SYNOPSIS
    Główny plik uruchamiający aplikację Helpdesk Tools.
.DESCRIPTION
    Aplikacja WPF do zarządzania Active Directory, Microsoft 365 (Graph), Exchange Online, Intune i SharePoint.
    Wygląd i układ są wspólne z Domain Ops (AD-ManagerDiamond) i ServerReview.
    Uruchom w PowerShell 7 (pwsh) jako administrator: pwsh -File .\HelpdeskTools.ps1
    Wtyczki: pliki *.ps1 w folderze Plugins programu albo %APPDATA%\HelpdeskTools\Plugins (zob. Plugins\README.md).
    Raporty zaplanowane bez okna: HelpdeskToolsRunner.ps1.
.PARAMETER Connect
    Usługa, z którą program połączy się zaraz po uruchomieniu (używane przy ponownym uruchomieniu po konflikcie bibliotek).
.PARAMETER HideConsole
    Ukrywa okno konsoli po uruchomieniu (skrót na pulpicie z Ustawienia > Aplikacja > «Skrót na pulpicie»).
.NOTES
    Pliki programu: konfiguracja %APPDATA%\HelpdeskTools\config.json, dziennik %LOCALAPPDATA%\HelpdeskTools\Logs,
    eksport Dokumenty\HelpdeskTools\Eksport (zmiana w Ustawieniach).

    Copyright (c) 2025-2026 Borys Kaleta. Wszelkie prawa zastrzeżone.
    Korzystanie z programu wymaga zgody autora - zob. plik LICENSE.
#>

#Requires -RunAsAdministrator
#Requires -Version 7

param (
    [ValidateSet("", "Exchange", "Graph", "SharePoint")]
    [string]$Connect = "",
    [switch]$HideConsole
)

$ErrorActionPreference = "Continue"

if (-not $IsWindows) {
    Write-Error "Helpdesk Tools wymaga systemu Windows (interfejs WPF)."
    return
}

# WPF wymaga wątku STA - w razie potrzeby uruchom ponownie w trybie STA
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    Write-Warning "Ponowne uruchamianie w trybie STA..."
    $relaunch = @("-STA", "-NoProfile", "-File", "`"$PSCommandPath`"")
    if ($HideConsole) { $relaunch += "-HideConsole" }
    Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $relaunch
    return
}

# Skrót na pulpicie: okno konsoli ukryte zaraz po starcie (komunikaty trafiają do dziennika w oknie programu)
if ($HideConsole) {
    try {
        Add-Type -Namespace HelpdeskTools -Name ConsoleWindow -ErrorAction Stop -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
'@
        $consoleHandle = [HelpdeskTools.ConsoleWindow]::GetConsoleWindow()
        if ($consoleHandle -ne [IntPtr]::Zero) { [void][HelpdeskTools.ConsoleWindow]::ShowWindow($consoleHandle, 0) }
    }
    catch { Write-Warning "Nie ukryto okna konsoli: $_" }
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

# Zmienne globalne
$Global:AppVersion = "3.17.0"
$Global:HTScriptPath = $PSCommandPath
$Global:HTRestarting = $false
$Global:ConfigDir = Join-Path -Path $env:APPDATA -ChildPath "HelpdeskTools"
$Global:LogDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "HelpdeskTools\Logs"
$Global:ConfigPath = Join-Path -Path $Global:ConfigDir -ChildPath "config.json"
$Global:IconsPath = Join-Path -Path $PSScriptRoot -ChildPath "Resources/Icons"
$Global:AppIconPath = Join-Path -Path $Global:IconsPath -ChildPath "Tools.ico"
$Global:PasswordSpecialCharacters = "!@#$%^&*?"
$Global:PasswordUseWordBased = $false
$Global:PasswordDefaultLength = 12
$Global:ConnectedToExchange = $false
$Global:ConnectedToGraphAPI = $false
$Global:ConnectedToSharepoint = $false
$Global:ConnectedToSharepointPnP = $false
$Global:LogPasswordGeneration = $false
$Global:LogClientIDForPnP = $false
$Global:LastUsedClientID = $null
$Global:IsModuleActiveDirectoryLoaded = $false
$Global:DefaultSharepointSite = $null
$Global:ShowNotifications = $true
$Global:ShowOnPremises = $false

# Funkcje lokalne (Active Directory) są ukryte, dopóki nie zostaną włączone w Ustawieniach - odczyt przed zbudowaniem interfejsu
if (Test-Path -LiteralPath $Global:ConfigPath) {
    try { $Global:ShowOnPremises = [bool]((Get-Content -Raw -LiteralPath $Global:ConfigPath -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop).ShowOnPremises) }
    catch { Write-Verbose "Wstępny odczyt konfiguracji: $_" }
}

# Import modułów (kolejność: najpierw moduły bazowe)
$moduleNames = @(
    "Utils",
    "Security",
    "Mfa",
    "QrCode",
    "TenantProfiles",
    "UserProfiles",
    "AccountBackup",
    "UiState",
    "ColumnFilters",
    "Reports",
    "Excel",
    "Integrations",
    "Automation",
    "UIComponents",
    "Config",
    "ModulesConnection",
    "ServiceWorker",
    "PasswordGenerator",
    "LocalActiveDirectory",
    "GraphAPIM365Users",
    "GraphAPISecurity",
    "GraphAPITeams",
    "MailboxesExchangeOnline",
    "ExchangeSettings",
    "ExchangeRecipients",
    "GraphAPIIntune",
    "GraphAPISharePoint",
    "SharePointAudit",
    "SharePointStructure",
    "Dashboard",
    "TenantSelfTest",
    "Startup"
)

foreach ($moduleName in $moduleNames) {
    $path = Join-Path $PSScriptRoot "Modules/$moduleName.psm1"
    if (Test-Path $path) {
        Import-Module $path -Force -Global -DisableNameChecking -ErrorAction Stop
    }
    else {
        Write-Warning "Moduł nie znaleziony: $path"
    }
}

# Dziennik operacji w oknie (wpisy sprzed utworzenia okna też trafią do panelu)
Register-HTLogSink -ScriptBlock { param($entry) Add-HTLogItem -Entry $entry }
Remove-HTOldLogs -Days 30
Write-Log -Message "Uruchamianie Helpdesk Tools $($Global:AppVersion) (PowerShell $($PSVersionTable.PSVersion))" -Type "Info"
# Moduły PowerShell w OneDrive bez lokalnej kopii plików (OneDrive nie działa) - folder pomijany w tej sesji
try { Repair-HTModulePath | Out-Null } catch { Write-Log -Message "Sprawdzenie folderów modułów: $($_.Exception.Message)" -Type "Warn" }

# Interfejs: okno główne, przestrzenie robocze i moduły
$guiFiles = @(
    "GUI/Common.ps1",
    "GUI/Dialogs.ps1",
    "GUI/MainWindow.ps1",
    "GUI/Tools.ps1",
    "GUI/Workspaces/Dashboard.ps1",
    "GUI/Workspaces/Organization.ps1",
    "GUI/Workspaces/M365Users.ps1",
    "GUI/Workspaces/Groups.ps1",
    "GUI/Workspaces/Security.ps1",
    "GUI/Workspaces/Exchange.ps1",
    "GUI/Workspaces/Intune.ps1",
    "GUI/Workspaces/Sites.ps1",
    "GUI/Workspaces/SharePoint.ps1",
    "GUI/Workspaces/Tasks.ps1"
)
# Przestrzenie Active Directory - tylko po włączeniu funkcji lokalnych w Ustawieniach
if ($Global:ShowOnPremises) { $guiFiles += "GUI/Workspaces/ActiveDirectory.ps1" }
foreach ($file in $guiFiles) {
    . (Join-Path $PSScriptRoot $file)
}

# Wtyczki: własne przestrzenie, moduły i polecenia palety (Register-HTWorkspace, Register-HTModule, Register-HTPaletteAction).
# Wtyczka działa z uprawnieniami programu - umieszczaj tylko własne, sprawdzone pliki.
foreach ($pluginDir in @((Join-Path $PSScriptRoot "Plugins"), (Join-Path $Global:ConfigDir "Plugins"))) {
    if (-not (Test-Path -LiteralPath $pluginDir)) { continue }
    foreach ($plugin in @(Get-ChildItem -LiteralPath $pluginDir -Filter "*.ps1" -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
        try {
            . $plugin.FullName
            Write-Log -Message "Wczytano wtyczkę: $($plugin.FullName)" -Type "Info"
        }
        catch { Write-Log -Message "Błąd wtyczki $($plugin.Name): $($_.Exception.Message)" -Type "Error" }
    }
}

try {
    $window = New-HTMainWindow
    foreach ($p in $HT_UI.Panels.Values) { [void]$HT_UI.Controls.targetHost.Children.Add($p.Root) }
    Initialize-HTNavigation

    # Wczytanie konfiguracji (przy pierwszym uruchomieniu pytanie o utworzenie pliku - okno już istnieje)
    $Global:HTConfig = Ensure-HTConfig -Path $Global:ConfigPath
    Apply-HTConfig -Config $Global:HTConfig

    # PIN przed oknem głównym (przy pierwszym uruchomieniu - ustawienie PIN-u); z MFA także kod z aplikacji
    if (-not (Unlock-HTApplication)) {
        Write-Log -Message "Program nie został odblokowany - zamykanie." -Type "Warn"
        return
    }
    # Nawigacja według uprawnień konta MFA, które odblokowało program
    Update-HTNavAccess

    # Nieobsłużone wyjątki w zdarzeniach interfejsu - wpis w dzienniku i komunikat zamiast zamknięcia programu
    $window.Dispatcher.add_UnhandledException({
            param($s, $e)
            $message = $e.Exception.Message
            if ($e.Exception.InnerException) { $message += "`n$($e.Exception.InnerException.Message)" }
            $e.Handled = $true
            try {
                Write-Log -Message "Nieobsłużony wyjątek: $message" -Type "Error"
                Show-HTError -Text 'Wystąpił nieoczekiwany błąd.' -ErrorObject $message
            }
            catch { Write-Warning $message }
        })

    $script:Started = $false
    $window.add_ContentRendered({
            if ($script:Started) { return }
            $script:Started = $true
            try {
                Update-HTHeaderLayout
                Initialize-HelpdeskTools
                Start-HTAutoLock
                Start-HTJobScheduler
                Start-HTUpdateCheck
                if ($Connect) { Invoke-HTUiAction -Module $null -Action { Invoke-HTConnectionClick -Service $Connect } }
            }
            catch {
                Write-Log -Message "Błąd inicjalizacji: $($_.Exception.Message)" -Type "Error"
            }
        })

    [void]$window.ShowDialog()
}
catch {
    Write-Error "Błąd uruchamiania GUI: $_"
}
finally {
    Stop-HTAutoLock
    try { Stop-HTJobScheduler; Close-HTBackground; Stop-HTServiceWorker -All } catch { Write-Verbose $_ }
    # Sprzątanie zmiennych globalnych aplikacji (pozostałe zmienne sesji pozostają bez zmian)
    $appVariables = @(
        "HT_UI", "HTConfig", "AppVersion", "ConfigDir", "ConfigPath", "IconsPath", "AppIconPath",
        "PasswordSpecialCharacters", "PasswordUseWordBased", "PasswordDefaultLength", "PasswordEmailAdress", "PasswordEmailTitle",
        "ConnectedToExchange", "ConnectedToGraphAPI", "ConnectedToSharepoint", "ConnectedToSharepointPnP",
        "LogPasswordGeneration", "LogClientIDForPnP", "LastUsedClientID", "IsModuleActiveDirectoryLoaded",
        "DefaultSharepointSite", "DefaultUsageLocation", "GraphScopes", "ShowNotifications", "LogFileMaxSizeMB", "ExportPath",
        "InactiveDays", "AadSyncServer", "LoginTimeoutMinutes", "ConfirmBeforeClose", "AutoLockMinutes", "LogDir", "HTScriptPath", "HTRestarting", "HTActiveAccount",
        "ShowOnPremises", "BackgroundQueries", "NotifyLongOperationsSeconds", "ShowSystemMailboxes", "HTSkippedModulePaths", "DebugLogging", "ExchangeInBackground", "SharePointInBackground"
    )
    Remove-Variable -Name $appVariables -Scope Global -ErrorAction SilentlyContinue
}
