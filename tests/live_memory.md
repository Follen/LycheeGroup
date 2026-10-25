# 游戏内内存探针

当前 Theme API v2 使用 [主题重载验证](theme_reload.md) 和 [live_theme_memory.lua](live_theme_memory.lua)。该探针全程采用自然 GC，保留现有招募、申请者和玩家存档；四包同一时刻合计的采样峰值与预算单列。下面的历史探针各自保留其前提和 GC 口径，含主动回收的旧结果不能替代本轮自然峰值验收。

`live_list_memory.lua` 在冻结行池与原生对象数量前，逐行遍历整行和半行偏移，使各复用行的文字、图标及部分可见行完成预热；报告同时保留预热前后的行池数量。初次多出一个部分可见行属于预热分配，预热后继续增长仍判失败。离线生命周期用例覆盖正常复用与后续扩容的失败检测。

`live_relations_memory.lua` 观察已经打开的真实招募页，要求当前 Relations 已启用且加载按来源刷新的修复。启动时通过公开读取主动初始化一次身份快照，报告 `primedSnapshot` 与 `initialVersion`；随后的 110 秒不再主动读取身份，每 5 秒刷新一次四包内存，共 23 个样本。同时记录真实好友／公会事件、关系通知、身份内容版本变化，以及页面、招募状态、队伍、公会和申请批次数量；新版本的内容版本不再代表读取或重建次数。探针不包装业务方法、不提交组队动作、不主动 GC。只有全程仍在招募页、至少收到 10 次公会或战网信息更新、采样峰值不超过性能文档预算时才报告通过；没有申请者时仍可检查社交事件，按实际记录的规模解释结果。完成、失败或取消均解除临时事件与 Group 订阅并取消采样 timer；`lua tests/test_live_relations_memory.lua` 覆盖单次初始化、通知计数与退订、超预算、缺少更新、离页、取消、观察器异常、重复执行和迟到回调。自然读数与带插桩的分配诊断分别记录。

```powershell
lycheedev live execute --project D:\Code\wow\addons\LycheeGroup --session <CON-id> --file tests/live_relations_memory.lua --request relations-memory-01 --budget-seconds 120 --wait-seconds 30 --policy observation --format json
```

若返回未完成，沿原 `<CON-id>` 执行 `live resume` 读取同一次观察，不换 request 重跑。实测结果归入 [性能文档](../perfermance.md#1221-2026-10-25-大公会招募页内存增长修复)。

离线探针生命周期入口为 `lua tests/test_live_theme_memory.lua`、`lua tests/test_live_refresh_memory.lua`、`lua tests/test_live_heroic_memory.lua`、`lua tests/test_live_compare.lua`、`lua tests/test_live_list_memory.lua`、`lua tests/test_live_memory_scenarios.lua` 和 `lua tests/test_live_ui_probes.lua`。刷新探针使用真实 Find 页面和 Search 请求控制器，检查六次请求、刷新与重开、筛选记忆关闭、未发出请求、空结果、错误代次、取消、观察器报错及清理后的迟到回调。英雄探针覆盖首次活动选择、六个请求代次、八秒请求间隔、首批结果后行池复用，以及完成、取消和失败后的恢复；对比探针覆盖 Lychee 分支的一次预热与六次正式搜索、当前 `activityIDs` 数组合同及清理。列表探针检查单次搜索、完整负载、原非默认筛选、准备失败和取消后的恢复；组合探针检查筛选记忆关闭时的团本分类确认、空态池首次扩容、完整列表滚动、申请者及编解码阶段，以及各阶段取消或失败后的清理。页面和动画探针覆盖完成、取消与回调失败后的路由、包装方法、帧率设置和资源恢复。各探针恢复原页面、各页显隐和导航选中状态，并保留真实的 `settingsReturnPage`；离线验证在清理后重新打开原页，逐页核对可见内容，再通过实际设置按钮核对原来源页。结果、内存计数和对比中的集合石环境使用替身，不计入游戏内性能结论。

准备阶段同样纳入恢复验证：主题、英雄列表、列表及对比探针覆盖开页后尚未保存局部 UI 引用便抛错的路径；对比探针另覆盖隔离角色筛选后、开页前失败。Presence 与动效计时探针在预热前登记清理，覆盖首次开页失败和正常完成，恢复预热前的页面状态。失败后检查角色筛选原引用与运行态、窗口与原生输入、导航、包装方法和帧率，并检查迟到任务不继续执行。

2026-10-18 的 LycheeUI 1.1.14 八轮审计后，复用下面的 Presence 与动效计时探针；[新结果](results/ui-audit-2026-10-18.json)单独保存，未覆盖 1.1.12／1.1.13 历史报告。离线调用数、原生轨迹和客户端整体帧时分别解释，完整范围见[本轮记录](results/performance-history-2026-10-23.md#2026-10-18-四轮动画与四轮全仓审计)。

`live_ui_motion_profile.lua` 对设置页执行“正常四轮 → 固定坐标四轮 → 正常四轮”的有界开关对照，用于区分坐标更新与其他帧耗时。UI 未构建时先预热设置页，要求主窗关闭、无战斗／Preview／弹窗且启用默认动画和原生 AddOn profiler。初始两秒包含探针启动与临时 FPS 切换，不能当作干净后台基线。它记录 `LastTime` 应用／插件指标、Motion Tick 计时及观察器成本；临时包装自有方法可能使分包 CPU 归属转移到探针槽，单包零值不得解释为零成本。探针在完成、失败或取消时恢复原方法、FPS、隐藏页面并移除观察器。只在诊断对照中固定坐标，不修改正式动画或业务设置；不做主动 GC。结果与剩余长帧边界见[动画计算与锚点更新优化](results/performance-history-2026-10-23.md#2026-10-18-动画计算与锚点更新优化)。

```powershell
lycheedev live execute --project D:\Code\wow\addons\LycheeGroup --session <CON-id> --file tests/live_ui_motion_profile.lua --request lycheegroup-ui-motion-01 --budget-seconds 32 --wait-seconds 35 --policy observation --format json
```

`live_ui_presence.lua` 针对主窗消失瞬间记录原生透明度、相位、纵向偏移和逐帧间隔，并检查 Logo 尚在变形时关闭是否跳回原形。要求主窗关闭、无战斗／Preview／弹窗且保留默认动画；UI 未加载时先创建设置页并立即关闭作为准备，不将这一步当作首开性能测量。正式过程打开设置页、等待品牌动作结束、正常关闭，再打开并在约 210ms 时关闭一次。它临时将前后台 FPS CVar 设为 60，但以实测 `dtMs` 为准，不假定客户端一定按该帧率运行；完成、失败或取消后恢复原值和原隐藏页面，移除观察器。下面的 `<CON-id>` 使用已建立的连接，每次独立测量指定新的 request。轨迹数据证明状态变化，不能代替目视体验或整场景 CPU 验收。[本轮轨迹与失败记录](results/ui-presence-2026-10-18.json)对应[主窗淡出收尾修正](results/performance-history-2026-10-23.md#2026-10-18-主窗淡出收尾修正)。

当前脚本在快速关闭后另加一轮中途反向：完全打开，关闭约 150ms 后立即重开，比较位置、透明度和 Logo 形状，再验证旧退场回调不会关闭新窗口。新增场景的 [1.1.13 结果](results/ui-motion-2026-10-18.json)单独保存，不改写此前 1.1.12 的历史报告。

```powershell
lycheedev live execute --project D:\Code\wow\addons\LycheeGroup --session <CON-id> --file tests/live_ui_presence.lua --request lycheegroup-ui-presence-01 --budget-seconds 14 --wait-seconds 30 --policy observation --format json
```

`live_ui_transitions.lua` 单独测量真实寻队、设置页的进出场帧时，不刷新内存计数。先正常打开两个页面使其完成加载，再关闭主窗；保留默认动画，退出战斗、Preview 和弹窗。探针交替打开两个页面各三次，调用正常搜索和关闭入口，不提交申请或招募。它用一个有界 `OnUpdate` 观察帧间隔，记录同步开关调用、进场、停留、退场和静置的中位数、P95 与最大值；帧时包含整个客户端工作，不能全部归给荔枝组队。运行期间把前后台帧率上限临时设为 120，结束、失败或取消时恢复原值、原隐藏页面并移除观察器；不修改 profiling 或主动 GC。关窗后的 `jobsAfter=0` 仅覆盖共享动画调度器。首次加载成本需要单独记录，不能用这个预热探针代替。结果见[真实页面进出场测量](results/performance-history-2026-10-23.md#2026-10-18-真实页面进出场测量)。

```powershell
lycheedev live execute --project D:\Code\wow\addons\LycheeGroup --session <CON-id> --file tests/live_ui_transitions.lua --request lycheegroup-ui-transitions-01 --budget-seconds 22 --wait-seconds 30 --policy observation --format json
```

`live_compare.lua` 用于荔枝组队与集合石的同场景 CPU／内存比较。只修改开头的 `targetName`，分别使用 `lychee` 和 `meetingstone`；另一轮使用独立文件和 request，避免改动仍待完成的请求源码。运行前两边主窗关闭、原生搜索框为空、没有组队／申请／招募／战斗／大秘境。先记录 `scriptProfile` 原值，启用计量并通过 LycheeDev 重载；两轮结束后恢复原值并再次重载。探针每轮至少预热 10 秒、正式采样 60 秒，采用 95 秒执行预算，记录 6 次真实搜索、120 次滚动、1 秒间隔内存样本以及 CPU 起止差值。它临时统一帧率上限，结束、失败或取消时恢复窗口、相关筛选、历史和帧率设置；没有主动 GC。结果和计量边界见[同场景比较](results/performance-history-2026-10-23.md#2026-10-18-与集合石的同场景比较)。

当前安装包含四个产品包，LycheeUI 已内置在 `LycheeGroup`，其成本计入主包。`live_memory_scenarios.lua` 使用当前四包口径，最新组合结果见[性能文档第 12 节](../perfermance.md#12-当前性能验证与历史结果)。列表、刷新、英雄列表和页面开关探针源码也按四个产品包采样；它们在 2026-10-17 保存的结果仍按当时独立 LycheeUI 的五包口径解释，历史结果文件不覆盖或换算。

角色偏好接入后，列表、刷新、英雄列表、组合及对比探针从 `Group.prefs.find` 保存和恢复当前角色筛选；列表探针在 Group 就绪后、首次开页前保存原运行态筛选，不将预热后的测试筛选当成恢复来源。需要临时调整筛选记忆时通过配置 API 写入 `session` 用户层。清理恢复先前的会话覆盖或移除本轮覆盖，保留原有效值与来源；报告读取分层后的有效设置，不直接读取旧存档镜像。筛选记录恢复原引用，不写旧账号迁移种子或玩家笔记。

自然主题、普通页面内存和页面进出场探针也会进入寻队页，当前均在进入前隔离角色筛选，并在完成、取消或失败后恢复原引用与运行态筛选。Presence 与动效计时探针只进入设置页；离线生命周期测试同时检查这两项保持原值。此前仅记录 Core Configuration 三层不变的结果，不能作为 Group 筛选恢复证据。

高频列表刷新使用 `live_list_memory.lua`。关闭主窗并退出 Preview，确保没有在途搜索、申请、招募、战斗、进行中的大秘境或未保存的原生招募草稿。它先正常打开设置、笔记、创建及寻队页，加载四个产品包，确认分类的全部活动后再进行一次真实赛季地下城搜索；进入负载前要求真实结果非空、列表绑定数量一致、首行有记录且空态隐藏。随后经产品原生事件分发入口交替触发整表更新、八条真实记录更新、本地排序筛选及滚动，共 1,280 次操作；每批 16 次，每 4 次刷新原生内存计数，预分配 336 个样本。前 1,024 次没有主动 GC，随后在边界测保留量并完成 256 次重复操作。正常动画保留，不提交申请或发布招募，完成后恢复原筛选、导航和偏好。原 2026-10-17 结果是五包测量；以当前源码复测时按四个产品包报告。

```powershell
lycheedev live execute --project D:\Code\wow\addons\LycheeGroup --session <CON-id> --file tests/live_list_memory.lua --request lycheegroup-list-memory-01 --budget-seconds 120 --wait-seconds 25 --policy opaque --format json
```

`live_list_memory.lua` 的 `operations` 只测每个操作的同步调用区间。整表及单项事件先进入队列，真正读取原生数据的 `CommitResults`／`OnResultUpdated` 在下一帧执行，不能把入队的近零堆差解释为刷新无分配，也不能把事件数乘以队伍数作为实际原生读取次数。同一批 16 个操作中的四个整表事件会合并；1.1.0 归因轮实际测得自然阶段 64 次、重复阶段 16 次整表执行。`SetFilters`、`RefreshResults`、`GetDetails` 的包含性读数可能重叠，不能相加。

当前同步实现的一次 `CommitResults` 调用完成整表读取与通知。历史分批候选则把一次完整读取分散到多次调用，比较旧数据时应以该方法内的最终 results 通知为完整扫描边界。自然阶段和重复阶段结束后，脚本等待 `Results.updatePending` 清空才采样终值或执行诊断 GC，确保已排队工作纳入结果。准备阶段要求没有原生活动申请或招募；该条件失败时先保存失败报告，待场景实际恢复后再开始一轮，不清除玩家业务来满足测试前提。

已撤回分批候选的混合、仅整表和只读字段核对保存在[历史候选复测记录](results/memory-fix-1.1.0-2026-10-19.json)，不能用于当前同步代码验收。混合场景使用 `live_list_memory.lua`；仅整表场景的 `bulkProbeSource` 单列每次完整扫描和通知到提交的延迟。该候选的 `businessProbeSource` 只读已存在、队列已清空的真实列表，核对全部有效原生 ID、12 个基础字段、活动 ID 和年龄；年龄按其服务器时钟字段对齐并容许一秒边界。它不触发搜索、筛选或 GC，只释放自己的 ticker。业务结果列表为空的准备失败单独保留，不能计为字段核对通过；筛选排序等价性另由离线独立参考结果覆盖。

无节流同步候选的[历史复测记录](results/memory-dirty-1.1.0-2026-10-19.json)保留两轮内存预算失败及混合轮对象数量检查失败：预热后首次创建的交互详情子树增加了对象，不能把该轮写成对象稳定。仅整表探针包装同步方法，每次调用对应一次完整提交；`GetTime` 在帧内不前进，记录中的零时间差不是零成本，同步耗时以 `debugprofilestop` 统计为准。该轮没有重新执行分批候选的逐字段只读比较。

当前 200 毫秒节流、同步完整提交的[复测记录](results/memory-throttle-1.1.0-2026-10-20.json)复用以上两种负载。仅整表轮同时记录通知数与实际完整读取数，验证合并效果；混合轮每批实际间隔已超过窗口，不能把这类负载描述为可以持续合并。保留混合轮预算失败，详细数字和观察边界见[性能结论](results/performance-history-2026-10-23.md#2026-10-20200-毫秒整表节流与同步提交当前未发布)。业务时序、完整批次、筛选排序和详情行为由对应离线回归覆盖。

全局 `UpdateAddOnMemoryUsage` 也属于探针成本。本次原场景的 330 个样本累计耗时 26.014 秒，整个场景为 35.907 秒；不能把这段时间计为产品 CPU 或据此推算正常帧时。临时归因探针只包装自有方法，记录实际执行次数、缓存命中和包含性堆差，结束后恢复；删去筛选、滚动的最小复现及不注入操作的静置对照见[本次原始结果](results/memory-tail-1.1.0-2026-10-19.json)和[性能结论](results/performance-history-2026-10-23.md#2026-10-19-110-结果刷新峰值归因)。自然阶段的负堆差可能来自客户端 GC，不代表负分配；较低的另一次峰值也不自动代表优化。

`live_refresh_memory.lua` 补查真实搜索请求与重开路径：在上述四包预热压测结束后运行，要求寻队页和行池已构建、没有进行中或待重试的搜索。六轮正常搜索动作交替使用重开和刷新，主动请求间隔至少 8 秒；保留服务器失败／节流行为，整个过程不主动 GC。重开未自动搜索时，先确认本分类的全部活动再搜索；已自动发出请求时不重复提交，不修改筛选记忆开关。每轮必须产生新请求代次，并取得对应代次的非空真实结果及已绑定的可见列表；没有发出请求、空结果或代次不符均明确失败。报告记录每轮代次、真实队伍与绑定数量、页面和行池复用、内存峰值及关闭后结果刷新驱动释放。结束、报错和取消均恢复原筛选、角色偏好引用和隐藏页面，撤销自有 timer 与事件。不得将高频本地事件数写成向服务器发出的搜索次数。已有 2026-10-17 测量仍按当时五包口径保留。

`live_heroic_memory.lua` 测“烈毒之渊（英雄）”的真实列表。它从当前目录查找活动，通过分类入口创建活动选择器，再经活动行的正常选择处理直接发出首次目标搜索，共完成六次真实搜索，并在请求间隔中用列表滚轮处理函数往返滚动。每次核对单项活动数组、新请求代次和对应代次的非空结果；首次真实结果填充后记录行池基线，随后检查复用。随后切换真实团本／成员提示框，以及本地筛选排序。初始加载、四个产品包计数和动画均计入；周期采样间隔为 0.5 秒，并采集操作边界。全程自然 GC，关闭后的诊断性 GC 单独报告。正常运行约 77 秒，使用 120 秒执行预算；调用控制器不等于验证物理鼠标命中。历史结果仍按 2026-10-17 的五包口径解释。

`live_memory_scenarios.lua` 在四个产品包和四页已加载、主窗关闭后补测页面／弹窗生命周期、100 支各 40 人的模拟团本、50 个五人模拟申请批次，以及 1,000 条记录连续三轮编解码。Preview 数据独立，笔记编解码不调用合并保存；场景结束检查存档数量、原生草稿、页面／行池复用及活动清理。预热使用正常页面与本地 Preview，活动选择器仍按首次展开创建；全功能保留量需要另计首次展开后的成本。原生创建框已有文字时跳过真实创建页的反复开关，保留其内容。模拟数据生成的客户端堆净变化单列，不能当作实际数据获取成本或加到四包计数后声称完整归因。周期样本与同步编解码返回边界不能证明函数内部未采到的瞬时峰值。

2026-10-19 补齐当时选择流程后的覆盖检查：生成模拟团本后，经 `Enter → CommitChoice → DoSearch` 确认并绑定 100 条结果，验证空态隐藏与首行身份；按实际绑定列表计算滚动范围，并在后续 tick 记录实际偏移和首行变化。未发生滚动会使探针失败。修正前的本轮首测虽有 100 条 provider 数据，但列表仍为空，其采样不能证明满列表滚动成本；保留该报告并标注覆盖缺口，不改写历史结果。

当前组合探针在 `Enter` 后通过 `SelectCategory("seasonRaid")` 明确选择分类，再确认并搜索，筛选记忆关闭时同样覆盖团本。寻队和申请者池各先完成 40 次滚动的完整往返，第 41 次请求前固定复用基线；随后至少再观察一遍完整往返，才进入下一场景。每段至少 20 秒且不少于 81 次操作，整个探针仍受原有期限限制。报告分别保留进入前、首次绑定和首次完整往返后的容量，所有初次扩容继续计入自然采样。该口径纳入滚动后首尾部分可见行所需的缓冲，后续增长仍会失败；离线故障注入验证预热后新增池容量不能被当作通过。

`live_transfer_memory.lua` 是编解码超标的精简复现：相同 1,000 条记录、每条 198 字节备注加序号，连续三轮；逐轮检查数量、名称和备注往返一致，在各函数返回后刷新四个产品包计数，内置 LycheeUI 计入 `LycheeGroup`，最后才执行诊断性 GC。使用 25 秒执行预算。工作放在受控 ticker 回调中；早期独立 LycheeUI 版本曾在槽加载期间同步运行相同代码，计数始终不变，因此那组读数不用于性能结论。当前有效的前后对比使用相同异步执行方式。

这三个补充探针均不进入产品 TOC。用上面的 `live execute --file` 命令替换文件名，并为新实验选择新的 request；原请求仍待完成时继续使用 `live resume`。原始结果、失败轮次和优化结论统一见[性能文档](results/performance-history-2026-10-23.md)。

以下说明适用于页面开关探针，不能用其空页面读数代替列表刷新结果。

`live_memory.lua` 供当前 LycheeDev Mailbox probe API 执行，不加入插件 TOC。安装 LycheeGroup 四个产品包并进入世界，关闭荔枝组队 / Lychee LFG，退出战斗，确保没有申请、招募、进行中的大秘境和未保存的原生招募文本。LycheeUI 已内置在主包，不再作为独立安装包计数。测试期间不要操作组队窗口。已有笔记和提醒继续保留。

已保留的 [2026-10-17 v4.4 五包结果](results/memory-2026-10-17-v44.json)是历史数据：当时 LycheeUI 独立安装，默认浮窗启用，冷起为 Core + LycheeUI，Group、Notes、UI 尚未加载。[2026-10-16 v3 四包结果](results/memory-2026-10-16-v3.json)同样按当时口径保留。两组历史结果早于自动搜索接通和 Preview，只覆盖空业务页面 Lua 计数与已知所有者清理，不代表当前满负载、CPU 或完整引擎资源验收。当前探针源码报告四个产品包，LycheeUI 成本计入 `LycheeGroup`。

在已有、空闲的连接上运行；将 `<CON-id>` 换成当前连接 ID：

```powershell
lycheedev live execute --project D:\Code\wow\addons\LycheeGroup --session <CON-id> --file tests/live_memory.lua --request lycheegroup-memory-01 --budget-seconds 115 --wait-seconds 60 --policy opaque --format json
```

`--wait-seconds` 返回 pending 时继续原请求，不要另建请求重跑。测试动作与静置约 82 秒，另加内存计数和 GC 用时，探针硬期限 110 秒。需要复测时，先确认上一请求结果及 cleanup 已完成。要观察当前四个产品包在业务页面未打开时的加载路径，应在新的 Lua 会话中、使用页面之前运行；不要清空存档制造冷态。

继续等待与结束连接分别使用以下命令；保留同一个连接 ID：

```powershell
lycheedev live resume <CON-id> --project D:\Code\wow\addons\LycheeGroup --wait-seconds 60 --format json
lycheedev live disconnect <CON-id> --project D:\Code\wow\addons\LycheeGroup --wait-seconds 30 --format json
```

流程为：起始自然／GC 双采样 → settings、notes、find、create 各首次观察的打开及关闭 → 预热后五轮自然开关 → 五轮受控 GC 开关 → 最终关闭采样与清理。每个开、关边界均等 1.9 秒，超过 420ms 退场与 1.386s Logo 动画之和。探针本身只操作页面入口，不提交申请、发布或邀请，不改 profiling、记录及动态效果设置。本次保留的 v4.4 结果在自动搜索接通前采集；当前寻队入口会自动发起真实搜索，后续重跑应记录实际返回规模，不沿用空页面结论。运行前应退出显式 Preview 模拟。每次 `after_gc` 只执行完整 GC，不改变 GC 的运行策略。

结果字段：

- `packages` 顺序为 `LycheeGroup`、`LycheeGroup_Group`、`LycheeGroup_Notes`、`LycheeGroup_UI`。每条 `samples` 的 `addonKB`、`loaded` 按同样顺序排列；`addonTotalKB` 为四个产品包之和，内置 LycheeUI 计入 `LycheeGroup`。每次计数前都会调用原生全局 `UpdateAddOnMemoryUsage()`。
- `summary` 比较 `warmed_closed_baseline` 与 `final_closed` 的 `after_gc` 样本，直接给出四个产品包各自增量、产品包总增量及客户端 Lua 堆增量，并保留两个样本的标签和下标。负增量也原样保留，不据此设置任意泄漏门槛。
- `mode=natural` 表示该次读数没有主动 GC；`after_gc` 表示显式完整 GC 后的保留量。初始、预热结束和阶段边界有受控 GC，因此自然阶段表示这些边界之后没有主动 GC，不能冒称全程未干预。`counterRefreshMs`、`gcMs` 单独记录观测操作时间。
- `luaHeapKB`、`luaHeapAfterRefreshKB` 是整个客户端 Lua 堆，包含其他插件、测试源码和预分配报告对象；不能把它们的增量归给荔枝组队。探针不报告进程内存、原生纹理内存、累计分配或没有采到的峰值，也不设置未经测量的达标门槛。
- `loadedAtStart`、`pageBuiltAtStart` 决定哪些首次打开实际是冷路径。`coreOnlyAtStart=true` 表示四个产品包中只有主包已加载；其内置 LycheeUI 成本仍计入主包。`businessPagesUnloadedAtStart=true` 表示 Group、Notes、LycheeGroup_UI 尚未加载。保持实际设置，不为冷态关闭默认功能；测试无法卸载已加载的包或撤回首次加载成本。
- `initialClosedOwners`、`closedOwnersBeforeCleanup`、`closedOwnersAfterCleanup` 记录初始、清理前后已知所有者：动画任务和驱动、Group 视图、搜索结果、申请、申请者及额外事件。只检查本产品已有对象，不扫描整个游戏 Frame，也不能证明所有未知 timer 都为零。启用且有记录时，笔记提醒是预期后台业务。
- `catalogUpdatesSubscribed` 单列 Group 加载后保留的原生活动目录事件；该事件用于失效缓存，没有定时器，不计入应随页面释放的 `extraGroupEvents`。旧报告没有此字段，保留原测量口径。
- `applicationCountdown` 记录寻队页按秒展示 ticker；`rosterTimer` 覆盖创建页的广播合并与串行检视 timer。两者均计入 `knownOwnersIdle`，不因展示任务移出动画驱动而漏报；旧报告保持原字段与范围。
- `checks` 单独给出清理前空闲状态、探针资源释放和原隐藏页面恢复结果。LycheeDev 的 `report.ok` 表示探针执行结果；判断残留还要查看这些字段。清理前结果保留，即使清理过程随后停止了测试产生的动画。

一个 ticker、两个包装回调和最多 32 个预分配样本组成全部测试驱动。完成、报错、取消或超时都会取消 ticker、撤销测试事件和脚本，并恢复原来的隐藏页面。四个产品包加载及正常页面创建留下的可复用对象如实保留；申请、招募和笔记提醒不被测试清理。若测试期间出现真实业务、战斗或切出世界，探针会停止，需先处理原请求的失败与清理结果。
