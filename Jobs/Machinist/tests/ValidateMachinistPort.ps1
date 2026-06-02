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

function Assert-NoLiteralConstAssignments {
    param(
        [string]$Path,
        [string]$Message
    )

    $text = Read-File $Path
    if ($text -match 'public const (?:uint|ushort) [A-Za-z][A-Za-z0-9_]* = \d+;') {
        $failures.Add("$Message ($Path)")
    }
}

$requiredFiles = @(
    "NuGet.Config",
    "scripts/build.ps1",
    "Jobs/Machinist/QTKey.cs",
    "Jobs/Machinist/Opener/MachinistOpener.cs",
    "Jobs/Machinist/MachinistSpellHelper.cs",
    "Jobs/Machinist/MachinistRotationEventHandler.cs",
    "Jobs/Machinist/Resolvers/GCD/MachinistAoeGcdResolver.cs",
    "Jobs/Machinist/Resolvers/GCD/MachinistOverheatedGcdResolver.cs",
    "Jobs/Machinist/Resolvers/GCD/MachinistStrongGcdResolver.cs",
    "Jobs/Machinist/Resolvers/GCD/MachinistBaseGcdResolver.cs",
    "Jobs/Machinist/Resolvers/OffGCD/MachinistQueenOverdriveResolver.cs",
    "Jobs/Machinist/Resolvers/OffGCD/MachinistWildfireResolver.cs",
    "Jobs/Machinist/Resolvers/OffGCD/MachinistBarrelStabilizerResolver.cs",
    "Jobs/Machinist/Resolvers/OffGCD/MachinistHyperchargeResolver.cs",
    "Jobs/Machinist/Resolvers/OffGCD/MachinistQueenResolver.cs",
    "Jobs/Machinist/Resolvers/OffGCD/MachinistReassembleResolver.cs",
    "Jobs/Machinist/Resolvers/OffGCD/MachinistGaussRoundResolver.cs"
)

foreach ($file in $requiredFiles) {
    Assert-File $file
}

Assert-Contains "NuGet.Config" "E:\\ff14\\HiAuRo\\local-nuget-feed\\" "Kairo ACR must restore HiAuRo.Sdk from the local runtime feed first"
Assert-Contains "KairoHiAuRoACR.csproj" "PackageReference\s+Include=""HiAuRo\.Sdk""\s+Version=""0\.1\.\*""" "Kairo ACR must track the local HiAuRo.Sdk 0.1.* package"
Assert-Contains "scripts/build.ps1" '\$LASTEXITCODE' "Build script must stop when dotnet build fails instead of deploying stale output"
Assert-NotContains "GlobalUsings.cs" "global\s+using\s+IUiBuilder" "Global usings must not keep the old IUiBuilder alias for ACR UI"
Assert-Contains "Helper/HiAuRo.Helper/MCHHelper.cs" "Flamethrower\s*=\s*1205" "Helper must expose MCH Flamethrower status ID"
Assert-Contains "Helper/HiAuRo.Helper/MCHHelper.cs" "WildfireOnTarget\s*=\s*861" "Helper must expose the target Wildfire status ID separately from the existing self Wildfire status"
Assert-Contains "Helper/HiAuRo.Helper/MCHHelper.cs" "ArmPunch\s*=\s*16504" "Helper must expose MCH Arm Punch ID"
Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "MachinistActionId|MachinistStatusId|KairoHiAuRoACR\.Jobs\.Machinist\.Data" "MCH SpellHelper must use Helper IDs directly instead of local ID catalogs"
Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" "MachinistActionId|KairoHiAuRoACR\.Jobs\.Machinist\.Data" "MCH opener must use Helper IDs directly instead of local ID catalogs"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" "MachinistActionId|KairoHiAuRoACR\.Jobs\.Machinist\.Data" "MCH UI hotkeys must use Helper IDs directly instead of local ID catalogs"
Assert-NotContains "KairoHiAuRoACR.csproj" "Jobs\\Machinist\\Data\\Machinist(?:Action|Status)Id\.cs" "MCH local ID catalog files must not be explicitly compiled"

Assert-Contains "Jobs/Machinist/MachinistRotationEntry.cs" "EventHandler\s*=\s*new\s+MachinistRotationEventHandler" "Rotation must register the MCH event handler"
Assert-Contains "Jobs/Machinist/MachinistRotationEntry.cs" "Opener\s*=\s*new\s+MachinistOpener\(\)" "Rotation must register the HiAuRo-native MCH opener"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "class\s+MachinistOpener\s*:\s*IOpener" "MCH opener must implement HiAuRo IOpener"
Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" "AEAssist|Kairo\.Machinist|UseActionManager|UseAction\(" "MCH opener must use only HiAuRo-native Slot/Spell APIs"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "InitCountDown\(CountDownHandler\s+handler\)" "MCH opener must register countdown actions through HiAuRo CountDownHandler"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "handler\.AddAction\(4_000,\s*\(\)\s*=>" "MCH opener must register prepull Reassemble through CountDownHandler; Runtime CountDownHandler.Update writes it to BattleData.NextSlot through AddSpell2NextSlot"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "new\s+Spell\(ActionId\.Reassemble,\s*SpellTargetType\.Self\)" "MCH opener must create the approved 4000ms prepull Reassemble spell through CountDownHandler"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "Type\s*=\s*SpellType\.Ability" "MCH prepull Reassemble must be marked as an ability for Runtime event history"
Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" "handler\.AddAction\([^,]+,\s*ActionId\.Drill" "MCH opener must not cast Drill during countdown; the opener GCD resolver starts Drill after countdown/combat begins"
Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" "handler\.AddAction\(0," "MCH opener must not move pull GCDs into countdown actions; Runtime CountDownHandler owns countdown NextSlot actions and OpenerMgr starts the opener sequence"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "public\s+List<Action<Slot>>\s+Sequence\s*=>\s*_activeSequence\s*\?\?=\s*BuildSequence\(\)" "MCH Runtime IOpener must own one executable opener sequence snapshot while OpenerMgr pushes it into BattleData.CurrSequence"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "private static readonly \(Func<bool> IsAvailable, Action<Slot> Build\)\[\] StandardOpenerSteps" "MCH opener must keep executable opener steps in a native Sequence builder"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "private static List<Action<Slot>> BuildSequence\(\)" "MCH opener must build its Runtime Sequence before indexed execution starts"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "StartCheck\(\)" "MCH opener must be startable by Runtime when countdown ends or combat starts"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "_activeSequence\s*=\s*BuildSequence\(\)" "MCH opener must snapshot Sequence in StartCheck before OpenerMgr starts indexed execution"
Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" "StartCheck\(\)\s*=>\s*-1" "MCH opener must not be disabled after Runtime countdown handling is fixed"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "StopCheck\(int\s+index\)\s*=>\s*-1" "MCH opener should not be interrupted by normal rotation once Runtime starts it"
Assert-InOrder "Jobs/Machinist/Opener/MachinistOpener.cs" @(
    "ActionId.Drill",
    "ActionId.AirAnchor",
    "ActionId.ChainSaw",
    "ActionId.Excavator",
    "ActionId.Drill",
    "ActionId.FullMetalField"
) "MCH opener GCD order must follow the old Kairo standard opener"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "BuildFirstDrillSlot" "MCH opener must build the first Drill slot"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "BuildAirAnchorSlot" "MCH opener must build the Air Anchor slot"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "BuildChainSawSlot" "MCH opener must build the Chain Saw slot"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "BuildExcavatorSlot" "MCH opener must build the Excavator slot"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "BuildSecondDrillSlot" "MCH opener must build the second Drill slot"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "BuildFullMetalFieldSlot" "MCH opener must build the Full Metal Field slot"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.Checkmate" "MCH opener must weave Checkmate in the fixed opener"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.DoubleCheck" "MCH opener must weave Double Check in the fixed opener"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.BarrelStabilizer" "MCH opener must weave Barrel Stabilizer after Air Anchor"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.AutomatonQueen" "MCH opener must weave Queen after Excavator"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.Reassemble" "MCH opener must weave the second Reassemble before second Drill"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.Wildfire" "MCH opener must weave Wildfire after second Drill"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.Hypercharge" "MCH opener must weave Hypercharge after Full Metal Field"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "SpellType\.Ability" "MCH opener oGCD spells must be marked as Ability for SlotExecutor"
Assert-Contains "Jobs/Machinist/docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md" "4s prepull Reassemble" "Docs must record the HiAuRo-only 4s prepull Reassemble decision"
Assert-InOrder "Jobs/Machinist/MachinistRotationEntry.cs" @(
    "MachinistQueenOverdriveResolver",
    "MachinistWildfireResolver",
    "MachinistBarrelStabilizerResolver",
    "MachinistHyperchargeResolver",
    "MachinistQueenResolver",
    "MachinistReassembleResolver",
    "MachinistGaussRoundResolver",
    "MachinistAoeGcdResolver",
    "MachinistOverheatedGcdResolver",
    "MachinistStrongGcdResolver",
    "MachinistBaseGcdResolver"
) "Resolver priority must follow the old Kairo MCH baseline translated to HiAuRo SlotResolvers"
Assert-FileNotExists "Jobs/Machinist/Opener/MachinistOpenerController.cs" "MCH must not keep the temporary opener controller after migrating to native IOpener.Sequence"
Assert-FileNotExists "Jobs/Machinist/Resolvers/GCD/MachinistOpenerGcdResolver.cs" "MCH must not keep the temporary opener GCD resolver after migrating to native IOpener.Sequence"
Assert-FileNotExists "Jobs/Machinist/Resolvers/OffGCD/MachinistOpenerOffGcdResolver.cs" "MCH must not keep the temporary opener oGCD resolver after migrating to native IOpener.Sequence"
Assert-NotContains "Jobs/Machinist/MachinistRotationEntry.cs" "MachinistOpenerController|MachinistOpenerGcdResolver|MachinistOpenerOffGcdResolver|OpenerPolling|TryQueueCountdownActions|OnOpenerTick|RegisterCountdownActions|RestoreRuntimeResetState|ACRLifecycle\.Runner\.CurrentRotation\?\.Opener\?\.InitCountDown|EventSystem" "Rotation entry must not keep ACR-side opener bridges after Runtime owns countdown/opener handling"
Assert-NotContains "Jobs/Machinist/MachinistRotationEventHandler.cs" "restoreRuntimeResetState|RegisterCountdownActions|RestartTargetSelectionPolling" "MCH reset handler must not restore Runtime internals from ACR code"
Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "MachinistOpenerController" "MCH SpellHelper must not depend on the removed temporary opener controller"
Assert-Contains "Jobs/Machinist/MachinistRotationEventHandler.cs" "Slot\?\s+BeforeSpell\(Slot\s+slot\)" "MCH event handler must implement the current HiAuRo v0.1.79 BeforeSpell signature"
Assert-NotContains "Jobs/Machinist/MachinistRotationEventHandler.cs" "void\s+BeforeSpell\(Slot\s+slot,\s*Spell\s+spell\)" "MCH event handler must not keep the old BeforeSpell signature that prevents ACR reflection loading"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "_lastRecordedActionId" "MCH action tracking must dedupe SlotExecutor and EventSystem records for the same successful action"

Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" "AddBuiltinQt\(BuiltinQt\.Burst,\s*true\)" "MCH UI must expose Burst"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" "AddBuiltinQt\(BuiltinQt\.Hold,\s*false\)" "MCH UI must expose Hold"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" "RegisterControls\(IAcrUiBuilder\s+builder\)" "MCH UI must implement the current IRotationUI builder signature"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" 'AddTab\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*"\)' "MCH UI tab must use a Chinese in-game label with the current AddTab signature"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" 'AddTab\("MCH"\)' "MCH UI tab must not expose an English-only job label"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" 'AddTab\("mch",\s*"MCH"\)' "MCH UI tab must not use the old two-argument SDK AddTab signature"
Assert-InOrder "Jobs/Machinist/MachinistRotationUi.cs" @(
    "QTKey.DumpResources",
    "QTKey.ForceBurst",
    "QTKey.ForbidBurst",
    "QTKey.Aoe"
) "MCH UI must expose only combat-time continuous QT toggles"
Assert-NotContains "Jobs/Machinist/QTKey.cs" "public const string Stop" "MCH must use the built-in Hold QT for the visible Stop toggle"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" "QTKey\.Stop" "MCH UI must not duplicate the built-in Hold/Stop QT"
Assert-Contains "Jobs/Machinist/QTKey.cs" 'public const string DumpResources = "[^"]*\p{IsCJKUnifiedIdeographs}[^"]*";' "MCH DumpResources QT must use a short Chinese visible label"
Assert-Contains "Jobs/Machinist/QTKey.cs" 'public const string ForceBurst = "[^"]*\p{IsCJKUnifiedIdeographs}[^"]*";' "MCH ForceBurst QT must use a short Chinese visible label"
Assert-Contains "Jobs/Machinist/QTKey.cs" 'public const string ForbidBurst = "[^"]*\p{IsCJKUnifiedIdeographs}[^"]*";' "MCH ForbidBurst QT must use a short Chinese visible label"
Assert-Contains "Jobs/Machinist/QTKey.cs" 'public const string Aoe = "AOE";' "MCH AOE QT must use a short visible label"
Assert-NotContains "Jobs/Machinist/QTKey.cs" "HighEndMode|MCH_|机工 " "Low-frequency mode selection must not be a QT and QT labels must not carry job prefixes"
Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "public\s+string\s+CombatMode\s*=\s*CombatModeDaily;" "MCH combat mode must be a persistent setting"
Assert-NotContains "Jobs/Machinist/MachinistSettings.cs" "TargetSelectionManual|TargetSelectionNearestEnemy|TargetSelectionOptions|public\s+string\s+TargetSelection" "MCH target selection must not remain an ACR persistent setting after Runtime owns target selection"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" 'AddDropdown\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*",\s*MachinistSettings\.CombatModeOptions,\s*ref\s+_settings\.CombatMode' "MCH combat mode must be configured in the main settings UI"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" "TargetSelectionOptions|_settings\.TargetSelection|目标选择|手动目标|最近敌人" "MCH UI must not expose target selection controls after Runtime owns target selection"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" "GetRuntimeDebugLines|CountDownHandler|LastCountdownSec|LastProviderSource|LastTriggerDebug|LastUseActionDebug|CombatContext\.CurrentState|Data\.Combat\.InCombat|OpenerMgr|MachinistOpenerController\.GetDebugText|Countdown\.CountdownTimer|GetCountdownDebugText|GetIpcSubscriber|DService|\.PI" "MCH UI must not keep temporary Runtime countdown/opener debug diagnostics"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" "QTKey\.HighEndMode|机工 " "Low-frequency mode selection must not appear as a QT"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "return\s+QTHelper\.IsEnabled\(BuiltinQt\.Hold\);" "Stop policy must use the built-in Hold QT"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" 'AddQtHotkey\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*",\s*new\s+HotkeyResolver_Potion' "Potion must remain a Chinese-labeled hotkey, not a QT toggle"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" 'AddQtHotkey\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*",\s*new\s+HotkeyResolver_LB' "Limit Break must remain a Chinese-labeled hotkey"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" 'Stop all MCH actions|Spend resources immediately|Treat the current window as burst|Hold burst resources|Use two-minute burst planning|Enable AOE GCD choices|AddQtHotkey\("(Potion|Sprint|Limit Break|Tactician|Dismantle|Second Wind|Arm''s Length|Head Graze|Leg Graze|Foot Graze)"' "MCH in-game UI labels and tooltips must be Chinese"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" "QTKey\.(UsePotion|RangedSafety|CastLog|PrepullReassemble)" "MCH UI must not expose unimplemented QT toggles"
Assert-NotContains "Jobs/Machinist/QTKey.cs" "(UsePotion|RangedSafety|CastLog|PrepullReassemble)" "MCH QT catalog must not keep unimplemented keys"
Assert-NotContains "Jobs/Machinist/MachinistSettings.cs" "PrepullReassembleCountdownMs|CountdownPullActionQueueLeadMs" "MCH settings must not keep countdown bridge settings after returning to documented IOpener countdown handling"
Assert-Contains "Jobs/Machinist/docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md" "visible UI labels.*Chinese" "Kairo author guide compliance must document Chinese visible UI labels"

Assert-Contains "Helper/HiAuRo.Helper/MCHHelper.cs" "FullMetalField\s*=\s*36982" "Helper MCH action catalog must include Dawntrail actions"
Assert-Contains "Helper/HiAuRo.Helper/MCHHelper.cs" "Overheated\s*=\s*2688" "Helper MCH status catalog must include Overheated"
Assert-Contains "Helper/HiAuRo.Helper/MCHHelper.cs" "Hypercharged\s*=\s*3864" "Helper MCH status catalog must include Hypercharged"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "GetAoeGcd" "MCH helper must expose AOE GCD policy"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "GetOverheatedGcd" "MCH helper must expose overheated GCD policy"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "GetStrongGcd" "MCH helper must expose strong GCD policy"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "GetBaseComboGcd" "MCH helper must expose combo filler policy"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "GetWildfireOffGcd" "MCH helper must expose Wildfire policy"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "GetHyperchargeOffGcd" "MCH helper must expose Hypercharge policy"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "HelperRuntime\.HasStatus\(StatusId\.Overheated\)" "MCH helper must use Helper MCH status constants"
Assert-NotContains "Jobs/Machinist/MachinistSettings.cs" "LongFightBurstPlanMs" "MCH settings must not keep hidden long-fight burst planning"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "_settings\.IsHighEndMode" "Two-minute burst planning must use the persistent combat mode setting"
Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "LongFightBurstPlanMs|_currentBattleTimeMs\s*>=\s*_settings\.LongFightBurstPlanMs|QTKey\.HighEndMode" "Two-minute burst planning must not use hidden timers or low-frequency QT"
Assert-Contains "Jobs/Machinist/MachinistRotationEntry.cs" "var\s+targetResolver\s*=\s*new\s+MachinistTargetResolver\(\)" "Rotation must create one Runtime-owned target resolver without ACR UI settings"
Assert-Contains "Jobs/Machinist/MachinistRotationEntry.cs" "EventHandler\s*=\s*new\s+MachinistRotationEventHandler\(\)" "Rotation event handler must not receive temporary target/countdown recovery hooks"
Assert-Contains "Jobs/Machinist/MachinistRotationEntry.cs" "TargetResolvers\s*=\s*\[targetResolver\]" "Rotation must wire the Runtime-owned target resolver"
Assert-File "Jobs/Machinist/MachinistTargetResolver.cs"
Assert-Contains "Jobs/Machinist/MachinistTargetResolver.cs" "TargetResolver_" "MCH nearest enemy mode must use HiAuRo's built-in target resolver"
Assert-Contains "Jobs/Machinist/MachinistTargetResolver.cs" "ResolveTarget\(out\s+agent\)" "MCH target resolver must delegate to HiAuRo's built-in resolver at runtime"
Assert-NotContains "Jobs/Machinist/MachinistTargetResolver.cs" "MachinistSettings|TargetSelection" "MCH target resolver must not depend on ACR target-selection settings"
Assert-NotContains "Jobs/Machinist/MachinistTargetResolver.cs" "TrySelectTarget\(\)|global::HiAuRo\.Data\.Objects\.Refresh\(\)|OmenTools\.OmenService\.TargetManager\.Target" "MCH target resolver must not self-assign targets outside Runtime TargetResolvers"
Assert-NotContains "Jobs/Machinist/MachinistRotationEntry.cs" "_targetResolver|TargetSelectionRetryMs|TargetSelectionPolling|OnTargetSelectionTick|Coroutine\.Instance\.WaitAsync|TrySelectTarget\(\)" "Rotation entry must not keep ACR-side target polling or immediate target assignment"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" 'TrySelectTarget\(\)' "MCH UI must not trigger target selection; Runtime TargetResolvers handle selection"
Assert-NotContains "Jobs/Machinist/MachinistRotationEventHandler.cs" "MachinistTargetResolver|TrySelectTarget\(\)" "MCH event handler must not run ACR-side target selection hooks"
Assert-NotContains "Jobs/Machinist/MachinistRotationEntry.cs" "BuildTargetResolvers" "Target selection must not be frozen at Rotation Build time"
Assert-Contains "Jobs/Machinist/docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md" "CombatContext\.State\.InCombat" "Docs must state that normal ACR loop starts only after InCombat"
Assert-Contains "Jobs/Machinist/docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md" "IOpener" "Docs must state that countdown pull actions belong to Opener"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "ACRLifecycle\.Update\(\): Refresh -> UpdateCountDown -> AiLoop\.Update\(runner\)" "Docs must describe the current CalSlot/AiLoop.Update runtime chain"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "BattleData\.AddSpell2NextSlot\(spell\).*BattleData\.NextSlot" "Docs must state countdown spells enter BattleData.NextSlot through AddSpell2NextSlot"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "OpenerMgr\.UseOpener\(battleData, rotation\).*BattleData\.CurrSequence" "Docs must state OpenerMgr pushes opener Sequence into BattleData.CurrSequence"
Assert-Contains "Jobs/Machinist/docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md" "production opener logic" "Docs must distinguish production countdown handling from read-only debug display"
Assert-NotContains "Jobs/Machinist/docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md" 'ACR 面板可以只读显示|read-only display .*Countdown\.CountdownTimer|Countdown\.CountdownTimer.*CountDownHandler' "Docs must not permit ACR UI to read countdown IPC directly"
Assert-InOrder "Jobs/Machinist/MachinistSpellHelper.cs" @(
    "public static Spell? GetHyperchargeOffGcd()",
    "var hasHyperchargedReady = HelperRuntime.HasStatus(StatusId.Hypercharged);",
    "if (!hasHyperchargedReady && GetHeat() < 50)",
    "if (!hypercharge.IsReadyWithCanCast())",
    "if (IsForbidBurstActive())",
    "var shouldUseActiveWildfireHypercharge = HasActiveWildfirePackage();",
    "var shouldSpendHeatForBudget = ShouldSpendHeatByBudget();"
) "Hypercharge budget and dump paths must respect ForbidBurst first"
Assert-InOrder "Jobs/Machinist/MachinistSpellHelper.cs" @(
    "public static Spell? GetQueenOffGcd()",
    "if (IsForbidBurstActive())",
    "var shouldSpendBatteryBySelectedStrategy"
) "Battery budget paths must respect ForbidBurst first"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "LevelAtLeast\(80\)\s*\?\s*ActionId\.QueenOverdrive\s*:\s*ActionId\.RookOverdrive" "MCH robot overdrive must choose RookOverdrive below level 80"

if ($failures.Count -gt 0) {
    Write-Host "Machinist port validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist port validation passed."

