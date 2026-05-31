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

$helper = Read-File "Jobs/Machinist/MachinistSpellHelper.cs"

foreach ($pattern in @(
    "public const string ForceBurst = ""mch_force_burst""",
    "public const string ForbidBurst = ""mch_forbid_burst""",
    "public const string HoldAllBurst = ""mch_hold_all_burst""",
    "public const string ReleaseDelayedBurst = ""mch_release_delayed_burst""",
    "public const string DumpResources = ""mch_dump_resources""",
    "public const string HoldWildfire = ""mch_hold_wildfire""",
    "public const string DumpWildfire = ""mch_dump_wildfire""",
    "public const string HoldBarrel = ""mch_hold_barrel""",
    "public const string DumpBarrel = ""mch_dump_barrel""",
    "public const string HoldCheckmateDoubleCheck = ""mch_hold_checkmate_doublecheck""",
    "public const string DumpCheckmateDoubleCheck = ""mch_dump_checkmate_doublecheck""",
    "public const string HoldBattery = ""mch_hold_battery""",
    "public const string DumpBattery = ""mch_dump_battery""",
    "public const string HoldHeat = ""mch_hold_heat""",
    "public const string DumpHeat = ""mch_dump_heat""",
    "public const string HoldStrongGcd = ""mch_hold_strong_gcd""",
    "public const string DumpStrongGcd = ""mch_dump_strong_gcd""",
    "public const string HoldReassembleDrill = ""mch_hold_reassemble_drill""",
    "public const string DumpReassembleDrill = ""mch_dump_reassemble_drill""",
    "public const string OpenerAirAnchorFirst = ""mch_opener_air_anchor_first"""
)) {
    Assert-Contains "Jobs/Machinist/Timeline/MachinistTimelineVariable.cs" $pattern "MCH timeline variable catalog must preserve old public variable names"
}

Assert-Contains "Jobs/Machinist/Timeline/MachinistTimelineState.cs" "ConcurrentDictionary<string, int>" "Timeline state must be ACR-owned and thread-safe"
Assert-Contains "Jobs/Machinist/Timeline/MachinistTimelineState.cs" "public static bool IsActive\(string variableName\)" "Timeline state must expose read API"
Assert-Contains "Jobs/Machinist/Timeline/MachinistTimelineState.cs" "public static void Set\(string variableName, bool active\)" "Timeline state must expose write API"
Assert-Contains "Jobs/Machinist/Timeline/MachinistTimelineState.cs" "public static void ResetAll\(\)" "Timeline state must support reset"
Assert-Contains "Jobs/Machinist/Timeline/MachinistTimelineState.cs" "public static void ExposeDefaults\(\)" "Timeline state must expose defaults for all public variables"

Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "class TriggerAction_TimelineVariable : ITriggerAction" "MCH must expose a HiAuRo trigger action for timeline variables"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "\[TriggerDisplay\(" "Timeline trigger action must use HiAuRo trigger metadata"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" '\[TriggerTypeName\("KairoMCHTimelineVariable"\)\]' "Timeline trigger action must have stable type discriminator"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "public MachinistTimelineVariableAction Action \{ get; set; \}" "Timeline trigger action must be serializable by HiAuRo"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "public bool Value \{ get; set; \}" "Timeline trigger action must expose boolean value"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "public void Draw\(IUiBuilder builder\)" "Timeline trigger action must use HiAuRo IUiBuilder"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "builder\.AddDropdown" "Timeline trigger action must declare dropdown UI"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "builder\.AddCheckbox" "Timeline trigger action must declare checkbox UI"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "StartDelayedBurstHold" "Timeline trigger action must support delayed burst hold preset"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "ReleaseDelayedBurstPackage" "Timeline trigger action must support delayed burst release preset"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "ResetDelayedBurstPackage" "Timeline trigger action must support delayed burst reset preset"
Assert-Contains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "MachinistSpellHelper\.ReanchorBurstCycleToCurrentTime\(\)" "Release preset must re-anchor following 120s burst cycle"
Assert-NotContains "Jobs/Machinist/Triggers/TriggerAction_TimelineVariable.cs" "AEAssist|ImGui|TimelineController|AI\.Instance" "Timeline trigger must not leak old plugin APIs"

Assert-Contains "Jobs/Machinist/MachinistRotationEntry.cs" "new TriggerAction_TimelineVariable\(\)" "Rotation must register MCH timeline trigger action for HiAuRo execution axis"

foreach ($pattern in @(
    "public static void ReanchorBurstCycleToCurrentTime\(\)",
    "public static bool IsTimelineHoldAllBurstActive\(\)",
    "public static bool IsTimelineReleaseDelayedBurstActive\(\)",
    "public static bool IsTimelineHoldWildfireActive\(\)",
    "public static bool IsTimelineDumpWildfireActive\(\)",
    "public static bool IsTimelineHoldBarrelActive\(\)",
    "public static bool IsTimelineDumpBarrelActive\(\)",
    "public static bool IsTimelineHoldCheckmateDoubleCheckActive\(\)",
    "public static bool IsTimelineDumpCheckmateDoubleCheckActive\(\)",
    "public static bool IsTimelineHoldBatteryActive\(\)",
    "public static bool IsTimelineDumpBatteryActive\(\)",
    "public static bool IsTimelineHoldHeatActive\(\)",
    "public static bool IsTimelineDumpHeatActive\(\)",
    "public static bool IsTimelineHoldStrongGcdActive\(\)",
    "public static bool IsTimelineDumpStrongGcdActive\(\)",
    "public static bool IsTimelineHoldReassembleDrillActive\(\)",
    "public static bool IsTimelineDumpReassembleDrillActive\(\)",
    "private static bool IsTimelineVariableActive\(string variableName\)",
    "public static bool ShouldHoldWildfireForTimeline\(\)",
    "public static bool ShouldDumpWildfireForTimeline\(\)",
    "public static bool ShouldHoldBarrelForTimeline\(\)",
    "public static bool ShouldDumpBarrelForTimeline\(\)",
    "public static bool ShouldHoldCheckmateDoubleCheckForTimeline\(\)",
    "public static bool ShouldDumpCheckmateDoubleCheckForTimeline\(\)",
    "public static bool ShouldHoldBatteryForTimeline\(\)",
    "public static bool ShouldReleaseBatteryForTimeline\(\)",
    "public static bool ShouldHoldHeatForTimeline\(\)",
    "public static bool ShouldDumpHeatForTimeline\(\)",
    "public static bool ShouldHoldStrongGcdForTimeline\(\)",
    "public static bool ShouldDumpStrongGcdForTimeline\(\)",
    "public static bool ShouldHoldReassembleDrillForTimeline\(\)",
    "public static bool ShouldDumpReassembleDrillForTimeline\(\)"
)) {
    if ($helper -notmatch $pattern) {
        $failures.Add("MachinistSpellHelper.cs missing timeline policy: $pattern")
    }
}

Assert-BodyContains $helper "public static Spell\? GetWildfireOffGcd\(\)" @(
    "ShouldHoldWildfireForTimeline\(\)",
    "ShouldDumpWildfireForTimeline\(\)"
) "Wildfire policy must honor timeline hold/dump"

Assert-BodyContains $helper "public static Spell\? GetBarrelStabilizerOffGcd\(\)" @(
    "ShouldHoldBarrelForTimeline\(\)",
    "ShouldDumpBarrelForTimeline\(\)"
) "Barrel policy must honor timeline hold/dump"

Assert-BodyContains $helper "public static Spell\? GetHyperchargeOffGcd\(\)" @(
    "ShouldHoldHeatForTimeline\(\)",
    "ShouldDumpHeatForTimeline\(\)"
) "Hypercharge policy must honor timeline hold/dump"

Assert-BodyContains $helper "public static Spell\? GetQueenOffGcd\(\)" @(
    "ShouldReleaseBatteryForTimeline\(\)",
    "ShouldHoldBatteryForTimeline\(\)"
) "Queen policy must honor timeline hold/dump"

Assert-BodyContains $helper "public static Spell\? GetGaussRoundOffGcd\(\)" @(
    "ShouldHoldCheckmateDoubleCheckForTimeline\(\)",
    "ShouldDumpCheckmateDoubleCheckForTimeline\(\)"
) "Checkmate/DoubleCheck policy must honor timeline hold/dump"

Assert-BodyContains $helper "public static Spell\? GetStrongGcd\(\)" @(
    "ShouldHoldStrongGcdForTimeline\(\)",
    "ShouldDumpStrongGcdForTimeline\(\)"
) "Strong GCD policy must honor timeline hold/dump"

Assert-BodyContains $helper "private static uint\? GetReassembleTargetActionId\(int lookaheadMs\)" @(
    "ShouldDumpReassembleDrillForTimeline\(\)",
    "ShouldHoldReassembleDrillForTimeline\(\)"
) "Reassemble target policy must honor timeline hold/dump"

Assert-Contains "docs/DEVELOPMENT.md" "KairoMCHTimelineVariable" "Development docs must record the HiAuRo timeline trigger discriminator"
Assert-Contains "docs/DEVELOPMENT.md" "mch_hold_wildfire" "Development docs must list old MCH timeline variables"
Assert-Contains "docs/DEVELOPMENT.md" "StartDelayedBurstHold" "Development docs must describe delayed burst hold preset"
Assert-Contains "docs/DEVELOPMENT.md" "ReleaseDelayedBurstPackage" "Development docs must describe delayed burst release preset"
Assert-Contains "docs/DEVELOPMENT.md" "ResetDelayedBurstPackage" "Development docs must describe delayed burst reset preset"

if ($failures.Count -gt 0) {
    Write-Host "Machinist timeline migration validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist timeline migration validation passed."
