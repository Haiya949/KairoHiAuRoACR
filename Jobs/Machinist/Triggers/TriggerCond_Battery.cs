using HiAuRo.Execution;

namespace KairoHiAuRoACR.Jobs.Machinist;

[TriggerDisplay("机工/电量条件", "等待机工电量大于等于指定值")]
[TriggerTypeName("KairoMCHBatteryCondition")]
public sealed class TriggerCond_Battery : ITriggerCond
{
    public int Battery { get; set; } = 50;
    public string Remark { get; set; } = string.Empty;

    public bool Handle(ITriggerCondParams? condParams = null)
    {
        return MCHHelper.BatteryGauge >= Battery;
    }

    public void Draw(IUiBuilder builder)
    {
        builder.AddIntInput(nameof(Battery), Battery, 1, 10);
        builder.AddLabel("当前电量大于等于该值时通过。");
    }
}
