# LycheeGroup 配置与主题 API

本页维护 1.2.4 引入的 API v2，含 1.2.7 新增的默认偏好包扩展。验证方法见 [tests/theme_reload.md](tests/theme_reload.md)，当前结果见 [perfermance.md](perfermance.md)，开发约束见 [Development.md](Development.md)。插件发布版本为 1.2.7；浮窗接入继续使用独立的 `API.Floating` v1，见[架构文档](Architecture.md#92-浮窗公开接口)。

DataBroker 等独立状态展示可使用 `API.Floating:Subscribe(callback, {background=true})`，在独立浮窗关闭时继续取得申请摘要；取消订阅同时释放后台状态需求。悬停可调用 `API.Floating:ShowPopup(owner, anchor)` 临时展开共用列表，移出用 `HidePopup(owner)`，宿主隐藏用 `HidePopup(owner, true)`；这不搬移入口图标，独立浮窗关闭时仍可使用。其余挂载与状态合同继续见上述浮窗接口文档。

## 入口与生效时间

第三方插件声明 `## Dependencies: LycheeGroup`，在自己的 `ADDON_LOADED` 后访问 `LycheeGroup.API`。读取目录、导入和选择主题不会加载组队、笔记或主窗口。

| 入口 | 负责内容 | 生效时间 |
| --- | --- | --- |
| `API.Theme` v2 | 主题目录、选择、第三方默认主题、版本、导出和旧静态覆盖清除 | 下一次登录或重载 |
| `API.Configuration` v2 | 已登记的设置和布局偏好 | 依对应设置的现有生命周期生效；字号、比例、尺寸和列宽实时更新，语言需重载 |
| `API.Appearance` v2 | 当前主题及声明目录的只读查询 | 返回本次启动的主题；不返回活控件 |

主题在读入存档、完成迁移后固定，早于语言、字体和任何界面 Context 的初始化。导入后，已有页面、第一次打开的页面、新增池行、菜单、提示框和浮窗继续使用同一份当前主题。关闭再打开窗口不会应用待生效主题。

## Theme Lua 格式

内置入口为 [Theme/Defaults.lua](addon/LycheeGroup/Theme/Defaults.lua)，元素声明位于同目录的 `Elements.lua` 和 `FindElements.lua`。第三方使用相同声明格式。未提供的属性继承产品与共享库默认值，不需要复制整套主题。

```lua
local definition = {
    schema = 1,
    id = "myaddon.readable",
    name = "我的清晰主题",
    revision = "2",
    settings = {fontScale = 110},
    layout = {window = {width = 1400}},
    appearance = {
        main = {
            tokens = {primary = {0.72, 0.28, 0.38, 1}},
            elements = {
                ["host.settingsButton"] = {
                    base = {label = {fontSize = 16}},
                },
            },
        },
    },
}
local ok, err = LycheeGroup.API.Theme:Import(definition, {storage = "account"})
```

`schema=1` 是声明格式版本，与 API v2、存档 schema 和插件发布版本分别管理。`id` 为稳定且非空的标识符，`revision` 为非空字符串或有限数值。允许升级、回退及重装；不按字符串大小判断新旧。

`name` 是可选的非空显示名称，设置页的主题列表使用它；旧包未提供名称时显示 `id`。名称随导出保留，仅修改名称不会要求重载。内置主题为 `lycheegroup.default`（默认主题）和 `lycheegroup.frosted`（透明毛玻璃）；这两个 ID 不允许导入覆盖或删除。复制默认模板创建第三方主题时，使用自己的 ID。

`appearance.main` 和 `appearance.floating` 支持 `tokens`、`components`、`elements`、`utilities`。组件与元素可声明固定的 `base`、`states`、`variants`，元素还可组合 `classes` 和模板 `instances`。命名工具样式及状态前缀的语法见 [LycheeUI API](https://github.com/Follen/LycheeUI/blob/v1.0.0/API.md)。

产品 token `gameTextTint` 分别作用于主窗、提示和浮窗的职业色、评分色及钥石等级文字。默认 `{1,1,1,1}` 保留游戏原色；前三通道分别乘到原颜色上，不修改原色表、角色数据或图标。声明图标颜色后，控件的选中、悬停刷新保留该颜色，未声明的透明度和灰度仍正常反馈。当前内置库包含这一通用所有权修复，候选身份与实际哈希见 [LycheeUI .lock](addon/LycheeGroup/Libs/LycheeUI/.lock)。

`settings` 仅接收默认模板列出的 UI 设置，例如字体、字号、主窗与浮窗比例、动效、语言、入口和成员图标。自动申请、笔记、提醒、历史等业务设置使用 Configuration。`layout` 接收已有窗口、表格和位置偏好。主题提供默认值，玩家已保存的偏好继续优先。

`Theme:GetDefaults()` 按需生成完整可编辑模板，保留别名与派生关系，省略默认跟随项的固定快照；调整基础色后，未显式覆盖的派生色仍随基础色计算。模板不含玩家覆盖，也不登记包或创建界面。复制后为主题设置自己的 ID 和 revision。

## 导入、选择与重载状态

```lua
local themes = LycheeGroup.API.Theme
local ok, err = themes:Import(definition, {storage = "account"})
if ok then
    -- 在用户选择此主题时调用；包升级只重新 Import。
    ok, err = themes:Activate(definition.id, {storage = "account"})
end
local status = themes:GetStatus()
-- current：本次启动的主题身份；next：下次启动的选择
-- reloadRequired：当前与下次启动来源是否不同
-- error：本次启动回退的具体错误（若存在）
-- next.error：待选主题定义缺失的错误；此查询不重新编译待生效组合
-- default：未被玩家选择覆盖时的默认候选
-- followingDefault：没有明确选择，正在跟随默认候选
-- defaultConfigured：账号或角色保存了第三方默认候选
```

| 方法 | 行为 |
| --- | --- |
| `GetDefaults()` | 返回同格式的内置模板副本 |
| `Import(definition, options)` | 验证并注册或替换主题；`activate=true` 同时明确选择，`default=true` 同时指定为默认候选；省略时仅注册 |
| `Activate(idOrFalse, options)` | 明确选择已有或内置主题；`false` 和 `"lycheegroup.default"` 均选择内置默认，保留定义和玩家覆盖 |
| `SetDefault(idOrFalseOrNil, options)` | 指定配置包推荐的默认主题；`false` 指定内置默认，`nil` 清除此保存位置的默认候选；不覆盖明确选择 |
| `UseDefault(options)` | 清除此保存位置的明确选择，重新按账号／角色优先级查找；其他位置的明确选择继续有效 |
| `Remove(id, options)` | 删除该保存位置的定义及同 ID 明确选择、默认候选，下层选择重新参与查找；内置主题不可删除 |
| `List(options)` | 列出已导入主题；`includeBuiltins=true` 同时列出两个内置主题 |
| `Export(id, options)` | 导出指定包；省略 ID 导出选中包，`state="current"` 选择本次启动来源，默认使用下次启动来源 |
| `GetStatus()` | 返回 `current`、`next`、`reloadRequired` 和具体错误 |
| `Subscribe(callback)` | 目录或保存的选择变化后调用无参数回调；返回取消订阅函数，不立即回调，也不修改正在运行的外观 |
| `ResetOverrides(scope, paths, options)` | 清除指定保存位置的旧静态视觉覆盖，重载后跟随主题 |

Theme 写操作只接收 `account` 或 `character`，省略为 `account`。`storage="session"` 返回错误。主题定义和选择必须能够跨重载保存。

主题选择依次取：角色明确选择 → 账号明确选择 → 角色默认候选 → 账号默认候选 → 内置默认主题。明确选择 `false` 同样优先于第三方默认候选。第三方推荐主题变化时，未手动选择主题的玩家随之切换；已有明确选择继续保留。内置主题直接从产品目录读取；其他 ID 的定义先查角色、再查账号。删除角色包及该位置的选择后，账号选择重新参与查找。

设置 → 界面显示 → 界面主题列出两个内置主题及有效的第三方主题。玩家选择写入已有明确选择的位置；尚无明确选择时写入账号。选择、导入或默认候选变化均沿用重载后生效的方式。设置页打开期间更新目录会刷新可选项和选中名称；这类目录通知不应用新的视觉规则。

配置包注册主题并指定默认值的示例：

```lua
local themes = LycheeGroup.API.Theme
local ok, err = themes:Import(definition, {storage = "account", default = true})
-- 后续可用 SetDefault 更换推荐主题；不会覆盖玩家手动选择。
-- 例如推荐内置毛玻璃主题：
-- themes:SetDefault("lycheegroup.frosted", {storage = "account"})

for _, item in ipairs(themes:List({includeBuiltins = true})) do
    if item.effective then
        print(item.name, item.id, item.selected, item.isDefault)
    end
end
```

列表每项包含 `id`、`name`、`revision`、`storage`、`builtin`、`effective`、`current`、`selected`、`isDefault`。`storage` 为 `account`、`character` 或 `builtin`；同 ID 的角色定义遮蔽账号定义，被遮蔽项仍可查询，但 `effective=false`，设置页不重复显示。包结构损坏的存档项同样标记为 `effective=false` 并附带 `error`，原数据保留；目录查询不编译每个包，具体视觉字段仍在导入、选择及启动时验证。`current` 标记本次启动使用的位置，`selected` 标记待生效位置，`isDefault` 标记默认候选；玩家可明确选择其他主题，所以后两项不必相同。现有调用 `List()` 仍只取得导入包。

相同 ID、revision 和内容重复导入是幂等操作。更新未选主题不会产生当前主题的重载请求；更新当前选中主题不会改变正在显示的界面。字号、窗口尺寸等实时偏好的变更不计入 `reloadRequired`。

输入在写入前整批验证。未知字段、非法类型、循环表、不可保存对象或无效最终组合返回 `false, error`，不提交部分定义。启动时还会验证选中主题与旧覆盖的最终组合；失败时本次启动回到内置主题，保留原定义、覆盖及选择，并报告具体错误。导入通过替换表保存待生效数据，不原地修改本次启动来源。

存档装载时补齐缺失容器；类型错误的容器、非法实时偏好和偏好包保存在对应账号或角色根的 `uiConfigRecovery[完整路径]`，记录原值及错误。账号或角色存档根本身异常时，用 `$root` 路径保留原值；首次安装的缺失根不记录错误。无效主题包和覆盖保留原位，修正或重新导入后可恢复使用。未知元素分支即使为空表也拒绝导入。导入、启动与导出采用相同的主题偏好范围：只接受内置主题声明的界面设置与已登记布局，自动进组等业务设置仍归 Configuration；静态覆盖层只接受视觉字段。

```lua
-- paths 使用带前缀和 scope 的完整旧视觉键；nil 清除该 scope 的全部旧覆盖。
local ok, err = themes:ResetOverrides("main", {"theme.main.primary"},
    {storage = "account"})
```

## 声明目录与实例

`Appearance:ListElementDefinitions("main", "settings")` 列出指定范围的元素和模板；省略第二个参数查询整个窗口目录。`template=true` 表示接收实例规则。`GetElementSchema(scope, id, paths)` 按请求列出默认叶和指定属性，例如 `{"settings.row.base.label.fontSize"}`。查询不会永久登记字段、创建对象或加载页面。

元素使用产品声明的 `slotKinds` 和作用范围；主题不能重写它们。模板实例以业务键关联，数字和同内容的字符串是不同键。固定业务键可以关联跨重载的同一对象；临时结果 ID 的含义取决于产生它的游戏会话。合法实例规则不会因为对象尚未显示而创建行。

```lua
definition.appearance.main.elements["settings.row"] = {
    instances = {
        fontScale = {base = {label = {color = {1, 0.85, 0.85, 1}}}},
    },
}
```

规则在构造或池行绑定时应用。池行换业务键会清除旧条目的内容、交互状态和独立规则；业务重绘后仍遵循本次启动的固定规则。行高、状态几何和实例高度参与完整列表的排列、滚动、定位及命中，零高条目折叠。

| Appearance 只读方法 | 返回内容 |
| --- | --- |
| `Get(scope)` | 当前解析 token；字体路径按当前用户字体偏好返回 |
| `GetSchema(scope)` | token 默认值、类型与限制 |
| `GetStyleSchema(scope, paths)` | 组件样式的按需目录 |
| `ListElementDefinitions(scope, filter)` | 静态元素与模板声明 |
| `GetElementSchema(scope, id, paths)` | 元素字段目录 |
| `GetElements(scope)` | 默认声明与当前有效元素规则的合并副本 |
| `GetElementRules(scope, id, key)` | 模板或指定实例的当前规则 |
| `GetUtilities(scope)` | 当前工具样式定义副本 |
| `GetTypography(scope)` | 共享文字角色的当前基准字号与行高 |
| `GetColors(scope)` | 当前颜色角色的解析值 |

这些接口不返回 Frame、Texture、FontString 或控制器。`GetElement`、`GetElementInfo`、视觉 Set／Reset 和各类 SetElement 方法已移除。内部必要的锚点、字体和池行引用由实际使用者管理。

## 实时设置与布局偏好

Configuration 只接收 `settings.*` 和已登记的 `layout.*`，拒绝 `theme.*`、`style.*`、`element.*` 和 `utility.*`，不转发到其他入口。

```lua
local config = LycheeGroup.API.Configuration
local ok, err = config:Set({["settings.fontScale"] = 110})
ok, err = config:Set({["layout.window.width"] = 1400}, {storage = "character"})
ok, err = config:Reset("settings.fontScale", {storage = "session"})
local value = config:Get("settings.fontScale")
local source = config:GetSource("settings.fontScale")
```

Configuration 保存位置为 `session`、`account`、`character`，省略为 `session`。账号位于 `LycheeGroupDB.uiConfig`，角色位于 `LycheeGroupPrefsDB.uiConfig`；session 只在内存中。

有效值依次取：会话用户修改 → 角色用户修改 → 账号用户修改 → 当前偏好包 → 本次启动主题的 UI 默认值 → 内置默认值。明确关闭偏好包仍允许继承本次启动的主题默认值。设置页按原保存范围写入；窗口尺寸、表格偏好等继续按角色保存。

| 方法 | 行为 |
| --- | --- |
| `Get(key)`、`GetSource(key)` | 值副本或来源；来源区分用户、偏好包、主题与内置默认 |
| `GetSchema(key)` | 指定键或全部实时设置目录 |
| `Set(values, options)` | 一批扁平键值写用户层，整批验证 |
| `Reset(keyOrKeys, options)` | 清除所选位置的一项或多项用户偏好 |
| `RegisterPreset(id, revision, values, options)` | 注册或替换偏好包；`default=true` 同时将其设为默认候选，不覆盖明确选择 |
| `ActivatePreset(idOrFalse, options)` | 选择偏好包或明确关闭偏好包 |
| `ApplyPreset(id, revision, values, options)` | 原子注册并选择偏好包 |
| `SetDefaultPreset(idOrFalseOrNil, options)` | 指定默认候选；`false` 默认不使用偏好包，`nil` 清除此位置的候选 |
| `UseDefaultPreset(options)` | 清除此位置的明确选择，重新按保存位置查找 |
| `GetPresetStatus()` | 查询有效选择、默认候选、是否跟随默认及缺失定义错误 |
| `RemovePreset(id, options)` | 删除该位置的定义和同 ID 明确选择、默认候选 |
| `ListPresets()`、`ExportPreset(id)` | 查询定义、位置和有效选择，或导出定义副本 |

偏好包只能包含实时设置与布局键。包升级用 RegisterPreset 替换默认值并保留用户层，不使用 Set 将包默认值逐项固定为用户选择。相同有效值写入仍记录明确用户意图，有效值未变时跳过无效界面刷新。输入与公开返回值均隔离复制。

偏好包选择顺序为：会话明确选择 → 角色明确选择 → 账号明确选择 → 会话默认候选 → 角色默认候选 → 账号默认候选。明确选择 `false` 也优先于所有默认候选。定义按会话、角色、账号查找；同 ID 上层定义遮蔽下层定义。`UseDefaultPreset` 只清除指定位置的明确选择，其他位置的选择仍有效。

`GetPresetStatus()` 返回 `selected`、`default`、`followingDefault`、`defaultConfigured`。前两项含 `id`（未用包时为 `false`）、`selectionStorage`（选择保存位置）；找到定义时另含 `storage` 和 `revision`，缺失时含 `error`。`selected` 是最终使用的候选；是否来自默认选择由 `followingDefault` 区分。

整合包作者可以在自己的加载入口注册一次，更新时保留 ID 并替换 revision 和 values：

```lua
local config = LycheeGroup.API.Configuration
local ok, err = config:RegisterPreset("myaddon.defaults", 2, {
    ["settings.fontScale"] = 110,
    ["settings.toggleBinding"] = "CTRL-G",
    ["settings.autoApply"] = false,
    ["settings.creationRaidDifficultyID"] = 15,
    ["layout.window.width"] = 1400,
    ["layout.tables.findResults.widths.title"] = 0.22,
    ["layout.tables.createApplicants.sortKey"] = "rating",
    ["layout.tables.createApplicants.descending"] = true,
}, {storage = "account", default = true})

-- 用户自己调整后，即使作者再次注册升级，用户值仍优先。
config:Set({["settings.fontScale"] = 100}, {storage = "character"})
-- 用户重置这项后，重新继承包的 110。
config:Reset("settings.fontScale", {storage = "character"})
```

配置包提供默认值时使用 `RegisterPreset(..., {default=true})`。`ApplyPreset` 会记录明确选择，适用于玩家主动应用整包的操作。上述写入均可在 UI 和业务包尚未加载时完成，后建页面读取有效值。

### 设置与布局覆盖范围

完整键、默认值、类型和范围通过 `GetSchema()` 查询；列宽和排序的合法列随表格区分，不猜测列名。当前八张表为 `findResults`、`findRaidResults`、`findApplications`、`createApplicants`、`notesRecords`、`notesHistory`、`notesHistoryMembers`、`blockedLeaders`。

| 内容 | 配置入口与含义 |
| --- | --- |
| 设置页普通偏好 | `settings.<控件键>`，包括语言、字体、字号、比例、动效、入口、声音、成员显示、笔记、提醒、历史及浮窗开关；保存范围见 Schema |
| 主题选择 | `Theme:Import(..., {default=true})`、`Theme:SetDefault`，下次重载生效 |
| 窗口与侧栏 | `layout.window.width/height`、`layout.find.railCollapsed`，按角色保存 |
| 浮窗位置 | `layout.floating.position`，锚点表或 `false`（自动位置），按账号保存；“重置位置”清除账号用户值并继承包／主题默认 |
| 表格 | `layout.tables.<表>.widths.<列>`、`.sortKey`、`.descending`；宽度是可用表宽的权重，受该列最小宽度约束。未提供时沿用列定义；重置清除角色用户宽度，重新继承有效默认 |
| 打开快捷键 | `settings.toggleBinding`，键名字符串或 `false`，默认 `";"`；沿原生账号／角色按键方案管理 |
| 自动申请 | `settings.autoApply`，布尔，默认 `false`，按角色保存 |
| 申请职责 | 使用 I 键原生组队面板当前的坦克／治疗／输出多选，不属于 Configuration 或主题字段 |
| 创建团本难度 | `settings.creationRaidDifficultyID`，`false` 或正整数，按角色保存；当前活动不可用时按原流程选择可用难度，不覆盖保存值 |
| 页面固定外观 | Theme 的 token、component、element 和 utility；留白、字号、控件宽高、状态颜色通过声明提供启动默认 |

申请职责不再通过配置包提供默认值，`GetSchema()` 不包含 `settings.applicationRoles`。初始化清理旧账号、角色及偏好包中的该字段；旧包通过 `Set`、`RegisterPreset` 或 `ApplyPreset` 写入时忽略该字段，其他值仍按原合同验证和保存。进入页面、显示控件和计算活动可用性不会将原生职责复制为用户覆盖。

正式申请弹窗读取 `GetLFGRoles()` 的坦克、治疗、输出三项选择；点击按钮立即通过 `SetLFGRoles` 同步三项，保留原生 leader 标志，不将其显示为职责选项。取消或申请失败均保留原生编辑。自动申请每次读取当前原生选择：非空且全部可用时直接启用或提交，空值或含不可用项时打开职责设置；`settings.autoApply` 仍按角色保存。普通预览及引导只修改 `provider.applicationPrefs.roles`，不修改原生职责或正式存档。

快捷键默认只更新本插件自动分配且用户未修改的主键，不抢占其他功能已有按键。已有原生绑定和旧版本初始化记录保持原状；玩家录键或在暴雪界面修改主键后记为用户选择。仅调整第二键不锁定自动主键，默认升级保留第二键。战斗期间等待退出战斗；冲突键释放后的绑定更新事件可重新尝试。`Get` 返回配置意图，实际按键仍以原生绑定及设置页显示为准。

表格在当前活动下没有某个排序列时，暂用可用排序；原排序偏好保留，列恢复后继续使用。配置更新发生在列宽拖动期间时，取消旧拖动，再应用新值。

### 寻队分类与筛选默认

`settings.find.category` 提供初始分类；每分类的默认放在 `settings.find.categories.<分类键>.<字段>`。启动登记 `seasonDungeon`、`seasonRaid`、`1`、`2`、`3`、`4`、`6`、`7`、`8`、`9`、`121` 共 11 个分类；客户端发现的额外数字分类随目录登记，保存后的分类在下次存档验证前恢复登记。可用分类和活动仍以客户端目录为准；作者写入前通过 Schema 查询已登记字段。每个字段独立解析和覆盖，不使用整表用户快照遮蔽其他默认。

| 字段 | 值 |
| --- | --- |
| `groupKey`、`groupKeys` | 单个非零整数活动组键，或 `{[活动组键]=true}` 集合；`false`／空集合表示不限定 |
| `tier`、`difficultyID`、`selected` | 资料片层级、难度及既有活动选择状态；`tier` 接受正整数或 `exp数字`，`difficultyID` 接受正整数，前两项也可为 `false`，`selected` 为布尔 |
| `neededRole` | `false`、`TANK`、`HEALER`、`DAMAGER` |
| `tankPresence`、`healerPresence`、`damagePresence` | `false`、`missing`、`present` |
| `hideZeroScore`、`hideSameSpec`、`hideSameClass`、`hideSameClassRole`、`requireBloodlust`、`roleMatchAny` | 布尔；具体活动不适用的条件不进入实际筛选 |
| `minRating`、`maxRating`、`minItemLevel`、`maxItemLevel`、`minMembers`、`maxMembers` | 整数或 `false`；人数按当前活动人数上限投影，配置原值保留 |
| `social` | `false`、`friend`、`guild`、`any`、`positive`、`noCaution` |
| `sort` | `false`、`newest`、`rating`、`itemLevel`、`members`；`false` 跟随 `settings.defaultSort`，与表头列排序分别管理 |

这些字段默认按角色保存。正常控件操作只写实际改变的字段；“清空筛选”写明确的关闭值，`Reset` 才恢复继承。分类和活动可用性修正、普通刷新、打开和关闭页面不会固定包默认。修改包或公开设置会刷新适用的筛选，但不直接确认搜索；后续操作沿用原页面流程。

关闭 `settings.rememberFilters` 后，持久的账号／角色寻队用户值暂不参与解析，仍保留在存档；此时 `Get`、`GetSource` 使用会话用户值 → 当前包 → 主题偏好 → 内置默认。单独切换记忆开关保留当前浏览状态和未提交的选择草稿，页面在换分类或重新进入时读取新的有效值。关闭期间的临时页面操作不写持久用户层；再次启用后，下次恢复页面偏好时使用持久筛选覆盖。预览与教学使用各自私有偏好。

例如，把大秘境最低评分默认设为 2000、默认不要求嗜血：

```lua
config:RegisterPreset("myaddon.find", 1, {
    ["settings.find.category"] = "seasonDungeon",
    ["settings.find.categories.seasonDungeon.minRating"] = 2000,
    ["settings.find.categories.seasonDungeon.requireBloodlust"] = false,
}, {storage = "account", default = true})
```

同一时刻只选用一个偏好包；实际整合包应把这些叶与上面的字体、列宽等放入同一个 `values`。分两次注册不同 ID 不会叠加成多层默认。


## 旧数据迁移

`uiConfig.schema` 从 1 迁到 2，业务存档 schema 不变。视觉用户覆盖进入 `uiConfig.theme.overrides`；主题定义及选择进入该 theme 表的 `presets` 和 `activePreset`。原用户设置、布局和业务偏好仍由 Configuration 持有。

旧混合包包含视觉内容时，其视觉、UI 默认值和布局投影为主题，剩余业务设置投影为偏好包；纯设置／布局包保留为偏好包。保留 ID、revision、保存位置和有效选择，选择只投影到实际存在的部分。迁移标记避免用户 Reset 后从旧字段恢复。无法识别的数据保留用于定位。

笔记、历史、收藏、屏蔽、申请与招募不进入主题存档。主题导入、选择和状态查询不发送业务操作。第三方通过公开接口更新，不直接写数据库、内部主题表或控件。
