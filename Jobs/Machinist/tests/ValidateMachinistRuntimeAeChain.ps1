param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path,
    [string]$RuntimeRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..\HiAuRo-master\HiAuRo")).Path
)

$ErrorActionPreference = "Stop"
$failures = New-Object System.Collections.Generic.List[string]

function Read-RepoFile {
    param([string]$Path)

    $fullPath = Join-Path $Root $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $failures.Add("Missing repo file: $Path")
        return ""
    }

    return Get-Content -LiteralPath $fullPath -Raw -Encoding utf8
}

function Read-RuntimeFile {
    param([string]$Path)

    $fullPath = Join-Path $RuntimeRoot $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $failures.Add("Missing runtime file: $Path")
        return ""
    }

    return Get-Content -LiteralPath $fullPath -Raw -Encoding utf8
}

function Assert-ContainsText {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        $failures.Add($Message)
    }
}

function Assert-NotContainsText {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -match $Pattern) {
        $failures.Add($Message)
    }
}

function Assert-InOrderText {
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

function Assert-RuntimeFileNotExists {
    param(
        [string]$Path,
        [string]$Message
    )

    if (Test-Path -LiteralPath (Join-Path $RuntimeRoot $Path)) {
        $failures.Add("$Message ($Path)")
    }
}

$acrLifecycle = Read-RuntimeFile "Runtime/ACRLifecycle.cs"
$countdown = Read-RuntimeFile "Runtime/CountDownHandler.cs"
$openerMgr = Read-RuntimeFile "ACR/OpenerMgr.cs"
$slotExecutor = Read-RuntimeFile "Runtime/SlotExecutor.cs"
$battleData = Read-RuntimeFile "Runtime/BattleData.cs"
$calSlot = Read-RuntimeFile "Runtime/AIRunner.CalSlot.cs"

Assert-RuntimeFileNotExists "Runtime/AIRunner.DecisionStage.cs" "Runtime must not keep old AIRunner.DecisionStage.cs"
Assert-RuntimeFileNotExists "Runtime/AIRunner.ExecutionStage.cs" "Runtime must not keep old AIRunner.ExecutionStage.cs"
Assert-RuntimeFileNotExists "Runtime/PrioritySlotStack.cs" "Runtime must not keep old PrioritySlotStack.cs"

Assert-InOrderText $acrLifecycle @(
    "runner.Refresh(state);",
    "runner.UpdateCountDown();",
    "runner.AiLoop.Update(runner);"
) "Runtime ACRLifecycle.Update must flow Refresh -> UpdateCountDown -> AiLoop.Update"

Assert-ContainsText $calSlot "CalSlotAsync\(\)" "Runtime must expose AIRunner.CalSlot CalSlotAsync"
Assert-ContainsText $calSlot "CheckNextSlot\(bd\)" "CalSlot must consume BattleData.NextSlot before normal slots"
Assert-ContainsText $calSlot "HandleSlotSequence\(bd\)" "CalSlot must route opener/sequence execution through SlotExecutor"
Assert-ContainsText $calSlot "ResolveSlots\(bd,\s*1\)" "CalSlot must resolve GCD mode separately"
Assert-ContainsText $calSlot "ResolveSlots\(bd,\s*2\)" "CalSlot must resolve oGCD mode separately"

Assert-ContainsText $battleData "HighPrioritySlots_GCD" "BattleData must expose GCD high-priority queue"
Assert-ContainsText $battleData "HighPrioritySlots_OffGCD" "BattleData must expose oGCD high-priority queue"
Assert-ContainsText $battleData "NextSlot" "BattleData must own countdown/time-axis NextSlot"
Assert-ContainsText $battleData "CurrSequence" "BattleData must own the current opener/slot sequence"
Assert-ContainsText $battleData "AddSpell2NextSlot\(Spell spell\)" "BattleData must expose AddSpell2NextSlot for CountDownHandler"

Assert-ContainsText $countdown "Update\(BattleData battleData\)" "CountDownHandler must update against Runtime BattleData"
Assert-ContainsText $countdown "battleData\.AddSpell2NextSlot\(spell\)" "CountDownHandler must enqueue countdown spells through BattleData.NextSlot"
Assert-NotContainsText $countdown "PrioritySlotStack" "CountDownHandler must not use old PrioritySlotStack"

Assert-ContainsText $openerMgr "UseOpener\(Runtime\.BattleData battleData,\s*Rotation\? rotation\)" "OpenerMgr must receive BattleData and Rotation"
Assert-ContainsText $openerMgr "battleData\.PushSequence" "OpenerMgr must push IOpener into BattleData.CurrSequence"
Assert-NotContainsText $openerMgr "CurrentState|PeekCurrentSlot" "OpenerMgr must not use old CurrentState/PeekCurrentSlot state"

Assert-ContainsText $slotExecutor "HandleSlotSequence\(BattleData bd\)" "SlotExecutor must own sequence execution"
Assert-ContainsText $slotExecutor "CountDownHandler\.Instance\.CanDoAction" "SlotExecutor must start opener only after countdown can act"
Assert-ContainsText $slotExecutor "OpenerMgr\.Instance\.UseOpener\(bd,\s*rot\)" "SlotExecutor must push opener through OpenerMgr"
Assert-ContainsText $slotExecutor "1 => item\.Mode is SlotMode\.Gcd or SlotMode\.Always" "SlotExecutor must route GCD resolvers by SlotMode"
Assert-ContainsText $slotExecutor "2 => item\.Mode is SlotMode\.OffGcd or SlotMode\.Always" "SlotExecutor must route oGCD resolvers by SlotMode"

$machinistDev = Read-RepoFile "Jobs/Machinist/docs/DEVELOPMENT.md"
$machinistCompliance = Read-RepoFile "Jobs/Machinist/docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md"
$rootDev = Read-RepoFile "docs/DEVELOPMENT.md"
$rootCompliance = Read-RepoFile "docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md"
$machinistPortTest = Read-RepoFile "Jobs/Machinist/tests/ValidateMachinistPort.ps1"
$machinistOpener = Read-RepoFile "Jobs/Machinist/Opener/MachinistOpener.cs"
$machinistEntry = Read-RepoFile "Jobs/Machinist/MachinistRotationEntry.cs"

foreach ($doc in @(
    @{ Name = "Jobs/Machinist/docs/DEVELOPMENT.md"; Text = $machinistDev },
    @{ Name = "Jobs/Machinist/docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md"; Text = $machinistCompliance },
    @{ Name = "docs/DEVELOPMENT.md"; Text = $rootDev },
    @{ Name = "docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md"; Text = $rootCompliance }
)) {
    Assert-ContainsText $doc.Text "CalSlot|AiLoop\.Update" "$($doc.Name) must describe the new CalSlot/AiLoop runtime chain"
    Assert-ContainsText $doc.Text "BattleData\.CurrSequence|CurrSequence" "$($doc.Name) must describe opener sequences living in BattleData.CurrSequence"
    Assert-ContainsText $doc.Text "AddSpell2NextSlot|NextSlot" "$($doc.Name) must describe countdown spells entering BattleData.NextSlot"
    Assert-ContainsText $doc.Text "HighPrioritySlots_GCD|HighPrioritySlots_OffGCD|GCD/oGCD" "$($doc.Name) must describe AE-style GCD/oGCD split queues"
    Assert-NotContainsText $doc.Text "PrioritySlotStack|AIRunner\.DecisionStage|AIRunner\.ExecutionStage|SlotExecutor\.StartSlot|ExecuteStep|Runtime v0\.1\.90" "$($doc.Name) must not keep old runtime pipeline wording"
}

Assert-ContainsText $machinistPortTest "BattleData\.CurrSequence|CurrSequence" "MCH port validation must assert the new opener sequence contract"
Assert-ContainsText $machinistPortTest "AddSpell2NextSlot|NextSlot" "MCH port validation must assert the new countdown NextSlot contract"
Assert-ContainsText $machinistPortTest "CalSlot|AiLoop\.Update" "MCH port validation must assert the new CalSlot runtime contract"
Assert-NotContainsText $machinistPortTest "Runtime v0\.1\.90|PrioritySlotStack|CurrentState/PeekCurrentSlot" "MCH port validation must not keep old runtime-version assumptions"

Assert-ContainsText $machinistOpener "InitCountDown\(CountDownHandler\s+handler\)" "MCH opener must stay on public IOpener/CountDownHandler contract"
Assert-ContainsText $machinistOpener "handler\.AddAction\(4_000,\s*\(\)\s*=>" "MCH opener must register prepull Reassemble through CountDownHandler"
Assert-ContainsText $machinistOpener "public\s+List<Action<Slot>>\s+Sequence\s*=>\s*_activeSequence\s*\?\?=\s*BuildSequence\(\)" "MCH opener must expose one executable Sequence snapshot"
Assert-ContainsText $machinistOpener "_activeSequence\s*=\s*BuildSequence\(\)" "MCH opener StartCheck must snapshot Sequence before Runtime pushes CurrSequence"
Assert-NotContainsText $machinistOpener "BattleData|AddSpell2NextSlot|CurrSequence|PrioritySlotStack|CurrentState|PeekCurrentSlot" "MCH opener must not directly couple to Runtime BattleData internals"

Assert-ContainsText $machinistEntry "Mode = SlotMode\.Gcd" "MCH rotation must keep GCD resolvers in SlotMode.Gcd"
Assert-ContainsText $machinistEntry "Mode = SlotMode\.OffGcd" "MCH rotation must keep oGCD resolvers in SlotMode.OffGcd"

if ($failures.Count -gt 0) {
    Write-Host "Machinist Runtime AE-chain validation failed:"
    foreach ($failure in $failures) {
        Write-Host " - $failure"
    }

    exit 1
}

Write-Host "Machinist Runtime AE-chain validation passed."
