# 荔枝组队 · Lychee LFG

简体中文 · [English](README.en.md)

魔兽世界正式服组队插件。在一个窗口里寻找队伍、管理招募，并记录与玩家的组队经历。

当前版本 **1.0.5**，目标客户端为正式服 **12.1.5**（Interface `120105`），支持中文和英文。版本变化见[更新日志](CHANGELOG.md)。

## 功能

- **寻找队伍**：浏览地下城、团本、地下堡和 PvP 等活动，搜索、筛选队伍，在列表查看创建备注，查看成员信息与申请状态。
- **创建组队**：发布和修改招募信息，查看申请者的大秘境记录与已知阵营，邀请成员。点击活动旁星标主动收藏当前创建条件，应用时保留当前标题和说明，由玩家确认发布；不自动保存创建历史。小队活动直接显示当前成员，团队活动悬停职责人数查看分组名单；当前赛季团本提供职业增益缺口提示。
- **角色偏好**：申请职责、各分类筛选和排序按角色保存，重载后恢复；自动申请开关仍需在当前会话开启。
- **玩家笔记**：账号内各角色共享推荐、中性或拉黑记录，再次组队时提醒；支持导入与导出。
- **大秘境历史**：按角色保存副本、层数、时间和队友，方便回顾与补充笔记。
- **界面设置**：修改主窗口快捷键和整体缩放，悬浮窗使用独立的缩放设置。

界面采用原生 Lua，内置 LycheeUI，业务模块按需加载。安装时无需另外安装 UI 库。

功能实现与验证范围见[产品文档](Product.md)。

## 安装

1. 下载或克隆本仓库。
2. 将 [`addon/`](addon) 下的四个文件夹复制到游戏目录 `World of Warcraft/_retail_/Interface/AddOns/`：

   ```text
   LycheeGroup
   LycheeGroup_Group
   LycheeGroup_Notes
   LycheeGroup_UI
   ```

3. 启动或重启游戏，在插件列表中启用荔枝组队，输入 `/lg` 打开。

## 常用命令

| 命令 | 操作 |
| --- | --- |
| `/lg` | 打开或关闭主窗口 |
| `/lg create` | 创建与管理组队 |
| `/lg notes` | 打开玩家笔记 |
| `/lg settings` | 打开设置 |
| `/lg note` | 记录当前目标玩家 |
| `/lg note 玩家名-服务器 理由` | 按姓名记录玩家 |

`/lycheegroup` 与 `/lg` 等效。

主窗默认快捷键为英文半角分号 `;`，只在尚无本插件绑定且该键未占用时初始化。可在设置“入口与快捷键”修改快捷键，在“界面与外观”将主窗整体缩放调整为 75%–125%，选择跟随游戏、简体中文或 English（重载后生效），以及切换界面字体。默认内置“荔枝字体 / LycheeFont”，中文界面整套使用雅黑，英文界面使用 Inter；也可继续使用游戏或共享字体。

## 开发

使用 Lua 5.1 在仓库根目录运行离线测试：

```sh
lua tests/runner.lua
```

本地控件树预览：运行 `lua tests/ui_preview.lua`，再打开 [`tests/ui-preview.html`](tests/ui-preview.html)。生成的 `tests/preview-data.js` 仅保留在本地，不提交到版本库；预览使用样例数据，不代表游戏内验证。

[`tools/Build-Addon.ps1`](tools/Build-Addon.ps1) 用于打包，默认从相邻的 `LycheeUI` 源码目录同步内置库，也可用 `-LibraryPath` 指定位置。

项目说明：[产品](Product.md) · [设计](Desgin.md) · [架构](Architecture.md) · [性能](perfermance.md) · [文档与变更记录规则](Agents.md)。当前实现与游戏内验证范围见产品文档。

共享界面库当前为 LycheeUI 1.2.0（修订 18）；开发接入见 [README](../LycheeUI/README.md)、[API](../LycheeUI/API.md) 和 [组件设计规范](../LycheeUI/DESIGN.md)。

内置第三方库的来源与许可见[库说明](addon/LycheeGroup_Group/Libs/README.md)。
