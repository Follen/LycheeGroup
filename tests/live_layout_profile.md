# 私有布局 CPU 与调用计数探针

`live_layout_profile.lua` 用同一份源文件比较实际加载的 开发基线 和后续布局候选。入口为 `probe[, library]`；省略第二参数时读取实际 `LycheeUI`。第二参数仅用于显式绑定私有候选库，不改写已安装的全局库。候选只有声明 `library.layoutModes.flex == true` 时才额外运行 `C.Row/Column(..., {mode='flex'})`。旧路径始终运行，开发基线 不会把忽略 `mode` 参数误报为支持 flex。

## 场景与边界

私有 Context、离屏 host 和 driver 只在首次创建阶段建立。12 个 Frame 与 12 个 FontString 共 24 个物理子项供全部场景复用。Row、Column 分别运行固定尺寸、内容文本、720／960 宽度变化和稳定重复布局。固定尺寸场景每次用相同描述项调用 `SetItems` 后布局，用来覆盖显式失效路径；稳定场景直接重复布局。每个序列为 300 次，每个回调至多 20 次布局；首次创建阶段至多 16 次预热布局。异步期限为 30 秒，脚本也在回调入口检查 29 秒工作期限。

首次创建包含全部场景各一次预热，让库的私有文字测量对象在计数高水位前建立。之后检查私有树中的对象总数不再增长。开发基线 为 host、driver、24 个子项共 26 个对象；候选可另有首次预热建立的私有测量 FontString。脚本不替换 `CreateFrame`、Blizzard 对象或全局 API，不安装 hook。原生对象清理方式是解除脚本、释放布局所有权、停止 Context 工作并隐藏私有父项；报告不声称原生对象已销毁或内存已回收。

每个场景先运行未插桩的计时序列，再运行单独的方法计数序列。计时保留 300 个有界样本，输出 p50、p95、最大值、总值和样本数。单次计时范围包含该场景规定的输入变化和布局调用。最长同步段另记首次创建或整个 driver 回调的最大耗时，其中含校验与观察工作；客户端帧间隔来自 driver 的 `OnUpdate elapsed`，单独汇总，不能相加或互相替代。时钟为 `debugprofilestop`，分辨率由客户端决定，脚本不校准。

计数只临时替换私有树对象实例上的宽高、锚点、文本内容与文字测量相关方法。输入 setter 包含在计数内，嵌套调用按实际进入各方法的次数统计，不把 Get／Set 等同于硬件交互。零次调用会明确输出为 0。完成、失败、取消或超时都会恢复实例原有字段与有效方法；迟到回调不能继续工作。候选最终几何按相同场景与旧路径对照。

几何对照按候选的物理像素吸附规则计算期望值。像素单位为 `768 / GetPhysicalScreenSize() 的屏幕高度 / host:GetEffectiveScale()`。对旧路径的左边界 `x` 和正向向下顶部 `top=-nativeY` 分别吸附起点，并将宽高终点 `x+width`、`top+height` 单独吸附；候选宽高期望值是吸附后的终点减吸附后的起点。报告记录屏幕尺寸、父级比例、像素单位及 host 绝对位置。比较容差按 `4 × 2^-23 × max(1, 实测值, 期望值, 相对起止边界, host 绝对坐标上的起止边界)` 计算，覆盖原生单精度读回及相减误差；容差随绝对坐标增长，仍远小于一个物理像素。正常完成的结构化报告保留各场景比较值。当前用于匹配 开发基线 基线的冻结探针在异常路径调用 `Log(table)`，原生传输只保留 `<unsupported>`；失败错误仍会保留，详细定位使用单独的有界字符串诊断探针，不能将缺失日志视为通过。

自然堆差值只读取 `collectgarbage('count')`，范围为客户端全 Lua 堆，包含观察器与其他 Lua 工作，受自然 GC 影响。它不是累计分配、保留量或私有 Context 的独占内存；脚本不强制 GC，也不停用 GC。

## 离线验证

在 LycheeGroup 目录运行：

```powershell
lua tests/test_live_layout_profile.lua
luac -p tests/live_layout_profile.lua
luac -p tests/test_live_layout_profile.lua
```

可传另一个库源码目录：`lua tests/test_live_layout_profile.lua ../LycheeUI`。离线测试只使用该目录的 `tests/stubs.lua` 与库源码，不联系游戏。几何夹具返回 1920×1080 和 1920×1024 两种物理屏幕尺寸；另一个 native-like 夹具在 host 有绝对位置时向首行高度读回注入小型单精度误差。夹具还注入超过一个物理像素的坐标偏差，检查像素单位计算、绝对位置精度界限、失败诊断和失败前日志。测试也覆盖完整与重复执行、可选库、显式 flex 能力、缺库、缺时钟、创建失败、取消、外部超时、内部期限、战斗中断、写入后失败、原生对象增长、清理与迟到回调。计时为假时钟，不能用来判定游戏内性能。测试中的显式能力夹具用于检查分支合同，实际候选的性能与原生行为仍由同份探针实机输出证明。

## 实机接入

源文件注册不执行游戏动作：

```powershell
lycheedev live probe put --name layout-profile --file tests/live_layout_profile.lua --format json
```

保留注册返回的不可变 PRB revision，用已有项目和 CON 执行；示例中的占位值必须替换为该会话的真实标识：

```powershell
lycheedev live execute --project <project-directory> --session <CON-id> --probe <PRB-revision> --request <stable-key> --budget-seconds 35 --policy observation --wait-seconds 120 --format json
```

运行前确认脱战，保留客户端 build、库语义版本／源码哈希及前后台帧率条件。比较时分别保存 开发基线 和候选的完整已验证报告；核对 `report.ok`、全部场景、计数作用域、对象高水位与 `cleanup`，再解释成本差异。报告中的失败轮次同样保留。脚本没有内置性能合格阈值，阈值由基线结果确定后在候选测量前固定。

## 不同 Context 的布局接管

`live_layout_handoff.lua` 是独立的补充探针，不改变上面的固定 CPU 场景。两个私有 Context 依次对同一批 24 个 Frame／FontString 执行相同 Row 布局，临时包装私有对象的宽高和锚点 setter，检查新所有者能够复用已经成功提交的原生请求／读回对。第二次排版要求四种 setter 均为零次；随后释放旧布局，核对新布局的实际尺寸和位置保持不变。失败日志保留四种调用次数；完成和失败都会恢复方法、释放布局并隐藏私有树。探针不主动 GC，不读取业务 UI 或修改存档，也不把这一小场景的耗时当作总 CPU 验收结果。

```powershell
lua tests/test_live_layout_handoff.lua ../LycheeUI
lycheedev live execute --project <project-directory> --session <CON-id> --file tests/live_layout_handoff.lua --request <stable-key> --budget-seconds 15 --policy observation --wait-seconds 30 --format json
```

离线夹具覆盖精确尺寸、单精度边缘读回、构造失败和重复清理。对照修复前的冻结库时可传第二个参数 `before`，此时夹具要求量化场景报告重复写入失败；这只证明能够复现问题，不表示旧库通过验收。两个修订的原生对照使用同字节探针。
