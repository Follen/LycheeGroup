# 原生 Element 样式布局补充探针

`live_layout_styles.lua` 用独立的离屏 Context 检查 24 个混合子项在三条声明路径中的布局调用和原生读写：没有 Element 样式、用 `C.Element` 类声明固定宽高、以及由一个匹配的容器条件声明宽高。探针不打开产品界面，也不修改用户配置、全局 API 或共享库源码。

每个场景先在 960 宽度重复布局 80 次，再交替设置 720／960 并布局 80 次。宽度变化阶段会刷新容器条件；固定宽高路径继续使用同一份 items 表，不重复调用 `SetItems`。每个 `OnUpdate` 最多执行 20 次稳定布局，宽度变化最多 2 次，以限制一次回调的同步工作。

每个阶段先在没有方法包装器时记录 `debugprofilestop` 样本，再单独统计 `GetSize`、宽高读取与写入、锚点读取与写入，以及私有 Context 的 `C.LayoutValue`／`C.FixedValue` 调用；库提供批量布局值查询时，也统计该查询的调用数，包括内部 `_ReadLayoutValues`。计数表示 Lua 方法调用，不表示硬件操作。探针按声明宽高、固定间距和独立计算的像素边界推导预期尺寸与位置，再比较原生 `GetSize`／`GetPoint` 读数，并按 host 绝对坐标的单精度误差计算容差。对象高水位包含未挂到 host 的 Context scheduler driver；不设置性能合格阈值。容器条件在 960 与 480 两侧都做语义检查；计时阶段的 720／960 均匹配 `minWidth=600` 条件，确认样式值随条件变化并恢复。

正常结束时，`Finish` 报告包含 `business.ok=true` 和清理状态。异常通过 `Fail` 结束，`Log` 只传有长度上限的字符串。完成、失败、取消与迟到回调都会恢复私有 Frame 方法和 Context 查询包装器、释放布局与样式控制器，并隐藏私有 host；同时核对 scheduler 队列、工作、通知、延后队列与条件订阅均已清空，scheduler driver 已停止。

## 离线验证

在 LycheeGroup 目录运行：

```powershell
lua tests/test_live_layout_styles.lua ../LycheeUI
lua tests/test_live_layout_styles.lua addon/LycheeGroup/Libs/LycheeUI
luac -p tests/live_layout_styles.lua
luac -p tests/test_live_layout_styles.lua
```

离线用例覆盖探针完整完成、静态样式和容器条件值、`GetSize` 计数、写入后抛错、取消及迟到回调。native-like 几何夹具接受微小单精度读回偏差，并拒绝超过一个物理像素的偏差。离线计时由假时钟提供，只用于检查生命周期和报告结构，不代表客户端性能。

## LycheeDev 接入

注册后保留命令返回的不可变探针 revision：

```powershell
lycheedev live probe put --name layout-styles --file tests/live_layout_styles.lua --format json
```

使用现有项目和连接执行；将占位符替换为当前会话的项目目录、CON 标识与 PRB revision：

```powershell
lycheedev live execute --project <project-directory> --session <CON-id> --probe <PRB-revision> --request <stable-key> --budget-seconds 35 --policy observation --wait-seconds 120 --format json
```

探针按实际加载的 LycheeUI 运行；省略可选第二参数，不会改动已安装库。结果应保留客户端 build、LycheeUI 语义版本／源码哈希、`report.business.ok`、三个场景的计时与调用计数、条件边界检查和 `cleanup`。`cleanup` 需包含 scheduler 队列／订阅状态与 driver 停止状态。若失败，保留失败报告中的短字符串诊断。
