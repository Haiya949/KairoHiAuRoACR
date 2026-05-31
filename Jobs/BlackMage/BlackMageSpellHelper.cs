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
        BLMHelper.EN.Skills.Fire,
        BLMHelper.EN.Skills.Blizzard,
        BLMHelper.EN.Skills.Thunder,
        BLMHelper.EN.Skills.FireII,
        BLMHelper.EN.Skills.ThunderII,
        BLMHelper.EN.Skills.FireIII,
        BLMHelper.EN.Skills.ThunderIII,
        BLMHelper.EN.Skills.BlizzardIII,
        BLMHelper.EN.Skills.Scathe,
        BLMHelper.EN.Skills.Freeze,
        BLMHelper.EN.Skills.Flare,
        BLMHelper.EN.Skills.BlizzardIV,
        BLMHelper.EN.Skills.FireIV,
        BLMHelper.EN.Skills.ThunderIV,
        BLMHelper.EN.Skills.Foul,
        BLMHelper.EN.Skills.Despair,
        BLMHelper.EN.Skills.UmbralSoul,
        BLMHelper.EN.Skills.Xenoglossy,
        BLMHelper.EN.Skills.BlizzardII,
        BLMHelper.EN.Skills.HighFireII,
        BLMHelper.EN.Skills.HighBlizzardII,
        BLMHelper.EN.Skills.Paradox,
        BLMHelper.EN.Skills.HighThunder,
        BLMHelper.EN.Skills.HighThunderII,
        BLMHelper.EN.Skills.FlareStar,
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

        if (actionId == BLMHelper.EN.Skills.LeyLines)
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

        if (GetCombatActionUseCount(BLMHelper.EN.Skills.HighThunder) > 0 ||
            GetCombatActionUseCount(BLMHelper.EN.Skills.FireIV) > 0 ||
            GetCombatActionUseCount(BLMHelper.EN.Skills.LeyLines) > 0)
            return false;

        return TargetSpell(BLMHelper.EN.Skills.HighThunder).IsReadyWithCanCast() ||
               TargetSpell(BLMHelper.EN.Skills.FireIV).IsReadyWithCanCast();
    }

    public static Spell? GetOpeningHighThunderGcd()
    {
        if (GetCombatActionUseCount(BLMHelper.EN.Skills.HighThunder) > 0)
            return null;

        return ReadyTargetSpell(BLMHelper.EN.Skills.HighThunder);
    }

    public static Spell? GetOpeningFireIvGcd()
    {
        if (GetCombatActionUseCount(BLMHelper.EN.Skills.FireIV) > 0)
            return null;

        return ReadyTargetSpell(BLMHelper.EN.Skills.FireIV);
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

        return GetNeutralElementGcd() ?? ReadyTargetSpell(BLMHelper.EN.Skills.Scathe);
    }

    public static Spell? GetDowntimeGcd()
    {
        if (!ShouldUseDowntimeRecovery())
            return null;

        return ReadySelfSpell(BLMHelper.EN.Skills.UmbralSoul);
    }

    public static Spell? GetAoeGcd()
    {
        if (!ShouldUseAoe())
            return null;

        if (ShouldUseHighEndAoeLoop())
            return GetHighEndAoeGcd() ?? GetLegacyAoeGcd();

        return GetLegacyAoeGcd();
    }

    private static Spell? GetHighEndAoeGcd()
    {
        var thunder = GetAoeThunderGcd();
        if (thunder is not null)
            return thunder;

        if (IsAstralFireActive())
        {
            var flareStar = GetFlareStarGcd();
            if (flareStar is not null)
                return flareStar;

            var flare = BestAoeTargetSpell(BLMHelper.EN.Skills.Flare);
            if (flare.IsReadyWithCanCast())
                return flare;

            return GetAoeFillerGcd();
        }

        if (IsUmbralIceActive())
        {
            if (GetUmbralHearts() < MaxElementalStacks || CurrentMp() < AoeFireEntryMpThreshold)
            {
                var freeze = BestAoeTargetSpell(BLMHelper.EN.Skills.Freeze);
                if (freeze.IsReadyWithCanCast())
                    return freeze;
            }

            return GetAoeFillerGcd();
        }

        var neutralFreeze = BestAoeTargetSpell(BLMHelper.EN.Skills.Freeze);
        if (neutralFreeze.IsReadyWithCanCast())
            return neutralFreeze;

        return GetAoeFillerGcd();
    }

    private static Spell? GetLegacyAoeGcd()
    {
        var polyglot = GetPolyglotGcd(true);
        if (polyglot is not null)
            return polyglot;

        var thunder = GetAoeThunderGcd();
        if (thunder is not null)
            return thunder;

        if (IsAstralFireActive())
        {
            if (CurrentMp() <= _settings.DespairMpThreshold)
            {
                var flare = BestAoeTargetSpell(BLMHelper.EN.Skills.Flare);
                if (flare.IsReadyWithCanCast())
                    return flare;
            }

            var fire = BestAoeTargetSpell(GetAoeFireActionId());
            if (fire.IsReadyWithCanCast())
                return fire;

            return GetAoeFillerGcd();
        }

        if (IsUmbralIceActive())
        {
            if (GetUmbralHearts() < MaxElementalStacks || CurrentMp() < AoeFireEntryMpThreshold)
            {
                var freeze = BestAoeTargetSpell(BLMHelper.EN.Skills.Freeze);
                if (freeze.IsReadyWithCanCast())
                    return freeze;
            }

            if (CurrentMp() >= AoeFireEntryMpThreshold)
            {
                var fire = BestAoeTargetSpell(GetAoeFireActionId());
                if (fire.IsReadyWithCanCast())
                    return fire;
            }

            var blizzard = BestAoeTargetSpell(GetAoeBlizzardActionId());
            if (blizzard.IsReadyWithCanCast())
                return blizzard;

            return GetAoeFillerGcd();
        }

        if (CurrentMp() >= AoeFireEntryMpThreshold)
        {
            var fire = BestAoeTargetSpell(GetAoeFireActionId());
            if (fire.IsReadyWithCanCast())
                return fire;
        }

        var neutralBlizzard = BestAoeTargetSpell(GetAoeBlizzardActionId());
        if (neutralBlizzard.IsReadyWithCanCast())
            return neutralBlizzard;

        return GetAoeFillerGcd();
    }

    private static Spell? GetAoeFillerGcd()
    {
        var thunder = GetAoeThunderGcd();
        if (thunder is not null)
            return thunder;

        var polyglot = GetPolyglotGcd(true);
        if (polyglot is not null)
            return polyglot;

        return IsUmbralIceActive() ? GetUmbralParadoxGcd() : null;
    }

    private static Spell? GetAstralFireGcd()
    {
        var firestarterEntry = GetFirestarterEntryGcd();
        if (firestarterEntry is not null)
            return firestarterEntry;

        var openingPolyglot = GetOpeningPolyglotBeforeManafontGcd();
        if (openingPolyglot is not null)
            return openingPolyglot;

        var fireParadox = GetFireParadoxGcd();
        if (fireParadox is not null)
            return fireParadox;

        var thunder = GetThunderGcd();
        if (thunder is not null)
            return thunder;

        var polyglot = GetPolyglotGcd(false);
        if (polyglot is not null)
            return polyglot;

        var flareStar = GetFlareStarGcd();
        if (flareStar is not null)
            return flareStar;

        if (ShouldWaitForOpeningFlareStarBeforeFireIv())
            return null;

        var fireIv = ReadyTargetSpell(BLMHelper.EN.Skills.FireIV);
        if (fireIv is not null)
            return fireIv;

        var despair = GetDespairGcd();
        if (despair is not null)
            return despair;

        if (ShouldWaitForOpeningFiveSevenPackageGcd())
            return null;

        if (ShouldSwitchToUmbralIce())
        {
            if (ShouldWaitForTransposeBeforeIceTransition())
                return null;

            return ReadyTargetSpell(BLMHelper.EN.Skills.BlizzardIII);
        }

        return ReadyTargetSpell(BLMHelper.EN.Skills.FireIII) ??
               ReadyTargetSpell(BLMHelper.EN.Skills.Fire);
    }

    private static Spell? GetUmbralIceGcd()
    {
        var polyglot = GetPolyglotGcd(false);
        if (polyglot is not null)
            return polyglot;

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

        return ReadyTargetSpell(BLMHelper.EN.Skills.BlizzardIII) ??
               ReadySelfSpell(BLMHelper.EN.Skills.UmbralSoul);
    }

    private static Spell? GetNeutralElementGcd()
    {
        if (CurrentMp() >= 2_400)
            return ReadyTargetSpell(BLMHelper.EN.Skills.FireIII);

        return ReadyTargetSpell(BLMHelper.EN.Skills.BlizzardIII);
    }

    private static Spell? GetUmbralRecoveryGcd()
    {
        if (GetUmbralIceStacks() < MaxElementalStacks)
        {
            var blizzardIII = ReadyTargetSpell(BLMHelper.EN.Skills.BlizzardIII);
            if (blizzardIII is not null)
                return blizzardIII;
        }

        if (GetUmbralHearts() < MaxElementalStacks)
        {
            var blizzardIV = ReadyTargetSpell(BLMHelper.EN.Skills.BlizzardIV);
            if (blizzardIV is not null)
                return blizzardIV;
        }

        return null;
    }

    private static Spell? GetUmbralParadoxGcd()
    {
        return IsParadoxReady() ? ReadyTargetSpell(BLMHelper.EN.Skills.Paradox) : null;
    }

    private static Spell? GetUmbralFireEntryGcd()
    {
        if (!ShouldSwitchToAstralFire())
            return null;

        return ReadyTargetSpell(BLMHelper.EN.Skills.FireIII);
    }

    private static Spell? GetFirestarterEntryGcd()
    {
        return ShouldUseFirestarterToEnterAstralFire() ? ReadyTargetSpell(BLMHelper.EN.Skills.FireIII) : null;
    }

    private static bool ShouldUseFirestarterToEnterAstralFire()
    {
        return IsAstralFireActive() &&
               HasFirestarter() &&
               !IsAfterOpeningFireIvBeforeFirstIce() &&
               GetAstralFireStacks() < MaxElementalStacks;
    }

    private static bool IsAfterOpeningFireIvBeforeFirstIce()
    {
        return GetCombatActionUseCount(BLMHelper.EN.Skills.FireIV) > 0 &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.BlizzardIII) == 0;
    }

    private static Spell? GetOpeningPolyglotBeforeManafontGcd()
    {
        if (!ShouldUsePolyglotBeforeManafont())
            return null;

        return ReadyTargetSpell(GetSingleTargetPolyglotActionId());
    }

    private static Spell? GetFireParadoxGcd()
    {
        return ShouldUseFireParadoxInAstralFire() ? ReadyTargetSpell(BLMHelper.EN.Skills.Paradox) : null;
    }

    private static bool ShouldUseFireParadoxInAstralFire()
    {
        if (!IsAstralFireActive() || !IsParadoxReady())
            return false;

        if (ShouldSkipOpeningParadoxAfterManafont())
            return false;

        if (GetAstralFireStacks() < MaxElementalStacks && !HasFirestarter())
            return true;

        return GetAstralSoulStacks() >= FireParadoxAstralSoulFloor;
    }

    private static bool ShouldSkipOpeningParadoxAfterManafont()
    {
        return (GetCombatActionUseCount(BLMHelper.EN.Skills.Manafont) > 0 || _openingManafontQueued) &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.FireIV) < OpeningTotalFireIVCount &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.Despair) == 0 &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.FlareStar) < OpeningFlareStarCount;
    }

    private static Spell? GetThunderGcd()
    {
        if (!ShouldRefreshThunder())
            return null;

        return ReadyTargetSpell(GetSingleTargetThunderActionId());
    }

    private static Spell? GetAoeThunderGcd()
    {
        if (!ShouldRefreshAoeThunder())
            return null;

        return ReadyTargetSpell(GetAoeThunderActionId());
    }

    public static Spell? GetFlareStarGcd()
    {
        if (!LevelAtLeast(100) || !IsAstralFireActive())
            return null;

        if (IsForbidBurstActive())
            return null;

        if (GetAstralSoulStacks() < MaxAstralSoulStacks)
            return null;

        return ReadyTargetSpell(BLMHelper.EN.Skills.FlareStar);
    }

    public static Spell? GetDespairGcd()
    {
        if (!LevelAtLeast(72) || !IsAstralFireActive() || IsForbidBurstActive())
            return null;

        if (CurrentMp() > _settings.DespairMpThreshold)
            return null;

        if (ShouldHoldDespairForOpeningFiveSevenPackage())
            return null;

        return ReadyTargetSpell(BLMHelper.EN.Skills.Despair);
    }

    private static Spell? GetPolyglotGcd(bool aoe)
    {
        if (GetPolyglotStacks() <= 0)
            return null;

        if (!ShouldUseDumpResources() && ShouldHoldPolyglot() && GetPolyglotStacks() < MaxPolyglotStacks)
            return null;

        if (!ShouldUsePolyglotInBurstPackage())
            return null;

        var actionId = aoe ? BLMHelper.EN.Skills.Foul : GetSingleTargetPolyglotActionId();
        return ReadyTargetSpell(actionId);
    }

    private static bool ShouldUsePolyglotInBurstPackage()
    {
        return ShouldUsePolyglotForDumpStacks() ||
               ShouldUsePolyglotBeforeManafont() ||
               ShouldUseMovementTools() ||
               ShouldUseDumpResources() ||
               ShouldDumpPolyglot() ||
               ShouldUsePolyglotForBurstAnchor();
    }

    private static uint GetSingleTargetPolyglotActionId()
    {
        return LevelAtLeast(80) ? BLMHelper.EN.Skills.Xenoglossy : BLMHelper.EN.Skills.Foul;
    }

    private static uint GetSingleTargetThunderActionId()
    {
        return LevelAtLeast(100)
            ? BLMHelper.EN.Skills.HighThunder
            : HelperRuntime.GetActionChange(BLMHelper.EN.Skills.Thunder);
    }

    private static uint GetAoeThunderActionId()
    {
        return LevelAtLeast(100)
            ? BLMHelper.EN.Skills.HighThunderII
            : HelperRuntime.GetActionChange(BLMHelper.EN.Skills.ThunderII);
    }

    private static uint GetAoeFireActionId()
    {
        return HelperRuntime.GetActionChange(BLMHelper.EN.Skills.FireII);
    }

    private static uint GetAoeBlizzardActionId()
    {
        return HelperRuntime.GetActionChange(BLMHelper.EN.Skills.BlizzardII);
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

        return ReadySelfAbility(BLMHelper.EN.Skills.LeyLines);
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

        return ReadySelfAbility(BLMHelper.EN.Skills.Triplecast);
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

        return ReadySelfAbility(BLMHelper.EN.Skills.Swiftcast);
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

        var spell = ReadySelfAbility(BLMHelper.EN.Skills.Manafont);
        if (spell is not null && shouldUseOpeningManafont)
            _openingManafontQueued = true;

        return spell;
    }

    public static Spell? GetTransposeOffGcd()
    {
        var shouldClipForIceTransition = ShouldClipTransposeForIceTransition();
        var shouldTransposeForAoeLoop = ShouldTransposeForAoeLoop();
        if (!CanUseOffGcdWindow() && !shouldClipForIceTransition)
            return null;

        if (!ShouldTransposeFromAstralFire() &&
            !ShouldTransposeFromUmbralIce() &&
            !shouldClipForIceTransition &&
            !shouldTransposeForAoeLoop)
            return null;

        return ReadySelfAbility(BLMHelper.EN.Skills.Transpose);
    }

    public static Spell? GetAmplifierOffGcd()
    {
        if (!CanUseOffGcdWindow())
            return null;

        if (ShouldHoldPolyglot() || GetPolyglotStacks() >= MaxPolyglotStacks)
            return null;

        if (!CanUseBurstResource() && !CanUseResourceForOvercap())
            return null;

        return ReadySelfAbility(BLMHelper.EN.Skills.Amplifier);
    }

    private static Spell? GetMovementGcd()
    {
        var polyglot = GetPolyglotGcd(false);
        if (polyglot is not null)
            return polyglot;

        if (IsParadoxReady())
        {
            var paradox = ReadyTargetSpell(BLMHelper.EN.Skills.Paradox);
            if (paradox is not null)
                return paradox;
        }

        if (HasFirestarter())
        {
            var firestarter = ReadyTargetSpell(BLMHelper.EN.Skills.FireIII);
            if (firestarter is not null)
                return firestarter;
        }

        if (HasThunderhead() && ShouldRefreshThunder())
        {
            var thunder = ReadyTargetSpell(GetSingleTargetThunderActionId());
            if (thunder is not null)
                return thunder;
        }

        return ReadyTargetSpell(BLMHelper.EN.Skills.Scathe);
    }

    public static bool ShouldUseManafontNow()
    {
        var shouldDumpManafont = ShouldUseDumpResources() || ShouldDumpManafont();

        if (!IsAstralFireActive())
            return false;

        if (ShouldUseOpeningManafontBeforeDespair())
            return true;

        if (!IsActionUsable(BLMHelper.EN.Skills.Manafont))
            return false;

        if (ShouldHoldManafontForBurstWindow() && !ShouldClipManafontToContinueAstralFire())
            return false;

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

        return _lastCombatGcdActionId is BLMHelper.EN.Skills.Despair or
                                      BLMHelper.EN.Skills.Xenoglossy or
                                      BLMHelper.EN.Skills.Foul;
    }

    private static bool ShouldHoldManafontForBurstWindow()
    {
        if (ShouldUseDumpResources() || ShouldDumpManafont())
            return false;

        if (!IsActionUsable(BLMHelper.EN.Skills.Manafont))
            return false;

        return !IsInTwoMinuteBurstWindow();
    }

    public static bool ShouldUseOpeningManafontBeforeDespair()
    {
        if (!IsOpeningManafontCandidate() || !HasReachedOpeningManafontTail())
            return false;

        if (ShouldUsePolyglotBeforeManafont())
            return false;

        return _lastCombatGcdActionId is BLMHelper.EN.Skills.Xenoglossy or BLMHelper.EN.Skills.Foul ||
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
        if (!LevelAtLeast(80))
            return false;

        if (!IsOpeningManafontCandidate() || !HasReachedOpeningManafontTail())
            return false;

        if (!HasOpeningFireIvTailGcd())
            return false;

        if (CurrentMp() >= GetExpectedFireIVMpCost())
            return false;

        if (GetPolyglotStacks() <= 0)
            return false;

        return IsActionUsable(BLMHelper.EN.Skills.Manafont) &&
               !ShouldHoldManafont() &&
               !ShouldHoldPolyglot();
    }

    private static bool IsOpeningManafontCandidate()
    {
        return IsOpeningFiveSevenPackageCandidate() &&
               IsActionUsable(BLMHelper.EN.Skills.Manafont);
    }

    private static bool IsOpeningFiveSevenPackageCandidate()
    {
        return IsAstralFireActive() &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.Manafont) == 0 &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.Despair) == 0 &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.FireIV) < OpeningTotalFireIVCount &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.FlareStar) < OpeningFlareStarCount &&
               !_openingManafontQueued;
    }

    private static bool HasReachedOpeningManafontTail()
    {
        return GetCombatActionUseCount(BLMHelper.EN.Skills.FireIV) >= OpeningManafontFireIVCount ||
               ShouldTreatLowMpOpeningTailAsReached();
    }

    private static bool HasOpeningFireIvTailGcd()
    {
        return _lastCombatGcdActionId == BLMHelper.EN.Skills.FireIV ||
               ShouldTreatLowMpOpeningTailAsReached();
    }

    private static bool ShouldTreatLowMpOpeningTailAsReached()
    {
        return LevelAtLeast(100) &&
               IsOpeningFiveSevenPackageCandidate() &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.BlizzardIII) == 0 &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.Manafont) == 0 &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.Despair) == 0 &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.FlareStar) == 0 &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.FireIV) >= OpeningManafontFireIVCount - 1 &&
               CurrentMp() < GetExpectedFireIVMpCost();
    }

    private static bool ShouldKeepOpeningFiveSevenPackageInAstralFire()
    {
        if (!LevelAtLeast(100) || !IsAstralFireActive())
            return false;

        if (GetCombatActionUseCount(BLMHelper.EN.Skills.BlizzardIII) > 0)
            return false;

        if (GetCombatActionUseCount(BLMHelper.EN.Skills.Despair) > 0)
            return false;

        if (IsOpeningFiveSevenPackageCandidate())
            return HasReachedOpeningManafontTail();

        if (!HasOpeningManafontStarted())
            return false;

        if (GetCombatActionUseCount(BLMHelper.EN.Skills.FlareStar) >= OpeningFlareStarCount)
            return false;

        return true;
    }

    private static bool HasOpeningManafontStarted()
    {
        return GetCombatActionUseCount(BLMHelper.EN.Skills.Manafont) > 0 ||
               _openingManafontQueued;
    }

    private static bool ShouldHoldDespairForOpeningFiveSevenPackage()
    {
        return ShouldKeepOpeningFiveSevenPackageInAstralFire() &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.FlareStar) < OpeningFlareStarCount;
    }

    private static bool ShouldWaitForOpeningFlareStarBeforeFireIv()
    {
        if (!ShouldKeepOpeningFiveSevenPackageInAstralFire())
            return false;

        if (!HasOpeningManafontStarted())
            return false;

        if (GetCombatActionUseCount(BLMHelper.EN.Skills.FlareStar) >= OpeningFlareStarCount)
            return false;

        var plannedFireIvCount = GetCombatActionUseCount(BLMHelper.EN.Skills.FlareStar) == 0
            ? OpeningManafontFireIVCount + 1
            : OpeningTotalFireIVCount;

        if (GetCombatActionUseCount(BLMHelper.EN.Skills.FireIV) < plannedFireIvCount)
            return false;

        return GetFlareStarGcd() is null;
    }

    private static bool ShouldWaitForOpeningFiveSevenPackageGcd()
    {
        return ShouldKeepOpeningFiveSevenPackageInAstralFire();
    }

    private static bool ShouldUsePolyglotForDumpStacks()
    {
        if (ShouldHoldOpeningPolyglotForManafontTail())
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

        if (ShouldHoldOpeningPolyglotForManafontTail())
            return false;

        return IsAtOrAfterTwoMinuteBurstAnchor();
    }

    private static bool ShouldHoldOpeningPolyglotForManafontTail()
    {
        return IsOpeningManafontCandidate() && !HasReachedOpeningManafontTail();
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

        return GetUmbralHearts() >= MaxElementalStacks || !IsActionUsable(BLMHelper.EN.Skills.BlizzardIV);
    }

    private static bool ShouldDelayAstralFireExitForResource()
    {
        if (!IsAstralFireActive())
            return false;

        if (ShouldKeepOpeningFiveSevenPackageInAstralFire())
            return true;

        if (GetAstralSoulStacks() >= MaxAstralSoulStacks && GetFlareStarGcd() is not null)
            return true;

        if (ShouldReserveDespairBeforeAstralFireExit())
            return true;

        if (ShouldUsePolyglotBeforeManafont())
            return true;

        return ShouldUseManafontNow();
    }

    private static bool ShouldReserveDespairBeforeAstralFireExit()
    {
        if (!LevelAtLeast(72) || !IsAstralFireActive())
            return false;

        if (IsForbidBurstActive())
            return false;

        if (_lastCombatGcdActionId == BLMHelper.EN.Skills.Despair)
            return false;

        if (CurrentMp() <= 0 || CurrentMp() > _settings.DespairMpThreshold)
            return false;

        if (ShouldUseOpeningManafontBeforeDespair())
            return false;

        return !ShouldSkipOpeningDespairAfterFiveSevenOpener();
    }

    private static bool ShouldSkipOpeningDespairAfterFiveSevenOpener()
    {
        return GetCombatActionUseCount(BLMHelper.EN.Skills.BlizzardIII) == 0 &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.Manafont) > 0 &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.Despair) == 0 &&
               GetCombatActionUseCount(BLMHelper.EN.Skills.FlareStar) < OpeningFlareStarCount;
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

        if (ShouldReserveManafontBeforeIceTransition())
            return false;

        if (!ShouldPrepareInstantIceTransition())
            return false;

        return IsActionUsable(BLMHelper.EN.Skills.Swiftcast);
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

        if (ShouldReserveManafontBeforeIceTransition())
            return false;

        if (!ShouldPrepareInstantIceTransition())
            return false;

        return IsActionUsable(BLMHelper.EN.Skills.Triplecast);
    }

    private static bool ShouldReserveManafontBeforeIceTransition()
    {
        if (ShouldHoldManafont())
            return false;

        if (!IsActionUsable(BLMHelper.EN.Skills.Manafont))
            return false;

        if (!ShouldUseManafontNow())
            return false;

        return ReadySelfAbility(BLMHelper.EN.Skills.Manafont) is not null;
    }

    private static bool IsSwiftcastNearlyReadyForIceTransition()
    {
        return ShouldPrepareInstantIceTransition() &&
               !HasSwiftcast() &&
               !HasTriplecast() &&
               GetSwiftcastCooldownMs() <= SwiftcastIceTransitionWaitMs;
    }

    private static float GetSwiftcastCooldownMs()
    {
        return SelfAbility(BLMHelper.EN.Skills.Swiftcast).CooldownMs;
    }

    private static bool ShouldPrepareInstantIceTransition()
    {
        return IsAstralFireActive() &&
               IsActionUsable(BLMHelper.EN.Skills.Transpose) &&
               (ShouldSwitchToUmbralIce() || ShouldTransposeFromAstralFire());
    }

    private static bool ShouldClipTransposeForIceTransition()
    {
        return ShouldPrepareInstantIceTransition() && (HasSwiftcast() || HasTriplecast());
    }

    private static bool ShouldWaitForTransposeBeforeIceTransition()
    {
        if (!ShouldPrepareInstantIceTransition())
            return false;

        if (GCDHelper.CanUseGCD())
            return false;

        return HasSwiftcast() ||
               HasTriplecast() ||
               ShouldUseSwiftcastForIceTransition() ||
               IsSwiftcastNearlyReadyForIceTransition() ||
               ShouldUseTriplecastForIceTransition();
    }

    private static bool ShouldUseHighEndAoeLoop()
    {
        return LevelAtLeast(100);
    }

    private static bool ShouldUseDowntimeRecovery()
    {
        return !ShouldStopActions() &&
               !HasTarget() &&
               IsUmbralIceActive() &&
               IsActionUsable(BLMHelper.EN.Skills.UmbralSoul) &&
               (CurrentMp() < _settings.UmbralIceFullMpThreshold ||
                GetUmbralHearts() < MaxElementalStacks);
    }

    private static bool ShouldTransposeForAoeLoop()
    {
        if (!ShouldUseHighEndAoeLoop() || !ShouldUseAoe())
            return false;

        if (IsAstralFireActive())
            return CurrentMp() <= 0 &&
                   GetAstralSoulStacks() < MaxAstralSoulStacks;

        if (IsUmbralIceActive())
            return GetUmbralHearts() >= MaxElementalStacks &&
                   CurrentMp() >= AoeFireEntryMpThreshold;

        return false;
    }

    private static bool ShouldUseAoe()
    {
        if (!QTHelper.IsEnabled(QTKey.Aoe) || GetCurrentTarget() is null)
            return false;

        return GetEnemyCountNearTarget(5f) >= _settings.AoeEnemyCount;
    }

    private static bool ShouldRefreshThunder()
    {
        if (!HasTarget())
            return false;

        return !ShouldSkipThunderForEndingTarget() &&
               GetThunderDotTimeLeft() * 1000 <= _settings.ThunderRefreshMs;
    }

    private static bool ShouldRefreshAoeThunder()
    {
        if (!ShouldUseAoe())
            return false;

        return !ShouldSkipThunderForEndingTarget() &&
               GetAoeThunderDotTimeLeft() * 1000 <= _settings.ThunderRefreshMs;
    }

    private static bool ShouldSkipThunderForEndingTarget()
    {
        var target = GetCurrentTarget();
        return target is null ||
               ShouldUseDumpResources() ||
               GetTargetHpPercent(target) <= _settings.ThunderSkipTargetHpPercent;
    }

    private static float GetTargetHpPercent(IBattleChara target)
    {
        if (target.MaxHp <= 0)
            return 0f;

        return (float)target.CurrentHp / target.MaxHp;
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

        var elapsed = GetElapsedInTwoMinuteBurstCycle();
        return elapsed <= _settings.BurstWindowTailMs ||
               elapsed >= 120_000 - _settings.BurstWindowLeadMs;
    }

    private static bool IsAtOrAfterTwoMinuteBurstAnchor()
    {
        if (IsForceBurstActive())
            return true;

        var elapsed = GetElapsedInTwoMinuteBurstCycle();
        return elapsed <= _settings.BurstWindowTailMs;
    }

    private static int GetTimeToNextTwoMinuteBurstAnchor()
    {
        var elapsed = GetElapsedInTwoMinuteBurstCycle();
        return elapsed == 0 ? 0 : 120_000 - elapsed;
    }

    private static int GetElapsedInTwoMinuteBurstCycle()
    {
        var diff = _currentBattleTimeMs - _settings.FirstBurstAnchorMs;
        return ((diff % 120_000) + 120_000) % 120_000;
    }

    private static int GetCurrentOrPreviousTwoMinuteBurstAnchor()
    {
        return _currentBattleTimeMs - GetElapsedInTwoMinuteBurstCycle();
    }

    private static int GetActiveTwoMinuteBurstWindowAnchor()
    {
        var elapsed = GetElapsedInTwoMinuteBurstCycle();
        var anchor = GetCurrentOrPreviousTwoMinuteBurstAnchor();

        return elapsed >= 120_000 - _settings.BurstWindowLeadMs
            ? anchor + 120_000
            : anchor;
    }

    private static bool ShouldUseOpeningLeyLines()
    {
        if (GetCombatActionUseCount(BLMHelper.EN.Skills.LeyLines) > 0)
            return false;

        if (_lastCombatGcdActionId != BLMHelper.EN.Skills.FireIV)
            return false;

        return _currentBattleTimeMs >= OpeningLeyLinesEarliestMs &&
               _currentBattleTimeMs <= OpeningLeyLinesLatestMs;
    }

    private static bool HasUsedLeyLinesInCurrentBurstWindow()
    {
        if (_lastLeyLinesUseMs is not { } lastUseMs)
            return false;

        var anchor = GetActiveTwoMinuteBurstWindowAnchor();
        var windowStart = Math.Max(0, anchor - _settings.BurstWindowLeadMs);
        var windowEnd = anchor + _settings.BurstWindowTailMs;

        return lastUseMs >= windowStart && lastUseMs <= windowEnd;
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
    private static bool IsParadoxReady() => BLMHelper.悖论指示;
    private static bool HasFirestarter() => HelperRuntime.HasStatus(BLMHelper.EN.Buffs.Firestarter);
    private static bool HasThunderhead() => HelperRuntime.HasStatus(BLMHelper.EN.Buffs.Thunderhead);
    private static bool HasSwiftcast() => HelperRuntime.HasStatus(BLMHelper.EN.Buffs.Swiftcast);
    private static bool HasTriplecast() => HelperRuntime.HasStatus(BLMHelper.EN.Buffs.Triplecast);
    private static bool HasLeyLines() => HelperRuntime.HasStatus(BLMHelper.EN.Buffs.LeyLines) ||
                                         HelperRuntime.HasStatus(BLMHelper.EN.Buffs.CircleOfPower);

    private static float GetThunderDotTimeLeft()
    {
        return Math.Max(
            HelperRuntime.GetStatusTimeLeftOnTarget(BLMHelper.EN.Buffs.HighThunder),
            Math.Max(
                HelperRuntime.GetStatusTimeLeftOnTarget(BLMHelper.EN.Buffs.ThunderIII),
                HelperRuntime.GetStatusTimeLeftOnTarget(BLMHelper.EN.Buffs.ThunderIV)));
    }

    private static float GetAoeThunderDotTimeLeft()
    {
        return Math.Max(
            HelperRuntime.GetStatusTimeLeftOnTarget(BLMHelper.EN.Buffs.HighThunderII),
            Math.Max(
                HelperRuntime.GetStatusTimeLeftOnTarget(BLMHelper.EN.Buffs.ThunderIV),
                HelperRuntime.GetStatusTimeLeftOnTarget(BLMHelper.EN.Buffs.ThunderIII)));
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
        return GetCurrentTarget() is not null;
    }

    private static IBattleChara? GetCurrentTarget()
    {
        return global::HiAuRo.Data.Target.Current is IBattleChara target &&
               target.CurrentHp > 0 &&
               target.IsDead != true &&
               target.IsTargetable
            ? target
            : null;
    }

    private static Spell BestAoeTargetSpell(uint actionId)
    {
        return new Spell(actionId, () => GetBestAoeTarget(actionId));
    }

    private static IBattleChara GetBestAoeTarget(uint actionId)
    {
        return TargetHelper.GetMostCanTargetObjects(actionId, _settings.AoeEnemyCount, 5f)
            ?? GetCurrentTarget()!;
    }

    private static int GetEnemyCountNearTarget(float range)
    {
        var nearTarget = HelperRuntime.GetEnemyCountNearTarget(range);
        return nearTarget > 0 ? nearTarget : HelperRuntime.GetNearbyEnemyCount(range);
    }

    private static bool LevelAtLeast(int level)
    {
        var currentLevel = HelperRuntime.GetCurrentLevel();
        return currentLevel > 0 && currentLevel >= level;
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
