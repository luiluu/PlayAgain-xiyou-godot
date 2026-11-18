# 交付：luiluu/t208

- 车道／工作者：T208 大型变身行动时指令菜单让开身体＋T197 小A P2-2（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-18 【cc·天启篇·未经审查】T208 大型变身行动时指令环与战技／物品列表让开身体＋头顶宝石逃跑时不再闪现（dev.待定）

- Kyo 11-18「战斗中指令栏会挡住大型精灵」→「指令栏按A」。`battle_scene.gd` 新增 `make_room_for_big`（在 `_place_near_actor` 新界面那支最后调）：行动者外观键含 `XBattleLayout.BIG_FORM_KEYS` 且 `BIG_FORM_H` 大于普通身高时，指令环（各项＋上方「某某的行动」，加 6px 放大余量）或战技／物品列表若压到其身体可见框（脚底居中、`width()`×`height()`）：① 外侧＝整块左挪到右边离身体 8px（压左下行动顺序条就抬到条上方），指令环另要求不压队友、首领信息区、队伍面板；② 不行就放画面下方中间（贴底、横向居中，压行动顺序条往右让，再压身体就贴身体左边抬到条上方）。普通大小角色一步不挪。回退：`XBattleScene.BIG_MAKE_ROOM = false`。没碰 `battle_layout.gd`。
- 协调预筛返工：P1-1 列表往左挪后表头被首领信息区「详情」胶囊盖住——列表（外侧、下方中间两档）都要让开首领信息区：顶边压到它下沿以下 8px，底边再碰行动顺序条／画面底就减行数滚动（`XSkinBattleSkillList.fit_rows`，选中行保持可见）。P2-1 样张假数据——专项改用真实技能表（照指令环上技能类指令过滤，取技能最多那类，标题＝指令名），渡鸦满进阶学全真实技能（渡鸦那张标题是「魔法」，她的六招都在魔法类）；两张列表样张重截。P3（列表盖前排两个小队友）照协调不改。
- R2（Kyo 11-18「指令环位置不行。我还是要在精灵身边。哪怕挡一下别的角色」）：指令环只躲自己的身体——贴身体左边（压首领信息区就往下挪、压行动顺序条就往上抬），左边不行再贴右边，两侧都不行才落下方中间；压前排队友不再算放不下。开关 `XBattleScene.RING_BESIDE`（false＝回 R1：压队友就落下方中间）。实测 4 人队（狗逍遥、里德、渡鸦神话、米拉黑龙）首领战、小怪战：两只大型变身的指令环都贴在身体左边（米拉盖里德，渡鸦盖狗逍遥、里德）；只 2 人时同样贴左边。列表保持 R1（Kyo 没意见）：贴身体左边、让开首领信息区、只躲行动顺序条。
- T197 小A P2-2：`turn_marker.gd` 两个开关——`HOLD_WHILE_HIDING`：`set_target(null)` 后等 HIDE_DELAY 那段只许保持或变淡、不许淡入（逃跑成功关窗后不再闪出来，两次行动之间也不闪）；`HIDE_ON_MESSAGE`：战斗消息窗开着（逃跑失败两行等）当作挡住。回退：两个都设 false。
- 新专项 `tests/xiyou_big_form_menu`（无头 110/110，窗口 114/114）：大型变身指令环、真实技能列表不压身体、不出屏、不压行动顺序条，列表不压首领信息区、减行数后选中行可见；指令环贴身体左边或右边、不压首领信息区，RING_BESIDE 关时落下方中间（咬得住）；狗逍遥、里德指令环与列表位置跟开关关逐像素相等；开关关时龙身确实被压（咬得住）；触屏跟角色摆法同样不压；宝石菜单开淡出／关淡入照旧；P2-2 等淡出时峰值 ≤0.01、开关关会闪（>0.05，咬得住）；消息窗开着挡住、关掉回来。
- 玩家可见：米拉黑龙、渡鸦神话行动时，指令菜单和技能列表改到它们身体旁边，不再盖住它们；逃跑时角色头顶的红宝石不再闪一下。

## 交接板

- 下一步：指令环两张已按 Kyo R2「要在精灵身边」重截（`luiluu_t208附图/T208_首领战_米拉黑龙行动_指令环.png`、`…渡鸦神话行动_指令环.png`，1280×720 原尺寸，4 人满队首领战），协调给 Kyo 审样；列表两张是 R1 预筛后的版本。
- 用户试玩说明：天启篇米拉黑龙／渡鸦神话变身后轮到它行动，看指令环是不是不再压身体。
- 需要用户决定：无。

## 待交叉核查附注

- 甲档核查（小A）时顺带文字审（派单第 8 条）：变更记录 T197 条的玩家可见句「战斗里米拉黑龙、渡鸦神话变身后明显比人物高大（约 200 像素）」，以及 3d799e47c 交付单整理；本条玩家可见句也待小A 审。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- `并行测试.py`（合 main 后）：xiyou_big_form_menu、xiyou_battle_actor_size、xiyou_ring_seven_battle、xiyou_party_fold、xiyou_ui_skin_battle、xiyou_ui_skin_battle_v07、xiyou_ui_skin_4a、xiyou_ui_skin_close、xiyou_tianqi_swap_view、xiyou_determinism、xiyou_battle_ui、xiyou_battle_layout、xiyou_flow、xiyou_mira_art、xiyou_raven_fx、xiyou_game_over、xiyou_hangup_stop、xiyou_big_form_sizes、xiyou_ui_sel_scale：19/19 通过。
- 选测.py 列出 154 个场景（battle_scene.gd 被广泛引用，含事件对照、楼层），车道只跑了上面与战斗界面相关的 19 个；其余留总装按影响面选测。
- 返工后：xiyou_big_form_menu、xiyou_ui_skin_battle、xiyou_ui_skin_battle_v07、xiyou_ui_skin_4a、xiyou_ui_skin_close、xiyou_ui_sel_scale、xiyou_item_list、xiyou_battle_ui、xiyou_battle_actor_size、xiyou_ring_seven_battle、xiyou_determinism、xiyou_tusu_ui、xiyou_guyu_ui：13/13 通过。
- 语法检查通过；工具回归通过。

## 本分支提交

- e09b7cffc T208 代码与专项
- （本次）预筛 P1-1 列表让开首领信息区＋减行数、P2-1 真实技能样张重截
- （本次）R2 指令环贴精灵身边（RING_BESIDE），重截指令环两张
