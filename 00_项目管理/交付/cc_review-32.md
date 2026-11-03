# 交付：cc/review-32

- 车道／工作者：审查／cc（审查，Opus medium）
- 状态：可合并
- 基线：从 main `245e30ba` 切出（派单写 00f1e2d8，开工时 main 已多合 growth4），只加本交付单。行号按这个基线。

## 变更记录草稿

无（核查条目见下节）。

## 待总装并入变更记录的核查条目

## 2026-11-03 【cc·审查】核查 奈叶探针 5.2 倍、成长装备尾项一、探针五乘区检查、璇的星谱页期一、洪荒诅咒自选

- 核查覆盖：cc/wukong-dmg1b（5d1ea3a2）、cc/bajie-growth3（60a1066e）、cc/nezha-tools49（6aabe889）、cc/nezha-xuan1（e808c146）、cc/wukong-honghuang1（44a5a47a）
- 结论：P1 一条、P2 一条，都在 xuan1（P1-1 满级星纹打不开操作页；P2-1 读档后命主名册移不出人）；P3 三条。dmg1b、honghuang1 通过；growth3、tools49 只有 P3。
- 验证：对着冻结 v0.28 读码；5 个原版探针重跑，产物与夹具逐例相等；专项 12 个全过；临时 Godot 脚本复现 P1、P2。没跑全量。

## 问题

### P1-1 星纹升到 3 级后，再点它，操作页是空的（xuan1）

- 位置：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/xuan_chart.gd:176`，`COST[lv]` 在 lv＝3 时越界（`COST` 只有 3 项）。
- 原版：`installNativeXuanRuntime.js:550` 同样读 `cost[3]`，但 JS 得到 undefined，只是文字变成「强化（星砂undefined）」，三行照常出，这一行不可选，配入、回收都能用。
- 后果：`mark_rows` 报 `Out of bounds get index '3'` 后返回空，页面没有任何选项。满级星纹不能再配入此槽，也不能回收强化星砂（花掉的 40 星砂退不回来）。玩家正常学满一个星纹就会遇到。
- 复现（临时脚本，`godot --headless --path 01_Godot工程 --script <脚本>`，extends SceneTree）：
  ```
  var s := XState.new_game(2, 1, [8, 9, 10]); XState.current = s; s.actor_max_level = 99
  s.set_switch(XItemMarks.SUPER_SWITCHES[0], true); XTusuXuan.recruit(s, 177)
  var a: XActor = s.actor(177); a.change_level_mv(60); XXuanChart.chart(s).sand = 1000
  XXuanChart.learn(s, a, "yuhui"); XXuanChart.learn(s, a, "yuhui")
  print(XXuanChart.mark_rows(s, "yuhui"))   # SCRIPT ERROR: Out of bounds，打印 []
  ```
- 测试为什么没发现：探针与专项的流程最多学到 2 级（`xuan_chart_probe.cjs:144`），夹具里没有 lv3 的页面。修时建议探针加一例学满再打开的流程。原版那行文字带 undefined 是原版缺陷，重制怎么显示由修的人定，登记优化。

### P2-1 读档后，命主名册里的人移不出去（xuan1）

- 位置：`core/xuan_chart.gd:116`，`c.roster.find(id)`。存档走 JSON，`s.flags`（`xstate.gd:905`）读回后名册是 `[8.0]`，而 Godot 里 `[8.0].find(8)` 是 -1。
- 后果：读档后点已在名册里的人，不是移出，而是再加一遍：3 席时变 `[8.0, 8]`，同一人占两席；1 席时要点两次才移出。名册现在还没有战斗效果，所以眼下只影响页面，但等璇的战斗机制接上就会读到错的名单。
- 复现：同上建档，`XXuanChart.toggle_roster(s, 8)`，`XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))` 读回，再 `toggle_roster(读回的档, 8)`：结果 `[8.0, 8]`，原版应为 `[]`。
- 测试为什么没发现：`save.roundtrip`（`tests/xiyou_xuan_chart.gd:196`）只比数值相等，没有读回后再操作。

### P3-1 选原件的说明卡字号压到 14，原版实际没压住（growth3，只读码，没跑原版）

- 位置：`ui/crafting.gd` `_sync_source` 的 `cap_size(14)`。
- 原版 `installNativeLeviathanForge.js:139～140` 先把 `descParams` 压到 14，再 `setItem(view)`；但这几件都是成长装备，`setItem` 包装走 `helpView`，里面 `getDescParams` 重算（`installNativeHubrisRuntime.js:175`），压的字号被冲掉。所以原版大概率是 18 号，重制 14 号。只是观感差别，要么照原版，要么登记为优化。

### P3-2 探针五乘区检查的正则有漏（tools49）

- 位置：`07_开发环境/探针登记检查.py`。没认 `evalDamageFormula`、`.result()` 等写法，交付单自己也提了这个疑问。
- 实例：`custom_damage_probe.cjs` 用 `evalDamageFormula`，`battle_gaps_probe.cjs`、`hit_warehouse_probe.cjs` 用 `.result()`，都没提 CodexZones，也不在存量清单。粗筛同类共 17 个，有些未必真读伤害，没有逐个确认。
- 复现：`grep -l "evalDamageFormula\|\.result()" mv_oracle/*_probe.cjs`，再去掉含 CodexZones 的。

### P3-3 优化登记 O-149、O-150 两行只有 5 列（不是本批引入）

- 位置：`03_再刷重制_Godot/00_设计/优化登记.md:128～129`。
- 后果：`回退开关覆盖.py` 报「解析不了」，这两个开关（含狂妄 `KILL_FIX`）不在覆盖检查里。补齐到 8 列就好。

## 已查通过

- **cc/wukong-honghuang1（甲）通过。**
  - 不掷随机：CE1442 共 569 条指令，没有控制变量指令（122），全文也没有 random；探针虽把 `Math.random` 固定成 0.5，但读源码确认用不到它。
  - 变量 1468～1472：只由第三段脚本写，后面按变量值 1～15 分支学 7201～7215；未选满时读回 0 的分支正式流程走不到。
  - 三段脚本：`_HH_OFFER／_HH_ASK／_HH_SAVE` 与原文去空白后整段相等；`TIER`、`FACTOR`、`curse_label`、`curse_ids` 与 `installNativeHonghuangRuntime.js` 一致。
  - 取消类型 -1 在 `message_box.gd:463` 是不可取消，和原版一致。候选放静态变量不进存档，同原版 `$gameTemp`。
  - 重跑探针，12 例与夹具全等；`xiyou_honghuang_curse` 885／885、`xiyou_script_census` 18／18。
  - 没查：专项用替身宿主，没有用真的对话框点过 15 项滚动。
- **cc/nezha-xuan1（甲）规则层除上两条外通过。**
  - `learn`、`refund`、`equip`、`mark_level`、`set_control`、`stage`、九个星纹名字与说明都和原版逐项一致。
  - 胜利星砂：`grant` 只有 `battle_scene.gd:1750` 胜利时调一次，有 `_rewards_granted` 防重复；`enemies` 含隐藏成员（`battle_logic.gd:148`），Boss 判定同 `CodexBossDifficulty.isBoss`；璇在后备不加。交付单请重点核的这两点都对。
  - 存档字段：`_codexXuanChart` 沿用，`_codexXuanControl`、`element` 只在设置后才有，旧档不受影响。
  - 重跑探针，25 例与夹具全等；`xiyou_xuan_chart` 128／128、`xiyou_skill_menu_events` 10／10。
  - 差异不必修：`toggle_roster` 在 0 席时清空，原版 `slice(-0)` 保留全部，但 0 席这一行不可选，走不到。`element_rows` 跳过空名字，原版显示「无」，现有数据第 2 项起没有空名字。
- **cc/bajie-growth3（甲）除 P3-1 外通过。**
  - O-151：夹具里「本场成长」「当前增益」「装备战力」出现 0 次，确认原版确实显示不出；`HELP_FIX` 是 static var，开关两支都有断言，`回退开关覆盖.py` 没报它。默认开着是否保留，仍等用户定。
  - 战力 `_growth_gear` 与 `installCombatPowerRuntime.js:122～123` 逐项一致，次序也在 `gearEffects` 之前；缓存键补了层数、盛名、底子。
  - `group` 的颜色归一：rgb／rgba／#hex 解析后比，和浏览器归一等价；英文颜色名没归一，现有行里没有，不算问题。
  - 魔冠：`desc_rows` 同 `getDescParams` 包装，四舍五入同 `Math.round`；图标只有 `xui.gd:249` 和 `large_icon` 两处取图，都接上了；`XPower.clear_cache` 在重放后调用。
  - 选原件：Shift 开关、取消先收起、选定收起，同原版 159／164／190 行。
  - 重跑探针，`growth_help` 12 例、`demon_crown` 20 例与夹具全等；专项 `growth_help` 50、`demon_crown` 106、`growth_forge` 538、`heartsteel` 423、`help_card` 1054、`power` 137、`crafting` 49 全过。
- **cc/wukong-dmg1b（乙）通过，5.2 倍确实是探针没关五乘区。** 我去掉探针里的关闭行重跑一次，和关闭时逐例逐字段比：差异只在伤害相关字段（`post.value`、`hp1`、`gains.*.d／hp`），MP、段数、目标都不变；`atk.1` 开 388／关 580、`atk.9` 开关都是 201，与交付单一致。关闭时的 31 例与夹具全等，`xiyou_nanoha` 251／251。
- **cc/nezha-tools49（丙）只看结论，除 P3-2 外通过。** `测试探针登记检查.py` 7 项通过，`探针登记检查.py` 真实工程通过，存量 50 个未逐个确认（交付单已写明）。

## 没查

- 派单之后才合的 cc/bajie-growth4、cc/wukong-honghuang2 不在本次范围，仍待核查。
- 没跑全量；没用真机试玩界面。

## 交接板

- 下一步：派车道修 xuan1 的 P1-1、P2-1（核查发现，尚未修好，留在交接板）；P3-1～P3-3 随手处理。
- 用户试玩说明：无（只加审查报告）。
- 需要用户决定：无新增（O-151 默认保留与否，仍是 growth3 交付单里那一条）。

## 进度账

- 无变化。

## 可优化（流程／工具／效率）

- 建议：写「页面行文」类探针时，流程用例覆盖等级或数量的上限（这次 P1 就是上限那一格没测），归写探针的车道。
- 建议：存档读回后的值都是 float，`Array.find／has` 用 int 找不到。可以在 `语法检查.py` 或审查清单里加一条，扫 `flags` 里取出的数组做 `find／has` 的地方，归工具车道。

## 本分支提交

- 本提交：只加本交付单。
