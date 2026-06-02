using OmenTools.Interop.Game.Lumina;

namespace KairoHiAuRoACR.Jobs.Viper;

public sealed class ViperPotionHotkeyResolver : IHotkeyResolver
{
    public string Id => ViperHotkeyIds.Potion;
    public string Label => "爆发药";
    public string DefaultKey => string.Empty;
    public uint IconId => LuminaWrapper.GetItemIconID(44163);

    public int Check()
    {
        return ViperSpellHelper.CanUsePotion() ? 0 : -1;
    }

    public void Execute()
    {
        if (!ViperSpellHelper.CanUsePotion())
            return;

        var slot = new Slot();
        slot.Add(Spell.CreatePotion());
        SlotHelper.Enqueue(slot);
        ViperSpellHelper.ConsumeTimelinePotionRequest();
    }
}
