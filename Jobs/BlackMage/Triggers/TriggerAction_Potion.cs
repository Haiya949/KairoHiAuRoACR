using HiAuRo.Execution;

namespace KairoHiAuRoACR.Jobs.BlackMage.Triggers;

[TriggerDisplay("黑魔/爆发药", "请求一次黑魔爆发药热键")]
[TriggerTypeName("KairoBLMPotion")]
public sealed class TriggerAction_Potion : ITriggerAction
{
    public string Remark { get; set; } = string.Empty;

    public bool Handle()
    {
        HotkeyHelper.ExecuteById(BlackMageHotkeyIds.Potion);
        return true;
    }

    public void Draw(IUiBuilder builder)
    {
        builder.AddLabel("请求一次黑魔爆发药热键。");
    }
}
