using System.Text.Json.Serialization;
using HiAuRo.Execution;
using ActionId = HiAuRo.Helper.MCHHelper.EN.Skills;

namespace KairoHiAuRoACR.Jobs.Machinist;

[TriggerDisplay("机工/热键", "请求一次机工 ACR 热键动作")]
[TriggerTypeName("KairoMCHHotkey")]
public sealed class TriggerAction_Hotkey : ITriggerAction
{
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public MachinistHotkeyAction Key { get; set; } = MachinistHotkeyAction.Potion;

    public string Remark { get; set; } = string.Empty;

    public bool Handle()
    {
        if (Key == MachinistHotkeyAction.Potion)
        {
            HotkeyHelper.ExecuteById(MachinistHotkeyIds.Potion);
            return true;
        }

        var spell = CreateSpell(Key);
        if (spell is null)
            return false;

        var slot = new Slot();
        slot.Add(spell);
        SlotHelper.Enqueue(slot);
        return true;
    }

    public void Draw(IUiBuilder builder)
    {
        builder.AddDropdown(nameof(Key), Enum.GetNames<MachinistHotkeyAction>(), Key.ToString());
        builder.AddLabel($"当前动作：{GetDisplayName(Key)}");
        builder.AddLabel(GetDescription(Key));
    }

    private static Spell? CreateSpell(MachinistHotkeyAction key)
    {
        return key switch
        {
            MachinistHotkeyAction.Sprint => SelfAbility(ActionId.Sprint, "冲刺"),
            MachinistHotkeyAction.Tactician => SelfAbility(ActionId.Tactician, "策动"),
            MachinistHotkeyAction.Dismantle => TargetAbility(ActionId.Dismantle, "武装解除"),
            MachinistHotkeyAction.SecondWind => SelfAbility(ActionId.SecondWind, "内丹"),
            MachinistHotkeyAction.ArmsLength => SelfAbility(ActionId.ArmsLength, "亲疏自行"),
            MachinistHotkeyAction.HeadGraze => TargetAbility(ActionId.HeadGraze, "伤头"),
            MachinistHotkeyAction.LegGraze => TargetAbility(ActionId.LegGraze, "伤腿"),
            MachinistHotkeyAction.FootGraze => TargetAbility(ActionId.FootGraze, "伤足"),
            _ => null,
        };
    }

    private static Spell SelfAbility(uint actionId, string name)
    {
        return new Spell(actionId, SpellTargetType.Self)
        {
            Name = name,
            Type = SpellType.Ability
        };
    }

    private static Spell TargetAbility(uint actionId, string name)
    {
        return new Spell(actionId, SpellTargetType.Target)
        {
            Name = name,
            Type = SpellType.Ability
        };
    }

    private static string GetDescription(MachinistHotkeyAction key)
    {
        return key switch
        {
            MachinistHotkeyAction.Potion => "请求一次爆发药热键。",
            MachinistHotkeyAction.Sprint => "请求一次冲刺。",
            MachinistHotkeyAction.Tactician => "请求一次策动。",
            MachinistHotkeyAction.Dismantle => "请求一次武装解除。",
            MachinistHotkeyAction.SecondWind => "请求一次内丹。",
            MachinistHotkeyAction.ArmsLength => "请求一次亲疏自行。",
            MachinistHotkeyAction.HeadGraze => "请求一次伤头。",
            MachinistHotkeyAction.LegGraze => "请求一次伤腿。",
            MachinistHotkeyAction.FootGraze => "请求一次伤足。",
            _ => key.ToString(),
        };
    }

    private static string GetDisplayName(MachinistHotkeyAction key)
    {
        return key switch
        {
            MachinistHotkeyAction.Potion => "爆发药",
            MachinistHotkeyAction.Sprint => "冲刺",
            MachinistHotkeyAction.Tactician => "策动",
            MachinistHotkeyAction.Dismantle => "武装解除",
            MachinistHotkeyAction.SecondWind => "内丹",
            MachinistHotkeyAction.ArmsLength => "亲疏自行",
            MachinistHotkeyAction.HeadGraze => "伤头",
            MachinistHotkeyAction.LegGraze => "伤腿",
            MachinistHotkeyAction.FootGraze => "伤足",
            _ => key.ToString(),
        };
    }
}

public enum MachinistHotkeyAction
{
    Potion,
    Sprint,
    Tactician,
    Dismantle,
    SecondWind,
    ArmsLength,
    HeadGraze,
    LegGraze,
    FootGraze,
}
