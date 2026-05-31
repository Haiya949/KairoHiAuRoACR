using HiAuRo.Runtime;

namespace KairoHiAuRoACR.Jobs.BlackMage.Opener;

public sealed class BlackMageOpener : IOpener
{
    private const int OpenerSlotMaxDurationMs = 3_500;

    private static readonly Action<Slot>[] StandardOpenerSteps =
    [
        BuildHighThunderSlot,
        BuildSwiftAmplifierSlot,
        BuildFirstFireIvSlot,
        BuildLeyLinesSlot,
        BuildSecondFireIvSlot,
        BuildThirdFireIvSlot,
        BuildFourthFireIvSlot,
        BuildFifthFireIvSlot,
        BuildXenoglossyManafontSlot,
        BuildSixthFireIvSlot,
        BuildFirstFlareStarSlot,
        BuildSeventhFireIvSlot,
        BuildEighthFireIvSlot,
        BuildRefreshHighThunderSlot,
        BuildNinthFireIvSlot,
        BuildTenthFireIvSlot,
        BuildEleventhFireIvSlot,
        BuildTwelfthFireIvSlot,
        BuildSecondFlareStarSlot,
        BuildDespairSlot,
    ];

    private List<Action<Slot>>? _activeSequence;

    public uint Level => 100;

    public List<Action<Slot>> Sequence => _activeSequence ??= BuildSequence();

    public int StartCheck()
    {
        _activeSequence = BuildSequence();
        return CanStart() && _activeSequence.Count > 0 ? 0 : -1;
    }

    public int StopCheck(int index) => -1;

    private static bool CanStart()
    {
        return !BlackMageSpellHelper.ShouldStopActions() &&
               BlackMageSpellHelper.ShouldUseOpenerSequence();
    }

    private static List<Action<Slot>> BuildSequence()
    {
        return StandardOpenerSteps.ToList();
    }

    public void InitCountDown(CountDownHandler handler)
    {
        handler.AddAction(4_000, BLMHelper.EN.Skills.FireIII, SpellTargetType.Target);
    }

    private static void BuildHighThunderSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddTargetGcd(slot, BLMHelper.EN.Skills.HighThunder);
    }

    private static void BuildSwiftAmplifierSlot(Slot slot)
    {
        slot.MaxDuration = 1_600;
        slot.AddDelaySpell(450, SelfAbility(BLMHelper.EN.Skills.Swiftcast));
        slot.Add2NdWindowAbility(SelfAbility(BLMHelper.EN.Skills.Amplifier));
    }

    private static void BuildFirstFireIvSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddTargetGcd(slot, BLMHelper.EN.Skills.FireIV);
    }

    private static void BuildLeyLinesSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddSelfAbility(slot, BLMHelper.EN.Skills.LeyLines);
    }

    private static void BuildSecondFireIvSlot(Slot slot)
    {
        BuildFireIvSlot(slot);
    }

    private static void BuildThirdFireIvSlot(Slot slot)
    {
        BuildFireIvSlot(slot);
    }

    private static void BuildFourthFireIvSlot(Slot slot)
    {
        BuildFireIvSlot(slot);
    }

    private static void BuildFifthFireIvSlot(Slot slot)
    {
        BuildFireIvSlot(slot);
    }

    private static void BuildXenoglossyManafontSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddTargetGcd(slot, BLMHelper.EN.Skills.Xenoglossy);
        AddSelfAbility(slot, BLMHelper.EN.Skills.Manafont);
    }

    private static void BuildSixthFireIvSlot(Slot slot)
    {
        BuildFireIvSlot(slot);
    }

    private static void BuildFirstFlareStarSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddTargetGcd(slot, BLMHelper.EN.Skills.FlareStar);
    }

    private static void BuildSeventhFireIvSlot(Slot slot)
    {
        BuildFireIvSlot(slot);
    }

    private static void BuildEighthFireIvSlot(Slot slot)
    {
        BuildFireIvSlot(slot);
    }

    private static void BuildRefreshHighThunderSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddTargetGcd(slot, BLMHelper.EN.Skills.HighThunder);
    }

    private static void BuildNinthFireIvSlot(Slot slot)
    {
        BuildFireIvSlot(slot);
    }

    private static void BuildTenthFireIvSlot(Slot slot)
    {
        BuildFireIvSlot(slot);
    }

    private static void BuildEleventhFireIvSlot(Slot slot)
    {
        BuildFireIvSlot(slot);
    }

    private static void BuildTwelfthFireIvSlot(Slot slot)
    {
        BuildFireIvSlot(slot);
    }

    private static void BuildSecondFlareStarSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddTargetGcd(slot, BLMHelper.EN.Skills.FlareStar);
    }

    private static void BuildDespairSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddTargetGcd(slot, BLMHelper.EN.Skills.Despair);
    }

    private static void BuildFireIvSlot(Slot slot)
    {
        PrepareOpenerSlot(slot);
        AddTargetGcd(slot, BLMHelper.EN.Skills.FireIV);
    }

    private static void PrepareOpenerSlot(Slot slot)
    {
        slot.MaxDuration = OpenerSlotMaxDurationMs;
    }

    private static void AddTargetGcd(Slot slot, uint actionId)
    {
        slot.Add(new Spell(actionId, SpellTargetType.Target));
    }

    private static void AddSelfAbility(Slot slot, uint actionId)
    {
        slot.Add(SelfAbility(actionId));
    }

    private static Spell SelfAbility(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Self) { Type = SpellType.Ability };
    }
}
