param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$failures = New-Object System.Collections.Generic.List[string]

function Assert-File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath (Join-Path $Root $Path))) {
        $failures.Add("Missing file: $Path")
    }
}

function Assert-FileNotExists {
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

function Get-MethodText {
    param(
        [string]$Path,
        [string]$MethodName
    )

    $text = Read-File $Path
    $match = [regex]::Match($text, "(?m)^\s*(public|private)\s+(?:static\s+)?[^`r`n]*\s+$MethodName\s*\(")
    if (-not $match.Success) {
        $failures.Add("Missing method: $MethodName ($Path)")
        return ""
    }

    $braceStart = $text.IndexOf('{', $match.Index)
    if ($braceStart -lt 0) {
        $failures.Add("Missing method body: $MethodName ($Path)")
        return ""
    }

    $depth = 0
    for ($i = $braceStart; $i -lt $text.Length; $i++) {
        if ($text[$i] -eq '{') {
            $depth++
        }
        elseif ($text[$i] -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return $text.Substring($match.Index, $i - $match.Index + 1)
            }
        }
    }

    $failures.Add("Unclosed method body: $MethodName ($Path)")
    return ""
}

function Get-StaticMethodText {
    param(
        [string]$Path,
        [string]$MethodName
    )

    $text = Read-File $Path
    $match = [regex]::Match($text, "(?m)^\s*private\s+static\s+[^`r`n]*\s+$MethodName\s*\(")
    if (-not $match.Success) {
        $failures.Add("Missing static method: $MethodName ($Path)")
        return ""
    }

    $braceStart = $text.IndexOf('{', $match.Index)
    if ($braceStart -lt 0) {
        $failures.Add("Missing static method body: $MethodName ($Path)")
        return ""
    }

    $depth = 0
    for ($i = $braceStart; $i -lt $text.Length; $i++) {
        if ($text[$i] -eq '{') {
            $depth++
        }
        elseif ($text[$i] -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return $text.Substring($match.Index, $i - $match.Index + 1)
            }
        }
    }

    $failures.Add("Unclosed static method body: $MethodName ($Path)")
    return ""
}

$requiredFiles = @(
    "Jobs/BlackMage/BlackMageRotationEntry.cs",
    "Jobs/BlackMage/BlackMageRotationEventHandler.cs",
    "Jobs/BlackMage/BlackMageRotationUi.cs",
    "Jobs/BlackMage/BlackMageSettings.cs",
    "Jobs/BlackMage/BlackMageSpellHelper.cs",
    "Jobs/BlackMage/BlackMageTargetResolver.cs",
    "Jobs/BlackMage/QTKey.cs",
    "Jobs/BlackMage/Triggers/BlackMageHotkeyIds.cs",
    "Jobs/BlackMage/Triggers/TriggerAction_Hotkey.cs",
    "Jobs/BlackMage/Triggers/TriggerAction_Potion.cs",
    "Jobs/BlackMage/Opener/BlackMageOpener.cs",
    "Jobs/BlackMage/docs/DEVELOPMENT.md",
    "Jobs/BlackMage/Resolvers/GCD/BlackMageAoeGcdResolver.cs",
    "Jobs/BlackMage/Resolvers/GCD/BlackMageSingleTargetGcdResolver.cs",
    "Jobs/BlackMage/Resolvers/OffGCD/BlackMageAmplifierResolver.cs",
    "Jobs/BlackMage/Resolvers/OffGCD/BlackMageLeyLinesResolver.cs",
    "Jobs/BlackMage/Resolvers/OffGCD/BlackMageManafontResolver.cs",
    "Jobs/BlackMage/Resolvers/OffGCD/BlackMageSwiftcastResolver.cs",
    "Jobs/BlackMage/Resolvers/OffGCD/BlackMageTransposeResolver.cs",
    "Jobs/BlackMage/Resolvers/OffGCD/BlackMageTriplecastResolver.cs"
)

foreach ($file in $requiredFiles) {
    Assert-File $file
}

Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'AuthorName\s*\{\s*get;\s*\}\s*=\s*"Kairo"' "BLM entry author must be Kairo"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'UseCustomUi\s*\{\s*get;\s*\}\s*=\s*false' "BLM must use HiAuRo native UI"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'TargetJobs\s*\{\s*get;\s*\}\s*=\s*\[HiAuRoJob\.BLM\]' "BLM entry must target BLM"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'TargetJob\s*=\s*HiAuRoJob\.BLM' "BLM rotation target job must match entry"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'AcrType\s*=\s*AcrType\.PvE' "BLM rotation must be PvE"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'MinLevel\s*=\s*70' "BLM rotation should reserve the high-end level band from 70 onward"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'MaxLevel\s*=\s*100' "BLM rotation must support current level 100"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'Opener\s*=\s*new\s+BlackMageOpener\(\)' "BLM rotation must register the level 100 opener"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'EventHandler\s*=\s*new\s+BlackMageRotationEventHandler\(\)' "BLM rotation event handler must not receive temporary target/opener polling hooks"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'new\s+TriggerAction_Hotkey\(\)' "BLM rotation must register the generic HiAuRo trigger hotkey action"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'new\s+TriggerAction_Potion\(\)' "BLM rotation must register the dedicated HiAuRo trigger potion action"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'TargetResolvers\s*=\s*\[targetResolver\]' "BLM rotation must register the same target resolver used by lifecycle hooks"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'ISettingsProvider<BlackMageSettings>' "BLM settings must be HiAuRo-native"
Assert-NotContains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'BlackMageOpenerController|_targetResolver|TargetSelectionRetryMs|OpenerPollingRetryMs|TargetSelectionPolling|StartTargetSelectionPolling|StopTargetSelectionPolling|RestartTargetSelectionPolling|StartOpenerPolling|StopOpenerPolling|RestartOpenerPolling|OnTargetSelectionTick|OnOpenerTick|Coroutine\.Instance\.WaitAsync|TrySelectTarget\(\)|TryQueueCountdownActions|RuntimeCore\.IsRunning|MainControlHelper\.IsPaused' "BLM entry must not keep ACR-side target/opener polling bridges"
Assert-NotContains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'KairoHiAuRoACR\.Jobs\.BlackMage\.Data|BlackMageActionId|BlackMageStatusId' "BLM entry must not depend on local action/status ID catalogs"

Assert-InOrder "Jobs/BlackMage/BlackMageRotationEntry.cs" @(
    "BlackMageLeyLinesResolver",
    "BlackMageTriplecastResolver",
    "BlackMageSwiftcastResolver",
    "BlackMageManafontResolver",
    "BlackMageTransposeResolver",
    "BlackMageAmplifierResolver",
    "BlackMageAoeGcdResolver",
    "BlackMageSingleTargetGcdResolver"
) "BLM resolver priority must keep planned burst/movement oGCDs before the GCD loop"

Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'class\s+BlackMageOpener\s*:\s*IOpener' "BLM opener must implement HiAuRo IOpener"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'public\s+uint\s+Level\s*=>\s*100' "BLM opener must be the level 100 opener"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'private\s+List<Action<Slot>>\?\s+_activeSequence;' "BLM opener must keep one active Runtime Sequence snapshot after StartCheck"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'public\s+List<Action<Slot>>\s+Sequence\s*=>\s*_activeSequence\s*\?\?=\s*BuildSequence\(\)' "BLM opener Sequence must expose the active snapshot used by OpenerMgr"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'private\s+static\s+List<Action<Slot>>\s+BuildSequence\(\)' "BLM opener must build the executable Sequence immediately before Runtime indexed execution"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" '_activeSequence\s*=\s*BuildSequence\(\)' "BLM opener StartCheck must snapshot Sequence before OpenerMgr starts"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'StopCheck\(int\s+index\)\s*=>\s*-1' "BLM opener must not allow normal rotation to interrupt the fixed opening sequence"
Assert-NotContains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'global::HiAuRo\.Data\.Target\.Current\s+is\s+null[\s\S]*return\s+0;' "BLM opener must not interrupt itself on transient target-selection gaps"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'handler\.AddAction\(4_000,\s*BLMHelper\.EN\.Skills\.FireIII,\s*SpellTargetType\.Target\)' "BLM opener must register 4000ms prepull Fire III through HiAuRo.Helper IDs"
Assert-InOrder "Jobs/BlackMage/Opener/BlackMageOpener.cs" @(
    "BuildHighThunderSlot",
    "BuildSwiftAmplifierSlot",
    "BuildFirstFireIvSlot",
    "BuildLeyLinesSlot",
    "BuildSecondFireIvSlot",
    "BuildThirdFireIvSlot",
    "BuildFourthFireIvSlot",
    "BuildFifthFireIvSlot",
    "BuildXenoglossyManafontSlot",
    "BuildSixthFireIvSlot",
    "BuildFirstFlareStarSlot",
    "BuildSeventhFireIvSlot",
    "BuildEighthFireIvSlot",
    "BuildRefreshHighThunderSlot",
    "BuildNinthFireIvSlot",
    "BuildTenthFireIvSlot",
    "BuildEleventhFireIvSlot",
    "BuildTwelfthFireIvSlot",
    "BuildSecondFlareStarSlot",
    "BuildDespairSlot"
) "BLM opener must put the whole 100-level 5+7 package and eighth-Fire-IV Thunder refresh in HiAuRo IOpener.Sequence"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'AddDelaySpell\(450,\s*SelfAbility\(BLMHelper\.EN\.Skills\.Swiftcast\)\)' "BLM opener must delay Swiftcast before the Amplifier second weave"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'Add2NdWindowAbility\(SelfAbility\(BLMHelper\.EN\.Skills\.Amplifier\)\)' "BLM opener must use the second weave window for Amplifier"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'AddTargetGcd\(slot,\s*BLMHelper\.EN\.Skills\.HighThunder\)' "BLM opener High Thunder must be a queued GCD, not an empty-slot readiness probe"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'AddTargetGcd\(slot,\s*BLMHelper\.EN\.Skills\.FireIV\)' "BLM opener Fire IV must be a queued GCD so OpenerMgr waits for GCD readiness before Ley Lines"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'AddTargetGcd\(slot,\s*BLMHelper\.EN\.Skills\.Xenoglossy\)' "BLM 5+7 opener must queue Xenoglossy inside IOpener.Sequence"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'AddSelfAbility\(slot,\s*BLMHelper\.EN\.Skills\.Manafont\)' "BLM 5+7 opener must queue Manafont inside IOpener.Sequence after Xenoglossy"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'AddTargetGcd\(slot,\s*BLMHelper\.EN\.Skills\.FlareStar\)' "BLM 5+7 opener must queue both Flare Stars inside IOpener.Sequence"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'AddTargetGcd\(slot,\s*BLMHelper\.EN\.Skills\.Despair\)' "BLM 5+7 opener must queue Despair before returning to the normal loop"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'private\s+const\s+int\s+OpenerSlotMaxDurationMs\s*=\s*3_500' "BLM opener slots must use a long enough Runtime wait window for fixed GCD/oGCD steps"
Assert-Contains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'PrepareOpenerSlot\(slot\)' "BLM opener fixed 5+7 steps must prepare long-duration slots instead of 600ms default skips"
Assert-NotContains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'GetOpeningHighThunderGcd\(\)|GetOpeningFireIvGcd\(\)|AddIfReady\(slot,\s*BlackMageSpellHelper\.GetOpening|AddIfReady\(slot,\s*SelfAbility\(BLMHelper\.EN\.Skills\.LeyLines\)\)' "BLM opener must not let OpenerMgr skip required opener steps because a Slot was built empty"
Assert-NotContains "Jobs/BlackMage/Opener/BlackMageOpener.cs" 'KairoHiAuRoACR\.Jobs\.BlackMage\.Data|BlackMageActionId|BlackMageStatusId' "BLM opener must use HiAuRo.Helper IDs instead of local ID catalogs"
Assert-FileNotExists "Jobs/BlackMage/Opener/BlackMageOpenerController.cs" "BLM must not keep a Kairo-side opener polling/controller bridge after returning to native IOpener/CountDownHandler"

Assert-Contains "Jobs/BlackMage/BlackMageRotationUi.cs" 'AddBuiltinQt\(BuiltinQt\.Burst,\s*true\)' "BLM UI must expose Burst"
Assert-Contains "Jobs/BlackMage/BlackMageRotationUi.cs" 'AddBuiltinQt\(BuiltinQt\.Hold,\s*false\)' "BLM UI must expose Hold"
Assert-Contains "Jobs/BlackMage/BlackMageRotationUi.cs" 'AddTab\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*"\)' "BLM UI tab must be Chinese"
Assert-Contains "Jobs/BlackMage/BlackMageRotationUi.cs" 'AddQtHotkey\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*",\s*new\s+HotkeyResolver_Potion\(\)\)' "BLM potion must be a Chinese-labeled UI hotkey"
Assert-NotContains "Jobs/BlackMage/BlackMageRotationUi.cs" 'TargetSelectionOptions|_settings\.TargetSelection|目标选择|手动目标|最近敌人' "BLM UI must not expose target selection controls after Runtime owns target selection"
Assert-NotContains "Jobs/BlackMage/BlackMageRotationUi.cs" 'UsePotion|QTKey\.Potion|QTKey\.UsePotion|AddQtToggle\([^\n]*Potion|AddQtToggle\([^\n]*UsePotion' "BLM potion must not be exposed as a persistent QT"
Assert-NotContains "Jobs/BlackMage/BlackMageRotationUi.cs" 'KairoHiAuRoACR\.Jobs\.BlackMage\.Data|BlackMageActionId|BlackMageStatusId' "BLM UI must use HiAuRo.Helper IDs instead of local ID catalogs"
Assert-InOrder "Jobs/BlackMage/BlackMageRotationUi.cs" @(
    "QTKey.ForceBurst",
    "QTKey.ForbidBurst",
    "QTKey.DumpResources",
    "QTKey.HoldPolyglot",
    "QTKey.DumpPolyglot",
    "QTKey.HoldTriplecast",
    "QTKey.DumpTriplecast",
    "QTKey.HoldManafont",
    "QTKey.DumpManafont",
    "QTKey.HoldLeyLines",
    "QTKey.DumpLeyLines",
    "QTKey.ForceMovement",
    "QTKey.ForbidMovement",
    "QTKey.Aoe"
) "BLM high-end QT controls must expose burst, resource, movement, and AoE gates"
Assert-NotContains "Jobs/BlackMage/QTKey.cs" 'public const string (Stop|Burst|HighEndMode|UsePotion|PrepullFireIII)\b' "BLM must use built-in Hold/Burst and settings/hotkeys, not old AEAssist QT keys"
Assert-NotContains "Jobs/BlackMage/QTKey.cs" 'Potion|UsePotion' "BLM QT catalog must not contain potion keys"
Assert-Contains "Jobs/BlackMage/Triggers/BlackMageHotkeyIds.cs" 'public const string Potion = "hk_[^"]*\p{IsCJKUnifiedIdeographs}[^"]*";' "BLM potion hotkey id must point at the registered Chinese UI hotkey"
Assert-Contains "Jobs/BlackMage/Triggers/TriggerAction_Potion.cs" '\[TriggerTypeName\("KairoBLMPotion"\)\]' "BLM dedicated potion trigger must keep its stable discriminator"
Assert-Contains "Jobs/BlackMage/Triggers/TriggerAction_Potion.cs" 'HotkeyHelper\.ExecuteById\(BlackMageHotkeyIds\.Potion\)' "BLM dedicated potion trigger must request the registered hotkey"
Assert-Contains "Jobs/BlackMage/Triggers/TriggerAction_Potion.cs" 'AddLabel\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*"\)' "BLM potion trigger authoring UI must show Chinese text"
Assert-NotContains "Jobs/BlackMage/Triggers/TriggerAction_Potion.cs" 'SlotHelper\.Enqueue|new Slot\(|QTKey\.UsePotion|UsePotion|SpellType\.Ability' "BLM dedicated potion trigger must not enqueue a spell or restore old UsePotion QT"
Assert-Contains "Jobs/BlackMage/Triggers/TriggerAction_Hotkey.cs" 'BlackMageHotkeyAction\.Potion' "BLM generic hotkey trigger must include Potion"
Assert-InOrder "Jobs/BlackMage/Triggers/TriggerAction_Hotkey.cs" @(
    "if (Key == BlackMageHotkeyAction.Potion)",
    "HotkeyHelper.ExecuteById(BlackMageHotkeyIds.Potion);",
    "return true;",
    "var spell = CreateSpell(Key);",
    "SlotHelper.Enqueue(slot);"
) "BLM generic hotkey trigger must handle Potion through HotkeyHelper before non-potion Slot enqueue"
Assert-NotContains "Jobs/BlackMage/Triggers/TriggerAction_Hotkey.cs" 'QTKey\.UsePotion|UsePotion' "BLM generic hotkey trigger must not restore the old potion QT gate"

Assert-Contains "Jobs/BlackMage/BlackMageSettings.cs" 'FirstBurstAnchorMs\s*=\s*7_000' "BLM settings must keep the old high-end 3G burst anchor"
Assert-Contains "Jobs/BlackMage/BlackMageSettings.cs" 'ThunderRefreshMs\s*=\s*3_000' "BLM settings must keep Thunder refresh timing"
Assert-Contains "Jobs/BlackMage/BlackMageSettings.cs" 'ThunderSkipTargetHpPercent\s*=\s*0\.03f' "BLM settings must keep the old low-target-HP Thunder skip threshold"
Assert-Contains "Jobs/BlackMage/BlackMageSettings.cs" 'PolyglotDumpStacks\s*=\s*2' "BLM settings must keep Polyglot dump threshold"
Assert-NotContains "Jobs/BlackMage/BlackMageSettings.cs" 'TargetSelectionManual|TargetSelectionNearestEnemy|TargetSelectionOptions|public\s+string\s+TargetSelection' "BLM target selection must not remain an ACR persistent setting after Runtime owns target selection"
Assert-NotContains "Jobs/BlackMage/BlackMageSettings.cs" 'PrepullFireIIICountdownMs|CountdownPullActionQueueLeadMs|PostCountdownPullRecoveryMs' "BLM settings must not keep countdown bridge timing settings"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'var\s+targetResolver\s*=\s*new\s+BlackMageTargetResolver\(\)' "BLM Rotation must create one Runtime-owned target resolver without ACR UI settings"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEntry.cs" 'TargetResolvers\s*=\s*\[targetResolver\]' "BLM Rotation must wire the Runtime-owned target resolver"
Assert-Contains "Jobs/BlackMage/BlackMageTargetResolver.cs" 'TargetResolver_' "BLM target resolver must delegate nearest-enemy selection to HiAuRo built-ins"
Assert-NotContains "Jobs/BlackMage/BlackMageTargetResolver.cs" 'BlackMageSettings|TargetSelection' "BLM target resolver must not depend on ACR target-selection settings"
Assert-NotContains "Jobs/BlackMage/BlackMageTargetResolver.cs" 'TrySelectTarget\(\)|global::HiAuRo\.Data\.Objects\.Refresh\(\)|OmenTools\.OmenService\.TargetManager\.Target' "BLM target resolver must not self-assign targets outside Runtime TargetResolvers"
Assert-NotContains "Jobs/BlackMage/BlackMageRotationEventHandler.cs" 'BlackMageTargetResolver|TrySelectTarget\(\)|restartTargetSelectionPolling|RestartTargetSelectionPolling' "BLM event handler must not run ACR-side target selection hooks"
Assert-InOrder "Jobs/BlackMage/BlackMageRotationEventHandler.cs" @(
    "OnNoTarget()",
    "BlackMageSpellHelper.GetDowntimeGcd()",
    "SlotHelper.Execute(slot);"
) "BLM no-target handler must execute only the HiAuRo-native downtime recovery slot"
Assert-Contains "Jobs/BlackMage/BlackMageRotationEventHandler.cs" 'Slot\?\s+BeforeSpell\(Slot\s+slot\)' "BLM event handler must implement the current HiAuRo v0.1.79 BeforeSpell signature"
Assert-NotContains "Jobs/BlackMage/BlackMageRotationEventHandler.cs" 'void\s+BeforeSpell\(Slot\s+slot,\s*Spell\s+spell\)' "BLM event handler must not keep the old BeforeSpell signature that prevents ACR reflection loading"

Assert-FileNotExists "Jobs/BlackMage/Data/BlackMageActionId.cs" "BLM must not keep a local action ID catalog when HiAuRo.Helper has BLM IDs"
Assert-FileNotExists "Jobs/BlackMage/Data/BlackMageStatusId.cs" "BLM must not keep a local status ID catalog when HiAuRo.Helper has BLM IDs"
Assert-Contains "Helper/HiAuRo.Helper/BLMHelper.cs" 'HighThunder\s*=\s*36986' "HiAuRo.Helper BLM skill catalog must include High Thunder"
Assert-Contains "Helper/HiAuRo.Helper/BLMHelper.cs" 'FlareStar\s*=\s*36989' "HiAuRo.Helper BLM skill catalog must include Flare Star"
Assert-Contains "Helper/HiAuRo.Helper/BLMHelper.cs" 'Amplifier\s*=\s*25796' "HiAuRo.Helper BLM skill catalog must include Amplifier"
Assert-Contains "Helper/HiAuRo.Helper/BLMHelper.cs" 'Thunderhead\s*=\s*3870' "HiAuRo.Helper BLM buff catalog must include Thunderhead"
Assert-Contains "Helper/HiAuRo.Helper/BLMHelper.cs" 'HighThunder\s*=\s*3871' "HiAuRo.Helper BLM buff catalog must include High Thunder DoT"

$helperPath = "Jobs/BlackMage/BlackMageSpellHelper.cs"
$openerPath = "Jobs/BlackMage/Opener/BlackMageOpener.cs"
$openerStartText = Get-MethodText -Path $openerPath -MethodName "StartCheck"
$openerBuildSequenceText = Get-StaticMethodText -Path $openerPath -MethodName "BuildSequence"
$openerHighThunderSlotText = Get-StaticMethodText -Path $openerPath -MethodName "BuildHighThunderSlot"
$openerRefreshHighThunderSlotText = Get-StaticMethodText -Path $openerPath -MethodName "BuildRefreshHighThunderSlot"
$openerFirstFireIvSlotText = Get-StaticMethodText -Path $openerPath -MethodName "BuildFirstFireIvSlot"
$openerXenoglossyManafontSlotText = Get-StaticMethodText -Path $openerPath -MethodName "BuildXenoglossyManafontSlot"
$openerFirstFlareStarSlotText = Get-StaticMethodText -Path $openerPath -MethodName "BuildFirstFlareStarSlot"
$openerSecondFlareStarSlotText = Get-StaticMethodText -Path $openerPath -MethodName "BuildSecondFlareStarSlot"
$openerDespairSlotText = Get-StaticMethodText -Path $openerPath -MethodName "BuildDespairSlot"
$singleTargetText = Get-MethodText -Path $helperPath -MethodName "GetSingleTargetGcd"
$downtimeText = Get-MethodText -Path $helperPath -MethodName "GetDowntimeGcd"
$downtimePolicyText = Get-MethodText -Path $helperPath -MethodName "ShouldUseDowntimeRecovery"
$astralText = Get-MethodText -Path $helperPath -MethodName "GetAstralFireGcd"
$umbralText = Get-MethodText -Path $helperPath -MethodName "GetUmbralIceGcd"
$polyglotText = Get-MethodText -Path $helperPath -MethodName "GetPolyglotGcd"
$despairText = Get-MethodText -Path $helperPath -MethodName "GetDespairGcd"
$fireParadoxText = Get-MethodText -Path $helperPath -MethodName "GetFireParadoxGcd"
$firestarterEntryText = Get-MethodText -Path $helperPath -MethodName "GetFirestarterEntryGcd"
$firestarterPolicyText = Get-MethodText -Path $helperPath -MethodName "ShouldUseFirestarterToEnterAstralFire"
$openingPolyglotGcdText = Get-MethodText -Path $helperPath -MethodName "GetOpeningPolyglotBeforeManafontGcd"
$waitTransposeText = Get-MethodText -Path $helperPath -MethodName "ShouldWaitForTransposeBeforeIceTransition"
$prepareInstantIceText = Get-MethodText -Path $helperPath -MethodName "ShouldPrepareInstantIceTransition"
$swiftNearlyReadyText = Get-MethodText -Path $helperPath -MethodName "IsSwiftcastNearlyReadyForIceTransition"
$swiftCooldownText = Get-MethodText -Path $helperPath -MethodName "GetSwiftcastCooldownMs"
$thunderText = Get-MethodText -Path $helperPath -MethodName "GetThunderGcd"
$aoeThunderText = Get-MethodText -Path $helperPath -MethodName "GetAoeThunderGcd"
$refreshThunderText = Get-MethodText -Path $helperPath -MethodName "ShouldRefreshThunder"
$refreshAoeThunderText = Get-MethodText -Path $helperPath -MethodName "ShouldRefreshAoeThunder"
$skipThunderText = Get-MethodText -Path $helperPath -MethodName "ShouldSkipThunderForEndingTarget"
$targetHpText = Get-MethodText -Path $helperPath -MethodName "GetTargetHpPercent"
$aoeThunderDotText = Get-MethodText -Path $helperPath -MethodName "GetAoeThunderDotTimeLeft"
$manafontText = Get-MethodText -Path $helperPath -MethodName "GetManafontOffGcd"
$manafontPolicyText = Get-MethodText -Path $helperPath -MethodName "ShouldUseManafontNow"
$manafontHoldText = Get-MethodText -Path $helperPath -MethodName "ShouldHoldManafontForBurstWindow"
$reserveManafontText = Get-MethodText -Path $helperPath -MethodName "ShouldReserveManafontBeforeIceTransition"
$swiftIceText = Get-MethodText -Path $helperPath -MethodName "ShouldUseSwiftcastForIceTransition"
$tripleIceText = Get-MethodText -Path $helperPath -MethodName "ShouldUseTriplecastForIceTransition"
$delayAstralExitText = Get-MethodText -Path $helperPath -MethodName "ShouldDelayAstralFireExitForResource"
$singleTargetPolyglotActionText = Get-MethodText -Path $helperPath -MethodName "GetSingleTargetPolyglotActionId"
$singleTargetThunderActionText = Get-MethodText -Path $helperPath -MethodName "GetSingleTargetThunderActionId"
$aoeThunderActionText = Get-MethodText -Path $helperPath -MethodName "GetAoeThunderActionId"
$aoeText = Get-MethodText -Path $helperPath -MethodName "GetAoeGcd"
$highEndAoeText = Get-MethodText -Path $helperPath -MethodName "GetHighEndAoeGcd"
$legacyAoeText = Get-MethodText -Path $helperPath -MethodName "GetLegacyAoeGcd"
$aoeFillerText = Get-MethodText -Path $helperPath -MethodName "GetAoeFillerGcd"
$highEndAoeGateText = Get-MethodText -Path $helperPath -MethodName "ShouldUseHighEndAoeLoop"
$aoeTransposeText = Get-MethodText -Path $helperPath -MethodName "ShouldTransposeForAoeLoop"
$aoeFireActionText = Get-MethodText -Path $helperPath -MethodName "GetAoeFireActionId"
$aoeBlizzardActionText = Get-MethodText -Path $helperPath -MethodName "GetAoeBlizzardActionId"
$bestAoeTargetSpellText = Get-MethodText -Path $helperPath -MethodName "BestAoeTargetSpell"
$bestAoeTargetText = Get-MethodText -Path $helperPath -MethodName "GetBestAoeTarget"
$currentTargetText = Get-MethodText -Path $helperPath -MethodName "GetCurrentTarget"
$polyglotPackageText = Get-MethodText -Path $helperPath -MethodName "ShouldUsePolyglotInBurstPackage"
$burstWindowText = Get-MethodText -Path $helperPath -MethodName "IsInTwoMinuteBurstWindow"
$burstElapsedText = Get-MethodText -Path $helperPath -MethodName "GetElapsedInTwoMinuteBurstCycle"
$burstAnchorText = Get-MethodText -Path $helperPath -MethodName "IsAtOrAfterTwoMinuteBurstAnchor"
$activeBurstAnchorText = Get-MethodText -Path $helperPath -MethodName "GetActiveTwoMinuteBurstWindowAnchor"
$leyLinesDuplicateText = Get-MethodText -Path $helperPath -MethodName "HasUsedLeyLinesInCurrentBurstWindow"
$levelAtLeastText = Get-MethodText -Path $helperPath -MethodName "LevelAtLeast"
$openingPolyglotBridgeText = Get-MethodText -Path $helperPath -MethodName "ShouldUsePolyglotBeforeManafont"
$openingPolyglotHoldText = Get-MethodText -Path $helperPath -MethodName "ShouldHoldOpeningPolyglotForManafontTail"
$openingManafontTailText = Get-MethodText -Path $helperPath -MethodName "HasReachedOpeningManafontTail"
$openingFireIvTailText = Get-MethodText -Path $helperPath -MethodName "HasOpeningFireIvTailGcd"
$lowMpOpeningTailText = Get-MethodText -Path $helperPath -MethodName "ShouldTreatLowMpOpeningTailAsReached"
$openingFiveSevenHoldText = Get-MethodText -Path $helperPath -MethodName "ShouldKeepOpeningFiveSevenPackageInAstralFire"
$openingManafontStartedText = Get-MethodText -Path $helperPath -MethodName "HasOpeningManafontStarted"
$openingDespairHoldText = Get-MethodText -Path $helperPath -MethodName "ShouldHoldDespairForOpeningFiveSevenPackage"
$openingFlareStarWaitText = Get-MethodText -Path $helperPath -MethodName "ShouldWaitForOpeningFlareStarBeforeFireIv"
$openingPackageWaitText = Get-MethodText -Path $helperPath -MethodName "ShouldWaitForOpeningFiveSevenPackageGcd"
$openingFiveSevenCandidateText = Get-MethodText -Path $helperPath -MethodName "IsOpeningFiveSevenPackageCandidate"
$polyglotDumpStacksText = Get-MethodText -Path $helperPath -MethodName "ShouldUsePolyglotForDumpStacks"
$polyglotBurstAnchorText = Get-MethodText -Path $helperPath -MethodName "ShouldUsePolyglotForBurstAnchor"
$fireParadoxPolicyText = Get-MethodText -Path $helperPath -MethodName "ShouldUseFireParadoxInAstralFire"
$skipOpeningParadoxText = Get-MethodText -Path $helperPath -MethodName "ShouldSkipOpeningParadoxAfterManafont"
$reserveDespairText = Get-MethodText -Path $helperPath -MethodName "ShouldReserveDespairBeforeAstralFireExit"
$skipOpeningDespairText = Get-MethodText -Path $helperPath -MethodName "ShouldSkipOpeningDespairAfterFiveSevenOpener"
$openingFirestarterBlockText = Get-MethodText -Path $helperPath -MethodName "IsAfterOpeningFireIvBeforeFirstIce"

if ($openerStartText -notmatch '_activeSequence\s*=\s*BuildSequence\(\)' -or
    $openerStartText -notmatch 'CanStart\(\)' -or
    $openerStartText -notmatch '_activeSequence\.Count\s*>\s*0') {
    $failures.Add("BLM opener StartCheck must build one executable Runtime Sequence snapshot before OpenerMgr starts indexed execution")
}

if ($openerBuildSequenceText -notmatch 'StandardOpenerSteps\.ToList\(\)') {
    $failures.Add("BLM opener BuildSequence must snapshot StandardOpenerSteps immediately before Runtime indexed execution")
}

foreach ($entry in @(
    @{ Name = "Xenoglossy + Manafont"; Text = $openerXenoglossyManafontSlotText; Gcd = "Xenoglossy"; Ability = "Manafont" },
    @{ Name = "First Flare Star"; Text = $openerFirstFlareStarSlotText; Gcd = "FlareStar"; Ability = $null },
    @{ Name = "Second Flare Star"; Text = $openerSecondFlareStarSlotText; Gcd = "FlareStar"; Ability = $null },
    @{ Name = "Despair"; Text = $openerDespairSlotText; Gcd = "Despair"; Ability = $null }
)) {
    if ($entry.Text -notmatch 'PrepareOpenerSlot\(slot\)') {
        $failures.Add("BLM opener $($entry.Name) step must use the long Runtime wait window")
    }

    if ($entry.Text -notmatch "AddTargetGcd\(slot,\s*BLMHelper\.EN\.Skills\.$($entry.Gcd)\)") {
        $failures.Add("BLM opener $($entry.Name) step must queue $($entry.Gcd) directly in IOpener.Sequence")
    }

    if ($entry.Ability -and $entry.Text -notmatch "AddSelfAbility\(slot,\s*BLMHelper\.EN\.Skills\.$($entry.Ability)\)") {
        $failures.Add("BLM opener $($entry.Name) step must queue $($entry.Ability) directly after the GCD")
    }
}

foreach ($entry in @(
    @{ Name = "High Thunder"; Text = $openerHighThunderSlotText; Action = "HighThunder" },
    @{ Name = "Refresh High Thunder"; Text = $openerRefreshHighThunderSlotText; Action = "HighThunder" },
    @{ Name = "Fire IV"; Text = $openerFirstFireIvSlotText; Action = "FireIV" }
)) {
    if ($entry.Text -notmatch "AddTargetGcd\(slot,\s*BLMHelper\.EN\.Skills\.$($entry.Action)\)" -or
        $entry.Text -match 'IsReadyWithCanCast\(\)|GetOpening') {
        $failures.Add("BLM opener $($entry.Name) step must queue the GCD directly so OpenerMgr waits instead of skipping an empty Slot")
    }
}

if ($singleTargetText -notmatch 'GetAstralFireGcd' -or $singleTargetText -notmatch 'GetUmbralIceGcd' -or $singleTargetText -notmatch 'GetNeutralElementGcd') {
    $failures.Add("BLM single-target GCD must route neutral, Astral Fire, and Umbral Ice states through dedicated helpers")
}

if ($downtimeText -notmatch 'ShouldUseDowntimeRecovery\(\)' -or
    $downtimeText -notmatch 'ReadySelfSpell\(BLMHelper\.EN\.Skills\.UmbralSoul\)') {
    $failures.Add("BLM downtime GCD must use Umbral Soul through a dedicated no-target recovery policy")
}

foreach ($pattern in @(
    '!ShouldStopActions\(\)',
    '!HasTarget\(\)',
    'IsUmbralIceActive\(\)',
    'IsActionUsable\(BLMHelper\.EN\.Skills\.UmbralSoul\)',
    'CurrentMp\(\)\s*<\s*_settings\.UmbralIceFullMpThreshold',
    'GetUmbralHearts\(\)\s*<\s*MaxElementalStacks'
)) {
    if ($downtimePolicyText -notmatch $pattern) {
        $failures.Add("BLM no-target downtime recovery policy missing guard: $pattern")
    }
}

if ($downtimePolicyText -match 'Timeline|ShouldForceDowntimeRecoveryByTimeline|ShouldForbidDowntimeRecoveryByTimeline') {
    $failures.Add("BLM no-target downtime recovery must not restore old timeline runtime gates")
}

foreach ($pattern in @(
    'GetFirestarterEntryGcd',
    'GetOpeningPolyglotBeforeManafontGcd',
    'GetThunderGcd',
    'GetFireParadoxGcd',
    'GetPolyglotGcd\(false\)',
    'GetFlareStarGcd',
    'GetDespairGcd',
    'BLMHelper\.EN\.Skills\.FireIV'
)) {
    if ($astralText -notmatch $pattern) {
        $failures.Add("BLM Astral Fire loop missing policy token: $pattern")
    }
}

foreach ($pattern in @(
    'GetUmbralRecoveryGcd',
    'GetThunderGcd',
    'GetUmbralParadoxGcd',
    'GetUmbralFireEntryGcd'
)) {
    if ($umbralText -notmatch $pattern) {
        $failures.Add("BLM Umbral Ice loop missing policy token: $pattern")
    }
}

if ($polyglotText -notmatch 'ShouldUsePolyglotInBurstPackage\(\)') {
    $failures.Add("BLM Polyglot spending must route through the shared burst package policy")
}

foreach ($pattern in @(
    'ShouldUsePolyglotForDumpStacks\(\)',
    'ShouldUsePolyglotBeforeManafont\(\)',
    'ShouldUseMovementTools\(\)',
    'ShouldUseDumpResources\(\)',
    'ShouldDumpPolyglot\(\)',
    'ShouldUsePolyglotForBurstAnchor\(\)'
)) {
    if ($polyglotPackageText -notmatch $pattern) {
        $failures.Add("BLM Polyglot burst package policy missing guard: $pattern")
    }
}

if ($polyglotPackageText -match 'Timeline|ShouldDumpPolyglotByTimeline') {
    $failures.Add("BLM Polyglot burst package policy must not restore old timeline runtime gates")
}

if ($openingPolyglotHoldText -notmatch 'IsOpeningManafontCandidate\(\)' -or
    $openingPolyglotHoldText -notmatch '!HasReachedOpeningManafontTail\(\)') {
    $failures.Add("BLM opening Polyglot hold must apply until the 5+7 Manafont tail is reached")
}

if ($polyglotDumpStacksText -notmatch 'ShouldHoldOpeningPolyglotForManafontTail\(\)[\s\S]*return false;') {
    $failures.Add("BLM Polyglot dump-stacks policy must not spend the opener bridge before the Manafont tail")
}

if ($polyglotBurstAnchorText -notmatch 'ShouldHoldOpeningPolyglotForManafontTail\(\)[\s\S]*return false;') {
    $failures.Add("BLM Polyglot burst-anchor policy must not spend the opener bridge before the Manafont tail")
}

if ($polyglotText -notmatch 'aoe\s*\?\s*BLMHelper\.EN\.Skills\.Foul\s*:\s*GetSingleTargetPolyglotActionId\(\)') {
    $failures.Add("BLM single-target Polyglot must choose Foul at 70-79 and Xenoglossy at 80+ through a level-profile helper")
}

if ($singleTargetPolyglotActionText -notmatch 'LevelAtLeast\(80\)' -or
    $singleTargetPolyglotActionText -notmatch 'BLMHelper\.EN\.Skills\.Xenoglossy' -or
    $singleTargetPolyglotActionText -notmatch 'BLMHelper\.EN\.Skills\.Foul') {
    $failures.Add("BLM single-target Polyglot action helper must gate Xenoglossy at level 80 and fall back to Foul")
}

if ($despairText -notmatch 'LevelAtLeast\(72\)') {
    $failures.Add("BLM Despair must be gated below level 72")
}

if ($openingPolyglotBridgeText -notmatch 'LevelAtLeast\(80\)') {
    $failures.Add("BLM opening Polyglot-before-Manafont bridge must be gated to level 80+ Xenoglossy profiles")
}

if ($openingPolyglotBridgeText -notmatch 'HasOpeningFireIvTailGcd\(\)') {
    $failures.Add("BLM opening Polyglot-before-Manafont bridge must tolerate HiAuRo opener Fire IV history under-counts")
}

if ($openingPolyglotBridgeText -notmatch 'IsActionUsable\(BLMHelper\.EN\.Skills\.Manafont\)') {
    $failures.Add("BLM Polyglot-before-Manafont bridge must still require a currently usable Manafont")
}

if ($openingManafontTailText -notmatch 'ShouldTreatLowMpOpeningTailAsReached\(\)') {
    $failures.Add("BLM 5+7 opener Manafont tail must include the FFLogs fight 16 low-MP under-count fallback")
}

foreach ($pattern in @(
    '_lastCombatGcdActionId\s*==\s*BLMHelper\.EN\.Skills\.FireIV',
    'ShouldTreatLowMpOpeningTailAsReached\(\)'
)) {
    if ($openingFireIvTailText -notmatch $pattern) {
        $failures.Add("BLM opening Fire IV tail GCD helper missing guard: $pattern")
    }
}

foreach ($pattern in @(
    'LevelAtLeast\(100\)',
    'IsOpeningFiveSevenPackageCandidate\(\)',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.BlizzardIII\)\s*==\s*0',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.Manafont\)\s*==\s*0',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.Despair\)\s*==\s*0',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.FlareStar\)\s*==\s*0',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.FireIV\)\s*>=\s*OpeningManafontFireIVCount\s*-\s*1',
    'CurrentMp\(\)\s*<\s*GetExpectedFireIVMpCost\(\)'
)) {
    if ($lowMpOpeningTailText -notmatch $pattern) {
        $failures.Add("BLM FFLogs fight 16 low-MP 5+7 fallback missing guard: $pattern")
    }
}

foreach ($pattern in @(
    'LevelAtLeast\(100\)',
    'IsAstralFireActive\(\)',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.BlizzardIII\)\s*>\s*0',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.Despair\)\s*>\s*0',
    'IsOpeningFiveSevenPackageCandidate\(\)',
    'HasOpeningManafontStarted\(\)',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.FlareStar\)\s*>=\s*OpeningFlareStarCount'
)) {
    if ($openingFiveSevenHoldText -notmatch $pattern) {
        $failures.Add("BLM full 5+7 opener Astral Fire hold missing guard: $pattern")
    }
}

if ($openingFiveSevenHoldText -match 'CurrentMp\(\)\s*>\s*0') {
    $failures.Add("BLM full 5+7 opener hold must not allow ice just because MP is zero before the package is complete")
}

if ($openingFiveSevenHoldText -match 'IsOpeningManafontCandidate\(\)') {
    $failures.Add("BLM full 5+7 opener hold must not depend on Manafont CD/readiness checks")
}

foreach ($pattern in @(
    'IsAstralFireActive\(\)',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.Manafont\)\s*==\s*0',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.Despair\)\s*==\s*0',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.FireIV\)\s*<\s*OpeningTotalFireIVCount',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.FlareStar\)\s*<\s*OpeningFlareStarCount',
    '!_openingManafontQueued'
)) {
    if ($openingFiveSevenCandidateText -notmatch $pattern) {
        $failures.Add("BLM full 5+7 opener candidate missing guard: $pattern")
    }
}

if ($openingFiveSevenCandidateText -match 'IsActionUsable\(BLMHelper\.EN\.Skills\.Manafont\)') {
    $failures.Add("BLM full 5+7 opener candidate must not depend on Manafont CD/readiness checks")
}

foreach ($pattern in @(
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.Manafont\)\s*>\s*0',
    '_openingManafontQueued'
)) {
    if ($openingManafontStartedText -notmatch $pattern) {
        $failures.Add("BLM full 5+7 opener Manafont-start detector missing guard: $pattern")
    }
}

if ($delayAstralExitText -notmatch 'ShouldKeepOpeningFiveSevenPackageInAstralFire\(\)[\s\S]*return true;') {
    $failures.Add("BLM Astral Fire exit must hold the whole 5+7 opener package before any ice transition")
}

foreach ($pattern in @(
    'ShouldKeepOpeningFiveSevenPackageInAstralFire\(\)',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.FlareStar\)\s*<\s*OpeningFlareStarCount'
)) {
    if ($openingDespairHoldText -notmatch $pattern) {
        $failures.Add("BLM 5+7 opener Despair hold missing guard: $pattern")
    }
}

if ($despairText -notmatch 'ShouldHoldDespairForOpeningFiveSevenPackage\(\)[\s\S]*return null;') {
    $failures.Add("BLM Despair must not fire before the two-Flare-Star 5+7 opener package is complete")
}

foreach ($pattern in @(
    'HasOpeningManafontStarted\(\)',
    'OpeningManafontFireIVCount\s*\+\s*1',
    'OpeningTotalFireIVCount',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.FireIV\)\s*<\s*plannedFireIvCount',
    'GetFlareStarGcd\(\)\s+is\s+null'
)) {
    if ($openingFlareStarWaitText -notmatch $pattern) {
        $failures.Add("BLM 5+7 opener Flare Star wait missing guard: $pattern")
    }
}

if ($openingPackageWaitText -notmatch 'ShouldKeepOpeningFiveSevenPackageInAstralFire\(\)') {
    $failures.Add("BLM 5+7 opener GCD wait helper must use the full package hold")
}

if ($levelAtLeastText -notmatch 'HelperRuntime\.GetCurrentLevel\(\)' -or
    $levelAtLeastText -notmatch 'currentLevel\s*>\s*0\s*&&\s*currentLevel\s*>=\s*level' -or
    $levelAtLeastText -match 'currentLevel\s*<=\s*0\s*\|\|') {
    $failures.Add("BLM level-profile gates must fail closed when HelperRuntime cannot report the current level")
}

if ($firestarterEntryText -notmatch 'ShouldUseFirestarterToEnterAstralFire\(\)' -or
    $firestarterEntryText -notmatch 'ReadyTargetSpell\(BLMHelper\.EN\.Skills\.FireIII\)') {
    $failures.Add("BLM Firestarter entry must route through a dedicated Fire III helper")
}

foreach ($pattern in @(
    'IsAstralFireActive\(\)',
    'HasFirestarter\(\)',
    'GetAstralFireStacks\(\)\s*<\s*MaxElementalStacks',
    '!IsAfterOpeningFireIvBeforeFirstIce\(\)'
)) {
    if ($firestarterPolicyText -notmatch $pattern) {
        $failures.Add("BLM Firestarter entry policy is missing guard: $pattern")
    }
}

foreach ($pattern in @(
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.FireIV\)\s*>\s*0',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.BlizzardIII\)\s*==\s*0'
)) {
    if ($openingFirestarterBlockText -notmatch $pattern) {
        $failures.Add("BLM opener Firestarter block must only apply after the first opener Fire IV and before the first ice transition: $pattern")
    }
}

$firestarterEntryIndex = $astralText.IndexOf('GetFirestarterEntryGcd()')
$openingPolyglotIndex = $astralText.IndexOf('GetOpeningPolyglotBeforeManafontGcd()')
$fireParadoxIndex = $astralText.IndexOf('GetFireParadoxGcd()')
$thunderIndex = $astralText.IndexOf('GetThunderGcd()')
if ($firestarterEntryIndex -lt 0 -or $thunderIndex -lt 0 -or $firestarterEntryIndex -gt $thunderIndex) {
    $failures.Add("BLM Astral Fire loop must use Firestarter to reach Astral Fire III before Thunder maintenance")
}

if ($openingPolyglotIndex -lt 0 -or $fireParadoxIndex -lt 0 -or $openingPolyglotIndex -gt $fireParadoxIndex) {
    $failures.Add("BLM opening Polyglot bridge must be selected before Fire Paradox in the 5+7 Manafont tail")
}

if ($fireParadoxIndex -lt 0 -or $thunderIndex -lt 0 -or $fireParadoxIndex -gt $thunderIndex) {
    $failures.Add("BLM Astral Fire loop must use Fire Paradox before Thunder so no-Firestarter fire entries generate Firestarter first")
}

$openingFlareStarWaitIndex = $astralText.IndexOf('ShouldWaitForOpeningFlareStarBeforeFireIv()')
$fireIvIndex = $astralText.IndexOf('ReadyTargetSpell(BLMHelper.EN.Skills.FireIV)')
if ($openingFlareStarWaitIndex -lt 0 -or $fireIvIndex -lt 0 -or $openingFlareStarWaitIndex -gt $fireIvIndex) {
    $failures.Add("BLM 5+7 opener must wait for planned Flare Star before continuing Fire IV")
}

$openingPackageWaitIndex = $astralText.IndexOf('ShouldWaitForOpeningFiveSevenPackageGcd()')
$switchToIceIndex = $astralText.IndexOf('ShouldSwitchToUmbralIce()')
if ($openingPackageWaitIndex -lt 0 -or $switchToIceIndex -lt 0 -or $openingPackageWaitIndex -gt $switchToIceIndex) {
    $failures.Add("BLM 5+7 opener must wait on an incomplete package before any ice-transition branch")
}

if ($openingPolyglotGcdText -notmatch 'ShouldUsePolyglotBeforeManafont\(\)' -or
    $openingPolyglotGcdText -notmatch 'ReadyTargetSpell\(GetSingleTargetPolyglotActionId\(\)\)') {
    $failures.Add("BLM opening Polyglot bridge helper must use the existing Manafont-tail gate and level-profile Polyglot action")
}

$waitTransposeIndex = $astralText.IndexOf('ShouldWaitForTransposeBeforeIceTransition()')
$directIceSwitchIndex = $astralText.IndexOf('ReadyTargetSpell(BLMHelper.EN.Skills.BlizzardIII)')
if ($waitTransposeIndex -lt 0 -or $directIceSwitchIndex -lt 0 -or $waitTransposeIndex -gt $directIceSwitchIndex) {
    $failures.Add("BLM Astral Fire loop must wait for Transpose before hardcasting Blizzard III when an instant ice transition is available")
}

foreach ($pattern in @(
    'ShouldPrepareInstantIceTransition\(\)',
    'GCDHelper\.CanUseGCD\(\)[\s\S]*return false;',
    'HasSwiftcast\(\)',
    'HasTriplecast\(\)',
    'ShouldUseSwiftcastForIceTransition\(\)',
    'IsSwiftcastNearlyReadyForIceTransition\(\)',
    'ShouldUseTriplecastForIceTransition\(\)'
)) {
    if ($waitTransposeText -notmatch $pattern) {
        $failures.Add("BLM Transpose wait policy missing guard: $pattern")
    }
}

foreach ($pattern in @(
    'IsAstralFireActive\(\)',
    'IsActionUsable\(BLMHelper\.EN\.Skills\.Transpose\)',
    'ShouldSwitchToUmbralIce\(\)',
    'ShouldTransposeFromAstralFire\(\)'
)) {
    if ($prepareInstantIceText -notmatch $pattern) {
        $failures.Add("BLM instant ice-transition preparation missing guard: $pattern")
    }
}

if ($swiftNearlyReadyText -notmatch 'GetSwiftcastCooldownMs\(\)' -or
    $swiftNearlyReadyText -notmatch 'SwiftcastIceTransitionWaitMs') {
    $failures.Add("BLM Swiftcast ice-transition wait must use the bounded Swiftcast cooldown helper")
}

if ($swiftCooldownText -notmatch 'SelfAbility\(BLMHelper\.EN\.Skills\.Swiftcast\)\.CooldownMs') {
    $failures.Add("BLM Swiftcast cooldown helper must read the live HiAuRo Spell cooldown")
}

if ($waitTransposeText.IndexOf('GCDHelper.CanUseGCD()') -gt $waitTransposeText.IndexOf('HasSwiftcast()')) {
    $failures.Add("BLM ice-transition wait must release the GCD before checking instant-cast tool state")
}

$umbralPolyglotIndex = $umbralText.IndexOf('GetPolyglotGcd(false)')
$umbralRecoveryIndex = $umbralText.IndexOf('GetUmbralRecoveryGcd()')
if ($umbralPolyglotIndex -lt 0 -or $umbralRecoveryIndex -lt 0 -or $umbralPolyglotIndex -gt $umbralRecoveryIndex) {
    $failures.Add("BLM Umbral Ice loop must allow burst/dump Polyglot before recovery GCDs")
}

if ($fireParadoxText -notmatch 'ShouldUseFireParadoxInAstralFire\(\)') {
    $failures.Add("BLM Fire Paradox must route through the explicit Astral Fire Paradox policy")
}

if ($fireParadoxPolicyText -notmatch 'ShouldSkipOpeningParadoxAfterManafont\(\)[\s\S]*return false;' -or
    $fireParadoxPolicyText.IndexOf('ShouldSkipOpeningParadoxAfterManafont()') -gt $fireParadoxPolicyText.IndexOf('!HasFirestarter()')) {
    $failures.Add("BLM Fire Paradox must be skipped after opening Manafont before missing-Firestarter or Astral Soul checks")
}

foreach ($pattern in @(
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.Manafont\)\s*>\s*0',
    '_openingManafontQueued',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.FireIV\)\s*<\s*OpeningTotalFireIVCount',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.Despair\)\s*==\s*0',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.FlareStar\)\s*<\s*OpeningFlareStarCount'
)) {
    if ($skipOpeningParadoxText -notmatch $pattern) {
        $failures.Add("BLM post-Manafont Fire Paradox skip missing guard: $pattern")
    }
}

if ($skipOpeningParadoxText -match 'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.FireIV\)\s*>=\s*OpeningManafontFireIVCount') {
    $failures.Add("BLM post-Manafont Fire Paradox skip must not depend on the opener Fire IV lower-bound count")
}

if ($delayAstralExitText -notmatch 'ShouldReserveDespairBeforeAstralFireExit\(\)[\s\S]*return true;') {
    $failures.Add("BLM Astral Fire exit must reserve Despair before Transpose or Blizzard III can cut the fire tail")
}

if ($delayAstralExitText -notmatch 'GetAstralSoulStacks\(\)\s*>=\s*MaxAstralSoulStacks[\s\S]*GetFlareStarGcd\(\)\s+is\s+not\s+null') {
    $failures.Add("BLM Astral Fire exit must only hold for max Astral Soul when Flare Star is actually ready/castable")
}

if ($delayAstralExitText -match 'GetAstralSoulStacks\(\)\s*>=\s*MaxAstralSoulStacks\)\s*[\r\n\s]*return true;') {
    $failures.Add("BLM Astral Fire exit must not wait forever on max Astral Soul when Flare Star is forbidden or unavailable")
}

foreach ($pattern in @(
    'LevelAtLeast\(72\)',
    '!IsAstralFireActive\(\)',
    'IsForbidBurstActive\(\)',
    '_lastCombatGcdActionId\s*==\s*BLMHelper\.EN\.Skills\.Despair',
    'CurrentMp\(\)\s*<=\s*0',
    'CurrentMp\(\)\s*>\s*_settings\.DespairMpThreshold',
    'ShouldUseOpeningManafontBeforeDespair\(\)',
    'ShouldSkipOpeningDespairAfterFiveSevenOpener\(\)'
)) {
    if ($reserveDespairText -notmatch $pattern) {
        $failures.Add("BLM Despair reservation is missing guard: $pattern")
    }
}

foreach ($pattern in @(
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.BlizzardIII\)\s*==\s*0',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.Manafont\)\s*>\s*0',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.Despair\)\s*==\s*0',
    'GetCombatActionUseCount\(BLMHelper\.EN\.Skills\.FlareStar\)\s*<\s*OpeningFlareStarCount'
)) {
    if ($skipOpeningDespairText -notmatch $pattern) {
        $failures.Add("BLM 5+7 opener early-Despair skip is missing guard: $pattern")
    }
}

if ($thunderText -notmatch 'GetSingleTargetThunderActionId\(\)' -or
    $singleTargetThunderActionText -notmatch 'LevelAtLeast\(100\)' -or
    $singleTargetThunderActionText -notmatch 'BLMHelper\.EN\.Skills\.HighThunder' -or
    $singleTargetThunderActionText -notmatch 'HelperRuntime\.GetActionChange\(BLMHelper\.EN\.Skills\.Thunder\)') {
    $failures.Add("BLM single-target Thunder must use High Thunder at 100 and Helper action-change fallback below 100")
}

foreach ($pattern in @(
    'GetCurrentTarget\(\)',
    'ShouldUseDumpResources\(\)',
    'GetTargetHpPercent\(target\)\s*<=\s*_settings\.ThunderSkipTargetHpPercent'
)) {
    if ($skipThunderText -notmatch $pattern) {
        $failures.Add("BLM Thunder skip policy must avoid low-value DoT refreshes on ending targets: $pattern")
    }
}

if ($targetHpText -notmatch 'target\.MaxHp\s*<=\s*0' -or
    $targetHpText -notmatch '\(float\)target\.CurrentHp\s*/\s*target\.MaxHp') {
    $failures.Add("BLM target HP percent helper must use live IBattleChara CurrentHp/MaxHp")
}

if ($refreshThunderText -notmatch '!ShouldSkipThunderForEndingTarget\(\)') {
    $failures.Add("BLM single-target Thunder refresh must skip dump/end-target refreshes")
}

if ($refreshAoeThunderText -notmatch '!ShouldSkipThunderForEndingTarget\(\)') {
    $failures.Add("BLM AoE Thunder refresh must skip dump/end-target refreshes")
}

if ($aoeThunderText -notmatch 'GetAoeThunderActionId\(\)' -or
    $aoeThunderActionText -notmatch 'LevelAtLeast\(100\)' -or
    $aoeThunderActionText -notmatch 'BLMHelper\.EN\.Skills\.HighThunderII' -or
    $aoeThunderActionText -notmatch 'HelperRuntime\.GetActionChange\(BLMHelper\.EN\.Skills\.ThunderII\)') {
    $failures.Add("BLM AoE Thunder must use High Thunder II at 100 and Helper action-change fallback below 100")
}

foreach ($pattern in @(
    'BLMHelper\.EN\.Buffs\.HighThunderII',
    'BLMHelper\.EN\.Buffs\.ThunderIV',
    'BLMHelper\.EN\.Buffs\.ThunderIII'
)) {
    if ($aoeThunderDotText -notmatch $pattern) {
        $failures.Add("BLM AoE Thunder DoT tracking must include level 70/80/90 and 100 thunder statuses: $pattern")
    }
}

foreach ($pattern in @(
    'ShouldUseHighEndAoeLoop\(\)',
    'GetHighEndAoeGcd\(\)',
    'GetLegacyAoeGcd\(\)'
)) {
    if ($aoeText -notmatch $pattern) {
        $failures.Add("BLM AoE GCD router missing policy token: $pattern")
    }
}

if ($highEndAoeGateText -notmatch 'LevelAtLeast\(100\)' -or
    $highEndAoeGateText -match 'HighEndMode') {
    $failures.Add("BLM high-end AoE loop must be level-100 gated without old AEAssist HighEndMode QT")
}

foreach ($pattern in @(
    'GetAoeThunderGcd\(\)',
    'GetFlareStarGcd\(\)',
    'BestAoeTargetSpell\(BLMHelper\.EN\.Skills\.Flare\)',
    'BestAoeTargetSpell\(BLMHelper\.EN\.Skills\.Freeze\)',
    'GetAoeFillerGcd\(\)'
)) {
    if ($highEndAoeText -notmatch $pattern) {
        $failures.Add("BLM level-100 high-end AoE loop missing policy token: $pattern")
    }
}

if ($highEndAoeText -match 'GetAoeFireActionId\(\)|GetAoeBlizzardActionId\(\)|HighFireII|FireII|HighBlizzardII|BlizzardII') {
    $failures.Add("BLM level-100 high-end AoE loop must stay on Freeze/Flare/Flare Star and not the legacy Fire II/Blizzard II line")
}

foreach ($pattern in @(
    'GetPolyglotGcd\(true\)',
    'GetAoeThunderGcd\(\)',
    'GetAoeFireActionId\(\)',
    'GetAoeBlizzardActionId\(\)',
    'BLMHelper\.EN\.Skills\.Flare',
    'BLMHelper\.EN\.Skills\.Freeze'
)) {
    if ($legacyAoeText -notmatch $pattern) {
        $failures.Add("BLM legacy 70/80/90 AoE loop missing policy token: $pattern")
    }
}

foreach ($pattern in @(
    'GetAoeThunderGcd\(\)',
    'GetPolyglotGcd\(true\)',
    'GetUmbralParadoxGcd\(\)'
)) {
    if ($aoeFillerText -notmatch $pattern) {
        $failures.Add("BLM AoE filler must preserve thunder, Foul/Polyglot, and ice Paradox fallback: $pattern")
    }
}

if ($aoeFireActionText -notmatch 'HelperRuntime\.GetActionChange\(BLMHelper\.EN\.Skills\.FireII\)' -or
    $aoeBlizzardActionText -notmatch 'HelperRuntime\.GetActionChange\(BLMHelper\.EN\.Skills\.BlizzardII\)') {
    $failures.Add("BLM legacy AoE action helpers must use Helper action-change for 70/80/90 level profiles")
}

foreach ($pattern in @(
    'ShouldUseHighEndAoeLoop\(\)',
    'ShouldUseAoe\(\)',
    'IsAstralFireActive\(\)',
    'CurrentMp\(\)\s*<=\s*0',
    'GetAstralSoulStacks\(\)\s*<\s*MaxAstralSoulStacks',
    'IsUmbralIceActive\(\)',
    'GetUmbralHearts\(\)\s*>=\s*MaxElementalStacks',
    'CurrentMp\(\)\s*>=\s*AoeFireEntryMpThreshold'
)) {
    if ($aoeTransposeText -notmatch $pattern) {
        $failures.Add("BLM high-end AoE Transpose policy missing guard: $pattern")
    }
}

if ($bestAoeTargetSpellText -notmatch 'new\s+Spell\(actionId,\s*\(\)\s*=>\s*GetBestAoeTarget\(actionId\)\)' -or
    $bestAoeTargetText -notmatch 'TargetHelper\.GetMostCanTargetObjects\(actionId,\s*_settings\.AoeEnemyCount,\s*5f\)' -or
    $bestAoeTargetText -notmatch 'GetCurrentTarget\(\)!') {
    $failures.Add("BLM AoE target spells must use HiAuRo TargetHelper dynamic targets with current-target fallback")
}

if ($currentTargetText -notmatch 'global::HiAuRo\.Data\.Target\.Current' -or
    $currentTargetText -notmatch 'IBattleChara' -or
    $currentTargetText -notmatch 'CurrentHp\s*>\s*0' -or
    $currentTargetText -notmatch 'IsTargetable') {
    $failures.Add("BLM current-target helper must stay on HiAuRo Data.Target and filter dead/invalid targets")
}

if ($helperPath -and (Read-File $helperPath) -notmatch 'ShouldTransposeForAoeLoop\(\)') {
    $failures.Add("BLM Transpose resolver path must include the high-end AoE Transpose loop")
}

if ($manafontText -notmatch 'ShouldUseOpeningManafontBeforeDespair' -or $manafontText -notmatch 'ShouldClipManafontToContinueAstralFire') {
    $failures.Add("BLM Manafont policy must support the 5+7 opener tail and emergency fire continuation")
}

foreach ($pattern in @(
    'GetElapsedInTwoMinuteBurstCycle\(\)',
    'elapsed\s*<=\s*_settings\.BurstWindowTailMs',
    'elapsed\s*>=\s*120_000\s*-\s*_settings\.BurstWindowLeadMs'
)) {
    if ($burstWindowText -notmatch $pattern) {
        $failures.Add("BLM 120s burst window must use elapsed-in-cycle lead/tail semantics: $pattern")
    }
}

if ($burstWindowText -match 'GetTimeToNextTwoMinuteBurstAnchor\(\)[\s\S]*timeToAnchor\s*<=\s*_settings\.BurstWindowTailMs') {
    $failures.Add("BLM 120s burst window must not treat time-to-next-anchor <= tail as post-anchor tail")
}

foreach ($pattern in @(
    '_currentBattleTimeMs\s*-\s*_settings\.FirstBurstAnchorMs',
    '\(\(diff\s*%\s*120_000\)\s*\+\s*120_000\)\s*%\s*120_000'
)) {
    if ($burstElapsedText -notmatch $pattern) {
        $failures.Add("BLM burst elapsed helper must normalize the current 120s cycle: $pattern")
    }
}

foreach ($pattern in @(
    'var\s+elapsed\s*=\s*GetElapsedInTwoMinuteBurstCycle\(\)',
    'elapsed\s*<=\s*_settings\.BurstWindowTailMs'
)) {
    if ($burstAnchorText -notmatch $pattern) {
        $failures.Add("BLM burst anchor gate must release only at/after the current anchor tail: $pattern")
    }
}

if ($burstAnchorText -match 'GetTimeToNextTwoMinuteBurstAnchor\(\)\s*<=\s*_settings\.BurstWindowTailMs') {
    $failures.Add("BLM burst anchor gate must not release during the pre-anchor tail-sized interval")
}

foreach ($pattern in @(
    'var\s+elapsed\s*=\s*GetElapsedInTwoMinuteBurstCycle\(\)',
    'var\s+anchor\s*=\s*GetCurrentOrPreviousTwoMinuteBurstAnchor\(\)',
    'elapsed\s*>=\s*120_000\s*-\s*_settings\.BurstWindowLeadMs',
    'anchor\s*\+\s*120_000'
)) {
    if ($activeBurstAnchorText -notmatch $pattern) {
        $failures.Add("BLM active burst window anchor must use the next anchor during the pre-anchor lead: $pattern")
    }
}

foreach ($pattern in @(
    'GetActiveTwoMinuteBurstWindowAnchor\(\)',
    'anchor\s*-\s*_settings\.BurstWindowLeadMs',
    'anchor\s*\+\s*_settings\.BurstWindowTailMs',
    'lastUseMs\s*>=\s*windowStart',
    'lastUseMs\s*<=\s*windowEnd'
)) {
    if ($leyLinesDuplicateText -notmatch $pattern) {
        $failures.Add("BLM Ley Lines duplicate guard must use the configured 120s burst window boundaries: $pattern")
    }
}

if ($leyLinesDuplicateText -match 'Math\.Abs\(_currentBattleTimeMs\s*-\s*lastUseMs\)\s*<\s*90_000') {
    $failures.Add("BLM Ley Lines duplicate guard must not use a 90s approximation for 120s windows")
}

foreach ($pattern in @(
    'IsInTwoMinuteBurstWindow\(\)',
    'ShouldUseDumpResources\(\)',
    'ShouldDumpManafont\(\)',
    '!IsInTwoMinuteBurstWindow\(\)'
)) {
    if ($manafontHoldText -notmatch $pattern) {
        $failures.Add("BLM Manafont 120s hold policy missing guard: $pattern")
    }
}

if ($manafontPolicyText -notmatch 'ShouldUseOpeningManafontBeforeDespair\(\)' -or
    $manafontPolicyText -notmatch '!IsActionUsable\(BLMHelper\.EN\.Skills\.Manafont\)[\s\S]*return false;' -or
    $manafontPolicyText -notmatch 'ShouldHoldManafontForBurstWindow\(\)' -or
    $manafontPolicyText -notmatch 'ShouldClipManafontToContinueAstralFire\(\)' -or
    $manafontPolicyText -notmatch 'CurrentMp\(\)\s*>\s*_settings\.ManafontMpThreshold' -or
    $manafontPolicyText -notmatch 'GetDespairGcd\(\)\s+is\s+not\s+null' -or
    $manafontPolicyText -notmatch 'if\s*\(shouldDumpManafont\)[\s\S]*return true;') {
    $failures.Add("BLM Manafont timing must preserve opener exception, 120s hold, MP threshold, Despair-first, and dump gates")
}

if ($manafontPolicyText.IndexOf('ShouldUseOpeningManafontBeforeDespair()') -gt
    $manafontPolicyText.IndexOf('ShouldHoldManafontForBurstWindow()')) {
    $failures.Add("BLM opener Manafont exception must run before the post-opener 120s hold")
}

if ($manafontPolicyText.IndexOf('!IsActionUsable(BLMHelper.EN.Skills.Manafont)') -gt
    $manafontPolicyText.IndexOf('ShouldHoldManafontForBurstWindow()')) {
    $failures.Add("BLM unavailable Manafont must not delay post-opener Astral Fire exit")
}

if ($manafontPolicyText.IndexOf('if (shouldDumpManafont)') -lt
    $manafontPolicyText.IndexOf('GetDespairGcd() is not null')) {
    $failures.Add("BLM DumpManafont must release only after the Despair-first guard")
}

foreach ($pattern in @(
    'ShouldHoldManafont\(\)',
    'IsActionUsable\(BLMHelper\.EN\.Skills\.Manafont\)',
    'ShouldUseManafontNow\(\)',
    'ReadySelfAbility\(BLMHelper\.EN\.Skills\.Manafont\)'
)) {
    if ($reserveManafontText -notmatch $pattern) {
        $failures.Add("BLM Manafont ice-transition reservation missing guard: $pattern")
    }
}

foreach ($method in @(
    @{ Name = "Swiftcast"; Text = $swiftIceText },
    @{ Name = "Triplecast"; Text = $tripleIceText }
)) {
    if ($method.Text -notmatch 'ShouldReserveManafontBeforeIceTransition\(\)[\s\S]*return false;') {
        $failures.Add("BLM $($method.Name) ice-transition tool must yield to a ready Manafont fire-tail extension")
    }
}

Assert-Contains $helperPath 'return\s+QTHelper\.IsEnabled\(BuiltinQt\.Hold\);' "BLM stop policy must use built-in Hold"
Assert-Contains $helperPath 'BLMHelper\.' "BLM helper must use HiAuRo.Helper BLM gauge accessors"
Assert-Contains $helperPath 'BLMHelper\.EN\.Skills\.' "BLM helper must use HiAuRo.Helper BLM skill IDs"
Assert-Contains $helperPath 'BLMHelper\.EN\.Buffs\.' "BLM helper must use HiAuRo.Helper BLM buff IDs"
Assert-Contains $helperPath 'Data\.Me\.Object.*CurrentMp' "BLM helper must read MP through HiAuRo Data.Me.Object"
Assert-Contains $helperPath 'Spell\.IsReadyWithCanCast\(\)' "BLM helper must use HiAuRo Spell readiness checks"
Assert-Contains $helperPath 'GetAoeGcd' "BLM helper must keep a high-end AoE branch for later high-difficulty multi-target use"
Assert-NotContains $helperPath 'KairoHiAuRoACR\.Jobs\.BlackMage\.Data|BlackMageActionId|BlackMageStatusId|BlackMageOpenerController|AEAssist|Core\.Resolve|JobViewWindow|UseActionManager|Kairo\.BlackMage|TimelineController|BlackMageTimeline' "BLM HiAuRo port must not leak local ID catalogs, old AEAssist APIs, Kairo-side opener bridges, or old timeline runtime"
Assert-Contains "Jobs/BlackMage/docs/DEVELOPMENT.md" 'HiAuRo\.Helper' "BLM job-owned docs must record the Helper ID source"
Assert-Contains "Jobs/BlackMage/docs/DEVELOPMENT.md" '不迁移时间轴|不要迁移时间轴|时间轴变量' "BLM job-owned docs must record the timeline boundary"
Assert-Contains "Jobs/BlackMage/docs/DEVELOPMENT.md" '70/80/90/100|70.*80.*90.*100' "BLM job-owned docs must record the supported high-difficulty level profiles"

if ($failures.Count -gt 0) {
    Write-Host "Black Mage port validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Black Mage port validation passed."
