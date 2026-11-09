# 交付单 cc/platform-android-keys-fix（接续，不可合并）

## 接续（额度用完，WIP 停手）
- 根因（已定）：dev.410 并入的开场图（XSplashScreen，要放约 10 秒以上并吃掉按键）让冒烟第一下键落在开场图上，标题没接键、新游戏没开；地图没进，所以切后台钩子（挂在地图上）也没打 PAUSE_SAVE。证据：run 42678614104 的 android-run-report logcat（SMOKE_KEY 在启动后约 1.7 秒）。
- 已改（未验证）：`modes/xiyou/ui/splash_screen.gd` 加 `SKIP_FOR_SMOKE`（默认 true，回退＝false）和 `is_smoke_run()`，命令行带 `--smoke-keys=` 时 `wanted()` 返回 false；`tests/xiyou_splash_autosave.gd` 加 4 条断言。
- 没做：工作树补齐被中断（`新建工作树.sh --补齐` 没跑完，需重跑）；`语法检查.py`、专项 `xiyou_splash_autosave`、`xiyou_key_smoke` 没跑；云端模拟器冒烟没跑；优化登记草稿（O-待定：安卓冒烟不放开场图，可回退开关 SKIP_FOR_SMOKE，不是原版 bug）没写。
- 下一步：补齐→语法检查→专项→推分支→云端「安卓 验收」模拟器冒烟，看 android_keys_title_*×3 与 android_pause_hook_fires 转绿；写交付单正文。
