class_name XQiyu
extends RefCounted
## 琦玉专属模块（正式 js/codex/runtime/installQiyuDimensionRuntime.js，CodexQiyuBalance revision 25），新游戏里生效的两条：
## - 163 用技能（物品不算）时 Game_Action itemHit＝1、itemEva／itemCnt／itemMrf＝0：必中、不被反击、不被魔法反射。
##   挂在 XBattleLogic.certain_hit（item_hit 与 _invoke 的反射／反击都读它）；闪避公式在西游恒为 0，不另挂。
## - Game_Actor.addState：163 加状态 2626「欢迎来到异次元」直接返回（数据里没有东西加 2626，只防旧档）；挂在 XActor.add_state。
## 未移植（新游戏里不生效）：法宝 124「一拳」的 normalizeRelic（数据库原件已是新数值，新生成实例实测与原件一致，只打修订标记）；
## 读档时的旧档迁移 Q.sync（去 10264、学 10169、去 2626）——重制不迁移 MV 旧存档。伤害结算 ×0.001 在 XImportedBalance。
## 参照：mv_oracle/qiyu_probe.cjs（generated/oracle/qiyu.json），测试 tests/xiyou_qiyu.gd。

const ACTOR_ID := 163
const BLOCKED_STATE := 2626


static func certain_skill(u, skill: Dictionary) -> bool:
	return u is XActor and int(u.actor_id) == ACTOR_ID and not skill.is_empty() and not XBattleLogic.is_item(skill)


static func blocks_state(actor_id: int, state_id: int) -> bool:
	return actor_id == ACTOR_ID and state_id == BLOCKED_STATE
