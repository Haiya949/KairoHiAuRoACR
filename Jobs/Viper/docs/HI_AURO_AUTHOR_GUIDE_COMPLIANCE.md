# 蝰蛇 HiAuRo 作者指南遵循记录

`ViperRotationEntry` 遵循原生 ACR 入口契约：作者为 `Kairo`，`UseCustomUi` 为 false，目标职业为 VPR，`Build(string settingFolder)` 只组装 `Rotation`，不承载重型战斗决策。

Resolver 按优先级排列，并按动作类型使用 `SlotMode.Gcd` 或 `SlotMode.OffGcd`。连携能力、Serpent's Ire 和 True North 是 oGCD resolver；Reawaken、Dreadwinder、Rattling Coil、AoE、远程兜底和基础连击是 GCD resolver。

当前 HiAuRo 运行时是 AE 风格 slot 执行。`ViperQuickOpener` 仍然实现 `IOpener`；`OpenerMgr.UseOpener()` 会把它推入 `BattleData.CurrSequence`，通过 `CountDownHandler` 注册的倒计时 Slither 会插入 `BattleData.NextSlot`。蝰蛇代码不应依赖已移除的三阶段 runner，也不应依赖旧起手的 peek/current-state 接口。

状态访问统一走 `HiAuRo.Helper`，其中 VPR 技能 ID、状态 ID 和量谱数据使用 `HiAuRo.Helper.VPRHelper`。移植代码不应依赖复制出来的本地 ID 目录，也不应依赖旧 AEAssist 职业 API。

目标圈身位显示使用 HiAuRo v0.1.90 的 `HiAuRo.Rendering.PositionalState.Push`，由蝰蛇 GCD slot 构建时推送侧面或背面要求，身位提示交给框架 VFX 指示而不是职业本地 overlay。

由 helper、起手或热键触发生成的每个 oGCD `Spell` 都必须带 `SpellType.Ability`。即使运行时可以推断动作类型，这个显式标记仍是兼容 HiAuRo slot 执行和事件记录所需的约定。

内置 QT 控制注册 Burst、Potion、Hold 和 AoE。职业专用 QT ID 保留在 `QTKey`，时间轴触发只操作 `ViperTimelineState`，不要把隐藏的副本专用逻辑塞进基础循环。

手动热键通过 `SlotHelper.Enqueue` 入队，由框架兼容层负责队列路由，不直接访问 `ACRLifecycle.Runner.SpellQueue`。
