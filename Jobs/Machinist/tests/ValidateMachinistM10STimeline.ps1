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

function Assert-NotContains {
    param([string]$Path, [string]$Pattern, [string]$Message)

    $text = Read-File $Path
    if ($text -match $Pattern) {
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

$timelinePath = "Jobs/Machinist/docs/execution_timelines/M10S-MCH-execution.json"
$timelineText = Read-File $timelinePath

Assert-Contains "Jobs/Machinist/docs/DEVELOPMENT.md" "Jobs/Machinist/docs/execution_timelines/M10S-MCH-execution\.json" "Development docs must point to the concrete M10S HiAuRo execution-axis example"
Assert-Contains "Jobs/Machinist/docs/execution_axis_variables.md" "Jobs/Machinist/docs/execution_timelines/M10S-MCH-execution\.json" "Execution-axis authoring docs must point to the concrete M10S example"

if (-not [string]::IsNullOrWhiteSpace($timelineText)) {
    try {
        $timeline = $timelineText | ConvertFrom-Json
    }
    catch {
        Add-Failure "M10S timeline is not valid JSON: $($_.Exception.Message)"
        $timeline = $null
    }

    if ($null -ne $timeline) {
        if ($timeline.Name -ne "M10S-MCH-Execution") {
            Add-Failure "M10S execution-axis Name must be M10S-MCH-Execution"
        }
        if ($timeline.Author -ne "Kairo") {
            Add-Failure "M10S timeline Author must be Kairo"
        }
        if ($timeline.TargetAcrAuthor -ne "Kairo") {
            Add-Failure "M10S timeline TargetAcrAuthor must be Kairo"
        }
        if ($timeline.TargetJob -ne 31) {
            Add-Failure "M10S timeline TargetJob must be 31 for Machinist"
        }
        if ($timeline.TerritoryTypeId -ne 1323) {
            Add-Failure "M10S timeline TerritoryTypeId must be 1323"
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
                Add-Failure "M10S timeline missing exposed variable: $varName"
            }
        }

        $nodes = New-Object System.Collections.Generic.List[object]
        $actions = New-Object System.Collections.Generic.List[object]
        $conds = New-Object System.Collections.Generic.List[object]
        Walk-Node $timeline.TreeRoot $nodes $actions $conds

        foreach ($node in $nodes) {
            $type = [string]$node.'$type'
            if (-not $type.StartsWith("HiAuRo.Execution.Tree")) {
                Add-Failure "M10S timeline node must use HiAuRo execution type: $type"
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
                Add-Failure "M10S timeline missing trigger action type: $typeName"
            }
        }

        foreach ($typeName in @("TriggerCondAfterBattleStart", "TriggerCondEnemyCastSpell")) {
            if (@($conds | Where-Object { $_.'$type' -eq $typeName }).Count -lt 1) {
                Add-Failure "M10S timeline missing trigger condition type: $typeName"
            }
        }

        foreach ($actionName in @(
            "OpenerAirAnchorFirst",
            "StartDelayedBurstHold",
            "ReleaseDelayedBurstPackage",
            "ResetDelayedBurstPackage"
        )) {
            if (@($actions | Where-Object { $_.PSObject.Properties.Name -contains "Action" -and $_.Action -eq $actionName }).Count -lt 1) {
                Add-Failure "M10S timeline missing timeline action: $actionName"
            }
        }

        $rootParallel = @($timeline.TreeRoot.Childs)[0]
        if ($null -eq $rootParallel -or [string]$rootParallel.'$type' -ne "HiAuRo.Execution.TreeParallel, HiAuRo") {
            Add-Failure "M10S timeline root must contain one top-level TreeParallel node"
        }

        $openerNodes = @(Find-NodesByRemark $nodes "M10S Air Anchor first opener")
        if ($openerNodes.Count -ne 1) {
            Add-Failure "M10S timeline must contain one opener control node"
        }

        $waterNodes = @(Find-NodesByRemark $nodes "M10S water/surf delayed burst control")
        if ($waterNodes.Count -ne 1) {
            Add-Failure "M10S timeline must contain one water/surf delayed burst control node"
        }
        else {
            $waterDescendants = New-Object System.Collections.Generic.List[object]
            foreach ($node in @(Get-DescendantNodes $waterNodes[0])) {
                $waterDescendants.Add($node)
            }
            $waterActions = Get-ActionsFromNodes $waterDescendants
            foreach ($actionName in @("StartDelayedBurstHold", "ReleaseDelayedBurstPackage", "ResetDelayedBurstPackage")) {
                if (@($waterActions | Where-Object { $_.Action -eq $actionName }).Count -lt 1) {
                    Add-Failure "M10S water/surf control missing timeline action: $actionName"
                }
            }

            Assert-TimedEnemyCastGate $waterDescendants 46519 290000 322000 "water hold on Deep Impact"
            Assert-TimedEnemyCastGate $waterDescendants 46533 330000 355000 "surf starts on Xtreme Wave"
            Assert-TimedEnemyCastGate $waterDescendants 46520 386000 410000 "post-surf Divers Dare release"
            Assert-TimedEnemyCastGate $waterDescendants 46486 420000 445000 "delayed burst cleanup on Freaky Pyrotation"

            $waterSpellIds = @($waterDescendants |
                Where-Object { $_.PSObject.Properties.Name -contains "TriggerConds" } |
                ForEach-Object { @($_.TriggerConds) } |
                Where-Object { $_.'$type' -eq "TriggerCondEnemyCastSpell" } |
                ForEach-Object { [int]$_.SpellId })

            foreach ($spellId in 46519, 46533, 46534, 46535, 46536, 44487, 46520, 46521, 46486) {
                if ($waterSpellIds -notcontains $spellId) {
                    Add-Failure "M10S water/surf control missing boss spell-id condition: $spellId"
                }
            }
        }

        $mitigationNodes = @(Find-NodesByRemark $nodes "M10S mitigation axis")
        if ($mitigationNodes.Count -ne 1) {
            Add-Failure "M10S timeline must contain one mitigation node"
        }
        else {
            $mitigationDescendants = New-Object System.Collections.Generic.List[object]
            foreach ($node in @(Get-DescendantNodes $mitigationNodes[0])) {
                $mitigationDescendants.Add($node)
            }
            $mitigationActions = Get-ActionsFromNodes $mitigationDescendants

            $tacticianCount = @($mitigationActions | Where-Object {
                $_.'$type' -eq "KairoMCHHotkey" -and $_.Key -eq "Tactician"
            }).Count
            if ($tacticianCount -lt 4) {
                Add-Failure "M10S mitigation expected at least four Tactician hotkey actions, got $tacticianCount"
            }

            $dismantleCount = @($mitigationActions | Where-Object {
                $_.'$type' -eq "TriggerActionHighPrioritySlot" -and [int]$_.SpellId -eq 2887 -and [int]$_.TargetType -eq 1
            }).Count
            if ($dismantleCount -lt 4) {
                Add-Failure "M10S mitigation expected at least four Dismantle high-priority slots, got $dismantleCount"
            }

            $bossTargetSelections = @($mitigationActions | Where-Object {
                $_.'$type' -eq "TriggerActionSelectenemy" -and ([int]$_.TargetDataId -eq 19287 -or [int]$_.TargetDataId -eq 19288)
            }).Count
            if ($bossTargetSelections -lt 4) {
                Add-Failure "M10S mitigation expected boss target selections before Dismantle, got $bossTargetSelections"
            }

            Assert-TimedEnemyCastGate $mitigationDescendants 46530 58000 70000 "first Pyrotation Dismantle"
            Assert-TimedEnemyCastGate $mitigationDescendants 46520 70000 85000 "first Divers Dare Tactician"
            Assert-TimedEnemyCastGate $mitigationDescendants 46500 155000 170000 "Xtreme Spectacular Tactician"
            Assert-TimedEnemyCastGate $mitigationDescendants 46520 218000 232000 "second Divers Dare Dismantle"
            Assert-TimedEnemyCastGate $mitigationDescendants 46519 300000 318000 "water Deep Impact Tactician"
            Assert-TimedEnemyCastGate $mitigationDescendants 46520 390000 405000 "post-surf Divers Dare Dismantle"
            Assert-TimedEnemyCastGate $mitigationDescendants 46510 460000 472000 "late Xtreme Firesnaking Tactician"
            Assert-TimedEnemyCastGate $mitigationDescendants 46520 518000 530000 "final Divers Dare Dismantle"
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
    "JobViewWindow"
)) {
    if ($timelineText -match $pattern) {
        Add-Failure "M10S timeline must not leak old plugin API or field: $pattern"
    }
}

Assert-Contains $timelinePath '"\$type"\s*:\s*"HiAuRo\.Execution\.TreeRoot, HiAuRo"' "M10S timeline root must use HiAuRo TreeRoot"
Assert-Contains $timelinePath '"\$type"\s*:\s*"KairoMCHTimelineVariable"' "M10S timeline must use KairoMCHTimelineVariable"
Assert-Contains $timelinePath '"Action"\s*:\s*"OpenerAirAnchorFirst"' "M10S timeline must enable Air Anchor first opener"
Assert-Contains $timelinePath "Air Anchor -> Drill -> Chain Saw" "M10S timeline note must document the opener variant"
Assert-Contains $timelinePath "water/surf" "M10S timeline note must document the delayed burst segment"

if ($failures.Count -gt 0) {
    Write-Host "Machinist M10S timeline validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }
    exit 1
}

Write-Host "Machinist M10S timeline validation passed."
