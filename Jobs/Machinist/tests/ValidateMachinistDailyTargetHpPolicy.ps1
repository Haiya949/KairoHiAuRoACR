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

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"

Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "public const string CombatModeDaily" "MCH daily target-HP policy must be tied to the persistent daily mode setting"
Assert-Contains "Jobs/Machinist/MachinistSettings.cs" "public const string CombatModeHighEnd" "MCH high-end mode must remain the explicit non-daily mode"

foreach ($pattern in @(
    "private const float WeakTargetBurstHpThreshold = 0\.12f",
    "private const float DumpResourcesHpThreshold = 0\.03f",
    "private static IBattleChara\? GetCurrentTarget\(\)",
    "private static bool ShouldUseDailyTargetHpPolicy\(\)",
    "private static float GetCurrentTargetHpPercent\(\)",
    "private static bool ShouldDumpResourcesByTargetHp\(\)",
    "private static bool ShouldHoldBurstForWeakTarget\(\)"
)) {
    if ($helper -notmatch $pattern) {
        $failures.Add("MachinistSpellHelper.cs missing daily target-HP policy pattern: $pattern")
    }
}

Assert-BodyContains $helper "private static bool ShouldUseDailyTargetHpPolicy\(\)" @(
    "!_settings\.IsHighEndMode"
) "Daily target-HP policy must be disabled in high-end mode"

Assert-BodyContains $helper "private static bool HasTarget\(\)" @(
    "GetCurrentTarget\(\) is not null"
) "HasTarget must share the live target helper used by target-HP policy"

Assert-BodyContains $helper "private static IBattleChara\? GetCurrentTarget\(\)" @(
    "global::HiAuRo\.Data\.Target\.Current is IBattleChara target",
    "target\.CurrentHp > 0",
    "target\.IsDead != true"
) "Current target helper must stay HiAuRo-native and reject stale/dead target objects"

Assert-BodyContains $helper "private static float GetCurrentTargetHpPercent\(\)" @(
    "var target = GetCurrentTarget\(\)",
    "target\.MaxHp <= 0",
    "\(float\)target\.CurrentHp / target\.MaxHp"
) "Target HP helper must calculate percent from the live HiAuRo target"

Assert-BodyContains $helper "private static bool ShouldDumpResourcesByTargetHp\(\)" @(
    "!ShouldUseDailyTargetHpPolicy\(\)",
    "var target = GetCurrentTarget\(\)",
    "target is null \|\| target\.MaxHp <= 0",
    "\(float\)target\.CurrentHp / target\.MaxHp <= DumpResourcesHpThreshold"
) "Daily mode should auto-dump resources only when a live target is nearly dead"

Assert-BodyContains $helper "private static bool ShouldHoldBurstForWeakTarget\(\)" @(
    "ShouldUseDailyTargetHpPolicy\(\)",
    "target\.IsBoss\(\)",
    "GetCurrentTargetHpPercent\(\) <= WeakTargetBurstHpThreshold"
) "Daily mode should avoid planned burst on weak non-boss targets"

Assert-BodyContains $helper "private static bool ShouldUseDumpResources\(\)" @(
    "QTHelper\.IsEnabled\(QTKey\.DumpResources\)",
    "IsTimelineVariableActive\(MachinistTimelineVariable\.DumpResources\)",
    "ShouldDumpResourcesByTargetHp\(\)"
) "DumpResources must include daily low-HP release without replacing visible QT/timeline controls"

Assert-BodyContains $helper "private static bool CanUseBurstResource\(\)" @(
    "ShouldUseDumpResources\(\) \|\| IsForceBurstActive\(\)",
    "ShouldUseTwoMinuteBurstPlan\(\)",
    "!ShouldHoldBurstForWeakTarget\(\)"
) "Daily weak-target hold must be after explicit dump/force and after high-end burst-plan handling"

Assert-BodyContains $helper "private static bool CanUseResourceForOvercap\(\)" @(
    "ShouldUseDumpResources\(\) \|\| IsForceBurstActive\(\)",
    "ShouldUseTwoMinuteBurstPlan\(\)",
    "!ShouldHoldBurstForWeakTarget\(\)"
) "Daily weak-target hold must also govern overcap spending, while explicit dump/force bypass it"

Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "Daily target HP policy" "Development docs must record the daily target-HP policy boundary"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "12%" "Development docs must record weak-target burst hold threshold"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "3%" "Development docs must record low-HP resource dump threshold"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "requires a live target" "Development docs must record that daily auto-dump is not active without a live target"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "disabled in high-end mode" "Development docs must state this QoL policy is not hidden high-end logic"

Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "Core\\.Me\\.GetCurrTarget|TargetHelper\\.GetNearbyEnemyCount|AEAssist|MachinistActionId|MachinistStatusId" "Daily target-HP policy must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist daily target-HP policy validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist daily target-HP policy validation passed."
