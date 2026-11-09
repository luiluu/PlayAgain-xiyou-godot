# 交付：cc/bajie-interp7

- 车道／工作者：A 内容／八戒（cc，GB5 interp7，Opus medium）
- 分支起点：github/main e8967abd（rules-gaps8 当时还没推上 GitHub）；车道在 scratchpad 的 `git clone --shared` 里做（主工作区是合并现场，没碰），交付后推回本库并删掉 clone。
- 状态：可合并

## 盘点：条件分支 111 角色／敌人／载具条件门（全源 v0.62.12，地图＋公共事件＋敌群页）

原版以 `rpg_οbjects.js` Game_Interpreter.command111 为准，外层 YEP_CoreEngine 只接管 0／2／12 三类，其余照原版；子类型用到的方法再查插件与 Codex 运行时覆写（YEP_ItemCore hasWeapon／hasArmor、YEP_AutoPassiveStates／krz isStateAffected、各 Codex skills 包装）。「战斗可达」＝技能／物品效果 44、敌群页 117 能调到的公共事件（含 117 链）。

| 子类型 | 全源 | 切片 | 战斗可达（公共事件） | 重制 | 结论 |
| --- | --- | --- | --- | --- | --- |
| 4·0 角色在队 | 469 | 450 | 239 | 原来查全队 `s.party` | **真缺**：原版用 `$gameParty.members()`，战斗中只算出战成员，后备不算。已修（见下） |
| 4·1 名字／4·2 职业 | 0 | 0 | — | 有实现 | 全源没用到，不动 |
| 4·3 技能 | 1290 | 744 | 591 | `XActor.skills()` 按编号找 | 一致（skills() 已接 Codex 各包装）。原版潜在怪处见下「没改的」 |
| 4·4 武器／4·5 防具 | 46／9 | 46／9 | 46／8 | 身上按底材编号比 | 一致（YEP_ItemCore hasBaseItem 比 baseItemId，非独立件比本体） |
| 4·6 状态 | 18 | 18 | 17 | `state_ids` | 一致；被问到的 11 个状态（692～698、995、1825、2566、2765、2769）都不是 YEP 被动状态 |
| 5·0 敌人出现 | 0 | 0 | — | 有实现 | 全源没用到 |
| 5·1 敌人状态 | 107 | 107 | 87 | 战斗读当场敌人、地图读上一场 | 一致；地图一侧已有 troop_condition 原版参照，战斗一侧死亡挂状态 1 |
| 6 角色朝向 | 80 | 80 | 0（都在地图） | 地图实现；战斗里记 skipped 返回 false | 一致（原版 character() 在战斗中返回 null → false） |
| 13 载具 | 44（都是飞艇） | 44 | 41 | `vehicle_type` | 一致，airship_probe 已有参照 |
| 11 按键 | 0 | 0 | — | 没实现 | 全源没用到 |

### 修了的

- **战斗中「角色在队」只算出战成员**（`mv_event_core.gd` 类型 4 子类 0 改用 `_party_members()`：地图是全队，XBattleEventRunner 是出战成员）。例：CE43「PUA」先问 13 号在不在队、会不会 319，成立就让 13 号强制行动并给全队挂 345；13 号在后备时原版整段跳过，重制原来照样给出战成员挂 345。战斗可达的 239 处这类条件都受影响，后备有人时才会不同。
- 原版参照专项 `xiyou_cond111`：新探针 `mv_oracle/cond111_probe.cjs`（实跑冻结 v0.62.12，只写 `.sandbox/cond111.json`，拷成 `tests/fixtures/cond111_oracle.json`，不接全量同步）。队伍 6 人、出战栏 [1,8,10,9,0]，13、14 在后备；地图上与战斗中各问 13 条（在队、技能、状态，含不存在的角色）。重制地图用 MVInterpreter、战斗用真开的 XBattleLogic＋XBattleEventRunner 逐项对。
  - 692 带 removeAtBattleEnd，本版 startBattle 开战时会从出战成员身上拿掉（探针只把 `_inBattle` 设真、没真开战），测试里先断言开战确实拿掉了，再「战斗中重新挂上」后比。
  - 反向验证：把修复改回 `s.party.has(aid)`，xiyou_cond111 失败（咬得住）。

### 没改的（记一笔）

- 原版怪处、无影响：CodexZhenqi 的 skills 包装把 28 个道法技能（10396～10423）换成副本，`hasSkill` 用 `skills().contains($dataSkills[n])` 比的是对象，所以原版里这些技能的 hasSkill 恒为 false。全源 111 和脚本里都没有对这 28 个技能问 hasSkill，重制按编号比、结果为 true，不做开关也不登记 O 号；以后有事件问到再说。
- 5·0「出现」重制用 `is_alive()`，不看隐藏（原版 isAlive 含 isAppeared）；全源没用到，不动。

## 变更记录草稿

## 2026-11-09 【cc·八戒·未经审查】条件分支 111「角色在队」战斗中只算出战成员（interp7，dev.待定）

- 盘点条件分支 111 的角色、敌人、载具几类子类型（全源计数、切片、战斗可达），对照原版 command111 与插件覆写：只有「角色在队」一处不同。原版用 `$gameParty.members()`，战斗中只算出战成员；重制原来查全队，后备的人在战斗里也算在队。改成走 `_party_members()`（地图全队、战斗出战成员）。
- 新增原版参照专项 `xiyou_cond111`（探针 `cond111_probe.cjs`，夹具 `cond111_oracle.json`）：后备成员地图上算在队、战斗中不算，技能与状态两边一致。
- 盘点清单与没改的两处（道法技能 hasSkill 原版恒假、敌人出现不看隐藏，全源都没用到）见交付单 cc_bajie-interp7。
- 玩家可见：后备里有某角色时，战斗中靠「该角色在队」触发的效果（如 PUA 再次释放）不再误触发。

## 交接板

- 下一步：无新增。dev.411 列的解释器剩余里「角色状态／载具／敌人条件门」这一项可以划掉。
- 用户试玩说明：后备成员不再触发「某角色在队」才有的战斗效果。
- 需要用户决定：无

## 进度账

- 事件解释器：条件分支 111 角色／敌人／载具条件门盘点完，补一处，完成度按总装口径

## 留给分段

- 无（没加预设，没碰 event_state_probe.cjs／event_presets.json）

## 可优化（流程／工具／效率）

- 无

## 验证

- `语法检查.py`：659 个 .gd，0 问题。
- 本地：`xiyou_cond111`、`xiyou_troop_condition`、`xiyou_battle_common_events`（95/95）通过；反向验证咬得住。
- `工具回归.py`：全部通过（58 秒）。
- 云端选测（43 个场景，>40 走云端，基准 e8967abd1，`--no-upload`）：5b9b0218 通过，43 个场景、3 片，最长一片 10.3 分钟（含 event_compare 四份、troop_events 五份）

## 待交叉核查

- `modes/xiyou/core/mv_event_core.gd`（事件核心，地图与战斗共用）
- `tests/xiyou_cond111.gd`、`mv_oracle/cond111_probe.cjs`

## 本分支提交

- 5b9b0218 interp7：条件分支 111「角色在队」战斗中只算出战成员，新增 cond111 原版参照专项
