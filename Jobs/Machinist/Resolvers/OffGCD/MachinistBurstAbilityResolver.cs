namespace KairoHiAuRoACR.Jobs.Machinist.Resolvers.OffGCD;

public sealed class MachinistBurstAbilityResolver : ISlotResolver
{
    private const uint GaussRound = 2874;
    private const uint Ricochet = 2890;

    private uint _nextSpell;

    public int Check()
    {
        if (Data.Target.Current == null)
            return -1;

        if (QTHelper.IsEnabled(BuiltinQt.Hold) || !QTHelper.IsEnabled(BuiltinQt.Burst))
            return -1;

        _nextSpell = SelectSpell();
        return _nextSpell != 0 ? 0 : -1;
    }

    public void Build(Slot slot)
    {
        slot.Add(new Spell(_nextSpell, SpellTargetType.Target) { Type = SpellType.Ability });
    }

    private static uint SelectSpell()
    {
        if (new Spell(GaussRound, SpellTargetType.Target).IsReadyWithCanCast())
            return GaussRound;

        if (new Spell(Ricochet, SpellTargetType.Target).IsReadyWithCanCast())
            return Ricochet;

        return 0;
    }
}

