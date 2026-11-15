class_name XTianqiSkinShow
extends RefCounted
## 【cc·天启篇·未经审查】新界面里天启篇专属数据的展示（界面风格提案 v0.7；盘点清册 #81、#82；新界面第 3A 批）。
## 只读数据、只管怎么显示，不改七印、号卷、装备的任何逻辑和随机数。共用的新界面页面（物品、装备、角色条）各调一行，
## 类名带 XTianqi 前缀：发行包里整份换成空壳（发行空壳.py），共用页面在发行包里拿到的是空结果（新皮肤在发行包本来就不开）。
##
## - #82 七印装备：物品／装备页的详情牌（XSkinItemPage.card_data）小字前加「黑印 · 七印套装 · 真印」，第一节写成色（三条）。
## - #82 号卷：详情牌把号卷自己的几行（效果、代价、获得、限制、号声）排成分节；「给谁学」右侧写各人已学几卷（已学会的写「已学会」）。
## - #81 七印外观：新界面的角色条（XSkinPartyStrip）里戴着七印外观的人，头像外圈换本印颜色、右下角放一枚小印。
## 开关：沿用新界面总开关 XUiSkin.ENABLED（O-467），不另开；只在新界面里被调。


## ---- #82 详情牌 ----

## d：XSkinItemPage.card_data 刚做好的牌（会被改）
static func dress_card(rec: Dictionary, d: Dictionary) -> void:
	if not XUiSkin.on():
		return
	if XTianqiQiyinEquip.is_qiyin(rec):
		_qiyin_card(rec, d)
	elif trumpet_no(rec) > 0:
		_trumpet_card(rec, d)


static func _qiyin_card(rec: Dictionary, d: Dictionary) -> void:
	var m := XTianqiQiyinEffects.mark_of(rec)
	var names: Dictionary = XTianqiQiyinEquip.data().get("names", {})
	var head := []
	var seal := str(m.get("seal", ""))
	if seal != "":
		head.append(str(XTianqiQiyin.seal_info(seal).get("seal", seal)))
	var kind := str(m.get("kind", ""))
	var word := str(names.get("kind_" + kind, ""))
	if word != "":
		head.append(word)
	if bool(m.get("true_seal", false)):
		head.append("真印")
	var sub := str(d.get("subtitle", ""))
	d.subtitle = " · ".join(PackedStringArray(head)) + ("　" + sub if sub != "" else "")
	var grades: Array = m.get("grades", [])
	if not grades.is_empty():
		var g := "／".join(PackedStringArray(grades.map(func(x): return XTianqiQiyin.grade_name(str(x)))))
		d.sections = [{"title": "", "rows": [{"text": "成色　" + g, "color": XUiSkin.GOLD_LIGHT}]}] + (d.get("sections", []) as Array)


## 第几卷号卷（不是号卷返回 0）
static func trumpet_no(rec: Dictionary) -> int:
	if not XTianqiTrumpet.on() or str(rec.get("kind", "")) not in ["", "item"] or rec.has("wtypeId") or rec.has("atypeId"):
		return 0
	return XTianqiTrumpet.of_item(int(rec.get("id", 0)))


static func _trumpet_card(rec: Dictionary, d: Dictionary) -> void:
	var sc := XTianqiTrumpet.scroll(trumpet_no(rec))
	if sc.is_empty():
		return
	var s := XState.current
	var sub := ["号卷", "第 %d 卷" % int(sc.n)]
	if s != null:
		sub.append("持有 %d" % s.item_count(int(rec.get("id", 0))))
	d.subtitle = " · ".join(PackedStringArray(sub))
	d.desc = str(sc.get("lore", ""))
	var rows := XSkinTemplatePage.help_rows(XHelpCard.content(rec, "item", false, 300.0))
	# 说明卡第一段是道具说明（「天启号卷／学习后获得被动……」），牌上已有名字和小字，只留号卷自己的几行
	rows = rows.filter(func(r): return not str(r.text).begins_with("天启号卷") and not str(r.text).begins_with("学习后获得被动") \
		and not str(r.text).ends_with(str(sc.get("lore", ""))))   # 「号声」那行就是牌上的说明，不重复
	d.sections = [{"title": "", "rows": rows}] if not rows.is_empty() else []


## 「给谁学」一行（XSkinItemPage.target_rows 做好的 row，会被改）：号卷写这人已学几卷
static func dress_target(rec: Dictionary, a: XActor, row: Dictionary) -> void:
	if not XUiSkin.on() or a == null:
		return
	var n := trumpet_no(rec)
	if n <= 0:
		return
	if XTianqiTrumpet.has(a, n):
		row.right = "已学会"
		row.right_color = XUiSkin.TEXT_3
		return
	var got := XTianqiTrumpet.learned(a).size()
	var cap := XTianqiTrumpet.limit(a)
	row.right = "已学 %d / %d" % [got, cap]
	row.right_color = XUiSkin.DOWN if got >= cap else XUiSkin.TEXT_2


## ---- #81 七印外观（角色条） ----

## 这人戴着哪一印的外观（没戴、外观关着返回 ""）
static func look_seal(a) -> String:
	if not XUiSkin.on() or not (a is XActor):
		return ""
	return XTianqiQiyinLook.worn(a)


static func look_color(seal: String) -> Color:
	return XTianqiQiyinShow.seal_color(seal) if seal != "" else Color(0, 0, 0, 0)


## 小印（七印徽记），美术没到时 null
static func look_badge(seal: String) -> Texture2D:
	return XTianqiQiyinShow.art("seal", seal) if seal != "" else null


## 角色条画头像后调：戴着外观的画本印颜色外圈＋右下角小印。c：圆心，r：头像半径
static func draw_look(ci: CanvasItem, seal: String, c: Vector2, r: float) -> void:
	if seal == "":
		return
	var col := look_color(seal)
	if col.a <= 0.0:
		return
	ci.draw_circle(c, r + 1.5, Color(col, 0.95), false, 2.5, true)
	var badge := look_badge(seal)
	if badge != null:
		var s := r * 0.9
		ci.draw_texture_rect(badge, Rect2(c + Vector2(r * 0.72 - s / 2.0, r * 0.72 - s / 2.0), Vector2(s, s)), false)
