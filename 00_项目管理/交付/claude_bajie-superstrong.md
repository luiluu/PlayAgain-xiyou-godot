# 交付：claude/bajie-superstrong

- 车道／工作者：B 界面·养成／八戒（Claude，重制_八戒_70）
- 状态：可合并
- 期一 超强者出战限制：完成；期二 领袖旗标对位置：没收到「LeaderFlag 已合进 main」的通知，跳过（见「期二」）；期三 设置「角色换装」：量小，已实现（战斗外观接入写成提案）

## 变更记录草稿

## 2026-10-25 【Claude·八戒·未经Codex检验】超强者出战限制（dev.待定）

- 移植冻结 v0.28 `installBossDifficultyRuntime` 的 `D.enforceParty`／`canDeploy`：没开持久挑战开关（2494／2489／2487／2483／2461～2463）且难度不是 9（混沌）时，出战栏里的超强者（复用 `XItemMarks.SUPER_STRONG_IDS`／`super_enabled`，不另起名单）换成 0，**只把这些空出的格**按队伍顺序补上「不是超强者、不在出战栏」的角色，补不满留 0；原本就空的格不动；队伍顺序不重排，角色仍在队伍里。代码在 `core/item_marks.gd` 超强段（`enforce_party`／`deploy_start`／`flush_deploy_notice`／`can_deploy`）。
- 挂点照原版包装：`XState.battle_members()` 先清（开战、羁绊／共享／领袖刷新、读档后都经它）；`init_battle_slots`／`add_actor`／`rearrange_actors` 前后各清一次（原版另包 swapOrderBattleMembers、changeBattleMax，重制没有这两处）。
- 提示「超强者仅限地狱及以上难度出战，已移至替补。」只在内存记一条，回地图（`map_scene` 进场、关菜单、战后）与开整队页时弹（原版 Scene_Map／Scene_Party.start）；读档换掉 XState 后，旧状态的提示不弹。
- 整队页（`ui/party_scene.gd`）：名单里超强者名字半透明（actorIsEnabled），确定蜂鸣、出战栏不变（isCurrentItemEnabled／switchActors）。原版帮助窗的「仅限地狱及以上难度出战」文字：整队页没有帮助窗，不涉及。
- 三霄 100～102 是超强者；MyGO 118／119／129／130／131 与镜流 170 是「强者」，**不受出战限制**（上一批交付单说 MyGO 也会被清出，是错的，以本参照为准）。
- 参照：新探针 `03_转换工具/mv_oracle/super_deploy_probe.cjs`（6 场景 30 步：三霄清出与补替补、替补不够、开关开关与混沌难度、加入已持有的超强者、MyGO／镜流不受限、读档），产物复制为 `tests/fixtures/super_deploy_oracle.json`；专项 `tests/xiyou_super_deploy`（43 项：逐步比出战栏、队伍顺序、出战成员、放行、名单可否编入、提示；整队页开页清出与提示、名单蜂鸣、普通角色照常编入）。
- `tests/xiyou_party_skills` 的新局照参照开开关 2494（参照本来就开着，Godot 侧原先没开，有了限制后三霄被清出）。
- 没进同步脚本 PROBES（固定参照随测试提交，同 party_skills_oracle）。
- 未接：超强者的 Boss 难度加成（每名出战超强者 Boss 八项＋20%、偶数回合霸体与输出加成，同一文件后半）在战斗（沙僧独占 battler／damage），列为后续。

## 2026-10-25 【Claude·八戒·未经Codex检验】设置「角色换装」（dev.待定）

- 范围（冻结 v0.28 `installCostumePreferencesRuntime`，和衣橱 Star_ChangeClothes 不是一套）：每个角色一个「战斗中显示换装卡外观」开关。
  - 换装卡：技能 6801～6858 备注 `<StartPushStateN:…>`、状态 N 备注里有 `var battlerName = '…'` 的登记（58 张，全部有效），名字去掉「变身——」。
  - 开关默认启用；原版存在 `Game_Actor._codexCostumeEnabled`（随局内存档，不是全局配置）。
  - 生效：`Game_Actor.battlerName` 包装——战斗中角色有卡状态时，启用显示卡图，关闭显示自身形态（`_prevBattlerName` 或数据库 battlerName）；另在 `Mx.SuperSVMetaProvider` 去掉角色自身的 SV 动作标签。影响画面只有战斗侧视图；卡的技能、状态与属性加成不变。
  - 入口：设置「角色换装」（主菜单同名指令被 installDisplayPreferencesRuntime 去掉了）；进游戏且不在战斗可开（状态「打开」），否则灰显、「进入游戏」、确定蜂鸣。确定不播确定音（Window_Options.processOk 被整个换掉），左右无作用。
  - 换装页 Scene_CodexCostumes：标题窗 (24,18,1232,120) 三行；列表 (150,150,980,546) 14 行，列出队伍＋角色仓库（去重），每行名字、学会的卡名（没有写「未使用换装卡」）、「启用」#a9dfb7／「关闭」；确定切换。
- 实现：`core/costumes.gd`（XCostumes：登记、开关、卡、当前卡、`battler_name`、拥有角色）；存档新字段 `XState.costume_off`（关掉的角色 ID，存档键 `costumeOff`，旧档没有为空＝全启用；不改 actor.gd，不迁移原版字段）；`ui/costumes_scene.gd`（XCostumesScene）；`ui/options_scene.gd` 这一项改为可用。
- 参照：新探针 `mv_oracle/costume_probe.cjs`（登记 58 张、角色 1 学两张卡上状态 1201 后关／存档往返／再开的战斗外观、拥有角色、设置页状态），产物复制为 `tests/fixtures/costume_oracle.json`；专项 `tests/xiyou_costumes`（22 项）。页面几何按代码照做（从简＋代码数值），没有截原版图。
- **还看不到效果**：重制战斗没有卡状态的换图（状态 Custom Apply Effect 里的 `setBattlerImage`），所以开关目前只影响 `XCostumes.battler_name` 的结果；战斗精灵接入见「提案」。
- 验证：见「验证」节。

## 期二：领袖旗标对位置

- 本批期间 main 没有悟空的 LeaderFlag 合并，也没收到总装通知，按任务跳过。`XPartyScene._paint_slots` 现照原版代码画在首格内缩后右上角（x＝内缩格宽−图宽、y＝0，不加格子 x），图没导出时不画。合进 main 后：`git merge main`，原版整队页（首位领袖，如角色 1）截一张，对齐旗标矩形即可，预计很小。

## 提案（要总装／沙僧定）

1. **换装卡战斗外观接入**（沙僧的战斗／状态效果范围）：卡状态 1201 等的 Custom Apply／Remove Effect 只做 `setBattlerImage`，重制状态效果没翻这段。建议不翻脚本，战斗精灵取角色外观时改用 `XCostumes.battler_name(state, actor)`（`core/appearance.gd` 的 `for_battler` 读 `battlerName` 处），并在状态增减后刷新该精灵；`Mx.SuperSVMetaProvider` 那层（启用卡图时去掉角色自身的 sv／SVzs／Cfdz／YCyy 标签）一起做。
2. **超强者 Boss 难度加成**（同文件后半，战斗）：Boss 八项属性按出战超强者人数×20%、偶数回合霸体（状态 2651，免控制）、霸体回合输出同倍率。出战限制做完后，地狱以下 Boss 不受影响，地狱及以上才有效。
3. 两个新探针是否进 `同步正式西游.py` 的 PROBES：本批照 party_skills 先例没加（参照随测试提交）。

## 交接板

- 下一步：期二（领袖旗标位置）等 LeaderFlag 合进 main 后派；提案 1、2 交沙僧排期。
- 用户试玩说明：地狱以下难度（没开挑战）时，三霄等超强者会被移出出战栏、换上替补，回地图弹「已移至替补」，整队里点他们会蜂鸣；设置「角色换装」可以打开，按角色切换启用／关闭（战斗里的换装外观重制还没有，暂时看不出区别）。
- 需要用户决定：无（O-096 未用）。

## 进度账

- B 界面·养成：超强者出战限制补齐获取／招募／出战三处；设置页「角色换装」从灰显变为可用（外观接入待战斗侧）。

## 验证

- 车道专项（`并行测试.py`，本工作树）：`xiyou_super_deploy` 43/43、`xiyou_super_acquire` 27/27、`xiyou_costumes` 22/22、`xiyou_party_skills` 214/214、`xiyou_party` 57/57。
- 出战成员相关回归：`xiyou_achievement_badge` 34、`xiyou_actor_p0` 3212、`xiyou_actor_warehouse` 26、`xiyou_advance_reads` 8、`xiyou_battle_ui` 70、`xiyou_cat` 992、`xiyou_combat` 34、`xiyou_drop_record` 26、`xiyou_hangup_auto` 226、`xiyou_map`／`map186`／`map186_legions` 281／104／32、`xiyou_options_misc` 86、`xiyou_panels` 35、`xiyou_review_fix`／`review_fixes` 60／16、`xiyou_save_page` 40、`xiyou_shield` 565，全过。
- 设置页相关：`xiyou_options_basic` 139、`xiyou_hangup_options` 57、`xiyou_notice_options` 71、`xiyou_battle_options` 92、`xiyou_window_rects` 9、`xiyou_power` 137、`xiyou_change_clothes` 32、`xiyou_smart_ai` 四段 20261／20172／17881／17881，全过。
- 必跑：`xiyou_rules.tscn xiyou_rules_d1b xiyou_rules_d1c xiyou_rules_d1d`（101600／101542／101385／101422 全过）、`xiyou_event_compare` 5/5（期一后、期三后各跑一次）。
- 没跑全量 `检查.sh`（车道规则）。探针产物 `.sandbox/super_deploy.json`、`costume.json` 与临时日志已清理。

## 本分支提交

- 75fa0b5a 超强者出战限制：enforce_party、挂点、参照与专项
- be71eabc 技能共享专项开开关 2494；回归通过
- 2c222855 角色换装：XCostumes、设置入口、换装页、参照与专项
- 本交付单提交
