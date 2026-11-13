class_name XTianqiQiyinArt
extends RefCounted
## 【cc·天启篇·未经审查】七印祭坛的美术接入（2026-11-12 定稿 26 项，源 新美术/TianqiQiyin_v1，导出 03_转换工具/天启七印美术导出.py）。
## 成品图在 res://content/tianqi/qiyin/（来源与尺寸见同目录 README.md）。
##
## - 首领战斗图：里副本殉印 Boss「白衣的魂」、默印 Boss「守默者」、七首之龙不再借原版敌人的图，换成新画的
##   （qiyin_altar.json 各印 boss.battler、qiyin_dragon_run.json fight.battler；图名 Tianqi_Qiyin_*，XDB.img_path 认 content/tianqi/qiyin/battlers/）。
##   七首之龙：躯干一层、七个头各一层（同画布原位），每断一首藏一个头（按揭印顺序）；守默者：单数回合（不寂静、放大招的回合）换「香炉燃起」那张。
## - 装备图标：七印套装 42 件、毕业武器 12 类（「不立文字」＝随机到的那类武器叠一卷空白卷轴）、神器 5 件，
##   不再借底子（base_id）那件的图标；图标号 ICON_BASE 起一段，XUI.icon_texture 分流到这里。
## - 不是装备的小图（I10 道具、O1 规则、O2 效果、O3 遗物与徽记）也编了号（SMALL），文字里写 \\I[号] 就画；
##   祭坛「印钥／印屑」、龙血几句台词已经带上。规则、效果状态、遗物的界面还没有，以后的界面直接用这些号。
## - 七印徽记（S1）、神器大图（P1～P5）、龙隙（P6）：XTianqiQiyinShow 的 art 路径本来就留着，图到了就换上；
##   七道印的灯也换成徽记（暗的用 dim() 去色压暗）。头像框 P7、法阵 P8 还没有「外观」系统接，图先放着。
##
## 回退开关 ENABLED（O-366）：false＝新做的装备照旧借底子图标、首领照旧借原版敌人的图（已经做出来的装备图标号存在存档里，照样画新图）。

## 开关：false＝新装备、首领不换新图
static var ENABLED := true

const DIR := "res://content/tianqi/qiyin/"
const BATTLER_PREFIX := "Tianqi_Qiyin_"
const DRAGON := "Tianqi_Qiyin_Dragon"
const SILENT := "Tianqi_Qiyin_Silent"
## 敌人身上的标记（XEnemy meta）：七首之龙已经断掉的头（七印键数组）、守默者这回合香炉燃起
const META_HEADS_OFF := "xqiyin_heads_off"
const META_LIT := "xqiyin_lit"

## 图标号：一段固定的块，加新图往块里加，不挪旧号（号存在装备实例里）
const ICON_BASE := 310000
const SET_BLOCK := 0        # +印序×10＋部位序（七印 × 六部位）
const WEAPON_BLOCK := 100   # +武器类序（qiyin_gear.json weapon_types 顺序）
const OVERLAY_BLOCK := 120  # +武器类序：「不立文字」＝那类武器＋卷轴叠层
const ARTIFACT_BLOCK := 200 # +神器序（qiyin_gear.json artifacts 顺序）
## 不是装备的小图（文字里用 \\I[号]，或以后的状态、外观、遗物界面用）：每块一张表，按表的顺序编号
const SMALL := {
	300: ["item_seal_key", "item_shards", "item_page", "item_dragon_blood", "item_sealed"],  # I10 印钥、印屑、残页、龙血、封着的装备
	500: ["rule_no_cure", "rule_war_cry", "rule_exam", "rule_magic_tower", "rule_sacrifice", "rule_star_fall", "rule_silence"],  # O1，同 qiyin_altar.json 七印的 rule
	600: ["effect_plague", "effect_weight", "effect_verdict", "effect_fallen_moon", "effect_book_page", "effect_chain_cut",
		"effect_reprieve", "effect_dragon_blood"],  # O2 疫、砝码、判决、陨月、天书页、连斩、缓期、龙血
	700: ["relic_death", "relic_war", "relic_famine", "relic_plague"],  # O3 骑士遗物（完整）
	710: ["relic_death_broken", "relic_war_broken", "relic_famine_broken", "relic_plague_broken"],  # O3 骑士遗物（残）
	800: ["badge_death", "badge_war", "badge_famine", "badge_plague"],  # O3 骑士徽记
}
const ICON_END := 900
const KEY_ICON := ICON_BASE + 300
const SHARDS_ICON := ICON_BASE + 301
const BLOOD_ICON := ICON_BASE + 303
const SEALED_ICON := ICON_BASE + 304

const SEALS := ["bai", "hong", "hei", "hui", "xun", "zhen", "mo"]
const PARTS := ["head", "body", "hands", "waist", "legs", "feet"]

static var _icons := {}


# ---- 图标 ----

static func is_icon(index: int) -> bool:
	return index >= ICON_BASE and index < ICON_BASE + ICON_END


static func _weapon_types() -> Array:
	return XTianqiQiyinGear.data().get("weapon_types", []).map(func(t): return str(t.get("key", "")))


static func _artifacts() -> Array:
	return XTianqiQiyinGear.data().get("artifacts", []).map(func(a): return str(a.get("key", "")))


## 图标号 → 图文件（不带 .png）；叠层的返回 [底, 叠]；不认识返回空
static func icon_files(index: int) -> Array:
	var n := index - ICON_BASE
	if n >= SET_BLOCK and n < SET_BLOCK + SEALS.size() * 10:
		var s := floori(n / 10.0)
		var p := n % 10
		return ["set_%s_%s" % [SEALS[s], PARTS[p]]] if p < PARTS.size() else []
	var types := _weapon_types()
	if n >= WEAPON_BLOCK and n < WEAPON_BLOCK + types.size():
		return ["weapon_" + str(types[n - WEAPON_BLOCK])]
	if n >= OVERLAY_BLOCK and n < OVERLAY_BLOCK + types.size():
		return ["weapon_" + str(types[n - OVERLAY_BLOCK]), "weapon_overlay_16"]
	var arts := _artifacts()
	if n >= ARTIFACT_BLOCK and n < ARTIFACT_BLOCK + arts.size():
		return ["artifact_" + str(arts[n - ARTIFACT_BLOCK])]
	for start in SMALL:
		var list: Array = SMALL[start]
		if n >= int(start) and n < int(start) + list.size():
			return [list[n - int(start)]]
	return []


## 小图的号（SMALL 表里的文件名，如 "rule_silence"）；没有返回 0
static func small_icon(file: String) -> int:
	for start in SMALL:
		var i: int = SMALL[start].find(file)
		if i >= 0:
			return ICON_BASE + int(start) + i
	return 0


static func icon_texture(index: int) -> AtlasTexture:
	if _icons.has(index):
		return _icons[index]
	var files := icon_files(index)
	var tex: Texture2D = null
	for f in files:
		if not ResourceLoader.exists(DIR + "icons/" + f + ".png"):
			return null
	if files.size() == 1:
		tex = load(DIR + "icons/" + str(files[0]) + ".png")
	elif files.size() == 2:
		var img := (load(DIR + "icons/" + str(files[0]) + ".png") as Texture2D).get_image()
		var top := (load(DIR + "icons/" + str(files[1]) + ".png") as Texture2D).get_image()
		img = _rgba(img)
		top = _rgba(top)
		# 卷轴缠在握柄上：16 格的叠层（导出时从母版缩好）贴左下角（七印武器图标都是柄朝左下、刃朝右上斜放）
		img.blend_rect(top, Rect2i(Vector2i.ZERO, top.get_size()), Vector2i(0, img.get_height() - top.get_height()))
		tex = ImageTexture.create_from_image(img)
	if tex == null:
		return null
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(Vector2.ZERO, tex.get_size())
	_icons[index] = a
	return a


static func _rgba(src: Image) -> Image:
	var im := src.duplicate() as Image
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	return im


static func set_icon(seal: String, part: String) -> int:
	var s := SEALS.find(seal)
	var p := PARTS.find(part)
	return ICON_BASE + SET_BLOCK + s * 10 + p if s >= 0 and p >= 0 else 0


## wtype：武器类的键（bow…）；overlay：「不立文字」
static func weapon_icon(wtype: String, overlay := false) -> int:
	var i := _weapon_types().find(wtype)
	return ICON_BASE + (OVERLAY_BLOCK if overlay else WEAPON_BLOCK) + i if i >= 0 else 0


static func artifact_icon(key: String) -> int:
	var i := _artifacts().find(key)
	return ICON_BASE + ARTIFACT_BLOCK + i if i >= 0 else 0


## 装备实例换上新图标（XTianqiQiyinEquip 做出来时调）；开关关、图不在就留底子的
static func dress_item(item: Dictionary, icon: int) -> void:
	if ENABLED and icon > 0 and icon_texture(icon) != null:
		item.iconIndex = icon


## 去色压暗的一张（七印徽记的暗态，清单「暗态用引擎去色」）；按原图缓存
static var _dim := {}

static func dim(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var key := tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if not _dim.has(key):
		var img := _rgba(tex.get_image())
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				var l := (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) * 0.55
				img.set_pixel(x, y, Color(l, l, l, c.a))
		_dim[key] = ImageTexture.create_from_image(img)
	return _dim[key]


## 骑士徽记大图（选线竖卡「已通关」那张卡上画）
static func badge_texture(line: String) -> Texture2D:
	var p := DIR + "badges_128/%s.png" % line
	if not ResourceLoader.exists(p):
		return null
	if not _dim.has(p):
		_dim[p] = load(p)
	return _dim[p]


# ---- 首领战斗图 ----

## 合成记录换成新画的战斗图（Boss 的 rec；原版敌人的侧视图、色相去掉）
static func dress_battler(rec: Dictionary, battler: String) -> void:
	if not ENABLED or battler == "" or XDB.img_path("sv_enemies", battler) == "":
		return
	rec.battlerName = battler
	rec.battlerHue = 0
	var meta: Dictionary = rec.get("meta", {}).duplicate()
	meta.erase("Sideview Battler")
	rec.meta = meta


## XDB.img_path 的新美术分流：sv_enemies/Tianqi_Qiyin_*
static func battler_path(name: String) -> String:
	if not name.begins_with(BATTLER_PREFIX):
		return ""
	var p := DIR + "battlers/" + name + ".png"
	return p if ResourceLoader.exists(p) else ""


static func _art_name(e) -> String:
	if not e is XEnemy or (e as XEnemy).horseman.is_empty():
		return ""
	return str((e as XEnemy).horseman.rec.get("battlerName", ""))


## 七首之龙断首（XTianqiQiyinDragonRun._check_cuts）：前 cut 道印的头藏起来
static func dragon_cut(e, order: Array, cut: int) -> void:
	if e == null:
		return
	e.set_meta(META_HEADS_OFF, order.slice(0, clampi(cut, 0, order.size())))


## 默印规则的回合开始（XTianqiQiyinRule.start_turn）：不寂静的回合 Boss 放大招，守默者的香炉燃起
static func silence_turn(logic, lit: bool) -> void:
	for e in logic.enemies:
		if _art_name(e) == SILENT:
			e.set_meta(META_LIT, lit)


## XBattlerSprite._process（敌人）：七首之龙的头、守默者的两态
static func update_sprite(sp) -> void:
	var name := _art_name(sp.battler)
	if not name.begins_with(BATTLER_PREFIX):
		return
	var body := sp.sprite as Sprite2D
	if body == null:
		return
	if not body.has_meta("xqiyin_art"):
		body.set_meta("xqiyin_art", true)
		if sp.sprite.material is ShaderMaterial:  # 借来的敌人掷到神话时会偏色，新画的图不偏
			(sp.sprite.material as ShaderMaterial).set_shader_parameter("hue", 0.0)
		if name == DRAGON:
			for k in SEALS:
				var p := XDB.img_path("sv_enemies", "%s_%s" % [DRAGON, k])
				if p == "":
					continue
				var head := Sprite2D.new()
				head.name = "qiyin_head_" + k
				head.texture = XAppearance.kept_load(p)
				head.centered = true
				head.use_parent_material = true
				body.add_child(head)
	if name == DRAGON:
		var off: Array = sp.battler.get_meta(META_HEADS_OFF, [])
		for k in SEALS:
			var head := body.get_node_or_null("qiyin_head_" + k) as Sprite2D
			if head != null:
				head.offset = body.offset
				head.visible = not off.has(k)
	elif name == SILENT:
		var want := XDB.img_path("sv_enemies", SILENT + ("_lit" if bool(sp.battler.get_meta(META_LIT, false)) else ""))
		if want != "" and (body.texture == null or body.texture.resource_path != want):
			body.texture = XAppearance.kept_load(want)
