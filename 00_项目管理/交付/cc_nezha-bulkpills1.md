# 交付：cc/nezha-bulkpills1（哪吒_12 起，哪吒_13 接续，批量服用丹药 BulkPills）

- 车道／工作者：C 规则·机制／哪吒（cc，哪吒_12 探针；哪吒_13 逻辑、入口与专项）
- 状态：可合并

## 变更记录草稿

## 2026-11-01 【cc·哪吒·未经审查】批量服用丹药：数量窗＋逐颗服用；补上效果 42「成长」（dev.待定）

- 原版 `installBulkPillsRuntime`（CodexBulkPills v1）：43 个丹药（凝血～九转 1685～1717 去掉 1701、养神丹 1726～1728、法宝经验丹 1901～1908、1987、1997）在物品页「使用」时改开数量窗，确定后逐颗服用。新逻辑 `XBulkPills`（`modes/xiyou/core/bulk_pills.gd`）：
  - 支持判断照原版：名单内、可消耗、普通物品；带公共事件的只认原版写死的那一个，而且事件指令逐条和原版审过的结构一致（提示脚本用同一条正则），否则整颗不支持、走原来的单颗使用。
  - 逐颗：库存与支持再查 → 使用者（可行动角色中 pha 最大者）→ 对队友的至少一个目标有效 → 消耗、对目标逐效果、效果 44 预约公共事件。这一颗期间的预约先收集，审过的当场跑完（不被下一颗盖掉单槽），没审过的连同后面的按先进先出交给地图，批量停下。结束原因照原版中文：已有预约、库存不足、没有可用角色、目标无法继续服用、后续事件交由地图执行。
  - `XState` 加一颗期间的预约收集（`capture_common_events`）和没审过事件的排队（`defer_common_events`，槽被取走时 `clear_common_event` 补上下一条；不存档，同原版 `$gameTemp`）。
- 物品页入口（`ui/item_scene.gd`）：在原本「使用」的那一步开数量窗（对队友的选人确定后，不对队友的直接开）：居中 456×8 行，「服用数量」、名字、× 数量、「持有：N 颗」、按键说明；左右 ±1、上下 ±10，夹在 1～库存；鼠标左键确定、右键取消、滚轮 ±1。确定后播一次使用音效逐颗服用，结束提示「已服用 名字 × N；剩余 N 颗（原因）」；还有库存且对队友时留在选人，否则回列表；有预约的事件就回地图。库存为 0 或已有预约时蜂鸣并提示「丹药库存不足」「请先完成当前道具事件」。
- **补上效果 42「成长」**（`battle_logic._apply_effect`）：原版 `itemEffectGrow` 对目标 `addParam(dataId, floor(value1))`。重制之前漏了这一种效果，丹药（单颗吃也一样）、仙馐果 978／烟罗果 979 这些成长物品吃了不加能力；现在走 `XActor.add_param`（和事件 317 同一份永久加成账本）。战斗里也有 4 个技能带这种效果（5744 月下遛鸟、7033／7034 魂士／魂师、8201 加固），现在和原版一样施放时永久加能力；敌人没有永久加成账本，对敌人不做（原版敌人加的是 `_paramPlus`，战斗结束就没了）。
- 原版 `fullyLearned`（万灵增元丹 1497～1500 目标已学会时提示「目标已学会…」）不做：它在 `Scene_Item.useItem` 里，但 `onActorOk` 先看 `canUse`，已学会时 `testApply` 为假直接蜂鸣，正式版走不到（参照 learned 例）。重制物品页同样蜂鸣。
- 参照：`mv_oracle/bulk_pills_probe.cjs`（9 例：支持名单与改坏事件、7 个服用例、已学会），产物在 `tests/fixtures/bulk_pills_oracle.json`（没接全量同步，同 param_max）。专项 `xiyou_bulk_pills` 103 项。
- 回退：批量服用是原版功能、效果 42 是重制漏做，都不是优化，没有开关。要关掉批量服用，把 `XBulkPills.supports` 改成恒 false 即回到单颗使用。

## 待交叉核查

- 甲档：`battle_logic.gd`（原归沙僧的核心文件）新增效果 42；`xstate.gd`（同）预约收集与排队。请重点核：8201 加固等 4 个战斗技能现在会永久加能力，是不是和原版一致（原版 `Game_Action.itemEffectGrow` 不分战斗内外）。
- 乙档：`bulk_pills.gd`、`item_scene.gd` 入口、`xiyou_bulk_pills.gd`。

## 验证

- 专项 `xiyou_bulk_pills` 103/103。反向验证：`approved_event` 改成全放行时 tampered 例和「没审过事件」例失败（2 项）；改成全拒时 1685 等全部带事件的例失败；拿掉效果 42 时各例 after.param 失败。
- 语法检查通过。
- 合 main（到 bbeecb5b）后 `--补齐`，选测 26 个场景（并行 3）：`xiyou_bulk_pills`、`xiyou_item_use`、`xiyou_item_list`、`xiyou_item_marks`、`xiyou_book_capacity`、`xiyou_book_capacity_ui`、`xiyou_magic_weapon.tscn`、`xiyou_magic_weapon_level`、`xiyou_power_books*`、`xiyou_pets.tscn`、`xiyou_actor_book*`、`xiyou_enemy_book.tscn`、`xiyou_floor_reach041`、`xiyou_param_max`、`xiyou_param_cache`、`xiyou_param_states`、`xiyou_custom_params`、`xiyou_transform_params`、必跑 `xiyou_event_compare` 与 `xiyou_rules.tscn xiyou_rules_d1b.tscn xiyou_rules_d1c.tscn xiyou_rules_d1d.tscn`：24 个通过。
  - `xiyou_bulk_pills` 第一次因退出时有一个页面没释放（「resources still in use」）判失败，改成共用一个页面最后释放后单跑通过（77 秒，无报错）。
  - **`xiyou_event_compare` 失败 `m4e1p2`、`m4e1p3`，不是本分支引起的**：大厅奥尔夫尼（Map004 事件 1）第 2、3 页，重制多出一个「\I[0]???」的选项列表，原版没有（像是称号一、二期接上「更换称号」后的结果）。把本分支改的 `battle_logic.gd`、`xstate.gd`、`item_scene.gd` 换回 main 的版本单跑，同样这两条失败，所以是 main 上 bbeecb5b（合并 cc/wukong-title2）带来的；title1／title2 交付单的验证里没有跑事件对照。请总装派给称号车道。

## 交接板

- 下一步：界面车道照原版补数量窗样式（`Window_BulkPillNumber`：不透明底、底色 #111827 填透明像素、触控按钮在 lh×5+12；现在用的是通用窗皮、无触控按钮）。原版结束提示写在 `_helpWindow`，重制物品页没有顶部说明栏，现在发右上角提示；要不要改成说明卡由界面车道看。
- 用户试玩说明：物品页吃丹药（凝血丹等四档丹药、养神丹、法宝经验丹）会弹「服用数量」窗，可以一次吃很多颗；吃丹药现在真的加最大生命等能力了（之前漏了）。
- 需要用户决定：无

## 进度账

- 物品与菜单：批量服用丹药 0% → 逻辑与入口完成，样式待界面车道。

## 可优化（流程／工具／效率）

- 建议：参照夹具 bulk_pills／param_max 都是手工从 `.sandbox` 拷进 `tests/fixtures`，没接全量同步；可以给同步加一张「只拷不比」的探针名单，探针改了会自动刷新夹具（预计省每次手工拷与漏拷，归工具车道）。
- 并行测试前缀：`xiyou_rules` 不带 `.tscn` 会扩成 23 段，本轮差点整轮跑；车道须知已写，但并行测试可以在匹配数远超其他名字时先提示（现在只在超过 40 时停），归工具车道。

## 本分支提交

- 7576391f 探针与参照夹具（哪吒_12）
- e35fc8fa WIP 交付单（哪吒_12）
- 67897097 XBulkPills、物品页数量窗、效果 42、专项（哪吒_13）
- 合并 main；专项退出时释放页面；交付单可合并（哪吒_13）
