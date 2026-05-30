namespace KairoHiAuRoACR.Jobs.Machinist.Resolvers.OffGCD;

public sealed class MachinistReassembleResolver : ISlotResolver
{
    private Spell? _spell;
    private uint? _targetActionId;

    public int Check()
    {
        if (MachinistSpellHelper.ShouldStopActions())
            return -100;

        _targetActionId = MachinistSpellHelper.GetReassembleOffGcdTargetActionId();
        _spell = _targetActionId is null ? null : MachinistSpellHelper.GetReassembleOffGcd();
        return _spell is not null ? 0 : -1;
    }

    public void Build(Slot slot)
    {
        if (_spell is null || _targetActionId is null)
            return;

        slot.Add(_spell);
        MachinistSpellHelper.MarkReassembleOffGcdIssued(_targetActionId.Value);
    }
}
