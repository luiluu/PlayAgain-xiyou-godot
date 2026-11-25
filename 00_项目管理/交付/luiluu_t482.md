# 交付：luiluu/t482

- 车道／工作者：T482 元素效果 D 卡·状态图标与角色属性界面（cc，Sonnet＋medium，P6；本单配 Sonnet＋medium，因为是界面接线和文字落地）
- 状态：可合并
- 依据：设计稿 `重制设定/天启篇_元素独特效果_v0.3.md` §7.2 D（fc614148）＋D284／D285；T483 小A 文字审非争议建议；Kyo 11-25 事项 59 文字定稿；T485 cc 核 P2-1
- 只做天启篇：新增界面入口都由 `XTianqiElements.on(XState.current)` 或 `XTianqiElementEffects._fx(logic)` 守着，西游档零改动

## 变更记录草稿

## 2026-11-25 【cc·T482·未经审查】天启篇元素独特效果 D 卡：状态图标、头顶跳字、「角色属性」一行（dev.待定）

- 状态图标：冰冻、浸湿、圣佑原来图标号是 0（状态栏不画），改借 1168／955／1189；寄生原来和灼烧同图，换成 916，十二个新状态都有图标（专项 `t482_all_states_have_icon`）。
- 圣护盾改名「圣佑」（Kyo 11-25 事项 59 ①）：状态名、说明、日志全改；「圣护」仍是神圣效果名（头顶弹字、`elements_table.json` 效果名）。碎甲不改名、遮蔽锋芒不缩（②③）。
- 头顶跳字：挂上元素效果弹效果名（灼烧、迟缓…）；神圣触发弹「圣护」（回复色）；圣佑挡下负面弹「圣佑抵挡」；麻痹／冰冻吃掉行动位弹「麻痹」「冰冻」；体质免疫元素效果时弹「免疫＋效果名」（如「免疫灼烧」），不弹「免疫」「无效」二字（⑤），只在本该掷中时弹（几率同真实几率，骰子用单独的跳字流 `elem_pop`，不动效果子流和战斗主流）。通道＝战斗日志 `battle_text` 带可选键 `pop`，战斗画面 `_play` 认它，不认的调用方照旧只读 `text`。
- 「角色属性：火焰」一行（④）：怪物图鉴（左栏种族行下）、人物图鉴（属性·武器·防具那一行末）、状态页角色牌（Lv·职业下）；双属性顿号隔开，无则「无」；西游档（或元素效果开关关）返回空串不画。楼层免疫提示：首领条悬停说明末尾补一句「角色属性只影响元素效果，不免疫元素伤害。」
- T485 核 P2-1：2704 端到端反射反例改为施放者挂「神圣有效度 ×0.02」垫子，被反射后必须存活（新增断言 `holy_reflected_caster_alive`）；dtype 守卫补直接测试 `holy_damage_dtype_guard`（伤害类技能打自己人不入神圣己方入口，白名单治疗类入）。变异实测：只拿掉 `_reflecting／reflected` 守卫 → `reflected_segment_not_recorded` 挂；只拿掉 dtype 守卫 → `holy_damage_dtype_guard` 挂；两条同时拿掉 → 三条一起挂（含 2704 端到端）。
- 玩家可见：战斗里元素效果状态都有图标和头顶字；图鉴、状态页多了「角色属性」一行。

## 返修 R2（小o 核 P1×3＋P2×3、小A 文字审 P2-1＋P3×4；本单配 Sonnet＋medium，P6）

- **P1-1 免疫跳字同一次结果**：免疫候选不再另掷跳字骰。`_try_apply` 里免疫目标继续走完同样的资格与几率门槛（旧状态归并、停手预算、浸湿加成、我方状态有效度、韧性），只是不动状态、冷却、预算；最后对效果子流**复制一份再取下一次骰**（`XRandomStream.restore(snapshot)`，正式流不消费），小于几率才弹「免疫＋效果名」。所以弹＝没有这层免疫它真会挂上；状态有效度 0 挡住时不弹。`immune`／`blocked` 统计口径不变（免疫仍记 immune 一次、不记 rolled）。去掉 `elem_pop` 流。新增 `t482_immune_pop_matches_effect_roll_0.25／0.75`（固定骰：弹＝对照侧真挂上、免疫侧不消费 draws）、`t482_immune_pop_silent_when_state_rate0`。
- **P1-2 跳字位置**：元素提示（只有 `battle_text.pop` 通道）改到受影响单位头顶（精灵脚底原点上移一个身高再抬 14，不低于 20），不压我方脚边、不盖敌方名牌；旧 `_custom_popup` 调用（黑闪等）不传新参数 `at_head`，原坐标不动。P2-3 一并：同一目标上还没消失的元素提示往上叠一格 26 px。截图 `popup_both_sides.png`（敌我同场，罗琳两条叠放）。
- **P1-3 原版界面补行**：怪物图鉴旧窗口左栏在 y=258 起插一行「角色属性 值」（原「弱化属性」起整体下移一行；未登记显示「？？？」），人物图鉴旧窗口在「最大进阶次数」同一行靠右，状态页旧窗口在状态图标与等级之间的空行；灰（系统色）标签＋白字值；西游档为空、不占位。新增 `t482_old_status_nature_row`、`t482_old_actor_book_nature_row`、`t482_old_rows_west_no_nature`。截图 `*_old.png`（`--ui-skin=old`）。
- **小A P2-1**：新界面人物图鉴「角色属性」单独一行（在属性·武器·防具那段之后另起），灰字标签＋白字值；怪物图鉴行同样灰标签白值（小A P3）。
- **小A P3**：`HELP` 去掉「只」；楼层免疫提示加前缀「注：」；`SPECS` 头注释「待小A 审」改「已审」；注释里旧词「圣护盾」改「圣佑」（`battler.gd:506` 的注释在西游共用文件里，本单不动，写在这里）；`免疫遮蔽锋芒` 六字宽度——`免疫灼烧` 实拍清晰，六字没有专门截，头顶居中不贴边，留真机顺看。
- **小o P2-1 图标**：圣佑 1189→1184（不再与旧「神圣护盾」同图）、寄生 916→1214（不再像「中毒」）、感电 1029→945（与麻痹分开）、遮蔽锋芒 921→920（与乱流分开）。**魔蚀／碎甲同图（706）本单不改**：图标表里没找到语义清晰的「魔法防御降」候选，硬换反而更乱，留给美术小卡。
- **小o P2-2 不改**：普通迟缓／浸湿的联动说明要拆首领版／普通版状态号才能分开写，本单不拆状态；角色属性元素色同样不做（正文色保持界面一致）。写在这里，不是遗漏。
- 发行空壳 check：0（84 个脚本、829 个函数；`XTianqiNature.split_line` 登记「已确认空值安全」）。西游档零改动（`random_stream.gd` 本单未动）。

## 交接板

- 下一步：C 卡校准；跳字时机（敌我同帧多条）如要加序可另提
- 用户试玩说明：天启篇战斗中挂上元素效果有图标和头顶字；体质免疫弹「免疫灼烧」类；图鉴、状态页看「角色属性」
- 需要用户决定：无

## 进度账

- 无新增部分；元素独特效果 D 卡完成

## 可优化（流程／工具／效率）

- 建议：（R2 已补旧窗口三处，此条作废）

## 验收逐条（卡上 5 条）

1. 状态图标、跳字位置、图鉴／角色页「角色属性」一行、楼层免疫提示：✓（截图见下）。跳字位置＝战斗画面 `_custom_popup` 的既有锚点（敌人在精灵头顶、我方在精灵位置）。
2. 文字用 E 卡定稿：✓（SPECS 说明沿用 T480 R2 按小A 非争议建议已落地的版本，本单只改圣佑；新增文字见上）。
3. 发行空壳.py check：✓ 84 个脚本、828 个函数；新增三个被西游代码调用的函数 `XTianqiNature.line_of`、`line_of_actor_id`、`XTianqiElementEffects.skip_log` 写入「已确认空值安全」并带理由。
4. T485 P2-1：✓（见上）。
5. 事项 59 ①～⑤：✓（①圣佑、②碎甲不改、③遮蔽锋芒不缩、④「角色属性：」、⑤「免疫＋效果名」）。

## 截图（`00_项目管理/交付截图/luiluu_t482/`，真窗口 1280×720、`--audio-driver Dummy`、隔离 HOME，工具 `tests/t482_shots.tscn`）

- 战斗中状态栏：`battle_state_bar.png`（敌人侧栏图标）；十二个状态的图标＋说明总表 `state_icons_all.png`
- 头顶跳字：`popup_burn_enemy.png`（灼烧）、`popup_immune_burn.png`（免疫灼烧）、`popup_holy_block.png`（圣佑抵挡）
- 图鉴「角色属性」：`book_enemy_nature.png`、`book_actor_nature.png`；状态页 `status_nature.png`
- 说明：战斗状态栏的图标是轮换显示的，单张截图只截到当下那几个，所以另给总表；跳字三张是用战斗画面 `_play` 喂带 `pop` 的 `battle_text` 日志的真通道截的，不是单独画的。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiElementEffects._say`（加可选参数 pop_target／pop_text／fmt） | 文件内 9 处（`git grep -n '_say(' -- '*/tianqi_element_effects.gd'`） | 默认值＝原行为；只有 4 处新带跳字 |
| `XBattleLogic` 停手日志（`battle_logic.gd` elem_skip 分支） | 1 处 | `take_skip` 返回非空才走；西游档 `_fx` 为空恒返回 ""，不进；日志多一个可选键 `pop` |
| `XBattleScene._play` 的 `battle_text` 分支 | 1 处 | 只在日志带 `pop` 且目标有精灵时多弹一个字；其它 battle_text 来源都不带 `pop` |
| `XTianqiElements.profile_tooltip` | 1 处（`git grep -n 'profile_tooltip' -- '*.gd'`，boss_status_panel） | 只在已有天启篇楼层牌组时有文本，末尾多一行 |
| `XSkinBookPage.enemy_info`／`actor_info`、`XSkinStatusPage._draw_actor` | 各 1～2 处 | 新增键 `nature`／一行文字，西游档为空串不画 |
| 状态图标号（冰冻、浸湿、圣佑、寄生） | 仅 `SPECS`（天启篇表外状态） | 只影响天启篇元素状态 |

## 测试

- 本机前台（`--audio-driver Dummy`，隔离 HOME）：`xiyou_tianqi_element_effects.tscn` 88/88（含新增 T482 九条、T485 P2-1 两条）
- `发行空壳.py check`：0
- 云端选测：整轮 811 个场景、16 片全绿，偶发 3 个（并行失败、单跑通过：`xiyou_floor_reach080`、`xiyou_tianqi_skill_debt`、`xiyou_ui_detail_d3`，与本单无关）

## 云端选测

- 提交 567f877feb（`ci/luiluu/t482`，整轮，选测基准 3370833830）：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45585130718 ，`gh run watch` 前台等到跑完，结论 success（19 个 job 全 ✓）。

## 本分支提交

- 55b4ac98a WIP：元素效果 D 卡主体（图标、跳字、角色属性、圣佑改名、T485 核 P2-1 测试）
- 960e13a8f 截图工具、寄生换图标、截图入仓
- 交付单草稿与云端结果补写（本提交）
