# Zarządzanie konfiguracją aplikacji (plik JSON w %APPDATA%\HelpdeskTools\config.json)

# Wersja schematu konfiguracji - podniesienie wersji uzupełnia uprawnienia Graph o zakresy wymagane przez nowe funkcje
$script:ConfigVersion = 2

# Domyślne uprawnienia (scopes) Microsoft Graph wymagane przez przestrzenie Microsoft 365, Intune, SharePoint i Pulpit
$script:DefaultGraphScopes = @(
    "User.ReadWrite.All",
    "Directory.AccessAsUser.All",
    "Group.ReadWrite.All",
    "GroupMember.ReadWrite.All",
    "UserAuthenticationMethod.ReadWrite.All",
    "Organization.Read.All",
    "AuditLog.Read.All",
    "Device.Read.All",
    "DeviceManagementManagedDevices.ReadWrite.All",
    "DeviceManagementManagedDevices.PrivilegedOperations.All",
    "BitlockerKey.Read.All",
    "DeviceLocalCredential.Read.All",
    "DeviceManagementConfiguration.Read.All",
    "Sites.Read.All",
    "RoleManagement.Read.Directory",
    "ServiceHealth.Read.All",
    "ServiceMessage.Read.All"
)

# Zwraca domyślną konfigurację
function Get-HTDefaultConfig {
    return [ordered]@{
        PasswordEmailAdress       = ""
        PasswordEmailTitle        = "Nowe hasło"
        PasswordSpecialCharacters = "!@#$%^&*?"
        PasswordUseWordBased      = $false
        PasswordDefaultLength     = 12
        LogPasswordGeneration     = $false
        LogClientIDForPnP         = $false
        LastUsedClientID          = $null
        DefaultSharepointSite     = ""
        DefaultUsageLocation      = "PL"
        GraphScopes               = $script:DefaultGraphScopes
        ShowNotifications         = $true
        LogFileMaxSizeMB          = 5
        ExportPath                = ""
        InactiveDays              = 90
        AadSyncServer             = ""
        LoginTimeoutMinutes       = 5
        AutoLockMinutes           = 15
        PinHash                   = ""
        PinSalt                   = ""
        PinLength                 = 0
        ConfirmBeforeClose        = $true
        # Funkcje lokalnego Active Directory (on-premises) - domyślnie ukryte, zmiana po ponownym uruchomieniu
        ShowOnPremises            = $false
        # Zapytania Microsoft Graph w tle (okno nie zamarza) i powiadomienie Windows po długiej operacji (sekundy, 0 = bez)
        BackgroundQueries         = $true
        NotifyLongOperationsSeconds = 20
        # Powiadomienia na kanał Teams (adres webhooka zaszyfrowany DPAPI) i zdarzenia, o których powiadamiać
        TeamsWebhookProtected     = ""
        TeamsNotify               = @("Offboarding", "Jobs", "Checklists")
        # Zapamiętane tenanty (np. klienci GDAP): @{ Name; Tenant; PartnerAccount }
        TenantProfiles            = @()
        # Aktualizacje programu z repozytorium GitHub (token dla repozytorium prywatnego zaszyfrowany DPAPI)
        UpdateRepository          = "borubarczyk/HelpdeskToolsProject_Scaffold"
        UpdateBranch              = "main"
        UpdateTokenProtected      = ""
        CheckUpdatesOnStart       = $true
        # Zadania automatyczne bez okna (aplikacja z certyfikatem, uprawnienia aplikacji)
        AutomationClientId        = ""
        AutomationTenantId        = ""
        AutomationCertificateThumbprint = ""
        AutomationOrganization    = ""
        ReportSender              = ""
        # Microsoft Defender for Endpoint (izolacja urządzeń) - rejestracja aplikacji z uprawnieniami WindowsDefenderATP
        DefenderClientId          = ""
        # Szczegółowy dziennik diagnostyczny (zapytania Graph, łączenie, moduły, stos błędów)
        DebugLogging              = $false
        # Skrzynki systemowe Exchange (DiscoverySearchMailbox) na listach i w raportach
        ShowSystemMailboxes       = $false
        ExchangeInBackground      = $true
        SharePointInBackground    = $true
        # Foldery modułów PowerShell w OneDrive pomijane, gdy pliki są tylko w chmurze, a OneDrive nie działa
        SkippedModulePaths        = @()
        ConfigVersion             = $script:ConfigVersion
    }
}

# Uzupełnia konfigurację o brakujące klucze domyślne. Zwraca obiekt oraz informację, czy coś dodano.
function Merge-HTConfig {
    [CmdletBinding()]
    param (
        [AllowNull()][object]$Config
    )

    $defaults = Get-HTDefaultConfig
    $merged = [ordered]@{}
    $added = @()

    if ($Config -is [System.Collections.IDictionary]) {
        foreach ($key in $Config.Keys) { $merged[$key] = $Config[$key] }
    }
    elseif ($Config) {
        foreach ($property in $Config.PSObject.Properties) {
            $merged[$property.Name] = $property.Value
        }
    }

    foreach ($key in $defaults.Keys) {
        if (-not $merged.Contains($key)) {
            $merged[$key] = $defaults[$key]
            $added += $key
        }
    }

    return [PSCustomObject]@{
        Config    = [PSCustomObject]$merged
        AddedKeys = $added
    }
}

function Get-HTConfig {
    [CmdletBinding()]
    param ([string]$Path = $Global:ConfigPath)
    if (Test-Path $Path) {
        try {
            $raw = Get-Content -Raw -Path $Path -Encoding utf8
            if ([string]::IsNullOrWhiteSpace($raw) -or $raw.Trim() -eq "null") {
                throw "Plik konfiguracyjny jest pusty."
            }
            return $raw | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Message "Błąd parsowania pliku konfiguracyjnego: $($_.Exception.Message)" -Type "Error&Notification"
            return $null
        }
    }
    else {
        Write-Log -Message "Brak pliku konfiguracyjnego: $Path" -Type "Warn"
        return $null
    }
}

function Set-HTConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][object]$Config,
        [string]$Path = $Global:ConfigPath
    )

    $dir = Split-Path -Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Force -Encoding utf8
    Write-Log -Message "Zapisano konfigurację do: $Path" -Type "Info"
}

function New-HTConfig {
    [CmdletBinding()]
    param ([string]$Path = $Global:ConfigPath)

    try {
        Set-HTConfig -Config (Get-HTDefaultConfig) -Path $Path
        Write-Log -Message "Utworzono plik konfiguracyjny: $Path" -Type "Info"
    }
    catch {
        Write-Log -Message "Błąd przy tworzeniu pliku konfiguracyjnego: $($_.Exception.Message)" -Type "Error&Notification"
    }
}

# Sprawdza istnienie konfiguracji, tworzy ją w razie potrzeby i uzupełnia brakujące klucze
function Ensure-HTConfig {
    [CmdletBinding()]
    param (
        [string]$Path = $Global:ConfigPath,
        # Tworzy plik bez pytania użytkownika
        [switch]$Force
    )

    if (-not (Test-Path $Path)) {
        Write-Log -Message "Plik konfiguracyjny nie istnieje: $Path" -Type "Warn"

        $create = $Force
        if (-not $create) {
            $response = Show-Dialog -Message "Plik konfiguracyjny nie istnieje:`n$Path`n`nUtworzyć go z ustawieniami domyślnymi?" `
                -Buttons "YesNo" -Type "Question" -Title "Brak pliku konfiguracyjnego"
            $create = ($response -eq "Yes")
        }

        if (-not $create) {
            Write-Log -Message "Użytkownik anulował tworzenie konfiguracji - używam ustawień domyślnych (tylko w pamięci)." -Type "Info"
            return (Merge-HTConfig -Config $null).Config
        }

        New-HTConfig -Path $Path
    }

    $config = Get-HTConfig -Path $Path
    if ($null -eq $config) {
        Write-Log -Message "Nie udało się wczytać konfiguracji - używam ustawień domyślnych." -Type "Warn"
        return (Merge-HTConfig -Config $null).Config
    }

    $merge = Merge-HTConfig -Config $config
    $upgraded = Update-HTConfigSchema -Config $merge.Config -AddedKeys $merge.AddedKeys
    if ($merge.AddedKeys.Count -gt 0 -or $upgraded) {
        if ($merge.AddedKeys.Count -gt 0) { Write-Log -Message "Uzupełniono konfigurację o nowe ustawienia: $($merge.AddedKeys -join ', ')" -Type "Info" }
        try { Set-HTConfig -Config $merge.Config -Path $Path } catch { Write-Log -Message "Nie udało się zapisać uzupełnionej konfiguracji: $_" -Type "Warn" }
    }
    return $merge.Config
}

# Migracja konfiguracji ze starszej wersji: dopisuje nowe zakresy Graph (pozostałe ustawienia bez zmian).
# Zwraca $true, gdy konfiguracja została zmieniona.
function Update-HTConfigSchema {
    param (
        [Parameter(Mandatory)][object]$Config,
        [string[]]$AddedKeys = @()
    )
    $version = 0
    if ($AddedKeys -notcontains "ConfigVersion") { [void][int]::TryParse("$($Config.ConfigVersion)", [ref]$version) }
    if ($version -ge $script:ConfigVersion) { return $false }
    $scopes = @($Config.GraphScopes | Where-Object { $_ })
    $missing = @($script:DefaultGraphScopes | Where-Object { $scopes -notcontains $_ })
    if ($missing.Count -gt 0) {
        $Config.GraphScopes = @($scopes + $missing)
        Write-Log -Message "Dodano uprawnienia Microsoft Graph wymagane przez nowe funkcje: $($missing -join ', ')" -Type "Info"
    }
    $Config.ConfigVersion = $script:ConfigVersion
    return $true
}

# Ustawia zmienne globalne na podstawie konfiguracji
function Apply-HTConfig {
    [CmdletBinding()]
    param ([object]$Config)

    if (-not $Config) {
        Write-Log -Message "Brak obiektu konfiguracji do zastosowania." -Type "Warn"
        return
    }

    $Config = (Merge-HTConfig -Config $Config).Config
    $Global:HTConfig = $Config

    $Global:PasswordEmailAdress = $Config.PasswordEmailAdress
    $Global:PasswordEmailTitle = $Config.PasswordEmailTitle
    $Global:PasswordSpecialCharacters = $Config.PasswordSpecialCharacters
    $Global:PasswordUseWordBased = [bool]$Config.PasswordUseWordBased
    $Global:PasswordDefaultLength = [int]$Config.PasswordDefaultLength
    $Global:LogPasswordGeneration = [bool]$Config.LogPasswordGeneration
    $Global:LogClientIDForPnP = [bool]$Config.LogClientIDForPnP
    $Global:LastUsedClientID = $Config.LastUsedClientID
    $Global:DefaultSharepointSite = $Config.DefaultSharepointSite
    $Global:DefaultUsageLocation = $Config.DefaultUsageLocation
    $Global:GraphScopes = @($Config.GraphScopes | Where-Object { $_ })
    $Global:ShowNotifications = [bool]$Config.ShowNotifications
    $Global:LogFileMaxSizeMB = $Config.LogFileMaxSizeMB
    $Global:ExportPath = $Config.ExportPath
    $Global:InactiveDays = [int]$Config.InactiveDays
    $Global:AadSyncServer = $Config.AadSyncServer
    $Global:LoginTimeoutMinutes = [int]$Config.LoginTimeoutMinutes
    $Global:AutoLockMinutes = [int]$Config.AutoLockMinutes
    $Global:ConfirmBeforeClose = [bool]$Config.ConfirmBeforeClose
    $Global:ShowOnPremises = [bool]$Config.ShowOnPremises
    $Global:BackgroundQueries = [bool]$Config.BackgroundQueries
    $Global:NotifyLongOperationsSeconds = [int]$Config.NotifyLongOperationsSeconds
    $Global:ShowSystemMailboxes = [bool]$Config.ShowSystemMailboxes
    $Global:ExchangeInBackground = $(if ($null -eq $Config.ExchangeInBackground) { $true } else { [bool]$Config.ExchangeInBackground })
    $Global:SharePointInBackground = $(if ($null -eq $Config.SharePointInBackground) { $true } else { [bool]$Config.SharePointInBackground })
    $Global:DebugLogging = [bool]$Config.DebugLogging

    if ($Global:PasswordDefaultLength -lt 8 -or $Global:PasswordDefaultLength -gt 64) { $Global:PasswordDefaultLength = 12 }
    if ($Global:GraphScopes.Count -eq 0) { $Global:GraphScopes = $script:DefaultGraphScopes }
    if ($Global:InactiveDays -lt 1 -or $Global:InactiveDays -gt 3650) { $Global:InactiveDays = 90 }
    if ($Global:LoginTimeoutMinutes -lt 1 -or $Global:LoginTimeoutMinutes -gt 60) { $Global:LoginTimeoutMinutes = 5 }
    if ($Global:AutoLockMinutes -lt 0 -or $Global:AutoLockMinutes -gt 480) { $Global:AutoLockMinutes = 15 }
    if ($Global:NotifyLongOperationsSeconds -lt 0 -or $Global:NotifyLongOperationsSeconds -gt 3600) { $Global:NotifyLongOperationsSeconds = 20 }

    # Foldery modułów z OneDrive pominięte w poprzednich sesjach (nowy proces PowerShell dopisuje je z powrotem)
    if (Get-Command -Name Restore-HTSkippedModulePaths -ErrorAction SilentlyContinue) {
        try { Restore-HTSkippedModulePaths | Out-Null } catch { Write-Log -Message "Pomijanie folderów modułów: $($_.Exception.Message)" -Type "Warn" }
    }
    if ($Global:DebugLogging -and (Get-Command -Name Write-HTEnvironmentDebug -ErrorAction SilentlyContinue)) {
        try { Write-HTEnvironmentDebug } catch { Write-Log -Message "Dziennik diagnostyczny: $($_.Exception.Message)" -Type "Warn" }
    }

    Write-Log -Message "Zastosowano konfigurację (e-mail: '$($Global:PasswordEmailAdress)', hasła słowne: $($Global:PasswordUseWordBased), domyślna witryna SharePoint: $($Global:DefaultSharepointSite))." -Type "Info"

}

# Zapisuje pojedyncze ustawienie w konfiguracji i pliku
function Set-HTConfigValue {
    param (
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()][object]$Value
    )
    $config = (Merge-HTConfig -Config $Global:HTConfig).Config
    $config.$Name = $Value
    $Global:HTConfig = $config
    if ($Global:ConfigPath) { Set-HTConfig -Config $config -Path $Global:ConfigPath }
}
