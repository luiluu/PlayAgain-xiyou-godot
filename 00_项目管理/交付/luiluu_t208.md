# 交付：luiluu/t208

- 车道／工作者：T208 大型变身行动时指令菜单让开身体＋T197 小A P2-2（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-18 【cc·天启篇·未经审查】T208 大型变身行动时指令环与战技／物品列表让开身体＋头顶宝石逃跑时不再闪现（dev.待定）

- Kyo 11-18「战斗中指令栏会挡住大型精灵」→「指令栏按A」。`battle_scene.gd` 新增 `make_room_for_big`（在 `_place_near_actor` 新界面那支最后调）：行动者外观键含 `XBattleLayout.BIG_FORM_KEYS` 且 `BIG_FORM_H` 大于普通身高时，指令环（各项＋上方「某某的行动」，加 6px 放大余量）或战技／物品列表若压到其身体可见框（脚底居中、`width()`×`height()`）：① 外侧＝整块左挪到右边离身体 8px（压左下行动顺序条就抬到条上方），指令环另要求不压队友、首领信息区、队伍面板；② 不行就放画面下方中间（贴底、横向居中，压行动顺序条往右让，再压身体就贴身体左边抬到条上方）。普通大小角色一步不挪。回退：`XBattleScene.BIG_MAKE_ROOM = false`。没碰 `battle_layout.gd`。
- 实测 4 人队（狗逍遥、里德、渡鸦神话、米拉黑龙）首领战、小怪战：两只大型变身的外侧都压前排队友，指令环都落到画面下方中间（x 573 起，避开行动顺序条）；只 2 人（狗逍遥＋米拉黑龙）时走外侧。列表走外侧（列表照原摆法本来就盖前排、首领信息区，只躲行动顺序条）。
- T197 小A P2-2：`turn_marker.gd` 两个开关——`HOLD_WHILE_HIDING`：`set_target(null)` 后等 HIDE_DELAY 那段只许保持或变淡、不许淡入（逃跑成功关窗后不再闪出来，两次行动之间也不闪）；`HIDE_ON_MESSAGE`：战斗消息窗开着（逃跑失败两行等）当作挡住。回退：两个都设 false。
- 新专项 `tests/xiyou_big_form_menu`（无头 86/86，窗口 90/90）：大型变身指令环、8 行列表不压身体、不出屏、不压行动顺序条；外侧时不压队友、下方中间时贴底；狗逍遥、里德指令环与列表位置跟开关关逐像素相等；开关关时龙身确实被压（咬得住）；触屏跟角色摆法同样不压；宝石菜单开淡出／关淡入照旧；P2-2 等淡出时峰值 ≤0.01、开关关会闪（>0.05，咬得住）；消息窗开着挡住、关掉回来。
- 玩家可见：米拉黑龙、渡鸦神话行动时，指令菜单和技能列表不再盖住它们的身体（挪到旁边或画面下方中间）；逃跑时角色头顶的红宝石不再闪一下。

## 交接板

- 下一步：协调把附图两张（`luiluu_t208附图/T208_首领战_米拉黑龙行动_指令环.png`、`…渡鸦神话行动_指令环.png`，1280×720 原尺寸）给 Kyo 审样；另两张战技列表展开图供参考。
- 用户试玩说明：天启篇米拉黑龙／渡鸦神话变身后轮到它行动，看指令环是不是不再压身体。
- 需要用户决定：无（4 人满队时两只大型变身的指令环都落到下方中间，是 Kyo 选 A 时说的兜底；若觉得应该优先别的位置再提）。

## 待交叉核查附注

- 甲档核查（小A）时顺带文字审（派单第 8 条）：变更记录 T197 条的玩家可见句「战斗里米拉黑龙、渡鸦神话变身后明显比人物高大（约 200 像素）」，以及 3d799e47c 交付单整理；本条玩家可见句也待小A 审。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- `并行测试.py`（合 main 后）：xiyou_big_form_menu、xiyou_battle_actor_size、xiyou_ring_seven_battle、xiyou_party_fold、xiyou_ui_skin_battle、xiyou_ui_skin_battle_v07、xiyou_ui_skin_4a、xiyou_ui_skin_close、xiyou_tianqi_swap_view、xiyou_determinism、xiyou_battle_ui、xiyou_battle_layout、xiyou_flow、xiyou_mira_art、xiyou_raven_fx、xiyou_game_over、xiyou_hangup_stop、xiyou_big_form_sizes、xiyou_ui_sel_scale：19/19 通过。
- 选测.py 列出 154 个场景（battle_scene.gd 被广泛引用，含事件对照、楼层），车道只跑了上面与战斗界面相关的 19 个；其余留总装按影响面选测。
- 语法检查通过；工具回归通过。

## 本分支提交

- e09b7cffc T208 代码与专项
