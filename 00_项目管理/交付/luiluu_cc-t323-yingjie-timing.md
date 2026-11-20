# 交付：luiluu/cc-t323-yingjie-timing

- 车道／工作者：T323 影劫出招时机两处（T319 P2×2）＋538 变身后首领保底（T322 P2）＋同堕播报占位、日志顺序、T322 测试假阳性（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·天启篇·未经审查】心魔【影劫】记招时机两处、30 层入魔 538 变身后仍算首领、同堕播报占位与日志顺序（dev.待定）

- 依据：T319 小A Neon 核查回执（11-20）P2-1、P2-2、P3-1、P3-2 与第四节润色句；T322 小A Neon 核查回执（11-20）P2-1、P3-1。
- **影劫重演招不被先手覆写**（T319 P2-1）：心魔在 `decide`（轮到时当场决定）才读 `c.mirror` 合成【影·原招】，重演回合挑战者先手出招会在它之前把 `mirror` 改掉，蓄势回合明牌的招、控招诱影都被破坏。现在映照分两格：`mirror`（这一轮要演的）和 `mirror_next`（下一轮候选）。重演回合（`charge_turn == turn − 1`）里心魔还没出【影·原招】时，挑战者新出的招只写 `mirror_next`；心魔出完招（`decide` 先按 `mirror` 合成再转正）或回合末（心魔被控没出手）转正。蓄势回合里照旧以最新的为准（控招诱影不变）。
- **被控跳过行动不记招**（T319 P2-2）：记招从 `act_begin` 拆成 `XTianqiXinmoTraits.mirror_note`，`BattleLogic.act` 在判完 `can_move`／五条悟信息过载之后、只在没跳过时调；`_forced_run` 紧跟 `act_begin` 调（强制行动不看能不能动）。发作行动照旧不记（`act_fit`）。
- **538 变身后首领保底**（T322 P2-1）：`BattleLogic.enemy_transform` 在 `transform_after` 后，`boss_difficulty_boss` 为假且 `XGuardianRework.transform_floor(e) > 0` 时置真。30 层玉皇大帝→入魔 538（不在 MOG_BossHP）变身后，天启篇 BOSS_RULE、首领减益减半、屠苏击晕豁免、首领状态栏等读 `boss_difficulty_boss` 的地方都按首领；随之也吃首领霸体（双数回合 `sync_boss_armor`），跟变身前一样。西游档、`TRANSFORM_IDENTITY` 关时 `transform_floor` 为 0，照原版。929／930 本来就在首领表，不变。
- **同堕镇压播报改占位**（T319 P3-1，采用小A 润色句）：`suppress`「%s 守住本心迎面一击，消去 %d 层「堕势」并压制心魔（%d 回合）！」读实际消去层数（`min(suppress_shed, 堕势)`）和 `suppress_rounds`；`suppress_only`「%s 守住本心迎面一击，压制了心魔的【同堕】（%d 回合）！」。盗形 open 括号改「（伤害提高、受伤降低）」。`天启篇数据校验.py` 的占位个数同步改成 3／2。
- **日志顺序**（T319 P3-2）：`act`、`_forced_run` 收尾先交 `XTianqiBrand.take_logs`、再交心魔特点的，「印纹发亮」排在「借势【同堕】」前。回合开始那段本来就是烙印在前，不动。附带：透骨、盗形等别的心魔播报跟同一次行动的烙印播报，相对顺序也变成烙印在前（同一次行动里的独立事件，我判断无碍）。
- **T322 测试假阳性**（T322 P3-1）：`tfid.default_on` 挪到 `_run` 开头、改任何开关之前断言；`_run` 保存／恢复 `TRANSFORM_IDENTITY`；补变身后再上第 4 层强化仍封顶 3 层（`tfid.N.buff_cap3`）。
- 回退：影劫两处和日志顺序没有单独开关（修时机，原写法是缺陷）；538 首领保底随 `XGuardianRework.TRANSFORM_IDENTITY = false` 一起回到 T317。
- 测试：`tests/xiyou_tianqi_xinmo_traits` 加影劫先手（`yj.preempt_*`、`yj.promote_*`、`yj.after_cast_direct`、`yj.t6_preempt_keeps`）、真走 `act` 记招／被晕不记（`yj.act_mirrors`、`yj.stun_*`）、同堕播报带回合数、日志顺序（`td.log_order`，真走 `act` 打满印纹）；`tests/xiyou_tianqi_pozhen_type` 加 `tfid.N.boss_flag`、`tfid.N.buff_cap3`、`tfid_off.30.boss_lost_538` 也查标记、`tfid_xy.538_not_boss`。
- 玩家可见：影劫心魔按蓄势回合明牌的招重演，挑战者在重演回合先手、或被晕没出手，都不会改掉它；30 层玉皇大帝入魔后仍是首领；同堕镇压播报按实际层数、回合数显示。

## 交接板

- 下一步：无新增。
- 用户试玩说明：天启篇闭关第 5 段（影劫）心魔重演的招就是蓄势回合预告的那招；30 层玉皇大帝入魔后控制减半、首领状态栏照常。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- 专项本机：`xiyou_tianqi_xinmo_traits` 212/212、`xiyou_tianqi_pozhen_type` 139/139（并行测试统一带 `--audio-driver Dummy`）。
- 反向验证 6/6 咬住：影劫不锁重演招、被控也记招、回合末不转正、日志顺序改回、538 不保底首领、西游档也保底。
- `语法检查.py` 过；`工具回归.py` 过；`天启篇数据校验.py` 全部通过。
- 云端选测 e9370ccfc7（基准 b9f3d9d534）336 个场景 16 片全过（run 44800733353）。
- 合并时按派单带 `--oracle`（改了 `battle_logic.gd` 的 `enemy_transform`，西游档逻辑不变）。
- 待交叉核查的核心文件：`battle_logic.gd`（act 记招位置、两处日志顺序、enemy_transform 首领保底）、`xinmo_traits.gd`。
- 玩家可见文字（`xinmo_traits.json` 的 suppress、suppress_only、盗形 open）：采用小A 润色句原文，待小A 文字审。

## 本分支提交

- e9370ccfc 影劫记招时机两处、538 变身后首领保底、同堕播报占位、日志顺序、T322 测试假阳性
