# 机工 HiAuRo 作者指南遵循补充

本文只记录机工专属合规边界。通用检查表见 `docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md`。

## 当前状态

- MCH 已接基础最近敌人 `TargetResolver`，由 HiAuRo Runtime 在各状态统一调度；ACR 主控不再暴露手动目标选择。
- MCH 已接 HiAuRo 原生 `IOpener` 起手，并按当前 `CountDownHandler` 整数秒接口使用 4s prepull Reassemble。
- HiAuRo Runtime v0.1.83 会在倒计时开始事件重置 `CountDownHandler` / `OpenerMgr` 并懒注册 `InitCountDown`，倒计时结束后自动启动 `OpenerMgr`；普通 ACR 循环仍只在 `CombatContext.State.InCombat` 后执行。
- 副本时间线、事实轴、辅助轴策略尚未接入 Kairo 机工逻辑。
- 游戏内 visible UI labels should be Chinese by default；机工面板、QT、Hotkey 和触发器作者界面新增文案需要保持中文。

## MCH 起手边界

- `MachinistOpener` 作为 HiAuRo `IOpener` 倒计时和起手入口，`InitCountDown` 声明 4s prepull Reassemble。
- 完整多 GCD 起手写进 `IOpener.Sequence`，由 Runtime `OpenerMgr` 在倒计时结束或进入战斗后启动。
- 每个起手 Slot 以 GCD 开头，后接该 GCD 后的固定 oGCD；Runtime v0.1.83 按 ActionCategory/recast group 判断 GCD/oGCD，ACR 保留 `SpellType.Ability` 标记用于兼容事件记录。
- 倒计时阶段的 production opener logic 只走 Runtime `CountDownHandler` 处理已注册动作；ACR 代码不直接读取 `Countdown.CountdownTimer`，也不在职业侧重注册或排队倒计时技能。
- ACR 面板不保留 Runtime 倒计时/起手调试诊断；需要排查时临时加日志，问题定位后移除。
