# 交付：cc/bailong-yunshang9

- 车道／工作者：E 角色专属／白龙_12（cc）
- 状态：可合并（选测里 xiyou_determinism 1 处失败是 main 带来的，见「验证」）
- 分支从 cc/bailong-yunshang8 末端 b6251518 切出（总装十派单）；yunshang8 已进 main，交付前合了一次 main（909f5638，干净自动合并），合进来的提交改了切片，已重跑 `--补齐`。
- 范围：云裳天衣铺二期——订单账本、制作、领取、回合进度、不朽天丝、角色进阶；九曲回针选针眼只列有冷却的技能（O-待定，总装十同意做成回退开关）。

## 变更记录草稿

## 2026-11-01 【cc·白龙_12·未经审查】云裳天衣铺二期：订单账本、制作、领取、进阶（dev.待定）

照原版 installNativeYunshangRuntime.js 第 94～200、235～244、519～590 行，新文件 `core/yunshang_orders.gd`（`XYunshangOrders`）：

1. **订单账本**：存档目录旁的独立文件 `yunshang_orders_v1.json`（原版同名，放 StorageManager 存档目录），整份写、先写临时文件再改名；存档只记本档编号 `flags._yunProfile` 和已重放到第几条 `flags._yunSeq`。改账本一律复制整份→改本档那条→写盘→重放（物品增减、发天衣、移除天衣，最后把云裳的进阶次数设成账本的并同步技能）。所以开工后读早先的档，天丝照扣、订单还在，不能重抽；领取后读更早的档天衣照发。读档（`XSave.load_slot`）后重放；出错只记下，普通读档照常。原版新局开局就建本档那条，重制等第一次用账本（天衣铺、不朽天丝）才建；读没有编号的档时只在账本里已有它的旧档身份（第几格＋文件 sha256）时才重放，不新建。
2. **制作**：35 级起、没有订单、制作池非空（按等级与进阶开放的 15 件天衣）、不朽天丝 2942 至少 15 份。随机选一件（装备随机数），底子是那件天衣，八项换成需求等级最高的布衣模板（4282 如来的袈裟）的、特性清空，属性浮动用模板的 Random Variance（150）；名字改回天衣名、记 `_yunUid`，开工时就排好镶嵌孔。扣 15 份、记订单。`XGear.create` 拆出 `roll_item`（对备好的模板掷词缀、浮动、插槽）给它用。
3. **回合进度**：云裳在出战成员里时每回合末（endTurn 包装，同一回合只记一次）记 1 格，token「本场编号:回合数」不重记，满 10 格可领。本档还没有账本编号时不记（不可能有订单，原版这里会建一条空的，重制不平白写文件）。
4. **领取**：满 10 格，把订单那件天衣发进背包、清订单。
5. **不朽天丝**（endBattle 包装，胜利、每场一次）：不朽的未知战斗——地图与敌群在原版 unknownBattles 里，来源地图在 immortalOrigins（来源地图由 Game_Map.setup 包装记在 `flags._yunUnknownOrigin`；没记时 152／176 用 Leviathan 记的来源，再没有看 unpaired 或难度变量 107）。天丝 +1；云裳出战且学了天丝成锦 10280 时另记 bonusClears，偶数次多 1 份。
6. **角色进阶**：天衣铺首页「角色进阶」开进阶页，关掉回首页。进阶页对云裳换掉三处（原版三个包装）：底部确定时底部窗关掉，条件不够（等级、人道意志碎片 2530 ×50／×188、背包天衣 3／9 件，穿着的不算）蜂鸣＋提示原因；够了在画面正中逐件选天衣（「选择进阶所需天衣 n/N」灰行＋「名字　编号K」，编号按背包次序），选够开确认窗「消耗N件天衣，确认进阶」；确认后扣碎片、移除所选天衣、账本进阶 +1，提示「云裳完成第N次进阶」，不走进阶表那一行的学技能、扣金钱。状态窗还有下一阶时第 12 行起写「背包天衣×N（确认时选择）」「已装备的天衣须先卸下」（18 号字）。
7. **天衣铺首页**：订单行「制作中：名字　n/10回合」；制作、领取、进阶按原版条件能选；制作、领取出错提示原因。账本不可用（文件坏了、本档记录缺失）时换成兜底页「制作记录暂不可用，请恢复配套记录后重试」＋返回。
8. **重制补的迁移**：给还没有账本编号的存档建账本那条时，进阶次数取存档里云裳当前的（原版一律 0），旧档已进阶的不归零。
9. **九曲回针选针眼（O-待定）**：默认只列有自己冷却的技能，见优化登记草稿。
- 参照：`yunshang_probe.cjs` 加 p8（8 个用例）：制作两种随机数（0.5／0.1）→读开工前的档→进度→领取→再读最早的档、开放条件与提示、真战斗回合末进度与不在队伍、不朽天丝 11 种情形、进阶页（拦 Scene_ActorAdvanced 建不进场景树的实例，按原版处理器走选天衣与确认）、兜底页。参照里 uuid 用 Math.random，固定 0.5 时同一毫秒的编号全一样，进阶那步临时换成会变的数。

## 优化登记草稿

| O-待定 | 云裳天衣铺九曲回针选针眼（`ui/yunshang_shop.gd`，installNativeYunshangRuntime 第 530 行） | 原版想只列有冷却的技能（`s.cooldown`），可 YEP_X_SkillCooldowns 给每个技能都建了 `cooldown` 对象，条件恒真，没冷却的技能也能选成针眼（针眼只是醒着时每回合越过一次冷却，选了没用） | 只列有自己冷却的技能（`<Cooldown: x>` x>0 或 `<Cooldown Eval>`，不在 Cooldown Bypass 里）；角色一个都没有时列表为空 | 选项里一半以上是选了没效果的 | `XYunshang.o_eye_cooldown = false` | cc（白龙_12） | 待用户确认 |

白龙_11 那条变更记录（2026-11-01 云裳天衣铺一期）的「优化登记草稿：无（针眼…照抄…）」已被这条取代，总装合并时可顺手改成指向 O-号。

## 验证

- 专项 xiyou_yunshang_shop 279/279：一期 p7 照旧（针眼照原版时 `XYunshang.o_eye_cooldown = false` 比参照；默认时 1 号那四个技能都没冷却、列表为空，教他青龙斩后只列它）＋二期 p8 七组：制作两种随机数的天衣（名字、底子、八项、插槽、品质、浮动）、存档→制作→读档（天丝 5、订单在、_yunSeq 1）→进度 9／10→领取→读档（天衣照发、_yunSeq 2）；开放条件 6 种；真战斗（XBattleLogic）回合末进度 [1,1,2]、不在队伍 [0,0,0]；不朽天丝 11 种；进阶页按键走一遍（提示、选天衣页、取消、灰行、确认窗字、进阶后碎片／天衣／技能／账本、两次进阶后的提示）；兜底页。
- 反向验证 11 处全抓到：读档不重放、八项不换模板、同 token 重记、偶数次不多给、编号不按背包次序、穿着的也算、152 不看 Leviathan 来源、没有兜底页、针眼不筛、确认窗不换字、进阶不移除所选天衣。
- 语法检查通过。回退开关：o_eye_cooldown 在专项里赋了回退值。
- 选测（CHECK_JOBS=3，38 个场景写全名，和别的车道共用测试槽，34 分钟）：35 个过，3 个失败——
  - xiyou_yunshang covers_all：p8 归天衣铺专项比，加进「别处比」那一档（已改，1584/1584）。
  - xiyou_flow save_roundtrip：读档时给没有编号的存档建了账本那条、写进 flags，存档读回再存多了 `_yunProfile`。改成读档时只在存档有编号、或账本里已有这个旧档身份时才重放，不新建（已改，48/48；读档类 autosave、battleback_save、save_events、save_page 重跑都过）。
  - **xiyou_determinism early_inventory_rule（371/372）不是本分支的**：把本分支改过的 7 个工程文件换回 main 的版本单跑，同样失败；应是合进来的战斗掉落改动（99033789「战斗掉落照原版 0.2 底…」）让这处早杀掉落不再出装备。请总装转给掉落那条车道。
  - 其余 35 个：xiyou_yunshang_ui、xiyou_yunshang_shop、xiyou_autosave、xiyou_battleback_save、xiyou_save_events、xiyou_save_page、xiyou_common_scripts、xiyou_script、xiyou_panels、xiyou_options_basic、xiyou_options_misc、xiyou_race_menu、xiyou_power_books_menu、xiyou_help_card、xiyou_battle_ui、xiyou_battle、xiyou_smart_ai、xiyou_smart_ai_b、xiyou_smart_ai_c、xiyou_smart_ai_d、xiyou_actor_modules、xiyou_actor_advanced、xiyou_advance_reads、xiyou_alien_battle、xiyou_equipment、xiyou_gear_ui、xiyou_item_bag、xiyou_orbs、xiyou_garou_progress、xiyou_floor_unknown160、xiyou_floor_unknown210、xiyou_floor_unknown223、xiyou_global_vars、xiyou_random_streams、xiyou_event_compare 全过，没有偶发。

## 交接板

- 下一步：云裳只剩天衣铺零碎——天衣图标（Yunshang_Icons）、织神天梭升级经验（relicNextLevelExp、relicDisplayParams）、天衣说明文字刷新（refreshYunshangText）、卖掉／丢弃带 `_yunUid` 的天衣时记进账本（见「可优化」）。
- 用户试玩说明：天衣铺能制作、领取天衣了：35 级起花 15 份不朽天丝开工（不朽的未知战斗胜利给天丝），云裳出战每回合推进 1 格，10 格后领取；开工时属性就定了，读档不重抽。「角色进阶」能用背包里的天衣给云裳进阶（35 级 3 件＋50 碎片，50 级 9 件＋188 碎片，穿着的天衣要先卸下）。订单记录在存档目录的 yunshang_orders_v1.json，跟存档一起搬。
- 需要用户决定：O-待定（针眼只列有冷却的技能，默认开）。

## 进度账

- 角色与专属机制：云裳完成度 0.93 → 0.97（制作、领取、进阶、不朽天丝；剩图标、织神天梭升级、说明文字、卖天衣记账），按工作量估。

## 可优化（流程／工具／效率）

- 发现（原版写法，没做）：原版 gainItem 包装在带 `_yunUid` 的天衣被卖、丢弃时也记一条移除，读更早的档时一并移除，防领取→卖掉→读档再领。重制装备离开背包的地方十几处（商店、分解、仓库、异化、各角色模块），这一期没接；现在领取后卖掉、再读领取前的档会再发一次。要接的话在 XState 加一个统一的「装备离开背包」出口最省事，建议派给管 xstate 的车道。
- 发现（工具，已做）：探针里 uuid 靠 Math.random，固定 0.5 时同毫秒编号全一样，凡是一步里生成多个编号的（进阶选多件天衣）要临时换成会变的数，否则原版只移除得了一件；已写进探针注释。

## 待交叉核查

- 新文件 `core/yunshang_orders.gd`（账本、制作、领取、进度、不朽天丝、进阶规则）。
- 共用核心文件：`core/gear.gd`（`create` 拆出 `roll_item`，行为不变）；`core/xsave.gd`（`load_slot` 读完调 `XYunshangOrders.after_load`）；`battle/battle_logic.gd`（`XYunshang.end_battle(self, result)` 传胜负）；`map/map_scene.gd`（地图切换调 `XYunshangOrders.on_map_setup`）。
- `core/yunshang.gd`：start_battle／end_turn／end_battle 接账本；`o_eye_cooldown`、`eye_candidate`。`ui/yunshang_shop.gd`：首页、兜底页、进阶入口、针眼筛选。`ui/actor_advanced.gd`：云裳的底部确定、选天衣、确认、状态窗两行。
- 留意：账本文件跟 XGlobalVars 的 global.json 一样放在 `XSave.dir()`，测试改了 dir_override 就跟着走；没改的测试只在用到账本时（读档、不朽天丝、天衣铺）才写。重放时会把云裳的进阶次数改成账本的——测试里直接改 `actor_advance[174]` 再走天衣铺，要先 `XYunshangOrders.transaction(s, func(p): p.stage = n)`。

## 本分支提交

- 31f2689d 参照 p8（WIP）
- e351443e 重制二期（WIP）
- 53314e88 专项 279/279（WIP）
- 76970dd8 合 main
- 本提交：选测后修 covers_all 与读档不新建账本条，交付单可合并
