class_name XLiuyingHelp
extends RefCounted
## 【cc·界面·未经审查】流萤技能说明按当前进阶生成（installLiuyingRuntime 15，v0.62.08 起；总装追加，流萤运行时清单 15）：
## L.refreshText 按流萤（179）的进阶阶数（_AdvancedNum，XLiuying.rank）重写 10622 天火轰击、10623 完全燃烧的备注：
## 留下不以「<pos=APs 」开头的行，L.skillLines 的行倒着追加成 APs（HelpExtend 倒序插回，显示是正序）。
## 原版改的是 $dataSkills 本身（Sprite_ItemHelp.setItem 与 Window_SkillList.refresh 包装触发、图鉴副本取同一份 descParams），
## 看的是 179 的阶，不管当前页是谁；重制只在出卡时取一份改过的拷贝（XHelpCard._content 开头），结果相同。
## 原版同时把 10623 的 customCostText 在三阶清空；重制技能列表还没有 <Custom Cost Display>，这一项没跟（见交付单）。
## 参照 liuying_help_probe（tests/fixtures/liuying_help_oracle.json），专项 xiyou_liuying_help。
## 新源行为（v0.28 没有流萤），不设开关。


static func _formula(id: int) -> String:
	return "伤害：每段[%d＋己·最大生命×%d＋己·物理攻击×%d＋己·敏捷＋施放前护盾×%d]×[1+技能等级×0.1]" % [
		int(XLiuying.BASE.get(id, 0.0)), int(XLiuying.HP_N), int(XLiuying.DAMAGE_N), int(XLiuying.DAMAGE_N)]


## L.skillLines：显示顺序（伤害在上、效果在下）；hiddenRate、逐火递减等暗改项不写
static func lines(id: int, r: int) -> Array:
	var rr := roundi(XLiuying.RE_RELEASE * 100.0)
	if id == XLiuying.TIANHUO:
		return [_formula(id), "伤害属性：火焰·物理", "目标：敌方单体", "命中类型：必中", "能否暴击：是",
			"攻击次数：%d" % (5 + (3 if r >= 2 else 0)),
			"消耗：5%当前生命",
			"装备限制：剑",
			"效果：消耗5%当前生命（至少保留1点），按实际扣除量转化为护盾",
			"效果：除主目标外，其余敌人受到50%扩散伤害",
			"效果：只有一个目标时，伤害结算×1.2",
			"效果：有%d%%概率再释放一次（不再消耗）" % rr,
			"效果：主动施放后叠加1层击破印记（多段与再释放不重复叠加）"]
	if id == XLiuying.RANSHAO:
		var top := r >= 3
		var cd := XLiuying.RS_COOLDOWN - (1 if top else 0)
		var out := [_formula(id), "伤害属性：火焰·物理", "目标：敌方全体", "命中类型：必中", "能否暴击：是",
			"攻击次数：9（只有一个目标时13）",
			"冷却时间：%d回合（按自然回合计，再动不缩短）%s" % [cd, "；施放后33%概率不进入冷却" if top else ""]]
		if not top:
			out.append("消耗：当前全部护盾")
		out.append("装备限制：剑")
		out.append("效果：增加与施放前护盾等量的护盾（上限为最大生命%d%%）" % roundi(XLiuying.SHIELD_CAP * 100.0) if top else "效果：消耗当前全部护盾")
		out.append_array(["效果：施放后回复全部生命", "效果：只有一个目标时，伤害结算×1.5",
			"效果：有%d%%概率再释放一次（不再消耗、不进冷却）" % rr,
			"效果：主动施放后叠加5层击破印记（多段与再释放不重复叠加）"])
		if r < 2:
			out.append("解锁：进阶2阶")
		return out
	return []


## 流萤的进阶阶数（$gameActors._data[179]._AdvancedNum；没有存档时 0）
static func rank_now() -> int:
	var s := XState.current
	return XAdvance.rank(s, XLiuying.ACTOR) if s != null else 0


## L.refreshText 后的技能（拷贝）；不是 10622／10623 原样返回
static func view(obj: Dictionary, r := -1) -> Dictionary:
	var id := int(obj.get("id", 0))
	if not obj.has("stypeId") or not XLiuying.lb_skill(id):
		return obj
	if r < 0:
		r = rank_now()
	var keep := []
	for t in str(obj.get("note", "")).replace("\r\n", "\n").split("\n"):
		if not t.begins_with("<pos=APs "):
			keep.append(t)
	var ls := lines(id, r)
	for i in range(ls.size() - 1, -1, -1):
		keep.append("<pos=APs text=%s size=18 color=rgba(255,255,255,1) line=false align=0>" % ls[i])
	var v := obj.duplicate(true)
	v.note = "\n".join(keep)
	return v
