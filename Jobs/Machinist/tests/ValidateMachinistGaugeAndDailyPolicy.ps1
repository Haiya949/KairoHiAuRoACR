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
        "$SignaturePattern\s*\{(?<body>.*?)\n\}",
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

$rotationEntry = Read-File "Jobs/Machinist/MachinistRotationEntry.cs"
$settings = Read-File "Jobs/Machinist/MachinistSettings.cs"
$ui = Read-File "Jobs/Machinist/MachinistRotationUi.cs"
$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"
$heatCond = Read-File "Jobs/Machinist/Triggers/TriggerCond_Heat.cs"
$batteryCond = Read-File "Jobs/Machinist/Triggers/TriggerCond_Battery.cs"

Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Heat.cs" "class\s+TriggerCond_Heat\s*:\s*ITriggerCond" "MCH heat condition must be a HiAuRo trigger condition"
Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Heat.cs" '\[TriggerDisplay\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*/[^"]*\p{IsCJKUnifiedIdeographs}' "MCH heat condition must expose Chinese HiAuRo trigger metadata"
Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Heat.cs" '\[TriggerTypeName\("KairoMCHHeatCondition"\)\]' "MCH heat condition must keep the documented type discriminator"
Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Heat.cs" "public\s+int\s+Heat\s*\{\s*get;\s*set;\s*\}\s*=\s*50;" "MCH heat condition must expose a serializable Heat threshold"
Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Heat.cs" "public\s+string\s+Remark\s*\{\s*get;\s*set;\s*\}\s*=\s*string\.Empty;" "MCH heat condition must expose Remark for HiAuRo authoring"
Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Heat.cs" "MCHHelper\.HeatGauge\s*>=\s*Heat" "MCH heat condition must read the gauge through HiAuRo.Helper"
Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Heat.cs" "builder\.AddIntInput\(nameof\(Heat\),\s*Heat" "MCH heat condition must draw a HiAuRo authoring field"
Assert-NotContains "Jobs/Machinist/Triggers/TriggerCond_Heat.cs" "AEAssist|JobApi_Machinist|Core\.Resolve|ImGui" "MCH heat condition must not leak AEAssist APIs"

Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Battery.cs" "class\s+TriggerCond_Battery\s*:\s*ITriggerCond" "MCH battery condition must be a HiAuRo trigger condition"
Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Battery.cs" '\[TriggerDisplay\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*/[^"]*\p{IsCJKUnifiedIdeographs}' "MCH battery condition must expose Chinese HiAuRo trigger metadata"
Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Battery.cs" '\[TriggerTypeName\("KairoMCHBatteryCondition"\)\]' "MCH battery condition must keep the documented type discriminator"
Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Battery.cs" "public\s+int\s+Battery\s*\{\s*get;\s*set;\s*\}\s*=\s*50;" "MCH battery condition must expose a serializable Battery threshold"
Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Battery.cs" "public\s+string\s+Remark\s*\{\s*get;\s*set;\s*\}\s*=\s*string\.Empty;" "MCH battery condition must expose Remark for HiAuRo authoring"
Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Battery.cs" "MCHHelper\.BatteryGauge\s*>=\s*Battery" "MCH battery condition must read the gauge through HiAuRo.Helper"
Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Battery.cs" "builder\.AddIntInput\(nameof\(Battery\),\s*Battery" "MCH battery condition must draw a HiAuRo authoring field"
Assert-NotContains "Jobs/Machinist/Triggers/TriggerCond_Battery.cs" "AEAssist|JobApi_Machinist|Core\.Resolve|ImGui" "MCH battery condition must not leak AEAssist APIs"

if ($rotationEntry -notmatch "TriggerConditions\s*=\s*\[[^\]]*new\s+TriggerCond_Heat\(\)[^\]]*new\s+TriggerCond_Battery\(\)[^\]]*\]") {
    $failures.Add("MCH rotation must register heat and battery trigger conditions in TriggerConditions")
}

foreach ($pattern in @(
    "public\s+float\s+DailyWeakTargetBurstHpThreshold\s*=\s*0\.12f;",
    "public\s+float\s+DailyDumpResourcesHpThreshold\s*=\s*0\.03f;",
    "public\s+bool\s+DailyMinionResourceGuardEnabled\s*=\s*true;",
    "public\s+float\s+DailyQueenHpThreshold\s*=\s*0\.75f;"
)) {
    if ($settings -notmatch $pattern) {
        $failures.Add("MachinistSettings missing daily target policy setting: $pattern")
    }
}

foreach ($pattern in @(
    'AddFloatInput\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*",\s*ref\s+_settings\.DailyWeakTargetBurstHpThreshold',
    'AddFloatInput\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*",\s*ref\s+_settings\.DailyDumpResourcesHpThreshold',
    'AddCheckbox\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*",\s*ref\s+_settings\.DailyMinionResourceGuardEnabled',
    'AddFloatInput\("[^"]*\p{IsCJKUnifiedIdeographs}[^"]*",\s*ref\s+_settings\.DailyQueenHpThreshold'
)) {
    if ($ui -notmatch $pattern) {
        $failures.Add("Machinist UI missing daily setting control: $pattern")
    }
}

Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "private const float (WeakTargetBurstHpThreshold|DumpResourcesHpThreshold)" "Daily target HP thresholds must come from MachinistSettings, not private constants"

Assert-BodyContains $helper "private static bool ShouldUseDailyTargetHpPolicy\(\)" @(
    "_settings\.DailyMinionResourceGuardEnabled",
    "!_settings\.IsHighEndMode"
) "Daily target HP policy must be controlled by settings and disabled in high-end mode"

Assert-BodyContains $helper "private static bool ShouldDumpResourcesByTargetHp\(\)" @(
    "\(float\)target\.CurrentHp / target\.MaxHp <= _settings\.DailyDumpResourcesHpThreshold"
) "Daily dump threshold must read MachinistSettings"

Assert-BodyContains $helper "private static bool ShouldHoldBurstForWeakTarget\(\)" @(
    "GetCurrentTargetHpPercent\(\) <= _settings\.DailyWeakTargetBurstHpThreshold"
) "Daily weak-target hold threshold must read MachinistSettings"

Assert-BodyContains $helper "public static Spell\? GetQueenOffGcd\(\)" @(
    "ShouldHoldQueenForWeakDailyTarget\(\)"
) "Queen release must respect the documented daily weak-minion guard"

Assert-BodyContains $helper "private static bool ShouldHoldQueenForWeakDailyTarget\(\)" @(
    "ShouldUseDailyTargetHpPolicy\(\)",
    "target\.IsBoss\(\)",
    "GetCurrentTargetHpPercent\(\) <= _settings\.DailyQueenHpThreshold"
) "Daily Queen guard must use settings and ignore bosses"

Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "Daily target HP policy.*settings" "Development docs must record that daily HP thresholds are configurable settings"
Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Heat.cs" "KairoMCHHeatCondition" "Heat trigger condition must keep its execution-axis discriminator"
Assert-Contains "Jobs/Machinist/Triggers/TriggerCond_Battery.cs" "KairoMCHBatteryCondition" "Battery trigger condition must keep its execution-axis discriminator"

if ($failures.Count -gt 0) {
    Write-Host "Machinist gauge/daily policy validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist gauge/daily policy validation passed."
