# 全部团本的增益与成员入口验证

范围见 [Product.md](../Product.md)：创建草稿与已发布招募均覆盖所有团队副本。职业覆盖、缺口筛选、成员 Tooltip、个人详情、WCL／Raider.IO 复制链接及笔记入口不按赛季限制。

## 离线回归

```powershell
lua tests/runner.lua group ui raid_buff_filter player_links
```

这些模块均纳入完整 runner。覆盖非当季和往期资料片团本、10／20／25／40 人小队范围、未发布草稿与已发布招募、增益职业多选、缺口补齐与活动失效清理。`player_links` 通过真实申请者悬停控件及当前队员名单进入个人详情，检查旧团本的两种链接内容和笔记入口，中英文均覆盖。预览仍禁止真实链接操作；不向 WCL 或 Raider.IO 请求成绩。

## 实机目录检查

先正常加载 Group 包（打开创建页即可），复用 lycheedev 连接执行：

```powershell
lycheedev live execute --project <项目> --session <CON> --file tests/live_all_raid_buffs.lua --request <唯一检查名> --budget-seconds 10 --wait-seconds 30 --policy observation --format json
```

脚本读取原生团本目录，对每个有效副本地图的活动调用正式增益模型，并检查团队名单、成员详情与链接入口的展示规则。使用空成员集合验证十三职业缺口，不读取或修改真实招募内容，不创建队伍，不发送申请，也不修改玩家配置。世界首领单独计数。结束后关闭连接，确认清理完成。

2026-10-31，客户端 12.1.5.70688，角色荔枝小月亮－燃烧之刃：原生分类 3 返回 152 个活动条目，其中 150 个为团本副本（不同难度分别计数），2 个为世界首领。修复前 `all-raid-before-1` 发现 141 个非当季条目缺少增益结果；同步候选并重载后，`all-raid-after-2` 检查 150 个团本条目全部通过，覆盖人数范围 10、20、25、30、40，非当季条目仍为 141 个。重载后通过 `LycheeGroup:Ensure("Group")` 加载业务包，再执行同一检查。

本轮完整 runner 58,519 项断言通过；随后补充旧团本 Tooltip／WCL／Raider.IO 控件场景，`player_links` 专项 989 项通过；架构检查 6,609 项通过。实机验证的是当前目录和正式模型，不代表逐项发布招募或对全部活动执行过鼠标交互。原始结果保留在项目 `D:/Code/wow/addons/LycheeGroup` 的连接 `CON-ef719204cb422a7c97ab524a13344d62` 中。
