# Black Mage Development

## Scope

Black Mage code lives under `Jobs/BlackMage/`. Other jobs are read-only templates; do not modify them while working on BLM.

`E:\ff14\ACR\Kairo\BlackMage` is strategy reference only. Do not migrate AEAssist APIs, timeline runtime, old QT plumbing, or old target/countdown bridges.

## HiAuRo Boundary

- Follow `E:\ff14\HiAuRo\HiAuRo-master\doc\ACR_AUTHOR_GUIDE.md` first.
- Use HiAuRo native `IRotationEntry`, `Rotation`, `IOpener`, `ISlotResolver`, `IAcrUiBuilder`, and `CountDownHandler`.
- Use `HiAuRo.Helper` for BLM skill IDs, buff IDs, and gauge data. Current code uses `BLMHelper.EN.Skills`, `BLMHelper.EN.Buffs`, and BLM gauge shortcuts.
- Do not keep local `BlackMageActionId` or `BlackMageStatusId` catalogs when Helper has the relevant values.

## Timeline Boundary

The original Black Mage ACR has timeline variables for burst, resource holds, movement, downtime recovery, and AoE control. These names may remain as future design vocabulary, but the HiAuRo migration does not migrate the old timeline runtime.

迁移规则：允许保留时间轴变量名作为未来接口词汇，但本次不要迁移时间轴运行时。

Current production BLM must not reference `TimelineController`, old `BlackMageTimeline*` classes, or AEAssist timeline APIs. Timeline behavior should later be rebuilt through HiAuRo-supported execution axis, fact axis, trigger, QT, hotkey, or event mechanisms.

## Current Strategy Notes

- Level 100 opener uses native countdown Fire III at `4_000` ms. The whole fixed opener is written in `IOpener.Sequence`: High Thunder, delayed Swiftcast plus Amplifier, five Fire IV, Xenoglossy plus Manafont, the sixth Fire IV, Flare Star, the seventh and eighth Fire IV, High Thunder refresh, four more Fire IV, Flare Star, then Despair.
- The in-combat opener uses an `IOpener.Sequence` snapshot built in `StartCheck()` and `StopCheck()` returns `-1`, matching the Runtime `OpenerMgr` contract. Required opener GCD steps are queued directly so `OpenerMgr` waits for GCD readiness instead of skipping an empty slot and letting Ley Lines or the normal loop run early. Fixed opener Slots use a long Runtime wait window so GCD / oGCD readiness gaps do not skip the 5+7 sequence.
- FFLogs dummy regression `dpVXCPM1T723KfrH` fight 15 showed the bad shape this guards against: Fire III at pull, High Thunder, Swiftcast, Amplifier, Ley Lines before the first Fire IV, then a second Fire III during the opener fire phase. Firestarter Fire III is blocked after the first opener Fire IV until the first Blizzard III transition so it cannot re-enter Astral Fire during the fixed opener tail.
- FFLogs dummy regression `dpVXCPM1T723KfrH` fight 16 guards the whole level-100 5+7 opener package: after five Fire IV casts, the opener sequence must use Xenoglossy, Manafont, the sixth Fire IV, Flare Star, the seventh and eighth Fire IV, refresh High Thunder, four more Fire IV casts, Flare Star, then Despair before entering ice. This fixed package belongs in `IOpener.Sequence`; normal Astral Fire loop guards only remain as safety fallback after the opener has fallen through.
- The base loop keeps the old high-end fire/ice policy: Thunder maintenance, Astral Fire damage phase, Umbral Ice recovery, Fire Paradox, Flare Star at 6 Astral Soul, Despair at fire tail, Polyglot burst/dump gates, and Manafont fire extension.
- The level-100 single-target loop follows the phase order: enter Astral Fire III through Fire III plus Firestarter when available, cast Fire IV until six Astral Soul are ready for Flare Star, use Paradox in both Astral Fire and Umbral Ice, spend Flare Star, finish remaining Fire IV / Paradox work, cast Despair, then enter Umbral Ice III with Blizzard III. If the fire phase did not enter with Firestarter, such as after the 5+7 opener, Astral Fire Paradox is prioritized before Thunder maintenance so it can generate Firestarter for the next fire entry.
- Astral Fire exit must not stall after Despair. Instant Transpose plus Swiftcast / Triplecast Blizzard III remains preferred when an off-GCD window is available, but once the GCD is ready the loop releases Blizzard III instead of waiting forever for an ideal instant transition.
- Polyglot is routed through one generic burst-package gate instead of old timeline runtime: dump stacks, Manafont bridge, forced movement, DumpResources, DumpPolyglot, and the 120s burst anchor all share the same spending policy before choosing Foul / Xenoglossy.
- The 120s burst window uses elapsed-in-cycle semantics around `FirstBurstAnchorMs`: `BurstWindowLeadMs` is only the pre-anchor window and `BurstWindowTailMs` is only the post-anchor window. The pre-anchor lead belongs to the upcoming anchor, and Ley Lines duplicate protection uses those same active-window boundaries.
- Dummy-loop MP cycle policy keeps the old Transpose recovery guard: when Astral Fire is ready to leave and Swiftcast / Triplecast can make Blizzard III instant, the GCD loop waits for Transpose instead of hardcasting Blizzard III. This protects the Transpose -> instant Blizzard III recovery line seen in the original BLM regression tests.
- Astral Fire exit only waits on full Astral Soul when Flare Star is actually ready/castable; if burst is forbidden or Flare Star is unavailable, the loop may recover to ice instead of stalling at the fire tail.
- No-target downtime recovery is HiAuRo-native: when Runtime has already failed target resolution and calls `OnNoTarget()`, BLM may execute `Umbral Soul` on self through `SlotHelper.Execute()` while in Umbral Ice and still missing MP or Umbral Hearts. This does not migrate the old downtime timeline variables.
- Manafont follows the old high-end resource policy without migrating timeline runtime: the 5+7 opener exception runs first, post-opener Manafont is held for the 120s burst window unless DumpResources / DumpManafont is active, Despair is still checked before dump release, and Swiftcast / Triplecast ice-transition tools yield when a ready Manafont can extend Astral Fire.
- Thunder refresh skips low-value applications during DumpResources or when the current target is at or below 3% HP. This applies to both single-target and AoE Thunder refreshes.
- High-difficulty level profiles are supported across 70/80/90/100 dungeons: below 80 single-target Polyglot falls back to Foul, 80+ uses Xenoglossy, Despair is gated to 72+, and High Thunder / High Thunder II are level-100 choices with Helper action-change fallback below 100.
- Level-profile gates fail closed when `HelperRuntime.GetCurrentLevel()` cannot report a positive level. This prevents 70/80/90 high-difficulty content from accidentally selecting level-100 branches during runtime initialization gaps.
- AoE Thunder refresh tracking covers both the level-100 High Thunder II DoT and the pre-100 Thunder III / Thunder IV DoT statuses, so 70/80/90 high-difficulty AoE does not reapply Thunder every cycle just because High Thunder II is unavailable.
- Level 100 high-end AoE uses the old Transpose-centered Freeze / Flare / Flare Star policy: Freeze rebuilds Umbral Hearts, Transpose carries into Astral Fire, Flare spends the fire phase, and Transpose returns to ice when MP is empty before Flare Star is ready. The 70/80/90 AoE fallback stays on Helper action-change Fire II / Blizzard II plus Freeze / Flare.
- AoE GCDs may use HiAuRo `TargetHelper.GetMostCanTargetObjects` to pick a better AoE center for Freeze, Flare, and legacy AoE fillers. This does not replace Runtime target selection; `Rotation.TargetResolvers` still owns normal current-target selection.
- QT controls are combat-time gates only: burst force/forbid, resource dump/hold, movement force/forbid, and AoE enable.
- Potion remains an explicit Chinese hotkey/timeline request through `KairoBLMPotion` / `KairoBLMHotkey`; do not restore the old persistent `UsePotion` QT or automatic potion resolver.
- Target selection is delegated to Runtime via `Rotation.TargetResolvers`; the BLM UI does not expose manual target mode.
