# 私有列表生命周期与自然堆观察

`live_list_lifetime.lua` 只创建一棵有明确锚点的离屏私有控件树和一个私有
LycheeUI Context。它不读取或修改 LycheeGroup 的窗口、preview、配置、搜索、
申请或当前招募；不要求当前招募为空，可在现有招募仍活动时运行。
探针不模拟硬件输入，不修改全局 API，不使用 debug upvalue。

本探针与旧 `live_list_memory.lua` 不同：它只调用
`collectgarbage("count")` 读取整个客户端 Lua 堆，不主动回收、不停止 GC，
也不查询插件归属内存。不要用旧探针替代本检查。

## 离线验证

从 LycheeGroup 根目录运行：

```text
lua tests/test_live_list_lifetime.lua ../LycheeUI
lua tests/test_live_list_lifetime.lua .lycheedev/responsive-layout/before-memory-LycheeUI
```

第一个参数选择待测库；第二个可选参数选择包含 `tests/stubs.lua` 的 fixture
目录，默认 `../LycheeUI`。探针本身接受 `(probe, optionalLibrary)`，离线 harness
通过第二个参数注入待测库，不修改已安装的库全局。

当前源码应 GREEN。冻结的 before-memory 副本应 RED：完整执行后以
`list_lifetime_checks_failed:rekey_fixed` 失败，日志同时保留其余失败检查，
包括固定规则记录重建、状态串行及 terminal 释放残留。RED 不作为成功验收。
离线 harness 还覆盖同一 stub 世界重复执行、执行前／rekey 中／列表阶段取消、
晚到回调、缺库、缺计时器、运行时错误、60 秒自限及各路径的清理。
stub 耗时和堆读数不作为游戏性能结果。

## 原生执行

仅由持有当前连接的主代理注册并执行，不另建并行驱动：

```text
lycheedev live probe put --name private-list-lifetime --file tests/live_list_lifetime.lua --format json
lycheedev live execute --project . --session <CON-id> --probe <immutable-PRB-revision> --request <stable-request-key> --budget-seconds 70 --policy observation --wait-seconds 120 --format json
```

保存 CLI 返回的不可变 PRB revision。比较两份源码快照时使用同一探针
revision，并分别记录实际已加载的库语义版本、源码标识和客户端 build。
外层 70 秒预算包含传输及清理；探针自身 `Async(60)`，并在每次回调检查
60 秒截止时间。进入战斗终止检查。低帧率导致未能完成时按失败保留，不延长期限。

## 工作量和结果

只有一个 `probe:Callback` 包裹的 OnUpdate。私有 Context 的调度队列在每个
工作批内显式 Flush，调度 driver 在回调让出前停止。每个工作回调最多执行
20 次逻辑操作，总上限 6000；有界的 setup、cleanup 和结构观察单独记录，
不计作工作负载操作。库内部调用不另算为探针操作。

- catalog、fixed、conditional、classes 四种固定声明各执行 1000 次同规则
  rekey，每批 20 次。记录 controller、records、conditionMatches 身份是否保留，
  以及每种声明的 50 批总耗时、最大批耗时和阶段堆净差。
- 1000 项条件高度列表先执行 8 次预热操作，再执行 200 次滚动、Clear、SetItems
  操作，两个阶段均为每回调最多 2 次，避免将多次原子前缀重建挤在同一帧。
  第 8 次预热操作完成后才固定原生对象数、物理池容量和每行固定记录身份；检查完整高度前缀。
- checked、disabled、selected 换业务 key，含恢复原始 disabled 默认、取消旧 pressed
  identity；这些是程序调用检查，不证明真实鼠标或键盘派发。
- terminal Release 检查数字前缀、元素／行样式绑定、条件订阅、ids、renderer、
  initializer、row-state 字段、pressed key 及私有调度队列。

所有预期检查先记录结果，再统一完成清理和报告。失败使用稳定原因及每条最多
1800 字符的字符串日志，不向 `probe:Log` 传表。日志包含各阶段结构数、堆净差、
四种 rekey 结果、完整检查结果和 cleanup 状态。

`heapNetKiB` 是两个时点的全局 Lua 堆差，可能为负，也包含观察器和客户端其他工作；
它不是累计分配，也不是插件保留量。自然 GC 不受探针控制，不能凭该差值证明
闭包 payload 已回收；这一点由离线弱引用测试另行验证。callback 的最大工作耗时
包含阶段检查和清理，排除最终字符串日志／SDK 完成序列化。原生几何比较允许
最多物理像素的百分之一读回误差，以容纳离屏绝对坐标下的小尺寸 binary32 舍入；
没有物理屏幕信息时，以控件绝对边界和尺寸的四个 ULP 估算。
离线测试接受约 `1.53e-5` UI 单位的读回差，拒绝一个完整物理像素的偏差。

## 清理边界

清理函数先于对象和任务注册。无论成功、失败、取消或超时，都会停止探针 driver，
释放私有 List、逐行释放残留 Element／Style（旧库也执行该兜底），释放其余私有
元素、容器、布局与工作记录，停止 Motion 和 Context 调度 driver，并隐藏私有 host。
terminal 检查先取值，兜底清理随后执行，不能用兜底后的正确状态掩盖旧库释放失败。

原生 Frame／region 不能销毁。清理后它们仍存在，报告将其数量与 Lua 堆读数分开；
重复执行也会留下另一棵隐藏的原生树。cleanup 成功表示监听、任务及可释放的绑定
已退场，不表示客户端回收了这些原生对象。
