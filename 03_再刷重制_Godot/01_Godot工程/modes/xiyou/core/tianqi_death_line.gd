class_name XTianqiDeathLine
extends RefCounted
## 【cc·天启篇·未经审查】死亡线（勇者＝《魔塔》24 层的勇者，和西游原版的勇者霍格尔无关）的开关和调用名（四线剧情与关卡设计稿 v0.4
## 第 4.1、5.1、5.2、5.7 节）。台词、地点、敌群、异化数值都在 tianqi_data/death_line.json（只读）；流程走 XTianqiLine（四线共用）。
## 开场三节：1「异兆」小小鱼从大厅直接开路进勇者之塔一层（82）→ 二层（83）：恶魔训犬×3，其中一只侵染·宣判者（教死期）；
## 2「蔓延」三层（84）：节末精英蚀骨·收尸人「勇者义从」罗奇，打完进王座（85），空王座上的背影说「现在一切结束了」；
## 3「天外裂」天外天：死亡骑士生存战（XTianqiHorsemen 的 survival：每 3 回合挂一次死期，有人逃跑就变骑士队长）。
## 使徒：10 层侵染·宣判者、20 层蚀骨·替身、30 层化形·骑士队长（XTianqiDeathAlien）。15 层黑暗废墟的绿钥匙、25 层上行天的传闻。
## 35 层影子（每回合一招弱化的神圣剑或挂一次死期）、36 层决战：XTianqiLine.run_shadow／run_final（31～36 层重做后接地图）。
##
## 开关 ENABLED（false＝死亡线一概不出：选线里不能选、开场和楼层节点都不跑、使徒不异化）；只认天启篇存档且这一档选了死亡线，
## 发行构建里还要 XTianqi.RELEASE_OPEN（现在 false），所以发行版、原版档、别的线都不受影响。

const KEY := "death"
const STAGE_DONE := 3

## 开关：false＝死亡线一概不出
static var ENABLED := true


static func data() -> Dictionary:
	return XTianqiLine.data(KEY)


static func allowed(s: XState = null) -> bool:
	return XTianqiLine.allowed(KEY, s)


static func progress(s: XState) -> Dictionary:
	return XTianqiLine.progress(KEY, s)


static func run_shadow(host, s: XState) -> int:
	return await XTianqiLine.run_shadow(host, s, KEY)


static func run_final(host, s: XState) -> int:
	return await XTianqiLine.run_final(host, s, KEY)
