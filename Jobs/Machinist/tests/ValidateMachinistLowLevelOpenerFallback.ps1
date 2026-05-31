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

$opener = Read-File "Jobs/Machinist/Opener/MachinistOpener.cs"

foreach ($pattern in @(
    "private static readonly \(Func<bool> IsAvailable, Action<Slot> Build\)\[\] StandardOpenerSteps",
    "private static List<Action<Slot>> BuildSequence\(\)",
    "public List<Action<Slot>> Sequence => _activeSequence \?\?= BuildSequence\(\);"
)) {
    if ($opener -notmatch $pattern) {
        $failures.Add("MachinistOpener.cs missing low-level sequence builder pattern: $pattern")
    }
}

Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "private static bool IsSecondDrillOpenerSlotAvailable\(\)" "MCH low-level opener must gate second Drill as a real late-opener step, not merely by Drill unlock"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "private static bool IsFullMetalFieldOpenerSlotAvailable\(\)" "MCH low-level opener must gate Full Metal Field on the late-opener chain"

Assert-BodyContains $opener "private static List<Action<Slot>> BuildSequence\(\)" @(
    "StandardOpenerSteps",
    "Where\(step => step\.IsAvailable\(\)\)",
    "Select\(step => step\.Build\)",
    "ToList\(\)"
) "MCH opener sequence must skip locked steps before Runtime starts indexed execution"

foreach ($pattern in @(
    "\(static \(\) => IsFirstOpenerSlotAvailable\(\), BuildFirstOpenerSlot\)",
    "\(static \(\) => IsSecondOpenerSlotAvailable\(\), BuildSecondOpenerSlot\)",
    "\(static \(\) => IsGcdUnlocked\(ActionId\.ChainSaw\), BuildChainSawSlot\)",
    "\(static \(\) => IsGcdUnlocked\(ActionId\.Excavator\), BuildExcavatorSlot\)",
    "\(static \(\) => IsSecondDrillOpenerSlotAvailable\(\), BuildSecondDrillSlot\)",
    "\(static \(\) => IsFullMetalFieldOpenerSlotAvailable\(\), BuildFullMetalFieldSlot\)"
)) {
    if ($opener -notmatch $pattern) {
        $failures.Add("MachinistOpener.cs missing low-level opener step gate: $pattern")
    }
}

Assert-BodyContains $opener "private static bool IsFirstOpenerSlotAvailable\(\)" @(
    "IsAirAnchorFirstOpenerActive\(\)",
    "IsGcdUnlocked\(ActionId\.AirAnchor\)",
    "IsGcdUnlocked\(ActionId\.Drill\)"
) "MCH opener first slot must only exist when its selected GCD is unlocked"

Assert-BodyContains $opener "private static bool IsSecondOpenerSlotAvailable\(\)" @(
    "IsAirAnchorFirstOpenerActive\(\)",
    "IsGcdUnlocked\(ActionId\.Drill\)",
    "IsGcdUnlocked\(ActionId\.AirAnchor\)"
) "MCH opener second slot must only exist when its selected GCD is unlocked"

Assert-BodyContains $opener "private static bool IsSecondDrillOpenerSlotAvailable\(\)" @(
    "IsGcdUnlocked\(ActionId\.AirAnchor\)",
    "IsGcdUnlocked\(ActionId\.ChainSaw\)",
    "IsGcdUnlocked\(ActionId\.Excavator\)",
    "IsGcdUnlocked\(ActionId\.Drill\)"
) "Second Drill opener slot must only appear when the late-opener chain exists, avoiding low-level duplicate Drill attempts"

Assert-BodyContains $opener "private static bool IsFullMetalFieldOpenerSlotAvailable\(\)" @(
    "IsSecondDrillOpenerSlotAvailable\(\)",
    "IsGcdUnlocked\(ActionId\.FullMetalField\)"
) "Full Metal opener slot must only appear after the late-opener chain and at level 100"

Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" "\(static \(\) => true, Build(?:First|Second)OpenerSlot\)" "MCH opener must not include first/second opener slots unconditionally because low levels can produce empty slots"

Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.AirAnchor => LevelAtLeast\(76\)" "MCH opener must keep Air Anchor level gate"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.ChainSaw => LevelAtLeast\(90\)" "MCH opener must keep Chain Saw level gate"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.Excavator => LevelAtLeast\(96\)" "MCH opener must keep Excavator level gate"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.FullMetalField => LevelAtLeast\(100\)" "MCH opener must keep Full Metal Field level gate"

Assert-Contains "docs/DEVELOPMENT.md" "Low-level opener rule" "Development docs must record the low-level opener fallback"
Assert-Contains "docs/DEVELOPMENT.md" "skip locked opener steps" "Development docs must state locked opener steps are skipped"
Assert-Contains "docs/DEVELOPMENT.md" "must not wait forever" "Development docs must record the no-empty-slot low-level invariant"
Assert-Contains "docs/DEVELOPMENT.md" "second Drill only exists after Air Anchor, Chain Saw, and Excavator" "Development docs must record the late-opener second Drill low-level invariant"

Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" "AEAssist|MachinistActionId|MachinistStatusId|Kairo\.Machinist|UseActionManager|UseAction\(" "MCH low-level opener fallback must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist low-level opener fallback validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist low-level opener fallback validation passed."
