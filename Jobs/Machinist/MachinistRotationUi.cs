using KairoHiAuRoACR.Jobs.Machinist.Data;

namespace KairoHiAuRoACR.Jobs.Machinist;

public sealed class MachinistRotationUi : IRotationUI
{
    private readonly MachinistSettings _settings;

    public MachinistRotationUi(MachinistSettings settings)
    {
        _settings = settings;
    }

    public void RegisterControls(IAcrUiBuilder builder)
    {
        builder.AddMainControl();
        builder.AddBuiltinQt(BuiltinQt.Burst, true);
        builder.AddBuiltinQt(BuiltinQt.Hold, false);
        builder.AddTab("机工士");
        builder.AddGroup("常用开关");
        builder.AddQtToggle(QTKey.DumpResources, false, "立即倾泻热量和电量资源");
        builder.AddQtToggle(QTKey.ForceBurst, false, "将当前窗口视为爆发期");
        builder.AddQtToggle(QTKey.ForbidBurst, false, "保留爆发资源");
        builder.AddQtToggle(QTKey.Aoe, true, "启用群攻 GCD 选择");

        builder.AddGroup("运行设置");
        builder.AddDropdown("战斗模式", MachinistSettings.CombatModeOptions, ref _settings.CombatMode);
        builder.AddDropdown("目标选择", MachinistSettings.TargetSelectionOptions, ref _settings.TargetSelection);

        builder.AddGroup("快捷动作");
        builder.AddQtHotkey("爆发药", new HotkeyResolver_Potion());
        builder.AddQtHotkey("冲刺", new HotkeyResolver_NormalSpell(MachinistActionId.Sprint, "冲刺", SpellTargetType.Self));
        builder.AddQtHotkey("极限技", new HotkeyResolver_LB());
        builder.AddQtHotkey("策动", new HotkeyResolver_NormalSpell(MachinistActionId.Tactician, "策动", SpellTargetType.Self));
        builder.AddQtHotkey("武装解除", new HotkeyResolver_NormalSpell(MachinistActionId.Dismantle, "武装解除"));
        builder.AddQtHotkey("内丹", new HotkeyResolver_NormalSpell(MachinistActionId.SecondWind, "内丹", SpellTargetType.Self));
        builder.AddQtHotkey("亲疏自行", new HotkeyResolver_NormalSpell(MachinistActionId.ArmsLength, "亲疏自行", SpellTargetType.Self));
        builder.AddQtHotkey("伤头", new HotkeyResolver_NormalSpell(MachinistActionId.HeadGraze, "伤头"));
        builder.AddQtHotkey("伤腿", new HotkeyResolver_NormalSpell(MachinistActionId.LegGraze, "伤腿"));
        builder.AddQtHotkey("伤足", new HotkeyResolver_NormalSpell(MachinistActionId.FootGraze, "伤足"));
    }
}
