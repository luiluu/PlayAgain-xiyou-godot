extends Node
## 【cc·悟空·未经审查】v0.62.12 停用／隐藏角色：installImportedBalanceRuntime B.migrateParty（读档把停用角色挪出队伍与出战栏）、
## installIntegratedV029Runtime 隐藏 7 名（141、146、152、157、160、161、166）在角色仓库列表与人物图鉴目录里不出现。
## 出战栏：原版量具 actor_sv_real.cjs 设 _actors=[id] → initializeBattleMembers 后 141／146／152／161／166 不在出战栏（被 migrateParty 挪走），
## 重制 add_actor 拦停用角色，两边一致。开关 XImportedBalance.V029_HIDE_ACTORS（O-299）开、关各一组。
## 解放苍龙破晓（XImportedBalance.RELEASE_CANGLONG，O-待定·解放苍龙）会让 146 不停用、不隐藏：按原版比的这一段先关掉它，末尾开着再查一次（细项在 xiyou_rift2_canglong）。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _state(party: Array, slots: Array, saved: Array) -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	s.party.assign(party)
	s.battle_slots = slots.duplicate()
	s.saved_actors.assign(saved)
	for id in party + saved:
		s.actor(int(id))
	return s


func _run() -> void:
	XImportedBalance.RELEASE_CANGLONG = false
	check("hidden_list", XImportedBalance.HIDDEN_ACTORS == [141, 146, 152, 157, 160, 161, 166])
	check("hidden_all_disabled", XImportedBalance.HIDDEN_ACTORS.all(func(id): return XImportedBalance.DISABLED_ACTORS.has(id)))
	# 出战栏：add_actor 拦停用角色（同原版 migrateParty 挪走）
	for id in [141, 146, 152, 161, 166]:
		var s := XState.new_game_blank()
		s.party.clear()
		s.battle_slots.clear()
		s.add_actor(id)
		check("join_blocked.%d" % id, not s.party.has(id) and not s.battle_slots.has(id), [s.party, s.battle_slots])
	# migrateParty：停用的挪进仓库末尾，出战栏清 0
	var s := _state([1, 141, 143, 8], [1, 141, 143, 8, 0], [9])
	check("migrate.changed", XImportedBalance.migrate_party(s))
	check("migrate.party", s.party == [1, 8], s.party)
	check("migrate.saved", s.saved_actors == [9, 141, 143], s.saved_actors)
	check("migrate.slots", s.battle_slots == [1, 0, 0, 8, 0], s.battle_slots)
	check("migrate.again_noop", not XImportedBalance.migrate_party(s))
	# 队伍全是停用的：从仓库补第一名可用的（拿出仓库），出战栏全空放队伍第一名
	s = _state([146], [146, 0, 0, 0, 0], [157, 9, 10])
	XImportedBalance.migrate_party(s)
	check("migrate.replace_stored", s.party == [9] and s.saved_actors == [157, 10, 146], [s.party, s.saved_actors])
	check("migrate.first_slot", s.battle_slots == [9, 0, 0, 0, 0], s.battle_slots)
	s = _state([146], [146, 0, 0, 0, 0], [])
	XImportedBalance.migrate_party(s)
	check("migrate.replace_actor1", s.party == [1] and s.saved_actors == [146], [s.party, s.saved_actors])
	# 读档走一遍
	s = _state([1, 161], [1, 161, 0, 0, 0], [])
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check("load.migrated", back.party == [1] and back.saved_actors == [161] and not back.battle_slots.has(161), [back.party, back.saved_actors, back.battle_slots])
	# 仓库列表：开关开时隐藏 7 名不出现（编号仍在仓库里），取出按编号取
	s = _state([1, 8], [1, 8, 0, 0, 0], [141, 9, 143, 160, 10])
	check("on.list", XActorWarehouse.list(s, false) == [9, 143, 10], XActorWarehouse.list(s, false))
	check("on.kept", s.saved_actors == [141, 9, 143, 160, 10], s.saved_actors)
	check("on.withdraw_by_id", XActorWarehouse.withdraw(s, 0) == "ok" and s.party == [1, 8, 9] and s.saved_actors == [141, 143, 160, 10], [s.party, s.saved_actors])
	check("on.withdraw_disabled", XActorWarehouse.withdraw(s, 0) == "disabled", XActorWarehouse.list(s, false))
	XImportedBalance.V029_HIDE_ACTORS = false
	check("off.list", XActorWarehouse.list(s, false) == [141, 143, 160, 10], XActorWarehouse.list(s, false))
	check("off.not_hidden", not XImportedBalance.is_hidden_actor(141))
	check("off.book_all_slots", XActorBook.index_ids().size() == (XDB.table("Actors") as Array).size())
	XImportedBalance.V029_HIDE_ACTORS = true
	check("on.book_rows", XActorBook.index_ids().size() == (XDB.table("Actors") as Array).size() - 7 and not XActorBook.index_ids().has(161))
	XImportedBalance.RELEASE_CANGLONG = true
	check("release.book_rows", XActorBook.index_ids().size() == (XDB.table("Actors") as Array).size() - 6 and XActorBook.index_ids().has(146))
	s = _state([1, 8], [1, 8, 0, 0, 0], [146, 141])
	check("release.list", XActorWarehouse.list(s, false) == [146], XActorWarehouse.list(s, false))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
