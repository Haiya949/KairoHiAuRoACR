namespace KairoHiAuRoACR.Jobs.Machinist.Resolvers.GCD;

public sealed class MachinistAoeGcdResolver : ISlotResolver
{
    private Spell? _spell;

    public int Check()
    {
        if (MachinistSpellHelper.ShouldStopActions())
            return -100;

        _spell = MachinistSpellHelper.GetAoeGcd();
        return _spell is not null ? 0 : -1;
    }

    public void Build(Slot slot)
    {
        if (_spell is not null)
            slot.Add(_spell);
    }
}
