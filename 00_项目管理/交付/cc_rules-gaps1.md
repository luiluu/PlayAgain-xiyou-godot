# 交付：cc/rules-gaps1（第十五批 FC：战斗规则缺口第一批）

- 车道／工作者：C 规则（cc，项目线程「完成再刷西游Godot引擎重制」）
- 状态：可合并
- 基于：本地 main cbc5bf9b（换源合并中途，v0.62.12）。

## 盘点（新源 v0.62.12 现跑）

- **未翻译状态块清单.py**：剩 46 块（32 个状态），**全部「不可达」**：派单写的「全游戏可达 34 块」是 rules8（dev.318 前后）已做完的那批，新源下没有新增可达的。46 块里只有 108 三昧真火、109 追击 能被运行时 `installZhenhuoMarkRuntime`（v0.53.01 至尊宝真火印记追击，硬编码 addState，数据里查不到）加上，这是角色专属，归白龙（见「可优化」）。
- **插件备注覆盖.py**：数据里有用量的 251 个标签／命令全是「已读」或「已核」。但工具有个盲区：插件说明里写成 `<passiveSTREG[状态编号]>` 这种方括号占位的，数据里的真实写法（`<passiveSTREG0007>`）对不上，报成「没读、用量 0」。按前缀逐个回数据里查，dsPassiveSkill 的 passive* 只有 **passiveSTREG** 是真缺（23 个技能＋防具 4088 有用量，重制完全没读）；其余（EWPN、EARM、WPNM、ARMM、ELEM、SPBST、ATKST、XPBST、PBSTEX 等）重制都读了。
- **AnimatedSVEnemies 4 标签**（BREATHING SPEED、SIDEVIEW SHOW SHADOW、SIDEVIEW WEAPON、SIDEVIEW BATTLER）：`battle/sv_enemy.gd`、`battler_sprite.gd`、`core/appearance.gd` 都实打实读了，不是名字撞上。
- 顺查 dsPassiveSkill itemCri 时发现 **SkillCriPush（暴击率增加）在原版里是死的**（见下），以及新源两条通用战斗规则 runtime 还没跟：v0.62.12 `installCritFloorRuntime`（暴击下限）、v0.62.11 `installOtbRestoreCapRuntime`（恢复行动插回守 5 次）。v0.53.01 `installCounterGuardRuntime`（反击者已不在敌群就跳过）是 MV 的防崩补丁，重制敌群从不移除成员（`enemies` 只在开战 append），不涉及。

## 做了什么

### ① passiveSTREG 状态无效化（照原版）

- 原版：`Game_Actor.stateResistSet` 追加被动缓存里 `passiveSTREG` 开头的键，后缀按数值（007／0007／00010 都行）。缓存只从**技能**读（含特性 43 加的技能、状态给的技能），防具 4088 阎罗兜帽备注里的同名标签原版不读。
- 重制：`core/actor.gd` 覆写 `traits_set(14)`，追加 `passive_state_resists()`（随 `skills()` 即时读，时序同其它被动标签与特性 14；所有抵抗判断都走 `traits_set(TRAIT_STATE_RESIST)`，一处覆盖）。
- 参照：`passive_probe.cjs` 新用例 `streg`：学 38／84／88／1174／5568／5979／5699／2366／3206 各技能后的抵抗表、7／8／9 能不能挂上；状态 686 天道*祝福经特性 43 给 5500 绝对理智后（refresh 后）也抵抗；防具 4088 装上不抵抗。测试 `xiyou_passive` `_streg`。
- 原版缓存时序的小差别（不复刻）：原版 stateResistSet 跟 krz refresh 才重算，挂上 686 到下一次 refresh 之间读不到 5500 的抵抗；重制即时。跟其它被动标签一个口径。

### ② SkillCriPush 暴击率增加（原版 bug，O-待定，默认修好）

- 原版：dsPassiveSkill `refreshPassiveCache` 用 `/<SkillCriPush(\w+):\s*(\d+)>/` 读，数据里 84 个标签（防具、技能、武器上）全写成 `<SkillCriPushAll: 15%>` 这种带 %，数字后面跟 % 一条都对不上，`critPush` 恒 0，itemCri 只算面板暴击率（参照 `passive_probe` `cripush`：装 1736、学 1282／1730 后 critPush 全 0，itemCri＝cri）。按 meta 读、认技能号的那版被注释掉了。说明文字和 CritFloor 运行时注释都把它当作在生效。
- 修法（`XActor.FIX_CRIT_PUSH`，默认 true）：% 可写可不写、带正负号，技能号后缀也认（被注释那版的意思）；itemCri 里加到攻击方暴击率上（`XActor.crit_push`：指定技能＋战技 Zj／魔法 Mf＋全局）。false 回到原版恒 0。
- **影响面不小**：这些装备／技能的暴击加成从没生效过，修好后这些东西的暴击率会实打实上去（常见 10%～20%）。写进「需要用户决定」。

### ③ v0.62.12 暴击下限（跟新源）

- `installCritFloor`：攻击方暴击率（面板＋critPush）≤0 时按 0 算，修「负暴击率碰上 >100% 暴击回避负负得正」；猫心必暴、云裳加成照旧。重制 `XBattleLogic.item_cri` 加 `maxf(rate, 0)`。复现新源，不登 O 号。参照 `cripush.floor` 5 行（cri −0.5／0／0.3 × cev 2／0.5）。
- 智能 AI 期望伤害的暴击率原来手写 `a.cri × (1 − cev × 甚尔)`，原版 Codex_SmartBattleAI 是 `action.itemCri(target)` 整条链；改成调 `logic.item_cri`（多了 critPush、暴击下限、谷雨不暴、猫心、云裳），跟原版一致。

### ④ v0.62.11 恢复行动插回守 5 次（跟新源）

- 重制原来就守 5 次（早先的重制优化），当前回合算法跟新源一样；**下个回合**不同：新源 `min(max(行动次数 − 本回合已行动, 1), 5)`，重制原来 `max(min(行动次数, 5) − 已行动, 1)`，行动次数 >5 且本回合已动过时少插（8 次、已动 4：新源 4、重制 1）。`_insert_orders` 改成新源算法。
- 参照：`otb_probe.cjs` 加 `restore_cap` 8 行，夹具 `tests/fixtures/otb.json` 同步（插件 SHA 不变），`xiyou_otb` 逐行比。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 暴击率增加 SkillCriPush（`modes/xiyou/core/actor.gd` `refresh_passive`／`crit_push`，`battle/battle_logic.gd` `item_cri`） | dsPassiveSkill 正则要求数字后直接是 `>`，数据 84 个标签全带 %，critPush 恒 0，这些装备／技能的「暴击率+n%」从不生效 | 照标签加暴击率（Zj／Mf／All／技能号，% 可省、带符号） | 原版缺陷（正则写错） | `XActor.FIX_CRIT_PUSH = false` | cc（规则 rules-gaps1） | 待用户决定 |

## 变更记录草稿

## 2026-11-07 【cc·规则·未经审查】战斗规则缺口第一批：状态无效化被动、暴击率增加、暴击下限、恢复行动插回（dev.待定）

- dsPassiveSkill `<passiveSTREG状态编号>` 状态无效化补上（正直、清晰、金斗庇佑、绝对理智等 23 个技能）：学了就免疫对应状态；参照 passive_probe streg。
- `<SkillCriPush…: n%>` 暴击率增加：原版正则对不上 %，从没生效；默认修好（O-待定，`XActor.FIX_CRIT_PUSH`）。
- 跟新源 v0.62.12 暴击下限：攻击方暴击率 ≤0 时自然暴击为 0；智能 AI 的暴击率改走完整 itemCri。
- 跟新源 v0.62.11：解除不能行动后插回下个回合的次数按新源算法（行动次数多的角色以前少插）。
- 玩家可见：带「暴击率+n%」的装备、技能现在真的加暴击；学了「正直」「清晰」等被动的角色不再中对应的异常状态。

## 交接板

- 下一步：真火印记追击（`installZhenhuoMarkRuntime`，至尊宝专属，108／109／1090）归白龙角色专属批次。
- 用户试玩说明：带「暴击率+n%」的装备（如 1736）现在暴击明显变多；学了正直（15 级）的角色免疫 7／8／9 号状态。
- 需要用户决定：**SkillCriPush 暴击率增加要不要修好**。原版这 84 个标签（装备、技能）的暴击加成从没生效过（正则写错），修好后暴击率会实打实上去，平衡会变；默认已修，不要就把 `XActor.FIX_CRIT_PUSH` 设 false。

## 待交叉核查

- cc/rules-gaps1：甲档（战斗核心）`core/actor.gd`（traits_set 覆写、refresh_passive critPush、crit_push）、`battle/battle_logic.gd`（item_cri、_insert_orders）、`battle/smart_ai.gd`（expected_damage 暴击率）；探针 `passive_probe.cjs`（streg、cripush）、`otb_probe.cjs`（restore_cap）与夹具 `tests/fixtures/otb.json`。

## 进度账

- 战斗规则：dsPassiveSkill 用到的被动标签补齐最后一个（passiveSTREG）；新源通用战斗 runtime 跟进 CritFloor、OtbRestoreCap。

## 可优化（流程／工具／效率）

- 建议：`插件备注覆盖.py` 把说明里的方括号占位（`<passiveSTREG[状态编号]>`、`<ChangeTo[技能编号]>`）当前缀＋数字去数据里匹配，现在报成「没读、用量 0」，真缺 passiveSTREG 就这样漏了两轮。归工具车道（FG），预计半小时。
- 建议：`未翻译块清单.py` 的可达性只看数据，运行时硬编码 addState 的（如 installZhenhuoMarkRuntime 加 108／109）报成不可达；可以扫一遍 `js/codex/runtime/*.js` 的 `addState(常量)`／`var X = 数字` 加一档「运行时可达」。归工具车道。

## 验证

- 合 main 2443a7b0 后 `--补齐`；改了 `passive_probe.cjs`，工作树跑 `同步正式西游.py --accept-additions`（只重跑 passive，passive.json 新增 streg、cripush 两例已接受，指纹留下）。`otb_probe.cjs` 是夹具式探针，`tests/fixtures/otb.json` 手动同步（插件 SHA 不变）。
- `语法检查.py` 635 个 .gd 0 问题；`工具回归.py` 全过。
- 云端选测第一轮（8a7ebfb5，基准 2443a7b0，314 场景）：311 过，挂 3 个：xiyou_otb（`_insert_orders` 用 `==` 比数组，两个空数组相等，下个回合被当成当前回合，已改 `is_same`）、xiyou_passive（测试里抵抗该走 `sequence_add_state`，重制 `add_state` 本身不查抵抗；critPush 断言漏了全局那份，都是测试写错）、xiyou_floor_reach080 `chest_reward_reset`（宝箱后装备 +2 而不是 +1，本机同一提交重跑 27/27 过，记偶发；本单没碰地图事件和掉落）。
- 修后本机：xiyou_otb 34/34、xiyou_passive 361/361、xiyou_floor_reach080 27/27。云端第二轮（7a2c1d6f，基准 8a7ebfb5，206 场景）全过：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42390228660
- 回退支：`xiyou_passive` 里 `XActor.FIX_CRIT_PUSH = false` 逐行比原版参照（critPush 全 0、itemCri＝面板暴击率）。

## 本分支提交

- 9b0b0bac passiveSTREG
- 419312bd SkillCriPush＋暴击下限＋AI 暴击率
- 2c0e798f OTB 恢复插回
- 8a7ebfb5 合 main
- 7a2c1d6f 云端挂的三处修正（is_same、测试）
