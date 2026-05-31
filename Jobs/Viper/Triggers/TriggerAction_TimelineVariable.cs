using System.Text.Json.Serialization;
using HiAuRo.Execution;

namespace KairoHiAuRoACR.Jobs.Viper;

[TriggerDisplay("蝰蛇/时间轴变量", "设置蝰蛇 ACR 的爆发和细分资源变量")]
[TriggerTypeName("KairoVPRTimelineVariable")]
public sealed class TriggerAction_TimelineVariable : ITriggerAction
{
    private static readonly string[] HoldVariables =
    [
        ViperTimelineVariable.HoldSerpentsIre,
        ViperTimelineVariable.HoldReawaken,
        ViperTimelineVariable.HoldDreadwinder,
        ViperTimelineVariable.HoldRattlingCoil,
    ];

    private static readonly string[] DumpVariables =
    [
        ViperTimelineVariable.DumpRattlingCoil,
        ViperTimelineVariable.DumpResources,
    ];

    [JsonConverter(typeof(JsonStringEnumConverter))]
    public ViperTimelineVariableAction Action { get; set; } = ViperTimelineVariableAction.HoldReawaken;

    public bool Value { get; set; } = true;
    public string Remark { get; set; } = string.Empty;

    public bool Handle()
    {
        ViperTimelineState.ExposeDefaults();

        switch (Action)
        {
            case ViperTimelineVariableAction.StartDelayedBurstHold:
                StartDelayedBurstHold();
                return true;
            case ViperTimelineVariableAction.ReleaseDelayedBurstPackage:
                ReleaseDelayedBurstPackage();
                return true;
            case ViperTimelineVariableAction.ResetDelayedBurstPackage:
                ResetDelayedBurstPackage();
                return true;
            case ViperTimelineVariableAction.ResetAllTimelineVariables:
                ViperTimelineState.ResetAll();
                return true;
        }

        var variableName = GetVariableName(Action);
        if (string.IsNullOrWhiteSpace(variableName))
            return false;

        ViperTimelineState.Set(variableName, Value);
        return true;
    }

    public void Draw(IUiBuilder builder)
    {
        builder.AddDropdown(nameof(Action), Enum.GetNames<ViperTimelineVariableAction>(), Action.ToString());
        builder.AddCheckbox(nameof(Value), Value);
        builder.AddLabel($"当前动作：{GetDisplayName(Action)}");
        builder.AddLabel(GetDescription(Action));
    }

    private static void StartDelayedBurstHold()
    {
        ViperTimelineState.Set(ViperTimelineVariable.ForceBurst, false);
        ViperTimelineState.Set(ViperTimelineVariable.ForbidBurst, true);
        ViperTimelineState.SetMany(HoldVariables, true);
        ViperTimelineState.SetMany(DumpVariables, false);
    }

    private static void ReleaseDelayedBurstPackage()
    {
        ViperTimelineState.Set(ViperTimelineVariable.ForceBurst, true);
        ViperTimelineState.Set(ViperTimelineVariable.ForbidBurst, false);
        ViperTimelineState.SetMany(HoldVariables, false);
        ViperTimelineState.SetMany(DumpVariables, true);
    }

    private static void ResetDelayedBurstPackage()
    {
        ViperTimelineState.Set(ViperTimelineVariable.ForceBurst, false);
        ViperTimelineState.Set(ViperTimelineVariable.ForbidBurst, false);
        ViperTimelineState.SetMany(HoldVariables, false);
        ViperTimelineState.SetMany(DumpVariables, false);
    }

    private static string GetVariableName(ViperTimelineVariableAction action)
    {
        return action switch
        {
            ViperTimelineVariableAction.ForceBurst => ViperTimelineVariable.ForceBurst,
            ViperTimelineVariableAction.ForbidBurst => ViperTimelineVariable.ForbidBurst,
            ViperTimelineVariableAction.HoldSerpentsIre => ViperTimelineVariable.HoldSerpentsIre,
            ViperTimelineVariableAction.HoldReawaken => ViperTimelineVariable.HoldReawaken,
            ViperTimelineVariableAction.HoldDreadwinder => ViperTimelineVariable.HoldDreadwinder,
            ViperTimelineVariableAction.HoldRattlingCoil => ViperTimelineVariable.HoldRattlingCoil,
            ViperTimelineVariableAction.DumpRattlingCoil => ViperTimelineVariable.DumpRattlingCoil,
            ViperTimelineVariableAction.DumpResources => ViperTimelineVariable.DumpResources,
            _ => string.Empty,
        };
    }

    private static string GetDescription(ViperTimelineVariableAction action)
    {
        return action switch
        {
            ViperTimelineVariableAction.StartDelayedBurstHold => "打开禁止爆发和全部细分留资源，并关闭释放标记。",
            ViperTimelineVariableAction.ReleaseDelayedBurstPackage => "关闭留资源，打开强制爆发和释放资源标记。",
            ViperTimelineVariableAction.ResetDelayedBurstPackage => "关闭延迟爆发相关的强制、禁止、留资源和释放标记。",
            ViperTimelineVariableAction.ResetAllTimelineVariables => "关闭蝰蛇公开给时间轴使用的全部变量。",
            _ => GetVariableName(action),
        };
    }

    private static string GetDisplayName(ViperTimelineVariableAction action)
    {
        return action switch
        {
            ViperTimelineVariableAction.StartDelayedBurstHold => "延后爆发：开始留资源",
            ViperTimelineVariableAction.ReleaseDelayedBurstPackage => "延后爆发：释放",
            ViperTimelineVariableAction.ResetDelayedBurstPackage => "延后爆发：重置",
            ViperTimelineVariableAction.ResetAllTimelineVariables => "重置全部时间轴变量",
            ViperTimelineVariableAction.ForceBurst => "强制爆发",
            ViperTimelineVariableAction.ForbidBurst => "禁止爆发",
            ViperTimelineVariableAction.HoldSerpentsIre => "保留蛇灵气",
            ViperTimelineVariableAction.HoldReawaken => "保留祖灵降临",
            ViperTimelineVariableAction.HoldDreadwinder => "保留盘蛇资源",
            ViperTimelineVariableAction.HoldRattlingCoil => "保留飞蛇资源",
            ViperTimelineVariableAction.DumpRattlingCoil => "释放飞蛇资源",
            ViperTimelineVariableAction.DumpResources => "倾泻全部资源",
            _ => action.ToString(),
        };
    }
}

public enum ViperTimelineVariableAction
{
    StartDelayedBurstHold,
    ReleaseDelayedBurstPackage,
    ResetDelayedBurstPackage,
    ResetAllTimelineVariables,
    ForceBurst,
    ForbidBurst,
    HoldSerpentsIre,
    HoldReawaken,
    HoldDreadwinder,
    HoldRattlingCoil,
    DumpRattlingCoil,
    DumpResources,
}
