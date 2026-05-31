using OmenTools.Dalamud.Services.ObjectTable.Abstractions.ObjectKinds;
using ActionId = HiAuRo.Helper.MCHHelper.EN.Skills;
using StatusId = HiAuRo.Helper.MCHHelper.EN.Buffs;

namespace KairoHiAuRoACR.Jobs.Machinist;

public static class MachinistSpellHelper
{
    private const int OpeningBurstWindowMs = 20_000;
    private const int BioblasterRefreshSeconds = 3;
    private const int ReassembleSequenceLookaheadPaddingMs = 250;
    private const int QueenActiveEstimateMs = 15_000;
    private const int WildfirePackageDurationMs = 10_000;
    private const int HyperchargeBeforeWildfireWindowMs = 4_000;
    private const int WildfireBurstPackageLookaheadMs = 40_000;
    private const int WildfirePreGcdClipWindowMs = 1_000;
    private const int FullMetalWildfireWeaveReserveMs = 5_000;
    private const int Fixed120BurstPackageLeadMs = 2_500;
    private const int Fixed120BurstPackageTailMs = 18_000;
    private const int Fixed120BatteryHoldLeadMs = 30_000;
    private const int PreWildfireOvercapHeatThreshold = 100;
    private const int PreWildfireOvercapHyperchargeMinCooldownMs = 20_000;
    private const int PreWildfireOvercapHyperchargeMaxCooldownMs = 30_000;
    private const int ReassembleChargePressureMs = 8_000;
    private const int ReassembleRechargeMs = 55_000;
    private const int ReassembleBurstSafetyMs = 3_000;
    private const int ReassembleExcavatorReserveMs = 8_000;
    private const int ReassemblePendingTargetExpireMs = 4_500;
    private const float WeakTargetBurstHpThreshold = 0.12f;
    private const float DumpResourcesHpThreshold = 0.03f;

    private static readonly uint[] StrongGcdPriority =
    [
        ActionId.Excavator,
        ActionId.FullMetalField,
        ActionId.ChainSaw,
        ActionId.AirAnchor,
        ActionId.Drill,
    ];

    private static readonly uint[] Fixed120StrongGcdPriority =
    [
        ActionId.Drill,
        ActionId.AirAnchor,
        ActionId.ChainSaw,
        ActionId.Excavator,
        ActionId.FullMetalField,
    ];

    private static readonly uint[] ReassembleTargetPriority =
    [
        ActionId.Excavator,
        ActionId.ChainSaw,
        ActionId.Drill,
        ActionId.AirAnchor,
    ];

    private static MachinistSettings _settings = new();
    private static int _currentBattleTimeMs;
    private static long? _acrCombatClockStartedAtTick;
    private static int _acrCombatClockStartedAtBattleTimeMs;
    private static int? _firstPostOpenerBurstAnchorMs;
    private static int? _lastWildfirePackageStartedAtMs;
    private static int? _lastHyperchargePackageStartedAtMs;
    private static int? _lastFullMetalFieldStartedAtMs;
    private static int _robotActiveUntilMs;
    private static uint? _pendingReassembleTargetActionId;
    private static int _pendingReassembleTargetExpiresAtMs;
    private static uint _lastRecordedActionId;
    private static long _lastRecordedActionAtMs;
    private static readonly Dictionary<uint, int> CombatActionLastUsedAtMs = new();
    private static readonly Dictionary<uint, int> CombatActionUseCounts = new();

    public static void Configure(MachinistSettings settings)
    {
        _settings = settings;
    }

    public static void Reset()
    {
        _currentBattleTimeMs = 0;
        ResetCombatTracking();
    }

    private static void ResetCombatTracking()
    {
        _acrCombatClockStartedAtTick = null;
        _acrCombatClockStartedAtBattleTimeMs = 0;
        _firstPostOpenerBurstAnchorMs = null;
        _lastWildfirePackageStartedAtMs = null;
        _lastHyperchargePackageStartedAtMs = null;
        _lastFullMetalFieldStartedAtMs = null;
        _robotActiveUntilMs = 0;
        ClearPendingReassembleTarget();
        _lastRecordedActionId = 0;
        _lastRecordedActionAtMs = 0;
        CombatActionLastUsedAtMs.Clear();
        CombatActionUseCounts.Clear();
    }

    public static void UpdateBattleTime(int battleTimeMs)
    {
        var next = Math.Max(0, battleTimeMs);
        if (_currentBattleTimeMs > 5_000 && next <= 1_000)
            ResetCombatTracking();

        _currentBattleTimeMs = next;
    }

    public static void RecordCombatActionUse(uint actionId)
    {
        var now = Environment.TickCount64;
        if (_lastRecordedActionId == actionId && now - _lastRecordedActionAtMs < 250)
            return;

        if (ShouldResetStaleCombatTrackingOnPull(actionId))
            ResetCombatTracking();

        _lastRecordedActionId = actionId;
        _lastRecordedActionAtMs = now;

        StartAcrCombatClockIfNeeded(actionId, now);
        var actionBattleTimeMs = GetAcrBattleTimeMs(now);
        TrackBurstPackageAction(actionId, actionBattleTimeMs);
        CombatActionUseCounts[actionId] = CombatActionUseCounts.GetValueOrDefault(actionId) + 1;
        CombatActionLastUsedAtMs[actionId] = actionBattleTimeMs;

        if (_pendingReassembleTargetActionId == actionId)
            ClearPendingReassembleTarget();

        if (actionId is ActionId.AutomatonQueen or ActionId.RookAutoturret)
            _robotActiveUntilMs = actionBattleTimeMs + QueenActiveEstimateMs;

        if (actionId is ActionId.QueenOverdrive or ActionId.RookOverdrive or ActionId.Detonator)
            _robotActiveUntilMs = 0;
    }

    private static bool ShouldResetStaleCombatTrackingOnPull(uint actionId)
    {
        if (_currentBattleTimeMs > 2_000)
            return false;

        if (actionId != ActionId.Reassemble)
            return false;

        if (_acrCombatClockStartedAtTick is not null)
            return false;

        return CombatActionUseCounts.Count > 0
            || CombatActionLastUsedAtMs.Count > 0
            || _firstPostOpenerBurstAnchorMs is not null
            || _lastWildfirePackageStartedAtMs is not null
            || _lastHyperchargePackageStartedAtMs is not null
            || _lastFullMetalFieldStartedAtMs is not null
            || _robotActiveUntilMs > 0;
    }

    public static void MarkCombatActionIssued(uint actionId)
    {
        var now = Environment.TickCount64;
        StartAcrCombatClockIfNeeded(actionId, now);
        var actionBattleTimeMs = GetAcrBattleTimeMs(now);
        TrackBurstPackageAction(actionId, actionBattleTimeMs);
        CombatActionLastUsedAtMs[actionId] = actionBattleTimeMs;

        if (actionId is ActionId.AutomatonQueen or ActionId.RookAutoturret)
            _robotActiveUntilMs = actionBattleTimeMs + QueenActiveEstimateMs;

        if (actionId is ActionId.QueenOverdrive or ActionId.RookOverdrive or ActionId.Detonator)
            _robotActiveUntilMs = 0;
    }

    public static void AddIssuedSpell(Slot slot, Spell spell)
    {
        slot.Add(spell);
        MarkCombatActionIssued(spell.Id);
    }

    public static bool ShouldStopActions()
    {
        return QTHelper.IsEnabled(BuiltinQt.Hold);
    }

    public static bool IsOverheated()
    {
        return HelperRuntime.HasStatus(StatusId.Overheated);
    }

    public static bool IsRobotActive()
    {
        return _robotActiveUntilMs > GetAcrBattleTimeMs()
            || HelperRuntime.RecentlyUsedSpell(ActionId.AutomatonQueen, QueenActiveEstimateMs)
            || HelperRuntime.RecentlyUsedSpell(ActionId.RookAutoturret, QueenActiveEstimateMs);
    }

    public static int GetHeat() => MCHHelper.HeatGauge;

    public static int GetBattery() => MCHHelper.BatteryGauge;

    public static bool CanWeave(int minGcdCooldownMs = 650)
    {
        return GCDHelper.GetGCDCooldown() >= minGcdCooldownMs;
    }

    private static int GetAcrBattleTimeMs()
    {
        return GetAcrBattleTimeMs(Environment.TickCount64);
    }

    private static int GetAcrBattleTimeMs(long now)
    {
        if (_acrCombatClockStartedAtTick is null)
            return _currentBattleTimeMs;

        var elapsedMs = Math.Max(0, now - _acrCombatClockStartedAtTick.Value);
        return _acrCombatClockStartedAtBattleTimeMs + (int)Math.Min(int.MaxValue, elapsedMs);
    }

    private static void StartAcrCombatClockIfNeeded(uint actionId, long now)
    {
        if (_acrCombatClockStartedAtTick is not null)
            return;

        if (!ShouldStartAcrCombatClock(actionId))
            return;

        _acrCombatClockStartedAtTick = now;
        _acrCombatClockStartedAtBattleTimeMs = 0;
    }

    private static bool ShouldStartAcrCombatClock(uint actionId)
    {
        if (actionId == ActionId.Reassemble && _currentBattleTimeMs <= 0)
            return false;

        return IsCombatClockAction(actionId);
    }

    private static bool IsCombatClockAction(uint actionId)
    {
        return actionId is ActionId.Drill
            or ActionId.AirAnchor
            or ActionId.ChainSaw
            or ActionId.Excavator
            or ActionId.FullMetalField
            or ActionId.SplitShot
            or ActionId.SlugShot
            or ActionId.CleanShot
            or ActionId.HeatedSplitShot
            or ActionId.HeatedSlugShot
            or ActionId.HeatedCleanShot
            or ActionId.HeatBlast
            or ActionId.BlazingShot
            or ActionId.AutoCrossbow
            or ActionId.SpreadShot
            or ActionId.Scattergun
            or ActionId.Bioblaster
            or ActionId.Wildfire
            or ActionId.Hypercharge
            or ActionId.BarrelStabilizer
            or ActionId.AutomatonQueen
            or ActionId.RookAutoturret;
    }

    public static Spell? GetAoeGcd()
    {
        if (!HasTarget() || !QTHelper.IsEnabled(QTKey.Aoe))
            return null;

        if (ShouldHoldGcdForFixed120Queen())
            return null;

        if (HasReassembled())
            return GetReassembledAoeGcd();

        var fillerActionId = LevelAtLeast(82) ? ActionId.Scattergun : ActionId.SpreadShot;
        if (GetEnemyCountNearTarget(5f) < GetAoeFillerTargetThreshold(fillerActionId))
            return null;

        if (IsOverheated())
        {
            var autoCrossbow = BestAoeTargetSpell(ActionId.AutoCrossbow);
            if (autoCrossbow.IsReadyWithCanCast())
                return autoCrossbow;
        }

        if (ShouldUseBioblasterOnAoe())
            return BestAoeTargetSpell(ActionId.Bioblaster);

        var filler = BestAoeTargetSpell(fillerActionId);
        return filler.IsReadyWithCanCast() ? filler : null;
    }

    public static Spell? GetOverheatedGcd()
    {
        if (!HasTarget() || HasReassembled() || !IsOverheated())
            return null;

        var actionId = LevelAtLeast(92) ? ActionId.BlazingShot : ActionId.HeatBlast;
        var spell = TargetSpell(actionId);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetStrongGcd()
    {
        if (!HasTarget() || IsOverheated())
            return null;

        if (ShouldHoldGcdForFixed120Queen())
            return null;

        if (ShouldHoldStrongGcdForTimeline() && !ShouldDumpStrongGcdForTimeline())
            return null;

        if (HasReassembled())
            return GetReassembledStrongGcd();

        foreach (var actionId in GetStrongGcdPriority())
        {
            var spell = GetReadyStrongGcd(actionId);
            if (spell is not null)
                return spell;
        }

        return GetLowLevelHotShotGcd();
    }

    public static Spell? GetBaseComboGcd()
    {
        if (!HasTarget())
            return null;

        if (ShouldHoldGcdForFixed120Queen())
            return null;

        var lastCombo = HelperRuntime.GetLastComboSpellId();
        var baseAction = lastCombo switch
        {
            ActionId.SplitShot or ActionId.HeatedSplitShot => ActionId.SlugShot,
            ActionId.SlugShot or ActionId.HeatedSlugShot => ActionId.CleanShot,
            _ => ActionId.SplitShot,
        };

        var currentAction = HelperRuntime.GetActionChange(baseAction);
        var spell = TargetSpell(currentAction);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetWildfireOffGcd()
    {
        if (IsForbidBurstActive())
            return null;

        if (ShouldHoldWildfireForTimeline())
            return null;

        if (!HasTarget() || !CanUseWildfireBurstPackage())
            return null;

        if (!ShouldDumpWildfireForTimeline() && !CanUseWildfireBurstPackage())
            return null;

        if (ShouldDelayWildfireUntilHyperchargeForBurstPackage())
            return null;

        if (ShouldDelayWildfireForLateWeaveWindow())
            return null;

        if (ShouldDelayWildfireForBurstPackageTiming())
            return null;

        if (!CanWeave() && !ShouldPreGcdWildfireForBurstPackage())
            return null;

        var spell = TargetAbility(ActionId.Wildfire);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetBarrelStabilizerOffGcd()
    {
        if (IsForbidBurstActive())
            return null;

        if (ShouldHoldBarrelForTimeline())
            return null;

        if (!HasTarget() || (!ShouldDumpBarrelForTimeline() && !CanUseBurstResource() && !ShouldUseFixed120BurstPackage()) || !CanWeave())
            return null;

        var spell = SelfAbility(ActionId.BarrelStabilizer);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetHyperchargeOffGcd()
    {
        if (!HasTarget())
            return null;

        if (!CanWeave())
            return null;

        if (IsOverheated() || HasReassembled())
            return null;

        var hypercharge = SelfAbility(ActionId.Hypercharge);
        var hasHyperchargedReady = HelperRuntime.HasStatus(StatusId.Hypercharged);
        if (!hasHyperchargedReady && GetHeat() < 50)
            return null;

        if (!hypercharge.IsReadyWithCanCast())
            return null;

        if (IsForbidBurstActive())
            return null;

        var shouldUseActiveWildfireHypercharge = HasActiveWildfirePackage();
        var shouldUseFullMetalWildfireHypercharge = ShouldUseHyperchargeBeforeWildfirePackage();
        var shouldSpendHeatForBudget = ShouldSpendHeatByBudget();

        if (!shouldUseActiveWildfireHypercharge && ShouldHoldHeatForTimeline())
            return null;

        if (ShouldDumpHeatForTimeline())
            return hypercharge;

        if (!shouldUseActiveWildfireHypercharge && ShouldDelayHyperchargeForFullMetalFieldPackage())
            return null;

        if (!shouldUseFullMetalWildfireHypercharge
            && !shouldUseActiveWildfireHypercharge
            && ShouldDelayHyperchargeForWildfireBurstPackage())
            return null;

        if (!shouldUseFullMetalWildfireHypercharge
            && !shouldUseActiveWildfireHypercharge
            && ShouldFinishCleanShotComboBeforeHypercharge())
            return null;

        if (!shouldUseFullMetalWildfireHypercharge
            && !shouldUseActiveWildfireHypercharge
            && ShouldDelayHyperchargeForToolCooldown())
            return null;

        if (!shouldUseFullMetalWildfireHypercharge
            && !shouldUseActiveWildfireHypercharge
            && HasStrongGcdSoon(_settings.StrongGcdLookaheadMs)
            && !shouldSpendHeatForBudget
            && GetHeat() < _settings.HeatOvercapThreshold)
            return null;

        if (shouldUseFullMetalWildfireHypercharge
            || shouldUseActiveWildfireHypercharge
            || shouldSpendHeatForBudget
            || ShouldUseDumpResources()
            || IsForceBurstActive())
            return hypercharge;

        if (!shouldUseFullMetalWildfireHypercharge
            && !shouldUseActiveWildfireHypercharge
            && CanUseBurstResource())
            return hypercharge;

        if (CanUseResourceForOvercap() && GetHeat() >= _settings.HeatOvercapThreshold)
            return hypercharge;

        return null;
    }

    public static Spell? GetQueenOffGcd()
    {
        if (!HasTarget() || IsRobotActive() || !LevelAtLeast(40))
            return null;

        if (GetBattery() < _settings.BatteryBurstSpendThreshold)
            return null;

        if (IsForbidBurstActive())
            return null;

        if (ShouldReleaseBatteryForTimeline())
            return CanWeave(650) ? BuildQueenSpell() : null;

        var shouldSpendBatteryInFixed120Burst = ShouldSpendBatteryInFixed120Burst();
        var shouldSpendBatteryByBudget = ShouldSpendBatteryByBudget();
        var minWeaveMs = shouldSpendBatteryInFixed120Burst ? 0 : shouldSpendBatteryByBudget ? 650 : 800;
        if (!CanWeave(minWeaveMs))
            return null;

        if (ShouldHoldBatteryForTimeline())
            return null;

        if (ShouldHoldBatteryForFixed120Burst())
            return null;

        if (ShouldReserveFullMetalWildfireWeaves())
            return null;

        if (ShouldUseDumpResources() || IsForceBurstActive() || shouldSpendBatteryInFixed120Burst || shouldSpendBatteryByBudget || CanUseBurstResource())
            return BuildQueenSpell();

        return null;
    }

    public static Spell? GetQueenOverdriveOffGcd()
    {
        if (IsForbidBurstActive())
            return null;

        if (!HasTarget() || !IsRobotActive() || !(ShouldReleaseBatteryForTimeline() || ShouldUseDumpResources()) || !CanWeave())
            return null;

        var actionId = LevelAtLeast(80) ? ActionId.QueenOverdrive : ActionId.RookOverdrive;
        var spell = SelfAbility(actionId);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    public static Spell? GetReassembleOffGcd()
    {
        if (!HasTarget() || !CanWeave() || HasReassembled() || IsOverheated())
            return null;

        var reassemble = SelfAbility(ActionId.Reassemble);
        if (!reassemble.IsReadyWithCanCast())
            return null;

        var targetActionId = GetReassembleSequenceTargetActionId();
        if (targetActionId is null)
            return null;

        if (!WillNextGcdConsumeReassembleTarget(targetActionId.Value))
            return null;

        return reassemble;
    }

    public static uint? GetReassembleOffGcdTargetActionId()
    {
        if (!HasTarget() || !CanWeave() || HasReassembled() || IsOverheated())
            return null;

        var reassemble = SelfAbility(ActionId.Reassemble);
        if (!reassemble.IsReadyWithCanCast())
            return null;

        var targetActionId = GetReassembleSequenceTargetActionId();
        if (targetActionId is null)
            return null;

        if (!WillNextGcdConsumeReassembleTarget(targetActionId.Value))
            return null;

        return targetActionId;
    }

    public static void MarkReassembleOffGcdIssued(uint targetActionId)
    {
        _pendingReassembleTargetActionId = targetActionId;
        _pendingReassembleTargetExpiresAtMs = GetAcrBattleTimeMs() + ReassemblePendingTargetExpireMs;
        MarkCombatActionIssued(ActionId.Reassemble);
    }

    public static Spell? GetGaussRoundOffGcd()
    {
        if (!HasTarget() || !CanWeave())
            return null;

        var spell = PickGaussRoundOrRicochet();
        if (spell is null)
            return null;

        if (ShouldHoldCheckmateDoubleCheckForTimeline())
            return null;

        if (ShouldDumpCheckmateDoubleCheckForTimeline())
            return spell;

        if (ShouldReserveFullMetalWildfireWeaves())
            return null;

        if (IsOverheated() || ShouldUseDumpResources() || spell.Charges >= 2)
            return spell;

        if (TargetSpell(ActionId.Wildfire).IsReadyWithCanCast() && CanUseBurstResource())
            return null;

        return spell;
    }

    private static Spell TargetSpell(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Target);
    }

    private static Spell BestAoeTargetSpell(uint actionId)
    {
        return new Spell(actionId, () => GetBestAoeTarget(actionId));
    }

    private static IBattleChara GetBestAoeTarget(uint actionId)
    {
        return TargetHelper.GetMostCanTargetObjects(actionId, GetAoeFillerTargetThreshold(actionId), 5f)
            ?? GetCurrentTarget()!;
    }

    private static Spell TargetAbility(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Target) { Type = SpellType.Ability };
    }

    private static Spell SelfAbility(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Self) { Type = SpellType.Ability };
    }

    private static bool HasTarget()
    {
        return GetCurrentTarget() is not null;
    }

    private static IBattleChara? GetCurrentTarget()
    {
        return global::HiAuRo.Data.Target.Current is IBattleChara target
            && target.CurrentHp > 0
            && target.IsDead != true
            ? target
            : null;
    }

    private static bool LevelAtLeast(int level)
    {
        var currentLevel = HelperRuntime.GetCurrentLevel();
        return currentLevel <= 0 || currentLevel >= level;
    }

    private static bool HasReassembled()
    {
        return HelperRuntime.HasStatus(StatusId.Reassembled);
    }

    private static bool ShouldUseBioblasterOnAoe()
    {
        var target = GetBestAoeTarget(ActionId.Bioblaster);
        var spell = BestAoeTargetSpell(ActionId.Bioblaster);
        return spell.IsReadyWithCanCast()
            && (!target.HasMyAura(StatusId.Bioblaster)
                || target.GetAuraTimeLeft(StatusId.Bioblaster) <= BioblasterRefreshSeconds);
    }

    private static int GetEnemyCountNearTarget(float range)
    {
        var nearTarget = HelperRuntime.GetEnemyCountNearTarget(range);
        return nearTarget > 0 ? nearTarget : HelperRuntime.GetNearbyEnemyCount(range);
    }

    private static int GetAoeFillerTargetThreshold(uint actionId)
    {
        return actionId == ActionId.Scattergun ? 4 : 3;
    }

    private static Spell? GetReadyStrongGcd(uint actionId)
    {
        if (!IsStrongGcdAvailableByStatus(actionId))
            return null;

        var spell = TargetSpell(actionId);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    private static bool IsStrongGcdAvailableByStatus(uint actionId)
    {
        return actionId switch
        {
            ActionId.Excavator => HelperRuntime.HasStatus(StatusId.ExcavatorReady),
            ActionId.FullMetalField => HelperRuntime.HasStatus(StatusId.FullMetalMachinist),
            _ => true,
        };
    }

    private static Spell? GetLowLevelHotShotGcd()
    {
        if (LevelAtLeast(76))
            return null;

        var spell = TargetSpell(ActionId.HotShot);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    private static Spell? GetReassembledStrongGcd()
    {
        return GetReassembleTargetSpell() ?? GetLowLevelHotShotGcd();
    }

    private static bool CanUseBurstResource()
    {
        if (ShouldStopActions() || !HasTarget() || IsForbidBurstActive())
            return false;

        if (!QTHelper.IsEnabled(BuiltinQt.Burst))
            return false;

        if (ShouldUseDumpResources() || IsForceBurstActive())
            return true;

        if (ShouldUseTwoMinuteBurstPlan())
            return IsInTwoMinuteBurstWindow();

        return !ShouldHoldBurstForWeakTarget();
    }

    private static bool CanUseResourceForOvercap()
    {
        var hasBasePermission = !ShouldStopActions()
            && HasTarget()
            && QTHelper.IsEnabled(BuiltinQt.Burst)
            && !IsForbidBurstActive();
        if (!hasBasePermission)
            return false;

        if (ShouldUseDumpResources() || IsForceBurstActive())
            return true;

        if (ShouldUseTwoMinuteBurstPlan())
            return true;

        return !ShouldHoldBurstForWeakTarget();
    }

    private static bool ShouldUseTwoMinuteBurstPlan()
    {
        return _settings.IsHighEndMode;
    }

    private static bool IsInTwoMinuteBurstWindow()
    {
        if (IsForceBurstActive())
            return true;

        if (_currentBattleTimeMs <= OpeningBurstWindowMs)
            return true;

        return MachinistBurstPlanner.IsInBurstWindow(
            _currentBattleTimeMs,
            GetCurrentBurstAnchorMs(),
            _settings.BurstWindowLeadMs,
            _settings.BurstWindowTailMs);
    }

    private static bool ShouldUseFixed120BurstPackage()
    {
        if (ShouldStopActions() || !HasTarget() || IsForbidBurstActive())
            return false;

        if (!QTHelper.IsEnabled(BuiltinQt.Burst))
            return false;

        var battleTimeMs = GetAcrBattleTimeMs();
        if (battleTimeMs <= OpeningBurstWindowMs)
            return false;

        return MachinistBurstPlanner.IsInBurstWindow(
            battleTimeMs,
            _settings.FirstBurstAnchorMs,
            Fixed120BurstPackageLeadMs,
            Fixed120BurstPackageTailMs);
    }

    private static int GetCurrentBurstAnchorMs()
    {
        return _firstPostOpenerBurstAnchorMs ?? _settings.FirstBurstAnchorMs;
    }

    private static int GetTimeToNextTwoMinuteBurstAnchor()
    {
        return MachinistBurstPlanner.GetTimeToNextBurstAnchor(GetAcrBattleTimeMs(), GetCurrentBurstAnchorMs());
    }

    private static int GetTimeToNextTwoMinuteBurstWindow()
    {
        return MachinistBurstPlanner.GetTimeToNextBurstWindow(
            GetAcrBattleTimeMs(),
            GetCurrentBurstAnchorMs(),
            _settings.BurstWindowLeadMs,
            _settings.BurstWindowTailMs);
    }

    private static bool ShouldUseDumpResources()
    {
        return QTHelper.IsEnabled(QTKey.DumpResources)
            || IsTimelineVariableActive(MachinistTimelineVariable.DumpResources)
            || ShouldDumpResourcesByTargetHp();
    }

    private static bool ShouldUseDailyTargetHpPolicy()
    {
        return !_settings.IsHighEndMode;
    }

    private static float GetCurrentTargetHpPercent()
    {
        var target = GetCurrentTarget();
        if (target is null || target.MaxHp <= 0)
            return 0f;

        return (float)target.CurrentHp / target.MaxHp;
    }

    private static bool ShouldDumpResourcesByTargetHp()
    {
        if (!ShouldUseDailyTargetHpPolicy())
            return false;

        var target = GetCurrentTarget();
        if (target is null || target.MaxHp <= 0)
            return false;

        return (float)target.CurrentHp / target.MaxHp <= DumpResourcesHpThreshold;
    }

    private static bool ShouldHoldBurstForWeakTarget()
    {
        if (!ShouldUseDailyTargetHpPolicy())
            return false;

        var target = GetCurrentTarget();
        if (target is null || target.IsBoss())
            return false;

        return GetCurrentTargetHpPercent() <= WeakTargetBurstHpThreshold;
    }

    private static bool IsForceBurstActive()
    {
        return !IsForbidBurstActive()
            && (QTHelper.IsEnabled(QTKey.ForceBurst)
                || IsTimelineVariableActive(MachinistTimelineVariable.ForceBurst));
    }

    private static bool IsForbidBurstActive()
    {
        return QTHelper.IsEnabled(QTKey.ForbidBurst)
            || IsTimelineVariableActive(MachinistTimelineVariable.ForbidBurst);
    }

    public static void ReanchorBurstCycleToCurrentTime()
    {
        var battleTimeMs = GetAcrBattleTimeMs();
        if (battleTimeMs <= 0)
            return;

        _firstPostOpenerBurstAnchorMs = battleTimeMs;
    }

    private static void TrackBurstPackageAction(uint actionId, int actionBattleTimeMs)
    {
        if (actionId == ActionId.Wildfire)
            _lastWildfirePackageStartedAtMs = actionBattleTimeMs;

        if (actionId == ActionId.Hypercharge)
            _lastHyperchargePackageStartedAtMs = actionBattleTimeMs;

        if (actionId == ActionId.FullMetalField)
            _lastFullMetalFieldStartedAtMs = actionBattleTimeMs;
    }

    private static bool IsBaseComboAction(uint actionId)
    {
        return actionId is ActionId.SplitShot
            or ActionId.SlugShot
            or ActionId.CleanShot
            or ActionId.HeatedSplitShot
            or ActionId.HeatedSlugShot
            or ActionId.HeatedCleanShot;
    }

    private static bool HasActiveWildfirePackage()
    {
        if (_lastWildfirePackageStartedAtMs is not null
            && GetAcrBattleTimeMs() - _lastWildfirePackageStartedAtMs.Value <= WildfirePackageDurationMs)
            return true;

        return HelperRuntime.HasStatusOnTarget(StatusId.WildfireOnTarget)
            && HelperRuntime.GetStatusTimeLeftOnTarget(StatusId.WildfireOnTarget) > 0.5f;
    }

    private static bool HasRecentPreBurstHypercharge()
    {
        if (_lastHyperchargePackageStartedAtMs is null)
            return false;

        if (IsInTwoMinuteBurstWindow())
            return false;

        return GetAcrBattleTimeMs() - _lastHyperchargePackageStartedAtMs.Value <= MachinistResourcePlanner.PreBurstBudgetLookaheadMs;
    }

    private static bool ShouldSpendHeatByBudget()
    {
        var wildfireCooldown = IsActionUnlockedForCooldownLookahead(ActionId.Wildfire)
            ? TargetSpell(ActionId.Wildfire).CooldownMs
            : double.MaxValue;

        return MachinistResourcePlanner.ShouldSpendHeatBeforeBurst(
            GetHeat(),
            GetTimeToNextTwoMinuteBurstAnchor(),
            IsInTwoMinuteBurstWindow(),
            wildfireCooldown);
    }

    private static int GetProjectedHeatAtNextBurst()
    {
        return MachinistResourcePlanner.GetProjectedHeatAtNextBurst(GetHeat(), GetTimeToNextTwoMinuteBurstAnchor());
    }

    private static bool ShouldDelayWildfireUntilHyperchargeForBurstPackage()
    {
        if (ShouldUseDumpResources())
            return false;

        if (ShouldDumpWildfireForTimeline())
            return false;

        if (ShouldUseFixed120BurstPackage() && !HasRecentFullMetalFieldForWildfirePackage())
            return true;

        if (!HasRecentFullMetalFieldForWildfirePackage())
            return false;

        return !HasRecentHyperchargeForWildfirePackage();
    }

    private static bool ShouldDelayWildfireForLateWeaveWindow()
    {
        if (!HasRecentFullMetalFieldForWildfirePackage())
            return false;

        if (!HasRecentHyperchargeForWildfirePackage())
            return false;

        return !GCDHelper.Is2ndAbilityTime();
    }

    private static bool ShouldDelayHyperchargeForFullMetalFieldPackage()
    {
        if (!IsActionUnlockedForCooldownLookahead(ActionId.FullMetalField))
            return false;

        if (HasRecentFullMetalFieldForWildfirePackage())
            return false;

        if (!HelperRuntime.HasStatus(StatusId.FullMetalMachinist))
            return false;

        var fullMetalReady = TargetSpell(ActionId.FullMetalField).IsReadyWithCanCast();
        return !fullMetalReady || GetNextStrongGcdActionId() == ActionId.FullMetalField;
    }

    private static bool ShouldDelayHyperchargeForWildfireBurstPackage()
    {
        if (!IsActionUnlockedForCooldownLookahead(ActionId.Wildfire))
            return false;

        if (!CanUseResourceForOvercap())
            return false;

        if (!IsInTwoMinuteBurstWindow() && GetTimeToNextTwoMinuteBurstWindow() > WildfireBurstPackageLookaheadMs)
            return false;

        var wildfire = TargetSpell(ActionId.Wildfire);
        if (ShouldUseHyperchargeBeforeWildfirePackage())
            return false;

        if (HasActiveWildfirePackage())
            return false;

        if (wildfire.IsReadyWithCanCast())
            return true;

        if (CanSpendPreWildfireOvercapHypercharge(wildfire))
            return false;

        return wildfire.CooldownMs <= WildfireBurstPackageLookaheadMs;
    }

    private static bool CanSpendPreWildfireOvercapHypercharge(Spell wildfire)
    {
        if (HasRecentPreBurstHypercharge())
            return false;

        var shouldSpendHeatForBudget = MachinistResourcePlanner.ShouldSpendHeatBeforeBurst(
            GetHeat(),
            GetTimeToNextTwoMinuteBurstAnchor(),
            IsInTwoMinuteBurstWindow(),
            wildfire.CooldownMs);
        if (shouldSpendHeatForBudget && wildfire.CooldownMs >= PreWildfireOvercapHyperchargeMinCooldownMs)
            return true;

        if (GetHeat() < PreWildfireOvercapHeatThreshold)
            return false;

        if (IsInTwoMinuteBurstWindow())
            return false;

        if (wildfire.CooldownMs < PreWildfireOvercapHyperchargeMinCooldownMs)
            return false;

        if (wildfire.CooldownMs > PreWildfireOvercapHyperchargeMaxCooldownMs)
            return false;

        return true;
    }

    private static bool CanUseWildfireBurstPackage()
    {
        return ShouldDumpWildfireForTimeline() || CanUseBurstResource() || ShouldUseFixed120BurstPackage();
    }

    private static bool ShouldUseHyperchargeBeforeWildfirePackage()
    {
        if (!CanUseWildfireBurstPackage())
            return false;

        if (!HasRecentFullMetalFieldForWildfirePackage())
            return false;

        if (HasRecentHyperchargeForWildfirePackage())
            return false;

        var wildfire = TargetSpell(ActionId.Wildfire);
        return wildfire.IsReadyWithCanCast();
    }

    private static bool ShouldReserveFullMetalWildfireWeaves()
    {
        if (!HasRecentFullMetalFieldForWildfirePackage())
            return false;

        return !HasRecentHyperchargeForWildfirePackage()
            || !HasRecentWildfireForFullMetalPackage();
    }

    private static bool HasRecentFullMetalFieldForWildfirePackage()
    {
        return _lastFullMetalFieldStartedAtMs is not null
            && GetAcrBattleTimeMs() - _lastFullMetalFieldStartedAtMs.Value <= FullMetalWildfireWeaveReserveMs;
    }

    private static bool HasRecentHyperchargeForWildfirePackage()
    {
        return IsOverheated()
            || (_lastHyperchargePackageStartedAtMs is not null
                && GetAcrBattleTimeMs() - _lastHyperchargePackageStartedAtMs.Value <= HyperchargeBeforeWildfireWindowMs);
    }

    private static bool HasRecentWildfireForFullMetalPackage()
    {
        return _lastWildfirePackageStartedAtMs is not null
            && GetAcrBattleTimeMs() - _lastWildfirePackageStartedAtMs.Value <= FullMetalWildfireWeaveReserveMs;
    }

    private static bool ShouldDelayWildfireForBurstPackageTiming()
    {
        if (!CanUseWildfireBurstPackage())
            return false;

        return GCDHelper.GetGCDCooldown() > WildfirePreGcdClipWindowMs
            && GetNextStrongGcdActionId() == ActionId.FullMetalField;
    }

    private static bool ShouldPreGcdWildfireForBurstPackage()
    {
        if (!CanUseWildfireBurstPackage())
            return false;

        if (GCDHelper.GetGCDCooldown() > WildfirePreGcdClipWindowMs)
            return false;

        return GetNextStrongGcdActionId() == ActionId.FullMetalField;
    }

    public static bool ShouldHoldGcdForWildfireBurstPackage()
    {
        var wildfire = TargetSpell(ActionId.Wildfire);
        if (!CanUseWildfireBurstPackage())
            return false;

        if (ShouldUseFixed120BurstPackage())
            return false;

        if (GCDHelper.GetGCDCooldown() > WildfirePreGcdClipWindowMs)
            return false;

        var nextStrongGcdIsFullMetal = GetNextStrongGcdActionId() == ActionId.FullMetalField;
        if (!nextStrongGcdIsFullMetal)
            return false;

        return !wildfire.IsReadyWithCanCast()
            && wildfire.CooldownMs <= WildfirePreGcdClipWindowMs;
    }

    private static bool ShouldSpendBatteryByBudget()
    {
        if (GetBattery() >= _settings.BatteryOvercapSpendThreshold)
            return true;

        return MachinistResourcePlanner.ShouldSpendBatteryBeforeBurst(
            GetBattery(),
            GetTimeToNextTwoMinuteBurstAnchor());
    }

    private static bool ShouldHoldBatteryForFixed120Burst()
    {
        if (ShouldUseDumpResources() || IsForceBurstActive() || ShouldReleaseBatteryForTimeline())
            return false;

        if (GetBattery() < _settings.BatteryBurstSpendThreshold)
            return false;

        var battleTimeMs = GetAcrBattleTimeMs();
        if (battleTimeMs <= OpeningBurstWindowMs)
            return false;

        if (ShouldUseFixed120BurstPackage())
            return false;

        return MachinistBurstPlanner.GetTimeToNextBurstAnchor(battleTimeMs, _settings.FirstBurstAnchorMs)
            <= Fixed120BatteryHoldLeadMs;
    }

    private static bool ShouldSpendBatteryInFixed120Burst()
    {
        if (GetBattery() < _settings.BatteryBurstSpendThreshold)
            return false;

        return ShouldUseFixed120BurstPackage()
            && HasUsedCurrentFixed120BurstAction(ActionId.Drill)
            && !HasUsedCurrentFixed120BurstAction(ActionId.ChainSaw)
            && !HasUsedCurrentFixed120BurstAction(ActionId.AutomatonQueen)
            && !HasUsedCurrentFixed120BurstAction(ActionId.RookAutoturret);
    }

    private static bool ShouldHoldGcdForFixed120Queen()
    {
        return ShouldSpendBatteryInFixed120Burst()
            && !ShouldHoldBatteryForTimeline()
            && !IsRobotActive()
            && LevelAtLeast(40);
    }

    private static bool HasUsedCurrentFixed120BurstAction(uint actionId)
    {
        if (!CombatActionLastUsedAtMs.TryGetValue(actionId, out var lastUsedAtMs))
            return false;

        var currentAnchorMs = GetCurrentFixed120BurstAnchorMs();
        return lastUsedAtMs >= currentAnchorMs - Fixed120BurstPackageLeadMs
            && lastUsedAtMs <= currentAnchorMs + Fixed120BurstPackageTailMs;
    }

    private static int GetCurrentFixed120BurstAnchorMs()
    {
        var battleTimeMs = GetAcrBattleTimeMs();
        var anchor = _settings.FirstBurstAnchorMs;
        if (battleTimeMs <= anchor)
            return anchor;

        var cycles = (battleTimeMs - anchor) / MachinistBurstPlanner.BurstCycleMs;
        return anchor + cycles * MachinistBurstPlanner.BurstCycleMs;
    }

    public static bool IsTimelineHoldAllBurstActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.HoldAllBurst);
    }

    public static bool IsTimelineReleaseDelayedBurstActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.ReleaseDelayedBurst);
    }

    public static bool IsTimelineHoldWildfireActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.HoldWildfire);
    }

    public static bool IsTimelineDumpWildfireActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.DumpWildfire);
    }

    public static bool IsTimelineHoldBarrelActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.HoldBarrel);
    }

    public static bool IsTimelineDumpBarrelActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.DumpBarrel);
    }

    public static bool IsTimelineHoldCheckmateDoubleCheckActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.HoldCheckmateDoubleCheck);
    }

    public static bool IsTimelineDumpCheckmateDoubleCheckActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.DumpCheckmateDoubleCheck);
    }

    public static bool IsTimelineHoldBatteryActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.HoldBattery);
    }

    public static bool IsTimelineDumpBatteryActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.DumpBattery);
    }

    public static bool IsTimelineHoldHeatActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.HoldHeat);
    }

    public static bool IsTimelineDumpHeatActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.DumpHeat);
    }

    public static bool IsTimelineHoldStrongGcdActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.HoldStrongGcd);
    }

    public static bool IsTimelineDumpStrongGcdActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.DumpStrongGcd);
    }

    public static bool IsTimelineHoldReassembleDrillActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.HoldReassembleDrill);
    }

    public static bool IsTimelineDumpReassembleDrillActive()
    {
        return IsTimelineVariableActive(MachinistTimelineVariable.DumpReassembleDrill);
    }

    private static bool IsTimelineVariableActive(string variableName)
    {
        return MachinistTimelineState.IsActive(variableName);
    }

    public static bool ShouldHoldWildfireForTimeline()
    {
        return (IsTimelineHoldAllBurstActive() || IsTimelineHoldWildfireActive())
            && !ShouldDumpWildfireForTimeline();
    }

    public static bool ShouldDumpWildfireForTimeline()
    {
        return IsTimelineReleaseDelayedBurstActive() || IsTimelineDumpWildfireActive();
    }

    public static bool ShouldHoldBarrelForTimeline()
    {
        return (IsTimelineHoldAllBurstActive() || IsTimelineHoldBarrelActive())
            && !ShouldDumpBarrelForTimeline();
    }

    public static bool ShouldDumpBarrelForTimeline()
    {
        return IsTimelineReleaseDelayedBurstActive() || IsTimelineDumpBarrelActive();
    }

    public static bool ShouldHoldCheckmateDoubleCheckForTimeline()
    {
        return IsTimelineHoldCheckmateDoubleCheckActive()
            && !ShouldDumpCheckmateDoubleCheckForTimeline();
    }

    public static bool ShouldDumpCheckmateDoubleCheckForTimeline()
    {
        return ShouldUseDumpResources() || IsTimelineDumpCheckmateDoubleCheckActive();
    }

    public static bool ShouldHoldBatteryForTimeline()
    {
        if (IsTimelineHoldBatteryActive())
            return !ShouldReleaseBatteryForTimeline();

        return IsTimelineHoldAllBurstActive()
            && !ShouldReleaseBatteryForTimeline()
            && !ShouldSpendBatteryByBudget();
    }

    public static bool ShouldReleaseBatteryForTimeline()
    {
        return ShouldUseDumpResources() || IsTimelineReleaseDelayedBurstActive() || IsTimelineDumpBatteryActive();
    }

    public static bool ShouldHoldHeatForTimeline()
    {
        return (IsTimelineHoldAllBurstActive() || IsTimelineHoldHeatActive())
            && !ShouldDumpHeatForTimeline();
    }

    public static bool ShouldDumpHeatForTimeline()
    {
        return ShouldUseDumpResources() || IsTimelineReleaseDelayedBurstActive() || IsTimelineDumpHeatActive();
    }

    public static bool ShouldHoldStrongGcdForTimeline()
    {
        return (IsTimelineHoldAllBurstActive() || IsTimelineHoldStrongGcdActive())
            && !ShouldDumpStrongGcdForTimeline();
    }

    public static bool ShouldDumpStrongGcdForTimeline()
    {
        return ShouldUseDumpResources() || IsTimelineReleaseDelayedBurstActive() || IsTimelineDumpStrongGcdActive();
    }

    public static bool ShouldHoldReassembleDrillForTimeline()
    {
        return (ShouldHoldStrongGcdForTimeline() || IsTimelineHoldReassembleDrillActive())
            && !ShouldDumpReassembleDrillForTimeline();
    }

    public static bool ShouldDumpReassembleDrillForTimeline()
    {
        return ShouldDumpStrongGcdForTimeline() || IsTimelineDumpReassembleDrillActive();
    }

    private static bool ShouldFinishCleanShotComboBeforeHypercharge()
    {
        if (GetHeat() > _settings.HeatOvercapThreshold)
            return false;

        var lastCombo = HelperRuntime.GetLastComboSpellId();
        return lastCombo is ActionId.SlugShot or ActionId.HeatedSlugShot;
    }

    private static bool ShouldDelayHyperchargeForToolCooldown()
    {
        return IsToolCooldownWithin(ActionId.ChainSaw, _settings.HyperchargeToolCooldownLookaheadMs)
            || IsToolCooldownWithin(ActionId.AirAnchor, _settings.HyperchargeToolCooldownLookaheadMs);
    }

    private static bool IsToolCooldownWithin(uint actionId, int lookaheadMs)
    {
        if (!IsActionUnlockedForCooldownLookahead(actionId))
            return false;

        return TargetSpell(actionId).CooldownMs <= lookaheadMs;
    }

    private static bool IsActionUnlockedForCooldownLookahead(uint actionId)
    {
        return actionId switch
        {
            ActionId.Wildfire => LevelAtLeast(45),
            ActionId.Drill => LevelAtLeast(58),
            ActionId.AirAnchor => LevelAtLeast(76),
            ActionId.ChainSaw => LevelAtLeast(90),
            ActionId.Excavator => LevelAtLeast(96),
            ActionId.FullMetalField => LevelAtLeast(100),
            _ => true,
        };
    }

    private static bool HasStrongGcdSoon(int lookaheadMs)
    {
        return GetReassembleTargetActionId(lookaheadMs) is not null;
    }

    private static int GetReassembleSequenceLookaheadMs()
    {
        return (int)Math.Max(0, GCDHelper.GetGCDCooldown()) + ReassembleSequenceLookaheadPaddingMs;
    }

    private static uint? GetReassembleTargetActionId(int lookaheadMs)
    {
        var shouldForceSpend = ShouldSpendReassembleForChargePressure();
        var hasExcavatorTarget = IsReadyForReassembleTarget(ActionId.Excavator)
            || IsReassembleTargetWithin(ActionId.Excavator, lookaheadMs);
        if (hasExcavatorTarget)
            return ActionId.Excavator;

        if (!shouldForceSpend && !ShouldDumpReassembleDrillForTimeline() && ShouldReserveReassembleForNextBurstWindow())
            return null;

        if (!shouldForceSpend && !ShouldDumpReassembleDrillForTimeline() && ShouldReserveReassembleForExcavator())
            return null;

        if (!shouldForceSpend && ShouldHoldReassembleDrillForTimeline())
            return null;

        foreach (var actionId in ReassembleTargetPriority)
        {
            if (actionId == ActionId.Excavator)
                continue;

            if (!shouldForceSpend && !ShouldDumpReassembleDrillForTimeline() && ShouldReserveReassembleForCurrentBurstDrill(actionId, lookaheadMs))
                continue;

            if (IsReadyForReassembleTarget(actionId) || IsReassembleTargetWithin(actionId, lookaheadMs))
                return actionId;
        }

        return GetReassembleAoeTargetActionId(lookaheadMs, shouldForceSpend);
    }

    private static uint? GetReassembleSequenceTargetActionId()
    {
        return GetReassembleTargetActionId(GetReassembleSequenceLookaheadMs());
    }

    private static uint? GetReadyReassembleTargetActionId()
    {
        foreach (var actionId in ReassembleTargetPriority)
        {
            if (IsReadyForReassembleTarget(actionId))
                return actionId;
        }

        return null;
    }

    private static Spell? GetReassembleTargetSpell()
    {
        var pendingActionId = GetPendingReassembleTargetActionId();
        if (pendingActionId is not null && IsReadyForReassembleTarget(pendingActionId.Value))
            return TargetSpell(pendingActionId.Value);

        var actionId = GetReadyReassembleTargetActionId();
        return actionId is null ? null : TargetSpell(actionId.Value);
    }

    private static uint? GetPendingReassembleTargetActionId()
    {
        if (_pendingReassembleTargetActionId is null)
            return null;

        if (GetAcrBattleTimeMs() > _pendingReassembleTargetExpiresAtMs)
        {
            ClearPendingReassembleTarget();
            return null;
        }

        return _pendingReassembleTargetActionId;
    }

    private static void ClearPendingReassembleTarget()
    {
        _pendingReassembleTargetActionId = null;
        _pendingReassembleTargetExpiresAtMs = 0;
    }

    private static uint? GetReassembleAoeTargetActionId(int lookaheadMs, bool shouldForceSpend)
    {
        return ShouldUseReassembleOnScattergun(lookaheadMs, shouldForceSpend)
            ? ActionId.Scattergun
            : null;
    }

    private static bool ShouldUseReassembleOnScattergun(int lookaheadMs, bool shouldForceSpend)
    {
        if (!QTHelper.IsEnabled(QTKey.Aoe))
            return false;

        if (!LevelAtLeast(82))
            return false;

        if (GetEnemyCountNearTarget(5f) < GetAoeFillerTargetThreshold(ActionId.Scattergun))
            return false;

        if (!shouldForceSpend && !ShouldDumpReassembleDrillForTimeline())
            return false;

        return IsReadyForReassembleTarget(ActionId.Scattergun)
            || IsReassembleTargetWithin(ActionId.Scattergun, lookaheadMs);
    }

    private static bool ShouldSpendReassembleForChargePressure()
    {
        var reassemble = SelfAbility(ActionId.Reassemble);
        return reassemble.Charges >= 2
            || (reassemble.Charges > 0 && reassemble.CooldownMs <= ReassembleChargePressureMs);
    }

    private static bool ShouldReserveReassembleForNextBurstWindow()
    {
        if (IsInTwoMinuteBurstWindow())
            return false;

        return GetTimeToNextTwoMinuteBurstWindow()
            <= ReassembleRechargeMs + ReassembleBurstSafetyMs;
    }

    private static bool ShouldReserveReassembleForExcavator()
    {
        if (!IsActionUnlockedForCooldownLookahead(ActionId.Excavator))
            return false;

        if (CanRecoverReassembleBeforeNextBurstWindow())
            return false;

        var chainSaw = TargetSpell(ActionId.ChainSaw);
        return IsActionUnlockedForCooldownLookahead(ActionId.ChainSaw)
            && (chainSaw.IsReadyWithCanCast() || chainSaw.CooldownMs <= ReassembleExcavatorReserveMs);
    }

    private static bool IsReadyForReassembleTarget(uint actionId)
    {
        if (!IsActionUnlockedForCooldownLookahead(actionId))
            return false;

        if (!IsStrongGcdAvailableByStatus(actionId))
            return false;

        return TargetSpell(actionId).IsReadyWithCanCast();
    }

    private static bool ShouldReserveReassembleForCurrentBurstDrill(uint actionId, int lookaheadMs)
    {
        if (!IsInTwoMinuteBurstWindow())
            return false;

        if (HasActiveWildfirePackage())
            return false;

        if (actionId == ActionId.Drill)
            return false;

        return !(IsReadyForReassembleTarget(ActionId.Drill)
            || IsReassembleTargetWithin(ActionId.Drill, lookaheadMs));
    }

    private static bool CanRecoverReassembleBeforeNextBurstWindow()
    {
        if (IsInTwoMinuteBurstWindow())
            return false;

        return GetTimeToNextTwoMinuteBurstWindow() > ReassembleRechargeMs + ReassembleBurstSafetyMs;
    }

    private static bool IsReassembleTargetWithin(uint actionId, int lookaheadMs)
    {
        if (lookaheadMs <= 0 || !IsActionUnlockedForCooldownLookahead(actionId))
            return false;

        var remainingMs = GetTrackedReassembleTargetCooldownRemainingMs(actionId);
        return remainingMs is not null && remainingMs.Value <= lookaheadMs;
    }

    private static bool WillNextGcdConsumeReassembleTarget(uint actionId)
    {
        if (GetNextStrongGcdActionId() == actionId)
            return true;

        if (actionId == ActionId.Scattergun && GetReassembledAoeGcd() is not null)
            return true;

        var remainingMs = GetTrackedReassembleTargetCooldownRemainingMs(actionId);
        return remainingMs is not null && remainingMs.Value <= GCDHelper.GetGCDCooldown();
    }

    private static Spell? GetReassembledAoeGcd()
    {
        if (!QTHelper.IsEnabled(QTKey.Aoe) || !LevelAtLeast(82))
            return null;

        if (GetEnemyCountNearTarget(5f) < GetAoeFillerTargetThreshold(ActionId.Scattergun))
            return null;

        var spell = BestAoeTargetSpell(ActionId.Scattergun);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    private static uint? GetNextStrongGcdActionId()
    {
        foreach (var actionId in GetStrongGcdPriority())
        {
            if (GetReadyStrongGcd(actionId) is not null)
                return actionId;
        }

        return GetLowLevelHotShotGcd() is null ? null : ActionId.HotShot;
    }

    private static IReadOnlyList<uint> GetStrongGcdPriority()
    {
        return ShouldUseFixed120BurstPackage()
            ? Fixed120StrongGcdPriority
            : StrongGcdPriority;
    }

    private static int? GetTrackedReassembleTargetCooldownRemainingMs(uint actionId)
    {
        if (actionId == ActionId.Excavator && (HelperRuntime.HasStatus(StatusId.ExcavatorReady) || HasPendingExcavatorFollowUp()))
            return 0;

        if (!CombatActionLastUsedAtMs.TryGetValue(actionId, out var lastUsedAtMs))
            return null;

        var recastMs = actionId switch
        {
            ActionId.Drill => 20_000,
            ActionId.AirAnchor => 40_000,
            ActionId.ChainSaw => 60_000,
            _ => (int?)null,
        };

        return recastMs is null ? null : Math.Max(0, recastMs.Value - (GetAcrBattleTimeMs() - lastUsedAtMs));
    }

    private static bool HasPendingExcavatorFollowUp()
    {
        if (!CombatActionLastUsedAtMs.TryGetValue(ActionId.ChainSaw, out var lastChainSawUsedAtMs))
            return false;

        if (CombatActionLastUsedAtMs.TryGetValue(ActionId.Excavator, out var lastExcavatorUsedAtMs)
            && lastChainSawUsedAtMs <= lastExcavatorUsedAtMs)
            return false;

        return GetAcrBattleTimeMs() - lastChainSawUsedAtMs <= ReassemblePendingTargetExpireMs;
    }

    private static Spell? BuildQueenSpell()
    {
        var actionId = LevelAtLeast(80) ? ActionId.AutomatonQueen : ActionId.RookAutoturret;
        var spell = TargetAbility(actionId);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    private static Spell? PickGaussRoundOrRicochet()
    {
        var gaussRound = LevelAtLeast(92)
            ? TargetAbility(ActionId.DoubleCheck)
            : TargetAbility(ActionId.GaussRound);
        var ricochet = LevelAtLeast(92)
            ? TargetAbility(ActionId.Checkmate)
            : TargetAbility(ActionId.Ricochet);

        var gaussReady = gaussRound.IsReadyWithCanCast();
        var ricochetReady = ricochet.IsReadyWithCanCast();
        if (!gaussReady && !ricochetReady)
            return null;

        if (!ricochetReady)
            return gaussRound;

        if (!gaussReady)
            return ricochet;

        if (ShouldUseFixed120BurstPackage())
            return gaussRound;

        return gaussRound.Charges >= ricochet.Charges ? gaussRound : ricochet;
    }
}
