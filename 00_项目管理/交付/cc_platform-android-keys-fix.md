# 交付单 cc/platform-android-keys-fix（本机验证通过，Actions 冒烟全绿，可合并）

状态：可合并（标题与本轮记录写明 Actions 冒烟全绿；总装三十九补状态行。O-待定 草稿是正文写法，总装合并后手补号）

## 接续（额度用完，WIP 停手）
- 根因（已定）：dev.410 并入的开场图（XSplashScreen，要放约 10 秒以上并吃掉按键）让冒烟第一下键落在开场图上，标题没接键、新游戏没开；地图没进，所以切后台钩子（挂在地图上）也没打 PAUSE_SAVE。证据：run 42678614104 的 android-run-report logcat（SMOKE_KEY 在启动后约 1.7 秒）。
- 已改（未验证）：`modes/xiyou/ui/splash_screen.gd` 加 `SKIP_FOR_SMOKE`（默认 true，回退＝false）和 `is_smoke_run()`，命令行带 `--smoke-keys=` 时 `wanted()` 返回 false；`tests/xiyou_splash_autosave.gd` 加 4 条断言。
- 没做：工作树补齐被中断（`新建工作树.sh --补齐` 没跑完，需重跑）；`语法检查.py`、专项 `xiyou_splash_autosave`、`xiyou_key_smoke` 没跑；云端模拟器冒烟没跑；优化登记草稿（O-待定：安卓冒烟不放开场图，可回退开关 SKIP_FOR_SMOKE，不是原版 bug）没写。
- 下一步：补齐→语法检查→专项→推分支→云端「安卓 验收」模拟器冒烟，看 android_keys_title_*×3 与 android_pause_hook_fires 转绿；写交付单正文。

## 本轮（接续）
- 已合 main；语法检查通过；专项 xiyou_splash_autosave、xiyou_key_smoke 通过。补齐里的事件状态探针按总装要求中途停掉（本改动用不到），generated 事件状态产物不完整，不要据此做事件相关测试。
- 待做：推分支，Actions「安卓 验收」模拟器冒烟看 android_keys_title_*×3、android_pause_hook_fires 转绿，结果补在这里。
- 优化登记草稿（O-待定，由总装合并时登记）：安卓按键冒烟不放开场图。开关 `XSplashScreen.SKIP_FOR_SMOKE`（默认 true，false＝回退）；不是原版 bug，只影响命令行带 `--smoke-keys=` 的冒烟运行，玩家正常启动不变。
- 待交叉核查：splash_screen.gd（甲档，开场图判定）。
- Actions 结果：导出冒烟 run 42706664517（platforms=android，头 9f725f223）全绿；android_keys_title_space/j/enter_new_game、android_keys_title_cancel_then_map_keys 与 android_pause_hook_fires 全部「过」。
- 可合并

## 变更记录草稿

## 2026-11-09 【cc·平台·未经审查】安卓按键冒烟不放开场图（dev.待定，O-待定）

- 根因：dev.410 并入的开场图（XSplashScreen）要放约 10 秒并吃掉按键，冒烟第一下键落在开场图上，标题没接键、没进地图，切后台钩子也没打。
- 改动：`modes/xiyou/ui/splash_screen.gd` 加 `SKIP_FOR_SMOKE`（默认 true，false＝回退）与 `is_smoke_run()`，命令行带 `--smoke-keys=` 时不放开场图；`tests/xiyou_splash_autosave.gd` 加断言。
- 验证：语法检查、专项 xiyou_splash_autosave、xiyou_key_smoke 过；Actions「安卓 验收」模拟器冒烟 android_keys_title_*×3、android_keys_title_cancel_then_map_keys、android_pause_hook_fires 全过。
- 玩家可见：无（只影响带 `--smoke-keys=` 的冒烟运行）。

## 优化登记（行草稿，O 号由总装分配，表格行格式同 `优化登记.md`）

| O-待定 | `modes/xiyou/ui/splash_screen.gd` `XSplashScreen.SKIP_FOR_SMOKE`（`wanted`／`is_smoke_run`） | 开场图每次启动都放，约 10 秒，期间吃掉按键 | 命令行带 `--smoke-keys=` 的冒烟运行不放开场图 | 自动冒烟第一下键被开场图吃掉，标题与切后台钩子测不到；玩家正常启动不变 | `SKIP_FOR_SMOKE = false` | cc（平台） | 待用户决定 |
