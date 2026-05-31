using HiAuRo.Execution;

namespace KairoHiAuRoACR.Jobs.Viper;

[TriggerDisplay("蝰蛇/爆发药", "请求一次蝰蛇爆发药窗口")]
[TriggerTypeName("KairoVPRPotion")]
public sealed class TriggerAction_Potion : ITriggerAction
{
    public string Remark { get; set; } = string.Empty;

    public bool Handle()
    {
        if (!QTHelper.IsEnabled(BuiltinQt.Potion))
            return false;

        ViperSpellHelper.RequestTimelinePotion();
        HotkeyHelper.ExecuteById(ViperHotkeyIds.Potion);
        return true;
    }

    public void Draw(IUiBuilder builder)
    {
        builder.AddLabel("请求一次短暂的蝰蛇爆发药窗口。");
    }
}
