using HiAuRo.Runtime;
using KairoHiAuRoACR.Jobs.BlackMage.Data;

namespace KairoHiAuRoACR.Jobs.BlackMage.Opener;

public sealed class BlackMageOpener : IOpener
{
    public uint Level => 100;

    public List<Action<Slot>> Sequence { get; } =
    [
        BuildHighThunderSlot,
        BuildSwiftAmplifierSlot,
        BuildFirstFireIvSlot,
        BuildLeyLinesSlot,
    ];

    public int StartCheck()
    {
        if (BlackMageSpellHelper.ShouldStopActions())
            return -100;

        return BlackMageSpellHelper.ShouldUseOpenerSequence() ? 0 : -1;
    }

    public int StopCheck(int index)
    {
        if (BlackMageSpellHelper.ShouldStopActions())
            return 0;

        if (global::HiAuRo.Data.Target.Current is null)
            return 0;

        return -1;
    }

    public void InitCountDown(CountDownHandler handler)
    {
        handler.AddAction(4_000, BlackMageActionId.FireIII, SpellTargetType.Target);
    }

    private static void BuildHighThunderSlot(Slot slot)
    {
        AddIfReady(slot, BlackMageSpellHelper.GetOpeningHighThunderGcd());
    }

    private static void BuildSwiftAmplifierSlot(Slot slot)
    {
        slot.MaxDuration = 1_600;
        slot.AddDelaySpell(450, SelfAbility(BlackMageActionId.Swiftcast));
        slot.Add2NdWindowAbility(SelfAbility(BlackMageActionId.Amplifier));
    }

    private static void BuildFirstFireIvSlot(Slot slot)
    {
        AddIfReady(slot, BlackMageSpellHelper.GetOpeningFireIvGcd());
    }

    private static void BuildLeyLinesSlot(Slot slot)
    {
        AddIfReady(slot, SelfAbility(BlackMageActionId.LeyLines));
    }

    private static Spell SelfAbility(uint actionId)
    {
        return new Spell(actionId, SpellTargetType.Self) { Type = SpellType.Ability };
    }

    private static void AddIfReady(Slot slot, Spell? spell)
    {
        if (spell is not null && spell.IsReadyWithCanCast())
            slot.Add(spell);
    }
}
