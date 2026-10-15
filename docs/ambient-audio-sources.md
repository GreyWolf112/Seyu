# 自然录音替换（2026-10-15）

用户反馈旧版三个滤波噪声音源听感相近，本次完全替换其波形，不再使用随机噪声合成。

| 应用音源 | 录音与作者 | 原始来源 | 获取文件 |
| --- | --- | --- | --- |
| 雨声 | Spring Night Rain2 — ali-k | Freesound 156049；本次原页面返回404，来源及CC0声明保留于Noixer公开索引 | https://abetusk.github.io/noixer/assets/156049__ali-k__spring-night-rain2-evosmos-salonika-03-15-15-05.mp3 |
| 海浪 | Pacifica Ocean Waves with Birds — el_boss | https://freesound.org/people/el_boss/sounds/561502/ | https://cdn.freesound.org/previews/561/561502_9129912-hq.mp3 |
| 林间风 | ForestDay BW 66 — sonidosreales245 | https://freesound.org/people/sonidosreales245/sounds/517042/ | https://abetusk.github.io/noixer/assets/517042__sonidosreales245__forestday-bw-66.mp3 |

许可：CC0 1.0，https://creativecommons.org/publicdomain/zero/1.0/ 。海浪和森林原始页面均直接标明Creative Commons 0。雨声依据分发项目Noixer的全部声音CC0声明：https://abetusk.github.io/noixer/ ，文件与作者映射：https://abetusk.github.io/noixer/js/noixer.js 。未使用Moodist的混合许可音源。

海浪作者明确描述为浪冲刷岩石海岸，并带背景鸟声。森林原作者描述为树木、树叶、风和夏日野外录音，Noixer将该文件标为birds。没有加入虚构的“花瓣落地音”，也没有把脚踩落叶声伪装成自然落叶。

处理：macOS afconvert解码为44.1kHz单声道PCM16；脚本截取雨声15秒起、海浪5秒起、森林5秒起的62秒，旋转并以2秒等功率交叉淡化生成60秒循环；去直流、音量平衡及峰值限制。保留自然变化，不做强制恒定音量处理。

复现：按表下载三个MP3为rain.mp3、rocks.mp3、forest.mp3；用 `afconvert -f WAVE -d LEI16@44100 -c 1 input.mp3 output.wav` 解码到同一目录，再运行 `python3 scripts/generate-ambient.py <目录>`。输出哈希与处理参数见ambient-audio-build.json。

验证范围：来源、格式、时长、峰值、文件差异和播放器路由测试；尚未完成真机试听，不能以自动测试替代对音质、鸟鸣密度、雨声舒适度与循环接缝的人工听感验收。
