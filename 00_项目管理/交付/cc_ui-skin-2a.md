# 交付：cc/ui-skin-2a

- 车道／工作者：B 界面·新界面 2A（战斗指令环、战技／物品列表、目标提示，盘点清册 #64）／cc（Opus＋medium，派单定：战斗界面接线）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·未经审查】新界面 2A：战斗指令环、战技／物品列表、目标提示（dev.待定）

- 玩家可见：无（新皮肤只在天启篇存档里开，天启篇没对玩家开放；重制版 0.01.x 与西游存档的战斗窗口与 main 逐像素一致）。开发版天启篇存档进战斗：指令窗变成行动者身边一圈圆球（上方旧金字「某某的回合」），战技／物品列表变成黑面板（标题＋右上现有 MP／TP、每行图标名字右对齐消耗、用不了才写原因并变暗、底下说明栏写「目标 · 用完剩多少」），选目标时目标头上挂名字＋范围的胶囊、脚下一圈锁定环。
- 依据：派单（协调 11-15）；设计稿 私密设计仓 `重制设定/界面风格提案_v0.7/` README 第一节「战斗」、样稿 `battle`（`样稿/src/build.py` `battle()` 的环心、角度、行高）；小A 文字审 `文字审_小A.md`（ba1f7ed）必改口径：#200「美娜的行动」改「美娜的回合」，#212 说明栏允许换行、兼容 MP；第 0 期交付单「第 1～6 期拆批建议」2A 行。
- 开关：沿用第 0 期 O-467 `XUiSkin.ENABLED`／`XUiSkin.on()`（不另开）。关着时 `XBattleScene` 照旧建 `XBattleList`，原代码路径不变。
- 新增文件（独占，`modes/xiyou/ui/skin/`）：
  - `skin_battle.gd`（`XSkinBattle`）：接线助手——`command()`／`list()` 按开关给新组件或原 `XBattleList`；`decorate_all()` 给每行补「不能用的原因」「TP 5 式消耗」「目标」「用完剩多少」（全读 `XBattleLogic` 现成结果：`can_use` 先后、`skill_cost`、`skill_hp_cost`、`can_pay_items`、冷却／预热表，不改任何状态、不取随机数）；`target_hint()` 选目标提示；图标贴图自带缓存（1A 修白块的 `XUiSkin.icon` 合进 main 后可换）。
  - `skin_battle_ring.gd`（`XSkinBattleRing extends XBattleList`）：指令环。只换画法和点选范围，选中／确定／上下循环／点选／右键／回显全继承。第 1 项在 258°（左上）往下逆时针每 36°；6 项时半径 139（样稿 124 时 82 直径的球会叠 5 像素，按球不相叠放大）；7 项以上在 252° 弧里等分、半径加大到最多 230，再多就缩球（最小约 28）；整环收在画面里；失活（开着列表、选目标、看怪物信息）时整环不画。
  - `skin_battle_list.gd`（`XSkinBattleSkillList extends XBattleList`）：战技／物品列表。宽 330、行高 44、一屏 8 行，超出时细滚动条；红乙选中条滑动；右边贴在行动者左边 37（样稿 452～782 对角色 819），上下以角色为中心；`row_rect()` 给说明卡定位。
  - `skin_target_hint.gd`（`XSkinTargetHint`）：目标提示胶囊（名字思源宋体 22＋范围旧金 15；敌人朱红边、我方旧金边）＋脚下锁定环（0.2 秒从 2 倍缩到位，动效关时直接到）；头顶放不下放脚下；全体／随机范围写「敌方全体 · 3 个」。
- 改共用文件（各只加一处「开着新皮肤就转去 XSkinBattle」，关着时行为不变）：
  - `modes/xiyou/battle/battle_scene.gd`：`_command_for` 建指令窗改调 `XSkinBattle.command`；`_pick_from_list` 开着时多一步 `decorate_all`（在 `XActor.read_begin／read_end` 里）、建列表改调 `XSkinBattle.list`（标题取指令窗当前项的字）；`_place_near_actor` 认 `place_for_actor`（只有新组件有）；`_help` 选中行矩形改用 `list_win.row_rect()`（原式子搬进 `XBattleList.row_rect`，数值一样）；`_select_target` 末尾调 `XSkinBattle.target_hint`（关着直接 return）。
  - `modes/xiyou/battle/battle_list.gd`：加 `row_rect(i)`（原 `_help` 里的式子）。
  - `tests/xiyou_ui_skin_offshot.gd`、`07_开发环境/皮肤关闭对照.py`：加战斗三张（指令窗、战技列表、选目标；西游存档）。
- 现状与没做的：
  - **两排站位时指令窗要不要挪（Kyo 问过，没定）**：现在环心＝行动者脚底往上 32，整环收在画面里；位置参数都留成 `XSkinBattleRing` 的 static var——`OFFSET`（环心相对脚底，默认 (0, −32)）、`START_DEG`（258）、`STEP_DEG`（36）、`MAX_SPAN_DEG`（252）、`RADIUS`／`MAX_RADIUS`／`ORB_R`；列表离角色 `XSkinBattleSkillList.GAP_TO_ACTOR`（37）。定了只改这几个数（五人两排站位 `party_layout(5)` 前后两列差 100，环跟着行动者走，后排角色的环会盖住前排小人）。
  - 说明卡（`XHelpCard`，成长、元素、黑闪等内容都在它上面）照旧贴在列表左边；新列表的说明栏只放「目标 · 用完剩多少」（用不了时只写原因），没有把技能说明搬进说明栏（派单口径）。要不要把说明卡收进说明栏留给后面定。
  - 战斗没申请 `XSkinLayout.request_wide`：战斗场景按 `_origin` 居中、背景按 1280 画，全局铺满留给 4A 评估；专项 `--wide` 截图是把整窗临时改 KEEP_HEIGHT 预览铺满后的位置。
  - 指令环和样稿的差别：样稿的环选中后淡出、列表从环的位置弹出的动画没做（列表打开时环直接收起）；指令环球里只写字，没放图标（样稿也只写字）。
  - 底部行动顺序条、右侧角色条、首领血弧、自动／变速按钮属 2B，没动；截图里环下端两个球压在旧行动顺序条上，2B 重排行动顺序条后再看。
- 验证：见「验证」节。

## 优化登记草稿

无（沿用 O-467 `XUiSkin.ENABLED`，不新开开关）。

## 新增可见文字（交付后协调派小A文字审）

天启篇开放后玩家能看到的：

| 文字 | 在哪 | 说明 |
| --- | --- | --- |
| 「某某的回合」（%s的回合） | 指令环上方 | 照文字审 #200 必改（不用「的行动」） |
| 敌方单体、敌方全体、敌方随机 1 个～敌方随机 4 个、我方单体、我方全体、我方单体（倒下的）、我方全体（倒下的）、自己 | 列表说明栏、目标提示胶囊 | 按技能范围（异化投影后）；没有范围的不写 |
| 「· 3 个」（敌方全体 · 3 个） | 目标提示胶囊 | 全体、随机范围一起亮的个数 |
| 用完剩 TP 4、用完剩 TP 4、MP 50（两种消耗）、用完剩 生命 100、用完剩 ×4 | 列表说明栏 | 多种消耗用「、」连 |
| TP 5、MP 150、生命 50；×5 | 列表每行右侧 | 消耗、物品数量（物品费用、自定义费用、元素徽记照原行的字） |
| MP 480　TP 9 | 技能列表右上 | 行动者现有；物品列表不写 |
| 预热 1 回合、冷却 2 回合、沉默中、被封印、物品不够、生命不够、TP 不够、MP 不够、现在不能用 | 用不了的行（橙小字）、说明栏 | 按 `can_use` 先后认出的原因；认不出的（专属角色条件等）写「现在不能用」 |
| 物品、技能 | 列表标题（兜底） | 平常标题是指令窗当前项的字（战技、魔法、物品……） |
| 空 | 列表没有项时 | 第 0 期已审 |

## 交接板

- 下一步：2B（右侧角色条、行动顺序、首领血弧＋状态胶囊＋详情、我方状态弹窗），依赖本批；派 2B 时带上「两排站位指令环位置」待 Kyo 定的事。
- 用户试玩说明：无（天启篇没对玩家开放）。
- 需要用户决定：两排站位（五人）时指令环要不要挪（现状：跟着行动者、整环收在画面里；参数见变更记录草稿）。可放进 `待Kyo拍板.json`，附截图 `04_验证/本地结果/ui_skin_2a/battle_2a_ring_16x9.png`。

## 进度账

- 天启篇新界面：第 0 期底层完成 → 加 2A 战斗指令环、战技／物品列表、目标提示；页面重排 1/83（#64 的指令窗、列表、目标提示部分；#64 的自动／变速与 HUD 归 2B）。

## 验证

- 专项 `tests/xiyou_ui_skin_battle.tscn`（新）：无头 58/58；有窗口 16:9、20:9（`--wide`）各 62/62（多 4 张截图）。覆盖：
  - 指令环：类型、六项照旧、标题「美娜的回合」、环心＝脚底＋OFFSET、角度 258/222/186/150/114/78、球不相叠（心距 ≥ 86）、整环在画面里、上下键与首尾循环、鼠标点球先选中再确定→开战技列表、点环心不中、开列表时整环收起；16 项时半径 ≤ 230、球 ≥ 28、弧 252°、收在画面里；`OFFSET` 参数生效；长指令名缩字（最小 14）。
  - 列表：类型、标题「战技」、右上 MP／TP、右边＝脚底 x−37、在画面里、行高 44、「TP 5」式消耗、能用不写原因、说明栏「敌方单体 · 用完剩 TP n」（按实际 TP 算）、说明卡在列表左边、`row_rect`、选中条在行上、鼠标点另一行只选中、取消回指令环。
  - 不能用的原因：冷却「冷却 2 回合」、预热「预热 1 回合」、TP 0 时「TP 不够」（行变暗、说明栏只写原因），恢复后能用；范围文字。
  - 物品列表：标题「物品」、右侧「×5」、说明栏「用完剩 ×4」。
  - 目标提示：攻击→选敌，胶囊名字＝光标那只、「敌方单体」、在头顶上方居中；左右换目标跟着换；取消收起、指令环回来且不透明。
  - 开关关着：`XSkinBattle.command`／`list` 给原 `XBattleList`（指令窗 220×（6×29＋22））、`row_rect` 同原式子、目标提示不建。
- **开关关掉与 main 一致**：`python3 03_再刷重制_Godot/07_开发环境/皮肤关闭对照.py --base main --out 03_再刷重制_Godot/04_验证/本地结果/ui_skin_2a/关闭对照`（main＝c4e5a375a）→ 13 张逐像素 SAME：第 0 期的 10 张＋战斗指令窗、战技列表（带说明卡）、选目标（西游存档）。同一分支先连拍两次确认战斗三张可复现（停呼吸、藏我方身体后 SAME）。
- 截图（有窗口，git 忽略目录 `03_再刷重制_Godot/04_验证/本地结果/ui_skin_2a/`）：`battle_2a_ring_16x9.png`、`battle_2a_skill_list_16x9.png`、`battle_2a_item_list_16x9.png`、`battle_2a_target_16x9.png`，同名 `_20x9`（1600×720，整窗临时 KEEP_HEIGHT 预览铺满）；`关闭对照/base`、`关闭对照/branch` 各 13 张。注：专项场面在地图 5 上直接开战，截图里战斗背景没铺（同 `xiyou_battle_ui` 的场面），关闭对照那三张有背景。
- 选测（本地）：`选测.py main --list` 给 130 个；本地跑了去掉 `xiyou_floor*`（47）、`xiyou_map186*`（7）、`xiyou_event_compare*`（4）之后的 72 个（含 `xiyou_determinism`、`xiyou_battle_*` 全部 13 个、`xiyou_tusu_ui`／`guyu_ui`／`yunshang_ui`、`xiyou_flow`、`xiyou_item_list`、`xiyou_tianqi_*`、`xiyou_ui_skin_*`），**72 个全部通过**（1100 秒，并行 2）。日志 `04_验证/本地结果/并行测试/20261115_073650_n2g19cxb/`。没跑的楼层／map186／事件对照：只改了建窗口和画法，开关关时走原 `XBattleList`，这几组不建天启篇存档、也不看窗口像素。
- `工具回归.py`：全部通过（135 秒）。`发行空壳.py check`：通过。`语法检查.py`：899 个 .gd 0 个问题。
- 给总装：`合并车道.sh --finish --affected --cloud`（选测 130 个场景，含上面本地没跑的楼层、map186、事件对照）。

## 核查

- cc 写 → 小A 乙档（界面换皮＋文字审）。本批碰到 `battle_scene.gd`，但只改了建窗口、摆位置、说明卡定位的几行，不碰战斗流程逻辑（`_picked` 的取值、行动、目标选择结果、随机数都没动），所以不需要 co 甲档；小A 核查时请重点看「关着时代码路径不变」那几处。

## 可优化（流程／工具／效率）

- 已做：`皮肤关闭对照.py`／`xiyou_ui_skin_offshot` 加战斗三张；战斗者呼吸相位是画面随机数（`XBattlerSprite._init` randomize）、我方待机帧跟载入快慢有关，对照时停掉呼吸、藏我方身体（光标、名字、血条照拍），两次跑逐像素一致。回退：删 `_battle_shots` 那段。
- 建议：天启篇存档开战时 TP 等还有别的随机来源（同样种子两次跑不一样），所以战斗对照只拍西游存档；要拍天启篇档得先查清那个随机来源（归界面车道或 2B，预计半小时）。

## 本分支提交

- 5174252af WIP：新界面 2A 战斗指令环、战技／物品列表、目标提示与专项
- （其余见 git log）

## 小A 乙档核查

- **核查对象**：`cc/ui-skin-2a` @ `c228b5e5a`（只读核查，未改游戏代码）。
- **结论**：**通过**（P1 0、P2 0、P3 3；文字必改：无；**不需要转 co 甲档**）。
- **核查方式分清**：
  - **前台实跑（核了规则／运行行为）**：`tests/xiyou_ui_skin_battle.tscn --headless` 58/58 通过；`tests/xiyou_ui_skin_offshot.tscn --headless -- --compare=...` 复核既有 `关闭对照/base` vs `branch` 13/13 全部 SAME；`语法检查.py` 900 个 `.gd` 0 问题；`发行空壳.py check` 58 脚本 484 函数通过；`content/ui_skin/fonts/charset_hei.txt`／`charset_song.txt` 覆盖全部 2A 新增汉字 0 缺字。
  - **只看代码（未重跑耗时长检查）**：逐行核对 `c4e5a375a..c228b5e5a` 差异及 `battle_scene.gd`、`battle_list.gd`、`battle_logic.gd`、`skin_battle*.gd`、`skin_target_hint.gd`、`alien_battle.gd`、`tusu.gd`、`tianqi_qiyin_effects.gd` 与 `xiyou-design-docs`（`ba1f7ed` `文字审_小A.md`、`README.md`）。
- **逐项核查**：
  1. **`battle_scene.gd` 四处开关分支与 13 张 SAME 口径（核代码＋复核 `--compare` 13/13）**：
     - 建指令窗 `_command_for` → `XSkinBattle.command`：关时直接返回 `XBattleList.create(parent, opts, width, "center")`。
     - 建列表 `_pick_from_list` → `XSkinBattle.list`（及 `decorate_all` 前置 `if XSkinBattle.on():`）：关时不调 `decorate_all`，直接返回 `XBattleList.create(parent, rows, width)`；`title` 读取 `cmd_win.entries[cmd_win.index].text` 为纯只读。
     - 摆位 `_place_near_actor` → `w.has_method("place_for_actor")`：原 `XBattleList` 无此方法，关时完全走原逻辑。
     - 说明卡定位 `_help` → `list_win.row_rect()`：原 `XBattleList.row_rect` 为原式子搬移，数值一致；选目标 `_select_target` → `XSkinBattle.target_hint` 首行 `if not on(): return`。
     - 皮肤关闭对照 13 张口径合理：第 0 期 10 张（西游／天启关各 5 页）＋西游战斗 3 张（指令窗、战技列表含说明卡、选目标）；天启篇关皮肤时 `XUiSkin.ENABLED = false` 使 `XUiSkin.on()` 与西游档走同一 `false` 分支，停呼吸与隐藏我方待机主体仅去帧率／随机相位抖动，保留光标、名字、血条与窗口像素对比。
  2. **战斗流程逻辑只读核查（只看代码＋58 项专项）**：
     - 未改动行动顺序（OTB）、随机数取用（`_rule()`／`XBattleRandom`）与技能可用判定：`battle_scene.gd` `_list_entry` 仍由 `logic.can_use(a, e)` 算 `enabled`，`XSkinBattle.decorate` 仅原样读取 `row.enabled`（不重算不改写），`XSkinBattleRing`／`XSkinBattleSkillList` 继承 `XBattleList._ok()`／`chosen`／`cancelled`，仅覆写 `_hit` 点选几何区域；`XSkinTargetHint` 不触碰 `_target_pool`、`_hover`、`_picked` 与返回值；`reason`／`skin_costs`／`target_text`／`left_text`／`target_hint` 均无状态写回与 RNG 调用。不涉及转 co 甲档。
  3. **「不能用才写原因」「目标 · 用完剩多少」数据来源（只看代码＋专项局部覆盖）**：
     - `decorate` 仅在 `not enabled` 时调 `reason()`；`foot_text`／`_draw_row` 在 `enabled` 时不画 `reason`。
     - `reason` 按 `XBattleLogic.can_use` 顺序读取 `warmups`、`cooldowns`、`XTianqiQiyinEffects.silenced`、`TRAIT_STYPE_SEAL`／`TRAIT_SKILL_SEAL`、`can_pay_items`、`can_pay_hp`、`skill_cost`（TP／MP，含 `XAlienBattle.glutton_mp`），其余专属条件兜底「现在不能用」。
     - `target_text` 经 `XAlienBattle.project(a, e)` 投影后读 `SCOPE_TEXT[scope]`；`target_hint` 复读已投影的 `_target_skill` 与 `group.size()`（`group.size() > 1` 拼 `· N 个`）；`left_text` 读 `logic.state.item_count`、`logic.skill_cost`、`XBattleLogic.skill_hp_cost`。
  4. **两排站位相关参数现状（只看代码）**：
     - 交付单「现状与没做的」及「交接板」已写明：`party_layout(5)` 前后两列差 100、当前环跟行动者走且后排环会压到前排小人，留作 `XSkinBattleRing` static var：`OFFSET`（默认 `(0, -32)`）、`START_DEG`（`258.0`）、`STEP_DEG`（`36.0`）、`MAX_SPAN_DEG`（`252.0`）、`RADIUS`／`MAX_RADIUS`／`ORB_R` 及 `XSkinBattleSkillList.GAP_TO_ACTOR`（`37.0`），已标待 Kyo 拍板并在 2B 交接带出。
  5. **文字审（`ba1f7ed` 口径＋按键提示统一）**：
     - 新增可见文字表与 `skin_battle*.gd` 字面量一致，符合 `ba1f7ed`（`文字审_小A.md`）：`#200` 用「`%s`的回合」（不用「的行动」）；`#212` 列表说明栏支持两行换行（`draw_multiline_string(..., 2)`，`FOOT_H = 52`）并兼容 MP／TP／生命／物品；全角中文括号「（倒下的）」、中文与数字半角空格（「冷却 2 回合」「预热 1 回合」「敌方随机 1 个」「TP 不够」「敌方全体 · 3 个」）、名词口径（「生命」「物品」「技能」「空」）均统一；`charset_hei`／`charset_song` 零缺字。
     - 按键提示：2A 战斗界面同 `v0.7` 样稿 `battle` 未加底部按键提示条，无新增按键文案（第 0 期既有 `XSkinKeyHints` 为统一胶囊套框）。
     - **文字必改**：无。
- **P1 / P2 / P3**：
  - **P1**：0。
  - **P2**：0。
  - **P3（3 处边界显示差异，不影响可用判定与正常流程，可并后顺手补或留 2B）**：
    1. `skin_battle.gd` `left_text`（及 `header_text`）读 `a.mp` 计算「用完剩 MP …」，但异化饕餮词条（`XAlienBattle.glutton_mp(a)`）实际由饥饿储备代扣 MP（`a.mp == 0`）、屠苏噬主可由队友代付 MP（`XTusu.can_pay`），该情形下技能可用但 `left_text` 会算出负余量（如 `用完剩 MP -50`）。
    2. `skin_battle.gd` `reason` 先于 `XYunshang.eye_bypass(a, e)` 判 `cooldowns`、先于 `XAlienBattle.silence_bypass`／`XToji.switch_unsealed` 判 `TRAIT_STYPE_SEAL`：若绕过冷却或绕过类别封印后仍因另一原因（如 MP 不够）不可用，`reason` 会优先报成「冷却 X 回合」或「被封印」。
    3. `选测对照.json` `ui_skin` 组 `scenes` 尚未列入 `xiyou_ui_skin_battle.tscn`（改 `tests/xiyou_ui_skin_battle.gd` 自身会进 `test` 组跑，后续只改 `skin_*.gd` 时依 `refs: true` 也会引用到，但补进 `ui_skin` 组更稳）。
- **没核到的**：
  - 有窗口实拍（`xiyou_ui_skin_battle.tscn` 16:9／20:9 实机截图、`皮肤关闭对照.py` 现场重跑与 2A 截图肉眼逐像素审看未重跑，仅以 `--headless` 58/58 及已有 `关闭对照/` `--compare` 13/13 核对）。
  - 选测全量 130 场景（含楼层 `xiyou_floor*`、map186、事件对照 `xiyou_event_compare*`）及 `工具回归.py`，留待总装 `--affected --cloud`。

