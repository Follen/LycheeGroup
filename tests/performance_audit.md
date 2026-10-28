# 性能审计回归

结果和成本约束由 [perfermance.md](../perfermance.md) 维护。这里说明本轮重复工作回归和原生共享库探针的执行方法；该轮开发基线的真实页面、自然内存与模拟满列表结果见 [实机复验记录](results/performance-live-2026-10-25.json)。

## 离线计数与行为

在产品根目录执行：

```powershell
lua tests/runner.lua business_performance
lua tests/runner.lua libspecialization_performance
lua tests/test_ui_refresh_cost.lua
lua tests/test_live_fixed_style_profile.lua
lua tests/test_live_find_refresh_cost.lua
lua tests/test_application_summary_performance.lua
lua tests/test_notes_count_performance.lua
lua tests/test_find_caption_performance.lua
lua tests/test_button_state_performance.lua
```

`business_performance` 覆盖收藏初始化的规模增长、精确数值去重与原对象选择，以及 40 人名单的同帧通知合并、即时读取、混合库广播和离页取消。数据来自替身，不代表游戏中的事件频率或耗时。

`libspecialization_performance` 统计密集请求生成天赋字符串的次数，并检查配置与专精变化、原生值未知或为空、公开读取失败、回调重入、发送节流和已有库版本优先级。只有内置 minor 28 成为共享提供者时使用本地缓存；其他同版或更新提供者仍按原选择规则运行。

`test_ui_refresh_cost.lua` 通过实际 Find、Create 和 Floating 控制器，分别统计隐藏排版、姓名高度及原生字体写入。覆盖双语、原位字段变化、标记身份、列宽、字体、成员顺序、备注、权限和清理；复用后的几何与清空缓存重新测量的结果比较。关闭的活动菜单在反复切换筛选、调整字号或字体时不重建，重新打开时取得最新目录、分数及完整布局；可见菜单随字体立即更新。真正未确认的单选、多选、难度及旧存档仍在取消、离页和关窗时恢复；固定控件规则在筛选布局处直接应用。

申请摘要回归直接加载 Results 与 Applications，验证隐藏同步、同帧更新、严格队长旗标与独立缓存，以及完整详情按需原位刷新。笔记数量回归通过真实 Records 变更和管理页通知统计全库遍历，覆盖类型变化、覆盖、重复合并、旧存档规范化及重新绑定。固定标题回归模拟非零字宽在显示帧改变，检查一次校正、稳定通知缓存及关闭取消。

在独立 LycheeUI 根目录执行 `lua tests/fixed_writes.lua`、`lua tests/list_clear.lua`、`lua tests/style_release.lua`、`lua tests/style_events.lua`、`lua tests/menu_font_writes.lua`、`lua tests/layout_release.lua` 和 `lua tests/layout_measure_records.lua`，检查固定样式重复应用、外部属性变化、状态与动效、清空变高列表后的业务键释放，以及重复绑定和原生输入失权后的订阅释放。事件测试单独模拟原生 HookScript 与 SetScript 的独立层，并覆盖相邻同控制器事件合并、交错绑定顺序、跨 Context、嵌入修订、重入与异常清理。菜单测试检查重复开关、实例字体、尺寸及路径取整、原生修改、失败后恢复和自然宽度。布局测试检查 Row／Column 的旧条目引用、重复释放、连续 SetItems＋Measure 的记录上限、空条目清理，以及原有锚点和新旧布局所有权。产品按钮测试通过真实 Find、Create 和 Notes 检查双语、鼠标状态、禁用、隐藏、换绑和任务清理。诊断 GC 只用于离线引用存活验证。

## 原生固定样式成本

`live_fixed_style_profile.lua` 新建私有 Context 和隐藏父级，不读取玩家名单或保存设置。输入固定为 300 行、400 像素视口、40 像素步长、18/24 字体与行盒，以及固定纹理和锚点。预热后先执行 120 次未插桩刷新，再执行相同 120 次带计数刷新，每帧最多 5 次；两阶段各记录 24 个批次的总耗时和最长批次。

计数包装只装在探针自己创建的 FontString 和 Texture 上；结束、取消或失败时还原方法、清空列表绑定、停止驱动与动效、隐藏父级。原生 UI 对象不能销毁，诊断对象保留至重载，因此此探针应放在产品自然内存采样之后。它测量私有列表调用，不能作为整帧耗时、四包内存峰值或真实页面验收。

可直接注册并执行该文件，检查当前已加载库。比较源库修订时，先生成隔离命名空间探针：

```powershell
./tests/Build-IsolatedLibraryProbe.ps1 -SourceRoot ../LycheeUI -OutputPath .lycheedev/library-profile.lua
luac -p .lycheedev/library-profile.lua
lua tests/test_live_fixed_style_profile.lua .lycheedev/library-profile.lua
lycheedev live probe put --name library-profile --file .lycheedev/library-profile.lua --format json
```

构建器按照该源库的 `embeds.xml` 包入运行源码，并输出相邻的 `.manifest.json`，记录每个文件的 SHA-256、组合来源哈希，以及页面与测量脚本哈希。注册返回的 PRB 修订标识完整探针源码哈希。运行时使用独立 `_G` 和私有库表，检查已加载 `LycheeUI` 的身份不变；不覆盖游戏插件目录或已加载库。比较两版时使用各自固定的源库快照、相同输入和客户端状态。LycheeDev 单份探针上限为 256 KiB，注册前核对生成文件大小。

通过 LycheeDev 已绑定的目标 CON 执行注册返回的 PRB 修订，使用 `observation`、30 秒预算和非战斗前提。探针自身异步上限为 12 秒；pending 时继续原 CON／request，不重放。完成后读取 `report.ok`、`reportState` 和 `cleanup`，保留原始结果及失败报告，任务结束断开连接。

报告中的 `baseline` 是未插桩的 120 次刷新成本，`instrumented` 是包含计数包装的成本；不将两者相减作为独占 CPU。`counts` 只包含被观察对象的原生 setter，`output` 用于比较字体、行盒、文字、纹理及锚点，`pool`／`poolAfter` 用于核对对象池增长。`cleanup.jobs=0` 只证明任务结束，不表示原生对象已回收。

## 原生固定标题校正

`live_find_caption_profile.lua` 在独立产品命名空间加载完整 Find 源码，只构造申请区的私有文字控件与 Row 布局。实际页面和业务入口不参与；校正回调的后续消费者缩小为该行布局。父级先隐藏构造，显示后置于屏幕外，中英文分别检查首次显示、100%→130% 字号及改用游戏字体。每个场景等待两个显示帧，再分十批执行 100 次稳定布局，记录两个标题的原生测宽次数、最终宽度、当前原生字宽及校正任务结束状态。

```powershell
./tests/Build-IsolatedLibraryProbe.ps1 -UseInstalledLibrary -ModulePath addon/LycheeGroup_UI/Find.lua -ProfilePath tests/live_find_caption_profile.lua -OutputPath .lycheedev/caption-profile.lua
luac -p .lycheedev/caption-profile.lua
lua tests/test_live_find_caption_profile.lua .lycheedev/caption-profile.lua
lycheedev live probe put --name caption-profile --file .lycheedev/caption-profile.lua --format json
```

`UseInstalledLibrary` 为私有 Context 复用当前加载库，避免把完整共享库和完整页面同时打包而超过探针上限。报告记录实际库修订，构建清单另记页面与探针哈希；前后对照保持同一已加载库。探针使用 25 秒异步上限和 35 秒执行预算，结束、失败或取消均还原私有测量方法、移除回调、停止动效并隐藏控件。此结果验证这些原生文字与布局的输出，不代替完整页面交互或四包内存验收。

## 原生菜单字体复用

`live_menu_font_profile.lua` 使用私有 Context、屏幕外父级和 14 个固定选项，分别检查默认字体的 130% 字号与游戏字体的 107% 字号。每个字体场景预热后先开关 100 次，再带计数开关 100 次，每帧 10 次；记录总耗时、最长批次、SetFont 与测宽次数、菜单尺寸及行池大小。计数只包装私有菜单的测量对象，不包装全局 API。

```powershell
./tests/Build-IsolatedLibraryProbe.ps1 -UseInstalledLibrary -ProfilePath tests/live_menu_font_profile.lua -OutputPath .lycheedev/menu-font-profile.lua
luac -p .lycheedev/menu-font-profile.lua
lua tests/test_live_menu_font_profile.lua .lycheedev/menu-font-profile.lua
lycheedev live probe put --name menu-font-profile --file .lycheedev/menu-font-profile.lua --format json
```

上述命令复验当前已加载库。比较源库快照时改用 `-SourceRoot`，注册前检查完整源码与探针合计不超过 256 KiB；报告中的库修订必须与目标相符。同一 CON 串行执行两版不可变 PRB，使用 `observation`、25 秒执行预算；探针异步上限为 15 秒。完成、取消、超时、战斗或回调异常均停止驱动、还原方法、关闭菜单并隐藏 Context。比较选项测宽次数、最终尺寸及池大小，不能仅以 setter 次数下降判定总耗时收益。完整结果及已撤回的通用候选文字测量试验见 [性能审计记录](results/performance-audit-2026-10-25.json)。

## 真实寻队页重复刷新

`live_find_refresh_cost.lua` 用于复现历史开发快照的真实 Find 刷新测量，脚本含固定快照检查，不直接用于 V1.0.0 验收。它使用已显示且搜索已结束的真实 Find 页面，要求正常动画、非战斗，选择器、筛选、菜单和提示关闭，无 Preview 或弹窗。先完成产品自然内存测量，再正常打开 Find 并等真实结果就绪。探针临时将会话字号按 100%→130%→100% 切换；每次变化先确认两个固定标题已重新测量，显示帧校正完成后再执行 100 次稳定布局，要求标题零重复测宽、隐藏活动选择器零刷新和零列表绑定。最后实际显示选择器一次，确认计数能观察到正常刷新。

```powershell
lua tests/test_live_find_refresh_cost.lua
lycheedev live execute --project . --session <CON-id> --file tests/live_find_refresh_cost.lua --request find-refresh-cost-01 --budget-seconds 35 --wait-seconds 45 --policy opaque --format json
```

普通关窗后等待退场完成，检查动画、输入占用、页面订阅、选择器成绩服务、申请时钟及列表绑定释放。成功、失败或取消均还原包装方法、原筛选表和偏好引用、所有配置存储、字号与原 Find 开窗状态；任务结束再正常关闭主窗。只包装两个产品 FontString 和产品自己的刷新入口，不改全局 API、CVar 或 GC 策略。报告中的局部计时包含计数包装，不能视为无插桩 CPU 对照。生命周期测试另注入旧版重复工作，检查断言确实能识别回归。


## 原生职责同步

`live_native_roles_profile.lua` 在私有原生 Context 内加载指定 Application 模块，构造三职责弹窗，正常动画、自然 GC。原生角色 API 在模块环境中替换为私有选择，真实全局 API、玩家设置和申请业务不变。稳定刷新与切换职责各执行 300 次计时，再各执行 300 次排版计数，每帧最多 10 次。共享控件及生产 LayoutApplication 参与测量，产品元素覆盖和职责图标材质不在此范围。自然堆读数是全客户端读数，不代表插件独占内存或保留量。

```powershell
./tests/Build-IsolatedLibraryProbe.ps1 -UseInstalledLibrary -ModulePath addon/LycheeGroup_UI/Application.lua -ProfilePath tests/live_native_roles_profile.lua -OutputPath .lycheedev/native-roles-profile.lua
luac -p .lycheedev/native-roles-profile.lua
lua tests/test_live_native_roles_profile.lua .lycheedev/native-roles-profile.lua
lycheedev live execute --project . --session <CON-id> --file .lycheedev/native-roles-profile.lua --request native-roles-profile-01 --budget-seconds 35 --wait-seconds 45 --policy observation --format json
```

生命周期脚本检查正常结束、取消、超时、回调错误、战斗入口和迟到回调。成功后确认 `report.ok`、零动画任务、驱动停止及工具清理完成。比较旧版时将 `ModulePath` 指向固定 Git 提交导出的源码，保持探针与已加载共享库不变；旧版稳定排版计数预期不同，不直接套用候选生命周期里的零排版断言。测量结果保留在 [2026-10-28 记录](results/native-roles-2026-10-28.json)。


`live_native_roles_smoke.lua` 用于已部署 1.2.8 的原生接入检查。前提是插件主窗及原生申请窗关闭、无其他模态窗口、非战斗；脚本加载 UI／Group 后，在透明但显示的主窗下打开职责设置，不搜索或提交队伍，不改职责或备注内容。结束归还原生输入父级和回调、关闭测试窗口；读取一次自然五包内存，观察器耗时单列。隐藏父窗不适合验证 OnHide 生命周期，不能用其清理失败判定正式流程缺陷。使用固定请求键、25 秒预算执行，保留 `report.ok` 及清理状态。
