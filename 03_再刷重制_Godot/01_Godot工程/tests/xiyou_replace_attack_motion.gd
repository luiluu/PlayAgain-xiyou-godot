extends Node
## 【cc·未经审查】替换后的普攻按技能动作演出（O-待定，XBattler.REPLACED_ATTACK_OWN_MOTION）。
## 原版 isAttack 规则：<Replace Attack: x> 换来的技能仍走 performAttack（挥武器、武器图）、不放施放动画（castAnimation），
## 琴里学了炽烈之魂（6174）后普攻 6170「初火*炽烈火柱」看着像平A（v0.01.10 玩家反馈）。
## 开关开：替换成带技能类型（stypeId>0）的技能按技能本身演出；没替换（技能 1）或替换成 stypeId 0 的「攻击」类技能照旧挥武器。
## - 判断：琴里 6170、火精灵文书（武器 1109 → 1004）、飞镖（武器 25 → 12，stypeId 0）、敌人佛陀真身（状态 66 → 562）、技能 1，开／关各一；
## - 结算不动：is_attack、普攻追加次数、同种子下 6170 的伤害／暴击／命中／TP 开关前后全同；
## - 画面：真战斗场景里跑完整行动序列，逐帧记出手者动作、武器图、出手者身上的施放动画、顶部日志招名；技能动画关时只少动画、动作照技能。
## 窗口模式加 -- --out=<目录> 截琴里出手（开关前后一样）与惊宵锤开／关各三帧。
class RecBattle extends XBattleScene:
	var started := []

	func _main() -> void:
		pass

	func _start_animation(id: int, target: XBattler, state_ani := false) -> MVAnimation:
		var a := super._start_animation(id, target, state_ani)
		started.append({"id": id, "target": target, "shown": a != null})
		return a

const KOTORI := 159
const SOUL := 6174
const PILLAR := 6170
const HERO := 4
var results := []
var out_dir := ""


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool, detail = null) -> void:
	results.append({"name": label, "passed": ok})
	if not ok:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _state() -> XState:
	var s := XState.new_game(3, 1, [8])
	XState.current = s
	s.switches[2494] = true  # 超强者开放（琴里是超强者，没开会被清出出战栏）
	s.party.clear()
	s.battle_slots.clear()
	s.add_actor(KOTORI)
	s.add_actor(HERO)
	s.random_master = XRandomStream.hex64(20261115)
	var k: XActor = s.actor(KOTORI)
	k.change_level_mv(60)
	k.learn_skill(SOUL)
	for id in [KOTORI, HERO]:
		s.actor(id).refresh_passive()
		s.actor(id).recover_all()
	return s


func _equip_weapon(a: XActor, base: int) -> void:
	a.keep_unequippable = true  # 夹具：直接套上别的职业的武器，refresh 不卸（看的是替换后的演出，不是能不能装）
	a.equips[0] = XGear.template("weapon", base)
	a.refresh_passive()


func _judge() -> void:
	var s := _state()
	var k: XActor = s.actor(KOTORI)
	var hero: XActor = s.actor(HERO)
	var pillar := XDB.rec("Skills", PILLAR)
	check("kotori.attack_is_6170", k.attack_skill_id() == PILLAR, k.attack_skill_id())
	check("kotori.is_attack", k.is_attack(pillar))
	check("kotori.skill_motion_on", not k.attack_motion(pillar))
	check("hero.skill1_swing", hero.attack_skill_id() == 1 and hero.attack_motion(XDB.rec("Skills", 1)))
	check("hero.other_skill_not_attack", not hero.attack_motion(pillar))
	_equip_weapon(hero, 1109)  # 火精灵文书 <Replace Attack: 1004>（炽烈火柱，stypeId 2）
	var book := XDB.rec("Skills", 1004)
	check("book.attack_is_1004", hero.attack_skill_id() == 1004 and hero.is_attack(book), hero.attack_skill_id())
	check("book.skill_motion_on", not hero.attack_motion(book))
	_equip_weapon(hero, 25)  # 飞镖 <Replace Attack: 12>（攻击，stypeId 0）
	var dart := XDB.rec("Skills", 12)
	check("dart.attack_is_12", hero.attack_skill_id() == 12, hero.attack_skill_id())
	check("dart.swing_on", hero.attack_motion(dart))
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	var e: XEnemy = logic.enemies[0]
	e.add_state(66)  # 佛陀真身 <Replace Attack: 562>（如来神掌，stypeId 2）
	var palm := XDB.rec("Skills", 562)
	check("enemy.attack_is_562", e.attack_skill_id() == 562 and e.is_attack(palm), e.attack_skill_id())
	check("enemy.skill_motion_on", not e.attack_motion(palm))
	# 甚尔四形态主技能、宿傩 10238 在排除名单里：开关开着也挥咒具；名单清空才按技能演出
	var toji: XActor = s.actor(XActor.TOJI)
	var toji_main := XDB.rec("Skills", toji.attack_skill_id())
	check("toji.main_skill", XActor.TOJI_MAIN.has(int(toji_main.id)) and toji.is_attack(toji_main), toji.attack_skill_id())
	check("toji.excluded_swing", toji.attack_motion(toji_main))
	var keep: Array = XBattler.OWN_MOTION_EXCLUDE
	XBattler.OWN_MOTION_EXCLUDE = []
	check("toji.unexcluded_skill_motion", not toji.attack_motion(toji_main))
	XBattler.OWN_MOTION_EXCLUDE = keep
	check("toji.exclude_list", XBattler.OWN_MOTION_EXCLUDE == XActor.TOJI_MAIN + [10238], XBattler.OWN_MOTION_EXCLUDE)
	var sukuna: XActor = s.actor(XSukuna.ACTOR)
	var body := XDB.rec("Skills", sukuna.attack_skill_id())
	check("sukuna.excluded_swing", sukuna.attack_skill_id() == 10238 and sukuna.is_attack(body) and sukuna.attack_motion(body), sukuna.attack_skill_id())
	XBattler.REPLACED_ATTACK_OWN_MOTION = false
	check("kotori.swing_off", k.attack_motion(pillar) and k.is_attack(pillar))
	_equip_weapon(hero, 1109)
	check("book.swing_off", hero.attack_motion(book))
	check("enemy.swing_off", e.attack_motion(palm))
	XBattler.REPLACED_ATTACK_OWN_MOTION = true


## 同种子出一次 6170：伤害、暴击、命中、TP、追加次数
func _settle(flag: bool) -> Array:
	XBattler.REPLACED_ATTACK_OWN_MOTION = flag
	seed(4242)
	var s := _state()
	var logic := XBattleLogic.new()
	logic.setup(2, s)
	logic.turn = 1
	var k: XActor = s.actor(KOTORI)
	var pillar := XDB.rec("Skills", PILLAR)
	var logs := logic.execute(k, pillar, logic.enemies[0], true)
	var out := [XBattleLogic.attack_repeats(k, pillar, int(pillar.repeats)), k.tp, k.mp]
	for l in logs:
		if l.type == "hit":
			out.append([logic.enemies.find(l.target), l.get("missed"), l.get("evaded"), l.get("critical"), l.get("hpDamage", l.get("damage", null))])
	for en in logic.enemies:
		out.append(en.hp)
	XBattler.REPLACED_ATTACK_OWN_MOTION = true
	return out


## 跑一招完整行动序列并逐帧记录
func _play(scene: RecBattle, user: XActor, skill_id: int, shot := "") -> Dictionary:
	for sp in scene.sprites.values():
		sp.set_motion("walk")
		sp.position = sp.home
	scene.started.clear()
	for e in scene.logic.enemies:
		e.remove_state(e.death_state_id() if e.has_method("death_state_id") else 1)
		e.hp = e.mhp
	var target: XBattler = scene.logic.alive(scene.logic.enemies)[0]
	var logs := scene.logic.execute(user, XDB.rec("Skills", skill_id), target, true)
	var i := logs.find(logs.filter(func(l): return l.type == "seq_phase")[0])
	var j := logs.find(logs.filter(func(l): return l.type == "seq_end")[0])
	var got := {"motions": [], "weapon": false, "log": "", "frames": 0}
	var sp: XBattlerSprite = scene.sprites[user]
	var player := XSequencePlayer.create(scene, logs[i - 1], logs.slice(i, j + 1))
	scene.show_views(logs[i - 1].views)
	player.on_frame = func(_p):
		got.frames += 1
		if got.motions.is_empty() or got.motions[-1] != sp.motion:
			got.motions.append(sp.motion)
		if sp.weapon != null and sp.weapon.visible and sp._weapon_id > 0:
			got.weapon = true
		if got.log == "" and not scene._log_lines.is_empty():
			got.log = str(scene._log_lines[0].text)
		if shot != "" and out_dir != "" and got.frames in [6, 18, 34]:
			_shot("%s_%02d" % [shot, got.frames])
	await player.play()
	scene.clear_views()
	got.cast = scene.started.filter(func(r): return r.target == user).map(func(r): return [r.id, r.shown])
	return got


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		DirAccess.make_dir_recursive_absolute(out_dir)
		img.save_png(out_dir.path_join(name + ".png"))


func _scene_checks() -> void:
	var s := _state()
	var scene := RecBattle.new()
	scene.setup(2, true, false, {})
	add_child(scene)
	await get_tree().physics_frame
	for e in scene.logic.enemies:
		var p: Array = (e as XEnemy).data().params.duplicate()
		p[0] = float(p[0]) + 100000000.0
		(e as XEnemy).zq_ref = {"p": p, "k": 1}
		e.hp = e.mhp
	var k: XActor = s.actor(KOTORI)
	var hero: XActor = s.actor(HERO)
	check("scene.party", scene.sprites.has(k) and scene.sprites.has(hero), scene.logic.actors.map(func(x): return x.actor_id))
	var magic: Array = XDB.system().get("magicSkills", [])
	var want := "spell" if magic.has(1) or magic.has(1.0) else "skill"  # 4437 stypeId 1
	for anim_on in [true, false]:
		XConfig.set_flag("CombatSkillAnimation", anim_on)
		var tag := "anim_on" if anim_on else "anim_off"
		# 琴里 6170：技能自己的序列写了三次 motion swing、<Cast Animation: 0>、不经 PERFORM ACTION，开关前后一样（火柱动画 158 只在技能动画开时放在目标上）
		var on := await _play(scene, k, PILLAR, "kotori_on" if anim_on else "")
		XBattler.REPLACED_ATTACK_OWN_MOTION = false
		var off := await _play(scene, k, PILLAR, "kotori_off" if anim_on else "")
		XBattler.REPLACED_ATTACK_OWN_MOTION = true
		check("scene.%s.kotori_own_sequence_swing" % tag, on.motions.has("swing") and on.cast.is_empty() and on.motions == off.motions and on.weapon == off.weapon, [on, off])
		check("scene.%s.kotori_log_name" % tag, on.log.ends_with(str(XDB.rec("Skills", PILLAR).name)) and off.log == on.log, [on.log, off.log])
		# 没替换的普攻照旧挥武器、不放施放动画
		var plain := await _play(scene, hero, 1)
		check("scene.%s.hero_attack_unchanged" % tag, not plain.motions.has(want) and not plain.motions.has("skill") and plain.cast.is_empty(), plain)
		# 传承:惊宵锤（武器 1724 → 4437 雷降，stypeId 1、物理，序列 PERFORM ACTION＋CAST ANIMATION、没写施放动画号＝物理 52）：
		# 按技能演出（施法动作、不出武器图）、放施放动画；关开关回到挥武器、不放。每次出手前重新套上
		_equip_weapon(hero, 1724)
		check("scene.%s.hammer_replaced" % tag, hero.attack_skill_id() == 4437, hero.attack_skill_id())
		var book := await _play(scene, hero, 4437, "hammer_on" if anim_on else "")
		check("scene.%s.hammer_motion_on" % tag, book.motions.has(want) and not book.weapon and book.cast.size() >= 1 and book.cast.all(func(c): return c[1] == anim_on), book)
		XBattler.REPLACED_ATTACK_OWN_MOTION = false
		_equip_weapon(hero, 1724)
		check("scene.%s.hammer_replaced_off" % tag, hero.attack_skill_id() == 4437, hero.attack_skill_id())
		var book_off := await _play(scene, hero, 4437, "hammer_off" if anim_on else "")
		XBattler.REPLACED_ATTACK_OWN_MOTION = true
		check("scene.%s.hammer_motion_off" % tag, not book_off.motions.has(want) and book_off.cast.is_empty(), book_off)
		hero.equips[0] = null
		hero.refresh_passive()
	XConfig.set_flag("CombatSkillAnimation", false)
	scene.queue_free()


func _run() -> void:
	XPartyFormation.ENABLED = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	XSave.dir_override = "user://test_xiyou_replace_attack_motion"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XEnemy.force_roll = 100.0
	for anim in XDB.table("Animations"):
		if anim is Dictionary:
			for tm in anim.get("timings", []):
				tm.erase("se")
	XConfig.set_battle_speed(4)
	_judge()
	var a := _settle(true)
	var b := _settle(false)
	check("settle.same", JSON.stringify(a) == JSON.stringify(b), [a, b])
	check("settle.has_hits", a.size() > 4, a)
	await _scene_checks()
	for sp in XSound._players:
		if is_instance_valid(sp):
			sp.stop()
	await get_tree().create_timer(0.3, true, false, true).timeout
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
