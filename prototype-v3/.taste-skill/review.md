# v3 设计复核

日期：2026-10-16。范围为桌面游戏插件的交互原型，未恢复 Lua 实施、安装或实机测试。

按用户指定的 design-taste-frontend 执行方向抽取、源码检查、三个视口的浏览器检查及截图复核。方向为 **The product performs**，seed **246573259**，无重抽；保留荔枝既有配色、字体与主导航。这个技能主要针对营销网页，其大图、视频、大标题和全页动效要求不适用于本次固定尺寸游戏界面，未据此把组队流程改为宣传页，也未将整页标成 `data-ui` 来隐藏检查结果。

ROUND 1
Seen in one second: 荔枝标志、队伍结果和右侧申请区；桌面能辨认工作区。
Idea (one sentence): 浏览队伍时持续看见申请进展，并把玩家记录放在组队判断旁边。
Live thing: 搜索队伍、提交申请、查看倒计时和沿用备注。
Layout words by section: navigation=bar / activity=list / results=list / applications=rail。
Scores: design 6.5 · usability 5 · creativity 7 · content 8 → overall 6.0（上限后）
Caps applied: 自动检查有 FAIL；按营销页规则缺少大幅图片；窄屏等比缩小不具备手机操作可读性。
Top three problems (most visible first), each with the screenshot it shows in and the fix:
1. `before/desktop-fold.jpg`：右栏重复放接受／婉拒，破坏原生邀请流程。改为状态和回应位置，独立演示游戏弹窗。
2. 用户提供的团本提示截图：概要、成员、笔记理由的层级不清。用进度／装等作为第一层，构成与说明在中段，笔记独立分组，Shift 在右侧增加完整名单。
3. `before/mobile-fold.jpg`：评审工具栏挤成竖排。允许工具栏换行，按钮文案不拆字；桌面游戏窗仍按既定方式等比预览，不伪称已完成手机产品布局。

ROUND 2
Seen in one second: 队伍与申请两块信息明确，主窗外的荔枝条提供后台状态入口。
Idea (one sentence): 浏览时能比较队伍，关窗后仍能用荔枝悬浮窗掌握申请与招募。
Live thing: 新申请事件同时更新招募列表、悬浮计数与提示音；设置可以立即试听、锁定和缩放。
Layout words by section: navigation=bar / results=list / applications=rail / raid-tooltip=overview+roster / floating=compact+expand / settings=aligned-rows。
Scores: design 6.5 · usability 6 · creativity 7 · content 8 → overall 6.0（上限后）
Caps applied: 营销页检查仍有 5 FAIL、2 WARN；不声称该量表通过。没有新增营销图片或视频，也未为凑动效数量让列表持续移动。
Top three problems (most visible first), each with the screenshot it shows in and the fix:
1. `after/mobile-fold.jpg` 中检查器截图裁切了缩放窗口；另用原浏览器 390 × 844 检查，窗口边界为 x=16..374，见 `after/mobile-preview-cua.png`。实际预览能完整缩放，但文字过小，仍只适合桌面评审。
2. `preview-raid-30.png`：30 人名单采用紧凑字号，需在未来客户端实际 UI 缩放和字体下再评估；网页当前全 30 人与全部笔记理由均可见，未截断名单。
3. `after/desktop-fold.jpg`：空申请区留白随业务状态变化；保留它的固定位置以免浏览过程跳动，不填宣传内容。主窗口作为浮层保留阴影；静态内容仍以明度与留白分区。

14 项观察摘要：桌面焦点与三列分区成立；主边缘对齐一致；概要与成员有明确间距；荔枝红用于选择和动作；封面均为方形；列表重复是业务内容所需；全窗口在手机上缩小而非响应式重排；桌面内容量足够；原生回应入口已纠正；浮窗在右侧与顶部会改变展开方向。品牌能辨认，但交互仍属于成熟组队工具范式，因此未给创造性高分。

## 检查结果与保留项

- `before/report.json`：5 FAIL、3 WARN。`after/report.json`：5 FAIL、2 WARN。
- FAIL：主窗阴影、重复结果行被判为图标卡片、无大幅图片、标题不符合营销页焦点比例、开场运动元素不足 8 个。保留原因分别是游戏浮层、完整业务列表、游戏信息密度、现有标题层级，以及只在真实动作时播放动画。
- WARN：无视频；两处辅助文字低于 13px。原型的提示说明维持辅助层级，游戏内可读性尚未验证。
- 源码 lint 的旧样式命中与业务标识（例如 `delve`、倒计时 `padStart`）不能视为展示文案问题；没有通过删除合法业务字段来消除命中。
- 当前新增素材是四段原创合成 WAV，无新外部照片、视频或素材来源。Logo 沿用原项目素材；21 枚图标沿用既有 imagegen 产物，原提示词在 `assets/icons/prompts.json`。玩家、活动、进度、评分与招募内容均为演示样例，正式接入使用游戏数据。

## 本轮实际交互验证

- 团本 Shift 展开：完整 30 名成员，提示内容高度与可见高度相同，无截断。
- 独立邀请示意接受后更新申请状态，右栏无重复接受／拒绝入口。
- 轻响、清铃、双音、木敲均成功解码并推进播放，无媒体错误。
- 关主窗后模拟新申请，计数增加并播放短音；关闭声音后计数继续更新且不重播。
- 浮窗入口能重新打开对应页面，拖动、锁定、50% 与 150% 缩放、重置位置、隐藏与右侧／顶部展开均已检查。

这些结果只适用于网页原型，不构成游戏内 API、音量控制或性能验收。
