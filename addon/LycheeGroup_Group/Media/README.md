# 申请提醒音频

`new-applicant-zhCN-v2.ogg`：用户于 2026-10-26 提供的替换语音，原文件名为 `MiniMax_2026-10-26_14_05_14_温暖少女_no-watermark.wav`。

格式为 Ogg Vorbis，保留原始 32 kHz 单声道与完整时长 1.834406 秒。使用质量档位 3，构建时降低 1.5 dB 为编码峰值留余量，不裁剪、不升采样，移除源文件元数据。文件大小为 18,561 字节，原 WAV 为 119,504 字节。全文件解码检查通过；成品平均音量 -8.8 dBFS、峰值 -0.8 dBFS，平均音量比前一版 OGG（-21.4 dBFS）提高约 12.6 dB。游戏全局声音设置不变。

替换素材同时改用新路径，重载后播放请求明确指向新文件。2026-10-26 已在游戏内记录到该文件通过 Dialog 声道成功播放；本次调整提醒规则后的验收状态见 [声音验证记录](../../../tests/applicant_alerts.md)。

转换命令（在仓库根目录执行，替换输入路径）：

```powershell
ffmpeg -hide_banner -loglevel error -n -i '<输入 WAV 路径>' -map 0:a:0 -map_metadata -1 -vn -af 'volume=-1.5dB' -c:a libvorbis -q:a 3 -ar 32000 -ac 1 'addon/LycheeGroup_Group/Media/new-applicant-zhCN-v2.ogg'
```

仅将 OGG 纳入插件素材，不打包原始 WAV。素材通过播放接口按需使用，不列入 TOC，不为素材新增初始化、预加载或轮询任务。
