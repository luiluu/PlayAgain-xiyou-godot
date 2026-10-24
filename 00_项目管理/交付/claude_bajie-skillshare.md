# 交付：claude/bajie-skillshare

- 车道／工作者：B 界面·养成／八戒（Claude，重制_八戒_69）
- 状态：可合并
- 期一：进阶次数读取；期二：三套系统范围与参照（见「期二：范围清单」）；期三～五：技能共享、羁绊、领袖技能实现（三套一起做完，全部可合并）

## 变更记录草稿

## 2026-10-24 【Claude·八戒·未经Codex检验】读进阶次数三处改读 XAdvance（dev.待定）

- 角色进阶（dev.168）留下的三处读点接上 `XAdvance.rank`：
  - 小猫 178 `XCat.advanced()`：照原版 `advanced(a)`＝本角色、35 级起、`_AdvancedNum≥1`、学会 10444。进阶后成长 `growth()` 换成 35／50／60／70／81 级插值 0.30～0.875 的曲线（不低于 0.5，81 级起 0.875）；「进阶后…」三条说明文字随之变成「效果：…」。伤害钩子 `cat_damage_hooks` 原本就经 `advanced()` 读，不用改。
  - 甚尔／宿傩进阶石 `XDungeon.roll_advance_stone`：甚尔进阶过（≥1）不再掷；宿傩还差 `3−进阶次数` 枚，≤0 或背包够数不掷（不掷时不耗随机数，同原版短路顺序）。
  - 角色图鉴「最大进阶次数」`XActorBook.advance_max`：按当前进阶次数取行（`XAdvance.max_text`），已满显示当前次数；渡鸦 167 照运行时补登的 5 条：未满 5，满后显示次数。
- 参照：新探针 `03_转换工具/mv_oracle/advance_reads_probe.cjs`（冻结 v0.28 新游戏、Math.random 0.5；掷石头的「中」用例临时改 0），产物复制为 `tests/fixtures/advance_reads_oracle.json`：小猫 60 例（10 个等级 × 进阶 0～2 × 是否学会 10444）、进阶石 52 例、图鉴 732 例（进阶表每个角色次数 0～最大＋1，另加 167、1）。没进同步脚本 PROBES（固定参照随测试提交，同 actor_advanced_oracle）。
- 专项 `tests/xiyou_advance_reads`（8 项）。
- 未接（写进 cat.gd 文件头）：进阶后额外行动（原版 makeActionTimes＋1，在 battler，沙僧独占）、进阶后终技帮助改品质 10（helpItem）。小猫进阶要的「小猫进阶石」与进阶表行本来就在 XAdvance 表里，奉神老妪界面已可进阶。
- 验证：并行测试 `xiyou_advance_reads`（8/8）、`xiyou_cat`（992/992）、`xiyou_actor_advanced`（33/33）、`xiyou_actor_book`（22/22）、`xiyou_actor_book_review`（6/6）、`xiyou_dungeon`（6954/6954）、`xiyou_random_streams`（484/484）、`xiyou_module_hooks`（1310/1310）；必跑 `xiyou_event_compare`（5/5）、`xiyou_rules.tscn xiyou_rules_d1b xiyou_rules_d1c xiyou_rules_d1d`（101600／101542／101385／101422 全过）。
- 提交：f6b131b9

## 2026-10-24 【Claude·八戒·未经Codex检验】技能共享、羁绊、领袖技能（dev.待定）

- 移植冻结 v0.28 的三套队伍技能系统，三个新核心由 `core/party_skills.gd`（XPartySkills）统一调用：
  - `core/skill_share.gd`（XSkillShare，Star_SkilsShare）：出战栏 5 格成员；先忘上次共享与上次装备学的，再学装备 `<ShareLearnSkill:n>`，再按「技能 meta Share＝ShareSkill（含其 `<ShareSkill:n>`）∩ 成员技能与装备里所有 `<ShareSkill:n>`」共享给全体出战成员。**重制从此有了「穿装备学技能」**（护甲 142 件、武器 8 件，如护甲 13 学 34），宝珠 `<继承词缀>` 接进实例备注的也算。提示照 codex 包装：一次刷新只弹一条「技能共享激活：a、b」（新激活的）。
  - `core/bonds.gd`（XBonds，Star_JiBanSiklls，7 条）：出战成员集合变了才刷；2～5 人组合命中某羁绊组合就给组合内各人学技能；失效的提示「羁绊：X失效！」并遗忘，每次刷新重播「羁绊：X激活！」；不足 2 人全部遗忘。「三霄羁绊」（1 人）照原版永不成立。
  - `core/lead_actor.gd`（XLeadActor，Star_LeadActor，29 条）：首位（出战栏第 0 格）是领袖角色时全体出战成员学其领袖技能，换首位时先忘上次的；整队出战栏首格右上角画 LeaderFlag（`ui/party_scene.gd`；图要随切片导出，见交接板提案，未导出时不画）。
- 挂点与顺序照原版插件包装：整队「完成」／指令窗取消（`ui/party_scene.gd`）、角色仓库退出（`ui/actor_warehouse.gd`）：共享 → 羁绊（成员变了）→ 领袖；开战（`map/map_scene.gd` 的 `start_battle`，建战斗场景前）：装备学技能变了刷共享、成员变了刷羁绊；读档（`ui/save_scene.gd` 读档成功后，`XSave.load_slot` 本身不刷新，读档往返测试不受影响）：领袖 → 羁绊 → 共享。
- 存档：`XState.party_skills`，新键 `partySkills`（旧档没有为空），没有改已有字段，没改 actor.gd（只用已有的 learn_skill／forget_skill／skills()／equips）。
- 优化 O-095（待用户决定，`XPartySkills.EXACT` 可回退，默认开）：三套记录随存档、每次读档按本档刷新；只忘本系统学会的（角色本来会的不误删）；羁绊仍成立时离开出战栏的人忘掉该羁绊技能。关掉即照原版（内存记录、同会话首次读档才刷新、不分来源遗忘）。已写进 `00_设计/优化登记.md`。
- 参照：探针 `mv_oracle/party_skills_probe.cjs`（6 场景 45 步，整队完成／仓库退出／开战／读档，`tests/fixtures/party_skills_oracle.json`）；专项 `tests/xiyou_party_skills`（214 项：原版模式逐步比技能、提示、三套记录全部一致；O-095 模式重跑各场景比技能（MyGO 一步按设计不同）、本来会的不误删、读档清掉失效技能、存档往返、旧档；四处挂点；领袖旗标判定）。
- 原版里三霄、MyGO 等「超强角色」没开挑战开关时会被 installBossDifficultyRuntime 清出出战栏，重制还没有这条限制（不在本车道，见交接板）；参照开开关 2494 只测三套本身。
- 原版羁绊技能以字符串 ID 推进 `_skills`，重制按整数学（只影响按数值查 isLearnedSkill 的地方，三条羁绊技能都是纯被动）。
- 验证：见「验证」节。
- 提交：aaeff5af、7b901e3e、3ab4748a 及本交付单提交

## 期二：范围清单（Star_SkilsShare／Star_JiBanSiklls／Star_LeadActor）

参照：新探针 `03_转换工具/mv_oracle/party_skills_probe.cjs`（冻结 v0.28 新游戏，产物复制为 `tests/fixtures/party_skills_oracle.json`，6 个场景 45 步：护甲 1583／武器 1111＋护甲 13 的共享与装备学技能、三霄与 MyGO 羁绊、领袖换人、三套混合；每步记相关角色的 `_skills` 原样、提示、三套的内存记录）。

**挂点与调用顺序**（plugins.js 里领袖 109、羁绊 110、共享 114，后载入的包在外层）
- 整队「完成」（`Scene_Party.commandFinish`，指令窗取消同此）与角色仓库退出（`Star_Scene_ActorWarehouse.cancelNowScene`）：共享 `refreshAllSkills`（无条件）→ 羁绊（出战成员集合变了才 `GetActors`）→ 领袖 `LearnSkill` → 原函数。
- 开战（`BattleManager.startBattle`）：共享只在「出战成员的装备学技能」有变化时刷新（`hasEquipLearnSkillsChanged`）；羁绊在成员变化时刷新；领袖不刷新（插件里注释掉了）。
- 读档（`Star_LeadActor` 包的 `DataManager.loadGame`，只在本会话领袖记录还空时）：领袖 → 羁绊（记录为 null 时）→ 共享（记录为空时）。所以同一会话第二次读档不刷新。
- 不刷新的地方：事件入队／离队（129）、换装备、学技能——都要等上面几处之一。整队在战斗中也会触发（YEP 战斗指令「整队」），重制战斗里没有整队，不涉及。
- 三套的「上次」记录（共享 `lastSharedSkillIds`／`lastEquipLearnSkills`／`cachedBattleMembers`、羁绊 `lastBattleMemberIds`／`lastActiveJiBans`、领袖 `RanksActors`／`LearnSkillActors`）**只在内存，不进存档**；学会的技能本身在 `_skills` 里随角色存档。

**技能共享（Star_SkilsShare，无插件参数，全靠备注）**
- `refreshAllSkills`：① 上次共享的技能从上次出战成员身上忘掉；② 上次装备学的技能从各角色身上忘掉；③ 当前出战成员（`$gameParty._battleMembers` 原样 5 格，含 0）装备上 `<ShareLearnSkill:n>` 的技能，没有就学（`hasSkill` 含特性、套装给的）；④ 出战成员 `skills()` 里带 `<Share:ShareSkill>` 的技能 ID 与其备注里 `<ShareSkill:n>` 的 n 组成「可共享」集合，出战成员技能与装备备注里所有 `<ShareSkill:n>` 组成「被点名」集合，两者交集就是本次共享，学给全体出战成员（已有不学）；⑤ 提示：codex `installV019UsabilityRuntime` 吞掉逐条「技能共享：X 激活！」，只在有新激活时发一条「技能共享激活：a、b」（消息提醒「share」类，菜单里总显示）。
- 数据量：技能备注 108 个 `<Share:ShareSkill>`、20 个 `<ShareSkill:n>`；武器 8／4、护甲 142／67 件带 `<ShareLearnSkill>`／`<ShareSkill>`。**重制目前装备学技能整个没有**（`orbs.gd` 文件头已记「ShareLearnSkill 尚未移植」），所以这一套同时补上「穿上某件装备就学会某技能」，如护甲 13 学 34「装备:大罗剑胎」。
- 装备备注用实例的 `note`（宝珠 `<继承词缀>` 会接进来），没有就用数据库原备注。

**羁绊（Star_JiBanSiklls，插件参数 `JiBan 1`～`JiBan 200`，冻结源 7 条）**
- 每条：`JiBanActId` 角色组、`JiBanActNum` 人数、`JiBanNeceActId` 必要角色（7 条都空）、`JiBanSkiId` 技能（JSON 字符串数组，按组合里的位置取 `i % 长度`）。预先生成该角色组的全部 `JiBanActNum` 人组合（缓存在 `RpgJibanDateLoaded.rpgsave`，只是缓存，重制不写这个文件）。
- `GetActors`：出战成员（`battleMembers()`）不足 2 人时把上次激活的羁绊技能全忘掉、清空记录；否则生成出战成员的 2～5 人组合，某羁绊的某组合在里面就给组合内各人学技能、记为激活；上次激活本次没激活的：提示「羁绊：名字失效！」、组合内各人忘掉；最后每个激活的提示「羁绊：名字激活！」（每次刷新都重播）。
- 切片里三霄（100～102：2 人 5594、3 人 5595）与 MyGO（118／119／129／130／131：2～5 人 5607／5642／5643／5644）。「三霄羁绊」人数 1（5593）永远凑不成组合（只生成 2～5 人组合），原版就从不生效，照原版。
- 原版把字符串 ID 推进 `_skills`（`"5594"`），`isLearnedSkill(5594)` 因此为假；`skills()`、被动都按对象解析不受影响。重制 `skill_ids` 是整数，照数值处理（差异只在 `isLearnedSkill` 这类按数值查的地方，三条羁绊技能都是纯被动，无人这样查）。
- 三霄、MyGO 都是 `installBossDifficultyRuntime` 的「超强角色」：没开挑战开关（2494 等）时 `battleMembers()` 把他们清出出战栏。重制还没有这条限制（不在本车道，列为后续）；参照里开了开关 2494 只测羁绊本身。

**领袖技能（Star_LeadActor，插件参数 `Lead 1`～`Lead 200`，冻结源 29 条，角色都在切片）**
- 每条：`LeadActId` 角色、`LeadSkiId` 技能（如 1 狗逍遥 717、29 金蝉 701、2 绿司机 2772）。
- `LearnSkill`：首位（`_battleMembers[0]`，空位就是 0）没有领袖技能且没有上次记录就什么都不做；否则先从上次学的人身上忘掉上次的领袖技能；首位有领袖技能时给全体出战成员学，并记下（首位没有时记录不清，下次再忘一次无害）。
- 界面：整队出战栏（`Window_PartySelect.drawActor`，YEP 显示行走图时）首位是领袖角色时在格子右上角画 `img/system/LeaderFlag`（冻结源有这张图）。重制整队页还没画，领袖那一期一起补（标准级：一张原版截图对位置）。

**存档**：原版不存三套记录。重制按 O-095（下）新增一个顶层字段 `partySkills`（三套记录），旧档缺省为空。不改角色行结构、不改 actor.gd——只调已有的 `learn_skill`／`forget_skill`／`skills()`／`equips`，学忘之后 `refresh_passive()`。

**要动到的文件**
- 新增 `core/party_skills.gd`（XPartySkills：三套共用的刷新入口、调用顺序、记录与存档读写；技能共享、羁绊、领袖各一段，或分 `core/skill_share.gd`／`core/bonds.gd`／`core/lead_actor.gd`）、专项 `tests/xiyou_party_skills`。
- 挂点（都是一行调用）：`ui/party_scene.gd` 完成／取消处、`ui/actor_warehouse.gd` 退出处（车道 B 自己的）；开战 `map/map_scene.gd` 的 `start_battle` 在 `XBattleScene.new()` 前（不是谁的独占，悟空只占解释器 317／Autosave 分支）；读档 `ui/save_scene.gd` 的 `load_slot` 成功后；存档字段 `core/xstate.gd` 两行（to_dict／from_dict，同 actorAdvance；悟空本批也在 xstate 加 `mv_param_plus`，合并时是相邻行的小冲突）。`core/actor_warehouse.gd` 文件头那句「没有移植」改掉。
- 不动 actor.gd、battler.gd、damage.gd、battle_logic.gd（沙僧）与切片、转换器、oracle_additions（悟空）。

**原版缺陷（O-095，做成可回退，开关 `XPartySkills.EXACT`）**
1. 记录只在内存：读档后记录丢了，存档时已失效但还没刷新掉的共享／羁绊／领袖技能（如换了队首没进整队就存档）永远不会被忘掉；同一会话读另一个存档时，又会拿前一个存档的记录去忘新存档角色身上的技能（可能忘掉本来就会的）。提案：三套记录随存档（`partySkills`），读档时用本档记录刷新。
2. 遗忘不分来源：共享技能失效时从上次全体出战成员身上忘掉，羁绊／领袖同理——角色本来自己学会的同一技能也会被忘掉。提案：记录「谁是被本系统学会的」（学之前已有就不记），失效时只忘记录里的。
3. 开关关掉时完全照原版（内存记录、同会话只在第一次读档刷新、不分来源遗忘）。参照逐步对比在开关关掉时做；开着时另测读档与「本来就会」两例。

**建议顺序与期数**
- 期三：公共骨架（刷新入口、四个挂点、记录与存档、O-095 开关）＋技能共享（含装备学技能）。对参照 `share.*` 两个场景。
- 期四：羁绊。对参照 `bond.*`。
- 期五：领袖技能＋整队页领袖旗标；对参照 `lead.swap`、`mixed`（三套先后）。
- 三套都是纯被动技能，能力值由已有被动解析计算；战斗相关，期三起每期加跑 `xiyou_rules` 难度 1 四段。

## 交接板

- 下一步：
  - 提案（悟空独占切片）：`03_转换工具/xiyou_slice.json` 的 `systemImages` 加 `LeaderFlag`（冻结源 `img/system/LeaderFlag.png`，33×30），加上后整队页领袖旗标即显示；画法已在 `XPartyScene._paint_slots`，位置照原版 (内缩格宽−图宽, 0)，加图后可补一张原版截图对位置（标准级）。
  - 后续（另开）：installBossDifficultyRuntime 的「超强角色」出战限制（没开挑战开关 2494／2489／2487／2483／2461～2463 或混沌难度时 `battleMembers()` 清出 `superStrongActorIds`）重制还没有；影响三霄、MyGO 等能否出战。
  - 小猫进阶后额外行动（makeActionTimes＋1）在 battler（沙僧独占），可随状态效果一起接。
- 用户试玩说明：小猫进阶后剑技成长曲线与说明文字变化；图鉴「最大进阶次数」按当前阶显示；甚尔、宿傩进阶后不再掉多余的进阶石。整队「完成」或角色仓库退出后：穿着带共享光环的装备（如学习光环护甲）全队学会光环，弹「技能共享激活：…」；穿特定装备的角色学会装备技能；三霄／MyGO 同时出战弹「羁绊：…激活！」；狗逍遥等领袖角色在首位时全队学会领袖被动。开战前装备变了也会刷新。
- 需要用户决定：O-095（队伍技能记录随存档、只忘本系统学会的；`XPartySkills.EXACT`）。

## 进度账

- 养成：角色进阶读点补齐；技能共享、羁绊、领袖技能三套移植（含穿装备学技能），完成度上升（总装按账面口径定）

## 本分支提交

- f6b131b9 进阶次数读取三处改读 XAdvance；参照 advance_reads_probe、专项 xiyou_advance_reads
- 486636bd 期二范围清单；参照 party_skills_probe
- aaeff5af 技能共享骨架、挂点、存档字段、专项
- 7b901e3e 羁绊、领袖；读档挂点移到读档页
- 3ab4748a 整队页领袖旗标、O-095 登记

## 验证

- 期一：见上面变更记录。
- 期三～五：`并行测试.py` 相关专项＋必跑项全部通过——`xiyou_party_skills` 214/214、`xiyou_party` 57/57、`xiyou_actor_warehouse` 26/26、`xiyou_save_page` 40/40、`xiyou_flow` 48/48、`xiyou_floor_run`／`_b`／`_c` 273／332／560、`xiyou_floor16_dungeon` 25/25、`xiyou_dungeon` 6954/6954、`xiyou_battle_ui` 70/70、`xiyou_hangup_auto` 226/226、`xiyou_review_regressions` 29/29；必跑 `xiyou_event_compare` 5/5、`xiyou_rules.tscn xiyou_rules_d1b xiyou_rules_d1c xiyou_rules_d1d`（101600／101542／101385／101422）。更早一轮（读档挂点还在 XSave 时）另跑过 achievement、actor_advanced、battleback_save、difficulty_notice、drop_record、drop_dh、global_vars、hud、interp_review、mac_export、options_basic、orbs、equipment、warehouse、popup_overlap、random_streams、screen_fx、zhenqi_break、zhenqi_daofa，全过（当时只有楼层三段与 flow 的读档前后相同失败，已把挂点移到读档页解决）。
- 没改切片、转换器、同步脚本的探针表（两个新探针产物随测试提交为 fixtures），不需同步。车道未跑全量 `检查.sh`。
- 临时输出（/private/tmp/claude-501/bajie69 下的日志与调试脚本、mv_oracle/.sandbox 里本车道的两个产物）收工时已清理。
