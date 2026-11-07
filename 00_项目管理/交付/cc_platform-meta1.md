# 交付：cc/platform-meta1

- 车道／工作者：平台（cc，项目线程「完成再刷西游Godot引擎重制」；EC 单）
- 状态：可合并
- 基于：main 02a1798c（tools81 合并）＋ **已并入 cc/platform-release3**（发行出包.py 在那边，EC 要改它）。合 main 时请先合 release3 再合本分支，或直接合本分支（会把 release3 一起带进来）。

## 变更记录草稿

## 2026-11-07 【cc·平台·未经审查】发行元数据：Mac／Windows 版本号、冒烟临时目录自清、出包只留最新一版、启动基线、「玩家可见」行（dev.待定）

- 玩家可见：Mac 和 Windows 版的「显示简介／属性」里能看到版本号了（跟安卓一样是 0.<开发编号>）
- `发行入口冒烟.py` 跑完删自己的 `xiyou_release_entry_*` 临时目录：通过就整个删；失败只留 .log（几十 KB）；被 SIGTERM／SIGHUP 结束也走收尾；启动时清掉上次被 SIGKILL 留下的（.pid 里的进程不在了，或没有 .pid 且超过 6 小时）。`--keep` 照旧全留。以前每次留 0.5～1 GB。
- Mac／Windows 版本号（O-待定·桌面版本号，开关 `XDesktopVersion.AUTO`，照安卓 O-216）：导出插件 `addons/xiyou_export` 在 Windows 导出时覆盖 file_version／product_version＝「0.<号>.0.0」，Mac 导出时覆盖 CFBundleShortVersionString＝「0.<号>」、CFBundleVersion＝「<号>」。冒烟新加 `bundle_version`、`exe_version` 两项（按当前工程 build_info 比）。正式版本号等正式发布再定（Kyo 11-06）。Mac 不做签名公证、不改 Bundle ID（Kyo 11-06）。
- `发行出包.py`：新包导出成功、冒烟全过后，删掉号更小的 `dev*_三平台发行` 目录和以前压的同名 .zip，只留最新一版（Kyo 11-06「直接删」，取代 release3 的「留两个、其余压 zip」）；导出或冒烟失败、`--no-smoke`、`--keep-old` 时不删；号更大的目录和 `_dev3xx备份` 不碰。`--dry-run` 列出会删什么。
- 发行入口启动基线：`发行入口冒烟.py` 量「起进程到打印 ENTRY_SCENE」的秒数，跟 `07_开发环境/发行入口启动基线.json`（按 macos／windows／android／macos_x86_64 各一份）比；慢一倍以上且多 2 秒打 `WARN startup_time 变慢`，只提示不算失败。`--update-baseline` 在全过时记基线。首份（本机 M1 Pro，dev.384）：macOS 11.4 秒、Windows 替身 8.7 秒、安卓替身 8.6 秒。`发行出包.py` 的冒烟.md 带上这一句。
- 「玩家可见」行：写进 [文件职责与记录](../规则/文件职责与记录.md)「变更记录格式」（可选一行）和交付单模板；`发行出包.py --notes-audit` 列出会进发行说明、但没写这一行的条目。公开发布前发行说明给 Kyo 过目。
- 验证：见交付单「验证」。

## 交接板

- 下一步：出包后旧版自动删；dev383_三平台发行 还在（自动模式拦了删除），要 Kyo 手动删一次。
- 用户试玩说明：Mac「显示简介」、Windows exe「属性→详细信息」能看到 0.<号> 版本号。
- 需要用户决定：
  - `XDesktopVersion.AUTO`（O-待定）采用与否，跟 O-216 一起等正式发布时定。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 变更记录 dev.380～383 三条玩家能感知的条目没写「玩家可见」行（`发行出包.py --notes-audit --since 378` 可见），下次出包前总装可在变更记录末尾追加一条补写；建议写法：
  - dev.380：修好发行版在标题按空格或 J 闪退
  - dev.381：安装包小了约三成；安卓商店页的存档键修好
  - dev.383：安卓切到后台会自动存一份，标题页可「继续」，不占手动存档位
- auto 模式下 `rm`／挪进废纸篓删 05_发布 里的旧包都被分类器拦（即使 Kyo 说过「直接删」）；`发行出包.py` 里自动删是脚本内 shutil，正常出包不受影响，但手动清理仍要 Kyo 跑。

## 验证

- 真导出三平台冒烟（本工作树，dev.384）：macOS 6/6（含 bundle_version 0.384／384）、Windows 5/5（含 exe_version 0.384.0.0）、安卓 7/7；三次都打印「临时目录已删」。
- 反向：拿 05_发布 里旧 dev384 包（没插件时导的）跑，`bundle_version`（1.0.0）和 `exe_version` 都 FAIL；失败时目录里只剩 .log 和 .pid。
- `测试发行入口冒烟.py` 15 项（新增清理 6 项、基线 3 项；SIGTERM 收尾那项把信号处理换回默认后会挂，确认咬得住）、`测试发行出包.py` 10 项、`工具回归.py` 全过。
- Godot：`xiyou_android_version`（19/19，新增 desktop_* 7 项含回退）、`xiyou_entry_release` 过；`语法检查.py` 602 个 .gd 0 问题；`事件空绿扫描.py --check` 55 例均在基线内。
- `选测.py main --list` 因 addons 改动给「整轮」；按车道规则没跑全量，改动只在导出插件（编辑器导出时才跑）和 07_开发环境 工具，游戏运行时代码没动。

## 本分支提交

- 并入 cc/platform-release3
- WIP：冒烟临时目录自清；桌面版本号；出包删旧版；--notes-audit；启动基线；优化登记 O-待定
- 交付单 cc_platform-meta1（本提交）

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | Mac／Windows 发行包版本号按开发编号（`addons/xiyou_export/desktop_version.gd` `XDesktopVersion.AUTO`；同一个导出插件） | 原版桌面包版本号由 NW.js 包定；重制的 Windows 预设一直是 0.0.0.0，Mac 预设没填（Info.plist 是 Godot 默认值），看不出是哪一版 | 导出时覆盖：Windows file_version／product_version＝「0.<号>.0.0」，Mac CFBundleShortVersionString＝「0.<号>」、CFBundleVersion＝「<号>」；读不出开发编号就用预设的值 | 跟安卓 O-216 同一套「0.<号>」，exe 属性和 Mac「显示简介」能看出版本；正式版本号等正式发布再定（Kyo 11-06）；测试 `xiyou_android_version` 的 desktop_* 项含回退，`发行入口冒烟.py` 查 bundle_version／exe_version | `XDesktopVersion.AUTO = false`（用 export_presets.cfg 的值） | cc（平台 EC） | 已做，待用户决定 |
