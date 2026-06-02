using ActionId = HiAuRo.Helper.MCHHelper.EN.Skills;

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
        builder.AddDropdown("机器人策略", MachinistSettings.BatteryStrategyOptions, ref _settings.BatteryStrategy);
        builder.AddIntInput("机器人阈值优先电量", ref _settings.BatteryThresholdStrategySpendThreshold, 5, 10);
        builder.AddFloatInput("日随保留爆发血量阈值", ref _settings.DailyWeakTargetBurstHpThreshold);
        builder.AddFloatInput("日随泄资源血量阈值", ref _settings.DailyDumpResourcesHpThreshold);
        builder.AddCheckbox("日随小怪资源保护", ref _settings.DailyMinionResourceGuardEnabled);
        builder.AddFloatInput("日随机器人血量阈值", ref _settings.DailyQueenHpThreshold);

        builder.AddGroup("快捷动作");
        builder.AddQtHotkey("爆发药", new HotkeyResolver_Potion());
        builder.AddQtHotkey("冲刺", new HotkeyResolver_NormalSpell(ActionId.Sprint, "冲刺", SpellTargetType.Self));
        builder.AddQtHotkey("极限技", new HotkeyResolver_LB());
        builder.AddQtHotkey("策动", new HotkeyResolver_NormalSpell(ActionId.Tactician, "策动", SpellTargetType.Self));
        builder.AddQtHotkey("武装解除", new HotkeyResolver_NormalSpell(ActionId.Dismantle, "武装解除"));
        builder.AddQtHotkey("内丹", new HotkeyResolver_NormalSpell(ActionId.SecondWind, "内丹", SpellTargetType.Self));
        builder.AddQtHotkey("亲疏自行", new HotkeyResolver_NormalSpell(ActionId.ArmsLength, "亲疏自行", SpellTargetType.Self));
        builder.AddQtHotkey("伤头", new HotkeyResolver_NormalSpell(ActionId.HeadGraze, "伤头"));
        builder.AddQtHotkey("伤腿", new HotkeyResolver_NormalSpell(ActionId.LegGraze, "伤腿"));
        builder.AddQtHotkey("伤足", new HotkeyResolver_NormalSpell(ActionId.FootGraze, "伤足"));
    }
}
