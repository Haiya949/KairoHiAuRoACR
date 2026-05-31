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

function Assert-BodyContains {
    param(
        [string]$Body,
        [string[]]$Patterns,
        [string]$Message
    )

    foreach ($pattern in $Patterns) {
        if ($Body -notmatch $pattern) {
            $failures.Add("$Message missing pattern: $pattern")
        }
    }
}

function Assert-BodyNotContains {
    param(
        [string]$Body,
        [string]$Pattern,
        [string]$Message
    )

    if ($Body -match $Pattern) {
        $failures.Add("$Message unexpected pattern: $Pattern")
    }
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

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"

$isOverheatedBody = Get-Body $helper "public static bool IsOverheated\(\)" "overheated status predicate"
Assert-BodyContains $isOverheatedBody @(
    "HelperRuntime\.HasStatus\(StatusId\.Overheated\)"
) "Overheated predicate must use the real Overheated status"
Assert-BodyNotContains $isOverheatedBody "StatusId\.Hypercharged" "Hypercharged is the Barrel Stabilizer ready status and must not block Full Metal Field or Hypercharge"

$hyperchargeBody = Get-Body $helper "public static Spell\? GetHyperchargeOffGcd\(\)" "Hypercharge oGCD policy"
Assert-BodyContains $hyperchargeBody @(
    "var hasHyperchargedReady = HelperRuntime\.HasStatus\(StatusId\.Hypercharged\)",
    "if \(!hasHyperchargedReady && GetHeat\(\) < 50",
    "ShouldDelayHyperchargeForFullMetalFieldPackage\(\)"
) "Hypercharge must consume Barrel Stabilizer's Hypercharged status and wait for pending Full Metal Field"

$fullMetalDelayBody = Get-Body $helper "private static bool ShouldDelayHyperchargeForFullMetalFieldPackage\(\)" "Full Metal Field package guard"
Assert-BodyContains $fullMetalDelayBody @(
    "IsActionUnlockedForCooldownLookahead\(ActionId\.FullMetalField\)",
    "HasRecentFullMetalFieldForWildfirePackage\(\)",
    "HelperRuntime\.HasStatus\(StatusId\.FullMetalMachinist\)",
    "TargetSpell\(ActionId\.FullMetalField\)\.IsReadyWithCanCast\(\)"
) "Hypercharge must not spend the Hypercharged status before Full Metal Field has been used"

$wildfireDelayBody = Get-Body $helper "private static bool ShouldDelayWildfireUntilHyperchargeForBurstPackage\(\)" "Wildfire package guard"
Assert-BodyContains $wildfireDelayBody @(
    "ShouldDumpWildfireForTimeline\(\)",
    "!HasRecentFullMetalFieldForWildfirePackage\(\)",
    "return !HasRecentHyperchargeForWildfirePackage\(\);"
) "Loop Wildfire must wait only for the recent Full Metal Field and Hypercharge package, matching the old ACR model"

$wildfireLateWindowBody = Get-Body $helper "private static bool ShouldDelayWildfireForLateWeaveWindow\(\)" "Wildfire late-weave guard"
Assert-BodyContains $wildfireLateWindowBody @(
    "HasRecentFullMetalFieldForWildfirePackage\(\)",
    "HasRecentHyperchargeForWildfirePackage\(\)",
    "GCDHelper\.Is2ndAbilityTime\(\)"
) "Loop Wildfire must prefer the later oGCD window after Hypercharge so the target-hit Wildfire counter has more room for six weaponskills"

$barrelBody = Get-Body $helper "public static Spell\? GetBarrelStabilizerOffGcd\(\)" "Barrel Stabilizer oGCD policy"
Assert-BodyContains $barrelBody @(
    "CanUseBurstResource\(\)"
) "Barrel Stabilizer must follow the old ACR burst-resource gate instead of a loop package state machine"

Assert-BodyNotContains $helper "CanUseLoopBurstPackage|LoopBurstPackageLeadMs" "Hypercharged policy must not reintroduce the failed loop-package state machine"

$gaussBody = Get-Body $helper "public static Spell\? GetGaussRoundOffGcd\(\)" "Checkmate/Double Check oGCD policy"
Assert-BodyContains $gaussBody @(
    "spell\.Charges >= 2"
) "Checkmate and Double Check must keep the natural two-charge release instead of a hidden loop-burst hold"

Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "Hypercharged.*not Overheated" "Development docs must record the Hypercharged/Overheated status split"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "loop Wildfire package.*Full Metal Field.*Hypercharge.*Wildfire" "Development docs must record the loop Wildfire package rule"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "Wildfire.*late oGCD window" "Development docs must record the late-window Wildfire rule"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "Checkmate / Double Check.*Charges >= 2" "Development docs must record the natural Checkmate/Double Check release"

if ($failures.Count -gt 0) {
    Write-Host "Machinist Hypercharged status validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist Hypercharged status validation passed."
