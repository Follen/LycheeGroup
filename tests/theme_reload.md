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

`lua tests/runner.lua group` 另覆盖明确取消前的状态核对：游戏状态已更新而本地仍是提交中时可正常取消，真实 pending、邀请、已结束和不存在的申请不误提交，重复操作不重复取消，其他申请及成员数据不被补读。回归同时走真实浮窗“取消全部申请”按钮和 Applications 服务；它证明旧状态误拦截的修复，不解释玩家现场最初提交没有反应的原因。

`test_element_refresh.lua` 现验证固定主题及导入待生效，保留字体／尺寸实时行为。`test_element_layout.lua`、`test_find_elements.lua` 和池测试在 fixture 第四个参数预载主题，保留静态 slot、状态、锚点、实例换键与列表几何。热主题事务、逐叶 diff 刷新次数、任意撤回和方法包装器断言已随取消的接口移除。原生输入所有权及归还快照仍保留验证。

测量脚本使用离线 Lua 堆和替身对象，读数不能换算为 WoW 四包字节。停止或强制 GC 的诊断测量单列，不用于自然峰值达标结论。

产品专项测量留在本目录，默认使用内置 LycheeUI：`measure_font_cost.lua` 检查字体切换成本，`measure_element_values.lua` 检查元素值读取，`measure_theme_context.lua` 检查新 Context 解析成本，`measure_static_allocations.lua` 分开首次建页与预热后的切页／字号成本。后者的 `stable`、`native` 模式减少 Lua 替身实现产生的额外开销，`native cow` 只在诊断虚拟机内比较静态规则共享方案，不修改运行文件。历史调查见 [static-allocation-2026-10-23.md](results/static-allocation-2026-10-23.md)。

2026-10-24 的界面调整另由 `test_find_filter_layout.lua` 和 `test_notes_layout.lua` 验证，均已加入布局 runner。前者覆盖中英文、70%–130% 公开字号与 160% 压力场景、最小窗口、同组快捷控件在主界面与弹窗间迁移、分类切换、完整文字、滚动裁切与命中恢复、值保留及对象复用；后者覆盖页头工具栏、两行记录、类型与日期留白、编辑区反馈避让和历史图标居中。浮窗主入口的打开、关闭和动画中反向归 `test_floating.lua`。产品 runner 的 `test_applicant_time.lua` 覆盖分数／实际用时切换、默认无提示、单行时间提示、数值排序、裸名刷新、池行迁移、申请和成员复用、离页清理、裁切和对象复用；原生用时读取、活动地图匹配、限时缓存及未知值在 `test_group.lua` 验证。客户端可用内置申请者预览检查文案与字体，模拟成绩不能记作真实申请者数据证据。

SEUI 适配由产品 runner 的 `test_seui.lua` 覆盖，可单独运行 `lua tests/runner.lua seui floating`。检查 SEUI 加载、浮窗显示与兼容开关的全部组合，宿主延迟创建、隐藏与恢复、骷髅定位、缩放、计数字体、主窗开关、原按钮保持及重复操作的对象复用；测试使用真实荔枝控制器与 SEUI 控件替身。游戏内仍需核对实际锚点、受保护状态、鼠标命中和悬停列表，不将替身结果计为实机通过。

寻队单行活动列由 `test_table_find.lua`、`test_ui.lua`、`test_font_layout.lua` 和 `test_find_pool.lua` 覆盖：12 条目录路由、活动列图标与表头起点、队长姓名后的关系／笔记标记、正文 19 号字及 58.88／44 基础行高、原生完整活动名、结果和申请的池行复用、旧列宽拆分及保存重载，以及团队职责／总人数原位替换且不重排列表。活动表头的三态、目录顺序、未知活动、目录失效与排序保存由 `test_table_find.lua` 验证；默认与各表头排序中的好友／公会优先结合 `test_group.lua` 验证。申请名额提示与行高由 `test_application_notice_layout.lua` 沿真实 Applications 状态通知验证：五项满额、取消／拒绝释放名额、绿色提示、关闭、样式重应用与字号变化；普通行保持基础高度，被拒绝行的提示完整，出现位置与最终布局一致。设置分类由 `test_settings_sections.lua` 检查八组内容、保存范围、切页清理、语言／主题重载、双语 70%／100%／130% 和最小窗口，已加入布局 runner。屏蔽页由 `test_blocked_layout.lua` 检查标题／数量／清空同行、表头与正文对齐、双语多字号、窄窗口及名单池复用；业务移除和清空继续由 `test_ui.lua` 覆盖。字体专项检查中英文 70%／100%／130%、未知评分、分钟／小时／天数、两位职责数、拒绝提示底行、主区左右边界及外侧滚动槽；离线布局不代替游戏中的文字裁切和图标呈现检查。


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

捕获脚本验证 HEAD 和工作区，仅读取 main 产品代码；测试替身映射到当前公共替身。它适配旧预览驱动的三个控件名，将数值 frame level 与笔记行同名文字字段分开，并将双方样例时钟固定在 2026-10-23，避免日期跨日造成无关差异。输出位于当前工作区 `.lycheedev/equivalence/`，包括原始控件树和来源元数据，已有文件拒绝覆盖；可用第二个参数指定新的输出文件。main checkout 不会改变。

基线建立与 candidate 检查分开；`--capture-main` 需要上述来源元数据，并拒绝覆盖已有正式摘要。日常验证只运行无该参数的 compare 命令。修改替身或渲染算法后先审查原因，再用同一环境重新捕获固定 main；不能用 candidate 输出替代 main 使对照通过。

2026-10-24 按用户要求重排笔记、筛选、历史图标、申请者时间列、收藏条目、寻队独立活动列及单行列表后，固定 main 仍是此前架构改造的历史参照。排序、设置分组及成员图标后续调整完成、默认主题更新之前，该轮 compare 以退出码 1 报告 25 个预期变化场景：寻求组队、钥石默认多选、队伍悬停、团本搜索描述列、收藏条件、收藏操作悬停、招募中收藏不可用、管理申请、申请者种族替换、申请者大秘境纪录、荔枝笔记、笔记列表悬停、历史记录悬停、团本成员布局、收藏与增益、职责筛选、筛选字体 130%、筛选字体 70%、设置、字体大小设置、设置字体 130%、主窗口 75%、主窗口 125%、行内修改快捷键、按键冲突；其余 16 个场景一致。这是该轮的历史结果。重新捕获固定 main 自身仍应为 41／41 一致。新布局按设计文档、上述专项测试及对应预览或客户端截图验证，各轮范围保留在验证记录中，不覆盖历史摘要。

同日按用户要求将当前角色界面设定保存为内置默认主题 revision 2，采集值见 [default-theme-2026-10-24.json](results/default-theme-2026-10-24.json)。窗口尺寸、侧栏状态、成员图标、悬浮窗缩放、列宽与排序的默认值已改变，前述 25／16 分类不再作为新版默认主题的差异名单；后续对照需分别解释这些已授权变化与其他差异。相关交互测试显式设置其所需的未排序、侧栏展开、圆形头像和列宽前提，继续验证排序切换、收放、图标状态及池复用；窗口断言按实际内容区计算，不固定旧窗口尺寸。`test_table_find.lua` 保留旧列宽拆分、其他权重与排序不变以及保存后重载的检查，新增内置活动列宽不能遮蔽旧存档中缺少活动列的事实。

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
