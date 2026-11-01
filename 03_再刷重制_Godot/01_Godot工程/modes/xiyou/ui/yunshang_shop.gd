class_name XYunshangShop
extends Control
## 【cc·白龙_11·未经审查】云裳的天衣铺（installNativeYunshangRuntime.js 第 519～533、554 行 Scene_Yunshang；公共事件 9011 Y.openCrafting）。
## 只用一个居中的 XYunChoicesWindow（原版 Window_YunChoices）换着列各页，打开时光标在第一项：
## - 首页：说明 4 行（「天衣铺　云裳 N级　进阶x/2　不朽天丝 n」、订单、两行规则）＋制作天衣、领取、角色进阶、配置天衣神纹、返回；取消＝返回。
##   **一期只接配置天衣神纹**：制作、领取、进阶要订单账本与云裳进阶，下一期做，现在灰显（原版制作 35 级起、进阶够等级时能选）。
## - 配置天衣神纹：先选穿天衣的队员（「名字｜天衣名」），再按天衣——空袖藏星选 3 个借用技能（队员会的可借技能「主人：技能」，
##   说明「选择借用技能 n/3（首个为常驻）」，选过的不再列）、九曲回针选针眼、七曜流霞选 3 个元素（首个为当前元素）；
##   别的天衣提示「这件天衣无需战前配置」。中途取消一律回首页、什么都不改。设置写进 XYunshang.setting（按天衣进存档）。
signal closed

const SILK := 2942  # C.silk 不朽天丝
var win: XYunChoicesWindow
var _ok: Callable
var _cancel: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	home()


## choose(scene, rows, ok, cancel, info)：换一页
func choose(rows: Array, ok: Callable, cancel: Callable, info := []) -> void:
	if win and is_instance_valid(win):
		win.queue_free()
	win = XYunChoicesWindow.for_rows(self, rows, info)
	_ok = ok
	_cancel = cancel
	var w := win
	w.chosen.connect(func(i): if w == win: _ok.call(w.entries[i]))
	w.cancelled.connect(func(): if w == win: _cancel.call())


func home() -> void:
	var s := XState.current
	var a := s.actor(XYunshang.ACTOR)
	var info := ["天衣铺　云裳 %d级　进阶%d/2　不朽天丝 %d" % [int(a.level), XYunshang.stage(a), int(s.items.get(SILK, 0))], "当前没有制作订单",
		"制作池按等级与进阶开放（35级起可制作）", "属性与词条开工时确定，领取或读档不重抽"]
	var rows := [{"text": "制作天衣　不朽天丝×15", "enabled": false}, {"text": "领取已完成的天衣", "enabled": false}, {"text": "角色进阶", "enabled": false},
		{"text": "配置天衣神纹", "run": config_actor}, {"text": "返回", "run": _close}]
	choose(rows, func(r): if r.has("run"): r.run.call(), _close, info)


func _close() -> void:
	closed.emit()


## configActor：穿天衣的队员（全部队员，含待机）
func config_actor() -> void:
	var rows := XState.current.members().filter(func(m): return not XYunshang.robe(m).is_empty()).map(func(m):
		var r := XYunshang.robe(m)
		return {"text": "%s｜%s" % [m.display_name(), str(r.get("name", XDB.rec("Armors", int(r.get("base", 0))).get("name", "")))], "actor": m})
	choose(rows, func(r): configure(r.actor), home)


func configure(a: XActor) -> void:
	var k := XYunshang.key(a)
	var conf := XYunshang.setting(a)
	if k == 6:
		var pool := []
		for owner in XState.current.members():
			for sk in owner.skills():
				if XYunshang.borrowable(sk):
					pool.append({"text": "%s：%s" % [owner.display_name(), str(sk.name)], "owner": int(owner.actor_id), "skill": int(sk.id)})
		_borrow(conf, pool, [])
		return
	if k == 7:
		# 原版条件里的 s.cooldown 是 YEP_X_SkillCooldowns 给每个技能都建的 {}，恒真，没有冷却的技能也列出（照抄）
		var re := RegEx.create_from_string("唤醒|复活|制作|进阶")
		var rows := a.skills().filter(func(sk): return int(sk.id) < XYunshang.MOUNTAIN and int(sk.get("occasion", 0)) != 3 and re.search(str(sk.name)) == null) \
			.map(func(sk): return {"text": str(sk.name), "skill": int(sk.id)})
		choose(rows, func(r):
			conf.eye = r.skill
			home(), home)
		return
	if k == 14:
		_elements(conf, [])
		return
	XToast.show_text("这件天衣无需战前配置", true)
	home()


func _borrow(conf: Dictionary, pool: Array, chosen: Array) -> void:
	var rows := pool.filter(func(r): return not chosen.any(func(c): return c.skill == r.skill))
	choose(rows, func(r):
		chosen.append({"owner": r.owner, "skill": r.skill})
		if chosen.size() == 3:
			conf.borrow = chosen
			home()
		else:
			_borrow(conf, pool, chosen), home, ["选择借用技能 %d/3（首个为常驻）" % chosen.size()])


func _elements(conf: Dictionary, chosen: Array) -> void:
	var names: Array = XDB.system().get("elements", [])
	var rows := []
	for i in names.size():
		if i >= 2 and i != 10 and str(names[i]) != "" and not chosen.has(i):
			rows.append({"text": str(names[i]), "id": i})
	choose(rows, func(r):
		chosen.append(r.id)
		if chosen.size() == 3:
			conf.elements = chosen
			conf.element = chosen[0]
			home()
		else:
			_elements(conf, chosen), home)
