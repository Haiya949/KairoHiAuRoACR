# 机工 HiAuRo 作者指南遵循补充

本文只记录机工专属合规边界。通用检查表见 `docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md`。

## 当前状态

- MCH 已接基础最近敌人 `TargetResolver`，由 HiAuRo Runtime 在各状态统一调度；ACR 主控不再暴露手动目标选择。
- MCH 已接 HiAuRo 原生 `IOpener` 起手，并按当前 `CountDownHandler` 毫秒接口使用 4s prepull Reassemble。
- HiAuRo Runtime 现在每帧按 `ACRLifecycle.Update(): Refresh -> UpdateCountDown -> AiLoop.Update(runner)` 推进，`AiLoop.Update` 进入 `AIRunner.CalSlotAsync`；倒计时动作通过 `BattleData.AddSpell2NextSlot(spell)` 进入 `BattleData.NextSlot`，起手由 `OpenerMgr.UseOpener(battleData, rotation)` 推入 `BattleData.CurrSequence`。
- 普通 ACR 循环仍以 `CombatContext.State.InCombat` / Runtime 战斗门控为边界；倒计时和起手只通过 Runtime `NextSlot` / `CurrSequence` 插入，不在 MCH 职业侧自建轮询。
- 副本时间线、事实轴、辅助轴策略尚未接入 Kairo 机工逻辑。
- 游戏内 visible UI labels should be Chinese by default；机工面板、QT、Hotkey 和触发器作者界面新增文案需要保持中文。

## MCH 起手边界

- `MachinistOpener` 作为 HiAuRo `IOpener` 倒计时和起手入口，`InitCountDown` 声明 4s prepull Reassemble。
- 完整多 GCD 起手写进 `IOpener.Sequence`，由 Runtime `OpenerMgr` 在倒计时结束或进入战斗后推入 `BattleData.CurrSequence`。
- 每个起手 Slot 以 GCD 开头，后接该 GCD 后的固定 oGCD；Runtime `SlotExecutor.ResolveSlots(mode)` 和高优先级队列按 GCD/oGCD 分流，ACR 保留 `SpellType.Ability` 标记用于事件记录；prepull Reassemble 通过动态倒计时动作显式标记为 Ability。
- 倒计时阶段的 production opener logic 只走 Runtime `CountDownHandler` 处理已注册动作；ACR 代码不直接读取 `Countdown.CountdownTimer`，也不在职业侧重注册或排队倒计时技能。
- ACR 面板不保留 Runtime 倒计时/起手调试诊断；需要排查时临时加日志，问题定位后移除。
