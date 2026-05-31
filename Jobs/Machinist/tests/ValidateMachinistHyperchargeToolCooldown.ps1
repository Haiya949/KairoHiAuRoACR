param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
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

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"

Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "HyperchargeToolCooldownLookaheadMs\s*\{\s*get;\s*set;\s*\}\s*=\s*8_000" "MCH must keep the 8s Hypercharge tool cooldown guard setting"
Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "HeatOvercapThreshold\s*\{\s*get;\s*set;\s*\}\s*=\s*90" "MCH must keep the 90 heat pressure threshold"

$hyperchargeBody = Get-Body $helper "public static Spell\? GetHyperchargeOffGcd\(\)" "Hypercharge oGCD policy"
Assert-BodyContains $hyperchargeBody @(
    "ShouldFinishCleanShotComboBeforeHypercharge\(\)",
    "ShouldDelayHyperchargeForToolCooldown\(\)",
    "!shouldUseFullMetalWildfireHypercharge",
    "!shouldUseActiveWildfireHypercharge",
    "return null;"
) "Hypercharge must preserve combo and tool cooldown delay gates outside the Wildfire package"

$toolDelayBody = Get-Body $helper "private static bool ShouldDelayHyperchargeForToolCooldown\(\)" "Hypercharge tool cooldown helper"
Assert-BodyContains $toolDelayBody @(
    "IsToolCooldownWithin\(ActionId\.ChainSaw, _settings\.HyperchargeToolCooldownLookaheadMs\)",
    "IsToolCooldownWithin\(ActionId\.AirAnchor, _settings\.HyperchargeToolCooldownLookaheadMs\)"
) "Hypercharge tool cooldown helper must guard Chain Saw and Air Anchor with the configured 8s window"
Assert-BodyNotContains $toolDelayBody "GetHeat\(\)" "Hypercharge tool cooldown guard must not be bypassed by current heat"
Assert-BodyNotContains $toolDelayBody "HyperchargeToolCooldownLookaheadMs \+ GCDHelper\.GetGCDCooldown\(\)" "Hypercharge tool cooldown guard must use the direct configured window"

$toolCooldownBody = Get-Body $helper "private static bool IsToolCooldownWithin\(uint actionId, int lookaheadMs\)" "tool cooldown lookahead helper"
Assert-BodyContains $toolCooldownBody @(
    "IsActionUnlockedForCooldownLookahead\(actionId\)",
    "TargetSpell\(actionId\)\.CooldownMs <= lookaheadMs"
) "Tool cooldown lookahead must inspect cooling actions without requiring them to be ready"
Assert-BodyNotContains $toolCooldownBody "IsReadyWithCanCast\(\)" "Tool cooldown lookahead must not require the tool to be ready"

$comboBody = Get-Body $helper "private static bool ShouldFinishCleanShotComboBeforeHypercharge\(\)" "Clean Shot combo protection helper"
Assert-BodyContains $comboBody @(
    "GetHeat\(\) > _settings\.HeatOvercapThreshold",
    "HelperRuntime\.GetLastComboSpellId\(\)",
    "ActionId\.SlugShot or ActionId\.HeatedSlugShot"
) "Hypercharge must finish the third combo GCD unless heat is over the pressure line"
Assert-BodyNotContains $comboBody "GetTimeToNextTwoMinute|FirstBurstAnchorMs" "Clean Shot combo protection must stay cycle-agnostic"

$unlockBody = Get-Body $helper "private static bool IsActionUnlockedForCooldownLookahead\(uint actionId\)" "cooldown lookahead level gates"
Assert-BodyContains $unlockBody @(
    "ActionId\.Wildfire => LevelAtLeast\(45\)",
    "ActionId\.AirAnchor => LevelAtLeast\(76\)",
    "ActionId\.ChainSaw => LevelAtLeast\(90\)",
    "ActionId\.Excavator => LevelAtLeast\(96\)",
    "ActionId\.FullMetalField => LevelAtLeast\(100\)"
) "Cooldown lookahead must keep level gates for all MCH tools"

Assert-Contains "docs/DEVELOPMENT.md" "Chain Saw and Air Anchor cooldown integrity" "Development docs must record Hypercharge tool cooldown protection"
Assert-Contains "docs/DEVELOPMENT.md" "exact 8s" "Development docs must record the exact Hypercharge tool cooldown window"
Assert-Contains "docs/DEVELOPMENT.md" "current heat does not override this guard" "Development docs must record that heat does not bypass the tool guard"
Assert-Contains "docs/DEVELOPMENT.md" "Barrel Stabilizer.*Hypercharged.*Full Metal Machinist" "Development docs must record Dawntrail Barrel Stabilizer mechanics"

Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "AEAssist|MachinistActionId|MachinistStatusId|Kairo\.Machinist" "Hypercharge tool cooldown migration must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist Hypercharge tool cooldown validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist Hypercharge tool cooldown validation passed."
