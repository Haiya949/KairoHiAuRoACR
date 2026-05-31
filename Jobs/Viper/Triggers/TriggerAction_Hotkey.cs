using System.Text.Json.Serialization;
using HiAuRo.Execution;
using ActionId = HiAuRo.Helper.VPRHelper.EN.Skills;

namespace KairoHiAuRoACR.Jobs.Viper;

[TriggerDisplay("蝰蛇/热键", "请求一次蝰蛇 ACR 热键动作")]
[TriggerTypeName("KairoVPRHotkey")]
public sealed class TriggerAction_Hotkey : ITriggerAction
{
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public ViperHotkeyAction Key { get; set; } = ViperHotkeyAction.Potion;

    public string Remark { get; set; } = string.Empty;

    public bool Handle()
    {
        if (Key == ViperHotkeyAction.Potion)
        {
            HotkeyHelper.ExecuteById(ViperHotkeyIds.Potion);
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
        builder.AddDropdown(nameof(Key), Enum.GetNames<ViperHotkeyAction>(), Key.ToString());
        builder.AddLabel($"当前动作：{GetDisplayName(Key)}");
        builder.AddLabel(GetDescription(Key));
    }

    private static Spell? CreateSpell(ViperHotkeyAction key)
    {
        return key switch
        {
            ViperHotkeyAction.Sprint => SelfAbility(3, "疾跑"),
            ViperHotkeyAction.TrueNorth => SelfAbility(ActionId.TrueNorth, "真北"),
            ViperHotkeyAction.ArmsLength => SelfAbility(ActionId.ArmsLength, "亲疏自行"),
            ViperHotkeyAction.SecondWind => SelfAbility(ActionId.SecondWind, "内丹"),
            ViperHotkeyAction.Feint => TargetAbility(ActionId.Feint, "牵制"),
            ViperHotkeyAction.Bloodbath => SelfAbility(ActionId.Bloodbath, "浴血"),
            ViperHotkeyAction.LegSweep => TargetAbility(ActionId.LegSweep, "扫腿"),
            ViperHotkeyAction.Slither => TargetAbility(ActionId.Slither, "蛇行"),
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

    private static string GetDescription(ViperHotkeyAction key)
    {
        return key switch
        {
            ViperHotkeyAction.Potion => "请求一次爆发药热键。",
            ViperHotkeyAction.Sprint => "请求一次疾跑。",
            ViperHotkeyAction.TrueNorth => "请求一次真北。",
            ViperHotkeyAction.ArmsLength => "请求一次亲疏自行。",
            ViperHotkeyAction.SecondWind => "请求一次内丹。",
            ViperHotkeyAction.Feint => "请求一次牵制。",
            ViperHotkeyAction.Bloodbath => "请求一次浴血。",
            ViperHotkeyAction.LegSweep => "请求一次扫腿。",
            ViperHotkeyAction.Slither => "请求一次蛇行。",
            _ => key.ToString(),
        };
    }

    private static string GetDisplayName(ViperHotkeyAction key)
    {
        return key switch
        {
            ViperHotkeyAction.Potion => "爆发药",
            ViperHotkeyAction.Sprint => "疾跑",
            ViperHotkeyAction.TrueNorth => "真北",
            ViperHotkeyAction.ArmsLength => "亲疏自行",
            ViperHotkeyAction.SecondWind => "内丹",
            ViperHotkeyAction.Feint => "牵制",
            ViperHotkeyAction.Bloodbath => "浴血",
            ViperHotkeyAction.LegSweep => "扫腿",
            ViperHotkeyAction.Slither => "蛇行",
            _ => key.ToString(),
        };
    }
}

public enum ViperHotkeyAction
{
    Potion,
    Sprint,
    TrueNorth,
    ArmsLength,
    SecondWind,
    Feint,
    Bloodbath,
    LegSweep,
    Slither,
}
