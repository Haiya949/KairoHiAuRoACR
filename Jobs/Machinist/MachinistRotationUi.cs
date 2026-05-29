using KairoHiAuRoACR.Jobs.Machinist.Data;

namespace KairoHiAuRoACR.Jobs.Machinist;

public sealed class MachinistRotationUi : IRotationUI
{
    public void RegisterControls(IUiBuilder builder)
    {
        builder.AddMainControl();
        builder.AddBuiltinQt(BuiltinQt.Burst, true);
        builder.AddBuiltinQt(BuiltinQt.Hold, false);
        builder.AddTab("mch", "MCH");
        builder.AddQtToggle(QTKey.Stop, false, "Stop all MCH actions");
        builder.AddQtToggle(QTKey.DumpResources, false, "Spend resources immediately");
        builder.AddQtToggle(QTKey.ForceBurst, false, "Treat the current window as burst");
        builder.AddQtToggle(QTKey.ForbidBurst, false, "Hold burst resources");
        builder.AddQtToggle(QTKey.HighEndMode, true, "Use two-minute burst planning");
        builder.AddQtToggle(QTKey.Aoe, true, "Enable AOE GCD choices");

        builder.AddQtHotkey("Potion", new HotkeyResolver_Potion());
        builder.AddQtHotkey("Sprint", new HotkeyResolver_NormalSpell(MachinistActionId.Sprint, "Sprint", SpellTargetType.Self));
        builder.AddQtHotkey("Limit Break", new HotkeyResolver_LB());
        builder.AddQtHotkey("Tactician", new HotkeyResolver_NormalSpell(MachinistActionId.Tactician, "Tactician", SpellTargetType.Self));
        builder.AddQtHotkey("Dismantle", new HotkeyResolver_NormalSpell(MachinistActionId.Dismantle, "Dismantle"));
        builder.AddQtHotkey("Second Wind", new HotkeyResolver_NormalSpell(MachinistActionId.SecondWind, "Second Wind", SpellTargetType.Self));
        builder.AddQtHotkey("Arm's Length", new HotkeyResolver_NormalSpell(MachinistActionId.ArmsLength, "Arm's Length", SpellTargetType.Self));
        builder.AddQtHotkey("Head Graze", new HotkeyResolver_NormalSpell(MachinistActionId.HeadGraze, "Head Graze"));
        builder.AddQtHotkey("Leg Graze", new HotkeyResolver_NormalSpell(MachinistActionId.LegGraze, "Leg Graze"));
        builder.AddQtHotkey("Foot Graze", new HotkeyResolver_NormalSpell(MachinistActionId.FootGraze, "Foot Graze"));
    }
}
