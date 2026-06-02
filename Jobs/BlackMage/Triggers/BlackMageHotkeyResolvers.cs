using OmenTools.Interop.Game.Lumina;

namespace KairoHiAuRoACR.Jobs.BlackMage.Triggers;

public sealed class BlackMageSpellHotkeyResolver : IHotkeyResolver
{
    private readonly uint _actionId;
    private readonly SpellTargetType _targetType;
    private readonly SpellCategory _category;

    public BlackMageSpellHotkeyResolver(
        string id,
        string label,
        uint actionId,
        SpellTargetType targetType = SpellTargetType.Target,
        SpellCategory category = SpellCategory.Default)
    {
        Id = id;
        Label = label;
        _actionId = actionId;
        _targetType = targetType;
        _category = category;
        IconId = actionId == 0 ? 0 : LuminaWrapper.GetActionIconID(actionId);
    }

    public string Id { get; }
    public string Label { get; }
    public string DefaultKey => string.Empty;
    public uint IconId { get; }

    public int Check()
    {
        if (_category == SpellCategory.LimitBreak)
            return 0;

        if (_actionId == 0)
            return -1;

        return SpellHelper.CanUseSpell(_actionId) ? 0 : -1;
    }

    public void Execute()
    {
        if (_actionId == 0 && _category != SpellCategory.LimitBreak)
            return;

        var slot = new Slot();
        slot.Add(new Spell
        {
            Id = _actionId,
            Name = Label,
            TargetType = _targetType,
            SpellCategory = _category,
            Type = SpellType.Ability,
        });
        SlotHelper.Execute(slot);
    }
}

public sealed class BlackMagePotionHotkeyResolver : IHotkeyResolver
{
    public string Id => BlackMageHotkeyIds.Potion;
    public string Label => "爆发药";
    public string DefaultKey => string.Empty;
    public uint IconId => LuminaWrapper.GetItemIconID(ItemHelper.GetCurrJobPotionItemId());

    public int Check()
    {
        return ItemHelper.CheckCurrJobPotion() ? 0 : -1;
    }

    public void Execute()
    {
        if (!ItemHelper.CheckCurrJobPotion())
            return;

        _ = ItemHelper.ForceUsePotion(ItemHelper.GetCurrJobPotionItemId());
    }
}
