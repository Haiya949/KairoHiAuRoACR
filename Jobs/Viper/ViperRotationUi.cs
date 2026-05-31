using ActionId = HiAuRo.Helper.VPRHelper.EN.Skills;

namespace KairoHiAuRoACR.Jobs.Viper;

public sealed class ViperRotationUi : IRotationUI
{
    private readonly ViperSettings _settings;

    public ViperRotationUi(ViperSettings settings)
    {
        _settings = settings;
    }

    public void RegisterControls(IAcrUiBuilder builder)
    {
        builder.AddMainControl();
        builder.AddBuiltinQt(BuiltinQt.Burst, true);
        builder.AddBuiltinQt(BuiltinQt.Potion, false);
        builder.AddBuiltinQt(BuiltinQt.Hold, false);
        builder.AddBuiltinQt(BuiltinQt.AoE, true);

        builder.AddTab("蝰蛇剑士");
        builder.AddGroup("常用开关");
        builder.AddQtToggle(QTKey.DumpResources, false, "立即倾泻祖灵、飞蛇和盘蛇资源");
        builder.AddQtToggle(QTKey.ForceBurst, false, "将当前窗口视为爆发期");
        builder.AddQtToggle(QTKey.ForbidBurst, false, "禁止开启新的爆发资源");
        builder.AddQtToggle(QTKey.AutoTrueNorth, true, "下一刀身位即将失败时自动真北");
        builder.AddQtToggle(QTKey.QuickOpener, true, "启用短起手和倒计时蛇行");
        builder.AddQtToggle(QTKey.RangedFallback, true, "远离近战距离时使用飞蛇之牙保 GCD");

        builder.AddGroup("运行设置");
        builder.AddDropdown("战斗模式", ViperSettings.CombatModeOptions, ref _settings.CombatMode);

        builder.AddGroup("快捷动作");
        builder.AddQtHotkey("爆发药", new ViperPotionHotkeyResolver());
        builder.AddQtHotkey("疾跑", new ViperSpellHotkeyResolver(ViperHotkeyIds.Sprint, "疾跑", 3, SpellTargetType.Self, SpellCategory.Sprint));
        builder.AddQtHotkey("极限技", new ViperSpellHotkeyResolver(ViperHotkeyIds.LimitBreak, "极限技", 0, SpellTargetType.Target, SpellCategory.LimitBreak));
        builder.AddQtHotkey("真北", new ViperSpellHotkeyResolver(ViperHotkeyIds.TrueNorth, "真北", ActionId.TrueNorth, SpellTargetType.Self));
        builder.AddQtHotkey("亲疏自行", new ViperSpellHotkeyResolver(ViperHotkeyIds.ArmsLength, "亲疏自行", ActionId.ArmsLength, SpellTargetType.Self));
        builder.AddQtHotkey("内丹", new ViperSpellHotkeyResolver(ViperHotkeyIds.SecondWind, "内丹", ActionId.SecondWind, SpellTargetType.Self));
        builder.AddQtHotkey("牵制", new ViperSpellHotkeyResolver(ViperHotkeyIds.Feint, "牵制", ActionId.Feint));
        builder.AddQtHotkey("浴血", new ViperSpellHotkeyResolver(ViperHotkeyIds.Bloodbath, "浴血", ActionId.Bloodbath, SpellTargetType.Self));
        builder.AddQtHotkey("扫腿", new ViperSpellHotkeyResolver(ViperHotkeyIds.LegSweep, "扫腿", ActionId.LegSweep));
        builder.AddQtHotkey("蛇行", new ViperSpellHotkeyResolver(ViperHotkeyIds.Slither, "蛇行", ActionId.Slither));
    }
}
