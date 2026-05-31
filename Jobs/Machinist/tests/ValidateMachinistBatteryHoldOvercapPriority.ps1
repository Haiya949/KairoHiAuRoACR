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
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    $text = Read-File $Path
    if ($text -notmatch $Pattern) {
        $failures.Add("$Message ($Path): $Pattern")
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
$queenBody = Get-Body $helper "public static Spell\? GetQueenOffGcd\(\)" "Queen battery hold/overcap policy"
$holdBody = Get-Body $helper "public static bool ShouldHoldBatteryForTimeline\(\)" "timeline battery hold policy"
$budgetBody = Get-Body $helper "private static bool ShouldSpendBatteryByBudget\(\)" "battery budget policy"

Assert-Order $queenBody @(
    "if (IsForbidBurstActive())",
    "if (ShouldReleaseBatteryForTimeline())",
    "var shouldSpendBatteryInFixed120Burst = ShouldSpendBatteryInFixed120Burst();",
    "var shouldSpendBatteryByBudget = ShouldSpendBatteryByBudget();",
    "if (ShouldHoldBatteryForTimeline())",
    "if (ShouldHoldBatteryForFixed120Burst())",
    "if (ShouldReserveFullMetalWildfireWeaves())",
    "if (ShouldUseDumpResources() || IsForceBurstActive() || shouldSpendBatteryInFixed120Burst || shouldSpendBatteryByBudget || CanUseBurstResource())"
) "Queen policy must keep ForbidBurst first, release second, then compute fixed-120/overcap pressure before timeline hold"

foreach ($pattern in @(
    "IsTimelineHoldBatteryActive\(\)",
    "!ShouldReleaseBatteryForTimeline\(\)",
    "!ShouldSpendBatteryByBudget\(\)"
)) {
    if ($holdBody -notmatch $pattern) {
        $failures.Add("ShouldHoldBatteryForTimeline must let overcap/budget pressure bypass generic delayed-burst hold while preserving explicit battery hold: $pattern")
    }
}

if ($holdBody -notmatch "if \(IsTimelineHoldBatteryActive\(\)\)\s*\r?\n\s*return !ShouldReleaseBatteryForTimeline\(\);") {
    $failures.Add("Explicit mch_hold_battery must remain a hard battery hold and must not be bypassed by overcap pressure.")
}

if ($holdBody -notmatch "return IsTimelineHoldAllBurstActive\(\)\s*\r?\n\s*&& !ShouldReleaseBatteryForTimeline\(\)\s*\r?\n\s*&& !ShouldSpendBatteryByBudget\(\);") {
    $failures.Add("Only generic mch_hold_all_burst may be bypassed by battery overcap/budget pressure.")
}

foreach ($pattern in @(
    "GetBattery\(\) >= _settings\.BatteryOvercapSpendThreshold",
    "MachinistResourcePlanner\.ShouldSpendBatteryBeforeBurst",
    "GetTimeToNextTwoMinuteBurstAnchor\(\)"
)) {
    if ($budgetBody -notmatch $pattern) {
        $failures.Add("Battery overcap/budget pressure missing pattern: $pattern")
    }
}

Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "mch_hold_all_burst.*90.*mch_hold_battery" "Development docs must record battery hold vs overcap priority"

if ($failures.Count -gt 0) {
    Write-Host "Machinist battery hold/overcap priority validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist battery hold/overcap priority validation passed."
