# 交付：cc/tianqi-subpage-bg

- 车道／工作者：天启篇标题子页底图／cc（v0.01 查标题线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-12 【cc·未经审查】天启篇标题的子页不再露出原版底图（dev.待定）

- 起因：Kyo 11-12 转来玩家安卓截图，说 v0.01 没带天启篇标题。查下来 v0.01 三平台包都带了（拆包看素材都在，Mac 包实跑出新标题）；截图是「游戏设置 → 调整按键位置」页。标题之外的子页（设置、调按键位置、读档、成就）会清掉新标题层，露出 entry.gd 垫在最底下的原版 PlayAgain 底图和粒子，看着像旧标题。
- 改法：`entry.gd` 的 `_build_background` 在用新标题（`XTianqiTitle.available()`）时只垫天启篇底图 `content/title/bg.png`（铺满、保持比例），不放原版 login 底图和粒子。回退：`XTianqiTitle.ENABLED = false` 整套回原版标题和原版底图。
- 测试：`xiyou_tianqi_title_flow` 加 `subpage_bg_is_tianqi`（39/39）；`xiyou_tianqi_title` 40/40、`xiyou_entry_release` 16/16、`xiyou_save_page` 42/42、`xiyou_input_handled` 10/10、`xiyou_platform` 146/146（本机单跑）。没在安卓真机上看。
- 玩家可见：设置、调整按键位置、读档等页面的背景换成天启篇标题底图，不再出现旧的 PlayAgain 画面。

## 交接板

- 下一步：无新增
- 用户试玩说明：进「游戏设置 → 调整按键位置」，背景应是天启篇底图
- 需要用户决定：要不要把这条做成补丁推给 v0.01 玩家（天启篇相关推送等 Kyo 单独点名）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：发行冒烟只检查进没进标题场景，可以加一项「子页底图是不是新图」的截图比对（收益小，归工具车道，不急）

## 本分支提交

- 见 git log main..cc/tianqi-subpage-bg
