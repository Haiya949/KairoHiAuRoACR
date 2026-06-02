using KairoHiAuRoACR.Jobs.BlackMage.Triggers;

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
        builder.AddQtHotkey("爆发药", new BlackMagePotionHotkeyResolver());
        builder.AddQtHotkey("冲刺", new BlackMageSpellHotkeyResolver("blm_hk_sprint", "冲刺", 3, SpellTargetType.Self, SpellCategory.Sprint));
        builder.AddQtHotkey("极限技", new BlackMageSpellHotkeyResolver("blm_hk_limit_break", "极限技", SpellsDefine.极限技, SpellTargetType.Target, SpellCategory.LimitBreak));
        builder.AddQtHotkey("即刻咏唱", new BlackMageSpellHotkeyResolver("blm_hk_swiftcast", "即刻咏唱", BLMHelper.EN.Skills.Swiftcast, SpellTargetType.Self));
        builder.AddQtHotkey("三连咏唱", new BlackMageSpellHotkeyResolver("blm_hk_triplecast", "三连咏唱", BLMHelper.EN.Skills.Triplecast, SpellTargetType.Self));
        builder.AddQtHotkey("黑魔纹", new BlackMageSpellHotkeyResolver("blm_hk_ley_lines", "黑魔纹", BLMHelper.EN.Skills.LeyLines, SpellTargetType.Self));
        builder.AddQtHotkey("回到魔纹", new BlackMageSpellHotkeyResolver("blm_hk_between_the_lines", "回到魔纹", BLMHelper.EN.Skills.BetweenTheLines, SpellTargetType.Self));
        builder.AddQtHotkey("魔纹重置", new BlackMageSpellHotkeyResolver("blm_hk_retrace", "魔纹重置", BLMHelper.EN.Skills.Retrace, SpellTargetType.Self));
        builder.AddQtHotkey("魔泉", new BlackMageSpellHotkeyResolver("blm_hk_manafont", "魔泉", BLMHelper.EN.Skills.Manafont, SpellTargetType.Self));
        builder.AddQtHotkey("星灵移位", new BlackMageSpellHotkeyResolver("blm_hk_transpose", "星灵移位", BLMHelper.EN.Skills.Transpose, SpellTargetType.Self));
        builder.AddQtHotkey("详述", new BlackMageSpellHotkeyResolver("blm_hk_amplifier", "详述", BLMHelper.EN.Skills.Amplifier, SpellTargetType.Self));
        builder.AddQtHotkey("魔罩", new BlackMageSpellHotkeyResolver("blm_hk_manaward", "魔罩", BLMHelper.EN.Skills.Manaward, SpellTargetType.Self));
        builder.AddQtHotkey("以太步", new BlackMageSpellHotkeyResolver("blm_hk_aetherial_manipulation", "以太步", BLMHelper.EN.Skills.AetherialManipulation));
        builder.AddQtHotkey("昏乱", new BlackMageSpellHotkeyResolver("blm_hk_addle", "昏乱", BLMHelper.EN.Skills.Addle));
        builder.AddQtHotkey("沉稳咏唱", new BlackMageSpellHotkeyResolver("blm_hk_surecast", "沉稳咏唱", BLMHelper.EN.Skills.Surecast, SpellTargetType.Self));
        builder.AddQtHotkey("醒梦", new BlackMageSpellHotkeyResolver("blm_hk_lucid_dreaming", "醒梦", BLMHelper.EN.Skills.LucidDreaming, SpellTargetType.Self));
    }
}
