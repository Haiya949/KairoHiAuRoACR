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
    param([string]$Path, [string]$Pattern, [string]$Message)

    $text = Read-File $Path
    if ($text -notmatch $Pattern) {
        $failures.Add("$Message ($Path): $Pattern")
    }
}

function Assert-NotContains {
    param([string]$Path, [string]$Pattern, [string]$Message)

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

function Assert-BodyNotContains {
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
        if ($match.Groups["body"].Value -match $pattern) {
            $failures.Add("$Message must not contain pattern: $pattern")
        }
    }
}

function Assert-BodyInOrder {
    param(
        [string]$Text,
        [string]$SignaturePattern,
        [string[]]$Tokens,
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

    $position = -1
    foreach ($token in $Tokens) {
        $next = $match.Groups["body"].Value.IndexOf($token, $position + 1, [StringComparison]::Ordinal)
        if ($next -lt 0) {
            $failures.Add("$Message missing or out of order token: $token")
            return
        }

        $position = $next
    }
}

$openerPath = "Jobs/Machinist/Opener/MachinistOpener.cs"
$opener = Read-File $openerPath

Assert-Contains $openerPath "private const int OpenerSlotMaxDurationMs = 3_500;" "MCH opener slots must have enough timeout for countdown target/status races"
Assert-Contains $openerPath "private static void PrepareOpenerSlot\(Slot slot\)" "MCH opener must centralize opener Slot timeout setup"
Assert-Contains $openerPath "slot\.MaxDuration = OpenerSlotMaxDurationMs;" "MCH opener must apply the longer opener Slot timeout"

foreach ($signature in @(
    "private static void BuildFirstDrillSlot\(Slot slot\)",
    "private static void BuildAirAnchorSlot\(Slot slot\)",
    "private static void BuildChainSawSlot\(Slot slot\)",
    "private static void BuildExcavatorSlot\(Slot slot\)",
    "private static void BuildSecondDrillSlot\(Slot slot\)",
    "private static void BuildFullMetalFieldSlot\(Slot slot\)"
)) {
    Assert-BodyContains $opener $signature @(
        "PrepareOpenerSlot\(slot\)"
    ) "Every executable opener slot must opt into the longer runtime timeout: $signature"
}

Assert-BodyNotContains $opener "private static bool CanStart\(\)" @(
    "HasTarget\(\)"
) "MCH opener StartCheck must not fail permanently because Runtime target selection resolves one frame late after countdown"

Assert-BodyContains $opener "private static void BuildExcavatorSlot\(Slot slot\)" @(
    "AddGcdIfUnlocked\(slot,\s*ActionId\.Excavator\)",
    "AddTargetAbilityWithoutReadinessGate\(slot,\s*LevelAtLeast\(80\) \? ActionId\.AutomatonQueen : ActionId\.RookAutoturret\)",
    "AddSelfAbilityIfReady\(slot,\s*ActionId\.Reassemble\)"
) "MCH opener must construct the Excavator step even before the server status is visible"
Assert-BodyNotContains $opener "private static void BuildExcavatorSlot\(Slot slot\)" @(
    "HasExcavatorReady\(\)",
    "AddGcdIfReady\(slot,\s*ActionId\.Excavator",
    "AddTargetAbilityIfReady\(slot,\s*LevelAtLeast\(80\) \? ActionId\.AutomatonQueen : ActionId\.RookAutoturret\)"
) "MCH opener must not skip the Excavator step or its generated Queen/Rook weave during server status sync"

Assert-BodyContains $opener "private static void BuildFullMetalFieldSlot\(Slot slot\)" @(
    "AddGcdIfUnlocked\(slot,\s*ActionId\.FullMetalField\)",
    "AddTargetAbilityIfReady\(slot,\s*ActionId\.DoubleCheck\)",
    "AddSelfAbilityWithoutReadinessGate\(slot,\s*ActionId\.Hypercharge\)"
) "MCH opener must construct the Full Metal Field step even before the server status is visible"
Assert-BodyNotContains $opener "private static void BuildFullMetalFieldSlot\(Slot slot\)" @(
    "HasFullMetalMachinist\(\)",
    "AddGcdIfReady\(slot,\s*ActionId\.FullMetalField",
    "AddSelfAbilityIfReady\(slot,\s*ActionId\.Hypercharge\)"
) "MCH opener must not skip the Full Metal Field step or its generated Hypercharge weave during server status sync"

Assert-BodyInOrder $opener "private static void BuildSecondDrillSlot\(Slot slot\)" @(
    "AddGcdIfUnlocked(slot, ActionId.Drill);",
    "AddTargetAbilityIfReady(slot, ActionId.Checkmate);",
    "AddTargetAbilityIfReady(slot, ActionId.Wildfire);"
) "MCH native IOpener saved ammo order must keep G5 Drill -> Checkmate -> Wildfire in one Slot"

Assert-BodyInOrder $opener "private static void BuildFullMetalFieldSlot\(Slot slot\)" @(
    "AddGcdIfUnlocked(slot, ActionId.FullMetalField);",
    "AddTargetAbilityIfReady(slot, ActionId.DoubleCheck);",
    "AddSelfAbilityWithoutReadinessGate(slot, ActionId.Hypercharge);"
) "MCH native IOpener saved ammo order must keep G6 Full Metal Field -> Double Check -> Hypercharge in one Slot"

Assert-BodyContains $opener "private static void AddTargetAbilityWithoutReadinessGate\(Slot slot, uint actionId\)" @(
    "slot\.Add\(TargetAbility\(actionId\)\)"
) "MCH opener must support target abilities whose readiness is created by the preceding opener GCD"

Assert-BodyContains $opener "private static void AddSelfAbilityWithoutReadinessGate\(Slot slot, uint actionId\)" @(
    "slot\.Add\(SelfAbility\(actionId\)\)"
) "MCH opener must support self abilities whose readiness is created by the preceding opener GCD"

Assert-NotContains $openerPath "MachinistOpenerController|MachinistOpenerGcdResolver|MachinistOpenerOffGcdResolver|UseActionManager|AEAssist" "MCH opener robustness must stay in native IOpener/Slot APIs"

if ($failures.Count -gt 0) {
    Write-Host "Machinist opener runtime robustness validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist opener runtime robustness validation passed."
