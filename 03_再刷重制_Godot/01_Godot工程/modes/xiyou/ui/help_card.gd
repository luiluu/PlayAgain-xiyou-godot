class_name XHelpCard
extends Control
## 物品/装备/技能说明卡，照正式版 HelpExtend（Sprite_ItemHelp）＋ItemQuality＋Codex 运行模块复现，
## 并按用户方向「根据原版说明卡去优化」做了可回退的优化（优化登记 O-007、O-008）。
##
## 内容（content()，与 tests/xiyou_help_card 对 generated/oracle/help_cards.json 逐行核对）：
## 1. HelpExtend getDescParams：名字（20 号、品质色、居中）、描述（10 号、品质色）；物品「消耗品」、
##    装备 8 项能力（12 号、各自颜色，最后一项后分隔）、技能 MP/TP 消耗（12 号）；买卖价格（12 号、黄）。
## 2. 备注 <pos=位置 text=… size=… color=… line=… align=…> 逐条插入（位置 AN/AD/AP/APs/AC；同位置后插的在前）；
##    ItemQuality 在描述后插「品质：名称」（18 号、品质色）。CodexDisplay.text：全伤→全属性伤害。
## 3. installDamageElementRuntime（setItem 外层）：装备文字的元素别名（阴阳/奥数/暗黑），去掉备注里的「伤害属性」行，
##    在名字后插入：技能「伤害属性：元素」（伤害类型 1/2/5/6）、装备的元素增伤/追加/承伤/减伤穿透与「攻击属性」（14 号）。
## 4. installDisplayPreferencesRuntime genericHelpView（普通技能）：改名合并（对象→目标、命中类型＋能否暴击 → 命中；暴击、
##    MP/TP 消耗 → 消耗：nTP），分成 抬头／公式（\c[5]）／基本信息（\c[0]，按 伤害属性→目标→…排序）／效果（\c[1]）／
##    成长（\c[3]）／价格 六组，组间分隔；正文统一为最常见字号。
## 5. installCombatPowerRuntime（setItem 最外层）：装备在名字后插「装备战力：N」（18 号、rgba(255,211,115,1)、align 0），
##    N 是与穿戴者无关的装备评分 XPower.equipment；设置页关掉「战力显示与估算」时不插。
##    专属角色技能（ID 10122～10299）改走 characterHelpView（XCharacterHelp，ui/character_help.gd）。
## 6. installThreeGrowthRelicRuntime R.syncItem：三法宝（谷雨百谷生／万象长春盏）先按所属人物等级改写名字、说明与备注里的条目（XThreeGrowth.view）。
## 7. 心钢／利维坦／狂妄／无我：H/U.helpView（XGrowthHelp，ui/growth_help.gd）按层数／盛名重写成长行、同色行归组。
##
## 版面（layout()）：宽 400、内边距 4；每行按 RJO.SW 逐字排版：可用宽 392−x，放不下换行；行高 = 该行最大字号 + 8；
## 居中/靠右的行只算第一行；有分隔的行之后加 3；卡高 = 8 + Σ行高 + 3×分隔数。\i[n] 占 36、画在 (x+2, y−3)；
## \{ \} 字号 ±6；\C[2000+e] 为元素颜色。
## 外观：四层品质窗口（Window{品质}.png，不透明度 60）套在卡外 10px，卡内实心 #161c25（Codex 覆盖）。

const WIDTH := 400.0
const PAD := 4.0
const SEP := 3.0
const NAME_SIZE := 20
const DESC_SIZE := 10
const OTHER_SIZE := 12
const CONSUMABLE_COLOR := "rgba(255,128,128,1)"
const PRICE_COLOR := "rgba(255,255,0,1)"
const MP_COLOR := "rgba(128,128,255,1)"
const TP_COLOR := "rgba(128,255,128,1)"
const PARAM_COLORS := ["rgba(255,128,128,1)", "rgba(76,76,255,1)", "rgba(255,76,76,1)", "rgba(128,128,128,1)",
	"rgba(255,76,255,1)", "rgba(76,255,255,1)", "rgba(128,255,128,1)", "rgba(255,255,128,1)"]
const VIEW_COLOR := "rgba(235,240,247,1)"
const POWER_PREFIX := "装备战力："
const POWER_COLOR := "rgba(255,211,115,1)"
const ELEMENT_ROW_COLOR := "rgba(170,215,245,1)"
const ELEMENT_COLORS := ["#c1c9d5", "#d5dce6", "#ff846b", "#9be4ff", "#d8ac74", "#f7db62", "#83d784", "#a99bff",
	"#fff0b0", "#bd8bc9", "#6fe4c0", "#b59cf0", "#f497c8", "#7eb8ff", "#65ccef", "#bce986"]
const BACK := Color8(0x16, 0x1c, 0x25)
## 优化 O-007：说明卡最小字号（原版描述 10、能力/价格 12、元素行 14，在 1280×720 上难以看清）。设 0 恢复原版。
static var MIN_FONT := 16
## 优化 O-008：true 贴着选中行（place_near）；false 照原版位置公式（place_original）。
static var PLACE_NEAR := true
## 优化 O-251（白龙 ui-pixel1）：O-008 贴行放时，卡片本体不高于 near_min_y（由页面设成右侧信息窗／状态窗首行之下）。
## 物品页、商店选第一行时，O-008 把卡贴到行顶 y≈186，盖住信息窗的名字行、商店状态窗的「持有数」；原版卡在首行之下（本体 y 236／237）。
## false 回到不限（卡贴行顶）。
static var NEAR_BELOW_HEADER := true
## 贴行放（O-008）时卡片本体的最高位置（0＝不限）；只在 NEAR_BELOW_HEADER 为真时生效
var near_min_y := 0.0
## 技能书附卡之间的间距：原版 10（品质框外扩 10，相邻卡的框会叠在一起）；O-008 留出两边的框再加 4。
const EXTRA_GAP_ORIGINAL := 10.0
const EXTRA_GAP_NEAR := 24.0
## 优化 O-049：「出售价格」写实际卖出价（XItemMarks.selling_price：<Sell Price> 优先，否则半价向下取整，与商店付的钱一致）；
## false 照原版 HelpExtend 写 Math.round(价格/2)，奇数价格比实卖多 1。
static var REAL_SELL_PRICE := true
## 冻结后跟进 v0.36（CodexDisplay D.equipmentRows）：装备说明里的白字属性行排在第一条蓝字「特效／效果／成长：」之前。
## false＝v0.28 的排法（白字按备注原位）；换源（v0.62.12）集成分支已翻成 true（O-205，回退＝改回 false）。
static var WHITE_STATS_FIRST := true
## 跟到 v0.62.12 的说明卡排版（installPanelLayoutV043Runtime，v0.43 起 D.readableView＝P.view）：品质与类别合成一行（17 号）、
## 白字属性两列（\col[50]）、施放信息两列（17 号 #e3eaf3）、正文（18 号；技能按 伤害→效果→条件→成长）、装备条件两列、
## 背景说明挪到最后（15 号 #a9b4c2）、价格两列（15 号）；块间 4 号空行；除居中标题外每行加 \lock[1]（之后忽略 \c[n]）。
## 原版 tidy 去掉「防御按攻防比例结算」、DROP 去掉「纯粹伤害：否」「武器／装备限制：无」：是原版有意不画，不是漏。
## 只改显示副本。默认开（O-253）；关＝v0.28 排法。
static var LAYOUT_V043 := true
## O-242：v0.43 排版里分组之间的空行（文字「 」、字号 4）照原版只占 4+8＝12；最小字号 MIN_FONT 把它也提到 16，一条空行变 24，
## 技能卡实测比原版高 38。设 false 回到「空行也按最小字号」。
static var KEEP_GAP_ROWS := true
## 打开说明卡的那一页的角色（Scene_Skill._actor／战斗技能窗的角色）；黑闪、甚尔说明卡用，别的页留空
static var scene_actor = null
## characterHelpView 的 listCosts（chars-gaps2）：原版 SceneManager._scene 是 Scene_Battle 或 Scene_Skill 时为真，技能列表里已经显示消耗，
## 说明卡就不再列消耗行。重制由 show_for 按卡片所在场景（祖先是 XBattleScene／XSkillScene）在出卡时设上，出完卡还原；静态调用 content 时为假。
static var list_costs := false

var rows: Array = []          # content() 的结果
var quality := 0
var robe_card := false      # 云裳天衣：窗口皮换成粉色
var min_font := MIN_FONT
## 卡宽（Sprite_ItemHelp 构造参数；人物图鉴技能详情为 727，其余 400）
var card_width := WIDTH
## 是否画四层品质外框：怪物图鉴掉落入口为 false（AB_EnemyBook updateHelp 设好卡后 HEw.hide() 移除发光窗口与附卡，再只把卡设可见）
var show_frame := true
## 人物图鉴技能详情：内容按技能浅拷贝取（见 content 的 skill_copy）
var skill_copy := false
var _lines: Array = []        # layout() 的结果：[{glyphs, y, h, line}]
var canvas: XMVCanvas
var frame: Control
## RJO.HE.updateExtraHelpWindows：物品带「学会技能」效果（code 43）时，所学技能各一张附卡
var extras: Array = []
var _anchor := Rect2()            # place_near 的选中行（附卡避开它）
## 品质框样式要一直引用到下一次重画：局部变量释放后皮肤贴图的 RID 失效，什么也画不出来
var _frame_style: XWindowStyle


# ======================================================================
# 内容
# ======================================================================

## obj：数据库条目或装备实例；kind：item / weapon / armor / skill（省略时自动判断）
## skill_copy：人物图鉴技能详情（Codex_ActorBookSkillDetails）传的是技能的浅拷贝，DataManager.isSkill 为假——
## installDamageElementRuntime 只删备注里的「伤害属性」行，不插技能的伤害属性
static func content(obj: Dictionary, kind := "", skill_copy := false, width := -1.0) -> Array:
	var rows := _content(obj, kind, skill_copy)
	if LAYOUT_V043 and not rows.is_empty():
		rows = panel_view(obj, rows, width if width > 0 else note_width(obj) - PAD * 2)
	return rows


## 装备页／物品页右侧详情（installEquipmentDetailV041 Detail.rows41 被 installPanelLayoutV043 改写后）：
## RJO.HE.getDescParams＋首行换成星级名，再 P.view 排版。
## 详情不经 Sprite_ItemHelp.setItem，所以没有那一层加的行：「装备战力：」（installCombatPowerRuntime）、攻击属性／元素增伤
## （installDamageElementRuntime 包的也是 setItem；云端专项 rows_* 对原版读数核过）。特效排序、◆唯一 包在 getDescParams 上，照样有。
static func detail_rows(obj: Dictionary, width: float) -> Array:
	var rows := _content(obj, "", false, false, false)
	if rows.is_empty():
		return rows
	rows[0][0] = XGearSearch.star_name(obj)
	# 独立装备登记时 CodexElements.normalizeGear 已把备注、说明里作元素用的别名改掉（暗黑→黑暗等），详情读的是改过的实例
	var kind := kind_of(obj)
	if kind == "weapon" or kind == "armor":
		for r in rows:
			r[0] = gear_text(str(r[0]))
	return panel_view(obj, rows, width)


static func _content(obj: Dictionary, kind := "", skill_copy := false, power := true, elements := true) -> Array:
	if obj.is_empty():
		return []
	obj = XThreeGrowth.view(obj)  # 三法宝成长 R.syncItem：法宝说明条目（relicLines）、名字、说明
	obj = XLiuyingHelp.view(obj)  # 流萤 Sprite_ItemHelp.setItem 包装：10622／10623 说明按流萤当前进阶重写（L.refreshText）
	if kind == "":
		kind = kind_of(obj)
	var type: int = {"item": 0, "weapon": 1, "armor": 2, "skill": 3}.get(kind, 0)
	# 心钢／狂妄：H/U.helpView（XGrowthHelp）；原版里它重算 descParams，外层元素与战力包装的改动被冲掉（O-151 HELP_FIX 关时照原版）
	var growth := type == 2 and XGrowthHelp.target(obj)
	var rows := XGrowthHelp.rows(obj, type) if growth else desc_params(obj, type)
	# 屠苏／璇的技能：bindGrowth 的 setItem 包装（最外层）把技能换成浅拷贝再往里传，元素包装看 isSkill 为假，同 skill_copy
	var binding_copy := type == 3 and int(XTusuXuan.owner_of(int(obj.get("id", 0)))[0]) != 0
	# 心钢技能卡 H.skillHelpView 传的是深拷贝（XGrowthHelp.skill_view 标 skill_copy），同上
	binding_copy = binding_copy or bool(obj.get("skill_copy", false))
	# 流萤 10622／10623：原版流萤的 setItem 包装在元素包装之内，拿到的是元素包装的代理（不是 $dataSkills 本身），
	# 就把 descParams 换回 refreshText 重算的那份，元素包装删插的「伤害属性」行被冲掉（照原版：卡上留备注里的写法）
	var liuying := type == 3 and XLiuying.lb_skill(int(obj.get("id", 0)))
	if (not growth or XGrowthHelp.HELP_FIX) and not liuying:
		if elements:
			rows = _element_wrapper(obj, 0 if skill_copy or binding_copy else type, rows)
		if power and (type == 1 or type == 2) and XPower.ui_enabled():
			rows.insert(1, [POWER_PREFIX + XPower.format(XPower.equipment(obj).total), 18, POWER_COLOR, false, 0])
		# v0.41 特效排序在 RJO.HE.getDescParams 的 D 包装里，元素／穿透行（内层包装）已经插好；◆唯一 标记（v0.56，最外层）在排序之后
		if EFFECT_SORT_V041 and (type == 1 or type == 2) and not growth:
			sort_effects(obj, rows)
	if type != 3 and XCharacterHelp.target(obj):
		rows = XCharacterHelp.view(obj, rows, list_costs)  # 小猫一族的物品、法宝（认 <CodexCat:）与专属装备（4001、4577～4581、破限之心、云裳天衣）：characterHelpTarget 走 characterHelpView
		if type == 1 or type == 2:
			# characterHelpView 最外层（terminologyView 之后）：每行 D.text，再 D.equipmentRows 一次——白字属性前移、v0.41 特效按品质排序、◆唯一
			# （所以「效果：」行会排到「专属：」等作者行前面；chars-gaps1 照 character_gear_help_probe 补）
			for r in rows:
				r[0] = _terms(str(r[0]))
			if WHITE_STATS_FIRST:
				rows = equipment_rows(rows)
			if EFFECT_SORT_V041:
				sort_effects(obj, rows)
			unique_mark(obj, rows)
	if type == 3:
		rows = XYomiJingliu.help_rows(obj, rows)  # 镜流 Sprite_ItemHelp.setItem 包装：10194 卡尾的星魂行
		rows.append_array(XToji.help_rows(obj, scene_actor))  # 甚尔 Sprite_ItemHelp.setItem 包装：主技能卡尾两行熟练度（先并入，characterHelpView 再分组）
		# 专属角色技能（10122～10299）走 characterHelpView（XCharacterHelp），其余技能走 genericHelpView
		rows = XCharacterHelp.view(obj, rows, list_costs) if XCharacterHelp.target(obj) else XCharacterHelp.now_growth(obj, _generic_view(obj, rows))
		rows.append_array(XBlackFlash.help_rows(obj, scene_actor))  # 黑闪 Sprite_ItemHelp.setItem 包装（在 characterHelpView 之内）：卡尾两行现况
	for r in rows:
		r[0] = _terms(str(r[0]))
	# v0.18 starredHead：名字行（第一行、名字字号）前加星级，只给武器/防具
	var star := XQuality.stars(obj, kind)
	if star != "" and not rows.is_empty() and int(rows[0][1]) == NAME_SIZE and not str(rows[0][0]).begins_with(star):
		rows[0][0] = star + str(rows[0][0])
	return rows


static func kind_of(obj: Dictionary) -> String:
	if obj.has("kind"):
		return str(obj.kind)
	if obj.has("stypeId"):
		return "skill"
	if obj.has("wtypeId"):
		return "weapon"
	if obj.has("atypeId"):
		return "armor"
	return "item"


static func _quality(obj: Dictionary) -> int:
	var q = obj.get("meta", {}).get("quality", 0)
	return int(str(q).strip_edges()) if str(q).strip_edges().is_valid_int() else 0


## ItemQuality 的 normalcolor/namecolor：QualitiesColor[旧档]，西游 v0.15 起整表换成七档颜色（XQuality）
static func quality_color_text(obj: Dictionary) -> String:
	return XQuality.color_text(obj)


static func _num(v) -> String:
	var f := float(v)
	if is_equal_approx(f, roundf(f)):
		return str(int(roundf(f)))
	return str(f)


## RJO.HE.getDescParams（＋ItemQuality 品质行、备注插入行）
static func desc_params(obj: Dictionary, type: int) -> Array:
	var normal := quality_color_text(obj)
	var name := str(obj.get("name", ""))
	var desc := str(obj.get("description", ""))
	var rows := []
	var pos := [1, 2, 2, 2, 2]
	rows.append([name, NAME_SIZE, normal, name != "", 1])
	rows.append([desc, DESC_SIZE, normal, desc != "", null])
	var terms: Dictionary = XDB.system().get("terms", {})
	match type:
		0:
			if bool(obj.get("consumable", false)):
				rows.append(["消耗品", OTHER_SIZE, CONSUMABLE_COLOR, false, null])
			_prices(obj, rows)
			pos[2] = rows.size()
		1, 2:
			var params: Array = obj.get("params", []) if not XYunshang.relic_item(obj) else XYunshang.relic_params(obj)
			for i in range(params.size()):
				if params[i] != null and float(params[i]) != 0.0:
					rows.append([str(terms.get("params", [])[i]) + ":" + _num(params[i]), OTHER_SIZE, PARAM_COLORS[i], false, null])
			rows[rows.size() - 1][3] = true
			pos[3] = rows.size()
			_prices(obj, rows)
			pos[2] = rows.size()
		3:
			var basic: Array = terms.get("basic", [])
			if int(obj.get("mpCost", 0)) > 0:
				rows.append([str(basic[4]) + "消耗：" + str(int(obj.mpCost)), OTHER_SIZE, MP_COLOR, false, null])
			if int(obj.get("tpCost", 0)) > 0:
				rows.append([str(basic[6]) + "消耗：" + str(int(obj.tpCost)), OTHER_SIZE, TP_COLOR, false, null])
			pos[4] = rows.size()
	for line in str(obj.get("note", "")).split("\n"):
		_extra_row(rows, pos, line.strip_edges(false, true), normal)
	if type == 2:  # 饿狼 G.describeRelic（getDescParams 包装）：备注末尾的 <CodexGarouHelp> 十行
		for line in XGarou.relic_help_lines(obj):
			_extra_row(rows, pos, line, normal)
	if type == 2 and XYunshang.relic_item(obj):
		_relic_rows(obj, rows, pos)
	# ItemQuality：<pos=AD text=品质：名称 size=18 color=normalcolor line=false align=0>
	_extra_row(rows, pos, "<pos=AD text=品质：%s size=18 color=normalcolor line=false align=0>" % XQuality.grade_name(obj), normal)
	# 西游 v0.15 Q.labelRows：所有「品质：」行换成七档名称，装备带标签（品质：不朽（传家宝））
	var label := "品质：" + XQuality.label(obj, ["item", "weapon", "armor", "skill"][type])
	if type == 3:
		label = XWeakChallenge.quality_label(obj, label)  # 弱者挑战 getItemExtraDescParams2 包装：10357 写「品质：神话」
	var color_code := RegEx.create_from_string("(?i)\\\\c\\[\\d+\\]")
	for r in rows:
		var plain := color_code.sub(str(r[0]), "", true)
		if plain.begins_with("品质：") or plain.begins_with("品质:"):
			r[0] = label
	for r in rows:
		r[0] = _terms(str(r[0]))
	if WHITE_STATS_FIRST and (type == 1 or type == 2):
		rows = equipment_rows(rows)
	if type == 1 or type == 2:
		unique_mark(obj, rows)  # 跟到 v0.62.12：installUniqueEffectMarkRuntime（v0.56）getDescParams 包装，只改显示文字
	if XDemonCrown.is_gear(obj):  # 魔冠的 getDescParams 包装：小数取整（describe 在发放／重放时已做）
		XDemonCrown.desc_rows(obj, rows)
	return rows


# ---- installPanelLayoutV043Runtime（P.view） ----
const P43_SIZE := {"head": 17, "body": 18, "meta": 17, "small": 15, "gap": 4}
const P43_META_COLOR := "#e3eaf3"
const P43_TAG_COLOR := "#9fb3c8"
const P43_FLAVOR_COLOR := "#a9b4c2"
const P43_META := ["^(?:伤害属性|攻击属性)[：:]", "^(?:目标|对象)[：:]", "^(?:命中类型|命中)[：:]", "^(?:能否暴击|暴击)[：:]",
	"^(?:攻击次数|段数)[：:]", "^(?:冷却时间|冷却|准备时间)[：:]", "^(?:消耗|.{1,4}消耗)[：:]", "^(?:武器限制)[：:]",
	"^(?:纯粹伤害)[：:]", "^分类[：:]"]
const P43_COND := "^(?:装备类型|武器类型|防具类型|装备位置|装备限制|等级需求|专属角色|使用角色|武器限制)[：:]"
const P43_DROP := "^(?:纯粹伤害[：:]否|(?:武器|装备)限制[：:]无)$"
const P43_ESC := "(?i)(?:\\\\|\u001b)c\\[\\d+\\]"


static func _p43_plain(t) -> String:
	return _js_trim(RegEx.create_from_string(P43_ESC).sub(str(t) if t != null else "", "", true))


## String.prototype.trim：连全角空格 U+3000、不换行空格等一起去掉
static func _js_trim(t: String) -> String:
	return RegEx.create_from_string("^[\\s\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]+|[\\s\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]+$").sub(t, "", true)


static func _p43_lead(t: String) -> String:
	var m := RegEx.create_from_string("(?i)^(?:(?:\\\\|\u001b)c\\[\\d+\\])+").search(t)
	return m.get_string() if m != null else ""


static func _p43_rgb(c) -> int:
	var s := str(c if c != null else "").replace(" ", "")
	var m := RegEx.create_from_string("(?i)^rgba?\\((\\d+),(\\d+),(\\d+)").search(s)
	if m != null:
		return (int(m.get_string(1)) << 16) + (int(m.get_string(2)) << 8) + int(m.get_string(3))
	m = RegEx.create_from_string("(?i)^#([0-9a-f]{3}|[0-9a-f]{6})$").search(s)
	if m == null:
		return 0xffffff
	var h := m.get_string(1)
	if h.length() == 3:
		h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]
	return h.hex_to_int()


## tidy：去掉通用的「防御按攻防比例结算」，行首标签的半角冒号换全角
static func _p43_tidy(t) -> String:
	var s := RegEx.create_from_string("[；;，,]?\\s*防御按攻防比例结算").sub(str(t) if t != null else "", "", true)
	return RegEx.create_from_string("^((?:(?:\\\\|\u001b)c\\[\\d+\\])*[^：:\\s\\\\\u001b]{1,8}):").sub(s, "$1：")


## units：全角（码位 > 0x2e80）算 1，其余 0.56
static func _p43_units(t: String) -> float:
	var s := RegEx.create_from_string("(?i)(?:\\\\|\u001b)(?:col|rgb|lock)\\[\\d+\\]").sub(_p43_plain(t), "", true)
	var n := 0.0
	for i in s.length():
		n += 1.0 if s.unicode_at(i) > 0x2e80 else 0.56
	return n


static func _p43_row(text: String, size: int, color, align := 0) -> Array:
	return [text, size, color if color != null and str(color) != "" else "#ffffff", false, align]


static func _p43_pairs(fields: Array, size: int, color: String, width: float) -> Array:
	var mx := floorf((width / 2.0 - 10.0) / size)
	var out := []
	var i := 0
	while i < fields.size():
		var a: String = fields[i]
		if i + 1 < fields.size() and _p43_units(a) <= mx and _p43_units(fields[i + 1]) <= mx:
			out.append(_p43_row(a + "\\col[50]" + str(fields[i + 1]), size, color))
			i += 2
		else:
			out.append(_p43_row(a, size, color))
			i += 1
	return out


static func _p43_meta_rank(t: String) -> int:
	for i in P43_META.size():
		if RegEx.create_from_string(P43_META[i]).search(t) != null:
			return i
	return -1


static func _p43_body_rank(t: String) -> int:
	if _re("^(?:基础)?伤害[：:]", t):
		return 0
	if _re("^(?:条件|限制|代价|时点)[：:]", t):
		return 2
	if _re("^成长[：:]", t):
		return 3
	return 1


## P.view(item, width)：rows 是已经过各层包装的说明行（相当于 characterHelpView 之后的 descParams）
static func panel_view(obj: Dictionary, rows: Array, width: float) -> Array:
	var kind := kind_of(obj)
	var gear := kind == "weapon" or kind == "armor"
	width = maxf(200.0, width)
	var names: Array = XDB.system().get("terms", {}).get("params", [])
	var title = null
	var quality = null
	var tags := []
	var params := []
	var meta := []
	var body := []
	var cond := []
	var flavor := []
	var price := []
	var desc := str(obj.get("description", ""))
	var esc_re := RegEx.create_from_string(P43_ESC)
	for index in rows.size():
		var src = rows[index]
		if not src is Array:
			continue
		var raw := _p43_tidy(src[0])
		var t := _p43_plain(raw)
		if index == 0:
			title = _p43_row(str(src[0]) if src[0] != null else "", NAME_SIZE, src[2], 1)
			continue
		if t == "":
			continue
		if str(src[0]) == desc or (index == 1 and src[1] != null and int(src[1]) == DESC_SIZE):
			var lines := Array(str(src[0]).replace("\r\n", "\n").split("\n")).map(func(x): return _js_trim(str(x))).filter(func(x): return x != "")
			if lines.size() > 1 and str(lines[0]).length() <= 8 and RegEx.create_from_string("[。，！？,.!?：:]").search(lines[0]) == null:
				tags.append(lines.pop_front())
			if not lines.is_empty():
				flavor.append(_p43_row("\n".join(lines), P43_SIZE.small, P43_FLAVOR_COLOR))
			continue
		if _re("^品质[：:]", t):
			quality = src
			continue
		if _re("^(?:购买价格|出售价格|无法出售)", t):
			price.append(t)
			continue
		if t == "消耗品":
			tags.append(t)
			continue
		if _re(P43_DROP, t):
			continue
		if gear:
			var p := RegEx.create_from_string("^(.+?)[：:]\\s*(-?\\d+(?:\\.\\d+)?)$").search(t)
			if p != null and _p43_lead(str(src[0])) == "" and names.has(p.get_string(1)) and src[1] != null and int(src[1]) <= OTHER_SIZE:
				params.append({"name": p.get_string(1), "value": p.get_string(2), "color": src[2]})
				continue
			if _re(P43_COND, t):
				cond.append(t)
				continue
		else:
			var parts: Array = Array(RegEx.create_from_string("[；;](?=[^；;]{1,6}[：:])").sub(t, "\u0001", true).split("\u0001"))
			var ranks := parts.map(func(x): return _p43_meta_rank(x))
			if ranks.all(func(r): return r >= 0):
				for k in parts.size():
					meta.append({"text": parts[k], "rank": ranks[k], "at": index * 10 + k})
				continue
		var head := _p43_lead(raw)
		var single := head + esc_re.sub(raw.substr(head.length()), "", true)
		body.append({"row": _p43_row(single, P43_SIZE.body, src[2], int(src[4]) if src[4] != null else 0), "rank": 1 if gear else _p43_body_rank(t), "at": index, "text": t})
	if meta.any(func(m): return _re("^消耗[：:]", m.text)):
		meta = meta.filter(func(m): return not _re("^.{1,4}消耗[：:]\\s*\\d+$", m.text) or _re("^消耗", m.text))
	if not params.is_empty():
		body = body.filter(func(b): return not _re("^基础[：:]", b.text))
	var by := func(a, b): return a.rank < b.rank or (a.rank == b.rank and a.at < b.at)
	meta.sort_custom(by)
	body.sort_custom(by)
	var blocks := []
	var head_block := []
	if title != null:
		head_block.append(title)
	if quality != null or not tags.is_empty():
		var label := (_p43_plain(quality[0]) if quality != null else "") + (("　" if quality != null else "") + "·".join(tags) if not tags.is_empty() else "")
		head_block.append(_p43_row(label, P43_SIZE.head, quality[2] if quality != null else P43_TAG_COLOR))
	blocks.append(head_block)
	var grid := []
	var cell := func(p): return "\\rgb[%d]%s：%s" % [_p43_rgb(p.color), p.name, p.value]
	for i in range(0, params.size(), 2):
		grid.append(_p43_row(cell.call(params[i]) + ("\\col[50]" + cell.call(params[i + 1]) if i + 1 < params.size() else ""), P43_SIZE.body, params[i].color))
	blocks.append(grid)
	blocks.append(_p43_pairs(meta.map(func(m): return m.text), P43_SIZE.meta, P43_META_COLOR, width))
	blocks.append(body.map(func(b): return b.row))
	blocks.append(_p43_pairs(cond, P43_SIZE.meta, P43_META_COLOR, width))
	blocks.append(flavor)
	blocks.append(_p43_pairs(price, P43_SIZE.small, PRICE_COLOR, width) if not price.is_empty() else [])
	var out := []
	for b in blocks:
		if b.is_empty():
			continue
		if not out.is_empty():
			out.append([" ", P43_SIZE.gap, "#000000", false, 0])
		out.append_array(b)
	for r in out:
		if str(r[0]) != " " and int(r[4]) == 0:
			var h := _p43_lead(str(r[0]))
			r[0] = h + "\\lock[1]" + str(r[0]).substr(h.length())
	return out


# ---- installUniqueEffectMarkRuntime（v0.56，CodexUnique）：备注 <KyoUnique: 特效名> 的特效行前加「◆唯一 」 ----
const UNIQUE_MARK := "◆唯一 "
static var _unique_global = null


static func _unique_tags(note: String) -> Array:
	var out := []
	for m in RegEx.create_from_string("(?i)<KyoUnique\\s*:\\s*([^>\\r\\n]+)>").search_all(note):
		var k := m.get_string(1).strip_edges()
		if k != "" and not out.has(k):
			out.append(k)
	return out


## U.globalKeys：只取数据库原型（武器、防具）的标签，长的在前
static func unique_global_keys() -> Array:
	if _unique_global == null:
		var keys := []
		for t in ["Weapons", "Armors"]:
			for d in XDB.table(t):
				if d is Dictionary:
					for k in _unique_tags(str(d.get("note", ""))):
						if not keys.has(k):
							keys.append(k)
		keys.sort_custom(func(a, b): return a.length() > b.length())
		_unique_global = keys
	return _unique_global


static func _unique_canon(t: String) -> String:
	return RegEx.create_from_string("全伤(?:害)?").sub(t, "全属性伤害", true)


## U.keysOf：本件备注＋原型备注的标签；独立实例另认备注里出现的全局键；数据库已撤的不算
static func unique_keys(obj: Dictionary) -> Array:
	var keys := _unique_tags(str(obj.get("note", "")))
	var base_id := int(obj.get("base", 0))
	if base_id > 0:
		var base := XDB.rec("Weapons" if kind_of(obj) == "weapon" else "Armors", base_id)
		if base != obj:
			for k in _unique_tags(str(base.get("note", ""))):
				if not keys.has(k):
					keys.append(k)
		var note := _unique_canon(str(obj.get("note", "")))
		for k in unique_global_keys():
			if note.contains(_unique_canon(k)) and not keys.has(k):
				keys.append(k)
	var live := unique_global_keys()
	return keys.filter(func(k): return live.has(k))


static func unique_mark(obj: Dictionary, rows: Array) -> void:
	var keys := unique_keys(obj)
	if keys.is_empty():
		return
	var color := RegEx.create_from_string("^(?:(?:\\\\|\u001b)c\\[\\d+\\])+")
	var effect := RegEx.create_from_string("^(?:混沌神话特效|神话特效|太古特效|mod特效|Mod特效|特效|效果|光环|连击|符石|被动|技能|套装(?:\\(\\d+\\))?)(?:[:：]|[（(])")
	for r in rows:
		var text := str(r[0]) if r[0] != null else ""
		if text == "" or text.contains(UNIQUE_MARK) or text == str(obj.get("name", "")) or text == str(obj.get("description", "")):
			continue
		var stripped := text.lstrip(" \t")
		var cm := color.search(stripped)
		var head := cm.get_string() if cm != null else ""
		if effect.search(stripped.substr(head.length()).strip_edges()) == null:
			continue
		for k in keys:
			if _unique_canon(text).contains(_unique_canon(k)):
				var lead := text.substr(0, text.length() - stripped.length())
				var body := RegEx.create_from_string("^([^：:\\s\\\\\u001b]{1,8}):").sub(stripped.substr(head.length()), "$1：")
				r[0] = lead + head + UNIQUE_MARK + body
				break


static var _white_stat_re: RegEx
static var _blue_head_re: RegEx
static var _color_code_re: RegEx

## v0.36 D.equipmentRows：白字属性（行内没有 \c[1-9]、行颜色空或纯白，名字是基础属性类）按原顺序提到
## 第一条以 \c[1] 开头的「特效／效果／成长：」前面；没有蓝字特效或没有白字属性就原样。只动顺序，不增删行。
static func equipment_rows(rows: Array) -> Array:
	if _white_stat_re == null:
		_white_stat_re = RegEx.create_from_string("^(?:最大生命值|最大魔法值|生命值|魔法值|物理攻击力?|魔法攻击力?|攻击力|防御力|魔法防御|敏捷|幸运|命中率?|暴击(?:率|伤害)?|反击率?|闪避率?|魔法闪避率?|攻击速度|全属性(?:伤害)?|全闪避|暴击闪避率?|魔法反射率?|魔法反击率?|物理魔法闪避|爆闪|爆伤|攻击次数|(?:物|魔|火|冰|雷|暗|光|水|土|风|毒)伤|每级全属性|进化后每级全属性)[：:＋+－\\-\\d、， ,/]")
		_blue_head_re = RegEx.create_from_string("(?i)^\\\\c\\[1\\](?:特效|效果|成长)[：:]")
		_color_code_re = RegEx.create_from_string("(?i)\\\\c\\[\\d+\\]")
	var any_color := RegEx.create_from_string("(?i)\\\\c\\[[1-9]\\d*\\]")
	var stats := []
	var kept := []
	var first := -1
	for r in rows:
		var raw := str(r[0])
		var plain := _color_code_re.sub(raw, "", true)
		var color := str(r[2]).replace(" ", "").replace("\t", "").to_lower() if r.size() > 2 and r[2] != null else ""
		var white := any_color.search(raw) == null and (color == "" or color in ["#fff", "#ffffff", "white", "rgba(255,255,255)", "rgba(255,255,255,1)", "rgb(255,255,255)", "rgb(255,255,255,1)"])  # 原版正则 rgba?\(255,255,255(?:,1)?\) 也认 rgb(…,1)（审查 50 乙档注）
		if white and _white_stat_re.search(plain) != null:
			stats.append(r)
			continue
		if first < 0 and _blue_head_re.search(raw) != null:
			first = kept.size()
		kept.append(r)
	if first < 0 or stats.is_empty():
		return rows
	var out := kept.slice(0, first)
	out.append_array(stats)
	out.append_array(kept.slice(first))
	return out


## installEquipmentDetailV041Runtime 的 CodexDisplay.equipmentRows 包装（跟到 v0.62.12）：装备的特效行按品质从高到低排，
## 只换特效所在的那几个位置（名字、基础属性、条件、价格不动）。特效行＝去色码、空白与冒号后以「混沌神话／混沌／神话／太古／mod特效」
## 或「特效／效果／成长」开头，或行内有 \c[1-9]。品质：备注里这一行（<pos=… text=…>）前最近的 <quality:N> 的 rank（XSafeSell.rank），
## 不是备注带来的行按模板（originalBaseItemId／baseItemId／id）的品质；混沌（神话）特效 111、神话特效 110、mod特效 93、太古特效 91。
## 同品质照原顺序。另去掉 v0.41 旧存档里留的「效果：持有…时，造成的技能伤害＋」「效果：持武增伤作用于」说明行。
static var EFFECT_SORT_V041 := true


static func _plain41(t) -> String:
	var t2 := RegEx.create_from_string("(?i)(?:\\\\|\u001b)c\\[\\d+\\]").sub(_terms(str(t)), "", true)
	return RegEx.create_from_string("[\\s:：]").sub(t2, "", true)


## 云裳天衣（7920～7935）：setItem 前原版 refreshYunshangText 把备注里的 <pos=APs …> 行挪到末尾（其余行在前，<quality:N> 也就在说明行之前），
## 所以 v0.41 排序给说明行查到的是天衣自身品质、与模板同档，「效果：」行不前移（chars-gaps1，character_gear_help_probe 7935 对出）。
## 重制天衣实例照模板建、不另刷说明，只在排序取品质时照这个顺序读。
static func _sort_note(obj: Dictionary) -> String:
	var note := str(obj.get("note", ""))
	var id := int(obj.get("base", obj.get("id", 0)))
	if not (obj.has("atypeId") or str(obj.get("kind", "")) == "armor") or id < 7920 or id > 7935:
		return note
	var lines := Array(note.replace("\r\n", "\n").split("\n"))
	var aps := lines.filter(func(x): return str(x).begins_with("<pos=APs "))
	return "\n".join(lines.filter(func(x): return not str(x).begins_with("<pos=APs ")) + aps)


static func sort_effects(obj: Dictionary, rows: Array) -> void:
	var drop := RegEx.create_from_string("^效果：(?:持有.+时，造成的技能伤害[＋+]|持武增伤作用于)")
	for i in range(rows.size() - 1, -1, -1):
		if drop.search(str(rows[i][0])) != null:
			rows.remove_at(i)
	var source := {}
	var q := 0
	var re := RegEx.create_from_string("(?i)<quality:\\s*(\\d+)>|<pos=\\S+\\s+text=([\\s\\S]*?)\\s+size=")
	for m in re.search_all(_sort_note(obj)):
		if m.get_string(1) != "":
			q = int(m.get_string(1))
		else:
			source[_plain41(m.get_string(2))] = XSafeSell.rank(q)
	var table := "Weapons" if obj.has("wtypeId") else "Armors"
	var base_id := int(obj.get("originalBaseItemId", obj.get("baseItemId", obj.get("base", obj.get("id", 0)))))
	var b := XDB.rec(table, base_id)
	var base_rank := XSafeSell.rank(XQuality.legacy(b)) if not b.is_empty() else 0
	var kind_re := RegEx.create_from_string("(?i)^(?:混沌神话|混沌|神话|太古|mod)特效|^(?:特效|效果|成长)")
	var blue_re := RegEx.create_from_string("(?i)(?:\\\\|\u001b)c\\[[1-9]\\d*\\]")
	var at := []
	var effects := []
	for n in rows.size():
		var text := _plain41(str(rows[n][0]).replace(UNIQUE_MARK, ""))
		if kind_re.search(text) == null and blue_re.search(str(rows[n][0])) == null:
			continue
		var rank: int = source.get(text, base_rank)
		if RegEx.create_from_string("^混沌(?:神话)?特效").search(text) != null:
			rank = 111
		elif text.begins_with("神话特效"):
			rank = 110
		elif RegEx.create_from_string("(?i)^mod特效").search(text) != null:
			rank = 93
		elif text.begins_with("太古特效"):
			rank = 91
		at.append(n)
		effects.append([rows[n], rank, n])
	effects.sort_custom(func(x, y): return x[1] > y[1] or (x[1] == y[1] and x[2] < y[2]))
	for k in at.size():
		rows[at[k]] = effects[k][0]


## 云裳 getDescParams 包装：织神天梭在「等级需求：1」后面（没有就在 APs 位置）插等级与法宝经验两行
static func _relic_rows(obj: Dictionary, rows: Array, pos: Array) -> void:
	var lv := int(XMagicWeapon.level_of(obj))
	var top := int(XMagicWeapon.max_level(obj))
	var xp := int(XMagicWeapon.exp_of(obj))
	var at := rows.find_custom(func(r): return str(r[0]) == "等级需求：1")
	at = at + 1 if at >= 0 else int(pos[3])
	var lines := ["当前等级：%d / %d" % [lv, top], "法宝经验：%d" % xp + ("（已满级）" if lv >= top else " / %d" % int(XMagicWeapon.next_level_exp(obj)))]
	for i in lines.size():
		rows.insert(at + i, [lines[i], OTHER_SIZE, "rgba(255,255,255,1)", false, 0])


static func _prices(obj: Dictionary, rows: Array) -> void:
	var price := float(obj.get("price", 0))
	if price > 0:
		rows.append(["购买价格：" + str(int(roundf(price))), OTHER_SIZE, PRICE_COLOR, false, null])
		var sell := XItemMarks.selling_price(obj) if REAL_SELL_PRICE else int(roundf(price / 2.0))
		rows.append(["出售价格：" + str(sell), OTHER_SIZE, PRICE_COLOR, false, null])
	else:
		rows.append(["无法出售给普通商店", OTHER_SIZE, PRICE_COLOR, false, null])


static var _pos_re: RegEx

## RJO.HE.processExtraDescParams：插在当时的位置（位置数组不随插入更新，所以同位置后插的在前）
static func _extra_row(rows: Array, pos: Array, line: String, normal: String) -> void:
	if _pos_re == null:
		_pos_re = RegEx.create_from_string("(?i)<pos=(.+) text=(.+) size=(.+) color=(.+) line=(true|false) align=(0|1|2)>")
	var m := _pos_re.search(line)
	if m == null:
		return
	var text := m.get_string(2)
	if text.contains("DreamX_bonus"):
		return
	var p := m.get_string(1)
	var at: int = {"AN": pos[0], "AD": pos[1], "AP": pos[2], "APs": pos[3], "AC": pos[4]}.get(p, -1)
	if at == -1:
		at = int(p) if p.is_valid_int() else 0
	var size := m.get_string(3)
	var color := m.get_string(4)
	var row := [text, OTHER_SIZE if size == "normalsize" else int(float(size)), normal if color == "normalcolor" else color,
		m.get_string(5).to_lower() == "true", int(m.get_string(6))]
	rows.insert(clampi(at, 0, rows.size()), row)


## CodexDisplay.text；跟到 v0.62.12 另套 installEquipmentDetailV041Runtime（v0.43）：「（全）武器伤（害）＋N%」写成「装备武器时，技能伤害＋N%」
static func _terms(text: String) -> String:
	text = RegEx.create_from_string("全伤(?:害)?").sub(text, "全属性伤害", true)
	return RegEx.create_from_string("(?:全)?武器伤(?:害)?(?=[＋+]\\s*[\\d.]+%)").sub(text, "装备武器时，技能伤害", true)


# ---- installDamageElementRuntime ----
## O-待定·说明卡元素表只读一次：原先每张说明卡（每个元素名）都把约 1 MB 的 CodexDamageElements.json 整份重读重解析一遍，
## 商店、背包、战斗技能列表每移一行要 40～100 ms（玩家反馈 v0.01「NPC 买东西轻微卡顿」）。改走 XDB.table 缓存（damage.gd 本来就这样读），只读不改。
## 回退 ELEMENT_DATA_CACHE = false。
static var ELEMENT_DATA_CACHE := true


static func _element_data() -> Dictionary:
	var d = XDB.table("CodexDamageElements") if ELEMENT_DATA_CACHE else XDB.load_json("db/CodexDamageElements.json")
	return d if d is Dictionary else {}


static func element_name(e: int) -> String:
	var names: Array = _element_data().get("names", [])
	return str(names[e]) if e >= 0 and e < names.size() and str(names[e]) != "" else "无属性"


static func rich(ids: Array) -> String:
	if ids.is_empty():
		return "无属性"
	return "／".join(ids.map(func(e): return "\\C[%d]%s\\C[0]" % [2000 + int(e), element_name(int(e))]))


## 装备文字的元素别名（阴阳→虚空、奥数→奥术、暗黑→黑暗），只在作为元素用时替换（照 gearText）
static func gear_text(text: String) -> String:
	var aliases := {"阴阳": "虚空", "奥数": "奥术", "暗黑": "黑暗"}
	var tail := RegEx.create_from_string("^(?:\\s|[、，,／/·（(]|物理|火焰|寒冰|冰|火|大地|雷电|雷|自然|奥术|奥数|神圣|黑暗|暗黑|阴阳|虚空|混沌|空间|水|风)*(?:伤害|伤|增伤|抗性|穿透|承伤|属性)")
	var direct := RegEx.create_from_string("^(?:伤害|伤|增伤|抗性|穿透|承伤|属性)")
	var before_sep := RegEx.create_from_string("[\\s、，,／/·（(：:]$")
	var attr_before := RegEx.create_from_string("(?:伤害属性|攻击属性|元素)\\s*[:：][^:：\\n]*$")
	var attr_after := RegEx.create_from_string("^(?:$|[\\s、，,／/·）)])")
	var out := ""
	var i := 0
	while i < text.length():
		var hit := ""
		for k in aliases:
			if text.substr(i, k.length()) == k:
				hit = k
				break
		if hit == "":
			out += text[i]
			i += 1
			continue
		var before := text.substr(0, i)
		var after := text.substr(i + hit.length())
		var ok := direct.search(after) != null
		ok = ok or ((i == 0 or before_sep.search(before) != null) and tail.search(after) != null)
		ok = ok or (attr_before.search(before) != null and attr_after.search(after) != null)
		out += aliases[hit] if ok else hit
		i += hit.length()
	return out


static func _element_wrapper(obj: Dictionary, type: int, rows: Array) -> Array:
	if type == 1 or type == 2:
		for r in rows:
			r[0] = _terms(gear_text(str(r[0])))
	var dmg_attr := RegEx.create_from_string("(?i)^(?:\\\\c\\[\\d+\\])?伤害属性\\s*[:：]")
	rows = rows.filter(func(r): return dmg_attr.search(str(r[0])) == null)
	var lines := []
	var data := _element_data()
	var active: Array = data.get("activeElements", [])
	if type == 3:
		var d: Dictionary = obj.get("damage", {})
		if [1, 2, 5, 6].has(int(d.get("type", 0))):
			var eid := _migrated_element(obj)
			var es := [eid]
			es.append_array(obj.get("yep", {}).get("multipleElements", []))
			es = es.map(func(e): return int(e)).filter(func(e): return e > 0)
			var uniq := []
			for e in es:
				if not uniq.has(e):
					uniq.append(e)
			var text := "伤害属性：" + (rich(uniq) if not uniq.is_empty() else ("随武器属性" if eid < 0 else "无属性"))
			if es.size() > 1:
				text += "（均分伤害）"
			lines.append(text)
	var trig = obj.get("meta", {}).get("CodexTriggeredElement")
	if trig != null:
		lines.append("触发攻击属性：" + rich([int(str(trig).strip_edges())]) + "（真实伤害）")
	if type == 1 or type == 2:
		var yep: Dictionary = obj.get("yep", {})
		_group(lines, active, _int_keys(yep.get("elementAmplify", {})), "增伤", _percent, 0.0)
		_group(lines, active, _int_keys(_note_rates(str(obj.get("note", "")), "Element Magnify")), "增伤", _percent, 0.0)
		_group(lines, active, _int_keys(yep.get("elementAmplifyN", {})), "追加", _num, 0.0)
		var resist := {}
		for t in obj.get("traits", []):
			if int(t.code) == 11 and active.has(int(t.dataId)):
				var e := int(t.dataId)
				if resist.get(e, -1.0) == 0.0:
					continue
				resist[e] = 0.0 if float(t.value) == 0.0 else float(resist.get(e, 1.0)) + float(t.value) - 1.0
		_group(lines, active, resist, "承伤", _percent, 1.0)
		_pierce_lines(lines, str(obj.get("note", "")))
		var attack := []
		for t in obj.get("traits", []):
			if int(t.code) == 31 and not attack.has(int(t.dataId)):
				attack.append(int(t.dataId))
		if not attack.is_empty():
			lines.append("攻击属性：" + rich(attack))
	for i in range(lines.size() - 1, -1, -1):
		rows.insert(1, [lines[i], 14, ELEMENT_ROW_COLOR, false, 0])
	return rows


## v0.51／v0.57 installDamageElementRuntime 说明卡穿透段（同被动缓存口径）：只认带元素号的 <DepassiveHarmReNN: ±X[%]>，
## 同一对象里元素号＋值写法完全相同的只计一次，可负；百分比一组「X穿透 N%」、固定一组「X固定减伤穿透 N」，每行三个元素，
## 全部元素（1～15 去掉 10 与无名元素）同值写「全部穿透 N%」；两位小数；有百分比穿透时末尾提示破免疫门槛（rules-newsrc4）
static func _pierce_lines(lines: Array, note: String) -> void:
	var all := []
	var names: Array = XDB.system().get("elements", [])
	for i in range(1, names.size() if not names.is_empty() else 16):
		if i == 10 or (not names.is_empty() and str(names[i]) == ""):
			continue
		all.append(i)
	if all.is_empty():
		all = [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15]
	var pct := {}
	var fixed := {}
	var seen := {}
	for m in RegEx.create_from_string("(?i)<DepassiveHarmRe(\\d+)\\s*:\\s*([+-]?[\\d.]+%?)>").search_all(note):
		var e := int(m.get_string(1))
		var key := "%d|%s" % [e, m.get_string(2)]
		if seen.has(key):
			continue
		seen[key] = true
		var text := m.get_string(2)
		var v := float(text.trim_suffix("%"))
		var pool: Dictionary = pct if text.contains("%") else fixed
		pool[e] = float(pool.get(e, 0.0)) + v
	var fmt := func(v: float) -> String:  # JS Math.round(v*100)/100 转字符串（整数不带 .0）
		var r := floorf(v * 100.0 + 0.5) / 100.0
		return str(int(r)) if r == floorf(r) else String.num(r)
	for pair in [[pct, "穿透", "%"], [fixed, "固定减伤穿透", ""]]:
		var map: Dictionary = pair[0]
		var ids := all.filter(func(e): return map.has(e))
		if ids.is_empty():
			continue
		if ids.size() == all.size() and ids.all(func(e): return map[e] == map[ids[0]]):
			lines.append("全部" + pair[1] + " " + fmt.call(map[ids[0]]) + pair[2])
			continue
		var i := 0
		while i < ids.size():
			lines.append(" · ".join(ids.slice(i, i + 3).map(func(e): return rich([e]) + pair[1] + " " + fmt.call(map[e]) + pair[2])))
			i += 3
	if not pct.is_empty():
		lines.append("穿透合计≥100%才能击破完全免疫")


static func _migrated_element(skill: Dictionary) -> int:
	var eid := int(skill.get("damage", {}).get("elementId", 0))
	for m in _element_data().get("elementMigrations", []):
		if int(m.get("id", 0)) == int(skill.get("id", 0)) and int(m.get("from", -99)) == eid:
			return int(m.to)
	return eid


static func _int_keys(d) -> Dictionary:
	var out := {}
	if d is Dictionary:
		for k in d:
			out[int(k)] = d[k]
	return out


static func _note_rates(note: String, tag: String) -> Dictionary:
	var out := {}
	for m in RegEx.create_from_string("(?i)<" + tag + " (\\d+):\\s*([+-]?[\\d.]+)%\\s*>").search_all(note):
		out[int(m.get_string(1))] = float(out.get(int(m.get_string(1)), 0.0)) + float(m.get_string(2)) / 100.0
	return out


static func _percent(v) -> String:
	return _num(roundf(float(v) * 10000.0) / 100.0) + "%"


static func _group(lines: Array, active: Array, values: Dictionary, label: String, fmt: Callable, neutral) -> void:
	var es := active.filter(func(e): return values.has(int(e)) and values[int(e)] != null and str(values[int(e)]) != str(neutral) and not (values[int(e)] is float and is_equal_approx(float(values[int(e)]), float(neutral))))
	if es.is_empty():
		return
	if es.size() == active.size() and es.all(func(e): return str(values[int(e)]) == str(values[int(es[0])])):
		lines.append("全部元素" + label + " " + fmt.call(values[int(es[0])]))
		return
	var i := 0
	while i < es.size():
		var chunk := es.slice(i, i + 3)
		lines.append(" · ".join(chunk.map(func(e): return rich([int(e)]) + label + " " + fmt.call(values[int(e)]))))
		i += 3


# ---- genericHelpView ----
static func plain(text: String) -> String:
	return RegEx.create_from_string("(?i)(?:\\\\|\u001b)c\\[\\d+\\]").sub(text, "", true)


static func _compact(text: String) -> String:
	var t := plain(text)
	var reps := [["^([^:：]{1,18}):", "$1："], ["^命中类型：", "命中："], ["^能否暴击：是$", "暴击：可"], ["^能否暴击：否$", "暴击：不可"],
		["^(?:攻击次数|实际段数)：", "段数："], ["^特效：", "效果："], ["^(?:熟练成长|技能熟练|成长规则|成长说明|节点)[：:]", "成长："],
		["^伤害受技能等级加成。$", "成长：伤害随技能等级提高"], ["^目标：(?:单个敌人|单体敌人|敌人单体)$", "目标：敌方单体"],
		["^目标：(?:所有敌人|全体敌人|敌人全体)$", "目标：敌方全体"], ["^能否暴击：能$", "暴击：可"], ["^能否暴击：不能$", "暴击：不可"],
		["^等级成长[：:]", "成长："], ["；实际消耗以技能列表为准", ""], ["；无(?:MP、TP|魔法、TP)消耗", ""],
		["^生效条件：(.+?)(?:且|、)已(?:学会|习得)本被动$", "生效条件：$1"]]
	for r in reps:
		t = RegEx.create_from_string(r[0]).sub(t, r[1], true)
	return t


static func _re(p: String, t: String) -> bool:
	return RegEx.create_from_string(p).search(t) != null


static func _is_info(t: String) -> bool:
	return _re("^(?:类型|元素|武器限制|专属|(?:生效|完成|制作|双重集真赤)?条件|装备限制|使用限制|限制|(?:(?:基础)?(?:MP|TP)?)?消耗|代价|制作材料|材料|目标|伤害类型|伤害属性|命中(?:类型)?|能否暴击|暴击|攻击次数|实际段数|段数|冷却(?:时间)?|准备时间|可用场合|使用方式|施放前|时点|来源|当前等级|当前经验|法宝经验|等级需求|等级上限|法宝形态|咒具熟练|进阶继承|储存上限)[：:]", t) or _re("^(?:当前咒具|切换至此咒具)", t)


static func _is_growth(t: String) -> bool:
	return _re("^(?:成长|熟练成长|技能熟练|每级|法宝每级|星魂预览|节点|升级)", t) or _re("(?:随等级|按等级|每级|平滑|线性|成长|熟练度提高|实际成长上限)", t)


static func _is_formula(t: String) -> bool:
	return _re("^(?:基础治疗|基础护盾|伤害|真实伤害|斩击|体术|自动斩击|每段(?:基础)?|基础伤害|基式|有效魔攻|有效双防|蓄势附加伤害|阶位系数|魄倍率|冠冕倍率|形态系数|防御系数|速度加成|倍率|术式威力|生命增量|魔法增量|魔攻增量)[：:=＝]", t) or _re("^[＋+×－−-]", t)


static func _generic_view(obj: Dictionary, rows: Array) -> Array:
	var header := []
	var formula := []
	var info := []
	var effects := []
	var growth := []
	var footer := []
	var element_rows := []
	var seen := {}
	var name := str(obj.get("name", ""))
	var desc := str(obj.get("description", ""))
	var unlock := RegEx.create_from_string("^(?:人物等级解锁|解锁等级|解锁(?:条件)?)[：:]\\s*(?:[\\x{4e00}-\\x{9fff}]{0,4})?\\d+级?\\s*$")
	for row in rows:
		var raw := str(row[0])
		var p := plain(raw)
		if p.strip_edges() == "":
			continue
		if raw == name or raw == desc or _re("^品质[：:]", p) or _re("^(?:战技|魔法|被动|呼吸法|其他|功法|鬼灭呼吸法)$", p):
			header.append(row)
			continue
		if _re("^(?:购买价格|出售价格|无法出售)", p):
			footer.append(row)
			continue
		if _re("^(?:伤害属性|攻击属性|触发攻击属性)[：:]", p):
			var er: Array = row.duplicate()
			er[0] = "\\c[0]" + RegEx.create_from_string("(?i)^(?:\\\\c\\[\\d+\\])+").sub(raw, "")
			er[2] = VIEW_COLOR
			er[3] = false
			er[4] = 0
			element_rows.append(er)
			continue
		var t := RegEx.create_from_string("^对象[：:]").sub(p, "目标：")
		t = RegEx.create_from_string("^(MP|TP)消耗[：:]\\s*(\\d+)\\s*$").sub(t, "消耗：$2$1")
		t = _compact(t)
		t = RegEx.create_from_string("^冷却时间：").sub(t, "冷却：")
		t = RegEx.create_from_string("^特性：").sub(t, "效果：")
		t = RegEx.create_from_string("[-－]\\s*\\[敌·(?:物抗|魔抗|物防|魔防)\\s*[*×]\\s*[\\d.]+\\](?:\\s*[*×]\\s*\\[[^\\]]*\\])*").sub(t, "", true)
		t = RegEx.create_from_string("[-－]\\s*敌·(?:物抗|魔抗|物防|魔防)(?:\\s*[*×]\\s*[\\d.]+)?").sub(t, "", true)
		t = RegEx.create_from_string("\\(\\s*\\)").sub(t, "", true)
		if unlock.search(t) != null or _re("^(?:装备限制|冷却)[：:]无$", t) or seen.has(t):
			continue
		seen[t] = true
		var s: Array = row.duplicate()
		s[2] = VIEW_COLOR
		s[3] = false
		s[4] = 0
		if _is_info(t):
			s[0] = "\\c[0]" + RegEx.create_from_string("([\\x{4e00}-\\x{9fff}])[:]").sub(t, "$1：", true)
			info.append(s)
		elif _is_formula(t):
			s[0] = "\\c[5]" + t
			formula.append(s)
		elif _is_growth(t):
			s[0] = "\\c[3]" + t
			growth.append(s)
		else:
			s[0] = "\\c[1]" + t
			effects.append(s)
	var priority := ["伤害属性", "目标", "伤害类型", "命中", "暴击", "段数", "冷却", "准备时间"]
	var basic := []
	var other := []
	for row in element_rows + info:
		var label := plain(str(row[0])).split("：")[0]
		var rank := priority.find(label)
		if rank < 0:
			other.append(row)
		else:
			basic.append([rank, basic.size(), row])
	basic.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	info = basic.map(func(x): return x[2]) + other
	var body := formula + info + effects + growth
	var sizes := {}
	var order := []
	for r in body:
		if not sizes.has(r[1]):
			order.append(r[1])
		sizes[r[1]] = int(sizes.get(r[1], 0)) + 1
	if not order.is_empty():
		var common = order[0]
		for k in order:
			if sizes[k] > sizes[common] or (sizes[k] == sizes[common] and _js_key_before(k, common)):
				common = k
		for r in body:
			r[1] = common
	var compact := []
	for row in info:
		var last = compact.back() if not compact.is_empty() else null
		var left := plain(str(last[0])) if last != null else ""
		var right := plain(str(row[0]))
		var pair := last != null and ((_re("^命中[：:]", left) and _re("^暴击[：:]", right)) or (_re("^(?:暴击|段数)[：:]", left) and _re("^(?:段数|冷却)[：:]", right)))
		if pair and left.length() + right.length() <= 28 and last[1] == row[1]:
			last[0] = str(last[0]) + "；" + RegEx.create_from_string("^\\\\c\\[0\\]").sub(str(row[0]), "")
		else:
			compact.append(row.duplicate())
	info = compact
	var groups := [header, formula, info, effects, growth, footer].filter(func(g): return not g.is_empty())
	for i in range(groups.size() - 1):
		var g: Array = groups[i]
		var last: Array = g.back().duplicate()
		last[3] = true
		g[g.size() - 1] = last
	var out := []
	for g in groups:
		out.append_array(g)
	return out


## JS Object.keys 对整数键按数值升序；sort 不稳定时的并列按此顺序（近似 V8 稳定排序的结果）
static func _js_key_before(a, b) -> bool:
	return int(a) < int(b)


# ======================================================================
# 版面
# ======================================================================

## 按 RJO.SW 排版，返回 {height, lines:[{glyphs, y, h, line}]}；min_size>0 时把小字号提到该值（优化 O-007）。
## measure(text, size) -> 宽度；省略时用游戏字体（测试用参照引擎的「字数×字号×0.6」核对算法）。
static func layout(rows: Array, min_size := 0, width := WIDTH, measure := Callable()) -> Dictionary:
	if not measure.is_valid():
		var font := XUI.font()
		measure = func(t: String, s: int) -> float: return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	var cw := width - PAD * 2
	var y := PAD
	var height := PAD * 2
	var lines := []
	for r in rows:
		var size := maxi(int(r[1]), min_size)
		if KEEP_GAP_ROWS and str(r[0]) == " " and int(r[1]) <= P43_SIZE.gap:
			size = int(r[1])
		var align := int(r[4]) if r[4] != null else 0
		var color := _css(str(r[2]))
		var text := _escapes(str(r[0]))
		var glyphs := []
		var heights := []
		var x := PAD
		var line_y := y
		var cur := size
		var line_max := size
		var i := 0
		var locked := false
		if text == "":
			# RJO.SW.setupTextState：空文字不排版，行高 0（分隔照加，如分组占位装备「------」的空描述）
			lines.append({"glyphs": glyphs, "y": y, "h": 0.0, "line": bool(r[3])})
			if bool(r[3]):
				y += SEP
				height += SEP
			continue
		if align != 0:
			# 居中/靠右：整行一次画（RJO.SW.drawText，行高 36）
			var w: float = measure.call(text, size)
			var gx := PAD + ((cw - w) / 2.0 if align == 1 else cw - w)
			glyphs.append({"t": text, "x": gx, "y": y, "size": size, "color": color, "lh": 36.0, "w": w})
			var th := float(_first_line_height(text, size))
			lines.append({"glyphs": glyphs, "y": y, "h": th, "line": bool(r[3])})
			y += th
			height += th
			if bool(r[3]):
				y += SEP
				height += SEP
			continue
		var line_h := float(_first_line_height(text, size))
		while i < text.length():
			var c := text[i]
			if c == "\n":
				heights.append(line_max + 8)
				x = PAD
				line_y += line_h
				# RJO.SW.processNewLine：此时位置还在换行符上，算出的行高就是当前字号 + 8
				line_h = cur + 8.0
				line_max = cur
				i += 1
				continue
			if c == "\u001b":
				var m := RegEx.create_from_string("^\u001b([A-Za-z]+)(?:\\[(\\d+)\\])?|^\u001b([{}])").search(text.substr(i))
				if m == null:
					i += 1
					continue
				var code := m.get_string(1).to_upper()
				var param := int(m.get_string(2)) if m.get_string(2) != "" else 0
				if m.get_string(3) == "{":
					if cur <= 96:
						cur += 6
					line_max = maxi(line_max, cur)
				elif m.get_string(3) == "}":
					if cur >= 24:
						cur -= 6
				elif code == "C":
					if not locked:  # v0.43 \lock[1]：之后本行忽略 \c[n]
						color = Color(ELEMENT_COLORS[param - 2000]) if param >= 2000 and param <= 2015 else XUI.text_color(param)
				elif code == "LOCK":
					locked = true
				elif code == "COL":  # v0.43 \col[N]：跳到本行 N% 处，至少前进 12
					x = maxf(PAD + cw * param / 100.0, x + 12.0)
				elif code == "RGB":  # v0.43 \rgb[N]：十进制 RRGGBB
					color = Color.hex(param * 256 + 255)
				elif code == "I":
					glyphs.append({"icon": param, "x": x + 2, "y": line_y - 3})
					x += 36
				i += m.get_string(0).length()
				continue
			var gw: float = measure.call(c, cur)
			if cw - x < gw:
				heights.append(line_max + 8)
				x = PAD
				line_y += line_h
				line_h = cur + 8.0
				line_max = cur
				continue
			glyphs.append({"t": c, "x": x, "y": line_y, "size": cur, "color": color, "lh": line_h, "w": gw})
			x += gw
			i += 1
		heights.append(line_max + 8)
		var th := 0.0
		for hh in heights:
			th += hh
		lines.append({"glyphs": glyphs, "y": y, "h": th, "line": bool(r[3])})
		y += th
		height += th
		if bool(r[3]):
			y += SEP
			height += SEP
	return {"height": height, "lines": lines}


## RJO.SW.calcTextHeight(textState, false)：本行（到换行符为止）最大字号 + 8
static func _first_line_height(text: String, size: int) -> int:
	var nl := text.find("\n")
	var line := text if nl < 0 else text.substr(0, nl)
	var cur := size
	var mx := size
	var i := line.find("\u001b")
	while i >= 0 and i + 1 < line.length():
		if line[i + 1] == "{":
			if cur <= 96:
				cur += 6
		elif line[i + 1] == "}":
			if cur >= 24:
				cur -= 6
		mx = maxi(mx, cur)
		i = line.find("\u001b", i + 1)
	return mx + 8


## RJO.SW.convertEscapeCharacters（\\ → ESC，变量/角色名/货币）
static func _escapes(text: String) -> String:
	return XMVText.convert_escapes(text)


## 颜色分组键（groupHelpRows 借 style.color 归一：rgb／rgba／#hex 同色算一组，其余按原字串）
static func css_key(text: String) -> String:
	return _css(text).to_html() if text.begins_with("#") or text.begins_with("rgb") else text


static func _css(text: String) -> Color:
	var m := RegEx.create_from_string("rgba?\\(\\s*([\\d.]+)\\s*,\\s*([\\d.]+)\\s*,\\s*([\\d.]+)(?:\\s*,\\s*([\\d.]+))?\\s*\\)").search(text)
	if m:
		return Color8(int(m.get_string(1)), int(m.get_string(2)), int(m.get_string(3)), int(float(m.get_string(4)) * 255) if m.get_string(4) != "" else 255)
	if text.begins_with("#"):
		return Color(text)
	return XUI.TEXT


# ======================================================================
# 显示
# ======================================================================

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame = Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(_draw_frame)
	add_child(frame)
	canvas = XMVCanvas.new()
	canvas.clip_contents = false
	canvas.painter = _paint
	add_child(canvas)
	visible = false


## HelpExtend setItem：备注 <HelpWidth: N> 把卡宽改成 N（专属角色技能多为 520）；没有时用 fallback。
## 原版改的是同一个 Sprite 的宽，之后没有标签的卡也沿用 N；重制每张卡按自己的备注取，不沿用。
static func note_width(obj: Dictionary, fallback := WIDTH) -> float:
	var m := RegEx.create_from_string("(?i)<HelpWidth:\\s*(\\d+)>").search(str(obj.get("note", "")))
	return float(m.get_string(1)) if m != null else fallback


## 显示 obj 的说明卡（obj 为空时隐藏）；with_extras：技能书同时显示所学技能的附卡
func show_for(obj, kind := "", with_extras := true) -> void:
	if not (obj is Dictionary) or obj.is_empty():
		visible = false
		_set_extras({})
		return
	list_costs = _list_costs_scene()
	rows = content(obj, kind, skill_copy, note_width(obj, card_width) - PAD * 2)
	quality = _quality(obj)
	robe_card = XYunshang.is_robe(obj)
	_apply(note_width(obj, card_width))
	_set_extras(obj if with_extras and visible else {})  # 附卡与主卡同一场景
	list_costs = false


## Sprite_ItemHelp.setText：假物品，内容只一行 [文字, ItemDescOtherSize 12, 白, 不分隔, 靠左]，品质 0、没有附卡
## （选敌时种族毒鸡汤说明用：「敌人名\n毒鸡汤（回合末） …」）
## 字号压到 n 以下再排版（锻造选原件的原件卡：descParams 每行 min(字号, 14)）
func cap_size(n: int) -> void:
	for r in rows:
		r[1] = mini(int(r[1]), n)
	_apply(size.x)


func _list_costs_scene() -> bool:
	var n := get_parent()
	while n != null:
		if n is XBattleScene or n is XSkillScene:
			return true
		n = n.get_parent()
	return false


func show_text(text: String) -> void:
	rows = [[text, OTHER_SIZE, "#ffffff", false, 0]]
	quality = 0
	robe_card = false
	_apply(card_width)
	_set_extras({})


func _apply(w: float) -> void:
	var lay := layout(rows, min_font, w)
	_lines = lay.lines
	size = Vector2(w, lay.height)
	frame.position = Vector2(-10, -10)
	frame.size = size + Vector2(20, 20)
	frame.visible = show_frame
	canvas.position = Vector2.ZERO
	canvas.size = size
	canvas.visible = true
	visible = lay.height > PAD * 2
	frame.queue_redraw()
	canvas.queue_redraw()


func _set_extras(obj: Dictionary) -> void:
	for c in extras:
		remove_child(c)
		c.queue_free()
	extras = []
	for ef in obj.get("effects", []):
		if int(ef.get("code", 0)) != 43:
			continue
		var c := XHelpCard.new()
		c.min_font = min_font
		add_child(c)
		c.show_for(XDB.rec("Skills", int(ef.get("dataId", 0))), "skill", false)
		if c.visible:
			extras.append(c)
		else:
			remove_child(c)
			c.queue_free()
	_layout_extras()


## 附卡并排：主卡左边放得下就放左边，否则右边，再否则在主卡下方竖排（原版判断用整个画面，O-008 用留边后的范围）。
func _layout_extras() -> void:
	if extras.is_empty():
		return
	var gap := EXTRA_GAP_NEAR if PLACE_NEAR else EXTRA_GAP_ORIGINAL
	var lo := 22.0 if PLACE_NEAR else 0.0
	var hi := 1258.0 if PLACE_NEAR else 1280.0
	var total := -gap
	for c in extras:
		total += c.size.x + gap
	var x := 0.0
	if position.x - gap - total >= lo:
		x = -gap - total
	elif position.x + size.x + gap + total <= hi:
		x = size.x + gap
	else:
		var y := size.y + gap
		for c in extras:
			c.position = Vector2(0, y)
			y += c.size.y + gap
		return
	for c in extras:
		c.position = Vector2(x, 0)
		x += c.size.x + gap
	if not PLACE_NEAR or _anchor.size == Vector2.ZERO:
		return
	# O-008：附卡压到选中行时，整排挪到选中行下方或上方（都放不下时取压得少的一边，贴画面边）
	var h := 0.0
	var hit := false
	for c in extras:
		h = maxf(h, c.size.y)
		hit = hit or Rect2(position + c.position, c.size).grow(10).intersects(_anchor)
	if not hit:
		return
	var below := minf(_anchor.end.y + 14.0, 698.0 - h)
	var above := maxf(_anchor.position.y - 14.0 - h, 22.0)
	var cover_below := maxf(0.0, _anchor.end.y + 14.0 - below)
	var cover_above := maxf(0.0, above + h + 14.0 - _anchor.position.y)
	var top := below if cover_below <= cover_above else above
	for c in extras:
		c.position.y = top - position.y


## 列表选中行变化时调用（Window_*.updateHelp）：anchor 为选中行在 1280×720 画布上的矩形（横向取整个列表窗口）；
## battle：战斗中（卡在列表左侧）。
func place_for_row(anchor: Rect2, battle := false) -> void:
	if PLACE_NEAR:
		place_near(anchor, "left" if battle else "right")
	else:
		place_original(anchor, battle)


## 原版位置：Sprite_ItemHelp.updatePos（战斗：行左 −宽−80、行底 −4；其他：行右 −4、行底 −4；超出画面时贴边留 4），
## 再经 setItem 的修正（x<900 右移 52，否则左移 10；y<220 下移 32；y>400 上移 100，仍>500 再上移 250；超出右/下边时留 30）。
## 差别：原版 updatePos 用「窗口位置＋内容区里的行矩形」（不含内边距）且用上一张卡的高度，这里用选中行的画布矩形与本卡高度。
func place_original(anchor: Rect2, battle := false) -> void:
	var w := size.x
	var h := size.y
	var p := Vector2(anchor.position.x - w - 80, anchor.end.y - 4) if battle else Vector2(anchor.end.x - 4, anchor.end.y - 4)
	if p.x < 0:
		p.x = 4
	if p.x + w > 1280:
		p.x = 1280 - w - 4
	if p.y + h > 720:
		p.y = 720 - h - 4
	p.x += 52 if p.x < 900 else -10
	if p.y < 220:
		p.y += 32
	if p.y > 400:
		p.y -= 100
	if p.y > 500:
		p.y -= 250
	if p.x + w > 1280:
		p.x = 1280 - w - 30
	if p.y + h > 720:
		p.y = 720 - h - 30
	position = p.round()
	_layout_extras()


## 优化 O-008：贴着选中行放，不盖住选中行，选中行上下移动时卡片跟着平移而不跳动。
## side：left（战斗，列表左侧）、right、below（列表内，选中行下方/上方）。
## anchor 为选中行在画布上的矩形；area 为卡片本体的可用范围（默认整个画面去掉品质框外扩 10、再留 12）。
func place_near(anchor: Rect2, side := "right", area := Rect2(22, 22, 1236, 676)) -> void:
	_anchor = anchor
	var w := size.x
	var h := size.y
	var p := Vector2.ZERO
	var gap := 14.0   # 品质框外扩 10，再留 4
	match side:
		"left":
			p = Vector2(anchor.position.x - gap - w, anchor.position.y)
			if p.x < area.position.x:
				p.x = anchor.end.x + gap
		"below":
			p = Vector2(anchor.end.x - w, anchor.end.y + gap)
			if p.y + h > area.end.y:
				p.y = anchor.position.y - gap - h
		_:
			p = Vector2(anchor.end.x + gap, anchor.position.y)
			if p.x + w > area.end.x:
				p.x = anchor.position.x - gap - w
	p.x = clampf(p.x, area.position.x, area.end.x - w)
	var top := maxf(area.position.y, near_min_y) if NEAR_BELOW_HEADER else area.position.y
	p.y = clampf(p.y, minf(top, area.end.y - h), area.end.y - h)
	position = p.round()
	_layout_extras()


func _draw_frame() -> void:
	# ItemQuality：四层 Window{品质} 窗口（西游 v0.15 起按七档取代表图）（不透明度、背景都是 60），覆盖卡外 10px
	var skin_path := XDB.img_path("system", "Window%d" % XQuality.window_skin(quality))
	_frame_style = XUI.panel(60)
	if skin_path != "":
		# 云裳 Sprite_ItemHelp.drawBackground 包装：天衣的说明卡用改成粉色的 Window12
		_frame_style.skin = XYunshang.robe_skin(XDB.img_path("system", "Window12")) if robe_card else load(skin_path)
	_frame_style.back_opacity = 60.0 / 255.0
	for i in range(4):
		frame.draw_style_box(_frame_style, Rect2(Vector2.ZERO, frame.size))


func _paint(c: XMVCanvas) -> void:
	c.draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), BACK)
	for l in _lines:
		for g in l.glyphs:
			if g.has("icon"):
				c.icon(int(g.icon), g.x, g.y)
			else:
				c.text(g.t, g.x, g.y, g.w * 2.0 if g.lh != 36.0 else g.w + 2, "left", g.color, g.size, g.lh)
