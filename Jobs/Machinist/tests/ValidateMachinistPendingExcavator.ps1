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

Assert-Contains "Jobs/Machinist/MachinistSpellHelper.cs" "private const int ReassemblePendingTargetExpireMs = 4_500" "Reassemble must keep a short pending target window for delayed server states"

Assert-BodyContains $helper "private static int\? GetTrackedReassembleTargetCooldownRemainingMs\(uint actionId\)" @(
    "actionId == ActionId\.Excavator",
    "HelperRuntime\.HasStatus\(StatusId\.ExcavatorReady\) \|\| HasPendingExcavatorFollowUp\(\)",
    "return 0"
) "Tracked cooldown must treat a just-issued Chain Saw as an imminent Excavator target"

Assert-BodyContains $helper "private static bool HasPendingExcavatorFollowUp\(\)" @(
    "CombatActionLastUsedAtMs\.TryGetValue\(ActionId\.ChainSaw, out var lastChainSawUsedAtMs\)",
    "CombatActionLastUsedAtMs\.TryGetValue\(ActionId\.Excavator, out var lastExcavatorUsedAtMs\)",
    "lastChainSawUsedAtMs <= lastExcavatorUsedAtMs",
    "GetAcrBattleTimeMs\(\) - lastChainSawUsedAtMs <= ReassemblePendingTargetExpireMs"
) "Pending Excavator follow-up must be based on Helper action IDs and issued-action tracking"

Assert-Contains "docs/DEVELOPMENT.md" "Chain Saw -> Excavator follow-up" "Development docs must record the pending Excavator follow-up rule"
Assert-Contains "docs/DEVELOPMENT.md" "4\.5s" "Development docs must record the pending target window"
Assert-Contains "docs/DEVELOPMENT.md" "StatusId\.ExcavatorReady" "Development docs must explain the real server state checked after the pending window"

Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "AEAssist|MachinistActionId|MachinistStatusId|Kairo\.Machinist" "Pending Excavator tracking must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist pending Excavator validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist pending Excavator validation passed."
