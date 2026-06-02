# 蝰蛇开发记录

本目录是 Kairo 蝰蛇在 HiAuRo 原生框架下的移植。当前范围是完整策略迁移：高难和日随战斗策略都收敛在 `ViperSpellHelper`，包括 Reawaken、Dreadwinder、Rattling Coil、AoE、远程兜底、连携 oGCD、Serpent's Ire、True North、爆发药请求和时间轴变量门控。

蝰蛇目录不能引入旧 AEAssist 运行时对象。`ViperRotationEntry` 只负责 HiAuRo 原生接线：`IRotationEntry`、`ISettingsProvider<ViperSettings>`、`SlotResolverData`、`ViperQuickOpener`、事件处理器、目标解析器和触发动作。

本体现在使用 AE 风格执行链：`ACRLifecycle.Update()` 先刷新数据，再推进倒计时，随后调用 `AiLoop.Update(runner)`，最终进入 `AIRunner.CalSlotAsync()`。蝰蛇常规循环仍然是按优先级排列的 `SlotResolverData` 列表；运行时由 `SlotExecutor` 判断本帧执行 GCD、oGCD、高优先级 slot、当前序列 slot，还是等待中的 GCD slot。

快速起手保留在原生 `IOpener.Sequence` 接口上。倒计时允许行动后，`OpenerMgr.UseOpener()` 会把 `ViperQuickOpener` 推入 `BattleData.CurrSequence`，因此蝰蛇不应依赖已经移除的 `OpenerMgr.CurrentState` 或 `PeekCurrentSlot` 旧接口。倒计时 Slither 仍通过 `CountDownHandler.AddAction(100, ActionId.Slither, SpellTargetType.Target)` 注册，本体现在会通过 `battleData.AddSpell2NextSlot(spell)` 把它落到 `BattleData.NextSlot`。

蝰蛇热键和爆发药请求统一通过 `SlotHelper.Enqueue(slot)` 入队。这样职业代码只使用公开 Helper 表面，由框架把请求映射到当前 AE 风格队列兼容路径。

时间轴支持只保留公开变量和触发动作契约。不迁移具体时间轴 JSON 到 `Jobs/Viper/docs/execution_timelines`；具体副本时间轴需要等它们按 HiAuRo 触发格式重新编写后再进入蝰蛇目录。

HiAuRo v0.1.90 起通过 `HiAuRo.Rendering.PositionalState.Push` 提供目标圈身位 VFX。蝰蛇会在 Flanksting Strike、Hindsting Strike、Hunter's Coil、Swiftskin's Coil 等侧面或背面 GCD slot 构建时推送该状态；UI 进度只保留为辅助和调试提示。

技能和状态 ID 来自 `HiAuRo.Helper.VPRHelper`。迁移策略需要的蝰蛇状态 ID，包括 Honed Steel、Honed Reavers、Noxious Gnash、Ready to Reawaken、毒类连携状态和 True North，都应放在 `VPRHelper`，不要在职业目录复制一份本地 ID 表。

AoE 和基础连击策略会先消费 Helper 支持的 Honed Steel / Honed Reavers，再按 Noxious Gnash 时机兜底。Dreadwinder 起手判断同时使用充能状态和技能替换校验，避免过期的 Hunter/Swiftskin 替换阻挡新的 Vicewinder 或 Vicepit 链。True North 自动化使用 700 到 1200 毫秒决策窗口，并且不会抢占待执行的连携 oGCD 或 Serpent's Ire。

高难 Serpent's Ire 对齐使用一段 Helper 支持的资源预估。预估会从 `VPRHelper.Gauge` 读取当前 Serpent Offering 和 Rattling Coil，通过 `HelperRuntime.GetCooldownRemaining` 读取 Serpent's Ire / Vicewinder 冷却，并按基础连击三段和一次可用 Dreadwinder 包估算窗口前资源。它可以在花费 50 灵力会导致下一轮 Serpent's Ire 包资源不足时保留 Reawaken，在 Serpent's Ire 前需要 Dreadwinder 充能时保留一层，并在差 10 灵力才能到达下一次 Reawaken 阈值时消耗一发 Rattling Coil。

凡是 oGCD、起手插入能力或热键触发能力，创建 `Spell` 时都必须显式使用 `SpellType.Ability`。这能让 HiAuRo 的事件记录和 slot 执行与官方 `SlotMode` 契约保持一致。

成功施法现在先经过框架的 `SpellCast` / `SpellActionTracker` 路径确认，再由 `OnSpellCastSuccess` 记录蝰蛇本地战斗状态。蝰蛇状态变更应继续放在 `ViperRotationEventHandler.OnSpellCastSuccess`，不要在 resolver 的 `Build()` 里预判成功。

## 迁移审计

旧 Kairo 蝰蛇实现只作为策略参考。HiAuRo 移植版把策略表面保留在原生文件中：

- `ViperRotationEntry` 只接入 VPR，包括起手、目标解析器、事件处理器、时间轴变量触发、热键触发和爆发药触发。
- `ViperSpellHelper` 负责战斗策略：Reawaken、Dreadwinder、Rattling Coil、AoE、远程兜底、基础连击、连携 oGCD、Serpent's Ire、True North、爆发药请求门控、低血量目标保留、两分钟爆发窗口、高难 Serpent's Ire 资源预估、资源倾泻和开战阻塞。
- `ViperTimelineVariable`、`ViperTimelineState` 和 `TriggerAction_TimelineVariable` 保留公开时间轴变量契约：强制或禁止爆发、按资源保留、Rattling Coil 倾泻、全资源倾泻、延迟爆发的保留和释放预设。
- `TriggerAction_Potion` 保留旧受控爆发药规则：只有内置 Potion QT 开启时，时间轴触发才会请求短爆发药窗口。
- `ViperQuickOpener` 作为 `BattleData.CurrSequence` 执行；仅倒计时动作插入 `BattleData.NextSlot`。
- `VPRHelper` 是迁移后 VPR 技能和状态 ID 的来源，包括 Serpent's Tail、Twinfang、Twinblood、True North、毒类连携状态、Noxious Gnash、Ready to Reawaken、Honed Steel 和 Honed Reavers。
- 旧的具体副本时间轴文件不复制到这个职业目录。

当前校验脚本在 `Jobs/Viper/tests/ValidateViperPort.ps1`。声明蝰蛇移植完成前，应同时运行该脚本和解决方案构建。
