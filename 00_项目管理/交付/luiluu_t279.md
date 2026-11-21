# 交付：luiluu/t279

- 车道／工作者：T279 六维⑤怪物图鉴＋战斗内首领详情接雷达图（cc，Sonnet＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-21 【cc·天启篇·未经审查】六维⑤：怪物图鉴、战斗内首领详情接六维雷达图（dev.待定）

- 依据：T270 六维定稿（私密仓 重制设定/天启篇_角色六维_v0.3定稿.md 第六节卡 5）；Kyo D234。复用 T278 的 `XSkinSixDimRadar.paint`，不改控件。
- **摘要函数**（`core/boss_status.gd`）：`XBossStatus.six_summary(b, logic)`：不生效（西游档、`XTianqiSixDim.ENABLED=false`）回 `{}`；否则 `{six, tier, tier_name, tier_line「战商 4 档·狡黠」, wit_hint, resist_pct, resist_line, immune, control_line}`。`hard_immune(b)`＝四骑士本体或霸体首领。不含任何战力。
- **怪物图鉴**（`ui/enemy_book.gd`）：天启篇、已登记的敌人，状态窗左栏右半放紧凑雷达＋两行简注（「战商 N 档·名」「控制抗性 +x%」），立绘靠左缩到最宽 200 让位；未登记整窗空（原样遮罩）；战斗内「怪物信息」未登记且 `BATTLE_SHOW_UNREGISTERED` 关时仍「？？？」不画。西游档、关开关时 ops 与改前一样。`actor_book.gd` 的 radar 操作加了可选第 6 位字号（图鉴默认 18 不变）。
- **首领详情**（`battle/boss_status_panel.gd`、`ui/skin/skin_boss_status.gd`）：天启篇多第四个页签「六维」（异常／增益／全部／六维，页签宽按 4 等分）；页签里左边雷达、右边战商档名＋一句话＋「控制抗性 +x%」或「免疫停手控制」。折叠胶囊不动；点击拦截、翻页、Esc 全沿用。西游档与关开关仍 3 个页签。旧面板与新界面各画一份。
- **四骑士算首领（我加的，见异议）**：`XBossStatus.is_boss` 在六维开着时把四骑士本体也算进去。原来骑士 `setup_horseman` 不记首领难度，详情面板根本不出现，没法「展开四骑士详情」。六维关着与改前完全一致。
- **玩家可见文字（全部，待小A 审）**：页签「六维」；战商档名（蒙昧／直觉／老练／狡黠／宗师，six_dim.json 已有）；档位简注「战商 N 档·名」；五句战商一句话（r1 按小A 文字审改，并对照 `tianqi_enemy_ai.gd` 实际行为）：1「全无章法，按本能随机出招」、2「选目标时有一半几率盯紧血量最低的」、3「会避开免疫与重复控制，优先打弱点」、4「专盯弱点与可斩杀目标，优先点治疗者」、5「遇厚盾与护持会留大招，先铺垫再爆发」；「控制抗性 +x%」（沿用 T278）；「免疫控制状态」（r1 改，原「免疫停手控制」）。
- **截图**（真跑 Godot `--audio-driver Dummy`，工具 `tests/t279_six_dim_shots.tscn`，1280×720，在 `00_项目管理/归档/交付截图/T279_六维雷达/`）：`book_8／9／10`（已登记的守层者训练官、哥布林、哥布林士兵…）、`book_30`（未登记，右窗全空）、`boss_death／war／famine／plague_six`（四骑士六维页签）、`boss_plague_debuff`（原「异常」页签不被挡）。

## 验收逐条（卡 5）

1. 图鉴：已登记普通怪出雷达（✓ 截图）；未登记严格遮罩（✓ `book_30`、专项 `book_unregistered_empty`）；**四骑士图鉴里没有条目**（骑士借壳敌人 71 出战，没有独立图鉴记录），所以这一半「图鉴里的四骑士」做不到，四骑士只在战斗详情验。
2. 战斗详情：四骑士展开→点「六维」页签，四张六边形各不相同且与 six_dim.json 一致（死亡＝生存 SS、战争＝速度 SS、饥荒＝战商 SS、瘟疫＝辅助 SS）；都显示「免疫控制状态」；原页签与点击拦截仍可用（专项点「异常」「全部」「六维」逐个切；`boss_plague_debuff`）。✓
3. 全程无战力字（专项 `summary_no_power`／`book_no_power_text`）；西游档与关开关（专项 `off_*`／`xiyou_*`／`book_*_no_radar`）与改前一致；无声实机截图核验不遮挡。✓（雷达在详情窗下半留白，不压立绘外的东西；图鉴立绘缩到 200 宽，原图较大的怪会比原来小。）

## 交接板

- 下一步：小A 文字审（上面一整节）；总装合并后按 `发行空壳.py check`（已过）。
- 需要用户决定：无（四骑士算首领、骑士战多「详情 ▾」胶囊，协调（项目经理cc）同意保留，未经 Kyo）。

## r1 返修（小A 核查退回 P1×1 P2×1 P3×3）

- **P1-1**：`XBossStatus.is_boss` 恢复原样（只认首领难度）；新增 `XBossStatus.is_panel_boss`（is_boss 或六维开着时的四骑士本体），只给 `XBossStatusPanel.bosses()` 用，战斗结算（灰镰处决、首领低血增伤、五条悟信息过载）不受开关影响。专项加断言：骑士战 `is_boss` 在开关开／关下结果相同（都为假），`is_panel_boss` 才随开关。
- **P2-1**：战商五句、「免疫控制状态」按审查建议改。**我对照 AI 代码（`tianqi_enemy_ai.gd`）后有两句没照抄，待小A 确认**：第 2 档审查写「偏重直伤，有时会盯紧残血目标」，但「偏重直伤」是输出维度（aggro_pct）的事，战商 2 档实际只做「选目标时一半几率盯最低血、一半照受击率」，改成「选目标时有一半几率盯紧血量最低的」；第 4 档「优先切后排」代码里没有，实际是斩杀目标权重 ×6、治疗者 ×1.5，改成「优先点治疗者」。第 1、3、5 档与代码对得上，照审查原句。
- **P3**：专项补直接建旧面板（`XBossStatusPanel.new()`）的六维页签用例（4 页签、点击切页、stamp 跟六维开关）；旧面板雷达传 `line=EDGE`／`gold=BLUE`；`refresh` 的 stamp 加 `six_tab_on()` 与 `enemy_id`；图鉴立绘让位加限高 200。截图已按新文字重拍。
- 验证：新专项 66/66；回归 enemy_book 96/96、six_dim_radar 33/33、ui_skin_hud 112/112、actor_book 28/28；发行空壳 check、语法检查过。

## 异议／偏离

- （协调（项目经理cc）同意保留，未经 Kyo：36 层骑士战正需要看规则。）四骑士原本不出首领详情面板（不是 `boss_difficulty_boss`），定稿卡 5 默认它有。我只在六维开着时让它算首领；副作用：骑士战里顶部多出「详情 ▾」胶囊，能看异常／增益页。若 Kyo 不想骑士战有这个胶囊，回退＝`is_boss` 去掉骑士那一行，六维页签就进不了骑士。
- 图鉴里没有四骑士条目（见验收 1）。
- 定稿把雷达放「立绘右侧」：图鉴立绘本来居中，我把它改靠左缩小腾位。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- 新专项 `xiyou_tianqi_six_dim_book_boss`（59 项：摘要、图鉴 ops、四骑士首领详情页签与点击、关开关、西游档）59/59；回归 `xiyou_enemy_book` 96/96、`xiyou_tianqi_six_dim_radar` 33/33、`xiyou_tianqi_six_dim` 69/69、`xiyou_actor_book` 28/28（本机 headless 直跑）。
- `xiyou_boss_status`：**原有失败，与本单无关**（已在干净基线对照）。本地 main（`0321f67a2`）另检出到临时目录（复制本机 `.godot` 与 generated），同一专项前台跑，输出与本分支逐行相同：
  - 输出（两边一样）：`FAIL power_enemy_shape {}`；`SCRIPT ERROR: Invalid access to property or key 'effectiveHp' on a base object of type 'Dictionary'.` 位置 `tests/xiyou_boss_status.gd:197`（`check("power_ehp_formula", ... pw.effectiveHp ...)`）。
  - 原因：战力先藏（5549faf15）后 `XPower.enabled()` 为假，`XPowerEnemy.enemy` 返回 `{}`，第 193 行 `power_enemy_shape` 先失败，第 197 行再对空字典取 `effectiveHp` 报脚本错，协程中断，专项不再往下跑也不打印 TEST_RESULT（headless 进程挂着不退出，我手动结束）。这一行之后的检查两边都没跑到。
  - 没有 origin 远端（远端叫 github，没取），对照用的是本地 main。
- `发行空壳.py check` 过（登记 `XTianqiSixDim.data`／`of_battler` 已确认空值安全）；`语法检查.py` 过（1136 个 .gd 0 问题）。

## 本分支提交

- （见回执）
