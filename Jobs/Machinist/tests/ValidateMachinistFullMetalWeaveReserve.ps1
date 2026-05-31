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

function Assert-BodyContains {
    param(
        [string]$Text,
        [string]$SignaturePattern,
        [string[]]$Patterns,
        [string]$Message
    )

    $match = [regex]::Match(
        $Text,
        "$SignaturePattern\s*\{(?<body>.*?)\n    \}",
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        $failures.Add("Could not find body: $Message")
        return
    }

    foreach ($pattern in $Patterns) {
        if ($match.Groups["body"].Value -notmatch $pattern) {
            $failures.Add("$Message missing pattern: $pattern")
        }
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
        $failures.Add("$Message ($Path): $Pattern")
    }
}

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"

foreach ($pattern in @(
    "private const int FullMetalWildfireWeaveReserveMs = 5_000",
    "private static bool ShouldReserveFullMetalWildfireWeaves\(\)",
    "private static bool HasRecentFullMetalFieldForWildfirePackage\(\)",
    "private static bool HasRecentHyperchargeForWildfirePackage\(\)",
    "private static bool HasRecentWildfireForFullMetalPackage\(\)"
)) {
    if ($helper -notmatch $pattern) {
        $failures.Add("MachinistSpellHelper.cs missing Full Metal weave reserve pattern: $pattern")
    }
}

Assert-BodyContains $helper "public static Spell\? GetQueenOffGcd\(\)" @(
    "ShouldReserveFullMetalWildfireWeaves\(\)[\s\S]*return null;",
    "ShouldReleaseBatteryForTimeline\(\)"
) "Queen must not consume the Full Metal Field weave slots reserved for Hypercharge and Wildfire"

Assert-BodyContains $helper "public static Spell\? GetGaussRoundOffGcd\(\)" @(
    "ShouldReserveFullMetalWildfireWeaves\(\)[\s\S]*return null;",
    "PickGaussRoundOrRicochet\(\)"
) "Checkmate and Double Check must not consume the Full Metal Field weave slots reserved for Hypercharge and Wildfire"

Assert-BodyContains $helper "private static bool ShouldReserveFullMetalWildfireWeaves\(\)" @(
    "HasRecentFullMetalFieldForWildfirePackage\(\)",
    "!HasRecentHyperchargeForWildfirePackage\(\)",
    "!HasRecentWildfireForFullMetalPackage\(\)"
) "Full Metal weave reserve must stay active until both Hypercharge and Wildfire are recorded"

Assert-BodyContains $helper "private static void TrackBurstPackageAction\(uint actionId, int actionBattleTimeMs\)" @(
    "if \(actionId == ActionId\.FullMetalField\)",
    "_lastFullMetalFieldStartedAtMs = actionBattleTimeMs"
) "Full Metal Field uses must be tracked for the weave reserve window"

Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "AEAssist|MachinistActionId|MachinistStatusId|Kairo\.Machinist" "Full Metal weave reserve must not leak old ACR APIs or local ID catalogs"

if ($failures.Count -gt 0) {
    Write-Host "Machinist Full Metal weave reserve validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist Full Metal weave reserve validation passed."
