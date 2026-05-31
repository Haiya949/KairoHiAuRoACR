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

function Find-TimelineActionTimedGate {
    param(
        [System.Collections.Generic.List[object]]$Nodes,
        [string]$ActionName,
        [bool]$Value,
        [int]$SpellId,
        [int]$MinTimeMs,
        [int]$MaxTimeMs
    )

    foreach ($node in $Nodes) {
        if (-not ($node.PSObject.Properties.Name -contains "Childs")) {
            continue
        }

        if ([string]$node.'$type' -ne "HiAuRo.Execution.TreeSequence, HiAuRo") {
            continue
        }

        $descendants = New-Object System.Collections.Generic.List[object]
        foreach ($descendant in @(Get-DescendantNodes $node)) {
            $descendants.Add($descendant)
        }

        $hasAction = @((Get-ActionsFromNodes $descendants) | Where-Object {
            $_.'$type' -eq "KairoMCHTimelineVariable" -and
            $_.Action -eq $ActionName -and
            [bool]$_.Value -eq $Value
        }).Count -gt 0

        if ($hasAction -and (Find-TimedEnemyCastGate $descendants $SpellId $MinTimeMs $MaxTimeMs)) {
            return $true
        }
    }

    return $false
}

function Assert-TimelineActionTimedGate {
    param(
        [System.Collections.Generic.List[object]]$Nodes,
        [string]$ActionName,
        [bool]$Value,
        [int]$SpellId,
        [int]$MinTimeMs,
        [int]$MaxTimeMs,
        [string]$Label
    )

    if (-not (Find-TimelineActionTimedGate $Nodes $ActionName $Value $SpellId $MinTimeMs $MaxTimeMs)) {
        Add-Failure "Missing timed timeline action for ${Label}: $ActionName=$Value on spell $SpellId"
    }
}

$timelinePath = "Jobs/Machinist/docs/execution_timelines/M9S-MCH-execution.json"
$timelineText = Read-File $timelinePath

Assert-Contains "docs/DEVELOPMENT.md" "Jobs/Machinist/docs/execution_timelines/M9S-MCH-execution\.json" "Development docs must point to the concrete M9S HiAuRo execution-axis example"
Assert-Contains "Jobs/Machinist/docs/execution_axis_variables.md" "Jobs/Machinist/docs/execution_timelines/M9S-MCH-execution\.json" "Execution-axis authoring docs must point to the concrete M9S example"

if (-not [string]::IsNullOrWhiteSpace($timelineText)) {
    try {
        $timeline = $timelineText | ConvertFrom-Json
    }
    catch {
        Add-Failure "M9S timeline is not valid JSON: $($_.Exception.Message)"
        $timeline = $null
    }

    if ($null -ne $timeline) {
        if ($timeline.Name -ne "M9S-MCH-Execution") {
            Add-Failure "M9S execution-axis Name must be M9S-MCH-Execution"
        }
        if ($timeline.Author -ne "Kairo") {
            Add-Failure "M9S timeline Author must be Kairo"
        }
        if ($timeline.TargetAcrAuthor -ne "Kairo") {
            Add-Failure "M9S timeline TargetAcrAuthor must be Kairo"
        }
        if ($timeline.TargetJob -ne 31) {
            Add-Failure "M9S timeline TargetJob must be 31 for Machinist"
        }
        if ($timeline.TerritoryTypeId -ne 1321) {
            Add-Failure "M9S timeline TerritoryTypeId must be 1321"
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
                Add-Failure "M9S timeline missing exposed variable: $varName"
            }
        }

        $nodes = New-Object System.Collections.Generic.List[object]
        $actions = New-Object System.Collections.Generic.List[object]
        $conds = New-Object System.Collections.Generic.List[object]
        Walk-Node $timeline.TreeRoot $nodes $actions $conds

        foreach ($node in $nodes) {
            $type = [string]$node.'$type'
            if (-not $type.StartsWith("HiAuRo.Execution.Tree")) {
                Add-Failure "M9S timeline node must use HiAuRo execution type: $type"
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
                Add-Failure "M9S timeline missing trigger action type: $typeName"
            }
        }

        foreach ($typeName in @("TriggerCondAfterBattleStart", "TriggerCondEnemyCastSpell", "TriggerCondWaitTarget")) {
            if (@($conds | Where-Object { $_.'$type' -eq $typeName }).Count -lt 1) {
                Add-Failure "M9S timeline missing trigger condition type: $typeName"
            }
        }

        $rootParallel = @($timeline.TreeRoot.Childs)[0]
        if ($null -eq $rootParallel -or [string]$rootParallel.'$type' -ne "HiAuRo.Execution.TreeParallel, HiAuRo") {
            Add-Failure "M9S timeline root must contain one top-level TreeParallel node"
        }

        $potionNodes = @(Find-NodesByRemark $nodes "M9S potion plan")
        if ($potionNodes.Count -ne 1) {
            Add-Failure "M9S timeline must contain one potion plan node"
        }
        else {
            $potionDescendants = New-Object System.Collections.Generic.List[object]
            foreach ($node in @(Get-DescendantNodes $potionNodes[0])) {
                $potionDescendants.Add($node)
            }
            $potionActions = Get-ActionsFromNodes $potionDescendants
            $potionCount = @($potionActions | Where-Object { $_.'$type' -eq "KairoMCHPotion" }).Count
            if ($potionCount -lt 2) {
                Add-Failure "M9S potion plan expected two potion requests, got $potionCount"
            }
            foreach ($timeMs in 125000, 485000) {
                if (@($potionDescendants |
                    Where-Object { $_.PSObject.Properties.Name -contains "TriggerConds" } |
                    ForEach-Object { @($_.TriggerConds) } |
                    Where-Object { $_.'$type' -eq "TriggerCondAfterBattleStart" -and [int]$_.TimeMs -eq $timeMs }).Count -lt 1) {
                    Add-Failure "M9S potion plan missing time gate: $timeMs"
                }
            }
        }

        $addNodes = @(Find-NodesByRemark $nodes "M9S add resource control")
        if ($addNodes.Count -ne 1) {
            Add-Failure "M9S timeline must contain one add resource control node"
        }
        else {
            $addDescendants = New-Object System.Collections.Generic.List[object]
            foreach ($node in @(Get-DescendantNodes $addNodes[0])) {
                $addDescendants.Add($node)
            }
            $addActions = Get-ActionsFromNodes $addDescendants

            if (@($addDescendants | Where-Object { [string]$_.'$type' -eq "HiAuRo.Execution.TreeDelayNode, HiAuRo" }).Count -gt 0) {
                Add-Failure "M9S add resource control must use boss spell-id conditions, not fixed delay nodes"
            }

            $addWaits = @($addDescendants |
                Where-Object { $_.PSObject.Properties.Name -contains "TriggerConds" } |
                ForEach-Object { @($_.TriggerConds) } |
                Where-Object { $_.'$type' -eq "TriggerCondWaitTarget" -and [int]$_.DataId -eq 19170 }).Count
            if ($addWaits -lt 3) {
                Add-Failure "M9S add control expected at least three TriggerCondWaitTarget DataId=19170 gates, got $addWaits"
            }

            $addTargetSelections = @($addActions | Where-Object {
                $_.'$type' -eq "TriggerActionSelectenemy" -and [int]$_.TargetDataId -eq 19170
            }).Count
            if ($addTargetSelections -lt 3) {
                Add-Failure "M9S add control expected at least three add target selections, got $addTargetSelections"
            }

            foreach ($spellId in 45875, 45963, 45956) {
                if (@($addDescendants |
                    Where-Object { $_.PSObject.Properties.Name -contains "TriggerConds" } |
                    ForEach-Object { @($_.TriggerConds) } |
                    Where-Object { $_.'$type' -eq "TriggerCondEnemyCastSpell" -and [int]$_.SpellId -eq $spellId }).Count -lt 1) {
                    Add-Failure "M9S add control missing boss spell-id condition: $spellId"
                }
            }

            foreach ($actionName in @("StartDelayedBurstHold", "ReleaseDelayedBurstPackage", "ResetDelayedBurstPackage", "HoldAllBurst", "ReleaseDelayedBurst")) {
                if (@($addActions | Where-Object { $_.'$type' -eq "KairoMCHTimelineVariable" -and $_.Action -eq $actionName }).Count -gt 0) {
                    Add-Failure "M9S add control must not use delayed-burst package action: $actionName"
                }
            }

            Assert-TimelineActionTimedGate $addDescendants "HoldHeat" $true 45875 250000 282000 "first rod heat hold"
            Assert-TimelineActionTimedGate $addDescendants "DumpHeat" $true 45963 285000 299000 "first rod heat dump"
            Assert-TimelineActionTimedGate $addDescendants "HoldStrongGcd" $true 45956 300000 315000 "second rod strong GCD hold"
            Assert-TimelineActionTimedGate $addDescendants "DumpStrongGcd" $true 45963 300000 322000 "second rod strong GCD dump"
            Assert-TimelineActionTimedGate $addDescendants "DumpReassembleDrill" $true 45963 300000 322000 "second rod Reassemble dump"
            Assert-TimelineActionTimedGate $addDescendants "DumpHeat" $true 45963 325000 345000 "third rod heat dump"
            Assert-TimelineActionTimedGate $addDescendants "HoldStrongGcd" $false 45875 335000 365000 "post add cleanup"

            if (Find-TimelineActionTimedGate $addDescendants "HoldStrongGcd" $true 45875 250000 282000) {
                Add-Failure "M9S add control must not hold strong GCD on the first rod gate"
            }
            if (Find-TimelineActionTimedGate $addDescendants "DumpStrongGcd" $true 45963 285000 299000) {
                Add-Failure "M9S add control must not dump strong GCD on the first rod gate"
            }
            if (Find-TimelineActionTimedGate $addDescendants "DumpReassembleDrill" $true 45963 285000 299000) {
                Add-Failure "M9S add control must not dump Reassemble on the first rod gate"
            }
        }

        $mitigationNodes = @(Find-NodesByRemark $nodes "M9S mitigation axis")
        if ($mitigationNodes.Count -ne 1) {
            Add-Failure "M9S timeline must contain one mitigation node"
        }
        else {
            $mitigationDescendants = New-Object System.Collections.Generic.List[object]
            foreach ($node in @(Get-DescendantNodes $mitigationNodes[0])) {
                $mitigationDescendants.Add($node)
            }
            $mitigationActions = Get-ActionsFromNodes $mitigationDescendants

            if (@($mitigationDescendants | Where-Object { [string]$_.'$type' -eq "HiAuRo.Execution.TreeDelayNode, HiAuRo" }).Count -gt 0) {
                Add-Failure "M9S mitigation must use boss spell-id conditions, not fixed delay nodes"
            }

            $tacticianCount = @($mitigationActions | Where-Object {
                $_.'$type' -eq "KairoMCHHotkey" -and $_.Key -eq "Tactician"
            }).Count
            if ($tacticianCount -lt 5) {
                Add-Failure "M9S mitigation expected at least five Tactician hotkey actions, got $tacticianCount"
            }

            $dismantleCount = @($mitigationActions | Where-Object {
                $_.'$type' -eq "TriggerActionHighPrioritySlot" -and [int]$_.SpellId -eq 2887 -and [int]$_.TargetType -eq 1
            }).Count
            if ($dismantleCount -lt 4) {
                Add-Failure "M9S mitigation expected at least four Dismantle high-priority slots, got $dismantleCount"
            }

            $bossTargetSelections = @($mitigationActions | Where-Object {
                $_.'$type' -eq "TriggerActionSelectenemy" -and [int]$_.TargetDataId -eq 19167
            }).Count
            if ($bossTargetSelections -lt 4) {
                Add-Failure "M9S mitigation expected boss target selections before Dismantle, got $bossTargetSelections"
            }

            Assert-TimedEnemyCastGate $mitigationDescendants 45917 35000 60000 "first Brutal Rain mitigation"
            Assert-TimedEnemyCastGate $mitigationDescendants 45875 120000 145000 "second Sadistic Screech Tactician"
            Assert-TimedEnemyCastGate $mitigationDescendants 45888 160000 180000 "Finale Fatale Dismantle"
            Assert-TimedEnemyCastGate $mitigationDescendants 45917 240000 265000 "second Brutal Rain mitigation"
            Assert-TimedEnemyCastGate $mitigationDescendants 45875 340000 365000 "six-minute Sadistic Screech mitigation"
            Assert-TimedEnemyCastGate $mitigationDescendants 45984 440000 455000 "seven-minute Bat Deathmatch Tactician"
            Assert-TimedEnemyCastGate $mitigationDescendants 45917 485000 505000 "eight-minute Brutal Rain Dismantle"
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
        Add-Failure "M9S timeline must not leak old plugin API or field: $pattern"
    }
}

Assert-Contains $timelinePath '"\$type"\s*:\s*"HiAuRo\.Execution\.TreeRoot, HiAuRo"' "M9S timeline root must use HiAuRo TreeRoot"
Assert-Contains $timelinePath '"\$type"\s*:\s*"KairoMCHTimelineVariable"' "M9S timeline must use KairoMCHTimelineVariable"
Assert-Contains $timelinePath "M9S add" "M9S timeline note must document the add-control segment"
Assert-Contains $timelinePath "19170" "M9S timeline must document/add-select the rod add DataId"

if ($failures.Count -gt 0) {
    Write-Host "Machinist M9S timeline validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist M9S timeline validation passed."
