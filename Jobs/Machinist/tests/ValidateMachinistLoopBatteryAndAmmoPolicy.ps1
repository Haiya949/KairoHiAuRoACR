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

$gaussBody = Get-Body $helper "public static Spell\? GetGaussRoundOffGcd\(\)" "Checkmate/Double Check policy"
Assert-NotContains $gaussBody "ShouldHoldCheckmateDoubleCheckForLoopBurst" "Checkmate/Double Check must not use a hidden loop-burst hold"
Assert-Contains $gaussBody "spell\.Charges >= 2" "Checkmate/Double Check must keep the original natural release at two charges"
Assert-Order $gaussBody @(
    "if (ShouldDumpCheckmateDoubleCheckForTimeline())",
    "if (ShouldReserveFullMetalWildfireWeaves())",
    "if (IsOverheated() || ShouldUseDumpResources() || spell.Charges >= 2)"
) "Checkmate/Double Check should keep timeline dump and Full Metal weave reserve before the natural two-charge release"

Assert-NotContains $helper "_lastLoopAirAnchorAnchorMs|TrackLoopBurstToolAction|ShouldReserveBatteryForLoopAirAnchor|ShouldSpendBatteryAfterLoopAirAnchor|ShouldPrioritizeBarrelAfterLoopAirAnchor" "Loop battery policy must not use the removed Air Anchor package state"

$queenBody = Get-Body $helper "public static Spell\? GetQueenOffGcd\(\)" "Queen/Rook battery policy"
Assert-Order $queenBody @(
    "var shouldSpendBatteryInFixed120Burst = ShouldSpendBatteryInFixed120Burst();",
    "var shouldSpendBatteryBySelectedStrategy = ShouldSpendBatteryBySelectedStrategy();",
    "if (ShouldHoldBatteryForTimeline())",
    "if (ShouldHoldBatteryForFixed120Burst())",
    "if (ShouldReserveFullMetalWildfireWeaves())",
    "if (ShouldUseDumpResources() || IsForceBurstActive() || shouldSpendBatteryInFixed120Burst || shouldSpendBatteryBySelectedStrategy || CanUseBatteryByBurstResourcePermission())"
) "Queen/Rook policy must use fixed-120 Drill-before-Chain-Saw release plus budget/overcap/resource gates without hidden package state"

Assert-Contains $docs "Checkmate / Double Check.*Charges >= 2" "Development docs must record the natural Checkmate/Double Check release"
Assert-Contains $docs "1:40.*Queen/Rook" "Development docs must record the 1:40 pre-120s Queen/Rook leak guard"
Assert-Contains $docs "Battery.*budget.*overcap" "Development docs must record the budget/overcap battery intent"

if ($failures.Count -gt 0) {
    Write-Host "Machinist loop battery/ammo validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist loop battery/ammo validation passed."
