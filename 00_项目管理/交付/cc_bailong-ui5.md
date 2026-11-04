# 交付：cc/bailong-ui5

- 车道／工作者：B 界面／哪吒（cc，Sonnet／medium），接 `cc/bailong-ui4b`（73e440ee），已 `git merge main`
- 状态：**可合并**（云端选测通过）。分支叠在 ui4b 上：ui4b 先合；ui5 把面板位置从写死的 131.5 改成跟血条算。

## 做了什么

移植原版 MOG_BossHP v2.3 的 Boss 血条，每场有名单 Boss 的战斗顶部都看得见：头像、框、彩虹生命条、血量数字、Boss 名。

- 新 `battle/boss_hp_bar.gd`（`XBossHpBar`，Node2D）；`battle_scene._build_ui` 最先加（窗口在它上面，对应原版 hudField 在窗口层下）；`boss_hp` 成员；`_hit_visual` 里命中敌人时 `boss_hp.applied`；`_victory`／失败／`_escape_success` 里 `boss_hp.ended()`。血量读 `view(e)`（演出中的画面读数，不是已结算的最终值）。
- 参数全读正式西游插件参数：框 (105,45.5)、生命条 (22,28)、数字 (320,42) 间距 20、名 (30,47) 字号 18、头像 (−50,−8)。
- 原版读法（源码 `Sprite_BossHP`）逐条照做：
  - 哪些敌人算 Boss：参数 `boss-1…boss-569` 的敌人编号（`_bosshp_meter`），**与备注 `<boss>`／难度 Boss 判定无关**；开战时取敌群里最后一个名单 Boss 且未隐藏的建条，开战没有就整场不建；一旦算过 Boss 不再清。
  - 条跟「最后被命中的名单 Boss」：换目标时红条、数字从命中前的血量起算；非名单敌人被打不抢条。
  - 每帧：条纹流动 4px（周期 928）；红条（下半）每帧降 1+差/160（指数式，尾巴很长）；数字每帧追 1+⌊差/30⌋；蓝条（上半）即时；掉血震动 80 帧、整条 y 在 −3…+2 随机；对话忙／战斗结束／Boss 死亡时不透明度每帧 −5，否则 +5，首帧直接满。
  - 数字：≥1 万加单位万／亿／兆／京，<100 取 2 位小数、<1000 取 1 位、其余取整，去掉末尾 0（`1.5亿`、`12.35万`），恰好一半取大（JS toFixed）。
  - 多 Boss：同时只显示一个，没有并排。
- **状态图标不画**：原版里这串图标被 Codex_BossStatusSummary 直接藏掉（`_state_icon.visible=false`），换成下方状态面板，所以血条不画图标。
- 状态面板跟血条对齐：`boss_status_panel.gd` 去掉写死的 `BAR_X／BAR_Y`，改读 `XBossHpBar.layout_pos().x` 和 `layout_bottom()+8`（结果仍是 (105,131.5)，`xiyou_boss_status` 37/37 照过）。
- 素材：转换器 `xiyou_export.py` 在切片里的敌人收集处加 `ref_img('bosshp', …)`：三张框／条／数字图，加切片里名单 Boss 的头像（冻结源 `img/bosshp/` 共 374 张，只带切片要用的）。同步过一次（`--accept-additions`），没动切片 json。

## 战力显示（总装补充，Kyo 11-04）：已做、默认关，等 Kyo 重构战力后再开

- 新 `core/power_enemy.gd`（`XPowerEnemy.enemy／cached`）照冻结源 `installCombatPowerRuntime.js` 的 `enemyPower` 取数：行动表伤害类型 1／2／5／6、评分不低于最高分−2 加权、三档中性靶（防御 100／1 万／100 万）预演普通＋暴击 × 命中 × 重复 × 范围，有效生命 = 最大生命×防御折算÷受伤率，两项各按曲线折分。取数与显示分开，以后换新战力只换这一个函数。
- 显示：`XBossStatusPanel.SHOW_POWER`（static var，默认 false）。开时折叠栏右上画金色「战力 N」，名字让出 118 宽；展开才现算，折叠只读缓存（同原版）。关时布局与之前完全一样。
- 专项 `xiyou_boss_status` 加开关两边的例（关：为空、布局同前；开：折叠只读缓存、展开现算、签名含状态表失效、有效生命与两条曲线按公式对上），共 53 项。
- **没有原版读数对照**：重制的 power_probe 只量角色战力，没有敌人战力的参照；输出部分只能验证形状和公式结构，没跟原版数值逐例比。要对得补一个 enemy 探针，没做。
- 回退开关覆盖检查：缺口数没变（新 0）。
- 截图 `04_验证/本地结果/boss_status_shot/boss_status_bar_power.png`（不入 Git）。

## 和原版的差别 / 没做

- 窗口截图和原版对照：做了窗口模式截图（`04_验证/本地结果/boss_hp_shot/bar_hit_trail.png`、`bar_settled.png`、`boss_hp_bar.png`，不入 Git）：框、头像、彩虹条＋紫色红条拖尾、`188.7万` 数字、名字位置都对。**没有跟原版实机截图逐像素对**，原版要开浏览器夹具，这轮没做；数值读数（位置、速度、公式）来自源码和 plugins.js。
- 敌人变身（transform）后血条不会切到新编号（原版切）；Boss 战中途现身不补建条（原版同样不建）。
- 名字没有 EliteEnemy 的那层 `Star.EliteEnemy.isElite` 判断，用重制已有的 `original_name()`（神话前缀已在里头）。
- 快捷键不连发：按派单不做。

## 验证

- `语法检查.py`：524 个 .gd 0 个问题。
- 专项 `xiyou_boss_hp_bar`（新，71～73 项）：名单与头像（敌 6→SL_TX_62、敌 21→BOSS_1、敌 28→BOSS_12）、位置 (105,45.5)/123.5/131.5、数字格式 18 种、首帧满、数字从 0 追、红条每帧下降读数、数字每帧追赶读数、震动 80 帧与 y 范围、流动 4px 与 928 回绕、回血不震动、对话忙淡出淡入、结束淡出、死亡淡出、无 Boss／隐藏 Boss 不建条、多 Boss（取最后一个、被命中抢条、命中前血量起算、非名单不抢）、接进真战斗画面、素材已带。`xiyou_boss_status` 37/37。
- 选测：`选测.py main --list` 选中 210 个场景（合 main 后），走 `云端选测.py run`：见下面「云端选测」。

## 云端选测

`云端选测.py run`：**通过**——210 个场景、7 片（含 `xiyou_boss_hp_bar`、`xiyou_boss_status`、战斗核心类），提交 e8012465df（ci/cc/bailong-ui5，即合 main 后的本分支），运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41807458062 。之后只改了交付单。

## 变更记录草稿

## 2026-11-04 【cc·哪吒·未经审查】Boss 血条（MOG_BossHP）移植（dev.待定）

- 战斗画面顶部加 Boss 血条：头像、框、彩虹生命条（掉血时紫色拖尾慢慢追上）、血量数字（≥1 万带「万／亿／兆／京」）、Boss 名；掉血震动、对话和战斗结束时淡出、Boss 死亡淡出。哪些敌人算 Boss 按原版插件参数名单；多个 Boss 时显示最后被打的那个。Boss 状态面板位置改成跟血条算（结果不变）。
- 转换器带上 `img/bosshp/` 的框、条、数字图和切片里 Boss 的头像（需要重新同步）。
- 折叠栏「战力」已做、默认关（`XBossStatusPanel.SHOW_POWER`），等战力系统重构后再开。
- 新专项 `xiyou_boss_hp_bar`。

## 待交叉核查

- `battle/boss_hp_bar.gd`（对照 `MOG_BossHP.js` 7794 行以后：refresh_hp_number、refresh_red_meter、update_shake_effect、need_onSkillCancelites）。
- `battle_scene.gd`（`_build_ui` 加血条、`_hit_visual` 的 `boss_hp.applied`、`_victory`／失败／逃跑的 `ended()`）。`boss_status_panel.gd`（位置改读血条）。`xiyou_export.py`（bosshp 素材引用）。
- `core/power_enemy.gd`（对照 installCombatPowerRuntime.js 411～448 行 enemyPower）；`boss_status_panel.gd` 的 SHOW_POWER 与折叠栏战力。
- 没改 battle_logic／actor／battler／damage／xstate 等核心文件。

## 给总装

- 合并后要重新同步（转换器改了：`img/bosshp/` 新增约 700 个文件含 .import，产物不入 Git）。
- 可优化：血条的红条是指数追（原版如此），Boss 血量到千万级时尾巴要几十秒才收；可以改成线性上限，原版行为先照搬，要不要改请 Kyo 定。
