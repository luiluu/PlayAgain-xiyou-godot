# 交付：cc/platform-pack1

- 车道／工作者：平台（cc，项目线程「完成再刷西游Godot引擎重制」；DX 单）
- 状态：可合并
- 基于：main 2bd62833，导出前合到 main eb610ced（dev.383，带上 DT 切后台存档）。本单没改代码，只导包、量包体、冒烟、换 Kyo 的 Mac 包。

## 变更记录草稿

## 2026-11-06 【cc·平台·未经审查】WebP 最高档生效后导出三平台发行包：各小约 150 MB，冒烟全过；Kyo 的 Mac 包换成 dev.383（dev.待定）

- 结论先说：三个发行包都比 DH 量的改前小约 150 MB，跟 DH 的预估对得上。发行入口冒烟全过：Mac 10/10、Mac x86_64（Rosetta）10/10、Windows 9/9。安卓发行包签名和包信息检查没有问题，要 Kyo 装到真机上试。
- 先在工作树删掉 `.godot/imported/*.ctex`，整轮重导入（约 26 分钟，前面另有 5 分钟被补齐脚本掐掉，见「可优化」）。重导入后贴图 ctex 一共 199.7 MB，跟 DH 报告里最高档的 199.7 MB 一样，说明导出时用的是 WebP 最高档。

| 包 | DH 改前 | 本次（dev.383） | 差 |
| --- | --- | --- | --- |
| macOS 发行 zip | 501.5 MB | 351.7 MB | −149.8 MB |
| Windows 发行 exe＋pck | 630.8 MB | 479.0 MB（exe 109.3＋pck 369.8） | −151.8 MB |
| 安卓发行 apk | 475 MB（DH 按发行过滤、调试签名量的） | 322.1 MB | −153 MB |

- 冒烟：Mac 用 `发行入口冒烟.py --zip <包> --keys` 和 `--arch x86_64 --keys`：包名、图标、进西游标题、正常退出，四组按键（空格、J、回车开新游戏，取消再按一串地图键）都在地图上结束，没有新的崩溃报告。Windows 用 `--platform windows --keys`：exe 里的名字和 256 图标对，pck 用同名的 macOS 发行模板跑，入口和四组按键都过。Windows 没开虚拟机。
- 安卓：「安卓 发行」用发行模板导出（不可调试）。正式 keystore 没有，所以签名用的是本机 Godot 的调试 keystore（通过 `GODOT_ANDROID_KEYSTORE_RELEASE_*` 环境变量指过去，没改预设，也没写进任何文件）。`导出冒烟.py` 的 `android_layout(debug=False)` 检查：apksigner 校验、包名 `local.kyo.remake`、应用名「再刷一把：天启篇」、只有 arm64-v8a、权限只有 WAKE_LOCK、包里没有 tests/，都没问题。`versionName` 是 0.0.0、`versionCode` 是 1，预设里没填，上架前要定。
- Kyo 的 Mac 包：`~/Applications/再刷一把：天启篇.app` 原来是 dev.380，先压成 `05_发布/导出包/再刷一把：天启篇_dev380备份.zip`（没留 .app 备份），再换成这次的 dev.383 包（universal：x86_64＋arm64）。

## 包路径（主工作区，不进 Git）

- `03_再刷重制_Godot/05_发布/导出包/dev383_三平台发行/再刷一把_天启篇_mac.zip`
- `03_再刷重制_Godot/05_发布/导出包/dev383_三平台发行/windows/再刷一把_天启篇.exe`、`再刷一把_天启篇.pck`（两个放同一个文件夹）
- `03_再刷重制_Godot/05_发布/导出包/dev383_三平台发行/再刷一把_天启篇_安卓.apk` ← 给 Kyo 装真机，按 DP 交付单「Kyo 真机测试清单」1～8 步，加上 DT 的 9～12 步（切后台自动存档）
- 本工作树 `01_Godot工程/builds/pack1/` 里另有一份同样的包，以及导出日志

## 交接板

- 下一步：Kyo 装安卓包，按 DP＋DT 清单试；Windows 包等有 Windows 机器时试。
- 用户试玩说明：Mac 上的「再刷一把：天启篇」已经换成 dev.383（包小了约 150 MB，画面不变）；安卓包在上面路径。
- 需要用户决定：安卓上架前要有正式 keystore 和版本号（现在是调试签名、0.0.0）。以前就是这样，这次只是写出来。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：`新建工作树.sh --补齐` 里的 `godot --import` 有 `alarm 300`，删掉 ctex 后整轮重导入要 30 多分钟，会被它在 5 分钟时掐断（这次 3065 张只导了 640 张就退出了，报「导入失败」）。我改成单独用 `长任务.py start` 跑 `占槽.py -- godot --import`。建议给 `--补齐` 加一个 `--long-import`（不设上限，或者上限放到 60 分钟），或者在失败提示里写明「整轮重导入请单独跑」。归 tools 车道。
- 建议：`发行入口冒烟.py` 没有安卓分支，这次是手动调 `导出冒烟.py` 的 `android_layout(debug=False)` 查的。可以给它加 `--platform android`，用调试 keystore 顶替发行签名，只做包结构检查。归平台车道。

## 验证

- 发行入口冒烟：Mac 10/10、Mac x86_64 10/10、Windows 9/9（日志在临时目录，结论见上）。
- 安卓发行包：android_layout 没有问题；aapt2 看应用名对，apksigner 看签名证书是 Android Debug。
- 没跑 Godot 测试：本单没改代码，合的 main 是总装云端整轮跑过的 eb610ced。

## 本分支提交

- 快进到 main eb610ced（带进 DT）
- 35a1f05c WIP：重导入完成（空提交）
- 交付单 cc_platform-pack1（本提交）
