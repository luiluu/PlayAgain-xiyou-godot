# 交付：cc/platform-release1

- 车道／工作者：平台／cc（BW，总装派单）
- 状态：进行中

## 变更记录草稿

## 2026-11-06 【cc·平台·未经审查】导出冒烟上云、安卓包体积、Windows 窗口核对（dev.待定）

- **导出冒烟进 GitHub Actions**：新工作流 `.github/workflows/export-smoke.yml`「导出冒烟」，只手动触发（Run workflow 选 both／windows／android、是否留包；或推 `ci-export/<分支>` 试跑），普通推送不跑。ubuntu-latest 上导出「Windows 验收」「安卓 验收」，跑 `导出冒烟.py`：包结构、签名校验（apksigner verify，只是调试签名）、包名、版本号、图标、安卓包体积表，再用 Linux 调试模板载入包里的资源跑 `xiyou_mac_export`、`xiyou_flow`。报告附件留 3 天；包本身默认不留（仓库公开，附件谁都能下），勾 `upload_packages` 才留 3 天。Mac 包照旧本机。
- 新工具 `07_开发环境/云端导出.py`：`templates`（官方 tpz 按 `环境登记.json` 已登记的 SHA256＋SHA512 校验，只解出四个模板进缓存）、`presets`（把两个验收预设的模板路径改到缓存，只改 CI 检出副本）、`keystore`（每次现生成一次性调试 keystore，随机密码、3 天有效，写进 `GODOT_ANDROID_KEYSTORE_DEBUG_*`；不碰发行 keystore）、`gen-ref`（转换产物同云端选测）。`环境登记.json` 加 `cloudExport` 段：模板清单、预设对应、安卓 build-tools 35.0.1、platform android-35、JDK temurin 17、附件 3 天（与 Mac 本机的 build-tools 35.0.1 一致）。注意：改 `环境登记.json` 会让云端选测的 Godot 缓存键变一次，下次云端选测重下一次 Godot（约 1 分钟）。
- `导出冒烟.py`：`XIYOU_GODOT`／`XIYOU_SMOKE_RUNNER` 环境变量（云端用 Linux 版 godot 与 Linux 调试模板）；Windows 另读 exe 的 VERSIONINFO（FileVersion、ProductVersion）与图标组（RT_GROUP_ICON），与预设的 `application/file_version`／`product_version` 比；安卓另读 versionCode、versionName、application-icon，与预设的 `version/code`／`version/name`／`package/unique_name` 比；安卓报告加「包体积」表（压缩后各部分占比，`.godot/imported` 按源文件类型分）；报告写明包内检查用的是哪种模板。`测试导出冒烟.py` 10→13 项（PE 资源与版本、安卓版本／图标、体积表、云端导出的预设改写与登记段）。
- **安卓包体积**（本机导出「安卓 验收」482 MB；按「安卓 发行」过滤导出（调试签名量体积，未碰发行签名）475 MB）：
  - 压缩后：PNG 贴图 250.8 MB（54.8%）、OGG 音乐 125.6 MB（27.4%）、JPG 贴图 34.8 MB（7.6%）、原生库 24.7 MB（5.4%，调试版；发行版模板更小）、tests/ 5.8 MB（只在验收包，发行已排除）、游戏数据 JSON 4.5 MB、ICU 断行数据 2.7 MB、字体 2.0 MB。
  - 能安全剔除的：`modes/xiyou/generated/oracle_batch.json`、`oracle_pending.json`（参照批次的开发记账，运行时没人读），六个导出预设都加进 exclude_filter（发行三档与 Mac 发行档同一规则），`测试导出过滤.py` 加这两项。其余都是游戏要用的：tests/、参照数据、产物清单在发行档本来就排除；按名字扫 2906 张图、251 段音频，找不到没用到的素材（881 个「没被提到」的都是按编号拼名字的帧图，如 `UserSV_*_N`、`Weapons<N>`、`Command_N`）；开发工具不在工程里。
  - 再要变小只能动画质／音质（见「可优化」），要 Kyo 定。
  - 启动耗时：本机测不了（没有安卓真机连着）。真机上可用 `adb shell am start -W -n local.kyo.remake.verification/com.godot.game.GodotAppLauncher` 看 TotalTime。
- **Windows 按键与窗口**（核对，没改代码）：已与 Mac 一致——Alt+Enter（Mac 是 ⌘Enter）和 F11 切全屏，退出全屏回到按屏幕可用区 90% 的 16:9 窗口（`core/window_fit.gd`、`core/game_app.gd`）；窗口可拉伸，画面 canvas_items＋keep 比例缩放、留黑边；高 DPI：`allow_hidpi` 用默认（开），Windows 上取的可用区是物理像素，和 Mac Retina 一样按物理像素算窗口，不会被系统放大糊掉。已有测试：`xiyou_flow`、`xiyou_panels` 两种组合键都按一遍，`ui_smoke` 核窗口大小算法。没有差异，所以没加开关、没登 O 行。Windows 实机（不同缩放比、多显示器拖动）没测。

## 交接板

- 下一步：①合并后在 Actions 页手动跑一次「导出冒烟」（默认分支有了工作流就能 Run workflow）。②安卓真机量启动耗时（命令见上）。③Windows 实机看 125%／150%／200% 缩放和多显示器。
- 用户试玩说明：无（只是工具和导出设置）。
- 需要用户决定：要不要为了包小动画质／音质（见「可优化」）。

## 进度账

- 跨平台适配：Windows／安卓验收包可在云端导出冒烟；安卓包体积摸清。

## 可优化（流程／工具／效率）

- 已做：云端导出冒烟（回退：删 `.github/workflows/export-smoke.yml`、`云端导出.py`，`环境登记.json` 去掉 `cloudExport`）；发行档剔除参照批次两个文件（回退：从六个 exclude_filter 去掉 `modes/xiyou/generated/oracle_*.json`）。
- 建议（要 Kyo 定，归平台车道）：PNG／JPG 贴图改成有损 WebP（预计贴图 285 MB 能小一半以上，但画面有轻微失真，像素风小图不宜）；BGM 重编码到较低码率（音乐 126 MB，最大一首 7 MB，降码率会损音质）；安卓改用按需下载或分包（Godot 不原生支持，工作量大）。
- 建议：工作流里的 actions/cache@v4、upload-artifact@v4 有 Node 20 弃用提示，等出 v5 再统一升（云端选测也用着同版本）。

## 验证

（待写）

## 本分支提交

（待写）
