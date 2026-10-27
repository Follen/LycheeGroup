# 配置默认覆盖审计 · 2026-10-27

本轮检查设置页、页面持久偏好、表格消费者及 LycheeUI 通用样式反馈。产品变更位于 `codex/configuration-defaults-audit`，源库变更位于独立工作树的 `codex/theme-style-ownership`。插件当前发布号仍为 1.2.6；内置库为尚未发布的 LycheeUI 1.0.1 候选（加载排序 10001）。公开用法与保存规则集中在 [API.md](../../API.md)，这里保留审计发现与验证范围。

白色主题已从本轮产品代码撤回。保留默认主题、透明毛玻璃及第三方主题入口；通用颜色和样式所有权修复继续保留。

## 覆盖清单

| 对象 | 审计结果与修正 |
| --- | --- |
| 设置页 27 项 | 26 项普通设置使用 Configuration；主题使用 Theme。补上原先独立于 Schema 的打开快捷键，其余普通控件已有有效值读取和变更接入 |
| 设置页外偏好 | `askReason`、`autoJoin`、`minimapAngle`、`notesEnabled` 已有接入；补全 `autoApply`、`applicationRoles`、`creationRaidDifficultyID` |
| 偏好包选择 | 新增默认候选，与玩家明确选择分离；默认包升级不抢回玩家选择，用户单项继续优先 |
| 寻队持久偏好 | 启动登记 11 个分类的 23 项字段及初始分类，共 254 叶。字段独立覆盖；新增原生分类在发现时登记，存档中的已登记分类在重载验证前恢复 Schema |
| 窗口、浮窗、侧栏 | 窗口宽高、浮窗位置及侧栏均有 API；修复浮窗重置写死自动位置，改为清除账号覆盖 |
| 八套表格 | 所有列宽叶及合法排序叶均有接入；修复同值重置丢有效默认、旧拖动覆盖新配置、暂时无评分列时丢排序偏好 |
| 页面固定外观 | 通过 Theme 的 token、component、element、utility 提供默认；不把固定像素尺寸重复加入实时设置 |
| LycheeUI 通用反馈 | 按实际目标逐属性检查声明所有权，覆盖子文字区域、Glyph／Texture 和其他 Context；无需产品导航专用绕过 |
| 游戏语义文字颜色 | 产品层 `gameTextTint` 分别适配主窗和浮窗，默认保持职业、评分、钥石等级原色；共享库不读取组队业务或角色资料 |

设置页普通键为：`language`、`toggleBinding`、`minimap`、`nativeLFGEntry`、`applicantAlertSound`、`font`、`fontScale`、`uiScale`、`reduceMotion`、`defaultSort`、`rememberFilters`、`showImportantFilters`、`relations`、`raidMembers`、`memberIconShape`、`memberIconScale`、`memberClassBorder`、`memberLeaderMark`、`defaultNote`、`noteMarks`、`reminders`、`history`、`floating`、`floatingCompatibility`、`floatingScale`、`floatingLocked`。

八套表格为：`findResults`、`findRaidResults`、`findApplications`、`createApplicants`、`notesRecords`、`notesHistory`、`notesHistoryMembers`、`blockedLeaders`。部分表默认宽度表为空，表示沿用动态列定义；其列宽 Schema 已登记，原先并非缺少 API。

当前招募的自动邀请、正在编辑的标题／备注、申请状态、搜索文本及短暂展开状态属于业务或临时交互。笔记、历史、收藏和屏蔽名单属于用户内容，不作为偏好包默认写入。

## 已复现的错误路径

- 表格当前列宽与包默认相同，右键重置不产生有效值变更通知，但控件已清空投影，导致默认丢失。重置成功后显式重建当前有效状态。
- 配置更新发生在列宽拖动中，旧拖动收尾提交覆盖新配置。更新前取消旧拖动。
- 创建页面从有评分列切到无评分列，临时排序回退被写回共享偏好。改为仅在当前呈现中回退。
- 浮窗“重置位置”写入 `false`，使包位置默认永久被用户层遮蔽。改用 `Reset`。
- 普通寻队刷新把继承的排序和筛选保存为用户值，后续包升级不再生效。改为标记实际控件操作，逐叶写入；兼容投影不参与再次迁移。
- 图标选择反馈直接写颜色，覆盖固定主题声明；独立子文字区域也可能被宿主默认反馈覆盖。库统一从实际目标查找有效属性所有权。
- 原生 Texture 的颜色 Alpha 与透明度共享通道。默认透明度反馈改变颜色读数后，旧释放判断误以为颜色被外部改动，留下声明色；修复后按已写 RGB 识别库自身的 Alpha 变化，并保留独立透明度声明。
- 侧聊转入的 `Motion.lua:275` 报错可在默认主题下用真实 Glyph 图标按钮的悬停首帧复现：渐变只读 `.color`，而 Glyph 只维护原生纹理色。改为读取可用的当前纹理色；CheckMark 维护其材质色；无法读取起点的自定义对象直接应用终值。专项保留正常渐变、中途改目标、原生外部变色和停止收尾。这个构造路径证明接口缺陷，未据此指定玩家原始报错来自哪个按钮。

## 自动申请职责反馈

用户报告 DPS 改回输出职责后，重载又默认治疗。独立复现使用已开启自动申请、已保存治疗职责、当前输出专精的前提：手动打开申请弹窗，取消治疗并选择输出，提交成功；本次原生提交是输出，但保存值仍为治疗，重新创建会话后仍选择治疗。

原因是旧产品规则将“自动申请已开启时的编辑后申请”视为单次修改，`Application:Apply` 成功分支跳过职责保存。本轮改为成功提交且玩家明确编辑职责时更新后续默认；取消、失败和仅预选不写。专精与申请职责分别管理，不根据当前专精强行改写已有合法选择。

## 验证入口

- 产品完整行为：`lua tests/runner.lua`。
- 页面几何和复用：`lua tests/run_layout_checks.lua`。
- 默认值专项：`configuration`、`binding_defaults`、`behavior_defaults`、`layout_preset_defaults`、`find_defaults`、`theme_game_colors`、`glyph_slots`。
- 共享库：`tests/run.lua`、`icon_style_ownership.lua`、`motion_color.lua`、`fixed_writes.lua`、`elements_ownership.lua`、`style_release.lua`、`style_events.lua`。
- 边界与源库同步：`node tests/check_architecture.cjs <独立库工作树>`，逐一核对 31 个冻结文件及 SHA-256。
- 原生加载与控件合同：[live_configuration_defaults.lua](../live_configuration_defaults.lua)，范围见[验证说明](../theme_reload.md)。

Configuration 的独立复核另枚举 4,096 种三层明确选择／默认候选组合，以及 5 类非法写入，确认明确关闭、跨层优先级与事务不部分提交。

## 本轮验证结果

- 完整产品 runner：55,442 条断言通过，0 个失败模块；部分独立控制器脚本另有自身计数，未混入此总数。
- 布局：17 个脚本全部通过，共 34,401 项检查。
- 性能探针生命周期：340 项通过，覆盖成功、取消、超时和观察器失败时的配置及界面恢复；此次没有重新测量游戏内存。
- 寻队新增专项：757 条断言；包含持久值与包默认不同、打开未提交草稿时切换记忆开关的情况。
- 84 个运行 Lua 文件及两个原生探针通过语法检查。
- 共享库：主回归 1,666 项，图标与共享 Alpha 专项 94 项，正常颜色渐变专项 14 项；固定写入 96、元素所有权 59、样式释放 727、样式事件 19 项均通过。
- 架构与同步：6,633 项通过，31 个冻结运行文件与独立源库、内置副本的 SHA-256 一致。

职责保存使用真实产品控制器与原生接口替身验证“治疗改输出 → 成功提交 → 后续自动申请 → 重载”。实机检查采用私有隐藏控件，不发送真实组队申请。

## 游戏同步与原生结果

2026-10-27 已将五个产品包同步到当前正式服安装目录，最终 163 个源文件逐一通过 SHA-256 校验。改写前备份和逐文件记录保留在本工作树 `.lycheedev/` 下三个 `api-defaults-deploy-20261027-` 目录中，时间后缀分别为 `122548`、`123633`、`124237`。选中的账号白色主题通过公开 Theme API 改回内置默认，并完成重载；其他设置未为探针准备而改写。

原生客户端为 retail `12.1.5.70575`，插件显示版本 `1.2.6`，实际加载 LycheeUI `1.0.1` 开发候选。最终请求 `api-defaults-native-check-r3`，操作 `LMO-ecdf6d0ebc729cfff0f17d24cd6cf0c8`：`report.ok=true`、`reportState=verified`、`cleanup=complete`；连接 `CON-c83074fecbe20d382a72bb8e51a7ef26` 已关闭。

原生检查确认新增公开方法与 16 个代表 Schema 叶存在、内置主题数量为 2、白色主题不存在、启动主题为默认且无编译错误；图标三态保留声明 RGB，释放后立即恢复默认 RGB／透明度／灰度，独立 Texture 透明度不被颜色状态和释放覆盖，独立子文字样式有效。正常动效下的 Glyph 颜色首帧插值、中途改目标和完成状态也通过。

首轮原生检查实际发现共享 Alpha 导致的释放错误，后续修复已在同一客户端重载复测。第二轮的新增透明度场景误用了同一宿主的两次构造式 `Style`，按公开合同改为独立宿主槽位后纳入最终检查；这项探针错误没有用于修改生产接口。
