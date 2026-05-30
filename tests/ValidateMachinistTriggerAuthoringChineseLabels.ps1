param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$failures = New-Object System.Collections.Generic.List[string]

function U {
    param([int[]]$Codes)
    return -join ($Codes | ForEach-Object { [char]$_ })
}

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

$hotkey = Read-File "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs"
$timeline = Read-File "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs"

Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" "builder\.AddDropdown\(nameof\(Key\), Enum\.GetNames<MachinistHotkeyAction>\(\), Key\.ToString\(\)\)" "Hotkey trigger must keep stable enum dropdown values for timeline JSON"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" "GetDisplayName\(Key\)" "Hotkey trigger authoring UI must show the selected action in Chinese"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_Hotkey.cs" "private static string GetDisplayName\(MachinistHotkeyAction key\)" "Hotkey trigger must centralize Chinese display names"

$hotkeyLabels = [ordered]@{
    Potion = U @(0x7206, 0x53d1, 0x836f)
    Sprint = U @(0x51b2, 0x523a)
    Tactician = U @(0x7b56, 0x52a8)
    Dismantle = U @(0x6b66, 0x88c5, 0x89e3, 0x9664)
    SecondWind = U @(0x5185, 0x4e39)
    ArmsLength = U @(0x4eb2, 0x758f, 0x81ea, 0x884c)
    HeadGraze = U @(0x4f24, 0x5934)
    LegGraze = U @(0x4f24, 0x817f)
    FootGraze = U @(0x4f24, 0x8db3)
}

foreach ($item in $hotkeyLabels.GetEnumerator()) {
    $pattern = 'MachinistHotkeyAction\.' + $item.Key + ' => "' + [regex]::Escape($item.Value) + '"'
    if ($hotkey -notmatch $pattern) {
        $failures.Add("Hotkey trigger missing Chinese display mapping: $($item.Key)")
    }
}

Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "builder\.AddDropdown\(nameof\(Action\), Enum\.GetNames<MachinistTimelineVariableAction>\(\), Action\.ToString\(\)\)" "Timeline variable trigger must keep stable enum dropdown values for timeline JSON"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "GetDisplayName\(Action\)" "Timeline variable trigger authoring UI must show the selected action in Chinese"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "private static string GetDisplayName\(MachinistTimelineVariableAction action\)" "Timeline variable trigger must centralize Chinese display names"

$timelineLabels = [ordered]@{
    StartDelayedBurstHold = U @(0x5ef6, 0x540e, 0x7206, 0x53d1, 0xff1a, 0x5f00, 0x59cb, 0x7559, 0x8d44, 0x6e90)
    ReleaseDelayedBurstPackage = U @(0x5ef6, 0x540e, 0x7206, 0x53d1, 0xff1a, 0x91ca, 0x653e)
    ResetDelayedBurstPackage = U @(0x5ef6, 0x540e, 0x7206, 0x53d1, 0xff1a, 0x91cd, 0x7f6e)
    ResetAllTimelineVariables = U @(0x91cd, 0x7f6e, 0x5168, 0x90e8, 0x65f6, 0x95f4, 0x8f74, 0x53d8, 0x91cf)
    ForceBurst = U @(0x5f3a, 0x5236, 0x7206, 0x53d1)
    ForbidBurst = U @(0x4fdd, 0x7559, 0x7206, 0x53d1)
    DumpResources = U @(0x6cc4, 0x8d44, 0x6e90)
    HoldBattery = U @(0x4fdd, 0x7559, 0x7535, 0x91cf)
    DumpBattery = U @(0x91ca, 0x653e, 0x7535, 0x91cf)
    HoldHeat = U @(0x4fdd, 0x7559, 0x70ed, 0x91cf)
    DumpHeat = U @(0x91ca, 0x653e, 0x70ed, 0x91cf)
    OpenerAirAnchorFirst = U @(0x7a7a, 0x6c14, 0x951a, 0x8d77, 0x624b)
}

foreach ($item in $timelineLabels.GetEnumerator()) {
    $pattern = 'MachinistTimelineVariableAction\.' + $item.Key + ' => "' + [regex]::Escape($item.Value) + '"'
    if ($timeline -notmatch $pattern) {
        $failures.Add("Timeline variable trigger missing Chinese display mapping: $($item.Key)")
    }
}

Assert-Contains 'docs/timeline_variables.md' ([regex]::Escape((U @(0x89e6, 0x53d1, 0x5668, 0x4f5c, 0x8005, 0x754c, 0x9762, 0x663e, 0x793a, 0x4e2d, 0x6587, 0x540d, 0x79f0)))) 'Timeline docs must explain Chinese authoring labels'
Assert-Contains 'docs/timeline_variables.md' 'JSON.*Key.*Action.*enum' 'Timeline docs must preserve the stable enum JSON contract'
Assert-Contains 'docs/DEVELOPMENT.md' 'trigger authoring UI uses Chinese labels' 'Development docs must record trigger authoring UI language policy'

if ($hotkey -notmatch 'Enum\.GetNames<MachinistHotkeyAction>\(\)') {
    $failures.Add('Hotkey trigger must keep serialized enum option values')
}

if ($timeline -notmatch 'Enum\.GetNames<MachinistTimelineVariableAction>\(\)') {
    $failures.Add('Timeline trigger must keep serialized enum option values')
}

if ($failures.Count -gt 0) {
    Write-Host "Machinist trigger authoring Chinese-label validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist trigger authoring Chinese-label validation passed."
