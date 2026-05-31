namespace KairoHiAuRoACR.Jobs.Viper;

public sealed class ViperRotationEventHandler : IRotationEventHandler
{
    public void OnPreCombat()
    {
        ViperSpellHelper.ResetTimelineManagedQt();
    }

    public void OnResetBattle()
    {
        ViperSpellHelper.ResetCombatState();
        ViperTimelineState.ResetAll();
    }

    public void OnNoTarget()
    {
        ViperSpellHelper.ResetTimelineManagedQt();
        ViperTimelineState.ResetAll();
    }

    public void OnSpellCastSuccess(Slot slot, Spell spell)
    {
        ViperSpellHelper.RecordCombatActionUse(spell.Id);
    }

    public Slot? BeforeSpell(Slot slot)
    {
        return null;
    }

    public void AfterSpell(Slot slot, Spell spell)
    {
    }

    public void OnBattleUpdate(int battleTimeMs)
    {
        ViperSpellHelper.UpdateBattleTime(battleTimeMs);
        ViperSpellHelper.SyncTimelineManagedQt();
    }

    public void OnTerritoryChanged()
    {
        ViperSpellHelper.ResetCombatState();
        ViperTimelineState.ResetAll();
    }

    public void OnGameEvent(ITriggerCondParams eventParams)
    {
    }

    public void OnPhaseChanged(string phaseId, string phaseName)
    {
    }
}
