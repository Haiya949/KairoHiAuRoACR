using KairoHiAuRoACR.Jobs.BlackMage.Data;

namespace KairoHiAuRoACR.Jobs.BlackMage;

public sealed class BlackMageRotationUi : IRotationUI
{
    private readonly BlackMageSettings _settings;

    public BlackMageRotationUi(BlackMageSettings settings)
    {
        _settings = settings;
    }

    public void RegisterControls(IAcrUiBuilder builder)
    {
        builder.AddMainControl();
        builder.AddBuiltinQt(BuiltinQt.Burst, true);
        builder.AddBuiltinQt(BuiltinQt.Hold, false);
        builder.AddTab("黑魔法师");

        builder.AddGroup("爆发与资源");
        builder.AddQtToggle(QTKey.ForceBurst, false, "将当前窗口视为爆发期");
        builder.AddQtToggle(QTKey.ForbidBurst, false, "禁止自动使用爆发资源");
        builder.AddQtToggle(QTKey.DumpResources, false, "立即释放可用资源");
        builder.AddQtToggle(QTKey.HoldPolyglot, false, "保留异言/秽浊");
        builder.AddQtToggle(QTKey.DumpPolyglot, false, "立即释放异言/秽浊");
        builder.AddQtToggle(QTKey.HoldTriplecast, false, "保留三连咏唱");
        builder.AddQtToggle(QTKey.DumpTriplecast, false, "允许立即使用三连咏唱");
        builder.AddQtToggle(QTKey.HoldManafont, false, "保留魔泉");
        builder.AddQtToggle(QTKey.DumpManafont, false, "允许立即使用魔泉");
        builder.AddQtToggle(QTKey.HoldLeyLines, false, "保留黑魔纹");
        builder.AddQtToggle(QTKey.DumpLeyLines, false, "允许立即使用黑魔纹");

        builder.AddGroup("移动与目标");
        builder.AddQtToggle(QTKey.ForceMovement, false, "使用移动安全 GCD 策略");
        builder.AddQtToggle(QTKey.ForbidMovement, false, "禁止自动消耗移动工具");
        builder.AddQtToggle(QTKey.Aoe, false, "允许多目标循环");

        builder.AddGroup("循环参数");
        builder.AddIntInput("首个爆发锚点", ref _settings.FirstBurstAnchorMs, 500, 2_500);
        builder.AddIntInput("雷刷新阈值", ref _settings.ThunderRefreshMs, 500, 1_000);
        builder.AddIntInput("通晓倾泻层数", ref _settings.PolyglotDumpStacks, 1, 1);

        builder.AddGroup("快捷动作");
        builder.AddQtHotkey("冲刺", new HotkeyResolver_NormalSpell(BlackMageActionId.Sprint, "冲刺", SpellTargetType.Self));
        builder.AddQtHotkey("极限技", new HotkeyResolver_LB());
        builder.AddQtHotkey("即刻咏唱", new HotkeyResolver_NormalSpell(BlackMageActionId.Swiftcast, "即刻咏唱", SpellTargetType.Self));
        builder.AddQtHotkey("三连咏唱", new HotkeyResolver_NormalSpell(BlackMageActionId.Triplecast, "三连咏唱", SpellTargetType.Self));
        builder.AddQtHotkey("黑魔纹", new HotkeyResolver_NormalSpell(BlackMageActionId.LeyLines, "黑魔纹", SpellTargetType.Self));
        builder.AddQtHotkey("回到魔纹", new HotkeyResolver_NormalSpell(BlackMageActionId.BetweenTheLines, "回到魔纹", SpellTargetType.Self));
        builder.AddQtHotkey("魔纹重置", new HotkeyResolver_NormalSpell(BlackMageActionId.Retrace, "魔纹重置", SpellTargetType.Self));
        builder.AddQtHotkey("魔泉", new HotkeyResolver_NormalSpell(BlackMageActionId.Manafont, "魔泉", SpellTargetType.Self));
        builder.AddQtHotkey("星灵移位", new HotkeyResolver_NormalSpell(BlackMageActionId.Transpose, "星灵移位", SpellTargetType.Self));
        builder.AddQtHotkey("详述", new HotkeyResolver_NormalSpell(BlackMageActionId.Amplifier, "详述", SpellTargetType.Self));
        builder.AddQtHotkey("魔罩", new HotkeyResolver_NormalSpell(BlackMageActionId.Manaward, "魔罩", SpellTargetType.Self));
        builder.AddQtHotkey("以太步", new HotkeyResolver_NormalSpell(BlackMageActionId.AetherialManipulation, "以太步"));
        builder.AddQtHotkey("昏乱", new HotkeyResolver_NormalSpell(BlackMageActionId.Addle, "昏乱"));
        builder.AddQtHotkey("沉稳咏唱", new HotkeyResolver_NormalSpell(BlackMageActionId.Surecast, "沉稳咏唱", SpellTargetType.Self));
        builder.AddQtHotkey("醒梦", new HotkeyResolver_NormalSpell(BlackMageActionId.LucidDreaming, "醒梦", SpellTargetType.Self));
    }
}
