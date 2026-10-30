# 原生队列入口验证

实现位于 `addon/LycheeGroup/Entrypoints.lua`，行为合同见 [Product.md](../Product.md)，状态与所有权见 [Architecture.md](../Architecture.md)，成本约束见 [perfermance.md](../perfermance.md)。

## 离线回归

```powershell
lua tests/runner.lua core native_queue
```

`core` 检查隐藏选项的恢复、原生动画保留、副本各阶段，以及 PvP 职责确认、就绪确认、排队、暂停、邀请、战场内状态和世界 PvP。覆盖多个队列交错结束、开启／关闭设置及重复刷新。

`native_queue` 从实际 Entrypoints 加载入口，分别模拟原生包已加载和延迟加载。验证原生点击脚本保持同一函数、预组队左键使用独立子按钮、右键透传、目标优先级、申请结束后的事件刷新、按下后目标失效、预览退出和打开失败恢复。三种稳定状态各重复刷新 100 次，要求没有新增 Frame、alpha／鼠标响应／显隐写入或 timer。替身记录子按钮的透传与鼠标移动设置，不模拟游戏的安全执行环境。

## lycheedev 实机检查

复用当前项目及连接；连接中断时先 `live status`，按其 continuation 恢复。将候选文件同步到当前测试客户端后，使用 `live reload` 重载。旧 OnClick 包装产生的菜单污染需要在新 Lua 会话中验证。

```powershell
lycheedev live execute --project . --session <CON> --file tests/live_native_queue.lua --request <唯一检查名> --budget-seconds 10 --wait-seconds 30 --policy observation --format json
lycheedev live bugs --project . --session <CON> --request <唯一错误快照名> --count 10 --wait-seconds 30 --format json
```

`live_native_queue.lua` 只读当前队列、入口显隐、原生 OnClick／OnEnter／OnLeave 身份，以及直属子按钮的透传设置。它不创建菜单、不调用退出队列 API，也不修改设置。一次读取的字段只描述当前客户端状态；空闲快照不能作为各类 PvP 队列已逐项实测的证据。

真实退出检查由玩家点击右键菜单后回报；结合前后队列状态和错误快照记录结果。不从探针手动调用原生 OnClick、菜单回调或受保护退出 API，这会改变要验证的执行路径。本任务不使用 Computer Use。结束后执行 `lycheedev live disconnect <CON> --project . --wait-seconds 30 --format json`，核实关闭及清理结果。

2026-10-30 的修复前拦截、修复后原生脚本身份、玩家右键退出确认和回归结果见 [本轮验证记录](results/native-queue-2026-10-30.json)。
