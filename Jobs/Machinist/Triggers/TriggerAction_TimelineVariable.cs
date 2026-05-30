using System.Text.Json.Serialization;
using HiAuRo.Execution;

namespace KairoHiAuRoACR.Jobs.Machinist;

[TriggerDisplay("机工/时间轴变量", "设置机工 ACR 的细分爆发留/放资源变量")]
[TriggerTypeName("KairoMCHTimelineVariable")]
public sealed class TriggerAction_TimelineVariable : ITriggerAction
{
    private static readonly string[] HoldVariables =
    [
        MachinistTimelineVariable.HoldWildfire,
        MachinistTimelineVariable.HoldBarrel,
        MachinistTimelineVariable.HoldCheckmateDoubleCheck,
        MachinistTimelineVariable.HoldBattery,
        MachinistTimelineVariable.HoldHeat,
        MachinistTimelineVariable.HoldStrongGcd,
        MachinistTimelineVariable.HoldReassembleDrill,
    ];

    private static readonly string[] DumpVariables =
    [
        MachinistTimelineVariable.DumpWildfire,
        MachinistTimelineVariable.DumpBarrel,
        MachinistTimelineVariable.DumpCheckmateDoubleCheck,
        MachinistTimelineVariable.DumpBattery,
        MachinistTimelineVariable.DumpHeat,
        MachinistTimelineVariable.DumpStrongGcd,
        MachinistTimelineVariable.DumpReassembleDrill,
    ];

    [JsonConverter(typeof(JsonStringEnumConverter))]
    public MachinistTimelineVariableAction Action { get; set; } = MachinistTimelineVariableAction.HoldHeat;

    public bool Value { get; set; } = true;
    public string Remark { get; set; } = string.Empty;

    public bool Handle()
    {
        MachinistTimelineState.ExposeDefaults();

        switch (Action)
        {
            case MachinistTimelineVariableAction.StartDelayedBurstHold:
                StartDelayedBurstHold();
                return true;
            case MachinistTimelineVariableAction.ReleaseDelayedBurstPackage:
                ReleaseDelayedBurstPackage();
                return true;
            case MachinistTimelineVariableAction.ResetDelayedBurstPackage:
                ResetDelayedBurstPackage();
                return true;
            case MachinistTimelineVariableAction.ResetAllTimelineVariables:
                MachinistTimelineState.ResetAll();
                return true;
        }

        var variableName = GetVariableName(Action);
        if (string.IsNullOrWhiteSpace(variableName))
            return false;

        MachinistTimelineState.Set(variableName, Value);
        return true;
    }

    public void Draw(IUiBuilder builder)
    {
        builder.AddDropdown(nameof(Action), Enum.GetNames<MachinistTimelineVariableAction>(), Action.ToString());
        builder.AddCheckbox(nameof(Value), Value);
        builder.AddLabel($"当前动作：{GetDisplayName(Action)}");
        builder.AddLabel(GetDescription(Action));
    }

    private static void StartDelayedBurstHold()
    {
        MachinistTimelineState.Set(MachinistTimelineVariable.ForceBurst, false);
        MachinistTimelineState.Set(MachinistTimelineVariable.ForbidBurst, true);
        MachinistTimelineState.Set(MachinistTimelineVariable.HoldAllBurst, true);
        MachinistTimelineState.Set(MachinistTimelineVariable.ReleaseDelayedBurst, false);
        MachinistTimelineState.SetMany(HoldVariables, true);
        MachinistTimelineState.SetMany(DumpVariables, false);
    }

    private static void ReleaseDelayedBurstPackage()
    {
        MachinistSpellHelper.ReanchorBurstCycleToCurrentTime();
        MachinistTimelineState.Set(MachinistTimelineVariable.ForceBurst, true);
        MachinistTimelineState.Set(MachinistTimelineVariable.ForbidBurst, false);
        MachinistTimelineState.Set(MachinistTimelineVariable.HoldAllBurst, false);
        MachinistTimelineState.Set(MachinistTimelineVariable.ReleaseDelayedBurst, true);
        MachinistTimelineState.SetMany(HoldVariables, false);
        MachinistTimelineState.SetMany(DumpVariables, true);
    }

    private static void ResetDelayedBurstPackage()
    {
        MachinistTimelineState.Set(MachinistTimelineVariable.ForceBurst, false);
        MachinistTimelineState.Set(MachinistTimelineVariable.ForbidBurst, false);
        MachinistTimelineState.Set(MachinistTimelineVariable.HoldAllBurst, false);
        MachinistTimelineState.Set(MachinistTimelineVariable.ReleaseDelayedBurst, false);
        MachinistTimelineState.SetMany(HoldVariables, false);
        MachinistTimelineState.SetMany(DumpVariables, false);
    }

    private static string GetVariableName(MachinistTimelineVariableAction action)
    {
        return action switch
        {
            MachinistTimelineVariableAction.ForceBurst => MachinistTimelineVariable.ForceBurst,
            MachinistTimelineVariableAction.ForbidBurst => MachinistTimelineVariable.ForbidBurst,
            MachinistTimelineVariableAction.HoldAllBurst => MachinistTimelineVariable.HoldAllBurst,
            MachinistTimelineVariableAction.ReleaseDelayedBurst => MachinistTimelineVariable.ReleaseDelayedBurst,
            MachinistTimelineVariableAction.DumpResources => MachinistTimelineVariable.DumpResources,
            MachinistTimelineVariableAction.HoldWildfire => MachinistTimelineVariable.HoldWildfire,
            MachinistTimelineVariableAction.DumpWildfire => MachinistTimelineVariable.DumpWildfire,
            MachinistTimelineVariableAction.HoldBarrel => MachinistTimelineVariable.HoldBarrel,
            MachinistTimelineVariableAction.DumpBarrel => MachinistTimelineVariable.DumpBarrel,
            MachinistTimelineVariableAction.HoldCheckmateDoubleCheck => MachinistTimelineVariable.HoldCheckmateDoubleCheck,
            MachinistTimelineVariableAction.DumpCheckmateDoubleCheck => MachinistTimelineVariable.DumpCheckmateDoubleCheck,
            MachinistTimelineVariableAction.HoldBattery => MachinistTimelineVariable.HoldBattery,
            MachinistTimelineVariableAction.DumpBattery => MachinistTimelineVariable.DumpBattery,
            MachinistTimelineVariableAction.HoldHeat => MachinistTimelineVariable.HoldHeat,
            MachinistTimelineVariableAction.DumpHeat => MachinistTimelineVariable.DumpHeat,
            MachinistTimelineVariableAction.HoldStrongGcd => MachinistTimelineVariable.HoldStrongGcd,
            MachinistTimelineVariableAction.DumpStrongGcd => MachinistTimelineVariable.DumpStrongGcd,
            MachinistTimelineVariableAction.HoldReassembleDrill => MachinistTimelineVariable.HoldReassembleDrill,
            MachinistTimelineVariableAction.DumpReassembleDrill => MachinistTimelineVariable.DumpReassembleDrill,
            MachinistTimelineVariableAction.OpenerAirAnchorFirst => MachinistTimelineVariable.OpenerAirAnchorFirst,
            _ => string.Empty,
        };
    }

    private static string GetDescription(MachinistTimelineVariableAction action)
    {
        return action switch
        {
            MachinistTimelineVariableAction.StartDelayedBurstHold => "打开禁止爆发、总留资源和各细分留资源，并关闭释放标记。",
            MachinistTimelineVariableAction.ReleaseDelayedBurstPackage => "关闭留资源，打开强制爆发、释放延迟爆发和各细分释放标记。",
            MachinistTimelineVariableAction.ResetDelayedBurstPackage => "关闭延迟爆发相关的强制、禁止、留资源和释放标记。",
            MachinistTimelineVariableAction.ResetAllTimelineVariables => "关闭机工公开给时间轴使用的全部变量。",
            _ => GetVariableName(action),
        };
    }

    private static string GetDisplayName(MachinistTimelineVariableAction action)
    {
        return action switch
        {
            MachinistTimelineVariableAction.StartDelayedBurstHold => "延后爆发：开始留资源",
            MachinistTimelineVariableAction.ReleaseDelayedBurstPackage => "延后爆发：释放",
            MachinistTimelineVariableAction.ResetDelayedBurstPackage => "延后爆发：重置",
            MachinistTimelineVariableAction.ResetAllTimelineVariables => "重置全部时间轴变量",
            MachinistTimelineVariableAction.ForceBurst => "强制爆发",
            MachinistTimelineVariableAction.ForbidBurst => "保留爆发",
            MachinistTimelineVariableAction.HoldAllBurst => "总留资源",
            MachinistTimelineVariableAction.ReleaseDelayedBurst => "释放延后爆发",
            MachinistTimelineVariableAction.DumpResources => "泄资源",
            MachinistTimelineVariableAction.HoldWildfire => "保留野火",
            MachinistTimelineVariableAction.DumpWildfire => "释放野火",
            MachinistTimelineVariableAction.HoldBarrel => "保留枪管",
            MachinistTimelineVariableAction.DumpBarrel => "释放枪管",
            MachinistTimelineVariableAction.HoldCheckmateDoubleCheck => "保留双将/将死",
            MachinistTimelineVariableAction.DumpCheckmateDoubleCheck => "释放双将/将死",
            MachinistTimelineVariableAction.HoldBattery => "保留电量",
            MachinistTimelineVariableAction.DumpBattery => "释放电量",
            MachinistTimelineVariableAction.HoldHeat => "保留热量",
            MachinistTimelineVariableAction.DumpHeat => "释放热量",
            MachinistTimelineVariableAction.HoldStrongGcd => "保留强 GCD",
            MachinistTimelineVariableAction.DumpStrongGcd => "释放强 GCD",
            MachinistTimelineVariableAction.HoldReassembleDrill => "保留整备目标",
            MachinistTimelineVariableAction.DumpReassembleDrill => "释放整备目标",
            MachinistTimelineVariableAction.OpenerAirAnchorFirst => "空气锚起手",
            _ => action.ToString(),
        };
    }
}

public enum MachinistTimelineVariableAction
{
    StartDelayedBurstHold,
    ReleaseDelayedBurstPackage,
    ResetDelayedBurstPackage,
    ResetAllTimelineVariables,
    ForceBurst,
    ForbidBurst,
    HoldAllBurst,
    ReleaseDelayedBurst,
    DumpResources,
    HoldWildfire,
    DumpWildfire,
    HoldBarrel,
    DumpBarrel,
    HoldCheckmateDoubleCheck,
    DumpCheckmateDoubleCheck,
    HoldBattery,
    DumpBattery,
    HoldHeat,
    DumpHeat,
    HoldStrongGcd,
    DumpStrongGcd,
    HoldReassembleDrill,
    DumpReassembleDrill,
    OpenerAirAnchorFirst,
}
