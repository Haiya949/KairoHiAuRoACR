using KairoHiAuRoACR.Jobs.BlackMage.Data;
using OmenTools.Dalamud.Services.ObjectTable.Abstractions.ObjectKinds;

namespace KairoHiAuRoACR.Jobs.BlackMage;

public static class BlackMageSpellHelper
{
    private const int MaxAstralSoulStacks = 6;
    private const int MaxElementalStacks = 3;
    private const int MaxPolyglotStacks = 3;
    private const int FireParadoxAstralSoulFloor = 3;
    private const int OpeningManafontFireIVCount = 5;
    private const int OpeningTotalFireIVCount = 12;
    private const int OpeningFlareStarCount = 2;
    private const int OpeningLeyLinesEarliestMs = 2_500;
    private const int OpeningLeyLinesLatestMs = 8_000;
    private const int PolyglotBurstHoldLeadMs = 10_000;
    private const int PolyglotOvercapReserveMs = 3_000;
    private const int AoeFireEntryMpThreshold = 6_000;
    private const int SwiftcastIceTransitionWaitMs = 500;

    private static readonly HashSet<uint> GcdActions =
    [
        BlackMageActionId.Fire,
        BlackMageActionId.Blizzard,
        BlackMageActionId.Thunder,
        BlackMageActionId.FireII,
        BlackMageActionId.ThunderII,
        BlackMageActionId.FireIII,
        BlackMageActionId.ThunderIII,
        BlackMageActionId.BlizzardIII,
        BlackMageActionId.Scathe,
        BlackMageActionId.Freeze,
        BlackMageActionId.Flare,
        BlackMageActionId.BlizzardIV,
        BlackMageActionId.FireIV,
        BlackMageActionId.ThunderIV,
        BlackMageActionId.Foul,
        BlackMageActionId.Despair,
        BlackMageActionId.UmbralSoul,
        BlackMageActionId.Xenoglossy,
        BlackMageActionId.BlizzardII,
        BlackMageActionId.HighFireII,
        BlackMageActionId.HighBlizzardII,
        BlackMageActionId.Paradox,
        BlackMageActionId.HighThunder,
        BlackMageActionId.HighThunderII,
        BlackMageActionId.FlareStar,
    ];

    private static BlackMageSettings _settings = new();
    private static int _currentBattleTimeMs;
    private static uint _lastCombatGcdActionId;
    private static int? _lastLeyLinesUseMs;
    private static bool _openingManafontQueued;
    private static readonly Dictionary<uint, int> CombatActionUseCounts = new();

    public static void Configure(BlackMageSettings settings)
    {
        _settings = settings;
    }

    public static void Reset()
    {
        _currentBattleTimeMs = 0;
        _lastCombatGcdActionId = 0;
        _lastLeyLinesUseMs = null;
        _openingManafontQueued = false;
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
        CombatActionUseCounts[actionId] = GetCombatActionUseCount(actionId) + 1;

        if (actionId == BlackMageActionId.LeyLines)
            _lastLeyLinesUseMs = _currentBattleTimeMs;

        if (GcdActions.Contains(actionId))
            _lastCombatGcdActionId = actionId;
    }

    public static bool ShouldStopActions()
    {
        return QTHelper.IsEnabled(BuiltinQt.Hold);
    }

    public static bool ShouldUseOpenerSequence()
    {
        if (ShouldStopActions() || !HasTarget() || !LevelAtLeast(100))
            return false;

        if (GetCombatActionUseCount(BlackMageActionId.HighThunder) > 0 ||
            GetCombatActionUseCount(BlackMageActionId.FireIV) > 0 ||
            GetCombatActionUseCount(BlackMageActionId.LeyLines) > 0)
            return false;

        return TargetSpell(BlackMageActionId.HighThunder).IsReadyWithCanCast() ||
               TargetSpell(BlackMageActionId.FireIV).IsReadyWithCanCast();
    }

    public static Spell? GetOpeningHighThunderGcd()
    {
        if (GetCombatActionUseCount(BlackMageActionId.HighThunder) > 0)
            return null;

        return ReadyTargetSpell(BlackMageActionId.HighThunder);
    }

    public static Spell? GetOpeningFireIvGcd()
    {
        if (GetCombatActionUseCount(BlackMageActionId.FireIV) > 0)
            return null;

        return ReadyTargetSpell(BlackMageActionId.FireIV);
    }

    public static Spell? GetSingleTargetGcd()
    {
        if (!HasTarget())
            return null;

        if (ShouldUseMovementTools())
        {
            var movement = GetMovementGcd();
            if (movement is not null)
                return movement;
        }

        if (IsAstralFireActive())
            return GetAstralFireGcd();

        if (IsUmbralIceActive())
            return GetUmbralIceGcd();

        var thunder = GetThunderGcd();
        if (thunder is not null)
            return thunder;

        return GetNeutralElementGcd() ?? ReadyTargetSpell(BlackMageActionId.Scathe);
    }

    public static Spell? GetAoeGcd()
    {
        if (!ShouldUseAoe())
            return null;

        var thunder = GetAoeThunderGcd();
        if (thunder is not null)
            return thunder;

        if (IsAstralFireActive())
        {
            var flareStar = GetFlareStarGcd();
            if (flareStar is not null)
                return flareStar;

            return ReadyTargetSpell(BlackMageActionId.Flare) ??
                   GetPolyglotGcd(true);
        }

        if (IsUmbralIceActive())
        {
            if ((GetUmbralHearts() < MaxElementalStacks || CurrentMp() < AoeFireEntryMpThreshold) &&
                IsActionUsable(BlackMageActionId.Freeze))
            {
                var freeze = ReadyTargetSpell(BlackMageActionId.Freeze);
                if (freeze is not null)
                    return freeze;
            }

            if (CurrentMp() >= AoeFireEntryMpThreshold)
                return ReadyTargetSpell(BlackMageActionId.Flare);

            return GetPolyglotGcd(true);
        }

        return ReadyTargetSpell(BlackMageActionId.Freeze) ?? GetPolyglotGcd(true);
    }

    private static Spell? GetAstralFireGcd()
    {
        var thunder = GetThunderGcd();
        if (thunder is not null)
            return thunder;

        var fireParadox = GetFireParadoxGcd();
        if (fireParadox is not null)
            return fireParadox;

        var polyglot = GetPolyglotGcd(false);
        if (polyglot is not null)
            return polyglot;

        var flareStar = GetFlareStarGcd();
        if (flareStar is not null)
            return flareStar;

        var fireIv = ReadyTargetSpell(BlackMageActionId.FireIV);
        if (fireIv is not null)
            return fireIv;

        var despair = GetDespairGcd();
        if (despair is not null)
            return despair;

        if (ShouldSwitchToUmbralIce())
            return ReadyTargetSpell(BlackMageActionId.BlizzardIII);

        return ReadyTargetSpell(BlackMageActionId.FireIII) ??
               ReadyTargetSpell(BlackMageActionId.Fire);
    }

    private static Spell? GetUmbralIceGcd()
    {
        var recovery = GetUmbralRecoveryGcd();
        if (recovery is not null)
            return recovery;

        var thunder = GetThunderGcd();
        if (thunder is not null)
            return thunder;

        var paradox = GetUmbralParadoxGcd();
        if (paradox is not null)
            return paradox;

        var fireEntry = GetUmbralFireEntryGcd();
        if (fireEntry is not null)
            return fireEntry;

        return ReadyTargetSpell(BlackMageActionId.BlizzardIII) ??
               ReadySelfSpell(BlackMageActionId.UmbralSoul);
    }

    private static Spell? GetNeutralElementGcd()
    {
        if (CurrentMp() >= 2_400)
            return ReadyTargetSpell(BlackMageActionId.FireIII);

        return ReadyTargetSpell(BlackMageActionId.BlizzardIII);
    }

    private static Spell? GetUmbralRecoveryGcd()
    {
        if (GetUmbralIceStacks() < MaxElementalStacks)
        {
            var blizzardIII = ReadyTargetSpell(BlackMageActionId.BlizzardIII);
            if (blizzardIII is not null)
                return blizzardIII;
        }

        if (GetUmbralHearts() < MaxElementalStacks)
        {
            var blizzardIV = ReadyTargetSpell(BlackMageActionId.BlizzardIV);
            if (blizzardIV is not null)
                return blizzardIV;
        }

        return null;
    }

    private static Spell? GetUmbralParadoxGcd()
    {
        return IsParadoxReady() ? ReadyTargetSpell(BlackMageActionId.Paradox) : null;
    }

    private static Spell? GetUmbralFireEntryGcd()
    {
        if (!ShouldSwitchToAstralFire())
            return null;

        return ReadyTargetSpell(BlackMageActionId.FireIII);
    }

    private static Spell? GetFireParadoxGcd()
    {
        if (!IsParadoxReady())
            return null;

        if (GetAstralFireStacks() < MaxElementalStacks && !HasFirestarter())
            return ReadyTargetSpell(BlackMageActionId.Paradox);

        if (GetAstralSoulStacks() >= FireParadoxAstralSoulFloor)
            return ReadyTargetSpell(BlackMageActionId.Paradox);

        return null;
    }

    private static Spell? GetThunderGcd()
    {
        if (!ShouldRefreshThunder())
            return null;

        return ReadyTargetSpell(BlackMageActionId.HighThunder);
    }

    private static Spell? GetAoeThunderGcd()
    {
        if (!ShouldRefreshAoeThunder())
            return null;

        return ReadyTargetSpell(BlackMageActionId.HighThunderII);
    }

    public static Spell? GetFlareStarGcd()
    {
        if (!LevelAtLeast(100) || !IsAstralFireActive())
            return null;

        if (IsForbidBurstActive())
            return null;

        if (GetAstralSoulStacks() < MaxAstralSoulStacks)
            return null;

        return ReadyTargetSpell(BlackMageActionId.FlareStar);
    }

    public static Spell? GetDespairGcd()
    {
        if (!IsAstralFireActive() || IsForbidBurstActive())
            return null;

        if (CurrentMp() > _settings.DespairMpThreshold)
            return null;

        return ReadyTargetSpell(BlackMageActionId.Despair);
    }

    private static Spell? GetPolyglotGcd(bool aoe)
    {
        if (GetPolyglotStacks() <= 0)
            return null;

        if (!ShouldUseDumpResources() && ShouldHoldPolyglot() && GetPolyglotStacks() < MaxPolyglotStacks)
            return null;

        var shouldDumpPolyglot = ShouldUseDumpResources() ||
                                 ShouldUsePolyglotBeforeManafont() ||
                                 ShouldDumpPolyglot() ||
                                 ShouldUsePolyglotForDumpStacks() ||
                                 ShouldUsePolyglotForBurstAnchor() ||
                                 ShouldUseMovementTools();
        if (!shouldDumpPolyglot)
            return null;

        var actionId = aoe ? BlackMageActionId.Foul : BlackMageActionId.Xenoglossy;
        return ReadyTargetSpell(actionId);
    }

    public static Spell? GetLeyLinesOffGcd()
    {
        if (ShouldHoldLeyLines() || !CanUseOffGcdWindow())
            return null;

        var shouldUseLeyLines = ShouldDumpLeyLines() ||
                                ShouldUseOpeningLeyLines() ||
                                ((IsForceBurstActive() || IsInTwoMinuteBurstWindow()) &&
                                 !HasUsedLeyLinesInCurrentBurstWindow());
        if (!shouldUseLeyLines || HasLeyLines())
            return null;

        return ReadySelfAbility(BlackMageActionId.LeyLines);
    }

    public static Spell? GetTriplecastOffGcd()
    {
        if (!ShouldUseDumpResources() && ShouldHoldTriplecast())
            return null;

        var shouldUseForIceTransition = ShouldUseTriplecastForIceTransition();
        if (!CanUseOffGcdWindow(allowMovementRecovery: true) && !shouldUseForIceTransition)
            return null;

        if (!shouldUseForIceTransition && !ShouldDumpTriplecast() && !ShouldUseMovementTools())
            return null;

        if (HasTriplecast() || HasSwiftcast())
            return null;

        return ReadySelfAbility(BlackMageActionId.Triplecast);
    }

    public static Spell? GetSwiftcastOffGcd()
    {
        var shouldUseForIceTransition = ShouldUseSwiftcastForIceTransition();
        if (!CanUseOffGcdWindow(allowMovementRecovery: true) && !shouldUseForIceTransition)
            return null;

        if (!shouldUseForIceTransition && !ShouldUseMovementTools())
            return null;

        if (HasSwiftcast())
            return null;

        return ReadySelfAbility(BlackMageActionId.Swiftcast);
    }

    public static Spell? GetManafontOffGcd()
    {
        if (!ShouldUseDumpResources() && ShouldHoldManafont())
            return null;

        if (!IsAstralFireActive())
            return null;

        var shouldUseOpeningManafont = ShouldUseOpeningManafontBeforeDespair();
        if (!shouldUseOpeningManafont && !ShouldUseManafontNow())
            return null;

        if (!CanUseOffGcdWindow() && !ShouldClipManafontToContinueAstralFire())
            return null;

        var spell = ReadySelfAbility(BlackMageActionId.Manafont);
        if (spell is not null && shouldUseOpeningManafont)
            _openingManafontQueued = true;

        return spell;
    }

    public static Spell? GetTransposeOffGcd()
    {
        var shouldClipForIceTransition = ShouldClipTransposeForIceTransition();
        if (!CanUseOffGcdWindow() && !shouldClipForIceTransition)
            return null;

        if (!ShouldTransposeFromAstralFire() && !ShouldTransposeFromUmbralIce() && !shouldClipForIceTransition)
            return null;

        return ReadySelfAbility(BlackMageActionId.Transpose);
    }

    public static Spell? GetAmplifierOffGcd()
    {
        if (!CanUseOffGcdWindow())
            return null;

        if (ShouldHoldPolyglot() || GetPolyglotStacks() >= MaxPolyglotStacks)
            return null;

        if (!CanUseBurstResource() && !CanUseResourceForOvercap())
            return null;

        return ReadySelfAbility(BlackMageActionId.Amplifier);
    }

    private static Spell? GetMovementGcd()
    {
        var polyglot = GetPolyglotGcd(false);
        if (polyglot is not null)
            return polyglot;

        if (IsParadoxReady())
        {
            var paradox = ReadyTargetSpell(BlackMageActionId.Paradox);
            if (paradox is not null)
                return paradox;
        }

        if (HasFirestarter())
        {
            var firestarter = ReadyTargetSpell(BlackMageActionId.FireIII);
            if (firestarter is not null)
                return firestarter;
        }

        if (HasThunderhead() && ShouldRefreshThunder())
        {
            var thunder = ReadyTargetSpell(BlackMageActionId.HighThunder);
            if (thunder is not null)
                return thunder;
        }

        return ReadyTargetSpell(BlackMageActionId.Scathe);
    }

    public static bool ShouldUseManafontNow()
    {
        var shouldDumpManafont = ShouldUseDumpResources() || ShouldDumpManafont();

        if (!IsAstralFireActive())
            return false;

        if (ShouldUseOpeningManafontBeforeDespair())
            return true;

        if (CurrentMp() > _settings.ManafontMpThreshold)
            return false;

        if (GetDespairGcd() is not null)
            return false;

        if (ShouldUsePolyglotBeforeManafont())
            return false;

        if (!shouldDumpManafont && !IsInTwoMinuteBurstWindow() && !ShouldClipManafontToContinueAstralFire())
            return false;

        if (shouldDumpManafont)
            return true;

        return _lastCombatGcdActionId is BlackMageActionId.Despair or
                                      BlackMageActionId.Xenoglossy or
                                      BlackMageActionId.Foul;
    }

    public static bool ShouldUseOpeningManafontBeforeDespair()
    {
        if (!IsOpeningManafontCandidate() || !HasReachedOpeningManafontTail())
            return false;

        if (ShouldUsePolyglotBeforeManafont())
            return false;

        return _lastCombatGcdActionId is BlackMageActionId.Xenoglossy or BlackMageActionId.Foul ||
               GetPolyglotStacks() <= 0;
    }

    public static bool ShouldClipManafontToContinueAstralFire()
    {
        if (!IsAstralFireActive())
            return false;

        if (CurrentMp() >= Math.Max(_settings.AstralFireMinimumMpToContinue, GetExpectedFireIVMpCost()))
            return false;

        if (GetFlareStarGcd() is not null || GetDespairGcd() is not null)
            return false;

        return true;
    }

    private static bool ShouldUsePolyglotBeforeManafont()
    {
        if (!IsOpeningManafontCandidate() || !HasReachedOpeningManafontTail())
            return false;

        if (_lastCombatGcdActionId != BlackMageActionId.FireIV)
            return false;

        if (CurrentMp() >= GetExpectedFireIVMpCost())
            return false;

        if (GetPolyglotStacks() <= 0)
            return false;

        return !ShouldHoldManafont() && !ShouldHoldPolyglot();
    }

    private static bool IsOpeningManafontCandidate()
    {
        return IsAstralFireActive() &&
               GetCombatActionUseCount(BlackMageActionId.Manafont) == 0 &&
               GetCombatActionUseCount(BlackMageActionId.Despair) == 0 &&
               GetCombatActionUseCount(BlackMageActionId.FireIV) < OpeningTotalFireIVCount &&
               GetCombatActionUseCount(BlackMageActionId.FlareStar) < OpeningFlareStarCount &&
               !_openingManafontQueued &&
               IsActionUsable(BlackMageActionId.Manafont);
    }

    private static bool HasReachedOpeningManafontTail()
    {
        return GetCombatActionUseCount(BlackMageActionId.FireIV) >= OpeningManafontFireIVCount;
    }

    private static bool ShouldUsePolyglotForDumpStacks()
    {
        if (IsOpeningManafontCandidate() && !HasReachedOpeningManafontTail())
            return false;

        if (GetPolyglotStacks() < _settings.PolyglotDumpStacks)
            return false;

        if (ShouldHoldPolyglotForUpcomingBurstAnchor())
            return false;

        return true;
    }

    private static bool ShouldUsePolyglotForBurstAnchor()
    {
        if (!CanUseBurstResource())
            return false;

        if (ShouldUseDumpResources() || IsForceBurstActive())
            return true;

        return IsAtOrAfterTwoMinuteBurstAnchor();
    }

    private static bool ShouldHoldPolyglotForUpcomingBurstAnchor()
    {
        return !ShouldUseDumpResources() &&
               !IsForceBurstActive() &&
               !ShouldDumpPolyglot() &&
               !ShouldAvoidPolyglotOvercapBeforeBurstAnchor() &&
               GetTimeToNextTwoMinuteBurstAnchor() <= PolyglotBurstHoldLeadMs &&
               !IsAtOrAfterTwoMinuteBurstAnchor();
    }

    private static bool ShouldAvoidPolyglotOvercapBeforeBurstAnchor()
    {
        return GetPolyglotStacks() >= MaxPolyglotStacks &&
               GetEnochianTimer() <= PolyglotOvercapReserveMs;
    }

    private static bool ShouldSwitchToUmbralIce()
    {
        if (!IsAstralFireActive())
            return false;

        if (ShouldDelayAstralFireExitForResource())
            return false;

        return CurrentMp() < Math.Max(_settings.AstralFireMinimumMpToContinue, GetExpectedFireIVMpCost());
    }

    private static bool ShouldSwitchToAstralFire()
    {
        if (!IsUmbralIceActive())
            return false;

        if (CurrentMp() < _settings.UmbralIceFullMpThreshold)
            return false;

        if (IsParadoxReady())
            return false;

        return GetUmbralHearts() >= MaxElementalStacks || !IsActionUsable(BlackMageActionId.BlizzardIV);
    }

    private static bool ShouldDelayAstralFireExitForResource()
    {
        if (!IsAstralFireActive())
            return false;

        if (GetAstralSoulStacks() >= MaxAstralSoulStacks)
            return true;

        if (CurrentMp() > 0 && CurrentMp() <= _settings.DespairMpThreshold && !IsForbidBurstActive())
            return true;

        if (ShouldUsePolyglotBeforeManafont())
            return true;

        return ShouldUseManafontNow();
    }

    private static bool ShouldTransposeFromAstralFire()
    {
        return IsAstralFireActive() &&
               !ShouldDelayAstralFireExitForResource() &&
               CurrentMp() <= 0;
    }

    private static bool ShouldTransposeFromUmbralIce()
    {
        return ShouldSwitchToAstralFire();
    }

    private static bool ShouldUseSwiftcastForIceTransition()
    {
        if (ShouldForbidMovement() && !ShouldForceMovement())
            return false;

        if (HasSwiftcast() || HasTriplecast())
            return false;

        if (!ShouldPrepareInstantIceTransition())
            return false;

        return IsActionUsable(BlackMageActionId.Swiftcast);
    }

    private static bool ShouldUseTriplecastForIceTransition()
    {
        if (!ShouldUseDumpResources() && ShouldHoldTriplecast())
            return false;

        if (ShouldForbidMovement() && !ShouldForceMovement())
            return false;

        if (HasSwiftcast() || HasTriplecast())
            return false;

        if (ShouldUseSwiftcastForIceTransition() || IsSwiftcastNearlyReadyForIceTransition())
            return false;

        if (!ShouldPrepareInstantIceTransition())
            return false;

        return IsActionUsable(BlackMageActionId.Triplecast);
    }

    private static bool IsSwiftcastNearlyReadyForIceTransition()
    {
        return ShouldPrepareInstantIceTransition() &&
               !HasSwiftcast() &&
               !HasTriplecast() &&
               SelfAbility(BlackMageActionId.Swiftcast).CooldownMs <= SwiftcastIceTransitionWaitMs;
    }

    private static bool ShouldPrepareInstantIceTransition()
    {
        return IsAstralFireActive() &&
               IsActionUsable(BlackMageActionId.Transpose) &&
               (ShouldSwitchToUmbralIce() || ShouldTransposeFromAstralFire());
    }

    private static bool ShouldClipTransposeForIceTransition()
    {
        return ShouldPrepareInstantIceTransition() && (HasSwiftcast() || HasTriplecast());
    }

    private static bool ShouldUseAoe()
    {
        if (!QTHelper.IsEnabled(QTKey.Aoe) || !HasTarget())
            return false;

        return HelperRuntime.GetEnemyCountNearTarget(5f) >= _settings.AoeEnemyCount;
    }

    private static bool ShouldRefreshThunder()
    {
        if (!HasTarget() || ShouldUseDumpResources())
            return false;

        return GetThunderDotTimeLeft() * 1000 <= _settings.ThunderRefreshMs;
    }

    private static bool ShouldRefreshAoeThunder()
    {
        if (!ShouldUseAoe())
            return false;

        return GetAoeThunderDotTimeLeft() * 1000 <= _settings.ThunderRefreshMs;
    }

    public static bool CanUseBurstResource()
    {
        if (ShouldStopActions() || !HasTarget() || IsForbidBurstActive())
            return false;

        if (!QTHelper.IsEnabled(BuiltinQt.Burst))
            return false;

        return ShouldUseDumpResources() || IsForceBurstActive() || IsInTwoMinuteBurstWindow();
    }

    public static bool CanUseResourceForOvercap()
    {
        return !ShouldStopActions() &&
               HasTarget() &&
               QTHelper.IsEnabled(BuiltinQt.Burst) &&
               !IsForbidBurstActive();
    }

    private static bool IsInTwoMinuteBurstWindow()
    {
        if (IsForceBurstActive())
            return true;

        var timeToAnchor = GetTimeToNextTwoMinuteBurstAnchor();
        return timeToAnchor <= _settings.BurstWindowTailMs ||
               timeToAnchor >= 120_000 - _settings.BurstWindowLeadMs;
    }

    private static bool IsAtOrAfterTwoMinuteBurstAnchor()
    {
        return IsForceBurstActive() || GetTimeToNextTwoMinuteBurstAnchor() <= _settings.BurstWindowTailMs;
    }

    private static int GetTimeToNextTwoMinuteBurstAnchor()
    {
        var diff = _currentBattleTimeMs - _settings.FirstBurstAnchorMs;
        var mod = ((diff % 120_000) + 120_000) % 120_000;
        return mod == 0 ? 0 : 120_000 - mod;
    }

    private static bool ShouldUseOpeningLeyLines()
    {
        if (GetCombatActionUseCount(BlackMageActionId.LeyLines) > 0)
            return false;

        if (_lastCombatGcdActionId != BlackMageActionId.FireIV)
            return false;

        return _currentBattleTimeMs >= OpeningLeyLinesEarliestMs &&
               _currentBattleTimeMs <= OpeningLeyLinesLatestMs;
    }

    private static bool HasUsedLeyLinesInCurrentBurstWindow()
    {
        if (_lastLeyLinesUseMs is not { } lastUseMs)
            return false;

        return Math.Abs(_currentBattleTimeMs - lastUseMs) < 90_000;
    }

    private static bool CanUseOffGcdWindow(int minGcdCooldownMs = 650, bool allowMovementRecovery = false)
    {
        if (ShouldStopActions())
            return false;

        if (GCDHelper.GetGCDCooldown() >= minGcdCooldownMs)
            return true;

        return allowMovementRecovery && ShouldUseMovementTools();
    }

    private static int GetExpectedFireIVMpCost()
    {
        return GetUmbralHearts() > 0 ? _settings.FireIVHeartMpCost : _settings.FireIVNoHeartMpCost;
    }

    private static int GetCombatActionUseCount(uint actionId)
    {
        return CombatActionUseCounts.GetValueOrDefault(actionId);
    }

    private static void ResetCombatTracking()
    {
        _lastCombatGcdActionId = 0;
        _lastLeyLinesUseMs = null;
        _openingManafontQueued = false;
        CombatActionUseCounts.Clear();
    }

    private static int CurrentMp()
    {
        return (int)(global::HiAuRo.Data.Me.Object?.CurrentMp ?? 0);
    }

    private static int GetAstralFireStacks() => (int)BLMHelper.火层数;
    private static int GetUmbralIceStacks() => (int)BLMHelper.冰层数;
    private static int GetUmbralHearts() => (int)BLMHelper.冰针数;
    private static int GetAstralSoulStacks() => BLMHelper.耀星层数;
    private static int GetPolyglotStacks() => (int)BLMHelper.通晓数;
    private static int GetEnochianTimer() => BLMHelper.通晓计时;
    private static bool IsAstralFireActive() => BLMHelper.火状态;
    private static bool IsUmbralIceActive() => BLMHelper.冰状态;
    private static bool IsParadoxReady() => BLMHelper.悖论指示 || HelperRuntime.HasStatus(BlackMageStatusId.Paradox);
    private static bool HasFirestarter() => HelperRuntime.HasStatus(BlackMageStatusId.Firestarter);
    private static bool HasThunderhead() => HelperRuntime.HasStatus(BlackMageStatusId.Thunderhead);
    private static bool HasSwiftcast() => HelperRuntime.HasStatus(BlackMageStatusId.Swiftcast);
    private static bool HasTriplecast() => HelperRuntime.HasStatus(BlackMageStatusId.Triplecast);
    private static bool HasLeyLines() => HelperRuntime.HasStatus(BlackMageStatusId.LeyLines) ||
                                         HelperRuntime.HasStatus(BlackMageStatusId.CircleOfPower);

    private static float GetThunderDotTimeLeft()
    {
        return Math.Max(
            HelperRuntime.GetStatusTimeLeftOnTarget(BlackMageStatusId.HighThunder),
            Math.Max(
                HelperRuntime.GetStatusTimeLeftOnTarget(BlackMageStatusId.ThunderIII),
                HelperRuntime.GetStatusTimeLeftOnTarget(BlackMageStatusId.ThunderIV)));
    }

    private static float GetAoeThunderDotTimeLeft()
    {
        return HelperRuntime.GetStatusTimeLeftOnTarget(BlackMageStatusId.HighThunderII);
    }

    private static bool ShouldUseDumpResources() => QTHelper.IsEnabled(QTKey.DumpResources);
    private static bool IsForceBurstActive() => !IsForbidBurstActive() && QTHelper.IsEnabled(QTKey.ForceBurst);
    private static bool IsForbidBurstActive() => QTHelper.IsEnabled(QTKey.ForbidBurst);
    private static bool ShouldHoldPolyglot() => QTHelper.IsEnabled(QTKey.HoldPolyglot);
    private static bool ShouldDumpPolyglot() => !ShouldHoldPolyglot() && QTHelper.IsEnabled(QTKey.DumpPolyglot);
    private static bool ShouldHoldTriplecast() => QTHelper.IsEnabled(QTKey.HoldTriplecast);
    private static bool ShouldDumpTriplecast() => !ShouldHoldTriplecast() && QTHelper.IsEnabled(QTKey.DumpTriplecast);
    private static bool ShouldHoldManafont() => QTHelper.IsEnabled(QTKey.HoldManafont);
    private static bool ShouldDumpManafont() => !ShouldHoldManafont() && QTHelper.IsEnabled(QTKey.DumpManafont);
    private static bool ShouldHoldLeyLines() => QTHelper.IsEnabled(QTKey.HoldLeyLines);
    private static bool ShouldDumpLeyLines() => !ShouldHoldLeyLines() && QTHelper.IsEnabled(QTKey.DumpLeyLines);
    private static bool ShouldForceMovement() => !ShouldForbidMovement() && QTHelper.IsEnabled(QTKey.ForceMovement);
    private static bool ShouldForbidMovement() => QTHelper.IsEnabled(QTKey.ForbidMovement);
    private static bool ShouldUseMovementTools() => ShouldForceMovement() && !ShouldForbidMovement();

    private static bool HasTarget()
    {
        return global::HiAuRo.Data.Target.Current is IBattleChara { IsDead: false, IsTargetable: true };
    }

    private static bool LevelAtLeast(int level)
    {
        var currentLevel = HelperRuntime.GetCurrentLevel();
        return currentLevel <= 0 || currentLevel >= level;
    }

    private static bool IsActionUsable(uint actionId)
    {
        return actionId.IsUnlockWithCDCheck();
    }

    private static Spell TargetSpell(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Target);
    }

    private static Spell SelfAbility(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Self) { Type = SpellType.Ability };
    }

    private static Spell? ReadyTargetSpell(uint actionId)
    {
        var spell = TargetSpell(actionId);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    private static Spell? ReadySelfSpell(uint actionId)
    {
        var spell = new Spell(actionId, SpellTargetType.Self);
        return spell.IsReadyWithCanCast() ? spell : null;
    }

    private static Spell? ReadySelfAbility(uint actionId)
    {
        var spell = SelfAbility(actionId);
        return spell.IsReadyWithCanCast() ? spell : null;
    }
}
