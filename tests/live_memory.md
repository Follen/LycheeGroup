# 游戏内内存探针

2026-10-18 当前四包安装使用 `live_memory_scenarios.lua`，LycheeUI 内置成本计入 `LycheeGroup`。最新前后结果见[性能文档第 12 节](../perfermance.md#12-当前内存测试与验证状态)。下面其他探针保留了 2026-10-17 独立 LycheeUI 的五包统计口径；再次执行前须按实际安装核对 `packages` 和加载检查，不将已取消的独立库包视为加载失败，也不把旧五包读数直接用于新版本。

此前高频列表刷新使用 `live_list_memory.lua`。关闭主窗并退出 Preview，确保没有在途搜索、申请、招募、战斗、进行中的大秘境或未保存的原生招募草稿。它先正常打开设置、笔记、创建及寻队页，加载全部五包，再进行一次真实赛季地下城搜索。随后经产品原生事件分发入口交替触发整表更新、八条真实记录更新、本地排序筛选及滚动，共 1,280 次操作；每批 16 次，每 4 次刷新原生内存计数，预分配 336 个样本。前 1,024 次没有主动 GC，随后在边界测保留量并完成 256 次重复操作。正常动画保留，不提交申请或发布招募，完成后恢复原筛选、导航和偏好。

```powershell
lycheedev live execute --project D:\Code\wow\addons\LycheeGroup --session <CON-id> --file tests/live_list_memory.lua --request lycheegroup-list-memory-01 --budget-seconds 120 --wait-seconds 25 --policy opaque --format json
```

`live_refresh_memory.lua` 补查真实搜索请求与重开路径：在上述五包预热压测结束后运行，六轮正常搜索动作交替使用刷新和重开，主动请求间隔至少 8 秒；保留服务器失败／节流行为，整个过程不主动 GC。它记录每轮代次、真实队伍数量、页面和行池复用、内存峰值及关闭后结果刷新驱动释放。不得将高频本地事件数写成向服务器发出的搜索次数。

`live_heroic_memory.lua` 测“烈毒之渊（英雄）”的真实列表。它从当前目录查找活动，通过活动行的正常选择处理切换到指定活动，完成六次真实搜索，并在请求间隔中用列表滚轮处理函数往返滚动。随后切换真实团本／成员提示框，以及本地筛选排序。初始加载、全部五包计数和动画均计入；周期采样间隔为 0.5 秒，并采集操作边界。全程自然 GC，关闭后的诊断性 GC 单独报告。正常运行约 85 秒，使用 120 秒执行预算；调用控制器不等于验证物理鼠标命中。

`live_memory_scenarios.lua` 在四个产品包和四页已加载、主窗关闭后补测页面／弹窗生命周期、100 支各 40 人的模拟团本、50 个五人模拟申请批次，以及 1,000 条记录连续三轮编解码。Preview 数据独立，笔记编解码不调用合并保存；场景结束检查存档数量、原生草稿、页面／行池复用及活动清理。预热使用正常页面与本地 Preview，活动选择器仍按首次展开创建；全功能保留量需要另计首次展开后的成本。原生创建框已有文字时跳过真实创建页的反复开关，保留其内容。模拟数据生成的客户端堆净变化单列，不能当作实际数据获取成本或加到四包计数后声称完整归因。周期样本与同步编解码返回边界不能证明函数内部未采到的瞬时峰值。

`live_transfer_memory.lua` 是编解码超标的精简复现：相同 1,000 条记录、每条 198 字节备注加序号，连续三轮；逐轮检查数量、名称和备注往返一致，在各函数返回后刷新五包计数，最后才执行诊断性 GC。使用 25 秒执行预算。工作放在受控 ticker 回调中：曾在槽加载期间同步运行相同代码，五包计数始终不变，故那组读数不用于性能结论。当前有效的前后对比使用相同异步执行方式。

这三个补充探针均不进入产品 TOC。用上面的 `live execute --file` 命令替换文件名，并为新实验选择新的 request；原请求仍待完成时继续使用 `live resume`。原始结果、失败轮次和优化结论统一见[性能文档](../perfermance.md#12-当前内存测试与验证状态)。

以下说明适用于页面开关探针，不能用其空页面读数代替列表刷新结果。

`live_memory.lua` 供当前 LycheeDev Mailbox probe API 执行，不加入插件 TOC。先安装 LycheeGroup 四个产品包及独立 LycheeUI（合计五包）并进入世界，关闭荔枝组队 / Lychee LFG，退出战斗，确保没有申请、招募、进行中的大秘境和未保存的原生招募文本。测试期间不要操作组队窗口。已有笔记和提醒继续保留。

当前已保留 [2026-10-17 v4.4 五包结果](results/memory-2026-10-17-v44.json)：默认浮窗启用，冷起为 Core + LycheeUI，Group、Notes、UI 尚未加载。当前结论与数值统一维护在[性能文档第 12 节](../perfermance.md#12-当前内存测试与验证状态)，[2026-10-16 v3 四包结果](results/memory-2026-10-16-v3.json)继续作为历史记录。本次五包采样早于自动搜索接通和 Preview，只覆盖空业务页面 Lua 计数与已知所有者清理，不代表最新满负载、CPU 或完整引擎资源验收。

在已有、空闲的连接上运行；将 `<CON-id>` 换成当前连接 ID：

```powershell
lycheedev live execute --project D:\Code\wow\addons\LycheeGroup --session <CON-id> --file tests/live_memory.lua --request lycheegroup-memory-01 --budget-seconds 115 --wait-seconds 60 --policy opaque --format json
```

`--wait-seconds` 返回 pending 时继续原请求，不要另建请求重跑。测试动作与静置约 82 秒，另加内存计数和 GC 用时，探针硬期限 110 秒。需要复测时，先确认上一请求结果及 cleanup 已完成。要观察当前五包在业务页面未打开时的加载路径，应在新的 Lua 会话中、使用页面之前运行；不要清空存档制造冷态。

继续等待与结束连接分别使用以下命令；保留同一个连接 ID：

```powershell
lycheedev live resume <CON-id> --project D:\Code\wow\addons\LycheeGroup --wait-seconds 60 --format json
lycheedev live disconnect <CON-id> --project D:\Code\wow\addons\LycheeGroup --wait-seconds 30 --format json
```

流程为：起始自然／GC 双采样 → settings、notes、find、create 各首次观察的打开及关闭 → 预热后五轮自然开关 → 五轮受控 GC 开关 → 最终关闭采样与清理。每个开、关边界均等 1.9 秒，超过 420ms 退场与 1.386s Logo 动画之和。探针本身只操作页面入口，不提交申请、发布或邀请，不改 profiling、记录及动态效果设置。本次保留的 v4.4 结果在自动搜索接通前采集；当前寻队入口会自动发起真实搜索，后续重跑应记录实际返回规模，不沿用空页面结论。运行前应退出显式 Preview 模拟。每次 `after_gc` 只执行完整 GC，不改变 GC 的运行策略。

结果字段：

- `packages` 顺序为 `LycheeGroup`、`LycheeGroup_Group`、`LycheeGroup_Notes`、`LycheeGroup_UI`、`LycheeUI`。每条 `samples` 的 `addonKB`、`loaded` 按同样顺序排列；`addonTotalKB` 为五包之和。每次计数前都会调用原生全局 `UpdateAddOnMemoryUsage()`。
- `summary` 比较 `warmed_closed_baseline` 与 `final_closed` 的 `after_gc` 样本，直接给出五包各自增量、五包总增量及客户端 Lua 堆增量，并保留两个样本的标签和下标。负增量也原样保留，不据此设置任意泄漏门槛。
- `mode=natural` 表示该次读数没有主动 GC；`after_gc` 表示显式完整 GC 后的保留量。初始、预热结束和阶段边界有受控 GC，因此自然阶段表示这些边界之后没有主动 GC，不能冒称全程未干预。`counterRefreshMs`、`gcMs` 单独记录观测操作时间。
- `luaHeapKB`、`luaHeapAfterRefreshKB` 是整个客户端 Lua 堆，包含其他插件、测试源码和预分配报告对象；不能把它们的增量归给荔枝组队。探针不报告进程内存、原生纹理内存、累计分配或没有采到的峰值，也不设置未经测量的达标门槛。
- `loadedAtStart`、`pageBuiltAtStart` 决定哪些首次打开实际是冷路径。`coreOnlyAtStart=true` 要求当前 Lua 会话中五包只有主包已加载；`businessPagesUnloadedAtStart=true` 表示 Group、Notes、LycheeGroup_UI 尚未加载，允许 LycheeUI 已加载。默认启用浮窗时通常是核心加共享库，不能把业务页面未开等同于仅核心。保持实际设置，不为冷态关闭默认功能；测试无法卸载已加载的包或撤回首次加载成本。
- `initialClosedOwners`、`closedOwnersBeforeCleanup`、`closedOwnersAfterCleanup` 记录初始、清理前后已知所有者：动画任务和驱动、Group 视图、搜索结果、申请、申请者及额外事件。只检查本产品已有对象，不扫描整个游戏 Frame，也不能证明所有未知 timer 都为零。启用且有记录时，笔记提醒是预期后台业务。
- `checks` 单独给出清理前空闲状态、探针资源释放和原隐藏页面恢复结果。LycheeDev 的 `report.ok` 表示探针执行结果；判断残留还要查看这些字段。清理前结果保留，即使清理过程随后停止了测试产生的动画。

一个 ticker、两个包装回调和最多 32 个预分配样本组成全部测试驱动。完成、报错、取消或超时都会取消 ticker、撤销测试事件和脚本，并恢复原来的隐藏页面。五包加载及正常页面创建留下的可复用对象如实保留；申请、招募和笔记提醒不被测试清理。若测试期间出现真实业务、战斗或切出世界，探针会停止，需先处理原请求的失败与清理结果。
