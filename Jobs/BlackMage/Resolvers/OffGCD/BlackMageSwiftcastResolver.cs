namespace KairoHiAuRoACR.Jobs.BlackMage.Resolvers.OffGCD;

public sealed class BlackMageSwiftcastResolver : ISlotResolver
{
    private Spell? _spell;

    public int Check()
    {
        if (BlackMageSpellHelper.ShouldStopActions())
            return -100;

        _spell = BlackMageSpellHelper.GetSwiftcastOffGcd();
        return _spell is not null ? 0 : -1;
    }

    public void Build(Slot slot)
    {
        if (_spell is not null)
            slot.Add(_spell);
    }
}
