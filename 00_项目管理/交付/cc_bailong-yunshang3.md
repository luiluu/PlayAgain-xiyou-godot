# 交付：cc/bailong-yunshang3

- 车道／工作者：E 角色专属／白龙_9（cc）
- 状态：WIP（只做了盘点与接续要点；白龙_9 上下文接近停手线，交下一个白龙会话）
- 分支从 cc/bailong-yunshang2 末端 5e26ae5a 切出（总装九派单）。工作树 great-snyder-6f0aed 上的就是这个分支，接手直接在这里做，或 `git worktree add` 后 `新建工作树.sh --补齐`。

## 范围（总装九）

其余 10 件天衣的战斗效果（0、1、2、3、4、5、6、7、10、12）、赊账、幽灵、借技能、云裳自动战斗 AI。AI 的智能档案参照八戒 toji4 的 XSmartAI 档案通道：第五批合进 main 后 rebase 过去再做，合之前先做别的。做法、验证、交付同 A 批（选测写全名、CHECK_JOBS=3、不用 --cloud、不跑全量）。

## 接续要点

1. 先读 `cc_bailong-yunshang2.md`：A 批已有的底子都在 `modes/xiyou/core/yunshang.gd` 后半段——战斗数据 `data(a)`（每件天衣一份，按 instanceId＋本场编号重建）、`awake`、`wake`、`setting`（天衣铺设置，现用默认值）、`frame`（当前主动行动）、`derived`（派生伤害，钩子按 `derived_frame` 走）、`burst`、`add_actions`／`took`（行动来源标签）、`split`／`calculate_split`、`battle_param`（所有角色的战斗内能力值层）、`skill_ids`（天衣给的技能）。B 批的天衣直接往这些函数里加分支。
2. 参照：`mv_oracle/yunshang_probe.cjs` 末尾 p2.* 那套（`battle2` 建队＋startBattle＋startTurn、`ys` 快照、`cast2`），B 批照样加 p3.*；专项 `tests/xiyou_yunshang.gd` 的 `_p2_case`／`_p2_compare` 照样扩。改错→重跑用 `07_开发环境/godot --headless --path 01_Godot工程 res://tests/xiyou_yunshang.tscn`（8 秒），交付前再走并行测试。
3. 坑（A 批踩过）：天衣有 req_level，等级不够原版穿不上、不生效，参照各例按需求给等级；探针要新角色出战就开 2494、挪到 `_actors` 与 `_battleMembers` 第一位；OTB 开回合时最快的人已取走，专项开回合后要 `logic.next_subject()` 一次（`_turn`）；GDScript `a().merged(b())` 先求 b()；字典用字符串键；钩子新字段要登记进 `actor_damage_hooks.gd` descriptor 的 writes，否则整次伤害 NaN。
4. 原版行号（installNativeYunshangRuntime.js）：

| 内容 | 行 | 要点 |
| --- | --- | --- |
| 赊账（2 赊月偿星） | 228～230 settleDebt／repay、238 endTurn 到期、243 endBattle 结清、373 executeHpDamage 记债、389 prepare 觉醒转换、419 apply 转附加伤害、428 finishAction 还债 33% | 50% 承伤记债（上限最大生命 200%），到期扣；觉醒时下一次主动命中把债 ×188.88 转符针附加伤害 |
| 幽灵（3 不渡黄泉） | 345 ghostDie、346～350 revive／deadMembers／smoothDeadTarget／itemEffectRemoveState、353 stateAdded 死亡、431 finishAction 计次、238 endTurn 到期 | 每场首次倒下留衣魂 2 次真实行动；觉醒时完成 2 次后回 50% 生命／MP；赠行、储行不计 |
| 0 山河作骨 | 248 skills 加山河击、370～372 executeHpDamage 分担 33% 进 bank、377 守势反击、388 prepare 取 bank、420 apply 转附加伤害；nativeDamage 里山河击取暴伤／终伤下限那段是死代码 | 公式山河击一期已有 |
| 1 百厄成锦 | 353～357 stateAdded 收录减益、418 apply 转给目标 | 要 stateCopy（222 行，含异化 withFrame 支援帧） |
| 4 逆命换锦 | 248 skills 加换锦、398～401 applyCommand 交换 | 不醒：自选的一个状态互换（重制没有选择窗，先用 AI 那套 aiExchange）；醒：全队减益转全敌、夺 3 个增益 |
| 5 千军入袖 | 265 makeTargets 的 _yunSleeve、421 apply 溢出、749～756 split 的 targets | 收袖开关原版在战斗指令窗（535 行），重制先给 API；溢出走 derived {damage} |
| 6 空袖藏星 | 248 skills 借技能、249 borrowable、253 meets、387 prepare 借双攻、65 param 借双攻 | 借的技能表在天衣铺战前设置（养成期），先给 API |
| 7 九曲回针 | 216 wake 清针眼冷却、254 meets 越过冷却、387 prepare、427 finishAction 缩冷却 | 针眼技能也是战前设置 |
| 10 孤灯照众 | 358～363 stateAdded 共享增益、229 resetRound lampRound | 要 stateCopy；Y._teamBuffApplying（394 行）挡全体增益技能 |
| 12 一身两世 | 429～430 finishAction 复演（derived {damage}）并复制普通状态 | 要每段命中记录 _yunHits（376 行，A 批没记，补在 applied） |
| 自动战斗 AI | 448～468（evaluate、aiBattle／aiAwake／aiGather／aiExchange／aiOutput）、541 makeAutoBattleActions | 智能档案等第五批合进 main 后照 toji4 的 XSmartAI 档案通道接 |

5. 建议顺序：先补 stateCopy 与 _yunHits（1、4、10、12 都要）→ 赊账与 2 → 幽灵与 3 → 0、5、12（都走 derived）→ 6、7（借技能、针眼，带设置 API）→ AI（第五批合入后）。量大，建议拆两期交付：先 2／3／0／1／4／12＋赊账＋幽灵，再 5／6／7／10＋AI。

## 本分支提交

- 本提交：盘点与接续要点（无代码）
