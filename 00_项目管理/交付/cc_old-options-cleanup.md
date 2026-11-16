# 交付：cc/old-options-cleanup

- 车道／工作者：T051 旧设置页列表清理／cc（Sonnet 5.5＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·未经审查】旧设置页清理：天启篇防骗三行改页底提示（dev.待定）

依据 T027 拆卡建议 #19、#20。先查了旧设置页（`options_scene.gd`）在各路径会不会露出这几项：

| 路径 | 防骗三行（wxxonoff／wxlonoff／wxtonoff） | 遇怪三开关（Boss／BOSS／boss） |
| --- | --- | --- |
| 西游档（旧列表是唯一设置页） | 露出（原版 v0.62.12 的 33 行之一）→ **不动**，`xy_ads_still_listed` 与行序 1:1 都保留 | 不露：`XEncounterTarget.ENABLED` 默认 true，「只遇稀有」换成「定向遇怪」，另两行去掉 |
| 天启篇、皮肤开（新界面） | 不露：`skin_options_page.gd` 的 HIDDEN_SYMBOLS 已藏 | 同上，不露 |
| 天启篇、皮肤关（界面风格选了原版） | 露出 → **本次改**：旧列表去掉三行，页底一行静态提示 | 同上，不露 |

- 防骗三行：`XUiSkin.selectable()`（天启篇存档，含皮肤关）时从旧列表滤掉，`_paint` 在窗口底部（12 行之下的 28 px）画一行小字提示 `XOptionsScene.ADS_TIP`；西游档一字不改。这三项本来就不存配置（状态空白），没有旧值要兼容。
- 遇怪三开关：**一字不改**（项目经理cc 拍板）。三行只在 `XEncounterTarget.ENABLED=false`（O-384 回退开关）时露出；`xiyou_options_basic／options_misc` 用它对照原版行序，`map_scene.gd` 仍读旧值，所以不能删。
- 提示文字（小A 文字审）：`本游戏免费，勿在闲鱼购买；总群 906327865`（由原版三行「此游戏为免费游戏！」「总群请加906327865！」「不要在闲鱼买到这个版本！」合并）。
- 专项：`xiyou_ui_skin_5c` 增加 `xy_ads_all_three`、`xy_no_ads_tip`（西游档三行仍在、无提示）和新场景 `tq_old_no_skin／tq_old_ads_gone／tq_old_ads_tip／tq_old_other_rows_kept`（天启篇皮肤关：三行不在、提示在、其他行保留）；`xiyou_options_basic`、`xiyou_options_misc`、`xiyou_ui_skin_5c` 通过（85／148／112）。
- 玩家可见：天启篇里把「界面风格」切回原版时，设置页不再有三行没用的宣传项，页底多一行小字提示。

## 交接板

- 下一步：提示文字交小A 文字审；遇怪三开关一直留着是 O-384 回退，无需拆卡。
- 用户试玩说明：天启篇设置页选「界面风格：原版」时看页底提示。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 git log
