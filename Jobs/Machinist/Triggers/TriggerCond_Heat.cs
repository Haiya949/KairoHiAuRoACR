using HiAuRo.Execution;

namespace KairoHiAuRoACR.Jobs.Machinist;

[TriggerDisplay("机工/热量条件", "等待机工热量大于等于指定值")]
[TriggerTypeName("KairoMCHHeatCondition")]
public sealed class TriggerCond_Heat : ITriggerCond
{
    public int Heat { get; set; } = 50;
    public string Remark { get; set; } = string.Empty;

    public bool Handle(ITriggerCondParams? condParams = null)
    {
        return MCHHelper.HeatGauge >= Heat;
    }

    public void Draw(IUiBuilder builder)
    {
        builder.AddIntInput(nameof(Heat), Heat, 1, 10);
        builder.AddLabel("当前热量大于等于该值时通过。");
    }
}
