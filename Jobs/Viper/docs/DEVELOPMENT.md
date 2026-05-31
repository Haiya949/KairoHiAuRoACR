# Viper Development Notes

This directory is a HiAuRo-native VPR port for Kairo. The scope is 完整策略迁移: keep the migrated high-end and daily combat policies in `ViperSpellHelper`, including Reawaken, Dreadwinder, Rattling Coil, AoE, ranged fallback, follow-up oGCDs, Serpent's Ire, True North, potion requests, and timeline variable gates.

Do not bring old AEAssist runtime objects into this tree. `ViperRotationEntry` owns only HiAuRo-native wiring: `IRotationEntry`, `ISettingsProvider<ViperSettings>`, `SlotResolverData`, `ViperQuickOpener`, event handler, target resolver, and trigger actions.

Timeline support is limited to public variable and trigger action contracts. 不迁移具体时间轴 JSON files into `Jobs/Viper/docs/execution_timelines`; concrete encounter timelines should stay outside this job port until they are authored against HiAuRo's trigger format.

Skill and status IDs come from `HiAuRo.Helper.VPRHelper`. Viper-specific status IDs needed by the migrated strategy, including Honed Steel, Honed Reavers, Noxious Gnash, Ready to Reawaken, venom follow-up auras, and True North, belong in `VPRHelper` instead of a copied job-local status catalog.

AOE and base combo policy consumes Helper-backed Honed Steel / Honed Reavers before falling back to Noxious Gnash timing. Dreadwinder starts use charge readiness plus an action-change sanity gate so stale Hunter/Swiftskin replacements do not block a fresh Vicewinder or Vicepit chain. True North automation uses the 700-1200ms decision window and does not preempt pending follow-up oGCDs or Serpent's Ire.

Ability spells must be created with `SpellType.Ability` whenever the action is an oGCD, opener weave, or hotkey-triggered ability. This keeps HiAuRo event accounting and slot execution aligned with the official SlotMode contract.

## Migration Audit

The old Kairo Viper implementation is used only as strategy reference. The HiAuRo port keeps the strategy surface in native files:

- `ViperRotationEntry` wires VPR only, with opener, target resolver, event handler, timeline variable trigger, hotkey trigger, and potion trigger.
- `ViperSpellHelper` owns the combat strategy: Reawaken, Dreadwinder, Rattling Coil, AoE, ranged fallback, base combo, follow-up oGCDs, Serpent's Ire, True North, potion request gating, weak-target holds, two-minute burst windows, resource dump, and combat-start blocking.
- `ViperTimelineVariable`, `ViperTimelineState`, and `TriggerAction_TimelineVariable` preserve the public timeline variable contract: force/forbid burst, per-resource holds, Rattling Coil dump, all-resource dump, and delayed-burst hold/release presets.
- `TriggerAction_Potion` keeps the old controlled-potion rule: timeline triggers request a short potion window only when the built-in Potion QT is enabled.
- `VPRHelper` is the action/status catalog source for migrated VPR IDs, including Serpent's Tail, Twinfang, Twinblood, True North, venom follow-up auras, Noxious Gnash, Ready to Reawaken, Honed Steel, and Honed Reavers.
- Concrete old encounter timeline files are intentionally not copied into this job folder.

Current verification lives in `Jobs/Viper/tests/ValidateViperPort.ps1` and should be run with the solution build before claiming the Viper port is ready.
