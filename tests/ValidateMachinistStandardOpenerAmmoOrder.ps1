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

function Assert-InOrder {
    param(
        [string]$Text,
        [string[]]$Tokens,
        [string]$Message
    )

    $position = -1
    foreach ($token in $Tokens) {
        $next = $Text.IndexOf($token, $position + 1, [StringComparison]::Ordinal)
        if ($next -lt 0) {
            $failures.Add("$Message missing or out of order token: $token")
            return
        }

        $position = $next
    }
}

$opener = Read-File "Jobs/Machinist/Opener/MachinistOpener.cs"

Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "class\s+MachinistOpener\s*:\s*IOpener" "MCH standard opener must stay in HiAuRo IOpener"

Assert-InOrder $opener @(
    "BuildFirstOpenerSlot",
    "BuildSecondOpenerSlot",
    "BuildChainSawSlot",
    "BuildExcavatorSlot",
    "BuildSecondDrillSlot",
    "BuildFullMetalFieldSlot"
) "MCH standard opener sequence must preserve the six-slot old Kairo order"

Assert-BodyInOrder $opener "private static void BuildSecondDrillSlot\(Slot slot\)" @(
    "PrepareOpenerSlot(slot);",
    "AddGcdIfUnlocked(slot, ActionId.Drill);",
    "AddTargetAbilityIfReady(slot, ActionId.Checkmate);",
    "AddTargetAbilityIfReady(slot, ActionId.Wildfire);"
) "MCH G5 opener slot must keep Drill -> Checkmate -> Wildfire"

Assert-BodyInOrder $opener "private static void BuildFullMetalFieldSlot\(Slot slot\)" @(
    "PrepareOpenerSlot(slot);",
    "AddGcdIfUnlocked(slot, ActionId.FullMetalField);",
    "AddTargetAbilityIfReady(slot, ActionId.DoubleCheck);",
    "AddSelfAbilityWithoutReadinessGate(slot, ActionId.Hypercharge);"
) "MCH G6 opener slot must keep Full Metal Field -> Double Check -> Hypercharge"

Assert-BodyContains $opener "private static void BuildFirstDrillSlot\(Slot slot\)" @(
    "AddGcdIfUnlocked\(slot,\s*ActionId\.Drill\)",
    "AddTargetAbilityIfReady\(slot,\s*ActionId\.Checkmate\)",
    "AddTargetAbilityIfReady\(slot,\s*ActionId\.DoubleCheck\)"
) "MCH first Drill slot must allow one Checkmate and one DoubleCheck before the later saved-ammo burst slots"

Assert-BodyContains $opener "private static void BuildAirAnchorSlot\(Slot slot\)" @(
    "AddGcdIfUnlocked\(slot,\s*ActionId\.AirAnchor\)",
    "AddSelfAbilityIfReady\(slot,\s*ActionId\.BarrelStabilizer\)"
) "MCH Air Anchor slot must keep Barrel Stabilizer after G2"

Assert-BodyContains $opener "private static void BuildExcavatorSlot\(Slot slot\)" @(
    "AddGcdIfUnlocked\(slot,\s*ActionId\.Excavator\)",
    "AddTargetAbilityWithoutReadinessGate\(slot,\s*LevelAtLeast\(80\) \? ActionId\.AutomatonQueen : ActionId\.RookAutoturret\)",
    "AddSelfAbilityIfReady\(slot,\s*ActionId\.Reassemble\)"
) "MCH Excavator slot must keep Queen/Rook and second Reassemble before G5 Drill"

Assert-BodyContains $opener "private static Spell TargetAbility\(uint actionId\)" @(
    "new Spell\(actionId,\s*SpellTargetType\.Target\) \{ Type = SpellType\.Ability \}"
) "Target opener weaves must be marked as Ability"

Assert-BodyContains $opener "private static Spell SelfAbility\(uint actionId\)" @(
    "new Spell\(actionId,\s*SpellTargetType\.Self\) \{ Type = SpellType\.Ability \}"
) "Self opener weaves must be marked as Ability"

Assert-Contains "docs/DEVELOPMENT.md" 'G5 `Drill` -> `Checkmate` -> `Wildfire`' "Development docs must record the saved-ammo G5 opener order"
Assert-Contains "docs/DEVELOPMENT.md" 'G6 `Full Metal Field` -> `Double Check` -> `Hypercharge`' "Development docs must record the saved-ammo G6 opener order"

Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" "AEAssist|MachinistActionId|MachinistStatusId|Kairo\.Machinist|UseActionManager|UseAction\(" "MCH standard opener must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist standard opener ammo-order validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist standard opener ammo-order validation passed."
