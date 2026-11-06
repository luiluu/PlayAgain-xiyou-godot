# 交付：cc/platform-size1

- 车道／工作者：平台 DH／cc（第十四批 DH 单）
- 状态：进行中

## 变更记录草稿

## 2026-11-06 【cc·平台·未经审查】包体减三成：贴图 WebP 无损最高档、BGM 降到 96k；安卓商店页存档键修好（dev.待定）

- 结论先说：三平台包都小约 150 MB（约 −30%），画面逐像素不变。改前→改后（本机同一提交导出）：macOS 发行 zip 501.5→351.7 MB，Windows 发行 exe＋pck 630.8→479.0 MB，安卓验收 apk 482.1→331.0 MB。
- O-210 采用（Kyo 11-06「用」）：`project.godot` 加 `textures/webp_compression/compression_method=6`、`lossless_compression_factor=100.0`。贴图 ctex 321.5→199.7 MB（安卓包里 png 部分 157.0 MB、jpg 帧 33.5 MB）。`贴图无损核对.gd` 3068 张里 3063 张与源图逐像素相同，没比上的 5 张和 CB 报告里现状就有的 5 张是同一批（3 张读不出、tgw_A3／A4 比对口径），不是压坏。
  - **注意**：Godot 只在源文件或 .import 变了才重导，改工程设置不会触发，已有的 `.godot/imported` 里还是默认档的大 ctex。要让包变小，得删掉 `.godot/imported/*.ctex` 再 `godot --import` 一次（本机约 38 分钟）；新工作树 `--补齐` 从主工作区带缓存，所以 main 合并后要在主工作区做一次，出发行包前也要确认做过。
- 音频（Kyo「合理调整，目前音乐不太重要」，总装定 96k）：转换器 `xiyou_export.py` 新增 `audio_96k`，平均码率高于 112k 的 BGM（v0.28 切片 33 首，最高 465k）用 oggenc（libvorbis）ABR 96k 重编码，采样率不变，LOOPSTART／LOOPLENGTH 等注释原样带上；BGM 124.1→74.4 MB，安卓包里音频 125.6→76.7 MB。BGS／ME 本来低于 96k、SE 短音不动；96～112k 的不动（省不了多少，再损一次音质）。ffmpeg 解码加 bitexact、oggenc 固定流序号：删掉 33 个产物重转，33/33 与上次逐字节相同；第二次同步走缓存（written 0）。重编码的产物不沿用源文件修改时间，否则 Godot 不重导（第一版就踩了这个，包里还是旧码率）。manifest 新增 `audio96k` 字段。回退：`XIYOU_AUDIO_96K=0` 重跑同步＝原样复制。本机要 `brew install vorbis-tools`（已装）；云端没有 oggenc 时沿用上次产物，对不上就原样复制并记 issue `audioNeedsOggenc`。
- 安卓商店页存档键按了没反应：商店、存档页、仓库、图鉴等是事件打开、挂在地图下的页面（原版各是 SceneManager.push 出去的独立场景，Mehmet_GhostButtons 不在那里建存档键）。O-211 只排除了战斗和菜单子页面，漏了这些；而事件进行中一键存档热键（~→公共事件 428）本来就不响应，于是键在、按了没反应。`XMapScene` 把 21 处事件页统一走 `_add_scene_page` 记下，`touch_save_visible` 在有页面开着时返回 false。回退 `XMapScene.SCENE_PAGE_HIDES_SAVE = false`。测试 `xiyou_platform` 加 5 项（真 XMapScene：无页面显示、开页面隐藏且触屏点不到、回退支显示、关页面后恢复）。
- 安卓验收包（调试签名、arm64-v8a）：`03_再刷重制_Godot/01_Godot工程/builds/android_验收/再刷重制_验收_size1.apk`（331 MB，提交 6451130d），导出冒烟通过（apksigner／aapt2，包内 xiyou_mac_export 12/12、xiyou_flow 49/49）。真机由 Kyo 装：看商店页右上没有存档键、地图和主菜单有且能存，听一下 BGM 有没有明显变差。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 事件打开的独立页面（`XMapScene._add_scene_page`／`scene_page_open`，商店、存档页、仓库、图鉴等 21 处）时的触屏存档键 | Mehmet_GhostButtons 只在 Scene_Map／Scene_Menu 建存档键，Scene_Shop 等 push 出去的场景都没有 | 这些页面开着时存档键不显示、不吃触摸（O-211 只排除了战斗与菜单子页面，漏了事件开的页面；事件进行中一键存档热键本来不响应，于是安卓商店页键在、按了没反应） | Kyo 11-06 安卓真机：商店页存档键按了没反应 | `XMapScene.SCENE_PAGE_HIDES_SAVE = false` 回到 O-211 原样 | cc（DH） | 已做，待审查 |
| O-待定 | 转换器 `xiyou_export.py` 的 `audio_96k`（BGM 素材） | 原版 BGM 照原码率放（最高 465k） | 平均码率高于 112k 的 BGM（v0.28 切片 33 首）用 oggenc 重编码到 96k，采样率与 LOOPSTART 等注释不变；三平台包体约 −50 MB（BGM 124.1→74.4 MB）；BGS／ME 本来低于 96k、SE 不动 | Kyo 11-06「合理调整，目前音乐不太重要」，总装定 96k | 环境变量 `XIYOU_AUDIO_96K=0`（或 `AUDIO_96K = False`）后重跑同步＝原样复制 | cc（DH） | 已做，待审查 |

（O-210 已在优化登记原行改成「已采用（Kyo 11-06）」，执行者加 DH。）

## 验证

- `事件空绿扫描.py --check`：空绿 55 例，均在基线内、都写明走不到理由。
- `选测.py main --list`：改了 project.godot（判整轮），所以整轮放云端：`云端选测.py run --full`（提交 ac4257c5，437 场景 15 片）——结果见下。6451130d 只改了转换器写文件时的修改时间一行，产物字节与 ac4257c5 那份快照相同。
- 本机：`xiyou_platform` 通过；`工具回归.py` 全过；`语法检查.py` 0 问题；`贴图无损核对.gd` 见上；安卓导出冒烟两次都通过（改前改后各一次）。

## 交接板

- 下一步：main 合并后在主工作区删 `.godot/imported/*.ctex` 重导一次（约 38 分钟），O-210 才在之后的包里生效；出发行包前确认。
- 用户试玩说明：安卓商店页（及存档页、仓库、图鉴等事件页面）不再显示存档键；包小约 150 MB；BGM 码率高的 33 首降到 96k。
- 需要用户决定：无（真机验收由 Kyo 装包看）。

## 进度账

- 无（平台扩展账，交总装按审查口径记）

## 可优化（流程／工具／效率）

- 建议：云端选测 prepare 的 `godot --import` 超时 1500 秒；Actions 缓存整个没命中、要从零导入时，WebP 最高档全量导入可能超过 25 分钟（本机 8 核约 38 分钟）。缓存有回退键（ws-v1-），平时只重导改过的文件，问题不大；建议哪吒把超时放宽或给首次导入单独留时间（归工具车道）。
- 建议：转换器里 `as_png` 把 JPEG／WebP 转成真 PNG 时也沿用源文件修改时间，同样可能让 Godot 不重导（目前只 3 张，源不变就无影响）；可照音频这次的写法改（归 A 车道）。

## 本分支提交

- ac4257c5 商店等事件页隐藏存档键、BGM 96k 重编码、O-210 WebP 无损最高档
- 6451130d 重编码音频不沿用源文件修改时间
