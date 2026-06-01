param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
)

$ErrorActionPreference = "Stop"
$failures = New-Object System.Collections.Generic.List[string]

function Assert-File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath (Join-Path $Root $Path))) {
        $failures.Add("Missing file: $Path")
    }
}

function Assert-DirectoryMissing {
    param(
        [string]$Path,
        [string]$Message
    )

    if (Test-Path -LiteralPath (Join-Path $Root $Path)) {
        $failures.Add("$Message ($Path)")
    }
}

function Read-File {
    param([string]$Path)

    $fullPath = Join-Path $Root $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        return ""
    }

    return Get-Content -LiteralPath $fullPath -Raw -Encoding utf8
}

function Assert-Contains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    $text = Read-File $Path
    if ($text -notmatch $Pattern) {
        $failures.Add("$Message ($Path)")
    }
}

function Assert-NotContains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    $text = Read-File $Path
    if ($text -match $Pattern) {
        $failures.Add("$Message ($Path)")
    }
}

function Assert-InOrder {
    param(
        [string]$Path,
        [string[]]$Tokens,
        [string]$Message
    )

    $text = Read-File $Path
    $position = -1

    foreach ($token in $Tokens) {
        $next = $text.IndexOf($token, $position + 1, [System.StringComparison]::Ordinal)
        if ($next -lt 0) {
            $failures.Add("$Message; missing or out of order token: $token ($Path)")
            return
        }

        $position = $next
    }
}

function Get-MethodBlock {
    param(
        [string]$Text,
        [string]$Signature
    )

    $start = $Text.IndexOf($Signature, [System.StringComparison]::Ordinal)
    if ($start -lt 0) {
        $failures.Add("Missing method signature: $Signature")
        return ""
    }

    $brace = $Text.IndexOf("{", $start, [System.StringComparison]::Ordinal)
    if ($brace -lt 0) {
        $failures.Add("Missing method body: $Signature")
        return ""
    }

    $depth = 0
    for ($i = $brace; $i -lt $Text.Length; $i++) {
        if ($Text[$i] -eq "{") {
            $depth++
        }
        elseif ($Text[$i] -eq "}") {
            $depth--
            if ($depth -eq 0) {
                return $Text.Substring($start, $i - $start + 1)
            }
        }
    }

    $failures.Add("Unclosed method body: $Signature")
    return ""
}

$requiredFiles = @(
    "Helper/HiAuRo.Helper/VPRHelper.cs",
    "Jobs/Viper/ViperRotationEntry.cs",
    "Jobs/Viper/ViperRotationUi.cs",
    "Jobs/Viper/ViperSettings.cs",
    "Jobs/Viper/ViperSpellHelper.cs",
    "Jobs/Viper/ViperRotationEventHandler.cs",
    "Jobs/Viper/ViperTargetResolver.cs",
    "Jobs/Viper/QTKey.cs",
    "Jobs/Viper/Opener/ViperQuickOpener.cs",
    "Jobs/Viper/Resolvers/GCD/ViperReawakenGcdResolver.cs",
    "Jobs/Viper/Resolvers/GCD/ViperDreadwinderGcdResolver.cs",
    "Jobs/Viper/Resolvers/GCD/ViperRattlingCoilGcdResolver.cs",
    "Jobs/Viper/Resolvers/GCD/ViperAoeGcdResolver.cs",
    "Jobs/Viper/Resolvers/GCD/ViperRangedFallbackGcdResolver.cs",
    "Jobs/Viper/Resolvers/GCD/ViperBaseGcdResolver.cs",
    "Jobs/Viper/Resolvers/OffGCD/ViperFollowUpAbilityResolver.cs",
    "Jobs/Viper/Resolvers/OffGCD/ViperSerpentsIreResolver.cs",
    "Jobs/Viper/Resolvers/OffGCD/ViperTrueNorthResolver.cs",
    "Jobs/Viper/Timeline/ViperTimelineVariable.cs",
    "Jobs/Viper/Timeline/ViperTimelineState.cs",
    "Jobs/Viper/Triggers/ViperHotkeyIds.cs",
    "Jobs/Viper/Triggers/TriggerAction_TimelineVariable.cs",
    "Jobs/Viper/Triggers/TriggerAction_Hotkey.cs",
    "Jobs/Viper/Triggers/TriggerAction_Potion.cs",
    "Jobs/Viper/docs/DEVELOPMENT.md",
    "Jobs/Viper/docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md"
)

foreach ($file in $requiredFiles) {
    Assert-File $file
}

Assert-Contains "Jobs/Viper/ViperRotationEntry.cs" "IRotationEntry,\s*ISettingsProvider<ViperSettings>" "Viper entry must use HiAuRo native entry and settings provider"
Assert-Contains "Jobs/Viper/ViperRotationEntry.cs" 'AuthorName\s*\{\s*get;\s*\}\s*=\s*"Kairo"' "Viper author must be Kairo"
Assert-Contains "Jobs/Viper/ViperRotationEntry.cs" "UseCustomUi\s*\{\s*get;\s*\}\s*=\s*false" "Viper must use HiAuRo declarative UI"
Assert-Contains "Jobs/Viper/ViperRotationEntry.cs" "TargetJobs\s*\{\s*get;\s*\}\s*=\s*\[HiAuRoJob\.VPR\]" "Viper TargetJobs must register VPR only"
Assert-Contains "Jobs/Viper/ViperRotationEntry.cs" "TargetJob\s*=\s*HiAuRoJob\.VPR" "Viper rotation TargetJob must be VPR"
Assert-Contains "Jobs/Viper/ViperRotationEntry.cs" "Opener\s*=\s*new\s+ViperQuickOpener\(\)" "Viper must register the quick opener"
Assert-Contains "Jobs/Viper/ViperRotationEntry.cs" "TriggerAction_TimelineVariable" "Viper must preserve timeline variable trigger action"
Assert-Contains "Jobs/Viper/ViperRotationEntry.cs" "TriggerAction_Hotkey" "Viper must preserve hotkey trigger action"
Assert-Contains "Jobs/Viper/ViperRotationEntry.cs" "TriggerAction_Potion" "Viper must preserve potion trigger action"
Assert-Contains "Jobs/Viper/ViperRotationEntry.cs" "OnEnterRotation\(\)[\s\S]+ResetCombatState\(\)" "Viper entry must reset the VPR combat state on entry"
Assert-Contains "Jobs/Viper/ViperRotationEntry.cs" "OnExitRotation\(\)[\s\S]+ResetCombatState\(\)" "Viper entry must reset the VPR combat state on exit"
Assert-InOrder "Jobs/Viper/ViperRotationEntry.cs" @(
    "ViperFollowUpAbilityResolver",
    "ViperSerpentsIreResolver",
    "ViperTrueNorthResolver",
    "ViperReawakenGcdResolver",
    "ViperDreadwinderGcdResolver",
    "ViperRattlingCoilGcdResolver",
    "ViperAoeGcdResolver",
    "ViperRangedFallbackGcdResolver",
    "ViperBaseGcdResolver"
) "Viper resolver order must keep follow-ups and burst resources ahead of base filler"

Assert-Contains "Jobs/Viper/ViperRotationUi.cs" "AddBuiltinQt\(BuiltinQt\.Burst,\s*true\)" "Viper UI must expose built-in Burst"
Assert-Contains "Jobs/Viper/ViperRotationUi.cs" "AddBuiltinQt\(BuiltinQt\.Potion,\s*false\)" "Viper UI must expose built-in Potion"
Assert-Contains "Jobs/Viper/ViperRotationUi.cs" "AddBuiltinQt\(BuiltinQt\.Hold,\s*false\)" "Viper UI must expose built-in Hold"
Assert-Contains "Jobs/Viper/ViperRotationUi.cs" "AddBuiltinQt\(BuiltinQt\.AoE,\s*true\)" "Viper UI must expose built-in AoE"
Assert-Contains "Jobs/Viper/ViperRotationUi.cs" "QTKey\.DumpResources" "Viper UI must expose resource dump QT"
Assert-Contains "Jobs/Viper/ViperRotationUi.cs" "QTKey\.ForceBurst" "Viper UI must expose force burst QT"
Assert-Contains "Jobs/Viper/ViperRotationUi.cs" "QTKey\.ForbidBurst" "Viper UI must expose forbid burst QT"
Assert-Contains "Jobs/Viper/ViperRotationUi.cs" "QTKey\.AutoTrueNorth" "Viper UI must expose automatic True North QT"
Assert-Contains "Jobs/Viper/ViperRotationUi.cs" "QTKey\.QuickOpener" "Viper UI must expose quick opener QT"
Assert-Contains "Jobs/Viper/ViperRotationUi.cs" "QTKey\.RangedFallback" "Viper UI must expose ranged fallback QT"
Assert-Contains "Jobs/Viper/ViperRotationUi.cs" 'AddDropdown\("战斗模式",\s*ViperSettings\.CombatModeOptions,\s*ref\s+_settings\.CombatMode' "Viper high-end/daily mode must be a persistent setting"

Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "HonedSteel\s*=\s*3672" "VPRHelper must expose Honed Steel for Viper AoE/base combo policy"
Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "HonedReavers\s*=\s*3772" "VPRHelper must expose Honed Reavers for Viper AoE/base combo policy"
Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "NoxiousGnash\s*=\s*3667" "VPRHelper must expose Noxious Gnash for Viper AoE poison policy"
Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "ReadyToReawaken\s*=\s*3671" "VPRHelper must expose Ready to Reawaken for Reawaken loss prevention"
Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "GrimhuntersVenom\s*=\s*3649" "VPRHelper must expose Grimhunter's Venom for follow-up policy"
Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "GrimskinsVenom\s*=\s*3650" "VPRHelper must expose Grimskin's Venom for follow-up policy"
Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "PoisedForTwinfang\s*=\s*3665" "VPRHelper must expose Poised for Twinfang for follow-up policy"
Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "PoisedForTwinblood\s*=\s*3666" "VPRHelper must expose Poised for Twinblood for follow-up policy"
Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "SerpentsTail\s*=\s*35920" "VPRHelper must expose Serpent's Tail base follow-up action"
Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "Twinfang\s*=\s*35921" "VPRHelper must expose Twinfang base follow-up action"
Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "Twinblood\s*=\s*35922" "VPRHelper must expose Twinblood base follow-up action"
Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "HuntersVenom\s*=\s*3657" "VPRHelper must expose Hunter's Venom for follow-up policy"
Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "SwiftskinsVenom\s*=\s*3658" "VPRHelper must expose Swiftskin's Venom for follow-up policy"
Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "FellhuntersVenom\s*=\s*3659" "VPRHelper must expose Fellhunter's Venom for follow-up policy"
Assert-Contains "Helper/HiAuRo.Helper/VPRHelper.cs" "FellskinsVenom\s*=\s*3660" "VPRHelper must expose Fellskin's Venom for follow-up policy"

Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "using ActionId = HiAuRo\.Helper\.VPRHelper\.EN\.Skills;" "Viper helper must use HiAuRo.Helper VPR action IDs"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "using StatusId = HiAuRo\.Helper\.VPRHelper\.EN\.Buffs;" "Viper helper must use HiAuRo.Helper VPR status IDs where available"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "VPRHelper\.Gauge" "Viper helper must read VPR gauge through HiAuRo.Helper"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "enum\s+TimelineBurstIntent" "Viper helper must preserve timeline burst intent semantics"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetTimelineBurstIntent" "Viper helper must expose force/forbid timeline burst intent"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "ResetTimelineManagedQt" "Viper helper must reset timeline-managed QT state"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "_timelineOwnedQtDefaults" "Viper helper must preserve user QT defaults when timeline temporarily owns them"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "ShouldBlockCombatRotationActions" "Viper helper must preserve combat-start blocking policy"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetBattleTimeInMs" "Viper helper must expose battle time for timeline strategy"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetTimeToNextTwoMinuteBurstWindow" "Viper helper must expose next two-minute burst window timing"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetTwoMinuteBurstAnchorInMs" "Viper helper must expose current two-minute anchor"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "ShouldStartReawaken" "Viper helper must preserve the named Reawaken start policy"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetReawakenBlockReason" "Viper helper must preserve Reawaken diagnostic block reasons"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetDreadwinderBlockReason" "Viper helper must preserve Dreadwinder diagnostic block reasons"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "CanStartDreadwinderActionChange" "Viper helper must gate fresh Dreadwinder starts against stale action change"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "ShouldTrustDreadwinderActionChangeFallback" "Viper helper must suppress stale Dreadwinder action-change fallback after a completed chain"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "CanUseDreadwinderGcd" "Viper helper must expose Dreadwinder readiness policy for the resolver"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetPendingFollowUpActionId" "Viper helper must preserve status-priority follow-up policy"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "HasPendingFollowUpOffGcd" "Viper helper must expose pending follow-up status to True North"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "HasTwinbloodFollowUpAura" "Viper helper must require real Twinblood aura before Twinblood follow-up"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "HasTwinfangFollowUpAura" "Viper helper must require real Twinfang aura before Twinfang follow-up"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "ActionId\.Twinblood" "Viper follow-up policy must action-change from the base Twinblood action"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "ActionId\.Twinfang" "Viper follow-up policy must action-change from the base Twinfang action"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "ActionId\.SerpentsTail" "Viper follow-up policy must action-change from the base Serpent's Tail action"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "StatusId\.HonedSteel" "Viper helper must use VPRHelper Honed Steel status"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "StatusId\.HonedReavers" "Viper helper must use VPRHelper Honed Reavers status"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "StatusId\.NoxiousGnash" "Viper helper must use VPRHelper Noxious Gnash status"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "HelperRuntime\.GetStatusTimeLeftOnTarget\(StatusId\.NoxiousGnash\)" "Viper AoE first step must fall back to target Noxious Gnash timing"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "StatusId\.PoisedForTwinblood" "Viper follow-up policy must use Helper Twinblood aura"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "StatusId\.PoisedForTwinfang" "Viper follow-up policy must use Helper Twinfang aura"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "StatusId\.ReadyToReawaken" "Viper Reawaken/Serpents Ire policy must use Helper Ready to Reawaken"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetTrueNorthGcdCooldown" "Viper helper must expose True North GCD cooldown decision value"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "IsInTrueNorthDecisionWindow" "Viper helper must preserve True North decision window"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetPositionalHintProgress" "Viper helper must preserve positional hint progress for UI/debug"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "using HiAuRo\.Rendering;" "Viper helper must use HiAuRo v0.1.90 positional rendering API"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "PushPositionalHint" "Viper helper must expose target-circle positional VFX push"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "PositionalState\.Push" "Viper helper must push target-circle positional VFX through HiAuRo"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "PositionalDir\.Flank" "Viper helper must map flank requirements to HiAuRo positional VFX"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "PositionalDir\.Behind" "Viper helper must map behind requirements to HiAuRo positional VFX"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetReawakenGcd" "Viper must port Reawaken chain strategy"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetDreadwinderGcd" "Viper must port Dreadwinder strategy"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetRattlingCoilGcd" "Viper must port Rattling Coil strategy"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetAoeGcd" "Viper must port AOE branch"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetRangedFallbackGcd" "Viper must port ranged fallback policy"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetFollowUpOffGcd" "Viper must port follow-up oGCD policy"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetSerpentsIreOffGcd" "Viper must port Serpents Ire burst policy"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "GetTrueNorthOffGcd" "Viper must port automatic True North policy"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "CanUsePotion" "Viper must preserve controlled potion request policy"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "ShouldHoldSerpentsIreByTimeline" "Viper must preserve Serpents Ire timeline variable gates"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "ShouldHoldReawakenByTimeline" "Viper must preserve Reawaken timeline variable gates"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "ShouldHoldDreadwinderByTimeline" "Viper must preserve Dreadwinder timeline variable gates"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "ShouldHoldRattlingCoilByTimeline" "Viper must preserve Rattling Coil timeline variable gates"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "ShouldDumpRattlingCoilByTimeline" "Viper must preserve Rattling Coil dump timeline variable gates"

Assert-Contains "Jobs/Viper/Timeline/ViperTimelineVariable.cs" 'viper_force_burst' "Viper timeline variables must keep force burst key"
Assert-Contains "Jobs/Viper/Timeline/ViperTimelineVariable.cs" 'viper_forbid_burst' "Viper timeline variables must keep forbid burst key"
Assert-Contains "Jobs/Viper/Timeline/ViperTimelineVariable.cs" 'viper_hold_serpents_ire' "Viper timeline variables must keep Serpents Ire hold key"
Assert-Contains "Jobs/Viper/Timeline/ViperTimelineVariable.cs" 'viper_hold_reawaken' "Viper timeline variables must keep Reawaken hold key"
Assert-Contains "Jobs/Viper/Timeline/ViperTimelineVariable.cs" 'viper_hold_dreadwinder' "Viper timeline variables must keep Dreadwinder hold key"
Assert-Contains "Jobs/Viper/Timeline/ViperTimelineVariable.cs" 'viper_hold_rattling_coil' "Viper timeline variables must keep Rattling Coil hold key"
Assert-Contains "Jobs/Viper/Timeline/ViperTimelineVariable.cs" 'viper_dump_rattling_coil' "Viper timeline variables must keep Rattling Coil dump key"
Assert-Contains "Jobs/Viper/Timeline/ViperTimelineVariable.cs" 'viper_dump_resources' "Viper timeline variables must keep dump resources key"
Assert-Contains "Jobs/Viper/Triggers/TriggerAction_TimelineVariable.cs" "StartDelayedBurstHold" "Viper timeline trigger must preserve delayed burst hold preset"
Assert-Contains "Jobs/Viper/Triggers/TriggerAction_TimelineVariable.cs" "ReleaseDelayedBurstPackage" "Viper timeline trigger must preserve delayed burst release preset"
Assert-Contains "Jobs/Viper/Triggers/TriggerAction_TimelineVariable.cs" "ResetAllTimelineVariables" "Viper timeline trigger must reset variables"
Assert-Contains "Jobs/Viper/Triggers/TriggerAction_Hotkey.cs" "ViperHotkeyAction" "Viper hotkey trigger must use stable enum values for timeline JSON"
Assert-Contains "Jobs/Viper/Triggers/TriggerAction_Potion.cs" "RequestTimelinePotion" "Viper potion trigger must request a short-lived controlled potion window"
Assert-Contains "Jobs/Viper/Triggers/TriggerAction_Potion.cs" "QTHelper\.IsEnabled\(BuiltinQt\.Potion\)" "Viper potion trigger must honor the built-in Potion QT before requesting a potion window"
Assert-Contains "Jobs/Viper/Triggers/ViperHotkeyIds.cs" 'public const string Potion = "hk_爆发药";' "Viper potion hotkey id must target the registered Chinese UI hotkey"

Assert-Contains "Jobs/Viper/Resolvers/GCD/ViperDreadwinderGcdResolver.cs" "CanUseDreadwinderGcd" "Viper Dreadwinder resolver must use the helper's fresh-start readiness policy"
Assert-Contains "Jobs/Viper/Resolvers/GCD/ViperBaseGcdResolver.cs" "PushPositionalHint\(_spell\)" "Viper base GCD resolver must push positional VFX for flank/behind combo finishers"
Assert-Contains "Jobs/Viper/Resolvers/GCD/ViperDreadwinderGcdResolver.cs" "PushPositionalHint\(_spell\)" "Viper Dreadwinder resolver must push positional VFX for Hunter/Swiftskin Coil"
Assert-Contains "Jobs/Viper/Opener/ViperQuickOpener.cs" "PushPositionalHint\(spell\)" "Viper opener must push positional VFX for opener positional GCDs"

foreach ($resolverPath in @(
    "Jobs/Viper/Resolvers/GCD/ViperReawakenGcdResolver.cs",
    "Jobs/Viper/Resolvers/GCD/ViperDreadwinderGcdResolver.cs",
    "Jobs/Viper/Resolvers/GCD/ViperRattlingCoilGcdResolver.cs",
    "Jobs/Viper/Resolvers/GCD/ViperAoeGcdResolver.cs",
    "Jobs/Viper/Resolvers/GCD/ViperRangedFallbackGcdResolver.cs",
    "Jobs/Viper/Resolvers/GCD/ViperBaseGcdResolver.cs",
    "Jobs/Viper/Resolvers/OffGCD/ViperFollowUpAbilityResolver.cs",
    "Jobs/Viper/Resolvers/OffGCD/ViperSerpentsIreResolver.cs",
    "Jobs/Viper/Resolvers/OffGCD/ViperTrueNorthResolver.cs"
)) {
    Assert-Contains $resolverPath "ShouldBlockCombatRotationActions" "Viper normal resolver must not select actions before combat battle time starts"
}

Assert-Contains "Jobs/Viper/Opener/ViperQuickOpener.cs" "class\s+ViperQuickOpener\s*:\s*IOpener" "Viper quick opener must use HiAuRo IOpener"
Assert-Contains "Jobs/Viper/Opener/ViperQuickOpener.cs" "handler\.AddAction\(100,\s*ActionId\.Slither,\s*SpellTargetType\.Target\)" "Viper quick opener must preserve 0.1s countdown Slither through HiAuRo CountDownHandler"
Assert-Contains "Jobs/Viper/Opener/ViperQuickOpener.cs" "public\s+List<Action<Slot>>\s+Sequence\s*=>\s*_activeSequence\s*\?\?=\s*BuildSequence\(\)" "Viper quick opener must snapshot Sequence before Runtime indexed execution"
Assert-InOrder "Jobs/Viper/Opener/ViperQuickOpener.cs" @(
    "ActionId.ReavingFangs",
    "ActionId.SwiftskinsSting",
    "ActionId.SerpentsIre",
    "ActionId.Vicewinder",
    "ActionId.HuntersCoil",
    "ActionId.SwiftskinsCoil"
) "Viper quick opener must preserve the old quick opener order"

Assert-DirectoryMissing "Jobs/Viper/docs/execution_timelines" "Viper must not migrate concrete execution timeline JSON files"
Assert-NotContains "Jobs/Viper/ViperRotationEntry.cs" "AEAssist|JobViewWindow|Kairo\.Viper|Dalamud\.Bindings\.ImGui" "Viper entry must not leak old AEAssist APIs"
Assert-NotContains "Jobs/Viper/ViperSpellHelper.cs" "AEAssist|JobApi_Viper|MemApi|Core\.|SettingMgr|TimelineController|Kairo\.Viper" "Viper helper must not leak old AEAssist APIs"
Assert-NotContains "Jobs/Viper/ViperSpellHelper.cs" "HasStatus\((3672|3772|3667|3671|3665|3666|3649|3650|3657|3658|3659|3660|1250)\)" "Viper helper must not use raw VPR status IDs when VPRHelper exposes them"
Assert-NotContains "Jobs/Viper/Opener/ViperQuickOpener.cs" "AEAssist|Core\.|SettingMgr|Kairo\.Viper" "Viper opener must not leak old AEAssist APIs"
Assert-NotContains "Jobs/Viper/Triggers/TriggerAction_Hotkey.cs" "AEAssist|JobViewWindow|ViperRotationEntry\.QT|GetHotkeyArray|SetHotkey" "Viper hotkey trigger must use HiAuRo hotkey APIs"
Assert-NotContains "Jobs/Viper/Triggers/TriggerAction_Potion.cs" "QTKey\.UsePotion|ViperRotationEntry\.QT" "Viper potion trigger must use built-in Potion and timeline request, not old custom UsePotion QT"
Assert-Contains "Jobs/Viper/ViperSpellHelper.cs" "SpellType\.Ability" "Viper ability spells must be explicitly marked as Ability"
Assert-Contains "Jobs/Viper/Opener/ViperQuickOpener.cs" "SpellType\.Ability" "Viper opener oGCD spells must be explicitly marked as Ability"
Assert-Contains "Jobs/Viper/Triggers/ViperSpellHotkeyResolver.cs" "SpellType\.Ability" "Viper hotkey spells must be explicitly marked as Ability"

Assert-Contains "Jobs/Viper/docs/DEVELOPMENT.md" "完整策略迁移" "Viper development docs must record the full-strategy migration scope"
Assert-Contains "Jobs/Viper/docs/DEVELOPMENT.md" "不迁移具体时间轴" "Viper development docs must record that concrete timeline JSON files are not migrated"
Assert-Contains "Jobs/Viper/docs/DEVELOPMENT.md" "VPRHelper" "Viper development docs must record VPRHelper as the status/action source"
Assert-Contains "Jobs/Viper/docs/DEVELOPMENT.md" "Honed Steel" "Viper development docs must record the Helper-backed Honed status policy"
Assert-Contains "Jobs/Viper/docs/DEVELOPMENT.md" "Dreadwinder" "Viper development docs must record the Dreadwinder action-change policy"
Assert-Contains "Jobs/Viper/docs/DEVELOPMENT.md" "True North" "Viper development docs must record the True North decision window"
Assert-Contains "Jobs/Viper/docs/DEVELOPMENT.md" "PositionalState.Push" "Viper development docs must record HiAuRo positional VFX usage"
Assert-Contains "Jobs/Viper/docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md" "HiAuRo.Helper" "Viper compliance docs must record Helper usage"
Assert-Contains "Jobs/Viper/docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md" "PositionalState.Push" "Viper compliance docs must record target-circle positional VFX usage"
Assert-Contains "Jobs/Viper/docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md" "SpellType.Ability" "Viper compliance docs must record the explicit ability marker rule"

$viperHelperText = Read-File "Jobs/Viper/ViperSpellHelper.cs"
$followUpBody = Get-MethodBlock $viperHelperText "public static Spell? GetFollowUpOffGcd()"
$serpentsIreIndex = $followUpBody.IndexOf("ShouldUseSerpentsIre()", [System.StringComparison]::Ordinal)
$pendingFollowUpIndex = $followUpBody.IndexOf("GetPendingFollowUpActionId()", [System.StringComparison]::Ordinal)
if ($serpentsIreIndex -lt 0 -or $pendingFollowUpIndex -lt 0 -or $serpentsIreIndex -gt $pendingFollowUpIndex) {
    $failures.Add("Viper follow-up oGCDs must yield to Serpents Ire before checking pending follow-up replacements (Jobs/Viper/ViperSpellHelper.cs)")
}

if ($followUpBody -notmatch "ShouldUseSerpentsIre\(\)[\s\S]+return\s+null") {
    $failures.Add("Viper GetFollowUpOffGcd must return null while Serpents Ire is ready for the current burst weave (Jobs/Viper/ViperSpellHelper.cs)")
}

$rattlingCoilBody = Get-MethodBlock $viperHelperText "public static Spell? GetRattlingCoilGcd()"
if ($rattlingCoilBody -notmatch "IsTargetOutsideMelee\(\)[\s\S]+return\s+null") {
    $failures.Add("Viper GetRattlingCoilGcd must hold outside melee range so ranged fallback can cover movement (Jobs/Viper/ViperSpellHelper.cs)")
}

$potionTriggerText = Read-File "Jobs/Viper/Triggers/TriggerAction_Potion.cs"
$potionHandleBody = Get-MethodBlock $potionTriggerText "public bool Handle()"
$potionQtGateIndex = $potionHandleBody.IndexOf("QTHelper.IsEnabled(BuiltinQt.Potion)", [System.StringComparison]::Ordinal)
$potionRequestIndex = $potionHandleBody.IndexOf("RequestTimelinePotion()", [System.StringComparison]::Ordinal)
if ($potionQtGateIndex -lt 0 -or $potionRequestIndex -lt 0 -or $potionQtGateIndex -gt $potionRequestIndex) {
    $failures.Add("Viper potion trigger must check built-in Potion QT before RequestTimelinePotion (Jobs/Viper/Triggers/TriggerAction_Potion.cs)")
}

if ($potionHandleBody -notmatch "!QTHelper\.IsEnabled\(BuiltinQt\.Potion\)[\s\S]+return\s+false") {
    $failures.Add("Viper potion trigger must return false without requesting a potion when built-in Potion QT is disabled (Jobs/Viper/Triggers/TriggerAction_Potion.cs)")
}

if ($failures.Count -gt 0) {
    Write-Host "Viper port validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Viper port validation passed."
