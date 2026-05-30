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

function Walk-Node {
    param(
        [object]$Node,
        [System.Collections.Generic.List[object]]$Nodes,
        [System.Collections.Generic.List[object]]$Actions
    )

    if ($null -eq $Node) {
        return
    }

    $Nodes.Add($Node)
    if ($Node.PSObject.Properties.Name -contains "TriggerActions" -and $null -ne $Node.TriggerActions) {
        foreach ($action in $Node.TriggerActions) {
            $Actions.Add($action)
        }
    }

    if ($Node.PSObject.Properties.Name -contains "Childs" -and $null -ne $Node.Childs) {
        foreach ($child in $Node.Childs) {
            Walk-Node $child $Nodes $Actions
        }
    }
}

$templatePath = "docs/templates/MCH-timeline-template.json"
$docPath = "docs/timeline_variables.md"
$templateText = Read-File $templatePath

Assert-Contains $docPath "KairoMCHTimelineVariable" "Timeline authoring docs must document the MCH timeline variable action"
Assert-Contains $docPath "KairoMCHHotkey" "Timeline authoring docs must document the MCH hotkey action"
Assert-Contains $docPath "KairoMCHPotion" "Timeline authoring docs must document the MCH potion action"
Assert-Contains $docPath "StartDelayedBurstHold" "Timeline authoring docs must document delayed burst hold"
Assert-Contains $docPath "ReleaseDelayedBurstPackage" "Timeline authoring docs must document delayed burst release"
Assert-Contains $docPath "ResetDelayedBurstPackage" "Timeline authoring docs must document delayed burst reset"
Assert-Contains $docPath "mch_hold_wildfire" "Timeline authoring docs must list exposed MCH variables"
Assert-Contains $docPath "MachinistHotkeyIds.Potion" "Timeline authoring docs must document the potion hotkey contract"
Assert-Contains $docPath "HiAuRo.Execution.TreeActionNode" "Timeline authoring docs must use HiAuRo execution-axis node types"
Assert-NotContains $docPath "AEAssist|Kairo\.Machinist\.Triggers|TriggerAction_QT|TriggerAction_NewQt|UsePotion QT" "Timeline authoring docs must not leak old plugin trigger names"

if (-not [string]::IsNullOrWhiteSpace($templateText)) {
    try {
        $template = $templateText | ConvertFrom-Json
    }
    catch {
        $failures.Add("Timeline template is not valid JSON: $($_.Exception.Message)")
        $template = $null
    }

    if ($null -ne $template) {
        if ($template.Name -ne "Kairo MCH HiAuRo timeline authoring template") {
            $failures.Add("Timeline template must use the Kairo MCH HiAuRo template name")
        }
        if ($template.Author -ne "Kairo") {
            $failures.Add("Timeline template Author must be Kairo")
        }
        if ($template.TargetAcrAuthor -ne "Kairo") {
            $failures.Add("Timeline template TargetAcrAuthor must be Kairo")
        }
        if ($template.TargetJob -ne 31) {
            $failures.Add("Timeline template TargetJob must be 31 for MCH")
        }
        if ($template.TerritoryTypeId -ne 0) {
            $failures.Add("Timeline template must stay territory-neutral")
        }

        $requiredVars = @(
            "mch_force_burst",
            "mch_forbid_burst",
            "mch_hold_all_burst",
            "mch_release_delayed_burst",
            "mch_dump_resources",
            "mch_hold_wildfire",
            "mch_dump_wildfire",
            "mch_hold_barrel",
            "mch_dump_barrel",
            "mch_hold_checkmate_doublecheck",
            "mch_dump_checkmate_doublecheck",
            "mch_hold_battery",
            "mch_dump_battery",
            "mch_hold_heat",
            "mch_dump_heat",
            "mch_hold_strong_gcd",
            "mch_dump_strong_gcd",
            "mch_hold_reassemble_drill",
            "mch_dump_reassemble_drill",
            "mch_opener_air_anchor_first"
        )
        foreach ($varName in $requiredVars) {
            if ($template.ExposedVars -notcontains $varName) {
                $failures.Add("Timeline template missing exposed variable: $varName")
            }
        }

        $nodes = New-Object System.Collections.Generic.List[object]
        $actions = New-Object System.Collections.Generic.List[object]
        Walk-Node $template.TreeRoot $nodes $actions

        foreach ($node in $nodes) {
            $type = [string]$node.'$type'
            if (-not $type.StartsWith("HiAuRo.Execution.Tree")) {
                $failures.Add("Timeline template node must use HiAuRo execution type: $type")
            }
        }

        $actionTypes = @($actions | ForEach-Object { [string]$_.'$type' })
        foreach ($typeName in @("KairoMCHTimelineVariable", "KairoMCHHotkey", "KairoMCHPotion")) {
            if ($actionTypes -notcontains $typeName) {
                $failures.Add("Timeline template missing trigger action type: $typeName")
            }
        }

        foreach ($actionName in @("StartDelayedBurstHold", "ReleaseDelayedBurstPackage", "ResetDelayedBurstPackage")) {
            if (-not ($actions | Where-Object { $_.PSObject.Properties.Name -contains "Action" -and $_.Action -eq $actionName })) {
                $failures.Add("Timeline template missing timeline action: $actionName")
            }
        }

        if (-not ($actions | Where-Object { $_.PSObject.Properties.Name -contains "Key" -and $_.Key -eq "Potion" })) {
            $failures.Add("Timeline template must use enum Key=Potion for KairoMCHHotkey")
        }
    }
}

Assert-Contains $templatePath '"\$type"\s*:\s*"HiAuRo\.Execution\.TreeRoot, HiAuRo"' "Timeline template root must use HiAuRo TreeRoot"
Assert-Contains $templatePath '"\$type"\s*:\s*"HiAuRo\.Execution\.TreeActionNode, HiAuRo"' "Timeline template must use HiAuRo TreeActionNode"
Assert-Contains $templatePath '"\$type"\s*:\s*"KairoMCHTimelineVariable"' "Timeline template must use the MCH variable type discriminator"
Assert-Contains $templatePath '"\$type"\s*:\s*"KairoMCHHotkey"' "Timeline template must use the MCH hotkey type discriminator"
Assert-Contains $templatePath '"\$type"\s*:\s*"KairoMCHPotion"' "Timeline template must use the MCH potion type discriminator"
Assert-NotContains $templatePath "AEAssist|Kairo\.Machinist\.Triggers|TriggerAction_QT|TriggerAction_NewQt|UsePotion QT|JobViewWindow" "Timeline template must not leak old plugin trigger names"

Assert-Contains "docs/DEVELOPMENT.md" "docs/templates/MCH-timeline-template.json" "Development docs must point to the HiAuRo MCH timeline template"
Assert-Contains "docs/DEVELOPMENT.md" "docs/timeline_variables.md" "Development docs must point to the timeline authoring docs"

if ($failures.Count -gt 0) {
    Write-Host "Machinist timeline authoring validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist timeline authoring validation passed."
