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

$opener = Read-File "Jobs/Machinist/Opener/MachinistOpener.cs"

Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "private List<Action<Slot>>\? _activeSequence;" "MCH opener must keep one active Sequence snapshot while Runtime OpenerMgr is executing"
Assert-Contains "Jobs/Machinist/Opener/MachinistOpener.cs" "public List<Action<Slot>> Sequence => _activeSequence \?\?= BuildSequence\(\);" "MCH opener Sequence must expose the active snapshot and only lazily rebuild before Runtime starts"
Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" "public List<Action<Slot>> Sequence => BuildSequence\(\);" "MCH opener Sequence must not rebuild on every Runtime step because OpenerMgr reads Sequence repeatedly"
Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" "public List<Action<Slot>> Sequence \{ get; \} = BuildSequence\(\);" "MCH opener Sequence must not be frozen at ACR build time"

Assert-BodyContains $opener "public int StartCheck\(\)" @(
    "_activeSequence = BuildSequence\(\)",
    "return CanStart\(\) && _activeSequence\.Count > 0 \? 0 : -1"
) "MCH opener StartCheck must snapshot the latest low-level gates and timeline variables before OpenerMgr starts indexed execution"

Assert-BodyContains $opener "private static List<Action<Slot>> BuildSequence\(\)" @(
    "StandardOpenerSteps",
    "step\.IsAvailable\(\)",
    "step\.Build",
    "ToList\(\)"
) "Dynamic Sequence rebuild must keep low-level skip-empty-slot behavior"

Assert-BodyContains $opener "private static void BuildFirstOpenerSlot\(Slot slot\)" @(
    "IsAirAnchorFirstOpenerActive\(\)",
    "BuildAirAnchorSlot\(slot\)",
    "BuildFirstDrillSlot\(slot\)"
) "Dynamic opener sequence must keep Air Anchor first slot selection"

Assert-BodyContains $opener "private static void BuildSecondOpenerSlot\(Slot slot\)" @(
    "IsAirAnchorFirstOpenerActive\(\)",
    "BuildFirstDrillSlot\(slot\)",
    "BuildAirAnchorSlot\(slot\)"
) "Dynamic opener sequence must keep inverted second slot selection"

Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "IOpener\.Sequence" "Development docs must record the opener Sequence contract"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "dynamic Sequence snapshot" "Development docs must record why opener Sequence is snapshotted at StartCheck"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "before OpenerMgr starts" "Development docs must state the Air Anchor first variable timing"
Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "same Sequence snapshot" "Development docs must state Runtime opener execution uses the same Sequence snapshot"
Assert-Contains "Jobs/Machinist/docs/execution_axis_variables.md" "before OpenerMgr starts" "Execution-axis docs must state when mch_opener_air_anchor_first is consumed"
Assert-Contains "Jobs/Machinist/docs/execution_axis_variables.md" "running opener snapshot" "Execution-axis docs must state opener variables do not mutate the running opener snapshot"

Assert-NotContains "Jobs/Machinist/Opener/MachinistOpener.cs" 'AEAssist|MachinistActionId|MachinistStatusId|Kairo\.Machinist|UseActionManager|UseAction\(' "Dynamic opener Sequence must stay HiAuRo-native and Helper-backed"

if ($failures.Count -gt 0) {
    Write-Host "Machinist dynamic opener Sequence validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist dynamic opener Sequence validation passed."
