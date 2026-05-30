# Kairo

Kairo 的 HiAuRo 原生 ACR 工程。这个仓库输出一个总包 `Kairo.dll`，职业按目录拆分到 `Jobs/` 下，当前先放入 MCH 最小可跑入口，后续 21 职业继续扩展进同一个 DLL。

## 最高规则

所有开发必须严格遵循 HiAuRo 官方文档：

- 本地文档：`E:\ff14\HiAuRo\HiAuRo-master\doc\ACR_AUTHOR_GUIDE.md`
- 在线文档：[ACR_AUTHOR_GUIDE.md](https://github.com/denghaoxuan991876906/HiAuRo/blob/master/doc/ACR_AUTHOR_GUIDE.md)

如果本仓库文档、个人习惯和官方文档冲突，以官方 `ACR_AUTHOR_GUIDE.md` 为准。

## 文档

| 文档 | 说明 |
|------|------|
| [开发规范](docs/DEVELOPMENT.md) | 工程边界、Helper 引用、目录约定、构建和部署 |
| [官方文档遵循清单](docs/HI_AURO_AUTHOR_GUIDE_COMPLIANCE.md) | 从运行时全景图、SlotMode、事件、UI、Helper 到验证的硬性检查 |
| [新增职业流程](docs/ADDING_JOB.md) | 从空职业目录到可识别 ACR 的步骤 |

本仓库文档只约束 Kairo 自己的组织方式，不覆盖 HiAuRo 官方规则。

## 快速构建

```powershell
E:\ff14\HiAuRo\KairoHiAuRoACR\scripts\build.ps1
```

输出：

```text
E:\ff14\HiAuRo\KairoHiAuRoACR\bin\Debug\net10.0-windows\Kairo.dll
```

部署到 HiAuRo：

```text
%APPDATA%\XIVLauncherCN\pluginConfigs\HiAuRo\ACR\Kairo\Kairo.dll
```

```powershell
E:\ff14\HiAuRo\KairoHiAuRoACR\scripts\deploy.ps1
```

游戏内执行 `/hi reload` 或重启插件后重新扫描。
