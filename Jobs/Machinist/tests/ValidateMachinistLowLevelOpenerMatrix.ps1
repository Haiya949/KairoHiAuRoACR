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

$opener = Read-File "Jobs/Machinist/Opener/MachinistOpener.cs"
$docs = Read-File "Jobs/Machinist/docs/DEVELOPMENT.md"

Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "private static readonly \(Func<bool> IsAvailable, Action<Slot> Build\)\[\] StandardOpenerSteps" "MCH opener must keep dynamic step availability as the low-level compatibility mechanism"
Assert-InOrder $opener @(
    "IsFirstOpenerSlotAvailable()",
    "IsSecondOpenerSlotAvailable()",
    "IsGcdUnlocked(ActionId.ChainSaw)",
    "IsGcdUnlocked(ActionId.Excavator)",
    "IsSecondDrillOpenerSlotAvailable()",
    "IsFullMetalFieldOpenerSlotAvailable()"
) "Standard opener dynamic step order must keep the documented low-level matrix"

Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "private static bool IsSecondDrillOpenerSlotAvailable\(\)\s*\{(?s).*IsGcdUnlocked\(ActionId\.AirAnchor\).*IsGcdUnlocked\(ActionId\.ChainSaw\).*IsGcdUnlocked\(ActionId\.Excavator\).*IsGcdUnlocked\(ActionId\.Drill\)" "Second Drill must require Air Anchor, Chain Saw, Excavator, and Drill so 58-95 does not repeat Drill after skipped steps"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "private static bool IsFullMetalFieldOpenerSlotAvailable\(\)\s*\{(?s).*IsSecondDrillOpenerSlotAvailable\(\).*IsGcdUnlocked\(ActionId\.FullMetalField\)" "Full Metal Field opener step must only exist after the complete second-Drill chain is available"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.AirAnchor => LevelAtLeast\(76\)" "Air Anchor opener step must be gated to level 76+"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.ChainSaw => LevelAtLeast\(90\)" "Chain Saw opener step must be gated to level 90+"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.Excavator => LevelAtLeast\(96\)" "Excavator opener step must be gated to level 96+"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "ActionId\.FullMetalField => LevelAtLeast\(100\)" "Full Metal Field opener step must be gated to level 100"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "LevelAtLeast\(80\) \? ActionId\.AutomatonQueen : ActionId\.RookAutoturret" "Excavator slot must document low-level Rook/Queen fallback when the step is available"

Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "Low-level opener matrix" "Development docs must include the low-level opener matrix"
foreach ($pattern in @(
    "58-75.*Drill",
    "76-89.*Air Anchor",
    "90-95.*Chain Saw",
    "96-99.*Excavator",
    "100.*Full Metal Field"
)) {
    if ($docs -notmatch $pattern) {
        $failures.Add("Development docs missing low-level opener matrix row: $pattern")
    }
}

Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "must not generate empty Slot" "Development docs must state low-level opener must not generate empty slots"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "second Drill.*96" "Development docs must explain second Drill is 96+ after Excavator"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "Low-level opener matrix" "Development docs must mark low-level opener matrix as implemented"

Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" "AEAssist|SlotSequence|JobViewWindow|MachinistActionId" "Low-level opener implementation must remain HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist low-level opener matrix validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist low-level opener matrix validation passed."
