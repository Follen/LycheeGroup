# 玩家记录理由框裁切验证

理由框布局位于 `addon/LycheeGroup_UI/Notes.lua`。最小高度应容纳当前一行文字和上下内边距；编辑区压缩字段间距后仍不足时，由页面最小高度约束保护日期、反馈与底部操作。窗口约束不改写玩家保存的尺寸偏好。

## 离线检查

```powershell
lua tests/test_notes_layout.lua
lua tests/runner.lua resize
```

布局专项已纳入 `tests/run_layout_checks.lua`，覆盖中英文、70%／100%／130% 字号、最小窗口、添加与编辑，以及两行反馈。断言同时检查理由框实际可见区域能容纳整行文字、日期与反馈顺序、底部按钮间距。`resize` 检查未保存理由在调整尺寸后保留。

## 实机读数

打开一条玩家记录后执行；隐藏编辑区后也可读取最后一次布局，但 `visible=false` 不表示当前屏幕正在展示该布局。

```powershell
lycheedev live execute --project <项目> --session <CON> --file tests/live_note_reason.lua --request <唯一检查名> --budget-seconds 10 --wait-seconds 30 --policy observation --format json
```

脚本只读取尺寸、字号和滚动位置，不修改记录、输入文本或设置。日志记录 `field`、`viewport`、`line` 和 `scroll`；可见区域小于一行时断言失败。检查结束后按 lycheedev 流程关闭连接。实机尺寸断言不替代中文输入、光标移动及滚轮操作的人工检查。

2026-10-30，客户端 12.1.5.70575 修复前保留的编辑区几何为：窗口高 760、编辑区高 508、理由框高 32、文字视口高 12、行高 24、字号 17、滚动偏移 5.25；`note-reason-before-3` 的断言失败，读取时编辑区已隐藏。

候选同步并重载后，通过公开 `LycheeGroup:Open("notes")` 打开已有记录，再运行同一尺寸断言；`note-reason-after-1` 在可见状态通过。窗口与编辑区高度保持 760／508，理由框高 44、文字视口高 24、行高 24、滚动偏移 0。随后读取该角色窗口截图，确认同一条记录的理由字形完整，日期与操作按钮没有重叠。未执行输入、保存或删除记录。候选 `Notes.lua` SHA-256 为 `e00c857e3665ef299fcf0dfc1499879614f56071e3d66e8d0e642b4e26900192`；实机记录在项目 `D:/Code/wow/addons/LycheeGroup` 的连接 `CON-fc71b30d6f0e0ce98802b517f3145531` 中保留。

本轮完整 runner 58,503 项断言、布局入口 17 个脚本（笔记专项 358 项）、架构检查 6,609 项均通过。未重新测量整插件 CPU 或内存。
