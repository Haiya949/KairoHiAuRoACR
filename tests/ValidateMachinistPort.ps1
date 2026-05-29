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

    return Get-Content -LiteralPath $fullPath -Raw
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
Assert-InOrder "Jobs/Machinist/MachinistRotationUi.cs" @(
    "QTKey.Stop",
    "QTKey.DumpResources",
    "QTKey.ForceBurst",
    "QTKey.ForbidBurst",
    "QTKey.HighEndMode",
    "QTKey.Aoe"
) "MCH UI must expose only implemented continuous QT toggles"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" "AddQtHotkey\(""Potion"",\s*new\s+HotkeyResolver_Potion" "Potion must remain a hotkey, not a QT toggle"
Assert-NotContains "Jobs/Machinist/MachinistRotationUi.cs" "QTKey\.(UsePotion|RangedSafety|CastLog|PrepullReassemble)" "MCH UI must not expose unimplemented QT toggles"
Assert-NotContains "Jobs/Machinist/QTKey.cs" "(UsePotion|RangedSafety|CastLog|PrepullReassemble)" "MCH QT catalog must not keep unimplemented keys"
Assert-NotContains "Jobs/Machinist/MachinistSettings.cs" "(PrepullReassemble|CountdownPullActionQueue)" "MCH settings must not keep unused prepull controls"

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
Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "LongFightBurstPlanMs|_currentBattleTimeMs\s*>=\s*_settings\.LongFightBurstPlanMs" "HighEndMode must be the only two-minute burst planning switch"
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
