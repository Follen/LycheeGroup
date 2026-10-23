# LycheeGroup 配置 API

状态：配置 API v1，随当前未发布分支提供。插件版本仍为 1.2.3；接口新增不自动发版。共享控件接口见 [LycheeUI API](../LycheeUI/API.md)，视觉默认值见 [Desgin.md](Desgin.md)。

## 入口与作用范围

第三方插件声明 `## Dependencies: LycheeGroup`，在自己的 `ADDON_LOADED` 后使用 `LycheeGroup.API.Configuration` 或 `LycheeGroup.API.Appearance`。读取配置不会加载组队、笔记或主窗口。配置可以在窗口首次打开前应用；已有控件会更新，后续创建及复用的控件使用相同值。

`Configuration:GetSchema()` 返回全部可配置键及其默认值、类型、默认用户保存位置和数值／枚举限制。键名区分大小写。主题默认值与产品扩展在同一目录中，第三方应查询目录，不直接修改 `LycheeGroupDB`、`UI.Theme` 或 Frame。

本轮目录共有 1,572 个配置键：主窗主题 1,134 项、浮窗主题 351 项、既有设置 28 项、窗口及表格偏好 59 项。主题目录包含 LycheeUI 的通用组件参数与产品参数；主窗、浮窗的同名键按范围分别计数，不代表 1,485 种不同的视觉标准。共享库提供 263 个默认主题参数，产品默认表另有主窗 877 项、浮窗 89 项，其中少量覆盖共享默认值。实际可用目录以 `GetSchema()` 为准。

| 键前缀 | 内容 |
| --- | --- |
| `settings.*` | 设置页使用的字体、字号比例、动效、入口、头像外观及已有行为开关 |
| `theme.main.*` | 主窗、小地图入口及其组件的字号、行高、颜色、尺寸、间距和动画参数 |
| `theme.floating.*` | 浮窗独立主题及组件参数 |
| `layout.window.width` / `height` | 用户偏好的主窗宽高；未设置时跟随主题尺寸 |
| `layout.floating.position` | 浮窗锚点，或 `false` 表示默认位置 |
| `layout.find.railCollapsed` | 寻队侧栏收起状态 |
| `layout.tables.<表名>.widths.<列名>` | 列宽权重，正数；按表内权重分配并保留控件所需最小宽度 |
| `layout.tables.<表名>.sortKey` / `descending` | 该表支持的排序列与方向；`false` 表示无额外表头排序 |

表名为 `findResults`、`findRaidResults`、`findApplications`、`createApplicants`、`notesRecords`、`notesHistory`、`notesHistoryMembers`、`blockedLeaders`。允许的列名由 schema 给出。主题的 `font` 不单独公开，两个窗口统一使用 `settings.font`，可选 `default`、`game` 或字体文件路径。`settings.fontScale` 是文字比例，`settings.uiScale`、`floatingScale` 和 `memberIconScale` 分别控制窗口、浮窗与成员头像比例。

玩家笔记、屏蔽名单、历史队友、真实申请／招募状态、收藏方案及搜索条件记录继续由原业务模块管理，不作为主题配置包数据分发。原 Floating API v1 保持兼容。

## 保存位置与优先级

所有公共写操作的 `options.storage` 可选 `session`、`account`、`character`，省略时为 `session`。

| 位置 | 生存期 | 保存方式 |
| --- | --- | --- |
| `session` | 当前游戏 UI 会话，重载后消失 | 仅 Lua 内存 |
| `account` | 同账号角色共享 | `LycheeGroupDB.uiConfig` |
| `character` | 当前角色 | `LycheeGroupPrefsDB.uiConfig` |

有效值依次取：会话用户修改 → 角色用户修改 → 账号用户修改 → 当前配置包 → 内置默认值。配置包只有一个生效选择；选择及同 ID 包定义均按会话、角色、账号顺序查找。`ActivatePreset(false, options)` 显式使用内置默认主题，仍保留用户修改。

设置页操作按原保存范围写用户层；窗口尺寸和表格布局按角色保存。对当前值再次 `Set` 仍会记录用户意图，但有效值不变时不刷新界面。`Reset` 清除指定位置的用户覆盖，使其重新跟随下层。它不会删除其他位置的用户修改。

## 配置包注册与升级

配置包作者使用 `RegisterPreset` 发布默认值，用户选择时再调用 `ActivatePreset`。`ApplyPreset` 在一个批次内完成两步，适合首次安装或用户明确选择。后续包升级使用相同 ID 调用 `RegisterPreset`，不会改动用户当前选择和用户覆盖。

```lua
local config = LycheeGroup.API.Configuration
local values = {
    ["theme.main.font14"] = 15,
    ["theme.main.line20"] = 22,
    ["theme.main.primary"] = {0.72, 0.28, 0.38, 1},
    ["theme.main.findResultRowHeight"] = 80,
    ["settings.reduceMotion"] = true,
}
local ok, err = config:RegisterPreset("myaddon.readable", "2", values,
    {storage = "account"})
if ok then
    -- Run on the user's choice, rather than on every package update.
    ok, err = config:ActivatePreset("myaddon.readable", {storage = "account"})
end
```

同 ID 再次注册会替换该位置的包定义，撤回的键重新跟随默认值。revision 是非空字符串或有限数值，用于识别版本；允许升级、回退及重装，不擅自按字符串比较版本。用户层与包定义分开保存，因此包换色、调字号或删掉旧参数都不会覆盖用户自己修改的键。

`Set` 表示明确修改用户层；配置包升级不要用它逐项重写默认值。直接写入外部复制的 SavedVariables 文件不在此 API 的保护范围内。

## 常用调用

```lua
local config = LycheeGroup.API.Configuration

-- Preview for this session; a later reload restores saved choices.
local ok, err = config:Set({["settings.fontScale"] = 110})

-- Explicit user preference, persisted for this character.
ok, err = config:Set({["layout.window.width"] = 1400}, {storage = "character"})

-- Follow the preset/default again for one account preference.
ok, err = config:Reset("theme.main.primary", {storage = "account"})

local value = config:Get("theme.main.primary")
local source = config:GetSource("theme.main.primary")
-- source.kind: default / preset / user
-- source.storage; for presets also id, revision and activationStorage.
```

| 方法 | 结果与行为 |
| --- | --- |
| `Get(key)` | 值的独立副本；未知键返回 `nil, error` |
| `GetSource(key)` | 有效值来源 |
| `GetSchema()` | 独立的公开目录；联合类型使用字符串数组 |
| `Set(values, options)` | 一批扁平键值写入用户层 |
| `Reset(keyOrKeys, options)` | 清除指定位置的一项或多项用户覆盖 |
| `RegisterPreset(id, revision, values, options)` | 注册或替换包定义，不改变选择 |
| `ActivatePreset(idOrFalse, options)` | 选择已注册包，或显式关闭配置包 |
| `ApplyPreset(id, revision, values, options)` | 原子注册并选择 |
| `RemovePreset(id, options)` | 删除指定位置的定义及该位置同 ID 的选择；下层选择重新生效 |
| `ListPresets()` | 列出各位置定义、版本和有效激活状态 |
| `ExportPreset(id)` | 导出该 ID 当前优先级最高的定义副本 |

写操作返回 `true` 或 `false, error`。整个批次先校验；未知键、错误类型、非法枚举、非有限数值、不可保存对象或循环表使整批失败，不留下半套配置。返回值及输入值复制，调用方后续修改表不会悄悄改变已保存配置。浮窗位置格式为 `{point="CENTER", relativePoint="CENTER", x=0, y=0}`，相对 UIParent。

只改外观时可使用简写，保存规则相同：

```lua
local appearance = LycheeGroup.API.Appearance
local schema = appearance:GetSchema("main")
local effectiveTheme = appearance:Get("main")
local ok, err = appearance:Set("main", {font14=15, line20=22})
ok, err = appearance:Reset("main", {"font14", "line20"})
```

`Appearance:Get` 返回解析了别名和派生颜色的主题。`Configuration:Get` 返回指定键在配置层中的值；未显式覆盖的颜色别名和基础字号别名仍在 LycheeUI 解析时跟随其来源。主窗原有字号／行高增量和文字比例保持原计算顺序。

## 旧数据迁移

首次加载时，在旧字段补默认值之前记录其真实存在状态。已有公开设置、窗口尺寸、浮窗位置和表格布局导入对应用户层；旧版本没有记录来源，因此即使旧值恰好等于默认值，也保守视为用户选择。新安装中不存在的字段继续跟随配置包。

迁移标记按键保存，重载不重复导入；后续增加的键从未被补默认值污染的原始快照读取。显式 Reset 也保存迁移标记，避免旧字段在下一次登录复活。原五份 SavedVariables 保留原职责和业务 schema，玩家记录、历史和收藏数据不搬迁。内部旧字段仅兼容镜像持久用户修改，配置包与会话预览不会把临时有效值写回旧存档字段。
