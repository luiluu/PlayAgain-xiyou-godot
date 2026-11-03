# 交付：cc/bajie-growth3

- 车道／工作者：C 规则·机制／八戒（cc，Opus）
- 状态：进行中

（成长装备尾项第一期：派单 1～3 加第 5 项的心钢／狂妄战力；智能 AI、甚尔、提示与 `_forced_run` 补例在「接续」。）

## 变更记录草稿

## 2026-11-03 【cc·八戒·未经审查】成长装备尾项一：心钢／狂妄动态说明、魔冠余项、选原件看词条（dev.待定）

派单：总装十五 growth3（成长装备尾项），按 1→3 的次序做，第 5 项先做了心钢／狂妄的战力。

### 一、心钢／狂妄动态说明（`ui/growth_help.gd` XGrowthHelp，新文件）

- 照 H/U.helpRows、describe、rewriteHelpRows、helpView、groupHelpRows 移植：说明里旧版开头换回数据库说明；备注里匹配 helpPatterns 的旧成长行删掉，按当前层数／盛名重写（效果／战技／冷却／条件行加 `\c[1]`，倒着追加到 APs）；有旧版累计生命的多一行「成长：额外最大生命＋N」；最后同色行归在一起。
- `XHelpCard.content` 对这四件（7900～7903）改走 XGrowthHelp；`XHubris` 开战记一个弱引用（说明卡要当前回合与出战名单，不直接存战斗对象）。
- 原版参照 `growth_help_probe`（新探针，12 例：心钢 0／100／350＋旧版生命／99＋待结算，利维坦 0／5049＋待结算，狂妄 0／300／42＋待结算／600＋扬名（两种回合），无我 1000），拷成 `tests/fixtures/growth_help_oracle.json`，不进同步。
- 参照里查出原版两处缺陷，登记 O-待定（`XGrowthHelp.HELP_FIX`，默认开）：这两个 setItem 包装装得早（第 15、17 个），外层元素包装先 `Object.assign` 拷了一份再往里传，所以①「本场成长」「当前增益」两行永远不出（拿拷贝去比待结算账本与 `U.gear(a)===i`）；②helpView 里重算 descParams，把外层战力包装插的「装备战力」行冲掉。默认按原件比、两行照常出，元素与战力包装在说明之后照常做；关掉回到原版，参照逐行比（文字、字号、颜色、对齐、行 y、卡高）。
- `xiyou_heartsteel` 的 PENDING_FIELDS 去掉 desc：胜利行比 describe 后的说明。

### 二、心钢／狂妄战力（`core/power.gd` `_growth_gear`）

- 照 installCombatPowerRuntime 第 122～123 行：狂妄／无我物理池 ×(1＋(扬名倍率−1)×0.6)；心钢／利维坦生命按参照 ×(生命倍率−1) 记一行「心钢 · 生命×N（层数k，第n阶）」、回合末回复池 ＋3%／5%。缓存键加上层数、盛名与底子（重制不随胜利改写备注，原版靠 describe 改备注换键）。
- 参照：`growth_help_probe` 每例另记 `CodexCombatPower.equipment`，12 例总分与逐行一致。渡鸦／米拉／甚尔的专属装备加成仍未做。

### 三、魔冠余项

- 图标 290000：切片 system 图加 `Codex_DemonCrown`（1254×1254），`XDemonCrown.icon_texture` 整张平滑缩到格子大小；`XUI.icon_texture` 与说明窗大图标接上（原版 CodexQualityIcons demonCrownArt）。
- RJO.HE.getDescParams 包装：魔冠的说明行里带小数的数字按 D.display（Math.round，正号丢掉）取整（`XDemonCrown.desc_rows`，`XHelpCard.desc_params` 末尾调）。
- replay 后清战力缓存（CodexCombatPower.clearCache）；CodexZones.invalidate 不用做（五乘区不移植，O-044／O-050）。
- 参照：`demon_crown_probe` 加 `help` 例（成长 12.3456 时的说明行），19 例无错；专项比说明行（神话词条是重制自己掷的，不比）、取整与图标。

### 四、锻造选原件时 Shift 看原件词条（`ui/crafting.gd`）

- 选原件时按 Shift，在详情窗位置另开一张原件说明卡（字号压到 14 以下），详情窗藏起；再按 Shift、取消、选定都收起，移光标时跟着换；帮助窗提示换成「按 Shift 返回升级预览」。照 installNativeLeviathanForge 的 _codexShowSourceHelp／_codexCloseSourceHelp。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 心钢／狂妄说明卡（`ui/growth_help.gd` `view`、`ui/help_card.gd` `content`） | 外层元素包装传进来的是拷贝，「本场成长」「当前增益」两行永远不出；helpView 重算 descParams，「装备战力」行与元素包装的改动被冲掉 | 按原件比，待结算与扬名增益两行照常显示；元素与战力包装在成长说明之后照常做 | 原版本意要显示（代码写了两行），实际因包装次序看不到 | `XGrowthHelp.HELP_FIX = false` | cc（八戒） | 待用户确认 |

## 待交叉核查

- 新文件：`ui/growth_help.gd`、`tests/xiyou_growth_help.gd`（＋tscn、fixture）、`mv_oracle/growth_help_probe.cjs`。
- 另改：`ui/help_card.gd`（content 分支、css_key、cap_size、desc_params 末尾魔冠取整）、`core/power.gd`（_growth_gear、缓存键）、`core/hubris.gd`（_logic 弱引用、wearer_buff）、`core/heartsteel.gd`（注释）、`core/demon_crown.gd`（icon_texture、desc_rows、replay 清战力缓存）、`ui/xui.gd`、`ui/item_status_painter.gd`（魔冠图标）、`ui/crafting.gd`（Shift 原件卡）、`03_转换工具/xiyou_slice.json`（system 图加一张，A 车道文件，只加一行）、`mv_oracle/demon_crown_probe.cjs`（help 例）、`tests/xiyou_heartsteel.gd`、`tests/xiyou_demon_crown.gd`、`tests/xiyou_growth_forge.gd`。
- 原沙僧核心文件：没改。
- 请重点核：groupHelpRows 的颜色归一（原版借 `style.color`；重制 rgb／rgba／#hex 解析后比，其余按原字串）；HELP_FIX 开时把元素包装放到成长说明之后的口径。

## 交接板

- 下一步：成长装备尾项一已交（心钢／狂妄说明与战力、魔冠余项、选原件看词条）；尾项二（智能 AI 巨人吞噬、甚尔抑制行动不减蓄力、解锁与锻造锤提示、`_forced_run` 补例）见本单「接续」。
- 用户试玩说明：心之钢／狂妄等四件的说明会跟着层数、盛名变；战斗里多两行金色「本场成长」「当前增益」（原版看不到，O-待定 可关）；装备战力算上成长阶数；魔冠「"头顶"」有自己的图标；锻造选原件时按 Shift 可看那件原件的词条。
- 需要用户决定：O-待定（说明卡显示待结算与扬名增益）保留与否，默认保留。

## 进度账

- 养成·成长装备：约 75% → 约 85%，依据：动态说明、战力、魔冠余项、选原件看词条都已做并对上参照；剩智能 AI、甚尔、提示几项。

## 可优化（流程／工具／效率）

- 已做：无。
- 建议：无。

## 验证

（待写）

## 本分支提交

- 382e4b57 心钢／狂妄动态说明；WIP 两条魔冠余项与战力；28ad1c2c 选原件看词条；b6e5dc75 合 main

## 接续

1. 智能 AI 选巨人吞噬：`Codex_SmartBattleAI.js` 引用 7900，先查 `plugins.js` 确认这个插件启用了（记忆：Codex_Raven.js 就没启用）。
2. 甚尔抑制行动（`_tojiSuppressed`）不减心钢蓄力。
3. 解锁与锻造锤的提示（$.toaster），心钢、狂妄、锻造锤三处。
4. 可选：`_forced_run` 新次序补一例（强制行动里屠苏剑气＋狂妄）。
5. 战力：渡鸦／米拉／甚尔的专属装备加成（power.gd 注释里仍列为未移植）。
