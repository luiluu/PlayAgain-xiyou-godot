# 交付：cc/version-v001

- 车道／工作者：总装／cc（总装）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·总装·未经审查】整包定版 v0.01：自动更新新旧只比开发编号，版本号显示读发行版本名（dev.待定）

- Kyo 11-11 定新整包为 v0.01。原来「有没有新版」拿清单的版本号文字和「0.<当前编号>」按段比，0.01 会被判成比 0.462 旧，清单永远不提示。
- 改成新旧只比开发编号（`XUpdateCheck.evaluate`、`XUpdateClient.has_update`），版本号只给人看。
- 版本号：build_info 的 `releaseVersion` 有值时（出整包时填 "0.01"），整包显示 0.01，之后的补丁显示 0.01.<比整包多几号>；没有时照旧 0.<编号>（`XUpdateCheck.release_name／release_base`，`XUpdateClient.init_versions／release_version`）。导出给系统看的 Mac／Windows 版本号、安卓 versionCode 不变。
- 右下角版本号（`XVersionLabel`）：发行构建有发行版本名时显示 v0.01（补丁 v0.01.N），开发版照旧显示开发编号。
- 专项 `xiyou_update_check` 加 6 项（显示 0.01／0.01.5／旧号、按编号判新旧，清单号更小不提示）。
- 玩家可见：版本号显示成 v0.01。

## 交接板

- 下一步：出整包时把 `content/build_info.json` 的 `releaseVersion` 填 "0.01" 再导出（只在那一版提交，之后补丁沿用）。
- 用户试玩说明：无
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 git log
