# SharePoint Online przez PnP.PowerShell (połączenie: Connect-Module -Name PnP.PowerShell)
# Węzeł drzewa (Node) to obiekt: @{ Title; ServerRelativeUrl; ListTitle; IsLibrary }

# Adres względny bieżącej witryny (np. /sites/Dzial)
function Get-HTSPWebUrl {
    $web = Get-PnPWeb -ErrorAction Stop
    return $web.ServerRelativeUrl.TrimEnd("/")
}

# Zamiana adresu względnego serwera na adres względny witryny
function ConvertTo-HTSPSiteRelativeUrl {
    param (
        [Parameter(Mandatory)][string]$ServerRelativeUrl,
        [AllowEmptyString()][string]$WebUrl
    )
    if ($null -eq $WebUrl -or -not $PSBoundParameters.ContainsKey("WebUrl")) { $WebUrl = Get-HTSPWebUrl }
    if ($WebUrl -and $ServerRelativeUrl.StartsWith($WebUrl, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $ServerRelativeUrl.Substring($WebUrl.Length).TrimStart("/")
    }
    return $ServerRelativeUrl.TrimStart("/")
}

# Biblioteki dokumentów witryny
function Get-HTSPLibraries {
    $lists = Get-PnPList -ErrorAction Stop | Where-Object { $_.BaseTemplate -eq 101 -and -not $_.Hidden }
    return @($lists | ForEach-Object {
            $root = Get-PnPProperty -ClientObject $_ -Property RootFolder
            [PSCustomObject]@{
                Title             = $_.Title
                ServerRelativeUrl = $root.ServerRelativeUrl
                ListTitle         = $_.Title
                IsLibrary         = $true
                ItemCount         = $_.ItemCount
            }
        } | Sort-Object Title)
}

# Podfoldery wskazanego folderu
function Get-HTSPSubFolders {
    param (
        [Parameter(Mandatory)][string]$ServerRelativeUrl,
        [Parameter(Mandatory)][string]$ListTitle
    )
    $siteRelative = ConvertTo-HTSPSiteRelativeUrl -ServerRelativeUrl $ServerRelativeUrl
    return @(Get-PnPFolderItem -FolderSiteRelativeUrl $siteRelative -ItemType Folder -ErrorAction Stop |
            Where-Object { $_.Name -ne "Forms" } |
            Sort-Object Name |
            ForEach-Object {
                [PSCustomObject]@{
                    Title             = $_.Name
                    ServerRelativeUrl = $_.ServerRelativeUrl
                    ListTitle         = $ListTitle
                    IsLibrary         = $false
                    ItemCount         = $_.ItemCount
                }
            })
}

# Obiekt zabezpieczalny (lista lub element folderu) dla węzła
function Get-HTSPSecurable {
    param ([Parameter(Mandatory)][object]$Node)
    if ($Node.IsLibrary) {
        return Get-PnPList -Identity $Node.ListTitle -ErrorAction Stop
    }
    $folder = Get-PnPFolder -Url $Node.ServerRelativeUrl -ErrorAction Stop
    return Get-PnPProperty -ClientObject $folder -Property ListItemAllFields
}

# Uprawnienia do biblioteki / folderu
function Get-HTSPPermissions {
    param ([Parameter(Mandatory)][object]$Node)

    $securable = Get-HTSPSecurable -Node $Node
    Get-PnPProperty -ClientObject $securable -Property HasUniqueRoleAssignments, RoleAssignments | Out-Null

    $limitedAccess = @("Limited Access", "Ograniczony dostęp", "Web-Only Limited Access")
    $rows = foreach ($assignment in $securable.RoleAssignments) {
        Get-PnPProperty -ClientObject $assignment -Property Member, RoleDefinitionBindings | Out-Null
        $roles = @($assignment.RoleDefinitionBindings | ForEach-Object { $_.Name } | Where-Object { $limitedAccess -notcontains $_ })
        if ($roles.Count -eq 0) { continue }
        [PSCustomObject]@{
            Principal     = $assignment.Member.Title
            LoginName     = $assignment.Member.LoginName
            PrincipalType = "$($assignment.Member.PrincipalType)"
            Roles         = $roles -join ", "
            Path          = $Node.ServerRelativeUrl
            Unique        = [bool]$securable.HasUniqueRoleAssignments
        }
    }
    return @($rows)
}

# Czy węzeł ma unikalne uprawnienia
function Test-HTSPUniquePermissions {
    param ([Parameter(Mandatory)][object]$Node)
    $securable = Get-HTSPSecurable -Node $Node
    return [bool](Get-PnPProperty -ClientObject $securable -Property HasUniqueRoleAssignments)
}

# Poziomy uprawnień dostępne w witrynie
function Get-HTSPRoleDefinitions {
    return @(Get-PnPRoleDefinition -ErrorAction Stop | Where-Object { -not $_.Hidden -and $_.Name -notmatch 'Limited|Ograniczony' } | ForEach-Object { $_.Name })
}

# Nadanie uprawnień (użytkownik / grupa zabezpieczeń - login lub e-mail; grupa SharePoint - nazwa)
function Grant-HTSPPermission {
    param (
        [Parameter(Mandatory)][object]$Node,
        [Parameter(Mandatory)][string]$Principal,
        [Parameter(Mandatory)][ValidateSet("User", "SharePointGroup")][string]$PrincipalType,
        [Parameter(Mandatory)][string]$Role
    )
    $target = if ($PrincipalType -eq "SharePointGroup") { @{ Group = $Principal } } else { @{ User = $Principal } }
    if ($Node.IsLibrary) {
        Set-PnPListPermission -Identity $Node.ListTitle -AddRole $Role @target -ErrorAction Stop
    }
    else {
        $siteRelative = ConvertTo-HTSPSiteRelativeUrl -ServerRelativeUrl $Node.ServerRelativeUrl
        Set-PnPFolderPermission -List $Node.ListTitle -Identity $siteRelative -AddRole $Role @target -ErrorAction Stop
    }
}

# Odebranie uprawnień
function Revoke-HTSPPermission {
    param (
        [Parameter(Mandatory)][object]$Node,
        [Parameter(Mandatory)][object]$Assignment
    )
    $isGroup = $Assignment.PrincipalType -eq "SharePointGroup"
    $target = if ($isGroup) { @{ Group = $Assignment.Principal } } else { @{ User = $Assignment.LoginName } }
    foreach ($role in ($Assignment.Roles -split ",\s*" | Where-Object { $_ })) {
        if ($Node.IsLibrary) {
            Set-PnPListPermission -Identity $Node.ListTitle -RemoveRole $role @target -ErrorAction Stop
        }
        else {
            $siteRelative = ConvertTo-HTSPSiteRelativeUrl -ServerRelativeUrl $Node.ServerRelativeUrl
            Set-PnPFolderPermission -List $Node.ListTitle -Identity $siteRelative -RemoveRole $role @target -ErrorAction Stop
        }
    }
}

# Przerwanie / przywrócenie dziedziczenia uprawnień
function Set-HTSPInheritance {
    param (
        [Parameter(Mandatory)][object]$Node,
        [Parameter(Mandatory)][bool]$Inherit,
        [bool]$CopyExisting = $true
    )
    if ($Node.IsLibrary) {
        if ($Inherit) {
            Set-PnPList -Identity $Node.ListTitle -ResetRoleInheritance -ErrorAction Stop | Out-Null
        }
        else {
            Set-PnPList -Identity $Node.ListTitle -BreakRoleInheritance -CopyRoleAssignments:$CopyExisting -ErrorAction Stop | Out-Null
        }
        return
    }

    $item = Get-HTSPSecurable -Node $Node
    if ($Inherit) { $item.ResetRoleInheritance() } else { $item.BreakRoleInheritance($CopyExisting, $false) }
    Invoke-PnPQuery -ErrorAction Stop
}

# Grupy SharePoint witryny
function Get-HTSPGroups {
    return @(Get-PnPGroup -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Title       = $_.Title
                Owner       = $_.OwnerTitle
                Description = $_.Description
                Id          = $_.Id
            }
        } | Sort-Object Title)
}

# Członkowie grupy SharePoint
function Get-HTSPGroupMembers {
    param ([Parameter(Mandatory)][string]$Group)
    return @(Get-PnPGroupMember -Group $Group -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Title         = $_.Title
                Email         = $_.Email
                LoginName     = $_.LoginName
                PrincipalType = "$($_.PrincipalType)"
            }
        } | Sort-Object Title)
}

# Nowa grupa SharePoint (opcjonalnie z członkami)
function New-HTSPGroup {
    param (
        [Parameter(Mandatory)][string]$Title,
        [string]$Description,
        [string[]]$Members = @()
    )
    $params = @{ Title = $Title; ErrorAction = "Stop" }
    if ($Description) { $params.Description = $Description }
    $group = New-PnPGroup @params
    foreach ($member in $Members) {
        Add-HTSPGroupMember -Group $Title -LoginName $member
    }
    return $group
}

function Add-HTSPGroupMember {
    param (
        [Parameter(Mandatory)][string]$Group,
        [Parameter(Mandatory)][string]$LoginName
    )
    Add-PnPGroupMember -Group $Group -LoginName $LoginName -ErrorAction Stop
}

function Remove-HTSPGroupMember {
    param (
        [Parameter(Mandatory)][string]$Group,
        [Parameter(Mandatory)][string]$LoginName
    )
    Remove-PnPGroupMember -Group $Group -LoginName $LoginName -ErrorAction Stop
}

# Nowy folder w bibliotece / folderze
function New-HTSPFolder {
    param (
        [Parameter(Mandatory)][object]$ParentNode,
        [Parameter(Mandatory)][string]$Name
    )
    if ($Name -match '["*:<>?/\\|]') { throw "Nazwa folderu zawiera niedozwolone znaki: "" * : < > ? / \ |" }
    $siteRelative = ConvertTo-HTSPSiteRelativeUrl -ServerRelativeUrl $ParentNode.ServerRelativeUrl
    $folder = Add-PnPFolder -Name $Name -Folder $siteRelative -ErrorAction Stop
    return [PSCustomObject]@{
        Title             = $folder.Name
        ServerRelativeUrl = $folder.ServerRelativeUrl
        ListTitle         = $ParentNode.ListTitle
        IsLibrary         = $false
        ItemCount         = 0
    }
}

# Pełny adres URL węzła (do otwarcia w przeglądarce)
function Get-HTSPAbsoluteUrl {
    param ([Parameter(Mandatory)][string]$ServerRelativeUrl)
    $connection = Get-PnPConnection -ErrorAction Stop
    $uri = [uri]$connection.Url
    return "$($uri.Scheme)://$($uri.Host)$ServerRelativeUrl"
}

#region Kosz witryny
function Get-HTSPRecycleBinItems {
    param (
        [ValidateRange(1, 93)][int]$Days = 93,
        [string]$DeletedBy
    )
    $cutoff = (Get-Date).AddDays(-$Days)
    return @(Get-PnPRecycleBinItem -RowLimit 5000 -ErrorAction Stop | Where-Object { $_.DeletedDate -ge $cutoff } | ForEach-Object {
            $by = if ($_.DeletedByEmail) { $_.DeletedByEmail } else { $_.DeletedByName }
            if ($DeletedBy -and "$by $($_.DeletedByName)" -notlike "*$DeletedBy*") { return }
            [PSCustomObject]@{
                Nazwa      = $_.LeafName
                Typ        = "$($_.ItemType)"
                Lokalizacja = $_.DirName
                Usunął     = $by
                Usunięto   = $_.DeletedDate
                "Rozmiar"  = Format-HTBytes $_.Size
                Etap       = if ("$($_.ItemState)" -eq "SecondStageRecycleBin") { "Kosz zbiorczy (2)" } else { "Kosz witryny (1)" }
                Id         = "$($_.Id)"
            }
        } | Sort-Object Usunięto -Descending)
}

function Restore-HTSPRecycleBinItem {
    param ([Parameter(Mandatory)][string]$Id)
    Restore-PnPRecycleBinItem -Identity $Id -Force -ErrorAction Stop
}

function Clear-HTSPRecycleBinItem {
    param ([Parameter(Mandatory)][string]$Id)
    Clear-PnPRecycleBinItem -Identity $Id -Force -ErrorAction Stop
}
#endregion

#region Zawartość folderów
function Get-HTSPFolderFiles {
    param ([Parameter(Mandatory)][object]$Node)
    $siteRelative = ConvertTo-HTSPSiteRelativeUrl -ServerRelativeUrl $Node.ServerRelativeUrl
    return @(Get-PnPFolderItem -FolderSiteRelativeUrl $siteRelative -ItemType File -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Nazwa             = $_.Name
                Rozmiar           = Format-HTBytes $_.Length
                "Rozmiar (B)"     = [long]$_.Length
                Zmodyfikowano     = $_.TimeLastModified
                Utworzono         = $_.TimeCreated
                Folder            = $Node.ServerRelativeUrl
                ServerRelativeUrl = $_.ServerRelativeUrl
            }
        } | Sort-Object Nazwa)
}
#endregion

#region Raport unikalnych uprawnień
# Biblioteki i foldery (do wskazanej głębokości) z przerwanym dziedziczeniem: @{ Node; Permissions } albo @{ Node; Error }.
# OnProgress: { param($Text) }
function Get-HTSPUniqueNodes {
    param (
        [ValidateRange(0, 10)][int]$Depth = 2,
        [object[]]$Nodes,
        [scriptblock]$OnProgress
    )
    $queue = New-Object System.Collections.Queue
    $roots = if ($Nodes) { @($Nodes) } else { @(Get-HTSPLibraries) }
    foreach ($n in $roots) { $queue.Enqueue(@{ Node = $n; Level = 0 }) }
    while ($queue.Count -gt 0) {
        $entry = $queue.Dequeue()
        $node = $entry.Node
        if ($OnProgress) { & $OnProgress $node.ServerRelativeUrl }
        try {
            if (Test-HTSPUniquePermissions -Node $node) { @{ Node = $node; Permissions = @(Get-HTSPPermissions -Node $node) } }
        }
        catch { @{ Node = $node; Error = $_.Exception.Message } }
        if ($entry.Level -lt $Depth) {
            try {
                foreach ($child in @(Get-HTSPSubFolders -ServerRelativeUrl $node.ServerRelativeUrl -ListTitle $node.ListTitle)) {
                    $queue.Enqueue(@{ Node = $child; Level = $entry.Level + 1 })
                }
            }
            catch { Write-Log -Message "Podfoldery $($node.ServerRelativeUrl): $($_.Exception.Message)" -Type "Warn" }
        }
    }
}

function Get-HTSPUniquePermissionsReport {
    param (
        [ValidateRange(0, 10)][int]$Depth = 2,
        [object[]]$Nodes,
        [scriptblock]$OnProgress
    )
    foreach ($entry in @(Get-HTSPUniqueNodes -Depth $Depth -Nodes $Nodes -OnProgress $OnProgress)) {
        $node = $entry.Node
        if ($entry.Error) {
            [PSCustomObject]@{ Ścieżka = $node.ServerRelativeUrl; Rodzaj = "Błąd"; Podmiot = ""; "Typ podmiotu" = ""; Uprawnienia = $entry.Error; Login = ""; __flag = "crit" }
            continue
        }
        foreach ($p in @($entry.Permissions)) {
            [PSCustomObject]@{
                Ścieżka       = $node.ServerRelativeUrl
                Rodzaj        = if ($node.IsLibrary) { "Biblioteka" } else { "Folder" }
                Podmiot       = $p.Principal
                "Typ podmiotu" = $p.PrincipalType
                Uprawnienia   = $p.Roles
                Login         = $p.LoginName
                __flag        = if ("$($p.LoginName)" -match 'spo-grid-all-users|Everyone|Wszyscy') { "warn" } else { "" }
            }
        }
    }
}
#endregion

#region Witryna
function Get-HTSPSiteInfo {
    <#
        Informacje o połączonej witrynie. Get-PnPSite -Includes przyjmuje tylko właściwości obiektu Site (PnP 3.x sprawdza je
        listą) - limit magazynu, blokada i udostępnianie zewnętrzne są właściwościami witryny w tenancie (Get-PnPTenantSite,
        wymaga roli administratora SharePoint); bez tej roli - opis zamiast błędu.
    #>
    $site = Get-PnPSite -Includes Usage, Owner, Url, ServerRelativeUrl, ReadOnly, WriteLocked -ErrorAction Stop
    $web = Get-PnPWeb -Includes Created, LastItemModifiedDate, Language, WebTemplate, Description -ErrorAction Stop
    $admins = @()
    try { $admins = @(Get-PnPSiteCollectionAdmin -ErrorAction Stop | ForEach-Object { "$($_.Title) <$($_.Email)>" }) } catch { $admins = @("(brak uprawnień do odczytu)") }
    $tenantSite = $null
    $tenantNote = ''
    try { $tenantSite = Get-PnPTenantSite -Identity $site.Url -ErrorAction Stop }
    catch { $tenantNote = '(wymaga roli administratora SharePoint)'; Write-Log -Message "Witryna w tenancie (Get-PnPTenantSite): $($_.Exception.Message)" -Type 'Debug' }
    $usage = $site.Usage
    $quotaMb = if ($tenantSite -and $tenantSite.StorageQuota) { [double]$tenantSite.StorageQuota } else { 0 }
    $lock = if ($tenantSite -and $tenantSite.LockState) { "$($tenantSite.LockState)" } elseif ($site.ReadOnly) { 'ReadOnly' } elseif ($site.WriteLocked) { 'NoAdditions' } elseif ($tenantNote) { "Unlock $tenantNote" } else { 'Unlock' }
    return [ordered]@{
        "Tytuł"                   = $web.Title
        "Adres"                   = $site.Url
        "Opis"                    = $web.Description
        "Szablon"                 = $web.WebTemplate
        "Utworzono"               = $web.Created
        "Ostatnia zmiana"         = $web.LastItemModifiedDate
        "Właściciel"              = if ($site.Owner) { "$($site.Owner.Title) <$($site.Owner.Email)>" } else { "" }
        "Stan blokady"            = $lock
        "Udostępnianie zewnętrzne" = if ($tenantSite) { "$($tenantSite.SharingCapability)" } else { $tenantNote }
        "Magazyn"                 = [ordered]@{
            "Wykorzystano"        = if ($usage) { Format-HTBytes $usage.Storage } else { "" }
            "Procent limitu"      = if ($usage) { "{0:N1}%" -f ($usage.StoragePercentageUsed * 100) } else { "" }
            "Limit"               = if ($quotaMb) { Format-HTBytes ($quotaMb * 1MB) } else { $tenantNote }
        }
        "Administratorzy kolekcji" = [ordered]@{ "Konta" = $admins }
    }
}

# Zapytanie KQL wyszukiwania witryn: słowa jako prefiksy («Dział kadr» -> Dział* kadr*), tylko witryny i podwitryny
function ConvertTo-HTSiteSearchQuery {
    param ([AllowNull()][AllowEmptyString()][string]$Search)
    $scope = '(contentclass:STS_Site OR contentclass:STS_Web)'
    $words = @(([string]$Search -replace '["()*:\\]', ' ') -split '\s+' | Where-Object { $_ -and $_ -cnotin 'AND', 'OR', 'NOT' })
    if ($words.Count -eq 0) { return $scope }
    return "($(@($words | ForEach-Object { "$_*" }) -join ' ')) AND $scope"
}

# Czy połączenie z Microsoft Graph jest logowaniem aplikacji (certyfikat) - bez zalogowanego użytkownika
function Test-HTGraphAppOnly {
    try { return ("$((Get-MgContext).AuthType)" -eq 'AppOnly') } catch { return $false }
}

<#
    Witryny tenantu z Microsoft Graph (surowe obiekty site). Zapytanie «sites?search=» nie działa przez Invoke-MgGraphRequest:
    moduł Microsoft Graph dopisuje «$» do parametru «search» (sites?$search=…), czego adres /sites nie obsługuje
    (400 Bad Request). Dlatego: logowanie użytkownika - Microsoft Search API (POST search/query, Sites.Read.All),
    logowanie aplikacji - sites/getAllSites (Search API wymagałby wtedy regionu).
#>
function Get-HTGraphSites {
    param ([string]$Search = '*', [int]$Max = 5000)
    $text = if ([string]::IsNullOrWhiteSpace($Search) -or $Search.Trim() -eq '*') { '' } else { $Search.Trim() }
    if (Test-HTGraphAppOnly) {
        $all = @(Invoke-HTGraphRequest -Uri 'sites/getAllSites' -All)
        if (-not $text) { return $all }
        $pattern = "*$text*"
        return @($all | Where-Object { "$($_.displayName)" -like $pattern -or "$($_.name)" -like $pattern -or "$($_.webUrl)" -like $pattern })
    }
    $query = ConvertTo-HTSiteSearchQuery -Search $text
    $items = New-Object System.Collections.Generic.List[object]
    $from = 0
    $size = 500
    while ($from -lt $Max) {
        $body = @{ requests = @(@{ entityTypes = @('site'); query = @{ queryString = $query }; from = $from; size = $size }) }
        $response = @(Invoke-HTGraphRequest -Uri 'search/query' -Method POST -Body $body)
        $container = @(@($response | Where-Object { $_ })[0].hitsContainers)[0]
        $hits = @($container.hits | Where-Object { $_ -and $_.resource })
        foreach ($hit in $hits) { $items.Add($hit.resource) }
        if ($hits.Count -eq 0 -or -not $container.moreResultsAvailable) { break }
        $from += $size
    }
    return $items.ToArray()
}

# Nazwa witryny: displayName, name, a gdy wyszukiwanie ich nie zwróci - ostatni człon adresu
function Get-HTSiteDisplayName {
    param ($Site)
    foreach ($candidate in @($Site.displayName, $Site.name, $Site.title)) { if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) { return [string]$candidate } }
    $url = [string]$Site.webUrl
    if (-not $url) { return '' }
    try {
        $uri = [System.Uri]$url
        $segment = @($uri.AbsolutePath.Trim('/') -split '/' | Where-Object { $_ })[-1]
        if ($segment) { return [System.Uri]::UnescapeDataString($segment) }
        return $uri.Host
    }
    catch { return $url }
}

# Wyszukiwanie witryn w tenancie przez Microsoft Graph (Sites.Read.All); bez OneDrive użytkowników
function Find-HTSPSites {
    param ([string]$Search = "*")
    $seen = @{}
    return @(Get-HTGraphSites -Search $Search | Where-Object {
            $url = [string]$_.webUrl
            $url -and $url -notmatch '/personal/' -and -not $_.isPersonalSite -and -not $seen.ContainsKey($url.TrimEnd('/').ToLowerInvariant())
        } | ForEach-Object {
            $seen[([string]$_.webUrl).TrimEnd('/').ToLowerInvariant()] = $true
            [PSCustomObject]@{
                Nazwa           = Get-HTSiteDisplayName -Site $_
                Adres           = $_.webUrl
                Id              = $_.id
                Opis            = $_.description
                Utworzono       = $_.createdDateTime
                "Ostatnia zmiana" = $_.lastModifiedDateTime
            }
        } | Sort-Object Nazwa)
}
#endregion

#region Przeglądanie witryn przez Microsoft Graph (bez PnP)
function Get-HTGraphSiteDrives {
    param ([Parameter(Mandatory)][string]$SiteId)
    $drives = Invoke-HTGraphRequest -Uri "sites/$SiteId/drives?`$select=id,name,driveType,quota,webUrl,createdDateTime,lastModifiedDateTime,description" -All
    return @($drives | ForEach-Object {
            $used = [double]$_.quota.used
            $total = [double]$_.quota.total
            [PSCustomObject]@{
                Biblioteka      = $_.name
                Wykorzystano    = Format-HTBytes $_.quota.used
                "Wykorzystano (MB)" = [Math]::Round($used / 1MB, 1)
                Limit           = Format-HTBytes $_.quota.total
                "Procent limitu" = if ($total -gt 0) { [Math]::Round(100 * $used / $total, 1) } else { $null }
                Stan            = $_.quota.state
                Zmodyfikowano   = $_.lastModifiedDateTime
                Adres           = $_.webUrl
                DriveId         = $_.id
                __flag          = if ("$($_.quota.state)" -in "critical", "exceeded") { "crit" } elseif ("$($_.quota.state)" -eq "nearing") { "warn" } else { "" }
            }
        } | Sort-Object Biblioteka)
}

function Get-HTGraphSiteDetail {
    param ([Parameter(Mandatory)][string]$SiteId)
    $site = Invoke-HTGraphRequest -Uri "sites/$SiteId`?`$select=id,name,displayName,webUrl,description,createdDateTime,lastModifiedDateTime,siteCollection"
    $drives = @(Get-HTGraphSiteDrives -SiteId $SiteId)
    $subsites = @()
    try { $subsites = @(Invoke-HTGraphRequest -Uri "sites/$SiteId/sites?`$select=displayName,webUrl" -All) } catch { $subsites = @() }
    $used = ($drives | Measure-Object -Property "Wykorzystano (MB)" -Sum).Sum
    return [ordered]@{
        "Nazwa"            = $site.displayName
        "Adres"            = $site.webUrl
        "Opis"             = $site.description
        "Utworzono"        = $site.createdDateTime
        "Ostatnia zmiana"  = $site.lastModifiedDateTime
        "Host"             = $site.siteCollection.hostname
        "Biblioteki"       = [ordered]@{
            "Liczba"        = $drives.Count
            "Wykorzystano"  = Format-HTBytes ([double]$used * 1MB)
            "Lista"         = @($drives | ForEach-Object { "$($_.Biblioteka): $($_.Wykorzystano)" })
        }
        "Podwitryny ($($subsites.Count))" = [ordered]@{ "Witryny" = @($subsites | ForEach-Object { "$($_.displayName) - $($_.webUrl)" }) }
        "Identyfikator"    = $site.id
    }
}

function Get-HTGraphSiteLists {
    param ([Parameter(Mandatory)][string]$SiteId, [switch]$IncludeHidden)
    $lists = Invoke-HTGraphRequest -Uri "sites/$SiteId/lists?`$select=id,displayName,list,webUrl,createdDateTime,lastModifiedDateTime,description" -All
    return @($lists | Where-Object { $IncludeHidden -or -not $_.list.hidden } | ForEach-Object {
            [PSCustomObject]@{
                Lista         = $_.displayName
                Szablon       = $_.list.template
                Ukryta        = [bool]$_.list.hidden
                Utworzono     = $_.createdDateTime
                Zmodyfikowano = $_.lastModifiedDateTime
                Opis          = $_.description
                Adres         = $_.webUrl
                ListId        = $_.id
            }
        } | Sort-Object Lista)
}

function Get-HTGraphSubsites {
    param ([Parameter(Mandatory)][string]$SiteId)
    return @(Invoke-HTGraphRequest -Uri "sites/$SiteId/sites?`$select=id,name,displayName,webUrl,createdDateTime,lastModifiedDateTime,description" -All | ForEach-Object {
            [PSCustomObject]@{ Nazwa = $_.displayName; Adres = $_.webUrl; Opis = $_.description; Utworzono = $_.createdDateTime; Zmodyfikowano = $_.lastModifiedDateTime; Id = $_.id }
        } | Sort-Object Nazwa)
}

# Zawartość folderu biblioteki (ItemId 'root' = folder główny)
function Get-HTGraphDriveItems {
    param ([Parameter(Mandatory)][string]$DriveId, [string]$ItemId = "root")
    $path = if ($ItemId -eq "root") { "drives/$DriveId/root/children" } else { "drives/$DriveId/items/$ItemId/children" }
    $items = Invoke-HTGraphRequest -Uri "$path`?`$select=id,name,size,folder,file,webUrl,lastModifiedDateTime,lastModifiedBy,createdDateTime&`$top=999" -All
    return @($items | ForEach-Object {
            $isFolder = $null -ne $_.folder
            [PSCustomObject]@{
                Nazwa          = $_.name
                Typ            = if ($isFolder) { "Folder" } else { [System.IO.Path]::GetExtension($_.name).TrimStart(".").ToUpperInvariant() }
                Rozmiar        = Format-HTBytes $_.size
                Elementy       = if ($isFolder) { $_.folder.childCount } else { $null }
                Zmodyfikowano  = $_.lastModifiedDateTime
                Zmodyfikował   = $_.lastModifiedBy.user.displayName
                Adres          = $_.webUrl
                ItemId         = $_.id
                DriveId        = $DriveId
                Folder         = $isFolder
                __flag         = if ($isFolder) { "" } else { "" }
            }
        } | Sort-Object @{ Expression = { -not $_.Folder } }, Nazwa)
}

# Pobranie pliku z biblioteki na dysk
function Save-HTGraphDriveItem {
    param ([Parameter(Mandatory)][string]$DriveId, [Parameter(Mandatory)][string]$ItemId, [Parameter(Mandatory)][string]$Path)
    Invoke-MgGraphRequest -Uri (Resolve-HTGraphUri -Uri "drives/$DriveId/items/$ItemId/content") -Method GET -OutputFilePath $Path -ErrorAction Stop
    return $Path
}
#endregion

#region Rejestracja aplikacji dla PnP PowerShell (Client ID) i klucze tajne
$script:SharePointResourceAppId = "00000003-0000-0ff1-ce00-000000000000"
$script:GraphResourceAppId = "00000003-0000-0000-c000-000000000000"
# Uprawnienia Graph wymagane do utworzenia aplikacji i nadania zgody administratora
$script:AppRegistrationScopes = @("Application.ReadWrite.All", "DelegatedPermissionGrant.ReadWrite.All")

function Test-HTGraphScopes {
    param ([Parameter(Mandatory)][string[]]$Scopes)
    $context = Get-MgContext
    if (-not $context) { return $false }
    $granted = @($context.Scopes)
    return (@($Scopes | Where-Object { $granted -notcontains $_ }).Count -eq 0)
}

function Get-HTAppRegistrationScopes { return $script:AppRegistrationScopes }

function Get-HTResourceServicePrincipal {
    param ([Parameter(Mandatory)][string]$AppId)
    $sp = @(Invoke-HTGraphRequest -Uri "servicePrincipals?`$filter=appId eq '$AppId'&`$select=id,appId,displayName,oauth2PermissionScopes")[0]
    if (-not $sp) { throw "Nie znaleziono usługi o identyfikatorze $AppId w tenancie." }
    return $sp
}

# Wpis requiredResourceAccess z nazw uprawnień delegowanych (identyfikatory odczytywane z tenantu)
function New-HTResourceAccess {
    param ([Parameter(Mandatory)][object]$ServicePrincipal, [Parameter(Mandatory)][string[]]$Scopes)
    $access = foreach ($scope in $Scopes) {
        $definition = @($ServicePrincipal.oauth2PermissionScopes | Where-Object { $_.value -eq $scope })[0]
        if (-not $definition) { throw "Nieznane uprawnienie $scope dla $($ServicePrincipal.displayName)." }
        @{ id = $definition.id; type = "Scope" }
    }
    return @{ resourceAppId = $ServicePrincipal.appId; resourceAccess = @($access) }
}

<#
    Tworzy rejestrację aplikacji (klient publiczny, przekierowanie http://localhost) do logowania interaktywnego PnP PowerShell.
    -GrantAdminConsent: zgoda administratora dla całej organizacji (użytkownicy nie zobaczą okna zgody).
    -SecretMonths: dodatkowo klucz tajny (client secret) - np. dla skryptów i innych narzędzi; wyświetlany tylko raz.
#>
function New-HTPnPAppRegistration {
    param (
        [string]$DisplayName = "Helpdesk Tools - PnP PowerShell",
        [string[]]$SharePointScopes = @("AllSites.FullControl", "TermStore.ReadWrite.All", "User.ReadWrite.All"),
        [string[]]$GraphScopes = @("User.Read", "Group.ReadWrite.All"),
        [switch]$GrantAdminConsent,
        [ValidateRange(0, 24)][int]$SecretMonths = 0
    )
    $spoSp = Get-HTResourceServicePrincipal -AppId $script:SharePointResourceAppId
    $graphSp = Get-HTResourceServicePrincipal -AppId $script:GraphResourceAppId
    $body = @{
        displayName            = $DisplayName
        signInAudience         = "AzureADMyOrg"
        isFallbackPublicClient = $true
        publicClient           = @{ redirectUris = @("http://localhost") }
        requiredResourceAccess = @(
            (New-HTResourceAccess -ServicePrincipal $spoSp -Scopes $SharePointScopes)
            (New-HTResourceAccess -ServicePrincipal $graphSp -Scopes $GraphScopes)
        )
    }
    $app = Invoke-HTGraphRequest -Uri "applications" -Method POST -Body $body
    Write-Log "Utworzono rejestrację aplikacji '$DisplayName' (Client ID: $($app.appId))." "Info"

    # Jednostka usługi aplikacji - zaraz po utworzeniu aplikacja bywa jeszcze niewidoczna (replikacja), stąd ponowienia
    $sp = $null
    for ($i = 0; $i -lt 6 -and -not $sp; $i++) {
        try { $sp = Invoke-HTGraphRequest -Uri "servicePrincipals" -Method POST -Body @{ appId = $app.appId } }
        catch { if ($i -eq 5) { throw }; Start-Sleep -Seconds 3 }
    }

    $consent = $false
    if ($GrantAdminConsent) {
        foreach ($grant in @(@{ Resource = $spoSp; Scopes = $SharePointScopes }, @{ Resource = $graphSp; Scopes = $GraphScopes })) {
            Invoke-HTGraphRequest -Uri "oauth2PermissionGrants" -Method POST -Body @{
                clientId    = $sp.id
                consentType = "AllPrincipals"
                resourceId  = $grant.Resource.id
                scope       = ($grant.Scopes -join " ")
            } | Out-Null
        }
        $consent = $true
        Write-Log "Nadano zgodę administratora dla aplikacji '$DisplayName'." "Info"
    }

    $secret = $null
    if ($SecretMonths -gt 0) { $secret = New-HTAppClientSecret -ApplicationObjectId $app.id -Months $SecretMonths }
    $tenantId = (Get-MgContext).TenantId
    return [PSCustomObject]@{
        DisplayName    = $DisplayName
        ClientId       = $app.appId
        ObjectId       = $app.id
        TenantId       = $tenantId
        ConsentGranted = $consent
        Secret         = $secret.SecretText
        SecretId       = $secret.KeyId
        SecretExpires  = $secret.Expires
    }
}

# Nowy klucz tajny (client secret) aplikacji - po ObjectId aplikacji albo jej Client ID
function New-HTAppClientSecret {
    param (
        [string]$ApplicationObjectId,
        [string]$ClientId,
        [ValidateRange(1, 24)][int]$Months = 12,
        [string]$Description = "Helpdesk Tools"
    )
    if (-not $ApplicationObjectId) {
        if (-not $ClientId) { throw "Podaj Client ID aplikacji." }
        $app = @(Invoke-HTGraphRequest -Uri "applications?`$filter=appId eq '$ClientId'&`$select=id,displayName")[0]
        if (-not $app) { throw "Nie znaleziono aplikacji o Client ID $ClientId." }
        $ApplicationObjectId = $app.id
    }
    $end = (Get-Date).ToUniversalTime().AddMonths($Months).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $result = Invoke-HTGraphRequest -Uri "applications/$ApplicationObjectId/addPassword" -Method POST -Body @{ passwordCredential = @{ displayName = $Description; endDateTime = $end } }
    Write-Log "Utworzono klucz tajny aplikacji (ważny do $($result.endDateTime))." "Info"
    return [PSCustomObject]@{ SecretText = $result.secretText; KeyId = $result.keyId; Expires = $result.endDateTime }
}

# Rejestracja przez PnP PowerShell (Register-PnPEntraIDAppForInteractiveLogin) - gdy nie ma połączenia z Graph
function Register-HTPnPAppWithPnP {
    param ([Parameter(Mandatory)][string]$Tenant, [string]$DisplayName = "Helpdesk Tools - PnP PowerShell")
    $command = Get-Command -Name Register-PnPEntraIDAppForInteractiveLogin -ErrorAction SilentlyContinue
    if (-not $command) { throw "Zainstalowana wersja PnP.PowerShell nie ma polecenia Register-PnPEntraIDAppForInteractiveLogin - zaktualizuj moduł (Update-Module PnP.PowerShell) albo utwórz aplikację przez Microsoft Graph." }
    $params = @{ ApplicationName = $DisplayName; Tenant = $Tenant; ErrorAction = "Stop" }
    if ($command.Parameters.ContainsKey("Interactive")) { $params.Interactive = $true }
    $output = Register-PnPEntraIDAppForInteractiveLogin @params
    $clientId = $null
    foreach ($o in @($output)) {
        if ($o -is [string] -and $o -match '[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}') { $clientId = $matches[0]; break }
        foreach ($p in @($o.PSObject.Properties)) {
            if ($p.Name -match 'ClientId|AppId' -and "$($p.Value)" -match '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') { $clientId = "$($p.Value)"; break }
        }
        if ($clientId) { break }
    }
    if (-not $clientId) { throw "Aplikacja mogła zostać utworzona, ale nie udało się odczytać jej Client ID - sprawdź w Entra ID (Rejestracje aplikacji): $DisplayName" }
    return [PSCustomObject]@{ DisplayName = $DisplayName; ClientId = $clientId; TenantId = $Tenant; ConsentGranted = $true; Secret = $null }
}

# Domena tenantu z adresu SharePoint (firma.sharepoint.com -> firma.onmicrosoft.com)
function Get-HTTenantFromSharePointUrl {
    param ([AllowEmptyString()][string]$Url)
    if ($Url -match '^https?://([^./]+?)(-admin|-my)?\.sharepoint\.(com|us|de|cn)') { return "$($matches[1]).onmicrosoft.com" }
    return ""
}
#endregion

#region Okna: wybór witryny i rejestracja aplikacji PnP
# Wybór witryny z listy witryn tenantu (Microsoft Graph); zwraca obiekt witryny (Nazwa, Adres, Id) albo $null
function Select-HTSharePointSite {
    if (-not $Global:ConnectedToGraphAPI) {
        Show-HTWarning -Title "Witryny" -Text "Lista witryn wymaga połączenia z Microsoft 365 (przycisk «Microsoft 365» w prawym górnym rogu). Możesz też wpisać adres witryny ręcznie."
        return $null
    }
    Set-HTBusy -Busy $true -Text "Pobieranie listy witryn…"
    try { $sites = @(Find-HTSPSites -Search "*") }
    finally { Set-HTBusy -Busy $false -Text "Gotowe" }
    $columns = @(@{ Text = "Nazwa"; Property = "Nazwa" }, @{ Text = "Adres"; Property = "Adres" }, @{ Text = "Ostatnia zmiana"; Property = "Ostatnia zmiana" })
    $selected = Show-HTSelectionDialog -Title "Wybierz witrynę SharePoint" -Items $sites -Columns $columns -Icon "E774"
    if (-not $selected) { return $null }
    return @($selected)[0]
}

<#
    Okno tworzenia aplikacji (Client ID) dla PnP PowerShell. Metody: Microsoft Graph (wymaga uprawnień
    Application.ReadWrite.All i DelegatedPermissionGrant.ReadWrite.All - program poprosi o nie) albo PnP PowerShell.
    Zapisuje Client ID w konfiguracji; zwraca wynik (ClientId, TenantId, Secret) albo $null.
#>
function Show-HTPnPAppRegistrationDialog {
    param ([string]$SiteUrl)
    $methods = @("Microsoft Graph (z poziomu programu)", "PnP PowerShell (logowanie administratora)")
    $form = Show-HTFormDialog -Title "Utwórz Client ID dla PnP" -Description "Rejestracja aplikacji w Entra ID do logowania PnP PowerShell. Wymaga roli Administrator aplikacji lub Administrator globalny." -OkText "Utwórz" -Icon "E710" -Width 600 -Fields @(
        @{ Name = "Name"; Label = "Nazwa aplikacji"; Required = $true; Default = "Helpdesk Tools - PnP PowerShell" }
        @{ Name = "Method"; Label = "Sposób"; Type = "Combo"; Options = $methods; Default = $(if ($Global:ConnectedToGraphAPI) { $methods[0] } else { $methods[1] }) }
        @{ Name = "Consent"; Label = "Nadaj zgodę administratora (użytkownicy nie zobaczą okna zgody)"; Type = "Check"; Default = $true }
        @{ Name = "Tenant"; Label = "Tenant (dla PnP PowerShell)"; Default = (Get-HTTenantFromSharePointUrl -Url $SiteUrl); Placeholder = "firma.onmicrosoft.com" }
        @{ Type = "Header"; Label = "Klucz tajny (opcjonalnie)" }
        @{ Name = "Secret"; Label = "Wygeneruj klucz tajny (client secret) - tylko metoda Microsoft Graph"; Type = "Check" }
        @{ Name = "Months"; Label = "Ważność klucza (miesiące)"; Type = "Number"; Default = 12; Min = 1; Max = 24; Hint = "Logowanie interaktywne PnP nie wymaga klucza - przydaje się w skryptach i innych narzędziach. Klucz jest pokazywany tylko raz." }
    )
    if (-not $form) { return $null }
    $result = $null
    if ($form.Method -eq $methods[0]) {
        if (-not $Global:ConnectedToGraphAPI -or -not (Test-HTGraphScopes -Scopes $script:AppRegistrationScopes)) {
            $ok = Show-HTConfirm -Title "Uprawnienia Microsoft Graph" -ConfirmText "Połącz" -Message "Utworzenie aplikacji wymaga uprawnień: $($script:AppRegistrationScopes -join ', '). Połączyć z Microsoft 365 z tymi uprawnieniami? (otworzy się logowanie w przeglądarce)"
            if (-not $ok) { return $null }
            if (-not (Connect-Module -Name "Microsoft.Graph" -ExtraScopes $script:AppRegistrationScopes)) { return $null }
            if (-not (Test-HTGraphScopes -Scopes $script:AppRegistrationScopes)) {
                Show-HTWarning -Text "Połączenie nie ma wymaganych uprawnień ($($script:AppRegistrationScopes -join ', ')). Sprawdź role konta lub użyj metody PnP PowerShell."
                return $null
            }
        }
        Set-HTBusy -Busy $true -Text "Tworzenie aplikacji $($form.Name)…"
        try {
            $result = New-HTPnPAppRegistration -DisplayName $form.Name -GrantAdminConsent:([bool]$form.Consent) -SecretMonths $(if ($form.Secret) { [int]$form.Months } else { 0 })
        }
        catch {
            Set-HTBusy -Busy $false -Text "Błąd"
            Show-HTError -Text "Nie udało się utworzyć aplikacji." -ErrorObject $_
            return $null
        }
        finally { Set-HTBusy -Busy $false -Text "Gotowe" }
    }
    else {
        if (-not $form.Tenant) { Show-HTWarning "Podaj tenant (np. firma.onmicrosoft.com)."; return $null }
        if (-not (Install-ModuleIfMissing -Name "PnP.PowerShell")) { return $null }
        Set-HTBusy -Busy $true -Text "Rejestracja aplikacji przez PnP PowerShell…"
        try {
            Import-HTRequiredModule -Name "PnP.PowerShell" | Out-Null
            $tenant = $form.Tenant
            $name = $form.Name
            # Wynik przez współdzieloną tablicę (blok z GetNewClosure ma własny zakres zmiennych)
            $holder = @{ Result = $null }
            Invoke-HTLogin -Title "Rejestracja aplikacji PnP" -ScriptBlock { $holder.Result = Register-HTPnPAppWithPnP -Tenant $tenant -DisplayName $name }.GetNewClosure()
            $result = $holder.Result
        }
        catch {
            Set-HTBusy -Busy $false -Text "Błąd"
            Show-HTError -Text "Nie udało się zarejestrować aplikacji przez PnP PowerShell." -ErrorObject $_
            return $null
        }
        finally { Set-HTBusy -Busy $false -Text "Gotowe" }
    }
    if (-not $result) { return $null }
    $Global:LastUsedClientID = $result.ClientId
    try {
        Set-HTConfigValue -Name "LastUsedClientID" -Value $result.ClientId
        Set-HTConfigValue -Name "LogClientIDForPnP" -Value $true
        $Global:LogClientIDForPnP = $true
    }
    catch { Write-Log "Nie zapisano Client ID w konfiguracji: $($_.Exception.Message)" "Warn" }
    Write-Log "Client ID aplikacji PnP: $($result.ClientId) (zapisano w ustawieniach)." "Info&Notification"
    $items = @(
        @{ Label = "Client ID (zapisany w ustawieniach)"; Value = $result.ClientId }
        @{ Label = "Tenant"; Value = $result.TenantId }
    )
    if ($result.Secret) {
        $items += @{ Label = "Klucz tajny (client secret) - zapisz go teraz, nie będzie ponownie wyświetlony"; Value = $result.Secret }
        $items += @{ Label = "Klucz ważny do"; Value = "$($result.SecretExpires)" }
    }
    $note = if ($result.ConsentGranted) { "Aplikacja jest gotowa do logowania PnP." } else { "Bez zgody administratora przy pierwszym logowaniu pojawi się okno zgody na uprawnienia." }
    Show-HTSecretDialog -Title "Aplikacja PnP utworzona" -Description "$note Zmiany w Entra ID mogą potrzebować do minuty, zanim logowanie zadziała." -Items $items
    return $result
}

# Nowy klucz tajny dla istniejącej aplikacji (po Client ID)
function Show-HTAppSecretDialog {
    param ([string]$ClientId = $Global:LastUsedClientID)
    $form = Show-HTFormDialog -Title "Nowy klucz tajny aplikacji" -Description "Klucz (client secret) jest pokazywany tylko raz. Wymaga uprawnienia Application.ReadWrite.All." -OkText "Utwórz" -Icon "E8D7" -Fields @(
        @{ Name = "ClientId"; Label = "Client ID aplikacji"; Required = $true; Validation = "Guid"; Default = "$ClientId" }
        @{ Name = "Months"; Label = "Ważność (miesiące)"; Type = "Number"; Default = 12; Min = 1; Max = 24 }
        @{ Name = "Description"; Label = "Opis klucza"; Default = "Helpdesk Tools $(Get-Date -Format 'yyyy-MM-dd')" }
    )
    if (-not $form) { return }
    if (-not $Global:ConnectedToGraphAPI -or -not (Test-HTGraphScopes -Scopes @("Application.ReadWrite.All"))) {
        if (-not (Show-HTConfirm -Title "Uprawnienia Microsoft Graph" -ConfirmText "Połącz" -Message "Utworzenie klucza wymaga uprawnienia Application.ReadWrite.All. Połączyć z Microsoft 365 z tym uprawnieniem?")) { return }
        if (-not (Connect-Module -Name "Microsoft.Graph" -ExtraScopes @("Application.ReadWrite.All"))) { return }
    }
    Set-HTBusy -Busy $true -Text "Tworzenie klucza tajnego…"
    try { $secret = New-HTAppClientSecret -ClientId $form.ClientId -Months $form.Months -Description $form.Description }
    catch { Set-HTBusy -Busy $false -Text "Błąd"; Show-HTError -Text "Nie udało się utworzyć klucza." -ErrorObject $_; return }
    finally { Set-HTBusy -Busy $false -Text "Gotowe" }
    Show-HTSecretDialog -Title "Klucz tajny aplikacji" -Items @(
        @{ Label = "Client ID"; Value = $form.ClientId }
        @{ Label = "Klucz tajny (zapisz go teraz)"; Value = $secret.SecretText }
        @{ Label = "Identyfikator klucza (Secret ID)"; Value = "$($secret.KeyId)" }
        @{ Label = "Ważny do"; Value = "$($secret.Expires)" }
    )
}
#endregion
