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

foreach ($pattern in @(
    "private static uint\? _pendingReassembleTargetActionId",
    "private static int _pendingReassembleTargetExpiresAtMs",
    "private static uint\? GetPendingReassembleTargetActionId\(\)",
    "private static void ClearPendingReassembleTarget\(\)",
    "private static Spell\? GetReassembleTargetSpell\(\)"
)) {
    if ($helper -notmatch $pattern) {
        $failures.Add("MachinistSpellHelper.cs missing pending Reassemble target pattern: $pattern")
    }
}

Assert-BodyContains $helper "private static void ResetCombatTracking\(\)" @(
    "ClearPendingReassembleTarget\(\)"
) "Combat reset must clear the pending Reassemble target"

Assert-BodyContains $helper "public static void RecordCombatActionUse\(uint actionId\)" @(
    "_pendingReassembleTargetActionId == actionId",
    "ClearPendingReassembleTarget\(\)"
) "Successful GCD use must clear the pending Reassemble target it consumed"

Assert-BodyContains $helper "public static void MarkReassembleOffGcdIssued\(uint targetActionId\)" @(
    "_pendingReassembleTargetActionId = targetActionId",
    "_pendingReassembleTargetExpiresAtMs = GetAcrBattleTimeMs\(\) \+ ReassemblePendingTargetExpireMs",
    "MarkCombatActionIssued\(ActionId\.Reassemble\)"
) "Reassemble oGCD issue marker must remember the strong GCD that should consume it"

Assert-BodyContains $helper "public static Spell\? GetReassembleOffGcd\(\)" @(
    "targetActionId",
    "WillNextGcdConsumeReassembleTarget\(targetActionId\.Value\)"
) "Reassemble preweave must resolve the next consuming target before issuing Reassemble"

Assert-BodyContains $helper "private static Spell\? GetReassembleTargetSpell\(\)" @(
    "var pendingActionId = GetPendingReassembleTargetActionId\(\)",
    "IsReadyForReassembleTarget\(pendingActionId\.Value\)",
    "TargetSpell\(pendingActionId\.Value\)",
    "GetReadyReassembleTargetActionId\(\)"
) "Reassembled strong GCD must prefer the pending preweave target before re-selecting by priority"

Assert-BodyContains $helper "private static uint\? GetPendingReassembleTargetActionId\(\)" @(
    "_pendingReassembleTargetActionId is null",
    "GetAcrBattleTimeMs\(\) > _pendingReassembleTargetExpiresAtMs",
    "ClearPendingReassembleTarget\(\)",
    "return _pendingReassembleTargetActionId"
) "Pending Reassemble target must expire after the short delayed-state window"

Assert-BodyContains $helper "private static void ClearPendingReassembleTarget\(\)" @(
    "_pendingReassembleTargetActionId = null",
    "_pendingReassembleTargetExpiresAtMs = 0"
) "Pending Reassemble target clear helper must reset both target and expiry"

Assert-BodyContains $helper "private static Spell\? GetReassembledStrongGcd\(\)" @(
    "GetReassembleTargetSpell\(\)",
    "GetLowLevelHotShotGcd\(\)"
) "Reassembled strong GCD selection must flow through pending target protection"

Assert-Contains "Jobs/Machinist/Resolvers/OffGCD/MachinistReassembleResolver.cs" "MachinistSpellHelper\.MarkReassembleOffGcdIssued\(_targetActionId\.Value\)" "Reassemble resolver must pass the selected target action into the issued marker"
Assert-Contains "Jobs/Machinist/Resolvers/OffGCD/MachinistReassembleResolver.cs" "private uint\? _targetActionId" "Reassemble resolver must cache the target selected during Check for Build"
Assert-NotContains "Jobs/Machinist/Resolvers/OffGCD/MachinistReassembleResolver.cs" "MarkReassembleOffGcdIssued\(\);" "Reassemble resolver must not call the old target-less issued marker"

Assert-Contains "docs/DEVELOPMENT.md" "pending Reassemble target" "Development docs must record pending Reassemble target protection"
Assert-Contains "docs/DEVELOPMENT.md" "next GCD" "Development docs must describe that the pending target protects the next consuming GCD"
Assert-NotContains "Jobs/Machinist/MachinistSpellHelper.cs" "AEAssist|MachinistActionId|MachinistStatusId|Kairo\.Machinist" "Pending Reassemble target tracking must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist pending Reassemble target validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist pending Reassemble target validation passed."
