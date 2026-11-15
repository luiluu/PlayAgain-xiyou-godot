# 甲档核查＋文字审：`cc/fest-champion-road`（冠军庆典丰富档 D46）

- **核查者**：ag（小A）
- **对象**：工作树 `/Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road`，分支 `cc/fest-champion-road`，交付提交 `e1f5ee6e2`（已合入过 `main`），交付单 `00_项目管理/交付/cc_fest-champion-road.md`
- **依据**：私密仓 `/Users/kyo/Documents/xiyou-design-docs/重制设定/冠军庆典活动_v0.3.1.md`（第 1～8 节，Kyo 11-15 定 D46＝丰富档）
- **核查结论**：**通过**（P1：**0 条**，P2：**0 条**，P3：**4 条**文案／体验建议；无需返修）

---

## 汇总

| 核查项 | 结论 | P1/P2 | P3 | 核查深度说明 |
| --- | --- | --- | --- | --- |
| 1）伤害钩子（一穿四／势如破竹） | 通过 | 0 | 0 | 核了底层计算规则与钩子注册表＋前代单测 `xiyou_fest_reward` |
| 2）存档防刷四处＋天启篇守门 | 通过 | 0 | 0 | 核了全仓消耗／销毁／卖出／仓库规则＋独立只读脚本实测抽查①②＋单测 |
| 3）`levelCap 60` 与 `8010～8012` 常驻 | 通过 | 0 | 0 | 核了升级／经验／序列化／转换器规则＋`xiyou_fest_reward` 实跑 |
| 4）两处按默认实现合理性意见 | 合理 | 0 | 1 | 核了数据库符文表与全局称号表规则，给出体验防呆建议 |
| 5）玩家可见文字审 | 通过 | 0 | 3 | 全量逐条核对交付单清单及源码全部可见文案与底线规则 |
| 6）前台专项与语法检查 | 通过 | 0 | 0 | `xiyou_fest_reward` **42/42**、`语法检查.py` **954 .gd 0 问题**；长测试列交总装 |

---

## P1 / P2 / P3 条目

### P1（必改阻塞）

- 无（0 条）。

### P2（需改或限期处理）

- 无（0 条）。

### P3（建议／润色，不阻断合并）

1. **贺礼／兑换店符文按 `top_level` 只看 `battle_members()` 存在误领低档的边角**（[fest_reward.gd:116-127](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_reward.gd#L116-L127)）
   - 现状：`top_level(s)` 在 `s.battle_members()` 非空时仅取当前出战队伍最高等级。若高练度主力放在后备、出战栏恰好只放了刚入队的低级新角色，领贺礼或换门票会按低级发成初级／中级符文（`24`/`64`）。
   - 建议：改为取全队已拥有角色 `s.members()` 的最高等级，或维持现状在 `SHOP_HELP["rune"]` 标明「按当前出战队伍最高等级」（当前写 `"按你现在的等级，发对应档的副本挑战符文。"`）。

2. **称号 `43`「冠军观赛团」获取说明与天启篇直赠口径略差异**（[fest_text.gd:121](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_text.gd#L121)）
   - 现状：`TITLE_TEXTS[43].how` 写 `"在庆典使者那里用庆典币兑换。"`；在重制版准确，但天启篇存档（[fest_lobby.gd:217-224](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/fest_lobby.gd#L217-L224)、[fest_reward.gd:153-160](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_reward.gd#L153-L160)）直接赠送且不开兑换店。因天启篇当前尚未对外发布，重制版全员适用现文案，可酌情补 `"（天启篇存档由使者直接赠送）"` 或保持。

3. **称号「限定。」后缀及颜色词标注略有不齐**（[fest_text.gd:119-124](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_text.gd#L119-L124)）
   - 现状：`42` 写 `"金色称号，限定。"`、`46`/`47` 写 `"限定。"`、`41`/`43`/`44` 未写 `"限定。"`。均为合法有效文案，如需版面完全整齐可统一后缀。

4. **精魂数字单位写法与读档提醒微末措辞**（[fest_text.gd:157,173,177](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_text.gd#L157)）
   - 现状：`SHOP_NAMES["gold"]`／`GOLD_ALL`／`LEFTOVER_TOAST` 用原始数（`精魂 ×10000`、`精魂 ×{gold}`），`SHOP_HELP["gold"]`／`ENVOY_GRACE` 用 `"1 万精魂"`；另 `REMIND_TOAST`（`"方桌大厅正在办冠军庆典，回大厅找庆典使者签到、领贺礼"`）在玩家已在大厅或已签满 3 天＋领过贺礼后当天首次读档仍会弹出，一天仅一次且无误导，不影响体验。

---

## 逐项核查明细

### 1）伤害钩子（一穿四 & 势如破竹）

- **叠层与清零周期**（核了底层机制＋`xiyou_fest_reward` 单测）：
  - 开战清理：[battle_logic.gd:200](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/battle/battle_logic.gd#L200) 调用 `XFestRing.battle_setup(self)`（[fest_ring.gd:204-205](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_ring.gd#L204-L205)），清除 `logic.actors` 的 `META_STACKS`（`"fest_ring_stacks"`）。
  - 倒下计层：[battle_logic.gd:3470](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/battle/battle_logic.gd#L3470) 调用 `XFestRing.on_collapses(self)`（[fest_ring.gd:211-222](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_ring.gd#L211-L222)）。`XEnemy.is_dead()`（[enemy.gd:165-166](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/enemy.gd#L165-L166)）先排除 `hidden` 未出场敌人；`META_COUNTED` 记在敌人实例上，同一只敌人复活再倒下或多次 `resolve_collapses()` 均不重复计数；每名 `stack_tier(a) > 0` 的参战角色各自 `+1` 层并封顶 `STACK_MAX = 4`。
  - 结束清理：[battle_logic.gd:3658](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/battle/battle_logic.gd#L3658) 调用 `XFestRing.finish(self)`（[fest_ring.gd:226-229](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_ring.gd#L226-L229)），同时清掉 `logic.actors` 与 `logic.state.members()` 的 `META_STACKS`。
  - 存读档与跨战隔离：核对 [xstate.gd:876-940](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/xstate.gd#L876-L940)，`to_dict()` 只序列化显式字段、不保存 Godot `Object` 元数据，`from_dict()` 重建全新 `XActor` 实例；即使战斗未走到 `end_battle()` 异常退出，下一场 `setup()` 也会清理 `logic.actors`，不会跨战或读档残留。
- **与现有 `finalMultiplier` 其它来源叠加关系**（核了底层公式）：
  - [actor_damage_hooks.gd:18,58](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/actor_damage_hooks.gd#L18) 将 `XFestRoad.damage_ops(a) + XFestRing.damage_ops(a)` 接在 `REST_TAGS[8] = "fest_road"`，返回 `{"op": "mul", "field": "finalMultiplier", "value": ...}`。
  - [module_registry.gd:287-291](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/module_registry.gd#L287-L291) 对 `SCALARS` (`finalMultiplier`) 的 `"mul"` 执行 `previous * float(value)`。
  - [damage.gd:290](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/damage.gd#L290) 计算 `final_mult = maxf(0.0, 1.0 + float(frame.finalAdd)) * maxf(0.0, float(frame.finalMultiplier))`。因此：
    - 「一穿四」（天灾 `1.0 + 0.05*n`／洪荒 `1.0 + 0.08*n`）与「势如破竹」（`1.0 + 0.10*streak`）及其它 `finalMultiplier` 来源均为**连乘**；
    - 戒指常驻 `<passiveHarmRi:N>` 进 `finalAdd`（相加区），与 `finalMultiplier` 相乘且**没有被重复乘**；
    - 治疗分支 `_healing`（[damage.gd:358-378](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/damage.gd#L358-L378)）不读 `finalMultiplier`，不会污染治疗；
    - 总账 [damage_ledger.json:290-299](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/damage_ledger.json#L290-L299) 已将 `fest_road` 登记为 `pooled`（天启篇出现即失败）。
- **仅在装备者身上生效**（核了代码逻辑＋单测）：
  - `stack_tier(a)`（[fest_ring.gd:171-178](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_ring.gd#L171-L178)）限定 `a is XActor` 且仅检查 `a.equip_list()`（不看队友与背包，欢庆 `tier=0` 返回 `-1`）；全游戏角色只有一个戒指栏位 `etypeId == 10`（[System.json `equipTypes`](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/generated/db/System.json)、[actor.gd:164-170](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/actor.gd#L164-L170)），即便特殊情景同时戴两枚也只取 `STACK_STEP` 较高档，不自叠。

---

### 2）存档防刷四处＋全途径排查＋天启篇守门

- **防刷四处逐处核查**：
  1. **跨存档星级仓库拒收**：`XFestRing.build`／`secure`（[fest_ring.gd:123-124,155-157](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_ring.gd#L123-L124)）同时写入实例 `meta["PushDct"] = true` 与备注 `<PushDct>`。核对 [star_warehouse.gd:104-114](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/star_warehouse.gd#L104-L114)，`push_dct(rec)` 在 `meta is Dictionary` 时只查 `meta.has("PushDct")`，命中则 `deposit_gear` 返回 `"不可存放"`、不写盘不消包。（同档内 `PH_Warehouse` [warehouse.gd](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/warehouse.gd) 不跨存档。）
  2. **法宝喂装备拦截**：[fabao_feed.gd:59-60](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fabao_feed.gd#L59-L60) 在 `is_locked` 之后单独判断 `XStarWarehouse.push_dct(item) or XFestRing.is_ring(item)`，拒绝原因 `"限定装备无法喂入"`；`feed`、`eligible`、`feed_grade` 与 `ui/item_scene.gd` 菜单全部走 `reason()`，故手动解锁后依然不可喂。
  3. **发放即默认锁定**：`XFestRing.grant` -> `secure`（[fest_ring.gd:155-157](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_ring.gd#L155-L157)）调用 `XItemMarks.toggle_lock(s, inst)` 加上 `"[锁定]"`。
  4. **定义常驻**：[xdb.gd:134](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/xdb.gd#L134) 无条件调用 `XFestRing.patch_armors(_tables[name])`，不受 `XFest.ENABLED` 与活动日期控制；关开关后读档，戒指定义、基础属性、成长、`一穿四`、`PushDct` 全部保留。
- **全仓其它失去／卖出／刷取途径核查**：
  - **卖出**：`price = 0`，[item_marks.gd:185,694](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/item_marks.gd#L185)（`can_sell` 与旧版一键出售／挂机自动卖 `sellable_gear`）均显式排除 `not XFestRing.is_ring(...)`；[safe_sell.gd:131-135](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/safe_sell.gd#L131-L135) 对 `price == 0` 且无卖出报酬返回 `"不可出售"`。
  - **吸收／分解／献祭／丢弃**：全仓检索 `lose_gear`／`gear.remove_at` 全部调用点，核实 [affix_absorb.gd:199-215](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/affix_absorb.gd#L199-L215)（无 `Mod特效/神话特效` 额外词条且默认锁定）、[alienation.gd:154-155](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/alienation.gd#L154-L155)（无异化标记）、[tianqi_qiyin_equip.gd:345-430](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_qiyin_equip.gd#L345-L430)（非七印装备）及 [item_scene.gd:309-321](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/item_scene.gd#L309-L321)（无丢弃入口）均无法消耗或销毁冠军戒指。
  - **存读档／换档／重复领取刷币／精魂／戒指**：所有发币、首胜、全胜、发戒、签到、限购标记、剩币兑换均绑定单局存档 `s.flags.fest_champion`；读档只会回退状态，三档各自独立计数且仅发一次（总上限 750 币，限购 480 币，剩币按 `10 币 -> 1 万精魂` 扣除后发放）。收尾期过后多次读同一未保存旧档虽会反复在内存里执行 `convert_leftover`，但每次都从同一份读档原币值扣除且不叠写磁盘（幂等），保存后即不再重复转换。跨存档导档复制同档仍受星级仓库拒收限制，无法汇聚到主档（同设计稿第 3 节）。
- **独立抽查两处确认（只读临时验证脚本，不改仓库代码）**：
  - 通过临时脚本 `scratch/verify_antifarm.gd` 在 Godot Headless 下独立实测：
    1. **抽查防刷①**：真实发放的 `r1` `XStarWarehouse.push_dct(r1) == true`、`deposit_gear(s, r1) == "不可存放"`；把内存副本 `r1.meta["PushDct"]` 删掉但保留备注 `<PushDct>` 后，`XStarWarehouse.push_dct(broken)` 立刻变成 `false`，实证「只写备注、不写死 `meta["PushDct"]`」确会被仓库放行。
    2. **抽查防刷②**：发放后 `is_locked == true`；手动调用 `XItemMarks.toggle_lock(s, r1)` 解锁后，`XFabaoFeed.reason(s, fabao, r1)` 仍返回 `"限定装备无法喂入"`、`eligible` 不含该戒指、`feed` 消耗 `0` 件；对照组同品质（quality 6）非限定防具 `ctrl_armor` `reason == ""`，实证拦截逻辑确实咬住。
- **天启篇存档守门**（[fest_lobby.gd:217-224,276-277](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/fest_lobby.gd#L217-L224)、[fest_reward.gd:153-199](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_reward.gd#L153-L199)、[fest_road.gd:510-513](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_road.gd#L510-L513)）：
  - 使者先判 `XFestReward.tianqi(s)`（即 `XTianqi.active(s)`），仅调用 `tianqi_gift(s)` 发称号 `43`「冠军观赛团」＋成就 `144`「我在现场」，不给币、精魂、门票、戒指，不弹签到／兑换菜单；`menu`/`sign_in`/`shop_open`/`XFestRoad.talk` 全部拦截天启篇存档，`give_gift` 也先分流 `tianqi_gift`。真守住。

---

### 3）`levelCap 60` 与 `8010～8012` 常驻定义对旧存档的影响

- **`levelCap 60` 影响**（全仓检索 `levelCap`／`customParams` ＋核对 [actor.gd:440-451,508-540,1256-1273](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/actor.gd#L1256-L1273)）：
  - `levelCap` 仅在 `XActor.custom_param` 读取，用于在求装备 `<Custom Parameters>` 成长加成时把等级项夹为 `minf(_lv, cap)`（欢庆戒指 60 级后物攻／魔攻固定封顶 `+60`）。
  - `exp_for_level`、`max_level`、`change_level`、`change_level_mv`、`gain_exp` 与 `XState.to_dict`/`from_dict` 完全不读取 `levelCap` 或 `customParams`，角色可照常升级过 60 级，经验曲线与存档读写无任何副作用。
  - 原版与转换器生成的装备不含 `levelCap` 键，读取时 `float(cp.get("levelCap", 0)) == 0.0` 走原路径 `float(_lv)`；[tests/xiyou_custom_params.gd:90](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/tests/xiyou_custom_params.gd#L90) 计数排除 `_fest` 标记仅避开运行时追加件，合理。
- **`8010～8012` 常驻定义不影响旧存档**（核对 [Armors.json](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/generated/db/Armors.json) 原表长 `8001`＋[gear.gd:97-145](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/gear.gd#L97-L145)）：
  - 编号在 `8001` 之外追加，不挤占原有防具，也不进任何商店／掉落／抽奖池；三枚戒指 `variance=0`、`slotVariance=0`、`affixes=[]`、`slots=6`，多次发放数值与 6 孔完全一致（已在 `xiyou_fest_reward` 实测确认）。

---

### 4）两处「按默认」实现的合理性评估

1. **符文按等级 `top_level` 挑档（[fest_reward.gd:114-127](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_reward.gd#L114-L127)），设计稿 2.4 写「按存档最高到达层」**
   - **意见：基本合理，推荐保留，但可考虑小改取全体队员最高级**。
   - 理由：四个副本挑战符文在 [Items.json](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/generated/db/Items.json) 本身标称等级段（`24` 10～20 级、`64` 20～30 级、`110` 30～40 级、`171` 40～50 级）。相比「最高到达层（变量 20）」，按角色等级更贴合实际战斗力（卡层但练了级的不会拿到过期低级票，速通低级档也不会拿到打不动的票），且限量最多共 6 张（贺礼 2＋店购 4），无刷资源风险。唯一边角见 P3-1（出战栏放低级新号而主力在后备时 `battle_members()` 会低估队伍等级，改成 `s.members()` 更稳妥）。
2. **三档四关全胜都发称号 `41`「冠军之路」（`45`「冠军之路·洪荒」并进 `41`）（[fest_road.gd:83-86](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_road.gd#L83-L86)、[fest_reward.gd:256-257](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_reward.gd#L256-L257)）**
   - **意见：完全合理，赞成保留**。
   - 理由：让大众玩家打通欢庆档就能拿到主称号「冠军之路」，降低参与挫败感；高难档位通过各自独立的不败称号（`47`「一穿四·天灾」橙、`46`「一穿四·洪荒」金红）与传说／不朽冠军戒指已经足够拉开荣誉区分，同时避免「冠军之路」与「冠军之路·洪荒」两个普通全胜称号冗余。`45` 从未对外发布过，读档补 `41` 兼容无害，且 `41～44` 编号未动。

---

### 5）文字审（交付单新增可见文字清单＋源码全量复核）

- **核查范围**：[fest_text.gd](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_text.gd)、[fest_ring.gd](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_ring.gd)（`RINGS`/`note_of`）、[fest_road.gd](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_road.gd)（`intro_lines`/`tier_labels`/`TIERS`/`run`/`talk`）、[fest_reward.gd](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/fest_reward.gd)（提示条与拒绝原因）及 [Plugins.json](file:///Users/kyo/orca/workspaces/再刷项目资料库/fest-champion-road/03_再刷重制_Godot/01_Godot工程/modes/xiyou/generated/db/Plugins.json)（确认 `"节日"` 在 `AchievementTypeList` 中）。
- **底线与文风核对**：
  - 通顺白话，无病句错别字；
  - 真实名称仅出现在 `XFest.CONGRATS` 一处，无真实选手、队标、赛事官方名；
  - **无西游人物与西游典故**（「欢庆／天灾／洪荒」为游戏通用难度与活动档位名）；
  - 与数据库实体及数值口径一致（如不朽碎片说明「卖给商店换成深渊货币」、深渊派对邀请函「30～50 级深渊派对的门票」、肝帝积分抽奖券「方桌大厅赌场用的抽奖券」、三枚戒指属性与特效显示行全部与代码实际数值一致）。
- 仅存在 P3-2/3/4 三处轻微润色/口径点，无实质硬伤。

---

### 6）本轮实跑检查与「核规则 vs 看代码」边界清单

#### 已前台独立实跑（全部通过）

- `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：`954 个 .gd，0 个问题（39 秒）`
- `./03_再刷重制_Godot/07_开发环境/godot --headless --path 03_再刷重制_Godot/01_Godot工程 res://tests/xiyou_fest_reward.tscn`：**`42/42` 通过**
- 只读临时脚本 `scratch/verify_antifarm.gd`（不改仓内文件）：独立验证防刷①（删 `meta["PushDct"]` 后 `push_dct` 失效）与防刷②（解锁后 `XFabaoFeed.reason` 仍拒喂、对照组正常品质防具可喂）

#### 明确区分：核了规则本身 vs 只看了代码

- **核了规则本身（对照 `v0.3.1` 设计稿、底层源码与实测）**：
  1. 伤害公式 `finalAdd`/`finalMultiplier` 叠乘机制与总账登记（`damage.gd`、`module_registry.gd`、`actor_damage_hooks.gd`、`damage_ledger.json`）；
  2. 防刷四处及全仓 `lose_gear`/`gear.remove_at`/`can_sell`/`sellable_gear` 全部出口排查 + 独立验证①②；
  3. 数据库基准对照（`Items.json` `24/64/110/171/179/180/1639`、`Armors.json` `245/8001`、`Enemies.json` `72/529`、`Troops.json` `69/462`、`Skills.json` `906`、`Plugins.json`、`System.json`）；
  4. `levelCap 60` 与存档序列化（`actor.gd`、`xstate.gd`、`gear.gd`）；
  5. 两处按默认实现评估与全部新增可见文案逐条审校。
- **只看了代码／未本轮执行（留给总装）**：
  1. **长测试与其余受影响单测（留给总装）**：
     - `xiyou_fest_road`（66 项）、`xiyou_fest_lobby`（121 项）、`xiyou_designation*`、`xiyou_achievement*`、`xiyou_custom_params`、`xiyou_event_compare*`、`xiyou_flow`、`xiyou_actor_modules`、`xiyou_tianqi_ledger`、`xiyou_fabao_rework`、`xiyou_star_warehouse`、`xiyou_item_marks`、`xiyou_hangup_auto`；
     - `03_再刷重制_Godot/07_开发环境/选测.py`、`并行测试.py`、`检查.sh --full`（及按需 `--oracle`）。
  2. **未真机／有头窗口实测项**：
     - 图标索引（`1532/2267/2817/1469/2506/2607/1800`）真窗渲染效果、大厅/战斗场景视觉表现；
     - 天灾／洪荒档用后期真实原版存档实打调优（交付单已知事项）；
     - **推前必做**：出安卓导出包真机冷启动验证新增 `class_name`（`XFestRing`、`XFestReward`、`XFestRoad`）无 `SCRIPT ERROR`。
