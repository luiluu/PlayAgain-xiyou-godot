# 交付：luiluu/t457

- 车道／工作者：小A（Neon＋high，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-24 【小A·未经审查】T457：修复发行包漏 XTianqiHallIntro、冒烟假绿与发布补丁 download_url 冲突（dev.待定）

- **问题**：dev.887 Mac 发行包实测进地图报 46～47 条 `SCRIPT ERROR`（`Identifier "XTianqiHallIntro" not declared`），根因是三个发行预设的 `exclude_filter` 包含 `modes/xiyou/ui/tianqi/*`，把已换空壳的 `modes/xiyou/ui/tianqi/tianqi_hall_intro.gd` 踢出 PCK，导致 `modes/xiyou/map/map_scene.gd:170-177` 编译失败；同时 `发行入口冒烟.py` 未检查脚本错误输出导致四路按键假绿，`发布补丁.py` 的 `--min-playable` 拒绝搭配 `--download-url none`，与「强制更新留空下载页、客户端改指 QQ 群」口径冲突。
- **改动**（按选项 A，不动 `map_scene.gd` 引用方式）：
  - 将 `modes/xiyou/ui/tianqi/tianqi_hall_intro.gd`（及 `.uid`）移至 `modes/xiyou/ui/tianqi_hall_intro.gd`，同步 `03_再刷重制_Godot/07_开发环境/测试发行空壳.py:311`；`modes/xiyou/ui/tianqi/*` 仍只排 5 张难度徽章 PNG（`01_xunchang.png`～`05_zhengdao.png`）。
  - `03_再刷重制_Godot/07_开发环境/发行入口冒烟.py` 新增 `SCRIPT_ERROR_RE` 与 `script_error_lines()`，`run_keys()` 与 `run_entry()` 输出含 `SCRIPT ERROR`／`Failed to load script`／`Parse Error` 必判失败；在 `03_再刷重制_Godot/07_开发环境/测试发行入口冒烟.py` 补 5 条回归单测（`ScriptErrorSmokeTests`）。
  - `03_再刷重制_Godot/07_开发环境/发布补丁.py` 允许 `--min-playable` 搭配 `--download-url none`（或空串 `""`）留空指 QQ 群，且已有 `min_playable` 且原清单留空 `download_url` 时后续不传 `--download-url` 保持留空不回填默认地址（新设 `--min-playable` 且未给 `--download-url` 仍默认补 `DEFAULT_DOWNLOAD_URL`）；在 `03_再刷重制_Godot/07_开发环境/测试发布补丁.py` 补 `test_min_playable_allows_empty_download_url_none`。
  - `03_再刷重制_Godot/07_开发环境/测试导出过滤.py` 增加发行预设防回归检查：三个发行预设的 `exclude_filter` 不得踢出任何空壳脚本、KEEP 脚本或非 `tests/` 工程 `.gd` 脚本。
- **全仓扫描结论（验收 4）**：
  - 三个发行预设（`macOS 发行`、`Windows 发行`、`安卓 发行`）的 `exclude_filter` 完全一致。
  - 80 个发行空壳脚本中，修复前仅 `XTianqiHallIntro`（`modes/xiyou/ui/tianqi/tianqi_hall_intro.gd`）被 `modes/xiyou/ui/tianqi/*` 踢出，移出后 80/80 全部保留在包内。
  - 2 个 KEEP 真脚本（`XRiftAlien`＝`modes/xiyou/core/rift_alien.gd`、`XTianqiTitle`＝`modes/xiyou/ui/tianqi_title.gd`）均未被排除（0 命中）。
  - 全仓非 `tests/`、`.godot/`、`builds/` 下的 `.gd` 脚本均未被排除（0 命中）；非空壳脚本 `preload("res://...")` 命中 `exclude_filter` 0 处；`.tscn`／`.tres` `ext_resource` 命中 `exclude_filter` 0 处。
- **验证**：
  - 静态与工具回归：`发行空壳.py check` 0（80 个脚本、774 个函数）；`测试发行空壳.py` 29/29 退出码 0；`测试导出过滤.py` 退出码 0；`测试发行入口冒烟.py` 26/26 退出码 0；`测试发布补丁.py` 22/22 退出码 0。
  - 专项 Godot 场景：`tests/xiyou_hall_intro.tscn` 67/67 退出码 0（`--audio-driver Dummy`）。
  - 云端选测：提交 `f59b1fb25e`（`ci/luiluu/t457`），6 个场景、2 片全部通过（最长一片 3.7 分钟），运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45420007444 。
  - dev.887 坏包反向验证（验收 2）：用修改后的 `发行入口冒烟.py --zip <dev887 mac zip> --keys` 实跑退出码 1（9/14），`release_no_script_errors` 与 4 路 `keys_*` 均 FAIL，检出 47 条脚本错误（首条 `SCRIPT ERROR: Parse Error: Identifier "XTianqiHallIntro" not declared in the current scope.`）。
  - Mac 发行包实导实跑（验收 5）：按空壳树＋封存＋资源加密流程用「macOS 发行」预设实导（558,849,772 字节；发行内容审计 0 问题；资源加密 scan 0 问题；PCK 含 `modes/xiyou/ui/tianqi_hall_intro.gdc`／`.gd.remap`，不含 `modes/xiyou/ui/tianqi/*`）；`发行入口冒烟.py --zip --keys` 14/14 通过（退出码 0）；解压实跑新开局进地图与老玩家明文旧档 `save_1.json` 读旧档进地图均 0 `SCRIPT ERROR`。
- **玩家可见**：无（修复发行包构建阻断与冒烟／发版工具链缺陷）

## 验收日志摘录

### 1. dev.887 坏包反向验证（证明修改后的冒烟会红）

```text
PASS app_bundle_name（再刷一把：天启篇.app）
PASS bundle_name（再刷一把：天启篇）
PASS bundle_version（0.887／887（应是 0.887／887））
PASS icon_from_app_icon（icon.icns）
PASS release_enters_title（res://modes/xiyou/entry.tscn）
PASS release_exit_clean（退出码 0）
FAIL release_no_script_errors（脚本错误 47 条（首条：SCRIPT ERROR: Parse Error: Identifier "XTianqiHallIntro" not declared in the current scope.））
PASS release_save_seal_active（XSaveSeal.active_now() 为真且封存自检通过）
PASS release_save_export_format_v2（kyo-remake-save-sealed-v2）
INFO startup_time（启动到标题 10.1 秒，基线 11.4 秒（macos））
FAIL keys_title_space_new_game（退出码 0，按完 5/5 步，最后在 res://modes/xiyou/map/map_scene.tscn，脚本错误 47 条（首条：SCRIPT ERROR: Parse Error: Identifier "XTianqiHallIntro" not declared in the current scope.））
FAIL keys_title_j_new_game（退出码 0，按完 5/5 步，最后在 res://modes/xiyou/map/map_scene.tscn，脚本错误 47 条（首条：SCRIPT ERROR: Parse Error: Identifier "XTianqiHallIntro" not declared in the current scope.））
FAIL keys_title_enter_new_game（退出码 0，按完 5/5 步，最后在 res://modes/xiyou/map/map_scene.tscn，脚本错误 47 条（首条：SCRIPT ERROR: Parse Error: Identifier "XTianqiHallIntro" not declared in the current scope.））
FAIL keys_title_cancel_then_map_keys（退出码 0，按完 17/17 步，最后在 res://modes/xiyou/map/map_scene.tscn，脚本错误 47 条（首条：SCRIPT ERROR: Parse Error: Identifier "XTianqiHallIntro" not declared in the current scope.））
PASS keys_no_new_crash_report（DiagnosticReports 没有新增）
结论：有失败（9/14）
EXIT_CODE=1
```

### 2. 修复后 Mac 发行包实导冒烟与新开局／读旧档进地图实跑（0 SCRIPT ERROR）

```text
PCK 内 tianqi_hall_intro 条目: ['modes/xiyou/ui/tianqi_hall_intro.gd.remap', 'modes/xiyou/ui/tianqi_hall_intro.gdc']
PCK 内 modes/xiyou/ui/tianqi/* 条目: []
发行内容审计问题数: 0
资源加密 scan 问题数: 0

PASS app_bundle_name（再刷一把：天启篇.app）
PASS bundle_name（再刷一把：天启篇）
PASS bundle_version（0.887／887（应是 0.887／887））
PASS icon_from_app_icon（icon.icns）
PASS release_enters_title（res://modes/xiyou/entry.tscn）
PASS release_exit_clean（退出码 0）
PASS release_no_script_errors（0 条）
PASS release_save_seal_active（XSaveSeal.active_now() 为真且封存自检通过）
PASS release_save_export_format_v2（kyo-remake-save-sealed-v2）
INFO startup_time（启动到标题 10.2 秒，基线 11.4 秒（macos））
PASS keys_title_space_new_game（退出码 0，按完 5/5 步，最后在 res://modes/xiyou/map/map_scene.tscn）
PASS keys_title_j_new_game（退出码 0，按完 5/5 步，最后在 res://modes/xiyou/map/map_scene.tscn）
PASS keys_title_enter_new_game（退出码 0，按完 5/5 步，最后在 res://modes/xiyou/map/map_scene.tscn）
PASS keys_title_cancel_then_map_keys（退出码 0，按完 17/17 步，最后在 res://modes/xiyou/map/map_scene.tscn）
PASS keys_no_new_crash_report（DiagnosticReports 没有新增）
结论：通过（14/14）

=== [实跑1：新开局进地图] rc=0, script_errors=0 ===
SMOKE_KEY=space scene=res://modes/xiyou/map/map_scene.tscn
SMOKE_KEY=space scene=res://modes/xiyou/map/map_scene.tscn
SMOKE_KEY=space scene=res://modes/xiyou/map/map_scene.tscn
SMOKE_KEY=down scene=res://modes/xiyou/map/map_scene.tscn
SMOKE_KEY=space scene=res://modes/xiyou/map/map_scene.tscn
SMOKE_KEY=wait:60 scene=res://modes/xiyou/map/map_scene.tscn
SMOKE_DONE scene=res://modes/xiyou/map/map_scene.tscn

=== [实跑2：读旧档进地图] rc=0, script_errors=0 ===
SMOKE_KEY=space scene=res://modes/xiyou/entry.tscn
SMOKE_KEY=wait:20 scene=res://modes/xiyou/entry.tscn
SMOKE_KEY=space scene=res://modes/xiyou/entry.tscn
SMOKE_KEY=wait:20 scene=res://modes/xiyou/entry.tscn
SMOKE_KEY=space scene=res://modes/xiyou/entry.tscn
SMOKE_KEY=wait:20 scene=res://modes/xiyou/entry.tscn
SMOKE_KEY=space scene=res://modes/xiyou/map/map_scene.tscn
SMOKE_KEY=wait:60 scene=res://modes/xiyou/map/map_scene.tscn
SMOKE_DONE scene=res://modes/xiyou/map/map_scene.tscn
XSaveSeal: 旧存档已补上签名：{"dir":"user://modes/xiyou","failed":[],"sealed":["save_1.json"]}
```

## 交接板

- 下一步：总装合并 `luiluu/t457` 后，在主工作区刷新一次 Godot 导入缓存（`godot --headless --audio-driver Dummy --path 03_再刷重制_Godot/01_Godot工程 --import`），再重跑三平台正式整包导出与 `--min-playable latest --download-url none` 候选清单生成。
- 用户试玩说明：无（工程内部发行修复，待总装重出正式整包后供玩家下载）。
- 需要用户决定：无

## 进度账

- 不涉及进度账百分比调整（发行阻断修复与发布／冒烟工具链补强）。

## 可优化（流程／工具／效率）

- 已做：在 `03_再刷重制_Godot/07_开发环境/测试导出过滤.py` 新增发行预设防回归检查，自动核对 3 个发行预设 `exclude_filter` 不得踢出任何空壳脚本、KEEP 脚本或非测试 `.gd` 脚本；同时在 `发行入口冒烟.py` 的 `run_entry()` 也补了 `release_no_script_errors`（与 `run_keys()` 同口径），回退方式为撤销对应检查行。

## 动了的共用函数和开关

无

## 本分支提交

- `f59b1fb25` T457：修复发行包漏 XTianqiHallIntro、冒烟脚本错漏检与发布补丁 download_url 冲突
