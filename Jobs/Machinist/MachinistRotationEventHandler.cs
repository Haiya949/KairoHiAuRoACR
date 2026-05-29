namespace KairoHiAuRoACR.Jobs.Machinist;

public sealed class MachinistRotationEventHandler : IRotationEventHandler
{
    public void OnPreCombat()
    {
    }

    public void OnResetBattle()
    {
        MachinistSpellHelper.Reset();
    }

    public void OnNoTarget()
    {
    }

    public void OnSpellCastSuccess(Slot slot, Spell spell)
    {
        MachinistSpellHelper.RecordCombatActionUse(spell.Id);
    }

    public void BeforeSpell(Slot slot, Spell spell)
    {
    }

    public void AfterSpell(Slot slot, Spell spell)
    {
    }

    public void OnBattleUpdate(int battleTimeMs)
    {
        MachinistSpellHelper.UpdateBattleTime(battleTimeMs);
    }

    public void OnTerritoryChanged()
    {
        MachinistSpellHelper.Reset();
    }

    public void OnGameEvent(ITriggerCondParams eventParams)
    {
    }

    public void OnPhaseChanged(string phaseId, string phaseName)
    {
    }
}
