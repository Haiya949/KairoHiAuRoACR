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

$opener = Read-File "Jobs/Machinist/Opener/MachinistOpener.cs"

Assert-Contains "Jobs/Machinist/Timeline/MachinistTimelineVariable.cs" 'OpenerAirAnchorFirst = "mch_opener_air_anchor_first"' "MCH must keep the old Air Anchor first opener variable"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "BuildFirstOpenerSlot" "MCH opener must have a variable-aware first opener slot"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "BuildSecondOpenerSlot" "MCH opener must have a variable-aware second opener slot"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "IsAirAnchorFirstOpenerActive" "MCH opener must expose the Air Anchor first opener check"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "MachinistTimelineState\.IsActive\(MachinistTimelineVariable\.OpenerAirAnchorFirst\)" "MCH opener must consume the timeline variable through ACR-owned timeline state"
Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" "AEAssist|Kairo\\.Machinist|TimelineController|AI\\.Instance" "Air Anchor first opener must stay HiAuRo-native"

Assert-BodyContains $opener "private static void BuildFirstOpenerSlot\(Slot slot\)" @(
    "IsAirAnchorFirstOpenerActive\(\)",
    "BuildAirAnchorSlot\(slot\)",
    "BuildFirstDrillSlot\(slot\)"
) "First opener slot must switch between Air Anchor and Drill"

Assert-BodyContains $opener "private static void BuildSecondOpenerSlot\(Slot slot\)" @(
    "IsAirAnchorFirstOpenerActive\(\)",
    "BuildFirstDrillSlot\(slot\)",
    "BuildAirAnchorSlot\(slot\)"
) "Second opener slot must invert the Air Anchor first order"

Assert-BodyContains $opener "private static bool CanStart\(\)" @(
    "IsAirAnchorFirstOpenerActive\(\)",
    "IsGcdUnlocked\(ActionId\.AirAnchor\)",
    "IsGcdUnlocked\(ActionId\.Drill\)"
) "Start check must require Air Anchor only when the special opener is active"

Assert-Contains "docs/execution_axis_variables.md" "Air Anchor" "Execution-axis docs must explain the Air Anchor first opener variable"
Assert-Contains "docs/DEVELOPMENT.md" "mch_opener_air_anchor_first" "Development docs must mention the special Air Anchor first opener"
Assert-NotContains "docs/execution_axis_variables.md" "尚未消费|not consumed|not yet consumed" "Execution-axis docs must not say the Air Anchor first variable is unused"

if ($failures.Count -gt 0) {
    Write-Host "Machinist Air Anchor first opener validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist Air Anchor first opener validation passed."
