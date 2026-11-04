# 交付：cc/nezha-gauge1

- 车道／工作者：C 规则／哪吒（cc，Sonnet）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·哪吒·未经审查】敌人血条显隐：<HIDE HP GAUGE> 的 546 个敌人不再出血条（dev.待定）

背景：敌人备注 `<HIDE HP GAUGE>` 546 个、`<SHOW HP GAUGE>` 277 个（两个都写的 2 个），转换器把它们存进 `meta`，运行时没人读，所有敌人受伤／被选中都出血条。

**原版规则**（读冻结源 `YEP_X_VisualHpGauge.js` 的 `Game_Enemy.hpGaugeVisible`／`Window_VisualHPGauge.isShowWindow`，插件参数 Defeat First=false、Always Visible=false；没有跑探针，源码判断是确定的）：
- 优先级：隐藏成员 → 不显示；`<HIDE HP GAUGE>` → 不显示（先于 SHOW，两个都写 HIDE 赢）；战斗测试 → 显示；`<SHOW HP GAUGE>` → 显示；其余 → 显示。
- 默认参数下 `<SHOW HP GAUGE>` 与不写等价（只有 Defeat First 打开才有区别，本游戏没开）。
- HIDE 的敌人血条一直不出现，被选中、受伤、滑动中都不出；`isShowWindow` 先判 `hpGaugeVisible`。
- 关系：Olivia_WeaknessDisplay 的 `<Show/Hide HP Gauge>`（`isShowWeaknessHpGauge`）全插件没人调用，它的名字窗口是独立窗口，名字照常显示；只有 YEP 脚下的粗血条受这两个标签管。Boss 血条（MOG）不受影响。

**运行时**：`XEnemy.hp_gauge_visible()`（读 `data().note`）；`battle_scene.gd` `_paint_enemy` 在画粗血条前判断，不可见就只画名字。没有新的开关；原版没有这个行为的对照数据以外的"回退"，要回到旧行为 `git revert` 即可。

**专项**：新 `tests/xiyou_hp_gauge_visible.gd`（14 项）：全库 546／277／2 个计数、全部 2000 个敌人的显隐与备注一致、隐藏成员、画面里 plain／SHOW／HIDE 三种敌人的血条填充与名字（HIDE 只有名字）。反向验证：去掉画面判断后 `paint_hide_gauge` 失败。界面对照截图：`04_验证/本地结果/nezha_gauge1/gauge_plain.png`（有血条）、`gauge_hide.png`（HIDE 无血条，名字照常；测试里换了敌人编号，所以名字与立绘对不上，只看血条有无）。

## 交接板

- 下一步：无
- 用户试玩说明：带 `<HIDE HP GAUGE>` 的敌人（约 546 种，多为宝宝、召唤物之类）打它们时脚下不再有粗血条，只有名字；其余敌人照旧。
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 无

## 验证

- 专项 `xiyou_hp_gauge_visible` 14 项通过。
- 云端选测（提交 fc7d88f3，基准 731840ff，187 个场景、6 片）全部通过：[运行页](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41862540600)。
- 待交叉核查：`enemy.gd`（新 `hp_gauge_visible`）、`battle_scene.gd`（`_paint_enemy` 加一行判断）。

## 本分支提交

- 见 `git log cc/nezha-gauge1`
