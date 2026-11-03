class_name XHonghuang
extends RefCounted
## 洪荒诅咒（installNativeHonghuangRuntime 的 CodexHonghuang，v0.5 S3）第一期：公共事件 1442「洪荒技能抽奖·诅咒」的自选流程。
## 原版没有随机数：15 种全列，连问 5 次（每次去掉已选的，不可取消），选完写变量 1468～1472，再由 1442 后半按变量全员 learnSkill(7200+N)。
## 选项文字照 CodexHonghuang.curseLabel：【档位·×系数】技能名（技能备注 <pos=APs text=…效果:X size=…> 的 X，去掉零宽空格）。
## 选择中的候选与已选（原版 $gameTemp._hhCurseOffer／_hhCursePicked，不进存档）放静态变量。
## 参照 mv_oracle/honghuang_curse_probe.cjs → tests/fixtures/honghuang_curse_oracle.json（tests/xiyou_honghuang_curse）。
## 诅咒倍率（发券、权能掉率）与权能掉落、洪荒压制被动不在本期。

const FACTOR := {"轻": 1.0, "中": 1.2, "重": 1.5}
const TIER := {7211: "轻", 7206: "轻", 7203: "轻", 7208: "轻",
	7210: "中", 7205: "中", 7207: "中", 7204: "中", 7209: "中", 7215: "中",
	7201: "重", 7202: "重", 7214: "重", 7212: "重", 7213: "重"}
const PICKS := 5
const FIRST_VARIABLE := 1468

## $gameTemp._hhCurseOffer／_hhCursePicked（null＝没有，同原版 delete 之后）
static var offer = null
static var picked = null


## CodexHonghuang.curseLabel(i)
static func curse_label(i: int) -> String:
	var id := 7200 + i
	var s := XDB.rec("Skills", id)
	var t: String = TIER.get(id, "轻")
	var m := RegEx.create_from_string("<pos=APs text=(?:\\\\c\\[\\d+\\])?效果:(.*?) size=").search(str(s.get("note", "")))
	var f: float = FACTOR[t]
	return "【" + t + ("·×" + _num(f) if f > 1.0 else "") + "】" + str(s.get("name", "")) + ("（" + m.get_string(1).replace("\u200b", "") + "）" if m else "")


## CodexHonghuang.curseIds：角色已学的诅咒技能（升序）
static func curse_ids(a: XActor) -> Array:
	var out := []
	for id in TIER:
		if a != null and a.skill_ids.has(int(id)):
			out.append(int(id))
	out.sort()
	return out


## CodexHonghuang.curseBonus：诅咒档位系数连乘（下期发券、权能掉率用）
static func curse_bonus(a: XActor) -> float:
	var r := 1.0
	for id in curse_ids(a):
		r *= float(FACTOR[TIER[id]])
	return r


## 选项还剩哪些（原版 left）
static func left() -> Array:
	return (offer as Array).filter(func(i): return not (picked as Array).has(i))


## JS 数字转字符串（1.2、1.5）
static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)
