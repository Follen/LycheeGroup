# LycheeFont / 荔枝字体

插件按界面语言选择独立默认字体文件，仅应用于本插件主窗、浮窗和借用中的输入框。

| 界面语言 | 文件 | 字体内容 |
| --- | --- | --- |
| 简体中文 | `LycheeFont-zhCN.ttf` | 完整原始微软雅黑 Bold，中文、数字、字母和标点全部保留原样，不合入 Inter |
| English | `LycheeFont-enUS.ttf` | Inter Regular；仅为英文界面里的中文玩家名和队伍标题补充 Inter 未覆盖的中文字形 |

设置中显示“荔枝字体 / LycheeFont”。语言选择重载后生效，默认字体随之切换；用户自行选择的其他字体保持不变。

## 来源与授权

中文来源为本机 `World of Warcraft/_retail_/Fonts/ARKai_T.ttf`，元数据为 Microsoft YaHei Bold / 微软雅黑 Bold。这是本机安装的字体替换文件，不表示所有魔兽世界客户端的原版字体都是微软雅黑。

| 来源 | 输入文件 SHA-256 |
| --- | --- |
| 本机 `Fonts/ARKai_T.ttf`，Microsoft YaHei Bold | `b5abe5458e1f3d32a60a71ddd289b3a64eeab311d2f6a3c0afe3f025d4ad82c2` |
| [Inter 4.1](https://rsms.me/inter/) | `4989b125924991b90d05b2d16e0e388c48f7d5bb8b30539bbf9c755278d0ccaf` |

项目持有人于 2026-10-19 明确确认，已取得中文字体的修改及随插件分发授权。保留中文源文件的版权、许可原文和嵌入限制标志，见 [NOTICE-ChineseFont.txt](NOTICE-ChineseFont.txt)；Inter 使用 [SIL Open Font License 1.1](LICENSE-Inter.txt)。打包不转移上游版权，也不表示上游作者认可或支持本插件。

## 构建

输入为上述本机中文 TTF，以及固定版本的 [InterVariable.ttf](https://raw.githubusercontent.com/rsms/inter/v4.1/docs/font-files/InterVariable.ttf)。在仓库根目录使用 Python 和 fontTools 4.62.1：

```powershell
python tools/BuildLycheeFont.py --chinese <ARKai_T.ttf路径> --inter <InterVariable.ttf路径> --output-directory addon/LycheeGroup/Media/Fonts
```

中文文件直接复制原文件，字形、字重、字宽、字号度量和 hinting 均不改动。英文文件的 Inter 固定字重 400、光学尺寸 14，保持完整拉丁、希腊及西里尔字符覆盖，并补充原中文字体中 Inter 未包含的字符；此处理只用于英文版本。英文文件共 31,251 个码点、31,393 个字形，不按当前界面文字裁剪玩家姓名字符。

| 产物 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `LycheeFont-zhCN.ttf` | 14,116,948 | `b5abe5458e1f3d32a60a71ddd289b3a64eeab311d2f6a3c0afe3f025d4ad82c2` |
| `LycheeFont-enUS.ttf` | 8,663,532 | `9d327cbafd239af3e014d467a6e1daf3f6c04ae74e062ff8593f39480b6b9c27` |

正在运行的客户端会缓存字体文件；新增或替换字体文件后需完全退出游戏再启动，单独重载界面未能刷新本次验证环境中的字体缓存。
