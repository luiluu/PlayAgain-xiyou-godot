extends "res://tests/xiyou_floor_run.gd"
## 造测试档：全通关、全角色养成满（T066，Kyo 11-16「给我做一个全通关用来测试的存档。全角色养成满。」）。
## 不在工程 tests/ 里、不进检查.sh；由 造测试档.py 生成临时场景挂上本脚本，对任意一份工程（main 或补丁线 cc/v00300）跑：
##   godot --headless --path <工程> -s res://tests/test_main_loop.gd <临时场景> -- --out=<输出目录> [--slot=10] [--seed=N]
## 做法（都走游戏自己的代码，不手写存档字段）：
## 0. 难度：洪荒（Kyo 11-16 定）。照玩家的路走：开局选天灾 → 大厅「破阵·投影」(EV41)「挑战灭世难度」→ 打到 13 层前
##    再找它「开启洪荒难度挑战」（Difficulty SetID 8，开关 2483）。
## 1. 通关：复用 xiyou_floor_run 的开局应答（存档位 1、狗逍遥、求道者，难度换成天灾）和「快速通过」，用游戏事件逐层打守层者（战斗强制自动、
##    队伍临时增强），打到楼层表末尾（33 层）。见面礼照 floor_run 先交。
## 1b. 洪荒路线打完 33 层（鸿蒙老祖胜后变量 1475＝1）后进三十四层古龙祭坛对话「是」：完美通关（变量 1476＝1）。
## 2. 收尾还原 floor_run 的测试增强：装备里被抬到上亿的能力值换回模板值、XActor.test_param_max 还原、交礼标记 842 归零。
## 3. 角色：每支伙伴号角跑它的招募公共事件（同玩家用号角）；超强者普通难度不能入队（XItemMarks.can_acquire_actor），记进报告。
## 4. 养成：等级到上限（33 层后 99）→ 进阶到表末（XAdvance.advance，先补齐金钱和材料）→ 种族祝福 7 阶（XRace.change／upgrade）
##    → 真气突破到顶（XZhenqi.breakthrough；突破奖励的道法选择留着待选）→ 修炼各项满级（XTraining.confirm）
##    → 技能熟练度到上限（XSkillMastery.gain_level，受变量 8／13 的上限夹）→ 本人专属法宝满级装上 → 回满。
## 5. 资源：精魂（金钱）、肝帝积分、各类材料若干；不碰冠军庆典（冠军之路三档、签到、庆典币，Kyo 11-16 定保持初始）。
## 6. 改固定存档位到 --slot（默认 10，开关 161～165／276～280），XSave.save 写盘，再 XSave.load_slot 读回核对，复制到 --out。
## 报告写 --out/report.json。

const HONGHUANG_FLOOR := 13
const ROSTER_EV := 41      # 大厅「破阵·投影」：开局灭世（天灾档、变量 20≤1），13 层前开洪荒
const ALTAR_MAP := 158     # 三十四层「决战：天外天」古龙祭坛

var out_abs := ""
var slot_out := 10
var report := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_abs = arg.substr(6)
		elif arg.begins_with("--slot="):
			slot_out = int(arg.substr(7))
	out_dir = ""
	super._ready()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_abs = arg.substr(6)
		elif arg.begins_with("--slot="):
			slot_out = int(arg.substr(7))
	out_dir = ""   # floor_run 的 --out 是截图目录，这里不截图
	var orig_param_max = XActor.test_param_max
	XMessageBox.auto = true
	# main 有、补丁线没有的开关：按名字设，没有就跳过（Object.set 对不存在的属性不做事）
	load("res://modes/xiyou/core/rift_alien.gd").set("ALIGN_LOBBY", false)
	XBattleScene.force_auto = true
	XEnemy.force_roll = 100.0
	XGuide.MILESTONE_ENABLED = false
	TestEnv.isolate("max_save")
	_fast_clock(true)
	seed(seed_value)
	var t0 := Time.get_ticks_msec()
	var floors := floor_table()
	await _opening_honghuang()
	var last := 0
	for f in floors:
		if f.floor == HONGHUANG_FLOOR and not await _to_honghuang():
			_finish(1, "13 层前开洪荒没成：难度 %d" % XState.current.difficulty)
			return
		if not await _floor(f, false):
			break
		last = f.floor
		print("第 %d 层通过（Map%03d），累计 %.1f 秒" % [f.floor, f.map, (Time.get_ticks_msec() - t0) / 1000.0])
	report.floors = {"cleared": last, "table": floors.size(), "var20": XState.current.variable(20)}
	if last != floors.size():
		_finish(1, "楼层没打完：%d/%d" % [last, floors.size()])
		return
	var s := XState.current
	await _altar34(s)
	_unboost(s)
	XActor.test_param_max = orig_param_max
	s.set_variable(842, 0)
	XBattleScene.force_auto = false
	XEnemy.force_roll = -1.0
	await _recruit_all(s)
	_resources(s)
	_grow_all(s)
	_resources(s)   # 养成花掉的补回来
	await _wait_idle(_scene())
	_save_and_verify(s)


## floor_run._boost_party 把出战成员第一件装备的能力值抬到上亿：换回模板（不掷浮动）的值
func _unboost(s: XState) -> void:
	var fixed := []
	for id in s.actors:
		var a: XActor = s.actors[id]
		for item in a.equips:
			if item is Dictionary and item.has("params") and (item.params as Array).any(func(v): return float(v) >= 1.0e9):
				var tpl := XGear.template(str(item.kind), int(item.id))
				item.params = tpl.get("params", [0, 0, 0, 0, 0, 0, 0, 0]).duplicate()
				fixed.append([a.actor_id, str(item.kind), int(item.id)])
		a.refresh_passive()
	for item in s.gear:
		if item is Dictionary and item.has("params") and (item.params as Array).any(func(v): return float(v) >= 1.0e9):
			item.params = XGear.template(str(item.kind), int(item.id)).get("params", [0, 0, 0, 0, 0, 0, 0, 0]).duplicate()
			fixed.append(["bag", str(item.kind), int(item.id)])
	report.unboost = fixed


func _recruit_all(s: XState) -> void:
	var map: XMapScene = _scene()
	var got := []
	var blocked := []
	for row in XBabyAllActors.catalog([]):
		var aid := int(row.actor)
		if s.party.has(aid) or s.saved_actors.has(aid):
			continue
		if not XItemMarks.can_acquire_actor(s, aid):
			blocked.append([aid, str(XDB.rec("Actors", aid).get("name", "")), "超强者：普通难度不能入队"])
			continue
		for ce in XBabyAllActors._horn_events(row.item):
			XMessageBox.auto_answers = []
			await map.run_common_event(int(ce))
			await _wait_idle(map)
			map = _scene()
		if s.party.has(aid) or s.saved_actors.has(aid):
			got.append(aid)
		else:
			blocked.append([aid, str(XDB.rec("Actors", aid).get("name", "")), "招募事件跑完没入队"])
	# 有名字、没停用、不在号角表里的角色（开局英雄另外几位等）：只记下来
	var horned := XBabyAllActors.catalog([]).map(func(r): return int(r.actor))
	var no_horn := []
	var db: Array = XDB.table("Actors")
	for i in range(1, db.size()):
		if db[i] is Dictionary and not XBabyAllActors.excluded(i) and not horned.has(i) and not s.party.has(i):
			no_horn.append([i, str(db[i].get("name", ""))])
	report.recruit = {"got": got, "blocked": blocked, "no_horn_not_owned": no_horn, "party_size": s.party.size()}


const MATERIALS := {
	29: 999, 184: 999, 185: 999, 186: 999, 187: 999, 188: 999,          # 魂灯
	180: 999, 181: 999, 182: 999, 640: 999, 2942: 999,                  # 不朽系
	24: 99, 64: 99, 110: 99, 171: 99, 397: 99,                          # 副本挑战符文
	982: 99, 1288: 99, 1296: 99, 1304: 99, 1312: 99, 1320: 99, 1328: 99, # 忘情水、祝福进阶石
	3027: 99, 3028: 99, 3029: 99, 3030: 99, 3031: 99,                   # 神秘珠
	1639: 99, 2530: 999, 1350: 999,                                     # 抽奖券、人道意志碎片、心法碎片
	1907: 99, 1908: 99, 1987: 99,                                       # 法宝经验丹
	258: 99, 259: 99, 260: 99, 261: 99, 262: 99, 263: 99, 264: 99, 265: 99,
	266: 99, 267: 99, 268: 99, 269: 99, 270: 99, 271: 99, 272: 99, 273: 99,
	452: 99, 453: 99, 454: 99, 455: 99,                                 # 强化石
}


## 补到目标数（不超过物品上限）；精魂（金钱）补满；肝帝积分（变量 206）补到 1 亿
func _resources(s: XState) -> void:
	for id in MATERIALS:
		if XDB.rec("Items", id).is_empty():
			continue
		var want := mini(int(MATERIALS[id]), XState.item_max(id))
		var have := s.item_count(id)
		if have < want:
			s.gain_item(id, want - have)
	s.gain_gold(XState.GOLD_MAX)
	if float(s.variable(206)) < 1.0e8:
		s.set_variable(206, 100000000)
	report.gold = s.gold
	report.score206 = s.variable(206)


func _grow_all(s: XState) -> void:
	var cap := s.max_level()
	var per := {}
	var stones: Array = XRace.config().get("stones", [])
	for id in s.party.duplicate() + Array(s.saved_actors):
		var a := s.actor(int(id))
		if a == null:
			continue
		var r := {"name": a.display_name()}
		a.change_level_mv(cap)
		# 进阶：每次先补齐这一行要的金钱和物品
		for n in range(200):
			var row = XAdvance.row(s, a.actor_id)
			if row == null:
				break
			s.gain_gold(XState.GOLD_MAX)
			for p in row.items:
				var need := int(p[1]) - s.item_count(int(p[0]))
				if need > 0:
					s.gain_item(int(p[0]), need)
			var lack := XAdvance.missing(s, a)
			if not lack.is_empty():
				r.advance_stuck = lack
				break
			if not XAdvance.advance(s, a):
				r.advance_stuck = ["advance 返回 false"]
				break
		r.advance = XAdvance.rank(s, a.actor_id)
		# 种族祝福
		var rd := XRace.data(s, a)
		if int(rd.race) < 0:
			s.gain_item(int(XRace.config().water), 1)
			var dr := XRace.default_race(s)
			XRace.change(s, a, dr if dr >= 0 else 0)
		for rank in range(int(rd.rank) + 1, 8):
			if rank - 2 >= 0 and rank - 2 < stones.size():
				s.gain_item(int(stones[rank - 2]), 1)
			var res := XRace.upgrade(s, a, rank)
			if not res.ok:
				r.race_stuck = res.reason
				break
		r.race = [int(XRace.data(s, a).race), int(XRace.data(s, a).rank)]
		# 真气
		var zd := XZhenqi.data(a)
		zd.qi = maxi(int(zd.qi), int(XZhenqi.REALMS[XZhenqi.REALMS.size() - 1].need))
		while XZhenqi.breakthrough(s, a):
			pass
		r.zhenqi = [int(zd.realm), XZhenqi.REALMS.size() - 1, (zd.pending as Array).size()]
		# 修炼
		var tr := {}
		for tid in XTraining.table():
			var e := XTraining.entry(int(tid))
			for k in range(int(e.max) + 1):
				s.gain_gold(XState.GOLD_MAX)
				if XTraining.confirm(s, a.actor_id, int(tid)) != "修炼成功":
					break
			tr[str(tid)] = [XTraining.level(s, a.actor_id, int(tid)), int(e.max)]
		r.training = tr
		a.refresh_passive()
		# 熟练度（最后学到的技能也算上）
		var m_cap := 0
		var m_all := 0
		for sid in a.skill_ids.duplicate():
			if XSkillMastery.max_level(int(sid)) <= 0:
				continue
			m_all += 1
			XSkillMastery.gain_level(a, int(sid), 100000)
			if XSkillMastery.is_maxed(a, int(sid)):
				m_cap += 1
		r.mastery = [m_cap, m_all, int(s.variable(8)), int(s.variable(13))]
		# 本人专属法宝
		var fid := _own_fabao(a.actor_id)
		if fid > 0:
			var item := XGear.create("armor", fid, s)
			if not item.is_empty():
				item.level = XMagicWeapon.max_level(item)
				item.exp = 0.0
				var slot := a.equip_slots().find(int(item.etypeId))
				if slot >= 0 and a.can_equip(item):
					var old = a.equips[slot]
					s.register_gear(item)
					a.equips[slot] = item
					if old is Dictionary and not old.is_empty():
						s.gear.append(old)
					r.fabao = [fid, item.level]
				else:
					r.fabao = [fid, "装不上"]
		a.refresh_passive()
		a.recover_all()
		r.level = [a.level, cap]
		per[str(id)] = r
	report.actors = per
	report.max_level = cap


static var _own := {}
static func _own_fabao(actor_id: int) -> int:
	if _own.is_empty():
		for rec in XDB.table("Armors"):
			if rec is Dictionary and rec.get("meta", {}).has("Magic Weapon") and rec.meta.has("req_actors"):
				for x in str(rec.meta.req_actors).split(","):
					if str(x).strip_edges().is_valid_int() and not _own.has(int(str(x).strip_edges())):
						_own[int(str(x).strip_edges())] = int(rec.id)
		_own[-1] = 0
	return int(_own.get(actor_id, 0))


func _save_and_verify(s: XState) -> void:
	for i in range(5):
		s.set_switch(161 + i, slot_out == i + 1)
		s.set_switch(276 + i, slot_out == i + 6)
	var ok := XSave.save(slot_out)
	var path := XSave.path(slot_out)
	var text := FileAccess.get_file_as_string(path) if ok else ""
	var back_ok := ok and XSave.load_slot(slot_out)
	var t := XState.current
	report.save = {"slot": slot_out, "written": ok, "file": path.get_file(), "bytes": text.length(), "reload": back_ok,
		"reload_party": t.party.size() if back_ok else -1, "reload_var20": t.variable(20) if back_ok else -1,
		"reload_fixed_slot": t.fixed_save_slot() if back_ok else -1}
	if out_abs != "" and ok:
		DirAccess.make_dir_recursive_absolute(out_abs)
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), out_abs.path_join(path.get_file()))
	_finish(0 if back_ok else 1, "")


func _finish(code: int, why: String) -> void:
	report.error = why
	if code != 0:
		report.last_messages = XMessageBox.transcript.slice(-12).map(func(m): return JSON.stringify(m).left(300))
		var sc = _scene()
		if sc is XMapScene:
			report.scene = {"map": sc.map_id, "busy": sc.busy, "toasts": sc.toasts.slice(-8)}
	report.version = ProjectSettings.get_setting("application/config/version", "")
	if out_abs != "":
		DirAccess.make_dir_recursive_absolute(out_abs)
		var f := FileAccess.open(out_abs.path_join("report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	# 清掉 user:// 里的临时目录
	var d := DirAccess.open(XSave.dir())
	if d != null:
		for fn in d.get_files():
			d.remove(fn)
	DirAccess.remove_absolute(XSave.dir())
	_fast_clock(false)
	print("MAX_SAVE_RESULT=" + JSON.stringify({"code": code, "error": why, "floors": report.get("floors")}))
	get_tree().quit.call_deferred(code)


## 同 floor_run._opening，难度选天灾（第 6 项），到大厅后开灭世
func _opening_honghuang() -> void:
	_check("enter_xiyou", GameApp.enter_mode("xiyou"))
	await _frames(3)
	var entry = _scene()
	XMessageBox.auto_answers = [0, 0, 0, "测试满档", 0, 5, 0, 0]
	entry._new_game()
	XState.current.random_master = XRandomStream.hex64(seed_value)
	if not await _wait_map(221, 9000):
		push_error("开局没到 Map221")
	var map: XMapScene = _scene()
	XMessageBox.auto_answers = [0]
	await map.run_event(_event(map, 2))
	await _wait_map(HUB, WAIT_MAP)
	var s := XState.current
	for i in range(WAIT_MAP):
		if s.self_switch(HUB, 20, "A") and not _scene().busy:
			break
		await get_tree().process_frame
	XRace.state(s).guideChosen = true
	_scene().relocate_race_guide()
	report.opening = {"difficulty_tianzai": s.difficulty, "sw2489": s.switch(2489)}
	map = _scene()
	XMessageBox.auto_answers = [2, 0]   # 挑战灭世难度 → 是
	await map.run_event(_event(map, ROSTER_EV))
	await _wait_idle(map)
	report.opening.difficulty_mieshi = s.difficulty
	report.opening.sw2487 = s.switch(2487)
	_boost_party(s)


## 13 层前（变量 20＝13）：破阵·投影 第 5 页先选「离开」，再「开启洪荒难度挑战」选「是」
func _to_honghuang() -> bool:
	var s := XState.current
	var map: XMapScene = _scene()
	await _wait_idle(map)
	XMessageBox.auto_answers = [1, 0, 0, 0, 0, 0]
	await map.run_event(_event(map, ROSTER_EV))
	await _wait_idle(map)
	map = _scene()
	if map.map_id != HUB:
		await _wait_map(HUB, WAIT_MAP)
	report.honghuang = {"difficulty": s.difficulty, "sw2483": s.switch(2483), "var20": s.variable(20)}
	_boost_party(s)
	return s.switch(2483)


## 三十四层：大厅门（变量 20＝34）→ Map158 古龙祭坛 EV1 第 2 页「是否保存了？」选「是」→ 变量 1476＝1；再用枫叶回大厅
func _altar34(s: XState) -> void:
	var map: XMapScene = _scene()
	report.altar = {"var20": s.variable(20), "v1475": s.variable(1475)}
	if s.variable(20) != 34:
		return
	XMessageBox.auto_answers = [0]
	map.run_event(_event(map, HUB_DOOR))
	if not await _wait_map(ALTAR_MAP):
		report.altar.error = "没进 Map158"
		return
	map = _scene()
	await _wait_idle(map)
	XMessageBox.auto_answers = [0]
	await map.run_event(_event(map, 1))
	await _wait_idle(map)
	report.altar.v1476 = s.variable(1476)
	report.altar.selfA = s.self_switch(ALTAR_MAP, 1, "A")
	map.return_to_hub()
	report.altar.back_hub = await _wait_map(HUB)


## 洪荒诅咒（全属性 ×0.5、结算伤害 ×0.5、无法行动、命中 −10% 等）下 floor_run 的增强扛不住守层者：在它的基础上把生命、防御、
## 魔防、敏捷也抬上去，攻击 ×4。只改出战成员第一件装备的能力值，造完由 _unboost 换回模板值。
func _boost_party(s: XState, atk := 2.0e16) -> void:
	super._boost_party(s, atk * 4.0)
	for a in s.members():
		var eq: Array = a.equip_list()
		if eq.is_empty():
			continue
		var p: Array = eq[0].params
		p[0] = 1.0e16
		p[1] = 1.0e8
		p[3] = 1.0e15
		p[5] = 1.0e15
		p[6] = 1.0e9
		p[7] = 1.0e6
		a.refresh_passive()
		a.hp = a.mhp
		a.mp = a.mmp
