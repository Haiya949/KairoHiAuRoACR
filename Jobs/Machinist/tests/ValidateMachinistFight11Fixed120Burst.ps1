param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
)

$ErrorActionPreference = "Stop"
$failures = New-Object System.Collections.Generic.List[string]

function Read-File {
    param([string]$Path)

    $fullPath = Join-Path $Root $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $failures.Add("Missing file: $Path")
        return ""
    }

    return Get-Content -LiteralPath $fullPath -Raw -Encoding utf8
}

function Get-Body {
    param(
        [string]$Text,
        [string]$SignaturePattern,
        [string]$Message
    )

    $match = [regex]::Match(
        $Text,
        "$SignaturePattern\s*\{(?<body>.*?)\n    \}",
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        $failures.Add("Could not find body: $Message")
        return ""
    }

    return $match.Groups["body"].Value
}

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        $failures.Add("$Message missing pattern: $Pattern")
    }
}

function Assert-NotContains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -match $Pattern) {
        $failures.Add("$Message unexpected pattern: $Pattern")
    }
}

function Assert-Order {
    param(
        [string]$Text,
        [string[]]$Tokens,
        [string]$Message
    )

    $position = -1
    foreach ($token in $Tokens) {
        $next = $Text.IndexOf($token, $position + 1, [StringComparison]::Ordinal)
        if ($next -lt 0) {
            $failures.Add("$Message; missing or out of order token: $token")
            return
        }

        $position = $next
    }
}

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"
$docs = Read-File "Jobs/Machinist/docs/DEVELOPMENT.md"

$trackBody = Get-Body $helper "private static void TrackBurstPackageAction\(uint actionId, int actionBattleTimeMs\)" "burst package tracker"
Assert-NotContains $trackBody "_firstPostOpenerBurstAnchorMs = _currentBattleTimeMs \+ MachinistBurstPlanner\.BurstCycleMs" "Fight 11: opener Wildfire must not shift the fixed 120s loop anchor"

$anchorBody = Get-Body $helper "private static int GetCurrentBurstAnchorMs\(\)" "current burst anchor"
Assert-Contains $anchorBody "_firstPostOpenerBurstAnchorMs \?\? _settings\.FirstBurstAnchorMs" "Delayed timeline release re-anchor must remain available"

$barrelBody = Get-Body $helper "public static Spell\? GetBarrelStabilizerOffGcd\(\)" "Barrel Stabilizer 120s policy"
Assert-Contains $barrelBody "ShouldUseFixed120BurstPackage\(\)" "Barrel Stabilizer must be allowed by the fixed 120s package"

$strongPriorityBody = Get-Body $helper "private static IReadOnlyList<uint> GetStrongGcdPriority\(\)" "fixed 120s strong GCD priority"
Assert-Contains $strongPriorityBody "Fixed120StrongGcdPriority" "Fixed 120s package must use the exact 120s strong-GCD order"
Assert-Order $helper @(
    "private static readonly uint[] Fixed120StrongGcdPriority",
    "ActionId.Drill",
    "ActionId.AirAnchor",
    "ActionId.ChainSaw",
    "ActionId.Excavator",
    "ActionId.FullMetalField"
) "Fixed 120s strong GCD priority must match the user-provided sequence"

$queenBody = Get-Body $helper "public static Spell\? GetQueenOffGcd\(\)" "Queen/Rook 120s policy"
Assert-Order $queenBody @(
    "var shouldSpendBatteryInFixed120Burst = ShouldSpendBatteryInFixed120Burst();",
    "if (ShouldHoldBatteryForFixed120Burst())",
    "if (ShouldUseDumpResources() || IsForceBurstActive() || shouldSpendBatteryInFixed120Burst || shouldSpendBatteryByBudget || CanUseBurstResource())"
) "Queen/Rook must be held before the 120s package and released after Drill before Chain Saw"

$wildfireDelayBody = Get-Body $helper "private static bool ShouldDelayWildfireUntilHyperchargeForBurstPackage\(\)" "Wildfire fixed 120s package guard"
Assert-Contains $wildfireDelayBody "ShouldUseFixed120BurstPackage\(\)" "Wildfire must not fire naked in the fixed 120s package before Full Metal Field and Hypercharge"

$wildfireGateBody = Get-Body $helper "private static bool CanUseWildfireBurstPackage\(\)" "Wildfire burst package gate"
Assert-Contains $wildfireGateBody "ShouldUseFixed120BurstPackage\(\)" "Wildfire gate must include the fixed 120s package"

$gcdHoldBody = Get-Body $helper "public static bool ShouldHoldGcdForWildfireBurstPackage\(\)" "Full Metal pre-GCD hold policy"
Assert-Contains $gcdHoldBody "ShouldUseFixed120BurstPackage\(\)[\s\S]*return false;" "Fixed 120s Full Metal Field must not wait for Wildfire cooldown"
Assert-Order $gcdHoldBody @(
    "ShouldUseFixed120BurstPackage()",
    "return false;",
    "wildfire.CooldownMs <= WildfirePreGcdClipWindowMs"
) "Fixed 120s no-hold guard must run before the generic pre-GCD Wildfire hold"

$gaussBody = Get-Body $helper "private static Spell\? PickGaussRoundOrRicochet\(\)" "Checkmate/Double Check 120s priority"
Assert-Contains $gaussBody "ShouldUseFixed120BurstPackage\(\)[\s\S]*return gaussRound;" "Fixed 120s package must prefer Double Check before Checkmate when both are ready"

Assert-Contains $docs "Fight 11" "Development docs must record the FFLogs fight 11 regression"
Assert-Contains $docs "fixed 120s.*Drill -> Queen/Rook -> Double Check / Checkmate -> Air Anchor -> Double Check / Checkmate -> Barrel Stabilizer -> Chain Saw -> Reassemble -> Excavator -> Double Check -> Checkmate -> Full Metal Field -> Hypercharge -> Wildfire" "Development docs must record the fixed 120s burst order"
Assert-Contains $docs "opener Wildfire.*must not shift.*120s" "Development docs must record that opener Wildfire does not shift the fixed 120s anchor"
Assert-Contains $docs "fixed 120s Full Metal Field must not wait for Wildfire cooldown" "Development docs must record the fight 11 Full Metal no-hold rule"

if ($failures.Count -gt 0) {
    Write-Host "Machinist fight 11 fixed-120 burst validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist fight 11 fixed-120 burst validation passed."
