using HiAuRo.Execution;

namespace KairoHiAuRoACR.Jobs.Machinist;

[TriggerDisplay("机工/爆发药", "请求一次机工爆发药热键")]
[TriggerTypeName("KairoMCHPotion")]
public sealed class TriggerAction_Potion : ITriggerAction
{
    public string Remark { get; set; } = string.Empty;

    public bool Handle()
    {
        HotkeyHelper.ExecuteById(MachinistHotkeyIds.Potion);
        return true;
    }

    public void Draw(IUiBuilder builder)
    {
        builder.AddLabel("请求一次机工爆发药热键。");
    }
}
