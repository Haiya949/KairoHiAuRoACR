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

$requiredFiles = @(
    "NuGet.Config",
    "scripts/build.ps1",
    "Jobs/Machinist/Data/MachinistActionId.cs",
    "Jobs/Machinist/Data/MachinistStatusId.cs",
    "Jobs/Machinist/QTKey.cs",
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

Assert-Contains "Jobs/Machinist/MachinistRotationEntry.cs" "EventHandler\s*=\s*new\s+MachinistRotationEventHandler" "Rotation must register the MCH event handler"
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

Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" "AddBuiltinQt\(BuiltinQt\.Burst,\s*true\)" "MCH UI must expose Burst"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" "AddBuiltinQt\(BuiltinQt\.Hold,\s*false\)" "MCH UI must expose Hold"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" "RegisterControls\(IAcrUiBuilder\s+builder\)" "MCH UI must implement the current IRotationUI builder signature"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" "AddTab\(""[^""]*\p{IsCJKUnifiedIdeographs}[^""]*""\)" "MCH UI tab must use a Chinese in-game label with the current AddTab signature"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" "AddTab\(""MCH""\)" "MCH UI tab must not expose an English-only job label"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" "AddTab\(""mch"",\s*""MCH""\)" "MCH UI tab must not use the old two-argument SDK AddTab signature"
Assert-InOrder "Jobs/Machinist/MachinistRotationUi.cs" @(
    "QTKey.DumpResources",
    "QTKey.ForceBurst",
    "QTKey.ForbidBurst",
    "QTKey.Aoe"
) "MCH UI must expose only combat-time continuous QT toggles"
Assert-NotContains "Jobs/Machinist/QTKey.cs" "public const string Stop" "MCH must use the built-in Hold QT for the visible Stop toggle"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" "QTKey\.Stop" "MCH UI must not duplicate the built-in Hold/Stop QT"
Assert-Contains "Jobs/Machinist/QTKey.cs" "public const string DumpResources = ""[^""]*\p{IsCJKUnifiedIdeographs}[^""]*"";" "MCH DumpResources QT must use a short Chinese visible label"
Assert-Contains "Jobs/Machinist/QTKey.cs" "public const string ForceBurst = ""[^""]*\p{IsCJKUnifiedIdeographs}[^""]*"";" "MCH ForceBurst QT must use a short Chinese visible label"
Assert-Contains "Jobs/Machinist/QTKey.cs" "public const string ForbidBurst = ""[^""]*\p{IsCJKUnifiedIdeographs}[^""]*"";" "MCH ForbidBurst QT must use a short Chinese visible label"
Assert-Contains "Jobs/Machinist/QTKey.cs" "public const string Aoe = ""AOE"";" "MCH AOE QT must use a short visible label"
Assert-NotContains "Jobs/Machinist/QTKey.cs" "HighEndMode|MCH_|机工 " "Low-frequency mode selection must not be a QT and QT labels must not carry job prefixes"
Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "public\s+string\s+CombatMode\s*=\s*CombatModeDaily;" "MCH combat mode must be a persistent setting"
Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "public\s+string\s+TargetSelection\s*=\s*TargetSelectionManual;" "MCH target selection must be a persistent setting"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" "AddDropdown\(""[^""]*\p{IsCJKUnifiedIdeographs}[^""]*"",\s*MachinistSettings\.CombatModeOptions,\s*ref\s+_settings\.CombatMode" "MCH combat mode must be configured in the main settings UI"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" "AddDropdown\(""[^""]*\p{IsCJKUnifiedIdeographs}[^""]*"",\s*MachinistSettings\.TargetSelectionOptions,\s*ref\s+_settings\.TargetSelection" "MCH target selection must be configured in the main settings UI"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" "QTKey\.HighEndMode|机工 " "Low-frequency mode selection must not appear as a QT"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "return\s+QTHelper\.IsEnabled\(BuiltinQt\.Hold\);" "Stop policy must use the built-in Hold QT"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" "AddQtHotkey\(""[^""]*\p{IsCJKUnifiedIdeographs}[^""]*"",\s*new\s+HotkeyResolver_Potion" "Potion must remain a Chinese-labeled hotkey, not a QT toggle"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" "AddQtHotkey\(""[^""]*\p{IsCJKUnifiedIdeographs}[^""]*"",\s*new\s+HotkeyResolver_LB" "Limit Break must remain a Chinese-labeled hotkey"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" "Stop all MCH actions|Spend resources immediately|Treat the current window as burst|Hold burst resources|Use two-minute burst planning|Enable AOE GCD choices|AddQtHotkey\(""(Potion|Sprint|Limit Break|Tactician|Dismantle|Second Wind|Arm's Length|Head Graze|Leg Graze|Foot Graze)""" "MCH in-game UI labels and tooltips must be Chinese"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" "QTKey\.(UsePotion|RangedSafety|CastLog|PrepullReassemble)" "MCH UI must not expose unimplemented QT toggles"
Assert-NotContains "Jobs/Machinist/QTKey.cs" "(UsePotion|RangedSafety|CastLog|PrepullReassemble)" "MCH QT catalog must not keep unimplemented keys"
Assert-NotContains "Jobs/Machinist/MachinistSettings.cs" "(PrepullReassemble|CountdownPullActionQueue)" "MCH settings must not keep unused prepull controls"
Assert-Contains "docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md" "visible UI labels.*Chinese" "Kairo author guide compliance must document Chinese visible UI labels"

Assert-Contains "Jobs/Machinist/Data/MachinistActionId.cs" "public const uint FullMetalField = 36982;" "MCH action catalog must include Dawntrail actions"
Assert-Contains "Jobs/Machinist/Data/MachinistStatusId.cs" "public const ushort Overheated = 2688;" "MCH status catalog must include Overheated"
Assert-Contains "Jobs/Machinist/Data/MachinistStatusId.cs" "public const ushort Hypercharged = 3864;" "MCH status catalog must include Hypercharged"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "GetAoeGcd" "MCH helper must expose AOE GCD policy"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "GetOverheatedGcd" "MCH helper must expose overheated GCD policy"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "GetStrongGcd" "MCH helper must expose strong GCD policy"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "GetBaseComboGcd" "MCH helper must expose combo filler policy"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "GetWildfireOffGcd" "MCH helper must expose Wildfire policy"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "GetHyperchargeOffGcd" "MCH helper must expose Hypercharge policy"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "HelperRuntime\.HasStatus\(MachinistStatusId\.Overheated\)" "MCH helper must not rely on stale Helper MCH Hypercharge status constants"
Assert-NotContains "Jobs/Machinist/MachinistSettings.cs" "LongFightBurstPlanMs" "MCH settings must not keep hidden long-fight burst planning"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "_settings\.IsHighEndMode" "Two-minute burst planning must use the persistent combat mode setting"
Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "LongFightBurstPlanMs|_currentBattleTimeMs\s*>=\s*_settings\.LongFightBurstPlanMs|QTKey\.HighEndMode" "Two-minute burst planning must not use hidden timers or low-frequency QT"
Assert-Contains "Jobs/Machinist/MachinistRotationEntry.cs" "TargetResolvers\s*=\s*\[new\s+MachinistTargetResolver\(Settings\)\]" "Rotation must wire a settings-backed target resolver"
Assert-File "Jobs/Machinist/MachinistTargetResolver.cs"
Assert-Contains "Jobs/Machinist/MachinistTargetResolver.cs" "TargetSelectionNearestEnemy" "MCH target selection must support nearest enemy mode"
Assert-Contains "Jobs/Machinist/MachinistTargetResolver.cs" "TargetResolver_" "MCH nearest enemy mode must use HiAuRo's built-in target resolver"
Assert-Contains "Jobs/Machinist/MachinistTargetResolver.cs" "ResolveTarget\(out\s+agent\)" "MCH target resolver must delegate to the selected resolver at runtime"
Assert-NotContains "Jobs/Machinist/MachinistRotationEntry.cs" "BuildTargetResolvers" "Target selection must not be frozen at Rotation Build time"
Assert-Contains "docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md" "CombatContext\.State\.InCombat" "Docs must state that normal ACR loop starts only after InCombat"
Assert-Contains "docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md" "IOpener" "Docs must state that countdown pull actions belong to Opener"
Assert-InOrder "Jobs/Machinist/MachinistSpellHelper.cs" @(
    "public static Spell? GetHyperchargeOffGcd()",
    "if (GetHeat() < 50 || !hypercharge.IsReadyWithCanCast())",
    "if (IsForbidBurstActive())",
    "var shouldUseActiveWildfireHypercharge = HasActiveWildfirePackage();",
    "var shouldSpendHeatForBudget = ShouldSpendHeatByBudget();"
) "Hypercharge budget and dump paths must respect ForbidBurst first"
Assert-InOrder "Jobs/Machinist/MachinistSpellHelper.cs" @(
    "public static Spell? GetQueenOffGcd()",
    "if (IsForbidBurstActive())",
    "var shouldSpendBatteryForOvercap"
) "Battery overcap paths must respect ForbidBurst first"
Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "LevelAtLeast\(80\)\s*\?\s*MachinistActionId\.QueenOverdrive\s*:\s*MachinistActionId\.RookOverdrive" "MCH robot overdrive must choose RookOverdrive below level 80"

if ($failures.Count -gt 0) {
    Write-Host "Machinist port validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist port validation passed."
