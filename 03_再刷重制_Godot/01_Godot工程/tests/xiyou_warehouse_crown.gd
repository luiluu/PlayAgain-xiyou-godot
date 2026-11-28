extends Node
## 【cc·T616·未经审查】玩家反馈 0.04.08「头顶存进仓库再取出就消失，读档也找不回」：魔冠「"头顶"」7940 存取方桌仓库（XWarehouse）
## 与成长账本（XDemonCrown，存档外的 crown_progress_v1.json）。西游档、启封档各跑一遍，都走真写盘真读档（tq_save_kit）。
## - fresh：刷出的（成长 0）和身上卸下的（打过胜仗、有成长）各一件，存仓库→取出→存档→读档：还在背包、整件一字不差（成长、词条、孔位、
##   特性倍率都在）、账本没记 removed；再穿上打一场照常成长。
## - stored：存在仓库里存档读档，账本成长变了重放照样盖到仓库那件上；取出存读后照旧。
## - repro：WAREHOUSE_KEEP 关掉＝修复前／原版：存仓库记 removed、取出后一存档就没了、读存仓库之前的档也没了（复现玩家现象）。
## - heal：开关打开后读修复前那两份档（背包里那件、仓库里那件）：以存档为准撤销 removed、成长不变、之后照常成长；第一次读档前账本原样
##   备份到 .t616bak，只备一次、后面不覆盖。
## - sold：修复后真卖掉（removed 带 lost 标记），读卖之前的档照旧移除（背包里的、仓库里的都拿掉，仓库占用跟着减）——防 SL 不放松。
## - other：普通武器、防具存取存读不受影响。
## 云裳天衣同类问题的专项在 xiyou_yunshang_gear_load（legacy_remove_bag、switch_off.legacy_bag_removed）与 xiyou_yunshang_shop（p8.lose warehouse／warehouse_keep）。

const Kit := preload("res://tests/lib/tq_save_kit.gd")
var results: Array = []
var kit: Kit
var s: XState
var mode := ""


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": mode + "." + name, "passed": ok})
	if not ok:
		print("FAIL ", mode, ".", name, " ", JSON.stringify(detail).left(1200))
	return ok


# ---- 夹具 ----
func _new_state(tq: bool) -> void:
	for f in DirAccess.get_files_at(kit.dir):
		DirAccess.remove_absolute(kit.dir.path_join(f))
	XDemonCrown.forget_ledger()
	XDemonCrown.storage_error = ""
	XDemonCrown.battle = null
	XDemonCrown.healed = []
	XDemonCrown.WAREHOUSE_KEEP = true
	if tq:
		s = Kit.new_game()
	else:
		s = XState.new_game(2, 1, [8, 9, 10])
		s.map_id = 4
	XState.current = s
	for a in s.battle_members():
		a._lv = maxi(a._lv, 60)  # 头顶有等级要求
		a.refresh_passive()
		a.recover_all()
	XWarehouse.create(s, "<仓库:999>")


func _reload(slot: int) -> bool:
	var st := kit.reload(slot)
	if st == null:
		return false
	s = st
	return true


func _wearer() -> XActor:
	return s.battle_members()[0]


func _grant() -> Dictionary:
	s.gain_gear("armor", XDemonCrown.ARMOR, 1)
	return s.gear.filter(XDemonCrown.is_gear).back()


func _wear(it: Dictionary) -> void:
	var a := _wearer()
	var slot := a.equip_slots().find(17)
	if not XEquipment.change(s, a, slot, it):
		a.equips[slot] = it
		s.gear.erase(it)
	a.refresh_passive()


func _unwear() -> void:
	var a := _wearer()
	XEquipment.change(s, a, a.equip_slots().find(17), null)
	a.refresh_passive()


func _win(n := 1) -> void:
	for i in n:
		XDemonCrown.begin(s, 3, func(): return 0.5)
		XDemonCrown.finish(s, 0)


func _uid(it: Dictionary) -> String:
	return str(it.get(XDemonCrown.UID, ""))


## 这件现在在哪：bag／worn／warehouse／""（没了）
func _where(uid: String) -> String:
	for e in s.gear:
		if _uid(e) == uid:
			return "bag"
	for a in s.actors.values():
		for e in a.raw_equip_list():
			if _uid(e) == uid:
				return "worn"
	for e in XDemonCrown.stored(s):
		if _uid(e) == uid:
			return "warehouse"
	return ""


func _item(uid: String) -> Dictionary:
	for e in s.gear + XDemonCrown.stored(s):
		if _uid(e) == uid:
			return e
	for a in s.actors.values():
		for e in a.raw_equip_list():
			if _uid(e) == uid:
				return e
	return {}


## 仓库里这件的条目（XWarehouse.stored 的 {rec, qty}）
func _stored_rec(uid: String) -> Dictionary:
	for e in XWarehouse.stored(s, "armor"):
		if _uid(e.rec) == uid:
			return e.rec
	return {}


func _row(uid: String):
	var p = XDemonCrown.record(s)
	return p.items.get(uid) if p != null else null


func _removed(uid: String) -> bool:
	var r = _row(uid)
	return r != null and bool(r.get("removed", false))


## 读存档后整数会变浮点：整的浮点统一成整数再比；说明文字去掉空行（describe 每重写一次多留空行，改前就有）；不比 equipment（见 _snap）
func _norm(v):
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return int(v)
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is Dictionary:
		var o := {}
		var keys: Array = v.keys()
		keys.sort()
		for k in keys:
			o[str(k)] = _norm(v[k])
		return o
	return v


func _snap(it: Dictionary) -> String:
	var d: Dictionary = JSON.parse_string(JSON.stringify(it))
	d.note = "\n".join(str(d.get("note", "")).split("\n", false))
	d.erase("equipment")  # 底子模板的词条池定义（不是这一件自己的数据）：存档瘦身不存、读档按模板补，普通装备也一样
	return JSON.stringify(_norm(d))


func _diff(a: String, b: String) -> Array:
	var x: Dictionary = JSON.parse_string(a)
	var y: Dictionary = JSON.parse_string(b)
	var out := []
	for k in x:
		if JSON.stringify(x[k]) != JSON.stringify(y.get(k)):
			out.append([k, x[k], y.get(k)])
	for k in y:
		if not x.has(k):
			out.append([k, null, y[k]])
	return out


func _crown_rate(it: Dictionary) -> float:
	for t in it.get("traits", []):
		if bool(t.get("_codexCrown", false)):
			return float(t.value)
	return -1.0


func _ledger_raw() -> String:
	return FileAccess.get_file_as_string(XDemonCrown.path()) if FileAccess.file_exists(XDemonCrown.path()) else ""


func _backup_raw() -> String:
	var b := XDemonCrown.path() + XDemonCrown.BACKUP_SUFFIX
	return FileAccess.get_file_as_string(b) if FileAccess.file_exists(b) else ""


# ---- 场景 ----
## 刷出的（成长 0）和身上卸下的（有成长）各一件：存→取→存档→读档
func _fresh() -> void:
	_new_state(mode == "qifeng")
	var dropped := _grant()
	var worn := _grant()
	_wear(worn)
	_win(5)
	_unwear()
	var b_worn := XDemonCrown.bonus(worn)
	_check("fresh.setup", b_worn > 4.0 and XDemonCrown.bonus(dropped) == 0.0 and _where(_uid(worn)) == "bag", [b_worn, _where(_uid(worn))])
	var snaps := {_uid(dropped): _snap(dropped), _uid(worn): _snap(worn)}
	for it in [dropped, worn]:
		var uid := _uid(it)
		var tag := "fresh." + ("dropped" if it == dropped else "worn")
		_check(tag + ".deposit", XWarehouse.deposit(s, "armor", it))
		_check(tag + ".in_warehouse", _where(uid) == "warehouse", _where(uid))
		_check(tag + ".not_removed_after_deposit", not _removed(uid), _row(uid))
		_check(tag + ".withdraw", XWarehouse.withdraw(s, "armor", _stored_rec(uid)))
		_check(tag + ".bag_after_withdraw", _where(uid) == "bag", _where(uid))
	_check("fresh.save", kit.save(1))
	_check("fresh.reload", _reload(1))
	for uid in snaps:
		var tag := "fresh." + ("dropped" if snaps.keys().find(uid) == 0 else "worn")
		_check(tag + ".bag_after_reload", _where(uid) == "bag", _where(uid))
		_check(tag + ".ledger_kept", _row(uid) != null and not _removed(uid), _row(uid))
		var it := _item(uid)
		if not it.is_empty():
			_check(tag + ".identical", _snap(it) == snaps[uid], _diff(snaps[uid], _snap(it)))
	_check("fresh.worn.rate", absf(_crown_rate(_item(snaps.keys()[1])) - (1.0 + XTianqiGear.crown_bonus(b_worn) / 100.0)) < 1e-6, _crown_rate(_item(snaps.keys()[1])))
	_check("fresh.count", XDemonCrown.owned(s).size() == 2, XDemonCrown.owned(s).size())
	# 存档再读一次也还在（重放不再删）
	_check("fresh.reload2", kit.save(1) and _reload(1) and _where(snaps.keys()[1]) == "bag")
	# 照常成长
	var it2 := _item(snaps.keys()[1])
	_wear(it2)
	_win(1)
	_check("fresh.grows_again", absf(XDemonCrown.bonus(XDemonCrown.gear(_wearer())) - XDemonCrown.next(b_worn)) < 1e-6, [XDemonCrown.bonus(XDemonCrown.gear(_wearer())), b_worn])


## 放在仓库里存档读档；账本成长变了，重放盖到仓库那件上
func _stored() -> void:
	_new_state(mode == "qifeng")
	var it := _grant()
	var uid := _uid(it)
	_check("stored.deposit", XWarehouse.deposit(s, "armor", it))
	var used := XWarehouse.used(s)
	_check("stored.save", kit.save(1) and _reload(1))
	_check("stored.in_warehouse_after_reload", _where(uid) == "warehouse" and XWarehouse.used(s) == used, [_where(uid), XWarehouse.used(s), used])
	_check("stored.ledger_change", XDemonCrown.transaction(s, func(p): p.items[uid].bonus = 123.0))
	var w := _stored_rec(uid)
	_check("stored.bonus_follows_ledger", absf(XDemonCrown.bonus(w) - 123.0) < 1e-6 and absf(_crown_rate(w) - (1.0 + XTianqiGear.crown_bonus(123.0) / 100.0)) < 1e-6, [XDemonCrown.bonus(w), _crown_rate(w)])
	_check("stored.withdraw", XWarehouse.withdraw(s, "armor", w))
	_check("stored.save2", kit.save(1) and _reload(1))
	_check("stored.bag_bonus", _where(uid) == "bag" and absf(XDemonCrown.bonus(_item(uid)) - 123.0) < 1e-6, [_where(uid), XDemonCrown.bonus(_item(uid))])


## 修复前（开关关掉）复现，再开开关读修复前的档恢复
func _repro_heal() -> void:
	_new_state(mode == "qifeng")
	XDemonCrown.WAREHOUSE_KEEP = false
	var a := _grant()  # 身上卸下、有成长；存仓库之前存过一份（slot 2）
	_wear(a)
	_win(3)
	_unwear()
	var ua := _uid(a)
	var ba := XDemonCrown.bonus(a)
	var snap_a := _snap(a)
	var c := _grant()  # 先存进仓库再存那份档（slot 2 里它在仓库、账本记了 removed）
	var uc := _uid(c)
	_check("repro.deposit_c", XWarehouse.deposit(s, "armor", c))
	_check("repro.c_marked_removed", _removed(uc) and not _row(uc).has(XDemonCrown.LOST_MARK), _row(uc))
	_check("repro.save_old", kit.save(2))
	_check("repro.deposit_a", XWarehouse.deposit(s, "armor", a))
	_check("repro.a_marked_removed", _removed(ua), _row(ua))
	_check("repro.withdraw", XWarehouse.withdraw(s, "armor", _stored_rec(ua)) and _where(ua) == "bag")
	_check("repro.save_after_withdraw", kit.save(1))
	_check("repro.gone_after_save", _where(ua) == "", _where(ua))  # 玩家现象：取出后一存档就没了
	_check("repro.reload_old", _reload(2))
	_check("repro.old_save_gone", _where(ua) == "", _where(ua))  # 「回档都没用」
	_check("repro.old_save_c_in_wh", _where(uc) == "warehouse", _where(uc))
	_check("repro.c_withdraw", XWarehouse.withdraw(s, "armor", _stored_rec(uc)) and kit.save(3))
	_check("repro.c_gone_after_save", _where(uc) == "", _where(uc))
	# 打开开关（＝装上修复）读修复前存的 slot 2
	XDemonCrown.WAREHOUSE_KEEP = true
	XDemonCrown.forget_ledger()
	XDemonCrown.healed = []
	var before := _ledger_raw()
	_check("heal.no_backup_yet", _backup_raw() == "")
	_check("heal.reload_old", _reload(2))
	_check("heal.backup_made", _backup_raw() == before and before != "", [_backup_raw().length(), before.length()])
	_check("heal.bag_back", _where(ua) == "bag", _where(ua))
	_check("heal.wh_back", _where(uc) == "warehouse", _where(uc))
	_check("heal.not_removed", not _removed(ua) and not _removed(uc), [_row(ua), _row(uc)])
	_check("heal.logged", XDemonCrown.healed.has(ua) and XDemonCrown.healed.has(uc), XDemonCrown.healed)
	if not _item(ua).is_empty():
		_check("heal.identical", _snap(_item(ua)) == snap_a, _diff(snap_a, _snap(_item(ua))))
	_check("heal.wh_withdraw", XWarehouse.withdraw(s, "armor", _stored_rec(uc)))
	_check("heal.persists", kit.save(2) and _reload(2) and _where(ua) == "bag" and _where(uc) == "bag" and not _removed(ua) and not _removed(uc), [_where(ua), _where(uc)])
	_wear(_item(ua))
	_win(1)
	_check("heal.grows", absf(XDemonCrown.bonus(XDemonCrown.gear(_wearer())) - XDemonCrown.next(ba)) < 1e-6, [XDemonCrown.bonus(XDemonCrown.gear(_wearer())), ba])
	# 修复后的档（slot 3、slot 1）里没有它们：不凭空发
	_check("heal.no_conjure", _reload(3) and _where(ua) == "" and _where(uc) == "", [_where(ua), _where(uc)])
	# 备份只备一次：之后账本改了、再读档，备份不变
	_check("heal.backup_once", _reload(2) and _backup_raw() == before and _ledger_raw() != before)


## 修复后真卖掉：读卖之前的档照旧移除（背包、仓库）
func _sold() -> void:
	_new_state(mode == "qifeng")
	var a := _grant()
	var ua := _uid(a)
	_check("sold.save_pre", kit.save(4))
	XItemMarks.sell(s, a)
	_check("sold.marked", _removed(ua) and bool(_row(ua).get(XDemonCrown.LOST_MARK, false)) and _where(ua) == "", [_row(ua), _where(ua)])
	_check("sold.reload_pre", _reload(4))
	_check("sold.bag_removed", _where(ua) == "", _where(ua))
	var c := _grant()
	var uc := _uid(c)
	_check("sold.deposit", XWarehouse.deposit(s, "armor", c))
	var used := XWarehouse.used(s)
	_check("sold.save_wh", kit.save(5))
	_check("sold.withdraw", XWarehouse.withdraw(s, "armor", _stored_rec(uc)))
	XItemMarks.sell(s, _item(uc))
	_check("sold.reload_wh", _reload(5))
	_check("sold.wh_removed", _where(uc) == "" and XWarehouse.used(s) == used - 1, [_where(uc), XWarehouse.used(s), used])
	# 关掉开关：卖出照原版不带标记
	XDemonCrown.WAREHOUSE_KEEP = false
	var d := _grant()
	XItemMarks.sell(s, d)
	_check("sold.switch_off_no_mark", _removed(_uid(d)) and not _row(_uid(d)).has(XDemonCrown.LOST_MARK), _row(_uid(d)))
	XDemonCrown.WAREHOUSE_KEEP = true


## 普通武器、防具存取存读
func _other() -> void:
	_new_state(mode == "qifeng")
	for kind in ["weapon", "armor"]:
		var base := 0
		for rec in XDB.table("Weapons" if kind == "weapon" else "Armors"):
			if rec is Dictionary and str(rec.get("name", "")) != "" and int(rec.get("id", 0)) != XDemonCrown.ARMOR:
				base = int(rec.id)
				break
		s.gain_gear(kind, base, 1)
		var it: Dictionary = s.gear.back()
		var inst := str(it.instanceId)
		var snap := _snap(it)
		_check("other.%s.deposit" % kind, XWarehouse.deposit(s, kind, it))
		var rec2: Dictionary = (XWarehouse.stored(s, kind).filter(func(e): return str(e.rec.get("instanceId", "")) == inst)[0] as Dictionary).rec
		_check("other.%s.withdraw" % kind, XWarehouse.withdraw(s, kind, rec2))
		_check("other.%s.save" % kind, kit.save(1) and _reload(1))
		var back := s.gear.filter(func(e): return str(e.get("instanceId", "")) == inst)
		_check("other.%s.back" % kind, back.size() == 1 and _snap(back[0]) == snap, _diff(snap, _snap(back[0])) if back.size() == 1 else back.size())


func _run() -> void:
	XTianqi.JOIN_GIFTS = false
	kit = Kit.new("xiyou_warehouse_crown")
	XDemonCrown.path_override = ProjectSettings.globalize_path(kit.dir).path_join("crown_progress_test.json")
	print("XTestMode unlocked=%s enabled=%s" % [XTestMode.unlocked(), XTestMode.enabled()])  # 本机开着测试模式时这里是 true，结果作废
	_check("test_mode_off", not XTestMode.unlocked() and not XTestMode.enabled())
	for m in ["xiyou", "qifeng"]:
		mode = m
		_fresh()
		_stored()
		_repro_heal()
		_sold()
		_other()
		_check("mode", XTianqi.active(s) == (m == "qifeng"))
	XDemonCrown.WAREHOUSE_KEEP = true
	XDemonCrown.path_override = ""
	XDemonCrown.forget_ledger()
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
