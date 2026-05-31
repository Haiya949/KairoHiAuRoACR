param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
)

$ErrorActionPreference = "Stop"
$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message)
}

function Read-File {
    param([string]$Path)

    $fullPath = Join-Path $Root $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        Add-Failure "Missing file: $Path"
        return ""
    }

    return Get-Content -LiteralPath $fullPath -Raw -Encoding utf8
}

function Assert-Contains {
    param([string]$Path, [string]$Pattern, [string]$Message)

    $text = Read-File $Path
    if ($text -notmatch $Pattern) {
        Add-Failure "$Message ($Path): $Pattern"
    }
}

function Walk-Node {
    param(
        [object]$Node,
        [System.Collections.Generic.List[object]]$Nodes,
        [System.Collections.Generic.List[object]]$Actions,
        [System.Collections.Generic.List[object]]$Conds
    )

    if ($null -eq $Node) {
        return
    }

    $Nodes.Add($Node)
    if ($Node.PSObject.Properties.Name -contains "TriggerActions" -and $null -ne $Node.TriggerActions) {
        foreach ($action in @($Node.TriggerActions)) {
            $Actions.Add($action)
        }
    }

    if ($Node.PSObject.Properties.Name -contains "TriggerConds" -and $null -ne $Node.TriggerConds) {
        foreach ($cond in @($Node.TriggerConds)) {
            $Conds.Add($cond)
        }
    }

    if ($Node.PSObject.Properties.Name -contains "Childs" -and $null -ne $Node.Childs) {
        foreach ($child in @($Node.Childs)) {
            Walk-Node $child $Nodes $Actions $Conds
        }
    }
}

function Find-NodesByRemark {
    param(
        [System.Collections.Generic.List[object]]$Nodes,
        [string]$Remark
    )

    return @($Nodes | Where-Object {
        $_.PSObject.Properties.Name -contains "Remark" -and $_.Remark -eq $Remark
    })
}

function Get-DescendantNodes {
    param([object]$Node)

    $result = New-Object System.Collections.Generic.List[object]
    $actions = New-Object System.Collections.Generic.List[object]
    $conds = New-Object System.Collections.Generic.List[object]
    Walk-Node $Node $result $actions $conds
    return $result
}

function Get-ActionsFromNodes {
    param([System.Collections.Generic.List[object]]$Nodes)

    $result = New-Object System.Collections.Generic.List[object]
    foreach ($node in $Nodes) {
        if ($node.PSObject.Properties.Name -contains "TriggerActions" -and $null -ne $node.TriggerActions) {
            foreach ($action in @($node.TriggerActions)) {
                $result.Add($action)
            }
        }
    }
    return $result
}

function Find-TimedEnemyCastGate {
    param(
        [System.Collections.Generic.List[object]]$Nodes,
        [int]$SpellId,
        [int]$MinTimeMs,
        [int]$MaxTimeMs
    )

    foreach ($node in $Nodes) {
        if (-not ($node.PSObject.Properties.Name -contains "TriggerConds")) {
            continue
        }

        $nodeConds = @($node.TriggerConds)
        $hasSpell = @($nodeConds | Where-Object {
            $_.PSObject.Properties.Name -contains '$type' -and
            $_.'$type' -eq "TriggerCondEnemyCastSpell" -and
            [int]$_.SpellId -eq $SpellId
        }).Count -gt 0
        if (-not $hasSpell) {
            continue
        }

        $hasTime = @($nodeConds | Where-Object {
            $_.PSObject.Properties.Name -contains '$type' -and
            $_.'$type' -eq "TriggerCondAfterBattleStart" -and
            [int]$_.TimeMs -ge $MinTimeMs -and
            [int]$_.TimeMs -le $MaxTimeMs
        }).Count -gt 0

        if ($hasTime) {
            return $true
        }
    }

    return $false
}

function Assert-TimedEnemyCastGate {
    param(
        [System.Collections.Generic.List[object]]$Nodes,
        [int]$SpellId,
        [int]$MinTimeMs,
        [int]$MaxTimeMs,
        [string]$Label
    )

    if (-not (Find-TimedEnemyCastGate $Nodes $SpellId $MinTimeMs $MaxTimeMs)) {
        Add-Failure "Missing timed boss cast gate for $Label / spell $SpellId between $MinTimeMs and $MaxTimeMs ms"
    }
}

function Find-TimeOnlyGate {
    param(
        [System.Collections.Generic.List[object]]$Nodes,
        [int]$MinTimeMs,
        [int]$MaxTimeMs
    )

    foreach ($node in $Nodes) {
        if (-not ($node.PSObject.Properties.Name -contains "TriggerConds")) {
            continue
        }

        $nodeConds = @($node.TriggerConds)
        $hasEnemyCast = @($nodeConds | Where-Object {
            $_.PSObject.Properties.Name -contains '$type' -and
            $_.'$type' -eq "TriggerCondEnemyCastSpell"
        }).Count -gt 0
        if ($hasEnemyCast) {
            continue
        }

        $hasTime = @($nodeConds | Where-Object {
            $_.PSObject.Properties.Name -contains '$type' -and
            $_.'$type' -eq "TriggerCondAfterBattleStart" -and
            [int]$_.TimeMs -ge $MinTimeMs -and
            [int]$_.TimeMs -le $MaxTimeMs
        }).Count -gt 0
        if ($hasTime) {
            return $true
        }
    }

    return $false
}

function Find-TimedTimelineAction {
    param(
        [System.Collections.Generic.List[object]]$Nodes,
        [string]$ActionName,
        [bool]$Value,
        [int]$MinTimeMs,
        [int]$MaxTimeMs
    )

    foreach ($node in $Nodes) {
        if ([string]$node.'$type' -ne "HiAuRo.Execution.TreeSequence, HiAuRo") {
            continue
        }

        $descendants = New-Object System.Collections.Generic.List[object]
        foreach ($descendant in @(Get-DescendantNodes $node)) {
            $descendants.Add($descendant)
        }

        if (-not (Find-TimeOnlyGate $descendants $MinTimeMs $MaxTimeMs)) {
            continue
        }

        $actions = Get-ActionsFromNodes $descendants
        $hasAction = @($actions | Where-Object {
            $_.'$type' -eq "KairoMCHTimelineVariable" -and
            $_.Action -eq $ActionName -and
            [bool]$_.Value -eq $Value
        }).Count -gt 0

        if ($hasAction) {
            return $true
        }
    }

    return $false
}

function Assert-TimedTimelineAction {
    param(
        [System.Collections.Generic.List[object]]$Nodes,
        [string]$ActionName,
        [bool]$Value,
        [int]$MinTimeMs,
        [int]$MaxTimeMs,
        [string]$Label
    )

    if (-not (Find-TimedTimelineAction $Nodes $ActionName $Value $MinTimeMs $MaxTimeMs)) {
        Add-Failure "Missing timed timeline action for ${Label}: $ActionName=$Value between $MinTimeMs and $MaxTimeMs ms"
    }
}

$timelinePath = "Jobs/Machinist/docs/execution_timelines/M11S-MCH-execution.json"
$timelineText = Read-File $timelinePath

Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "Jobs/Machinist/docs/execution_timelines/M11S-MCH-execution\.json" "Development docs must point to the concrete M11S HiAuRo execution-axis example"
Assert-Contains "Jobs/Machinist/docs/execution_axis_variables.md" "Jobs/Machinist/docs/execution_timelines/M11S-MCH-execution\.json" "Execution-axis authoring docs must point to the concrete M11S example"

if (-not [string]::IsNullOrWhiteSpace($timelineText)) {
    try {
        $timeline = $timelineText | ConvertFrom-Json
    }
    catch {
        Add-Failure "M11S timeline is not valid JSON: $($_.Exception.Message)"
        $timeline = $null
    }

    if ($null -ne $timeline) {
        if ($timeline.Name -ne "M11S-MCH-Execution") {
            Add-Failure "M11S execution-axis Name must be M11S-MCH-Execution"
        }
        if ($timeline.Author -ne "Kairo") {
            Add-Failure "M11S timeline Author must be Kairo"
        }
        if ($timeline.TargetAcrAuthor -ne "Kairo") {
            Add-Failure "M11S timeline TargetAcrAuthor must be Kairo"
        }
        if ($timeline.TargetJob -ne 31) {
            Add-Failure "M11S timeline TargetJob must be 31 for Machinist"
        }
        if ($timeline.TerritoryTypeId -ne 1325) {
            Add-Failure "M11S timeline TerritoryTypeId must be 1325"
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
            if ($timeline.ExposedVars -notcontains $varName) {
                Add-Failure "M11S timeline missing exposed variable: $varName"
            }
        }

        $nodes = New-Object System.Collections.Generic.List[object]
        $actions = New-Object System.Collections.Generic.List[object]
        $conds = New-Object System.Collections.Generic.List[object]
        Walk-Node $timeline.TreeRoot $nodes $actions $conds

        foreach ($node in $nodes) {
            $type = [string]$node.'$type'
            if (-not $type.StartsWith("HiAuRo.Execution.Tree")) {
                Add-Failure "M11S timeline node must use HiAuRo execution type: $type"
            }
        }

        foreach ($typeName in @(
            "KairoMCHTimelineVariable",
            "KairoMCHPotion",
            "KairoMCHHotkey",
            "TriggerActionSelectenemy",
            "TriggerActionHighPrioritySlot"
        )) {
            if (@($actions | Where-Object { $_.'$type' -eq $typeName }).Count -lt 1) {
                Add-Failure "M11S timeline missing trigger action type: $typeName"
            }
        }

        foreach ($typeName in @("TriggerCondAfterBattleStart", "TriggerCondEnemyCastSpell")) {
            if (@($conds | Where-Object { $_.'$type' -eq $typeName }).Count -lt 1) {
                Add-Failure "M11S timeline missing trigger condition type: $typeName"
            }
        }

        $rootParallel = @($timeline.TreeRoot.Childs)[0]
        if ($null -eq $rootParallel -or [string]$rootParallel.'$type' -ne "HiAuRo.Execution.TreeParallel, HiAuRo") {
            Add-Failure "M11S timeline root must contain one top-level TreeParallel node"
        }

        $potionNodes = @(Find-NodesByRemark $nodes "M11S potion plan")
        if ($potionNodes.Count -ne 1) {
            Add-Failure "M11S timeline must contain one potion plan node"
        }
        else {
            $potionDescendants = New-Object System.Collections.Generic.List[object]
            foreach ($node in @(Get-DescendantNodes $potionNodes[0])) {
                $potionDescendants.Add($node)
            }

            $potionActions = Get-ActionsFromNodes $potionDescendants
            $potionCount = @($potionActions | Where-Object { $_.'$type' -eq "KairoMCHPotion" }).Count
            if ($potionCount -ne 3) {
                Add-Failure "M11S potion plan expected exactly three default potion requests, got $potionCount"
            }

            foreach ($gate in @(
                @{ TimeMs = 6000; Min = 5000; Max = 12000; Label = "opener potion" },
                @{ TimeMs = 300000; Min = 298000; Max = 304000; Label = "five-minute potion" },
                @{ TimeMs = 612000; Min = 608000; Max = 615000; Label = "ten-minute potion" }
            )) {
                if (-not (Find-TimeOnlyGate $potionDescendants $gate.Min $gate.Max)) {
                    Add-Failure "M11S potion plan missing time-only gate for $($gate.Label)"
                }
            }
        }

        $fiveMinuteNodes = @(Find-NodesByRemark $nodes "M11S 5m potion reassemble control")
        if ($fiveMinuteNodes.Count -ne 1) {
            Add-Failure "M11S timeline must contain one five-minute Reassemble control node"
        }
        else {
            $fiveMinuteDescendants = New-Object System.Collections.Generic.List[object]
            foreach ($node in @(Get-DescendantNodes $fiveMinuteNodes[0])) {
                $fiveMinuteDescendants.Add($node)
            }

            if (@($fiveMinuteDescendants | Where-Object { [string]$_.'$type' -eq "HiAuRo.Execution.TreeDelayNode, HiAuRo" }).Count -gt 0) {
                Add-Failure "M11S five-minute Reassemble control must use time-only condition gates, not delay nodes"
            }

            Assert-TimedTimelineAction $fiveMinuteDescendants "HoldReassembleDrill" $true 276000 282000 "278s hold Reassemble before potion"
            Assert-TimedTimelineAction $fiveMinuteDescendants "HoldStrongGcd" $true 296000 299000 "298s hold strong GCD before potion"
            Assert-TimedTimelineAction $fiveMinuteDescendants "HoldStrongGcd" $false 301000 304000 "302s release strong GCD hold"
            Assert-TimedTimelineAction $fiveMinuteDescendants "DumpStrongGcd" $true 301000 304000 "302s dump strong GCD"
            Assert-TimedTimelineAction $fiveMinuteDescendants "HoldReassembleDrill" $false 301000 304000 "302s release Reassemble hold"
            Assert-TimedTimelineAction $fiveMinuteDescendants "DumpReassembleDrill" $true 301000 304000 "302s dump Reassemble"
            Assert-TimedTimelineAction $fiveMinuteDescendants "HoldStrongGcd" $false 310000 316000 "312s clear strong GCD hold"
            Assert-TimedTimelineAction $fiveMinuteDescendants "DumpStrongGcd" $false 310000 316000 "312s clear strong GCD dump"
            Assert-TimedTimelineAction $fiveMinuteDescendants "HoldReassembleDrill" $false 310000 316000 "312s clear Reassemble hold"
            Assert-TimedTimelineAction $fiveMinuteDescendants "DumpReassembleDrill" $false 310000 316000 "312s clear Reassemble dump"
        }

        $meteorNodes = @(Find-NodesByRemark $nodes "M11S meteor heat control")
        if ($meteorNodes.Count -ne 1) {
            Add-Failure "M11S timeline must contain one meteor heat control node"
        }
        else {
            $meteorDescendants = New-Object System.Collections.Generic.List[object]
            foreach ($node in @(Get-DescendantNodes $meteorNodes[0])) {
                $meteorDescendants.Add($node)
            }

            if (@($meteorDescendants | Where-Object { [string]$_.'$type' -eq "HiAuRo.Execution.TreeDelayNode, HiAuRo" }).Count -gt 0) {
                Add-Failure "M11S meteor control must use boss spell-id conditions with battle-time tolerance, not delay nodes"
            }

            Assert-TimedEnemyCastGate $meteorDescendants 46144 365000 380000 "Majestic Meteor phase start"
            Assert-TimedEnemyCastGate $meteorDescendants 46148 378000 386000 "first meteor Explosion heat hold"
            Assert-TimedEnemyCastGate $meteorDescendants 46150 392000 402000 "first Fire Breath heat release"
            Assert-TimedEnemyCastGate $meteorDescendants 46152 438000 446000 "Massive Meteor optional release"
            Assert-TimedEnemyCastGate $meteorDescendants 46148 448000 454000 "third meteor Explosion cleanup"

            $meteorActions = Get-ActionsFromNodes $meteorDescendants
            foreach ($actionName in @("HoldHeat", "DumpHeat", "HoldWildfire", "DumpWildfire", "HoldBarrel", "DumpBarrel")) {
                if (@($meteorActions | Where-Object { $_.'$type' -eq "KairoMCHTimelineVariable" -and $_.Action -eq $actionName }).Count -lt 1) {
                    Add-Failure "M11S meteor control missing timeline action: $actionName"
                }
            }
        }

        $mitigationNodes = @(Find-NodesByRemark $nodes "M11S mitigation axis")
        if ($mitigationNodes.Count -ne 1) {
            Add-Failure "M11S timeline must contain one mitigation node"
        }
        else {
            $mitigationDescendants = New-Object System.Collections.Generic.List[object]
            foreach ($node in @(Get-DescendantNodes $mitigationNodes[0])) {
                $mitigationDescendants.Add($node)
            }

            if (@($mitigationDescendants | Where-Object { [string]$_.'$type' -eq "HiAuRo.Execution.TreeDelayNode, HiAuRo" }).Count -gt 0) {
                Add-Failure "M11S mitigation must use boss spell-id conditions with battle-time tolerance, not delay nodes"
            }

            $mitigationActions = Get-ActionsFromNodes $mitigationDescendants
            $tacticianCount = @($mitigationActions | Where-Object {
                $_.'$type' -eq "KairoMCHHotkey" -and $_.Key -eq "Tactician"
            }).Count
            if ($tacticianCount -lt 5) {
                Add-Failure "M11S mitigation expected at least five Tactician hotkey actions, got $tacticianCount"
            }

            $dismantleCount = @($mitigationActions | Where-Object {
                $_.'$type' -eq "TriggerActionHighPrioritySlot" -and [int]$_.SpellId -eq 2887 -and [int]$_.TargetType -eq 1
            }).Count
            if ($dismantleCount -lt 4) {
                Add-Failure "M11S mitigation expected at least four Dismantle high-priority slots, got $dismantleCount"
            }

            $bossTargetSelections = @($mitigationActions | Where-Object {
                $_.'$type' -eq "TriggerActionSelectenemy" -and [int]$_.TargetDataId -eq 3913
            }).Count
            if ($bossTargetSelections -lt 4) {
                Add-Failure "M11S mitigation expected boss DataId 3913 selections before Dismantle, got $bossTargetSelections"
            }

            Assert-TimedEnemyCastGate $mitigationDescendants 46086 6000 13000 "opener Crown Tactician"
            Assert-TimedEnemyCastGate $mitigationDescendants 46120 135000 145000 "Dominion Tactician"
            Assert-TimedEnemyCastGate $mitigationDescendants 46122 238000 246000 "Tyrant Tactician"
            Assert-TimedEnemyCastGate $mitigationDescendants 46140 336000 345000 "Triple Tyrannhilation Tactician"
            Assert-TimedEnemyCastGate $mitigationDescendants 46150 392000 402000 "first meteor Fire Breath Dismantle"
            Assert-TimedEnemyCastGate $mitigationDescendants 46150 426000 434000 "second meteor Fire Breath Dismantle"
            Assert-TimedEnemyCastGate $mitigationDescendants 46152 438000 446000 "Massive Meteor Tactician"
            Assert-TimedEnemyCastGate $mitigationDescendants 46086 476000 485000 "eight-minute Crown Tactician"
            Assert-TimedEnemyCastGate $mitigationDescendants 46131 506000 516000 "Orbital Omen Dismantle"
        }
    }
}

foreach ($pattern in @(
    "AEAssist",
    "Kairo\.Machinist\.Triggers",
    "RegexNameOrId",
    "NeedTargetable",
    "SpellConfig",
    "NameorId",
    "TriggerAction_QT",
    "TriggerAction_NewQt",
    "TriggerActionAddVariable",
    "/aeTargetSelector",
    "JobViewWindow",
    "qtValues"
)) {
    if ($timelineText -match $pattern) {
        Add-Failure "M11S timeline must not leak old plugin API or field: $pattern"
    }
}

Assert-Contains $timelinePath '"\$type"\s*:\s*"HiAuRo\.Execution\.TreeRoot, HiAuRo"' "M11S timeline root must use HiAuRo TreeRoot"
Assert-Contains $timelinePath '"\$type"\s*:\s*"KairoMCHTimelineVariable"' "M11S timeline must use KairoMCHTimelineVariable"
Assert-Contains $timelinePath "0 / 5 / 10" "M11S timeline note must document default 0 / 5 / 10 potion plan"
Assert-Contains $timelinePath "0 / 6 / 10:30" "M11S timeline note must document optional progression 0 / 6 / 10:30 potion plan"

if ($timelineText -match "0 / 510") {
    Add-Failure "M11S timeline note must not document 0 / 510; write 0 / 5 / 10"
}

if ($failures.Count -gt 0) {
    Write-Host "Machinist M11S timeline validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist M11S timeline validation passed."
