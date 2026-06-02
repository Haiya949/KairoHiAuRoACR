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

function Assert-InOrder {
    param(
        [string]$Text,
        [string[]]$Tokens,
        [string]$Message
    )

    $position = -1
    foreach ($token in $Tokens) {
        $next = $Text.IndexOf($token, $position + 1, [System.StringComparison]::Ordinal)
        if ($next -lt 0) {
            $failures.Add("$Message; missing or out of order token: $token")
            return
        }

        $position = $next
    }
}

$settings = Read-File "Jobs/Machinist/MachinistSettings.cs"
$ui = Read-File "Jobs/Machinist/MachinistRotationUi.cs"
$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"
$docs = Read-File "Jobs/Machinist/docs/DEVELOPMENT.md"

Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "public const string BatteryStrategyBudgetFirst" "MCH settings must expose budget-first battery strategy"
Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "public const string BatteryStrategyFullFirst" "MCH settings must expose full-battery-first strategy"
Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "public const string BatteryStrategyThresholdFirst" "MCH settings must expose threshold-first strategy"
Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "BatteryStrategyOptions\s*=\s*\[[^\]]*BatteryStrategyBudgetFirst[^\]]*BatteryStrategyFullFirst[^\]]*BatteryStrategyThresholdFirst[^\]]*\]" "MCH settings must publish battery strategy dropdown options"
Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "public\s+string\s+BatteryStrategy\s*=\s*BatteryStrategyBudgetFirst;" "Battery strategy must default to budget-first"
Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "public\s+int\s+BatteryThresholdStrategySpendThreshold\s*=\s*70;" "Threshold-first strategy must expose a daily threshold field"

Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" 'AddDropdown\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*",\s*MachinistSettings\.BatteryStrategyOptions,\s*ref\s+_settings\.BatteryStrategy' "MCH UI must expose a Chinese battery strategy dropdown"
Assert-Contains "Jobs/Machinist/MachinistRotationUi.cs" 'AddIntInput\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*",\s*ref\s+_settings\.BatteryThresholdStrategySpendThreshold' "MCH UI must expose the threshold-first battery value"

Assert-BodyContains $helper "private static bool ShouldUseBudgetBatteryStrategy\(\)" @(
    "_settings\.IsHighEndMode",
    "_settings\.BatteryStrategy == MachinistSettings\.BatteryStrategyBudgetFirst"
) "High-end mode must force budget-first battery strategy"

Assert-BodyContains $helper "private static bool ShouldUseFullFirstBatteryStrategy\(\)" @(
    "!_settings\.IsHighEndMode",
    "_settings\.BatteryStrategy == MachinistSettings\.BatteryStrategyFullFirst"
) "Full-battery-first strategy must only apply outside high-end mode"

Assert-BodyContains $helper "private static bool ShouldUseThresholdFirstBatteryStrategy\(\)" @(
    "!_settings\.IsHighEndMode",
    "_settings\.BatteryStrategy == MachinistSettings\.BatteryStrategyThresholdFirst"
) "Threshold-first strategy must only apply outside high-end mode"

Assert-BodyContains $helper "private static bool ShouldSpendBatteryBySelectedStrategy\(\)" @(
    "ShouldUseBudgetBatteryStrategy\(\)",
    "ShouldSpendBatteryByBudget\(\)",
    "ShouldUseFullFirstBatteryStrategy\(\)",
    "GetBattery\(\) >= _settings\.BatteryOvercapSpendThreshold",
    "ShouldUseThresholdFirstBatteryStrategy\(\)",
    "GetBattery\(\) >= _settings\.BatteryThresholdStrategySpendThreshold",
    "return false"
) "Selected battery strategy must keep budget mode and daily-only full/threshold modes"

Assert-BodyContains $helper "private static bool CanUseBatteryByBurstResourcePermission\(\)" @(
    "ShouldUseBudgetBatteryStrategy\(\)",
    "CanUseBurstResource\(\)"
) "Generic Burst permission must only bypass battery strategy while budget-first is active"

Assert-BodyContains $helper "public static Spell\? GetQueenOffGcd\(\)" @(
    "var shouldSpendBatteryBySelectedStrategy = ShouldSpendBatteryBySelectedStrategy\(\)",
    "var minWeaveMs = shouldSpendBatteryInFixed120Burst \? 0 : shouldSpendBatteryBySelectedStrategy \? 650 : 800",
    "shouldSpendBatteryBySelectedStrategy \|\| CanUseBatteryByBurstResourcePermission\(\)"
) "Queen summon must use selected battery strategy without removing fixed-120 burst release"

Assert-InOrder $helper @(
    "if (IsForbidBurstActive())",
    "if (ShouldReleaseBatteryForTimeline())",
    "var shouldSpendBatteryInFixed120Burst = ShouldSpendBatteryInFixed120Burst();",
    "var shouldSpendBatteryBySelectedStrategy = ShouldSpendBatteryBySelectedStrategy();",
    "if (ShouldHoldBatteryForTimeline())",
    "if (ShouldHoldBatteryForFixed120Burst())"
) "Battery strategy must not bypass ForbidBurst, explicit timeline release, fixed-120 release, or timeline hold priority"

Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "Battery strategy modes" "Development docs must record battery strategy modes"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "high-end.*budget-first|高难.*预算优先" "Development docs must state high-end mode forces budget-first"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "BatteryStrategyBudgetFirst" "Development docs must mark robot strategy mode implementation"

Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "AEAssist|JobApi_Machinist|MachinistActionId|MachinistStatusId" "Battery strategy implementation must remain HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist battery strategy mode validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist battery strategy mode validation passed."
