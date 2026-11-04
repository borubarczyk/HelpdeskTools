<#
    Statyczna kontrola całego kodu (bez uruchamiania i bez połączenia z tenantem) - łapie błędy, które inaczej wychodzą
    dopiero po kliknięciu przycisku: wywołanie nieistniejącej funkcji programu (np. literówka w nazwie), parametr, którego
    funkcja nie ma (np. -Type zamiast -RecipientType), funkcja zdefiniowana dwa razy, błąd składni.
#>
BeforeAll {
    $script:Root = Split-Path -Parent $PSScriptRoot
    $script:Common = @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable', 'ProgressAction', 'WhatIf', 'Confirm')
    $script:Files = @(Get-ChildItem -Path $script:Root -Recurse -Include *.ps1, *.psm1 | Where-Object { $_.FullName -notmatch '[\\/](\.git|Tests)[\\/]' })
    $script:Asts = @{}
    $script:ParseErrors = New-Object System.Collections.Generic.List[string]
    $script:Functions = @{}
    $script:Definitions = @{}
    foreach ($f in $script:Files) {
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
        $rel = $f.FullName.Substring($script:Root.Length + 1)
        $script:Asts[$rel] = $ast
        foreach ($e in @($errors)) { $script:ParseErrors.Add("$($rel):$($e.Extent.StartLineNumber) $($e.Message)") }
        foreach ($fd in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
            $key = $fd.Name.ToLowerInvariant()
            if (-not $script:Definitions.ContainsKey($key)) { $script:Definitions[$key] = New-Object System.Collections.Generic.List[string] }
            $script:Definitions[$key].Add("$($rel):$($fd.Extent.StartLineNumber)")
            $names = @()
            $aliases = @()
            $advanced = $false
            if ($fd.Body.ParamBlock) {
                $names = @($fd.Body.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
                foreach ($p in $fd.Body.ParamBlock.Parameters) { foreach ($a in $p.Attributes) { if ($a.TypeName.Name -eq 'Alias') { $aliases += @($a.PositionalArguments | ForEach-Object { $_.Value }) } } }
                $advanced = [bool](@($fd.Body.ParamBlock.Attributes | Where-Object { $_.TypeName.Name -eq 'CmdletBinding' }).Count) -or
                [bool](@($fd.Body.ParamBlock.Parameters | Where-Object { @($_.Attributes | Where-Object { $_.TypeName.Name -eq 'Parameter' }).Count }).Count)
            }
            elseif ($fd.Parameters) { $names = @($fd.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }) }
            $script:Functions[$key] = @{ Names = @($names + $aliases); Advanced = $advanced }
        }
    }
}

Describe "Statyczna kontrola wywołań" {
    It "wszystkie pliki programu parsują się bez błędów" {
        $script:ParseErrors | Should -BeNullOrEmpty
    }

    It "żadna funkcja programu nie jest zdefiniowana dwa razy (ostatnia definicja po cichu zastępuje wcześniejszą)" {
        $dupes = @($script:Definitions.Keys | Where-Object { $script:Definitions[$_].Count -gt 1 } | ForEach-Object { "$_ : $($script:Definitions[$_] -join ', ')" })
        $dupes | Should -BeNullOrEmpty
    }

    It "wywoływane funkcje programu (Czasownik-HT…) istnieją" {
        $missing = foreach ($rel in $script:Asts.Keys) {
            foreach ($c in $script:Asts[$rel].FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
                $name = $c.GetCommandName()
                if ($name -and $name -match '^[A-Za-z]+-HT[A-Za-z0-9]+$' -and -not $script:Functions.ContainsKey($name.ToLowerInvariant())) { "$($rel):$($c.Extent.StartLineNumber) $name" }
            }
        }
        @($missing) | Should -BeNullOrEmpty
    }

    It "Get-PnPSite / Get-PnPWeb -Includes: tylko właściwości dostępne w PnP.PowerShell 3.x (lista z walidacji parametru)" {
        # PnP 3.x sprawdza -Includes listą właściwości obiektu Site / Web - spoza listy (np. StorageQuota, LockState
        # z Get-PnPTenantSite) polecenie odrzuca. Listy z komunikatu PnP.PowerShell 3.4.1.
        $allowed = @{
            'get-pnpsite' = @(
        'AllowedExternalDomains', 'AllowExternalEmbeddingWrapper', 'Audit', 'ChannelCapabilities', 'CurrentChangeToken', 'CustomizedFormsPages', 'CustomScriptSafeDomains', 'EventReceivers',
                'Features', 'HubSiteSynchronizableVisitorGroup', 'Owner', 'ResourcePath', 'RecycleBin', 'RestrictContentOrgWideSearchUpdate', 'RestrictedAccessControlGroupsDelegatedOnSite', 'RootWeb',
                'SandboxedCodeActivationCapability', 'SearchBoxInNavBar', 'SecondaryContact', 'SensitivityLabelInfo', 'ServerRelativePath', 'UnlicensedOdbLicenseEnforcementWarningContext', 'UpgradeInfo', 'Usage',
                'UserCustomActions', 'VersionPolicyForNewLibrariesTemplate', 'AllowCreateDeclarativeWorkflow', 'AllowDesigner', 'AllowMasterPageEditing', 'AllowRevertFromTemplate', 'AllowSaveDeclarativeWorkflowAsTemplate', 'AllowSavePublishDeclarativeWorkflow',
                'AllowSelfServiceUpgrade', 'AllowSelfServiceUpgradeEvaluation', 'AuditLogTrimmingRetention', 'CanSyncHubSitePermissions', 'CanUpgrade', 'ChannelGroupId', 'Classification', 'CommentsOnSitePagesDisabled',
                'CompatibilityLevel', 'ComplianceAttribute', 'DisableAppViews', 'DisableCompanyWideSharingLinks', 'DisableFlows', 'ExternalSharingTipsEnabled', 'ExternalUserExpirationInDays', 'GeoLocation',
                'GroupId', 'HubSiteId', 'Id', 'SensitivityLabelId', 'SensitivityLabel', 'IsHubSite', 'IsPersonalSiteOverLicenseQuota', 'IsPersonalSiteStorageLimitSetOnPaygTenant',
                'IsRestrictContentOrgWideSearchPolicyEnforcedOnSite', 'IsRestrictedAccessControlPolicyEnforcedOnSite', 'IsRestrictedContentDiscoveryforCopilotAndAgentsEnabled', 'IsScheduledForRemoval', 'IsUnlicensedOdb', 'LockIssue', 'MaxItemsPerThrottledOperation', 'MediaTranscriptionDisabled',
                'NeedsB2BUpgrade', 'PrimaryUri', 'ReadOnly', 'RelatedGroupId', 'RequiredDesignerVersion', 'RestrictedAccessControlGroupsEnforcedOnSite', 'ScheduledDateForRemoval', 'SearchBoxPlaceholderText',
                'ServerRelativeUrl', 'ShareByEmailEnabled', 'ShareByLinkEnabled', 'ShowPeoplePickerSuggestionsForGuestUsers', 'ShowUrlStructure', 'SitePolicyEnabled', 'SocialBarOnSitePagesDisabled', 'StatusBarLink',
                'StatusBarText', 'ThicketSupportDisabled', 'TrimAuditLog', 'UIVersionConfigurationEnabled', 'UnifiedDomainUrl', 'UpgradeReminderDate', 'UpgradeScheduled', 'UpgradeScheduledDate',
                'Upgrading', 'Url', 'WriteLocked'
            )
            'get-pnpweb' = @(
        'Alerts', 'AllProperties', 'AppTiles', 'AssociatedMemberGroup', 'AssociatedOwnerGroup', 'AssociatedVisitorGroup', 'Author', 'AvailableContentTypes',
                'AvailableFields', 'CanModernizeHomepage', 'ContentTypes', 'CurrentChangeToken', 'CurrentUser', 'DataLeakagePreventionStatusInfo', 'DescriptionResource', 'EffectiveBasePermissions',
                'EventReceivers', 'Features', 'Fields', 'Folders', 'FontOptionForSiteFooterNav', 'FontOptionForSiteFooterTitle', 'FontOptionForSiteNav', 'FontOptionForSiteTitle',
                'FooterAlignment', 'FooterBackgroundFocalPoint', 'FooterEmphasis', 'FooterLayout', 'FooterOverlayColor', 'FooterOverlayGradientDirection', 'HeaderEmphasis', 'HeaderLayout',
                'HeaderOverlayColor', 'HeaderOverlayGradientDirection', 'HostedApps', 'Lists', 'ListTemplates', 'LogoAlignment', 'Navigation', 'ParentWeb',
                'ResourcePath', 'PushNotificationSubscribers', 'RecycleBin', 'RegionalSettings', 'RoleDefinitions', 'RootFolder', 'SearchBoxInNavBar', 'SearchScope',
                'ServerRelativePath', 'SiteCollectionAppCatalog', 'SiteGroups', 'SiteUserInfoList', 'SiteUsers', 'TenantAdminMembersCanShare', 'TenantAppCatalog', 'ThemeInfo',
                'TitleResource', 'UserCustomActions', 'Webs', 'WorkflowAssociations', 'WorkflowTemplates', 'FirstUniqueAncestorSecurableObject', 'RoleAssignments', 'AccessRequestListUrl',
                'AccessRequestSiteDescription', 'Acronym', 'AllowAutomaticASPXPageIndexing', 'AllowCreateDeclarativeWorkflowForCurrentUser', 'AllowDesignerForCurrentUser', 'AllowMasterPageEditingForCurrentUser', 'AllowRevertFromTemplateForCurrentUser', 'AllowRssFeeds',
                'AllowSaveDeclarativeWorkflowAsTemplateForCurrentUser', 'AllowSavePublishDeclarativeWorkflowForCurrentUser', 'AlternateCssUrl', 'AppInstanceId', 'ClassicWelcomePage', 'CommentsOnSitePagesDisabled', 'Configuration', 'ContainsConfidentialInfo',
                'Created', 'CustomMasterUrl', 'CustomSiteActionsDisabled', 'Description', 'DescriptionForExistingLanguage', 'DescriptionTranslations', 'DesignerDownloadUrlForCurrentUser', 'DesignPackageId',
                'DisableAppViews', 'DisableFlows', 'DisableRecommendedItems', 'DocumentLibraryCalloutOfficeWebAppPreviewersDisabled', 'EnableMinimalDownload', 'ExcludeFromOfflineClient', 'FooterBlur', 'FooterColorIndexInDarkMode',
                'FooterColorIndexInLightMode', 'FooterEnabled', 'FooterOverlayOpacity', 'HasFooterBackgroundImage', 'HasHeaderBackgroundImage', 'HasWebTemplateExtension', 'HeaderColorIndexInDarkMode', 'HeaderColorIndexInLightMode',
                'HeaderOverlayOpacity', 'HideTitleInHeader', 'HorizontalQuickLaunch', 'Id', 'IsEduClass', 'IsEduClassProvisionChecked', 'IsEduClassProvisionPending', 'IsHomepageModernized',
                'IsMultilingual', 'IsProvisioningComplete', 'IsRevertHomepageLinkHidden', 'Language', 'LastItemModifiedDate', 'LastItemUserModifiedDate', 'MasterUrl', 'MegaMenuEnabled',
                'MembersCanShare', 'NavAudienceTargetingEnabled', 'NextStepsFirstRunEnabled', 'NoCrawl', 'NotificationsInOneDriveForBusinessEnabled', 'NotificationsInSharePointEnabled', 'ObjectCacheEnabled', 'OverwriteTranslationsOnChange',
                'PreviewFeaturesEnabled', 'PrimaryColor', 'QuickLaunchEnabled', 'RecycleBinEnabled', 'RelatedHubSiteIds', 'RequestAccessEmail', 'SaveSiteAsTemplateEnabled', 'SearchBoxPlaceholderText',
                'ServerRelativeUrl', 'ShouldExtendHeaderBgImageToNav', 'ShowUrlStructureForCurrentUser', 'SiteLogoDescription', 'SiteLogoUrl', 'SupportedUILanguageIds', 'SyndicationEnabled', 'TenantTagPolicyEnabled',
                'ThemeApplicationActionHistory', 'ThemedCssFolderUrl', 'ThirdPartyMdmEnabled', 'Title', 'TitleForExistingLanguage', 'TitleTranslations', 'TreeViewEnabled', 'UIVersion',
                'UIVersionConfigurationEnabled', 'Url', 'UseAccessRequestDefault', 'WebTemplate', 'WebTemplateConfiguration', 'WebTemplatesGalleryFirstRunEnabled', 'WelcomePage', 'HasUniqueRoleAssignments',
                'ShieldAddRoleAssignmentPushdown'
            )
        }
        $problems = foreach ($rel in $script:Asts.Keys) {
            foreach ($c in $script:Asts[$rel].FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
                $name = ([string]$c.GetCommandName()).ToLowerInvariant()
                if (-not $allowed.ContainsKey($name)) { continue }
                $els = @($c.CommandElements)
                for ($i = 0; $i -lt $els.Count; $i++) {
                    if ($els[$i] -isnot [System.Management.Automation.Language.CommandParameterAst] -or $els[$i].ParameterName -ne 'Includes') { continue }
                    $value = if ($els[$i].Argument) { $els[$i].Argument } elseif ($i + 1 -lt $els.Count) { $els[$i + 1] } else { $null }
                    $names = if ($value -is [System.Management.Automation.Language.ArrayLiteralAst]) { @($value.Elements | ForEach-Object { $_.Extent.Text.Trim("'", '"') }) } elseif ($value) { @($value.Extent.Text.Trim("'", '"')) } else { @() }
                    foreach ($n in $names) { if ($allowed[$name] -notcontains $n) { "$($rel):$($c.Extent.StartLineNumber) $($c.GetCommandName()) -Includes $n" } }
                }
            }
        }
        @($problems) | Should -BeNullOrEmpty
    }

    It "parametry w wywołaniach funkcji programu istnieją (pełna nazwa albo jednoznaczny początek)" {
        $problems = foreach ($rel in $script:Asts.Keys) {
            foreach ($c in $script:Asts[$rel].FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
                $name = $c.GetCommandName()
                if (-not $name -or -not $script:Functions.ContainsKey($name.ToLowerInvariant())) { continue }
                $def = $script:Functions[$name.ToLowerInvariant()]
                $declared = @($def.Names) + $(if ($def.Advanced) { $script:Common } else { @() })
                foreach ($el in $c.CommandElements) {
                    if ($el -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }
                    $p = $el.ParameterName
                    if (@($declared | Where-Object { $_ -eq $p }).Count) { continue }
                    $match = @($declared | Where-Object { $_ -like "$p*" })
                    if ($match.Count -ne 1) { "$($rel):$($c.Extent.StartLineNumber) $name -$p ($(if ($match.Count) { "niejednoznaczny: $($match -join ', ')" } else { 'brak parametru' }))" }
                }
            }
        }
        @($problems) | Should -BeNullOrEmpty
    }
}
