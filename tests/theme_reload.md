# 主题重载与 main 等价验证

本说明对应未发布的 Theme／Configuration／Appearance API v2。产品合同见 [API.md](../API.md)，开发边界见 [Development.md](../Development.md)。当前结果、实机数据与预算结论写入 [perfermance.md](../perfermance.md)，本文维护执行方法。

## 离线入口

在产品仓库根目录使用 Lua 5.1 和 Node.js：

```powershell
lua tests/runner.lua
lua tests/run_layout_checks.lua
lua tests/test_live_theme_memory.lua
lua tests/test_live_refresh_memory.lua
lua tests/test_live_heroic_memory.lua
lua tests/test_live_list_memory.lua
lua tests/test_live_memory_scenarios.lua
lua tests/test_live_compare.lua
lua tests/test_live_ui_probes.lua
lua tests/ui_preview.lua
node tests/compare_main_ui.cjs
lua tests/measure_configuration.lua
lua tests/measure_creation.lua
```

产品 runner 包含 core、configuration、appearance、theme_reload、brand_motion 及原业务、输入、表格和界面测试。`test_brand_motion.lua` 按 1ms 步进将两种尺寸的品牌轨迹与独立二分参考对照，并检查取消、批量停止、改尺寸及首帧时长；通用任务的结束和清理合同由共享库测试维护。布局 runner 包含字号、成员尺寸、产品组件、页面布局、静态元素、迟建对象、实例复用、浮窗池和结果行读取。`test_result_row_details.lua` 通过实际 Results getter 与 Find／Tooltip 消费链验证团本列表按需摘要、非首位队长、进度未知与零值、完整悬停详情及五人头像。它们验证真实 Lua 控制器与替身对象，不证明游戏受保护调用或鼠标命中。

`test_theme_reload.lua` 重新创建会话并复用保存数据，覆盖导入后已有和迟建对象保持当前来源、重载后统一生效、幂等导入、账号／角色选择、旧混合包迁移、静态覆盖清除、无效定义回退与错误保留。真实初始化顺序包含主包 ADDON_LOADED、第三方导入、PLAYER_LOGIN 和浮窗创建；关窗再开不作为重载。

`test_element_refresh.lua` 现验证固定主题及导入待生效，保留字体／尺寸实时行为。`test_element_layout.lua`、`test_find_elements.lua` 和池测试在 fixture 第四个参数预载主题，保留静态 slot、状态、锚点、实例换键与列表几何。热主题事务、逐叶 diff 刷新次数、任意撤回和方法包装器断言已随取消的接口移除。原生输入所有权及归还快照仍保留验证。

测量脚本使用离线 Lua 堆和替身对象，读数不能换算为 WoW 四包字节。停止或强制 GC 的诊断测量单列，不用于自然峰值达标结论。

产品专项测量留在本目录，默认使用内置 LycheeUI：`measure_font_cost.lua` 检查字体切换成本，`measure_element_values.lua` 检查元素值读取，`measure_theme_context.lua` 检查新 Context 解析成本，`measure_static_allocations.lua` 分开首次建页与预热后的切页／字号成本。后者的 `stable`、`native` 模式减少 Lua 替身实现产生的额外开销，`native cow` 只在诊断虚拟机内比较静态规则共享方案，不修改运行文件。历史调查见 [static-allocation-2026-10-23.md](results/static-allocation-2026-10-23.md)。

以下入口补充分配来源与读取时机的离线诊断：

```powershell
lua tests/measure_ui_firstbuild.lua
lua tests/measure_ui_cycles.lua
lua tests/measure_ui_cycles.lua profile
lua tests/trace_find_row_reads.lua
```

`measure_ui_firstbuild.lua` 按页面、设置分区和隐藏分支统计首次构建的替身对象及 Lua 堆净变化。`measure_ui_cycles.lua` 在预热后进行 12 轮切页和字号往返，记录对象、字体、规则与布局数量；`pages`、`fonts` 分别只切页或只调整字号，`profile` 临时包装调用并报告排除子调用后的堆净变化。这两个脚本采用自然 GC，堆差可以为负，不能当作累计分配量。`trace_find_row_reads.lua` 用 105 条模拟团本记录追踪首入、可见字号变化、隐藏字号变化及重进页面的成员统计读取，输出调用路径、实际绑定数和可见数；它检查读取范围，不建立游戏性能结论。这些脚本只修改自身进程内的 fixture。

## 验证范围与通过条件

| 场景 | 必须保留的行为 |
| --- | --- |
| 已有与迟建对象 | 主窗、浮窗创建后导入并选择主题，当前颜色、字体、材质、尺寸和业务状态保持不变；随后创建的页面、菜单、Tooltip、弹窗、原生输入及新池行仍使用本次启动主题。 |
| 重载与存储 | 保存并重载后，所有对象使用同一新主题；再次导入相同 ID／revision／内容幂等。账号／角色选择、显式默认、升级、移除和覆盖清除按 API 的优先级确定下次启动来源。验证结束恢复原选择、主题存储及实时偏好并再次重载核对。 |
| 非法定义与旧数据 | 非法值、循环、未知字段、错误 slot／引用／实例键整批拒绝，不部分改存档。既有最终组合无效时本次回退默认并保留原数据和错误；旧偏好迁移、作者插件缺席及重复登录不丢业务数据、不复活已清除覆盖。已取消视觉入口保持不存在，Configuration 拒绝视觉字段。 |
| 实时交互 | 待生效主题期间，窗口拖动、尺寸、列宽、排序、主窗／浮窗缩放和字体往返即时响应；表头与行边界一致，比例不累计，完整数据可达。当前原生输入和迟建文字同步字体偏好。 |
| 状态、复用与所有权 | 固定规则的 hover／pressed／focus／selected／checked／disabled／展开状态正常进入和退出；池行换业务键不残留前一项外观或事件；原生输入失去所有权后停止写入，归还恢复外部状态。预热后相同场景不持续增加池、绑定或原生对象。 |
| 业务与默认 UI | 按固定 main 重新捕获中英文对应场景。搜索、招募、申请者、申请弹窗和 Floating 接入保留业务规则；主题操作不额外触发搜索、发布、取消或邀请。 |

控件树和脚本调用之外，客户端另核对真实鼠标拖动、焦点、滚动命中及主要窗口截图。Button:Click 或直接触发脚本只能记录为控制器验证；真实业务动作与只读观察分别记录。

自然运行采样分别覆盖登录与四页首开、真实搜索与详情、正常动画、12 轮切页与字号往返、主题导入与重载、新建招募与申请者变化、浮窗展开与关闭，以及关窗仍保留活动业务的场景。没有申请者的空招募不能记为申请者验证；已有业务不得为测试前提而取消。每轮记录实际规模、各包同一时刻字节数、观察器成本、恢复检查及清理结果，预算只引用 [perfermance.md](../perfermance.md)。

## 默认界面对照

固定源为 `main` 提交 `5ce215182c15b59e44c573db9a1a6488536bb8bd`。`tests/results/main-ui-5ce2151.json` 保存 41 个场景的可见投影数量、摘要、源文件及测试替身哈希。candidate 的控件 ID、不可见备用对象数量不参与匹配；可见文字、字体、颜色、素材、位置、尺寸及裁切标记参与匹配。数值和 CSS 只归一到 1e-6，字面文本保持原样；素材搬迁路径仅在逐项校验字节相同后归一。

比较使用同一 `ui_stubs.lua` 与同一 HTML 预览算法。旧 main 自带替身对零尺寸返回至少 1，新替身返回实际 0；两者混用会产生虚假的浮窗圆角与最小滑条差异。替身补充 `CanWordWrap` 读取后，已再次捕获固定 main，并确认 41 个原有投影全部不变，只更新替身来源摘要。首轮异环境摘要保留为 `main-ui-5ce2151-legacy-fixture.json`，不用于当前等价判定。

从一个干净且停在固定提交的 main checkout 重新生成原始对照：

```powershell
node tests/capture_main_ui.cjs D:/Code/wow/addons/LycheeGroup
```

捕获脚本验证 HEAD 和工作区，仅读取 main 产品代码；测试替身映射到当前公共替身。它只适配旧预览驱动的三个控件名，并将数值 frame level 与笔记行同名文字字段分开。输出位于当前工作区 `.lycheedev/equivalence/`，包括原始控件树和来源元数据，已有文件拒绝覆盖。main checkout 不会改变。

基线建立与 candidate 检查分开；`--capture-main` 需要上述来源元数据，并拒绝覆盖已有正式摘要。日常验证只运行无该参数的 compare 命令。修改替身或渲染算法后先审查原因，再用同一环境重新捕获固定 main；不能用 candidate 输出替代 main 使对照通过。

预览用样例文本和近似字体度量，游戏素材中的部分图像仅显示占位。该对照是默认几何与属性证据；原生字体、实际截图、动画轨迹、鼠标拖拽、焦点和点击仍由客户端场景验证。

## 实机与清理

自然连续场景使用 `live_theme_memory.lua`。它要求 API v2 已加载、非战斗、没有 Preview 或活动模态窗口；有招募时观察真实招募与申请者，没有招募时等待实际非空搜索结果。最多等待 12 次初始搜索检查，随后遍历 8 个设置分区及 12 轮四页／字号切换，基本操作间隔 0.75 秒。每轮重进寻队再检查搜索完成、结果代次及可见行填充，未完成时以 0.5 秒间隔最多等 12 次；失败明确记为未覆盖，不以空列表成本算通过。异步上限 120 秒。使用原生 Button:Click 调用入口，不代表硬件点击。日志记录操作边界和等待样本、观察器刷新成本、同一时刻四包字节数、每轮实际结果规模和 `budgetPassed`，`report.ok` 不能代替预算字段。

在已连接的同一项目执行一次固定请求，并按 CLI 返回的原操作继续：

```powershell
lycheedev live execute --project . --session <CON-id> --file tests/live_theme_memory.lua --request theme-cold-natural-01 --budget-seconds 120 --wait-seconds 45 --policy opaque --format json
```

探针会暂时修改会话字号、动效偏好和页面状态，因此使用 `opaque` 策略，未完成时沿用原请求恢复。结束、报错、取消时恢复原值、原页面、各页显隐和导航状态，取消自有 timer；浮窗可见状态在主窗还原后恢复，避免被主窗关闭再次收起。账号／角色存储及已有招募身份必须保持不变。`test_live_theme_memory.lua` 使用真实产品 fixture 检查完成、取消、观察器报错、首次开页后局部 UI 引用尚未赋值时的失败与迟到回调，假计数不用于内存结论。`mainBuiltAtStart` 区分本轮是否覆盖主窗首次创建；已经打开的主窗不能记作冷路径。

寻队页会在正常进入时保存角色筛选。探针在首次进入前隔离 `Group.prefs.find`，结束、取消或失败后恢复原引用和原运行态筛选，重置页面读取标记；恢复 Core Configuration 三层不代替这项检查。生命周期测试使用真实 Find／Search 控制器，分别检查角色筛选内容、原引用和运行态恢复。

沿用 [live_memory.md](live_memory.md) 的 LycheeDev 连接、返回验证和清理方法。主题改造的自然场景必须计入登录、首开、四页、正常动画、字号与缩放往返、浮窗、原生输入，以及实际存在的搜索、招募和申请者；已有玩家业务不为测试前提而取消。

Theme 的 pending 测试先保存账号／角色主题与偏好，对导入、迟建对象、字号隔离及重载分别采样；完成后通过明确恢复数据和重载还原。保留固定请求、实际客户端与角色身份、每包同一时刻的字节数、采样规模、业务结果和 cleanup。四包预算按性能文档执行，不通过强制 GC、清空存档、删结果、缩小池容量或关闭正常动画达标。
