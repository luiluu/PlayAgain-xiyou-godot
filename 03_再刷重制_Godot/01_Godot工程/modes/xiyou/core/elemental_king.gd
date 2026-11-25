class_name XElementalKing
extends RefCounted
## 西游档玩家定制装备「元素之王的赐福」（T472，阿夜专属，仅西游档生效，天启篇零改动）。
## - 槽位：形态栏（etypeId 19）、饰品防具类型（atypeId 5，全职业可穿）、需求等级 60。
## - 品质与词条：品质 12（神话★，与「头顶」7940 同级），随机词条池对齐 7940（15% 混沌词条 4897～4901 / 40% 神话词条 4800～4896，随 XAffixRate 难度浮动），
##   0～12 孔（slots 6 ± 6），基础面板带 ±500 随机浮动；随穿戴者等级线性成长（customParams，每级生命+100、魔力+50、六维各+25，无封顶）。
## - 随机元素：爆出实例化时从 13 种活跃元素（火/冰/地/雷/自然/奥术/神圣/黑暗/虚空/混沌/空间/水/风，ID 2～9、11～15）均等随机定一种，存入实例字段 elemKingElement 与备注行，存档读回不变。
## - 战斗双元素：佩戴者在西游档发动伤害类行动（dmg_type in [1,2,5,6]）时，XDamage.action_elements / original_elements 追加该元素，
##   形成流萤式「原属性＋X」双元素（择优结算抗性、克制与增伤；原无属性伤害招保留无属性保底，避免遇免疫降伤）。
## - 掉落：西游档二层深渊（「深渊:未知存在」地图）全部【未知存在】敌人击败后，每只独立以固定 1/888 掉落（不吃队伍掉率加成、不被挂机/品质屏蔽）。
## - 回退开关：ENABLED = false 时停止掉落且战斗附加元素不生效（数据库定义常驻以兼容已有存档）。

static var ENABLED := true

## 号段：Armors 表外追加（原表到 8000，五条悟眼罩 8001，冠军戒指 8010～8012）
const ARMOR := 8013
const TEMPLATE := 5203
const ETYPE := 19
const ATYPE := 5
const REQ_LEVEL := 60
const QUALITY := 12
const PRICE := 9999

## 图标：独立 32×32 PNG（T474 定稿 A 晶内映纹），XUI.icon_texture 分流
const ICON := 340000
const ICON_PATH := "res://content/xiyou/icons/elemental_king_blessing.png"

## 掉落：二层深渊所有【未知存在】固定 1/888
const DROP_RATE := 1.0 / 888.0

## 全部 13 种活跃元素（ID 2～9、11～15，与 XDamage.ACTIVE 对齐，不含物理与治疗）
const ELEMENTS := [2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15]
const ELEMENT_FALLBACK_NAMES := {
	2: "火焰", 3: "寒冰", 4: "大地", 5: "雷电",
	6: "自然", 7: "奥术", 8: "神圣", 9: "黑暗",
	11: "虚空", 12: "混沌", 13: "空间", 14: "水", 15: "风",
}
const ELEM_KEY := "elemKingElement"

## 基础底子（±500 随机浮动）＋ 每级线性成长（随穿戴者等级，不封顶）
const BASE_PARAMS := [4000, 2000, 1000, 1000, 1000, 1000, 1000, 1000]
const PARAM_VARIANCE := 500
const GROWTH_PER_LEVEL := [100.0, 50.0, 25.0, 25.0, 25.0, 25.0, 25.0, 25.0]

const NAME := "元素之王的赐福"
const DESCRIPTION := "形态\n纪念群友大手子首通洪荒的特殊装备。\n他亲自替大家向元素之王讨来的福利。"
const ELEM_PLACEHOLDER := "赐福元素：获得时从十三种元素中随机定下一种（攻击时额外附带该属性）"

static var _icon_cache: AtlasTexture = null


static func is_blessing(rec) -> bool:
	if not (rec is Dictionary) or rec.is_empty():
		return false
	if rec.has("kind") and str(rec.get("kind", "")) != "armor":
		return false
	if not rec.has("kind") and not rec.has("atypeId"):
		return false
	return int(rec.get("base", rec.get("id", 0))) == ARMOR


static func element_of(rec) -> int:
	if not (rec is Dictionary):
		return 0
	var eid := int(rec.get(ELEM_KEY, 0))
	return eid if ELEMENTS.has(eid) else 0


static func element_name(elem_id: int) -> String:
	var names: Array = XDB.system().get("elements", [])
	if elem_id > 0 and elem_id < names.size() and str(names[elem_id]) != "":
		return str(names[elem_id])
	return str(ELEMENT_FALLBACK_NAMES.get(elem_id, ""))


static func custom_params() -> Dictionary:
	var terms := []
	for i in range(8):
		terms.append({"k": 0.0, "level": float(GROWTH_PER_LEVEL[i]), "vars": {}})
	return {"params": terms, "ignored": []}


static func affix_rows() -> Array:
	var chaos_ids := []
	for i in range(4897, 4902):
		chaos_ids.append(i)
	var mythic_ids := []
	for i in range(4800, 4897):
		mythic_ids.append(i)
	return [{
		"kind": "prefix",
		"choices": [
			{"chance": 15, "ids": chaos_ids},
			{"chance": 40, "ids": mythic_ids},
		],
	}]


static func _aps_line(text: String) -> String:
	return "<pos=APs text=%s size=18 color=rgba(255,255,255,1) line=false align=0>" % text


static func _element_text(elem_id: int) -> String:
	var ename := element_name(elem_id)
	if ename == "":
		return ELEM_PLACEHOLDER
	return "赐福元素：%s（攻击时额外附带%s属性）" % [ename, ename]


static func base_note() -> String:
	var lines := [
		"<dh:183>",
		"<req_level:%d>" % REQ_LEVEL,
		"<Random Variance: %d>" % PARAM_VARIANCE,
		"<quality:%d>" % QUALITY,
		"<ici:%d>" % QUALITY,
		"<Prefixes>",
		"4897-4901 15% 4800-4896 40%",
		"</Prefixes>",
		_aps_line("等级需求:%d" % REQ_LEVEL),
		_aps_line("\\c[1]%s" % ELEM_PLACEHOLDER),
		_aps_line("\\c[1]成长：穿戴者每升一级，生命+%d、魔力+%d、其余六项属性各+%d" % [
			int(GROWTH_PER_LEVEL[0]), int(GROWTH_PER_LEVEL[1]), int(GROWTH_PER_LEVEL[2]),
		]),
	]
	return "\n".join(lines)


## XDB.table("Armors") 读表时追加（常驻，确保已有存档随时能查表）
static func patch_armors(t: Array) -> void:
	if TEMPLATE >= t.size() or not (t[TEMPLATE] is Dictionary):
		return
	while t.size() <= ARMOR:
		t.append(null)
	if t[ARMOR] is Dictionary and str(t[ARMOR].get("name", "")) != "" and not bool(t[ARMOR].get("_elem_king", false)):
		push_error("XElementalKing: 防具 %d 已被正式源占用，元素之王的赐福未写入（需挪号）" % ARMOR)
		return
	t[ARMOR] = build(t[TEMPLATE])


static func build(template: Dictionary) -> Dictionary:
	var out: Dictionary = template.duplicate(true)
	out["id"] = ARMOR
	out["_elem_king"] = true
	out["name"] = NAME
	out["description"] = DESCRIPTION
	out["iconIndex"] = ICON
	out["etypeId"] = ETYPE
	out["atypeId"] = ATYPE
	out["price"] = PRICE
	out["params"] = BASE_PARAMS.duplicate()
	out["traits"] = []
	out["note"] = base_note()
	out["meta"] = XTianqiSkills.parse_meta(str(out["note"]))
	out.erase("yep")
	out["customParams"] = custom_params()
	out["equipment"] = {
		"affixes": affix_rows(),
		"suits": [],
		"variance": PARAM_VARIANCE,
		"slots": 6,
		"slotVariance": 6,
		"requirements": {"actors": []},
	}
	return out


## 装备实例化掷骰时（XGear.roll_item 末尾）随机定下 13 种活跃元素之一并写进实例
static func on_roll(item: Dictionary, owner: XState = null) -> void:
	if not is_blessing(item):
		return
	var eid := element_of(item)
	if eid == 0:
		var idx := mini(floori(XGear.roll(owner) * ELEMENTS.size()), ELEMENTS.size() - 1)
		eid = int(ELEMENTS[maxi(0, idx)])
	assign_element(item, eid)


## 给实例写入选定元素并更新其说明行（不覆盖词条合并后的品质与特效行）
static func assign_element(item: Dictionary, elem_id: int) -> void:
	if not is_blessing(item) or not ELEMENTS.has(elem_id):
		return
	item[ELEM_KEY] = elem_id
	var note := str(item.get("note", ""))
	var target := _aps_line("\\c[1]%s" % _element_text(elem_id))
	var placeholder_line := _aps_line("\\c[1]%s" % ELEM_PLACEHOLDER)
	if note.contains(placeholder_line):
		note = note.replace(placeholder_line, target)
	else:
		var rx := RegEx.create_from_string("<pos=APs text=\\\\c\\[1\\]赐福元素：[^>]*>")
		if rx.search(note) != null:
			note = rx.sub(note, target, true)
		else:
			note = target if note == "" else (note + "\n" + target)
	item["note"] = note


## 战斗双元素（XDamage.action_elements / original_elements）：
## 仅西游档生效，佩戴者发动伤害类攻击时返回实例存储的元素 ID（2～9、11～15），否则返回 0。
static func extra_element(item: Dictionary, a) -> int:
	if not ENABLED or not (a is XActor) or item.is_empty():
		return 0
	if XTianqi.active(XState.current):
		return 0
	var dmg_type := int(item.get("damage", {}).get("type", 0))
	if not dmg_type in [1, 2, 5, 6]:
		return 0
	for e in (a as XActor).equip_list():
		if is_blessing(e):
			var eid := element_of(e)
			if eid > 0:
				return eid
	return 0


## 是否属于二层深渊「未知存在」地图
static func is_unknown_abyss_map(map_id: int) -> bool:
	if XYunshangOrders.UNKNOWN.has(map_id):
		return true
	return str(XDB.rec("MapInfos", map_id).get("name", "")).begins_with("深渊:未知存在")


## 是否为【未知存在】敌人
static func is_unknown_enemy(e) -> bool:
	return e is XEnemy and str(e.data().get("name", "")).contains("【未知存在】")


## 二层深渊所有【未知存在】固定 1/888 掉落（仅西游档，不吃掉率加成、不被挂机/品质屏蔽）
static func battle_drops(logic) -> Array:
	var out := []
	if not ENABLED or logic == null or logic.state == null or logic.random == null:
		return out
	var s: XState = logic.state
	if XTianqi.active(s) or not is_unknown_abyss_map(s.map_id):
		return out
	if XDB.rec("Armors", ARMOR).is_empty():
		return out
	for e in logic.enemies:
		if e.hidden or e.is_alive() or not is_unknown_enemy(e):
			continue
		if logic.random.reward_for(logic.stable_id(e) + "|elem_king").next_float("elem_king_drop", "0") < DROP_RATE:
			out.append({"kind": 3, "id": ARMOR, "elem_king": true})
	return out


## 独立 32×32 图标（XUI.icon_texture 分流；XItemStatusPainter.large_icon 自动最近邻放大）
static func is_icon(index: int) -> bool:
	return index == ICON


static func icon_texture() -> AtlasTexture:
	if _icon_cache != null:
		return _icon_cache
	var tex: Texture2D = null
	if ResourceLoader.exists(ICON_PATH):
		tex = load(ICON_PATH) as Texture2D
	if tex == null:
		var abs_path := ProjectSettings.globalize_path(ICON_PATH)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	if tex == null:
		return null
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(Vector2.ZERO, tex.get_size())
	_icon_cache = a
	return a


## 工具方法：计算指定穿戴者等级下的合计有效面板（基础 params ＋ 等级成长）
static func total_params_at(level: int, item := {}) -> Array:
	var base: Array = item.get("params", BASE_PARAMS) if (item is Dictionary and item.get("params") is Array) else BASE_PARAMS
	var out := []
	for i in range(8):
		out.append(float(base[i]) + float(GROWTH_PER_LEVEL[i]) * float(level))
	return out
