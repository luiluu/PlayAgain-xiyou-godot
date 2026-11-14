class_name XTianqiQiyin
extends RefCounted
## 【cc·天启篇·未经审查】七印祭坛的流程（天启篇_七印祭坛_里副本套装毕业武器方案 v0.4 第 2.1、2.2、3、6.5 节）。
## 流程表 tianqi_data/qiyin_altar.json（只读）；掉落算法 XTianqiQiyinDrop，装备数据 XTianqiQiyinGear，战斗规则 XTianqiQiyinRule。
##
## - 入口：大厅 EV048（原版「合成天顶剑」的提示，天启篇删了天顶剑）、32 层焰轮天和 33 层清净天的古龙祭坛门（EV002）。
##   祭坛借 19 层副本的古龙祭坛（Map054）换色调；流程一次走完（借来的图上没有自己的事件），打完回祭坛的菜单，离开回大厅。
## - 揭印（方案 2.2 节）：打过 31 层白、红；32 层黑；33 层灰；34 层殉；35 层震；前六印的 Boss 都打过开默印。
## - 进里副本：自选已揭开的印（Kyo 11-11）；每次花 1 把印钥（方案 6.5 节第 1 条），输了不退；每进 3 次抽一印躁动（XTianqiQiyinDrop.on_enter）。
##   首通过的可以「直取」只打 Boss；进之前可以献印屑定第一件的部位。
##   三场连战（两场精英、一场 Boss），场间不回复；输了回祭坛。魔塔（灰印）每场前三选一捡宝石，本次副本内累计。
## - 掉落：精英印屑、Boss 套装件／毕业武器／神器（XTianqiQiyinDrop.roll_boss）、首通加 1 件；31～35 层守层者首杀给它揭开那几印各 1 件（到祭坛时补发）。
##   掉下来的都是封着的（先掉后揭，方案 6.1 节第 3 条），放进本档的「印库」；结算时可以当场揭（6.5 节第 3 条），也可以回祭坛揭。
##   揭开时生成能穿的装备进背包（XTianqiQiyinEquip：词条、七印标记），印库里只留封着的；熔、分解、印屑兑换、献武器也在祭坛（cc/qiyin-equip）。
## - 印钥：里副本 Boss 打赢 33% 退 1 把；31～35 层野外怪 5%，精英、守护者、守层者必掉（XTianqiQiyinRule.end 记，回祭坛时报）。
##
## 开关 ENABLED（false＝祭坛一概不开，三处入口照原版事件）；只认天启篇存档且选了线，发行构建里还要 XTianqi.RELEASE_OPEN。

const PATH := "res://modes/xiyou/tianqi_data/qiyin_altar.json"
const FLOOR_VAR := 20
const HALL_ENTRY := 0

## 开关：false＝七印祭坛整个不出（入口事件照原版）
static var ENABLED := true

static var _data: Dictionary = {}
## 测试注入：掉落、躁动、印钥用的随机流；null 时每次现开一条
static var rng_override: XRandomStream = null
## 正在跑的里副本（地图名、战斗规则用；跑完清空）
static var _at := ""


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):  # 发行包里没有（没发行的内容，见 发行内容审计.py）
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiQiyin: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiQiyin: JSON 解析失败 " + PATH)
	return _data


static func reload() -> void:
	_data = {}


## 表里设计数值含数字 4 的（豁免键见表头）
static func nice_number_violations() -> Array:
	var out := []
	XTianqiHorsemen._scan(data(), "", data().get("nice_number_exempt", []), out)
	return out


## 开关（O-427）：true＝祭坛和七首之龙的随机流由存档派生（progress.seed＋存档里的计数 rng_n），读档不能重掷；
## false＝回到每次现开一条（XRandomStream.fresh_seed）
static var SEED_FROM_SAVE := true


## 本档的七印随机流：种子由存档种子 orb_seed 派生（老档第一次用到时补；orb_seed 本身随存档保存），每开一条流计数 +1，
## 计数也在存档里，所以读档后同样的操作掷出同样的结果。domain 区分祭坛（qiyin）和七首之龙（qiyin_dragon）
static func save_rng(s: XState, domain := "qiyin") -> XRandomStream:
	return XRandomStream.create(next_seed(s, domain), domain)


## 下一条流的种子（十六进制）；存档派生关掉或没有存档时现开
static func next_seed(s: XState, domain: String) -> String:
	if s == null or not SEED_FROM_SAVE:
		return XRandomStream.fresh_seed()
	var p := progress(s)
	var n := int(p.rng_n)
	p.rng_n = n + 1
	return XRandomStream.derive(str(p.seed), "%s|%d" % [domain, n])


static func _rng(s: XState = null) -> XRandomStream:
	if rng_override != null:
		return rng_override
	return save_rng(s, "qiyin")


# ---- 开关与本档进度 ----

## 天启篇存档、发行构建里天启篇已开放、选了线
static func allowed(s: XState = null) -> bool:
	if s == null:
		s = XState.current
	return ENABLED and s != null and XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release()) \
		and XTianqi.line_of(s) != ""


## 本档的祭坛记录（flags.tianqi.qiyin）：
##   opened 祭坛开过；keys 印钥；shards 印屑；drop 掉落状态（XTianqiQiyinDrop.new_state 的字段）；
##   bag 印库 [物品…]（XTianqiQiyinDrop 的物品字典＋revealed: bool）；artifacts 拿到的神器键；field_keys 野外捡到还没报的印钥；
##   seed、rng_n 本档随机流的种子和已开的条数（save_rng）；artifact_miss 神器保底计数（roll_artifact）
static func progress(s: XState) -> Dictionary:
	if not s.flags.tianqi.get("qiyin") is Dictionary:
		s.flags.tianqi["qiyin"] = {}
	var p: Dictionary = s.flags.tianqi["qiyin"]
	if not p.get("drop") is Dictionary:
		p["drop"] = XTianqiQiyinDrop.new_state()
	for k in ["keys", "shards", "field_keys", "rng_n", "artifact_miss"]:
		if not p.has(k):
			p[k] = 0
	if str(p.get("seed", "")) == "":  # 老档没有：由存档种子派生（同一个档每次都一样）
		p["seed"] = XRandomStream.derive(XRandomStream.hex64(int(s.orb_seed)), "qiyin")
	for k in ["bag", "artifacts"]:
		if not p.get(k) is Array:
			p[k] = []
	return p


static func keys(s: XState) -> int:
	return int(progress(s).keys)


static func shards(s: XState) -> int:
	return int(progress(s).shards)


static func seal_keys() -> Array:
	var out: Array = data().get("seals", {}).keys()
	out.sort_custom(func(a, b): return int(seal_info(a).order) < int(seal_info(b).order))
	return out


static func seal_info(key: String) -> Dictionary:
	var v = data().get("seals", {}).get(key)
	return v if v is Dictionary else {}


## 打过 n 层的守层者（34 层另认 XTianqiSummit 的鸿钧记录）
static func floor_beaten(s: XState, n: int) -> bool:
	if int(s.variable(FLOOR_VAR)) >= n + 1:
		return true
	return n == 34 and XTianqiSummit.hongjun_beaten(s)


## 这一印揭开了没有（方案 2.2 节）
static func unlocked(s: XState, key: String) -> bool:
	var u = data().get("unlock", {}).get(key)
	if not u is Dictionary:
		return false
	if u.has("floor"):
		return floor_beaten(s, int(u.floor))
	if u.has("after_seals"):
		var cleared: Dictionary = progress(s).drop.get("first_clear", {})
		for k in u.after_seals:
			if not bool(cleared.get(k, false)):
				return false
		return true
	return false


static func unlocked_seals(s: XState) -> Array:
	return seal_keys().filter(func(k): return unlocked(s, k))


static func difficulty_key(s: XState) -> String:
	var d := XTianqi.difficulty_of(s)
	return str(d.get("key", "jianxian")) if not d.is_empty() else "jianxian"


# ---- 地图挂钩 ----

static func _entry_index(map_id: int, event_id: int) -> int:
	var list: Array = data().get("entries", [])
	for i in list.size():
		if int(list[i].map) == map_id and int(list[i].event) == event_id:
			return i
	return -1


## 地图场景要启动一个事件前：三处入口在天启篇里由本模块接（还没有一印揭开时，门照原版）
static func intercepts(s: XState, map_id: int, event_id: int) -> bool:
	return allowed(s) and _entry_index(map_id, event_id) >= 0 and not unlocked_seals(s).is_empty()


static func run_event(host, s: XState, map_id: int, event_id: int) -> bool:
	if _entry_index(map_id, event_id) < 0:
		return false
	await run_altar(host, s)
	return true


## 地图名：在祭坛或里副本里时用新名字
static func map_name(s: XState, map_id: int, original: String) -> String:
	if _at == "" or not allowed(s):
		return original
	if _at == "altar" and int(data().altar.map) == map_id:
		return str(data().altar.name)
	var info := seal_info(_at)
	if not info.is_empty() and int(info.map) == map_id:
		return str(info.name)
	return original


## 祭坛和里副本都没有随机遇敌（借来的图原来有）
static func no_encounter(s: XState, _map_id: int) -> bool:
	return _at != "" and allowed(s)


# ---- 台词 ----

static func scene(key: String) -> Array:
	var v = data().get("scenes", {}).get(key)
	return v if v is Array else []


static func _line(row: Array, args := []) -> String:
	var text := str(row[1])
	if not args.is_empty() and text.contains("%"):
		text = text % args
	return text if str(row[0]) == "" else "\\n<%s>%s" % [row[0], text]


static func say(host, key: String, args := []) -> void:
	for row in scene(key):
		await host.show_text("", 0, [_line(row, args)])


static func ask(host, key: String, options: Array, args := []) -> int:
	var rows := scene(key)
	var head := _line(rows[0], args) if not rows.is_empty() else ""
	return await host.show_text_with_choices("", 0, [head], options, options.size() - 1)


# ---- 祭坛 ----

## 第一次开祭坛送印钥、补发守层者首杀、报野外捡到的印钥。返回要说的话 [[场景键, 参数]…]（测试直接看）
static func sync(s: XState) -> Array:
	var p := progress(s)
	var notes := []
	if not bool(p.get("opened", false)):
		p.opened = true
		p.keys = int(p.keys) + int(data().keys.first_open)
		notes.append(["first_open", [int(data().keys.first_open)]])
	for n in [31, 32, 33, 34, 35]:
		if not floor_beaten(s, n) or bool(p.drop.get("floor_kill", {}).get(str(n), false)):
			continue
		var r := XTianqiQiyinDrop.floor_first_kill(p.drop, n, difficulty_key(s), _owned_by_seal(s), _rng(s))
		p.drop = r.state
		for item in r.set_pieces:
			if XTianqiQiyinGear.set_rule().get("first_kill_floors", []).any(func(f): return int(f) == n):
				item = item.duplicate(true)
				item["level"] = int(XTianqiQiyinGear.set_rule().get("first_kill_level", 80))
			_stash(s, item)
		if not r.set_pieces.is_empty():
			notes.append(["floor_kill", [", ".join(r.set_pieces.map(func(i): return sealed_label(i)))]])
	if int(p.field_keys) > 0:
		notes.append(["field_keys", [int(p.field_keys)]])
		p.field_keys = 0
	claim(s)
	return notes


## 揭开过、已生成装备的从印库拿掉；拿到的神器生成装备进背包（XTianqiQiyinEquip 开着时）。返回这次进背包的神器
static func claim(s: XState) -> Array:
	var p := progress(s)
	if not XTianqiQiyinEquip.on(s):
		return []
	p.bag = p.bag.filter(func(i): return str(i.get("gear", "")) == "")
	var got := []
	if not p.get("artifacts_got") is Array:
		p["artifacts_got"] = []
	for k in p.artifacts:
		var item := XTianqiQiyinEquip.give(s, XTianqiQiyinEquip.make_artifact(str(k)))
		if not item.is_empty():
			got.append(item)
			p.artifacts_got.append(str(k))
	p.artifacts = []
	return got


static func run_altar(host, s: XState) -> void:
	_at = "altar"
	var a: Dictionary = data().altar
	await host.transfer(int(a.map), int(a.pos[0]), int(a.pos[1]), int(a.pos[2]))
	s.screen.start_tint(a.get("tone", [0, 0, 0, 0]), 0)
	for n in sync(s):
		await say(host, n[0], n[1])
	XTianqiQiyinLook.catch_up(s)  # 七印外观：这个功能之前揭开的也补记
	for k in XTianqiQiyinLook.take_new():
		await say(host, "look_unlock", [XTianqiQiyinLook.seal_name(str(k))])
	while true:
		claim(s)
		var opts := altar_options(s)
		var labels: Array = opts.map(func(o): return o.label)
		var i: int = await ask(host, "head", labels, [keys(s), shards(s)])
		if i < 0 or i >= opts.size() or opts[i].id == "leave":
			break
		match str(opts[i].id):
			"enter":
				await choose_and_run(host, s)
				_at = "altar"
				await host.transfer(int(a.map), int(a.pos[0]), int(a.pos[1]), int(a.pos[2]))
				s.screen.start_tint(a.get("tone", [0, 0, 0, 0]), 0)
			"reveal":
				await run_reveal(host, s)
			"bag":
				await run_bag(host, s)
			"forge":
				await XTianqiQiyinEquip.run_forge(host, s)
			"look":
				await XTianqiQiyinLook.run(host, s)
			_:
				await XTianqiQiyinDragonRun.run_option(host, s, str(opts[i].id))  # 七首之龙：存着的龙隙、首杀招募、龙血
	await say(host, "leave")
	await _home(host, s)


## 祭坛菜单 [{id, label}…]
static func altar_options(s: XState) -> Array:
	var out := [{"id": "enter", "label": "揭印（进里副本）"}]
	var n := sealed_items(s).size()
	if n > 0:
		out.append({"id": "reveal", "label": "揭开封着的（%d 件）" % n})
	if not progress(s).bag.is_empty():
		out.append({"id": "bag", "label": "看印库"})
	if XTianqiQiyinEquip.on(s):
		out.append({"id": "forge", "label": "熔炼、分解、兑换"})
	out.append_array(XTianqiQiyinDragonRun.altar_options(s))  # 七首之龙：存着的龙隙、首杀招募、龙血
	out.append_array(XTianqiQiyinLook.altar_options(s))  # 七印外观（头像框、战斗法阵）
	out.append({"id": "leave", "label": "离开"})
	return out


## 选印的选项（已揭开的印；躁动、首通标在名字后面）
static func seal_options(s: XState) -> Array:
	var drop: Dictionary = progress(s).drop
	var out := []
	for k in unlocked_seals(s):
		var info := seal_info(k)
		var tag := ""
		if str(drop.get("restless", "")) == k:
			tag += "【躁动】"
		if not bool(drop.get("first_clear", {}).get(k, false)):
			tag += "（未通）"
		out.append({"key": k, "label": "%s %s%s" % [info.seal, info.name, tag]})
	return out


static func choose_and_run(host, s: XState) -> int:
	var opts := seal_options(s)
	var labels: Array = opts.map(func(o): return o.label)
	labels.append("返回")
	var i: int = await ask(host, "pick_seal", labels)
	if i < 0 or i >= opts.size():
		return -1
	var key := str(opts[i].key)
	var info := seal_info(key)
	await say(host, "enter", [info.name, "%s——%s" % [info.rule_name, info.rule_text]])
	var direct := false
	if XTianqiQiyinDrop.direct_allowed(progress(s).drop, key):
		var m: int = await ask(host, "mode", ["打满三场", "直取（只打 Boss，没有前两场的印屑）", "返回"])
		if m < 0 or m == 2:
			return -1
		direct = m == 1
	var offering = await _ask_offering(host, s, key)
	if offering == null:
		return -1
	if keys(s) < int(data().keys.cost):
		await say(host, "no_key")
		return -1
	var r := await run_dungeon(host, s, key, direct, offering)
	return r


## 献（方案 6.3 节）：献印屑定第一件的部位，或献一把背包里的本印毕业武器（XTianqiQiyinEquip 开着时）
static func _ask_offering(host, s: XState, key: String):
	var cost := int(XTianqiQiyinDrop.data().get("offering", {}).get("shards", {}).get("cost", 5))
	var weapons := XTianqiQiyinEquip.offer_weapons(s, key) if XTianqiQiyinEquip.on(s) else []
	var can_shards := shards(s) >= cost
	if not can_shards and weapons.is_empty():
		return {}
	var opts := ["不献"]
	if can_shards:
		opts.append("献 %d 个印屑，指定第一件的部位" % cost)
	if not weapons.is_empty():
		opts.append("献一把本印毕业武器（这次毕业武器几率翻倍、必是同类）")
	opts.append("返回")
	var i: int = await ask(host, "offer_head", opts, [shards(s)])
	if i == 0:
		return {}
	if i < 0 or i >= opts.size() - 1:
		return null
	if str(opts[i]).begins_with("献一把"):
		var labels: Array = weapons.map(func(w): return str(w.name))
		labels.append("返回")
		var w: int = await host.show_text_with_choices("", 0, ["献哪一把？（献了就没了）"], labels, labels.size() - 1)
		if w < 0 or w >= weapons.size():
			return null
		return XTianqiQiyinEquip.weapon_offering(weapons[w])
	var parts := XTianqiQiyinDrop.parts()
	var labels: Array = parts.map(func(p): return part_name(p))
	labels.append("返回")
	var j: int = await ask(host, "offer_part", labels)
	if j < 0 or j >= parts.size():
		return null
	return {"kind": XTianqiQiyinDrop.OFFER_SHARDS, "part": parts[j]}


## 进一次里副本：扣印钥、记进入次数（躁动）、三场连战、结算。返回 0 打通，1 输了，-1 没进。
static func run_dungeon(host, s: XState, key: String, direct: bool, offering: Dictionary) -> int:
	var p := progress(s)
	var info := seal_info(key)
	if info.is_empty() or keys(s) < int(data().keys.cost) or not unlocked(s, key):
		return -1
	var chk := XTianqiQiyinDrop.offering_check(key, offering)
	if not chk.ok or shards(s) < int(chk.shards):
		return -1
	if int(chk.weapons) > 0 and not XTianqiQiyinEquip.take_offering(s, offering):
		return -1
	p.keys = keys(s) - int(data().keys.cost)
	p.shards = shards(s) - int(chk.shards)
	var en := XTianqiQiyinDrop.on_enter(p.drop, unlocked_seals(s), _rng(s))
	p.drop = en.state
	if str(en.restless) != "":
		await say(host, "restless", [str(seal_info(str(en.restless)).get("seal", ""))])
	_at = key
	await host.transfer(int(info.map), int(info.pos[0]), int(info.pos[1]), int(info.pos[2]))
	s.screen.start_tint(info.get("tone", [0, 0, 0, 0]), 0)
	var run := {"seal": key, "gems": {}, "shards": 0}
	var troops: Array = info.troops
	var start := 2 if direct else 0
	var result := 0
	for f in range(start, troops.size()):
		if f > start:
			await say(host, "next")
		if str(info.rule) == "magic_tower":
			await _pick_gem(host, run)
		XTianqiQiyinRule.prepare(key, f == troops.size() - 1, run.gems)
		var r: int = await host.start_battle(int(troops[f]), false, true)
		if r != 0:
			result = 1
			break
		if f < troops.size() - 1:
			var e := XTianqiQiyinDrop.roll_elite(p.drop, _rng(s))
			p.drop = e.state
			run.shards = int(run.shards) + int(e.shards)
	if result != 0:
		p.shards = shards(s) + int(run.shards)
		await say(host, "lost")
		return 1
	await say(host, "boss_win", [str(info.boss.name)])
	var rift := await XTianqiQiyinDragonRun.after_boss(host, s)  # 七首之龙：结算之前判龙隙，出了就演地面裂开
	await settle(host, s, key, offering, run)
	await XTianqiQiyinDragonRun.offer(host, s, rift)  # 七首之龙：刚出的龙隙当场问进不进，不进就存着
	return 0


static func _pick_gem(host, run: Dictionary) -> void:
	var gems: Array = data().rules.magic_tower.gems
	var labels: Array = gems.map(func(g): return g.name)
	var i: int = await ask(host, "gem", labels)
	i = clampi(i, 0, gems.size() - 1)
	var k := str(gems[i].key)
	run.gems[k] = float(run.gems.get(k, 0.0)) + float(gems[i].value)


## Boss 打赢后的结算：掉落、首通、印钥退还、印屑；当场揭（方案 6.5 节第 3 条）。返回这一场掉的物品（测试用）
static func settle(host, s: XState, key: String, offering: Dictionary, run: Dictionary) -> Array:
	var p := progress(s)
	var rng := _rng(s)
	var r := XTianqiQiyinDrop.roll_boss(p.drop, key, difficulty_key(s), _owned_by_seal(s), offering, drop_mult(s), rng,
		not ARTIFACT_PITY)  # 神器保底开着时神器不在 roll_boss 里掷，下面 roll_artifact 掷（同一条流、同一位置）
	var got := []
	if str(r.error) != "":
		push_error("XTianqiQiyin: roll_boss " + str(r.error))
		return got
	p.drop = r.state
	if ARTIFACT_PITY:
		r.artifact = roll_artifact(s, float(XTianqiQiyinDrop.data().get("artifact", {}).get("chance", 0.0)), rng)
	got.append_array(r.set_pieces)
	if not r.weapon.is_empty():
		got.append(r.weapon)
	var fc := XTianqiQiyinDrop.first_clear(p.drop, key, difficulty_key(s), _owned_by_seal(s, got), rng)
	p.drop = fc.state
	var first: bool = not fc.set_pieces.is_empty()
	got.append_array(fc.set_pieces)
	var first_idx: int = p.bag.size()
	for item in got:
		_stash(s, item)
	if str(r.artifact) != "":
		p.artifacts.append(str(r.artifact))
	var gained_shards := int(run.get("shards", 0)) + int(r.shards) + int(r.refund)
	p.shards = shards(s) + gained_shards
	var refund := rng.next_float("qiyin_key_refund") < float(data().keys.refund_chance)
	if refund:
		p.keys = keys(s) + 1
	if host == null:
		return got
	if not got.is_empty() or str(r.artifact) != "":
		await say(host, "drop_head")
		for item in got:
			await XTianqiQiyinShow.drop(host, item)  # 演出：套装件闪本印色、毕业武器定格、真印红光震屏
			await host.show_text("", 0, [sealed_label(item)])
		if str(r.artifact) != "":
			await XTianqiQiyinShow.artifact(host, str(r.artifact))  # 演出：整屏变暗、七印依次亮起
			await host.show_text("", 0, ["神器「%s」" % str(XTianqiQiyinGear.artifact(str(r.artifact)).get("name", r.artifact))])
	if first:
		await say(host, "first_clear")
	if gained_shards > 0:
		await say(host, "shards", [gained_shards])
	if refund:
		await say(host, "key_refund")
	if not got.is_empty():
		var i: int = await host.show_text_with_choices("", 0, ["现在就揭开吗？"], ["揭开", "先收着"], 1)
		if i == 0:
			for idx in range(first_idx, first_idx + got.size()):
				await XTianqiQiyinShow.reveal(host, progress(s).bag[idx])  # 演出：封印碎开
				await host.show_text("", 0, [_line(scene("reveal_done")[0], [revealed_label(reveal(s, idx))])])
				for k in XTianqiQiyinLook.take_new():
					await say(host, "look_unlock", [XTianqiQiyinLook.seal_name(str(k))])
	return got


## 开关（O-423）：true＝七印的套装件、毕业武器几率乘全队掉率加成（和常规掉落同一套：XTianqiDrop.party_mult，
## 技能、套装、号卷、寻宝猎人、亡魂汲取、词条「物品掉落」相加后按 合计×200÷(合计＋200) 递减，最高逼近 3 倍）；false＝按 1
static var DROP_BONUS := true


## 物品掉落加成（方案 6.2 节：对套装件、毕业武器照常生效；真印、神器、龙隙不吃）。基础掉率不动（Kyo 11-14：接上，但要非常低）
static func drop_mult(s: XState, members = null) -> float:
	if not DROP_BONUS or s == null or not XTianqiDrop.on(s):
		return 1.0
	return XTianqiDrop.party_mult(s, members)


# ---- 神器：保底、防重（Kyo 11-14） ----

## 开关（O-424）：true＝能掉神器的战斗（里副本 Boss、七首之龙）共用一个保底计数 artifact_miss，连着 pity_after－1 次没出、
## 下一次必出；已有的神器不再掉，五件齐了不掷也不计。false＝回到原来（五件里随机、没有保底、可重复）
static var ARTIFACT_PITY := true


## 保底次数（qiyin_drop.json artifact.pity_after）：第这么多次必出
static func artifact_pity_after() -> int:
	return int(XTianqiQiyinDrop.data().get("artifact", {}).get("pity_after", 333))


## 本档拿到过的神器键（印库里没领的、领过的、背包和身上的）
static func owned_artifacts(s: XState) -> Array:
	var p := progress(s)
	var out := []
	for k in p.artifacts + p.get("artifacts_got", []):
		if not out.has(str(k)):
			out.append(str(k))
	for e in s.gear + XTianqiQiyinEquip.worn(s):
		var m := XTianqiQiyinEffects.mark_of(e)
		if str(m.get("kind", "")) == "artifact" and not out.has(str(m.get("key", ""))):
			out.append(str(m.key))
	return out


## 还能掉的神器（五件里还没有的，表里的顺序）
static func artifact_pool(s: XState) -> Array:
	var owned := owned_artifacts(s)
	return XTianqiQiyinDrop.artifact_keys().filter(func(k): return not owned.has(str(k)))


## 掷一次神器（里副本 Boss、七首之龙共用）。chance 是这场的几率（不吃掉率加成）。返回神器键或 ""。
## 抽取：五件齐了不抽；到保底不抽浮点数；中了、还剩两件以上时 next_index_mod 一次。reason 前缀区分来源（磁带测试用）
static func roll_artifact(s: XState, chance: float, rng: XRandomStream, reason := "qiyin_artifact") -> String:
	if not ARTIFACT_PITY:
		if rng.next_float(reason) < chance:
			var keys := XTianqiQiyinDrop.artifact_keys()
			return str(keys[rng.next_index_mod(keys.size(), reason + "_pick")])
		return ""
	var p := progress(s)
	var pool := artifact_pool(s)
	if pool.is_empty():
		return ""
	var miss := int(p.artifact_miss)
	var hit := miss + 1 >= artifact_pity_after()
	if not hit:
		hit = rng.next_float(reason) < chance
	if not hit:
		p.artifact_miss = miss + 1
		return ""
	p.artifact_miss = 0
	return str(pool[0]) if pool.size() == 1 else str(pool[rng.next_index_mod(pool.size(), reason + "_pick")])


static func _stash(s: XState, item: Dictionary) -> void:
	var it := item.duplicate(true)
	it["revealed"] = false
	progress(s).bag.append(it)


## 印库里已有的部位 {印: [部位…]}（掉落「已有部位减半」用；extra 是同一次刚掉、还没入库的）
static func _owned_by_seal(s: XState, extra := []) -> Dictionary:
	var equip := XTianqiQiyinEquip.on(s)
	var out := XTianqiQiyinEquip.owned_parts(s) if equip else {}
	for item in progress(s).bag + extra:
		if equip and str(item.get("gear", "")) != "":
			continue
		if str(item.get("kind", "")) != XTianqiQiyinDrop.KIND_SET:
			continue
		var k := str(item.seal)
		if not out.has(k):
			out[k] = []
		if not out[k].has(str(item.part)):
			out[k].append(str(item.part))
	return out


# ---- 封着的、揭开 ----

static func sealed_items(s: XState) -> Array:
	return progress(s).bag.filter(func(i): return not bool(i.get("revealed", false)))


static func part_name(part: String) -> String:
	return str(data().get("names", {}).get("parts", {}).get(part, part))


static func grade_name(g: String) -> String:
	return str(data().get("names", {}).get("grades", {}).get(g, g))


## 封着时只看得出是哪一印、哪个部位（武器看得出类型）、金光还是红光（方案 6.1 节第 3 条）
static func sealed_label(item: Dictionary) -> String:
	var seal := str(seal_info(str(item.get("seal", ""))).get("seal", item.get("seal", "")))
	var glow := str(data().names.true_glow if bool(item.get("true_seal", false)) else data().names.set_glow)
	if str(item.get("kind", "")) == XTianqiQiyinDrop.KIND_WEAPON:
		return "%s·毕业武器（%s）〔%s〕" % [seal, str(item.get("wtype", "")), glow]
	return "%s·%s〔%s〕" % [seal, part_name(str(item.get("part", ""))), glow]


## 揭开后的名字：套装件名或武器名、真印、三条成色
static func revealed_label(item: Dictionary) -> String:
	var name := ""
	if str(item.get("kind", "")) == XTianqiQiyinDrop.KIND_WEAPON:
		var w := XTianqiQiyinGear.weapon_of_type(str(item.get("wtype", "")))
		if str(item.seal) == "mo" or w.is_empty() or str(w.get("seal", "")) != str(item.seal):
			var list := XTianqiQiyinGear.weapons_of_seal(str(item.seal))
			w = list[0] if not list.is_empty() else {}
		name = "%s（%s）" % [str(w.get("name", "毕业武器")), str(item.get("wtype", ""))]
	else:
		var st := XTianqiQiyinGear.set_of(str(item.get("seal", "")))
		for pc in st.get("pieces", []):
			if str(pc.part) == str(item.get("part", "")):
				name = str(pc.name)
	var grades: Array = item.get("grades", []).map(func(g): return grade_name(str(g)))
	var text := "%s%s　成色：%s" % ["【真印】" if bool(item.get("true_seal", false)) else "", name, "／".join(grades)]
	if item.get("affix_text") is Array and not item.affix_text.is_empty():
		text += "\n" + "\n".join(PackedStringArray(item.affix_text))
	return text


## 揭开印库第 idx 件（成色、真印在掉落时已经掷定，这里只亮出来）。返回这件
static func reveal(s: XState, idx: int) -> Dictionary:
	var bag: Array = progress(s).bag
	if idx < 0 or idx >= bag.size():
		return {}
	bag[idx]["revealed"] = true
	XTianqiQiyinLook.note(bag[idx])  # 七印外观：一套六件都揭到过就解锁（跨存档）
	if XTianqiQiyinEquip.on(s) and str(bag[idx].get("gear", "")) == "":
		var gear := XTianqiQiyinEquip.give(s, XTianqiQiyinEquip.make(bag[idx], difficulty_key(s), _rng(s)))
		if not gear.is_empty():
			bag[idx]["gear"] = str(gear.instanceId)
			bag[idx]["affix_text"] = XTianqiQiyinEffects.mark_of(gear).get("affixes", []).map(func(a): return XTianqiQiyinEquip.affix_line(a))
	return bag[idx]


static func run_reveal(host, s: XState) -> void:
	while true:
		var bag: Array = progress(s).bag
		var idxs := []
		for i in bag.size():
			if not bool(bag[i].get("revealed", false)):
				idxs.append(i)
		if idxs.is_empty():
			await say(host, "reveal_none")
			return
		var labels: Array = idxs.map(func(i): return sealed_label(bag[i]))
		labels.append("全部揭开")
		labels.append("返回")
		var c: int = await ask(host, "reveal_head", labels, [idxs.size()])
		if c < 0 or c == labels.size() - 1:
			return
		var picked := idxs if c == idxs.size() else [idxs[c]]
		for i in picked:
			await XTianqiQiyinShow.reveal(host, bag[int(i)])  # 演出：封印碎开
			await host.show_text("", 0, [_line(scene("reveal_done")[0], [revealed_label(reveal(s, int(i)))])])
			for k in XTianqiQiyinLook.take_new():
				await say(host, "look_unlock", [XTianqiQiyinLook.seal_name(str(k))])


static func run_bag(host, s: XState) -> void:
	var bag: Array = progress(s).bag
	await say(host, "bag_head", [bag.size()])
	for item in bag:
		await host.show_text("", 0, [revealed_label(item) if bool(item.get("revealed", false)) else sealed_label(item)])


## 揭开的件变成能穿的装备（XTianqiQiyinEquip，cc/qiyin-equip）
static func equip_ready() -> bool:
	return XTianqiQiyinEquip.on()


# ---- 野外印钥（XTianqiQiyinRule.end 调） ----

## 31～35 层的一场普通战斗打赢：精英、守护者、守层者必掉，别的 field_chance。返回掉了几把
static func field_drop(s: XState, map_id: int, troop_name: String, rng: XRandomStream = null) -> int:
	if not allowed(s) or _at != "" or not data().keys.field_maps.any(func(m): return int(m) == map_id):
		return 0
	var n := 0
	for tag in data().keys.sure_tags:
		if troop_name.contains(str(tag)):
			n = 1
	if n == 0:
		if rng == null:
			rng = _rng(s)
		n = 1 if rng.next_float("qiyin_field_key") < float(data().keys.field_chance) else 0
	if n > 0:
		var p := progress(s)
		p.keys = keys(s) + n
		p.field_keys = int(p.field_keys) + n
	return n


static func _home(host, s: XState) -> void:
	_at = ""
	s.screen.start_tint([0, 0, 0, 0], 0)
	await host.transfer(XTianqi.HALL_MAP, XTianqi.HALL_POS.x, XTianqi.HALL_POS.y, XTianqi.HALL_POS.z)


static func current() -> String:
	return _at


## 测试用：直接设当前所在（"altar"／印键／""）
static func set_current(key: String) -> void:
	_at = key
