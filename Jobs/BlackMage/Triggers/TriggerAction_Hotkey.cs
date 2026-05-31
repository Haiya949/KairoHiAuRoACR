using System.Text.Json.Serialization;
using HiAuRo.Execution;

namespace KairoHiAuRoACR.Jobs.BlackMage.Triggers;

[TriggerDisplay("黑魔/热键", "请求一次黑魔 ACR 热键动作")]
[TriggerTypeName("KairoBLMHotkey")]
public sealed class TriggerAction_Hotkey : ITriggerAction
{
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public BlackMageHotkeyAction Key { get; set; } = BlackMageHotkeyAction.Potion;

    public string Remark { get; set; } = string.Empty;

    public bool Handle()
    {
        if (Key == BlackMageHotkeyAction.Potion)
        {
            HotkeyHelper.ExecuteById(BlackMageHotkeyIds.Potion);
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
        builder.AddDropdown(nameof(Key), Enum.GetNames<BlackMageHotkeyAction>(), Key.ToString());
        builder.AddLabel($"当前动作：{GetDisplayName(Key)}");
        builder.AddLabel(GetDescription(Key));
    }

    private static Spell? CreateSpell(BlackMageHotkeyAction key)
    {
        return key switch
        {
            BlackMageHotkeyAction.Swiftcast => SelfAbility(BLMHelper.EN.Skills.Swiftcast, "即刻咏唱"),
            BlackMageHotkeyAction.Triplecast => SelfAbility(BLMHelper.EN.Skills.Triplecast, "三连咏唱"),
            BlackMageHotkeyAction.LeyLines => SelfAbility(BLMHelper.EN.Skills.LeyLines, "黑魔纹"),
            BlackMageHotkeyAction.BetweenTheLines => SelfAbility(BLMHelper.EN.Skills.BetweenTheLines, "回到魔纹"),
            BlackMageHotkeyAction.Retrace => SelfAbility(BLMHelper.EN.Skills.Retrace, "魔纹重置"),
            BlackMageHotkeyAction.Manafont => SelfAbility(BLMHelper.EN.Skills.Manafont, "魔泉"),
            BlackMageHotkeyAction.Transpose => SelfAbility(BLMHelper.EN.Skills.Transpose, "星灵移位"),
            BlackMageHotkeyAction.Amplifier => SelfAbility(BLMHelper.EN.Skills.Amplifier, "详述"),
            BlackMageHotkeyAction.Manaward => SelfAbility(BLMHelper.EN.Skills.Manaward, "魔罩"),
            BlackMageHotkeyAction.AetherialManipulation => TargetAbility(BLMHelper.EN.Skills.AetherialManipulation, "以太步"),
            BlackMageHotkeyAction.Addle => TargetAbility(BLMHelper.EN.Skills.Addle, "昏乱"),
            BlackMageHotkeyAction.Surecast => SelfAbility(BLMHelper.EN.Skills.Surecast, "沉稳咏唱"),
            BlackMageHotkeyAction.LucidDreaming => SelfAbility(BLMHelper.EN.Skills.LucidDreaming, "醒梦"),
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

    private static string GetDescription(BlackMageHotkeyAction key)
    {
        return key switch
        {
            BlackMageHotkeyAction.Potion => "请求一次爆发药热键。",
            BlackMageHotkeyAction.Swiftcast => "请求一次即刻咏唱。",
            BlackMageHotkeyAction.Triplecast => "请求一次三连咏唱。",
            BlackMageHotkeyAction.LeyLines => "请求一次黑魔纹。",
            BlackMageHotkeyAction.BetweenTheLines => "请求一次回到魔纹。",
            BlackMageHotkeyAction.Retrace => "请求一次魔纹重置。",
            BlackMageHotkeyAction.Manafont => "请求一次魔泉。",
            BlackMageHotkeyAction.Transpose => "请求一次星灵移位。",
            BlackMageHotkeyAction.Amplifier => "请求一次详述。",
            BlackMageHotkeyAction.Manaward => "请求一次魔罩。",
            BlackMageHotkeyAction.AetherialManipulation => "请求一次以太步。",
            BlackMageHotkeyAction.Addle => "请求一次昏乱。",
            BlackMageHotkeyAction.Surecast => "请求一次沉稳咏唱。",
            BlackMageHotkeyAction.LucidDreaming => "请求一次醒梦。",
            _ => key.ToString(),
        };
    }

    private static string GetDisplayName(BlackMageHotkeyAction key)
    {
        return key switch
        {
            BlackMageHotkeyAction.Potion => "爆发药",
            BlackMageHotkeyAction.Swiftcast => "即刻咏唱",
            BlackMageHotkeyAction.Triplecast => "三连咏唱",
            BlackMageHotkeyAction.LeyLines => "黑魔纹",
            BlackMageHotkeyAction.BetweenTheLines => "回到魔纹",
            BlackMageHotkeyAction.Retrace => "魔纹重置",
            BlackMageHotkeyAction.Manafont => "魔泉",
            BlackMageHotkeyAction.Transpose => "星灵移位",
            BlackMageHotkeyAction.Amplifier => "详述",
            BlackMageHotkeyAction.Manaward => "魔罩",
            BlackMageHotkeyAction.AetherialManipulation => "以太步",
            BlackMageHotkeyAction.Addle => "昏乱",
            BlackMageHotkeyAction.Surecast => "沉稳咏唱",
            BlackMageHotkeyAction.LucidDreaming => "醒梦",
            _ => key.ToString(),
        };
    }
}

public enum BlackMageHotkeyAction
{
    Potion,
    Swiftcast,
    Triplecast,
    LeyLines,
    BetweenTheLines,
    Retrace,
    Manafont,
    Transpose,
    Amplifier,
    Manaward,
    AetherialManipulation,
    Addle,
    Surecast,
    LucidDreaming,
}
