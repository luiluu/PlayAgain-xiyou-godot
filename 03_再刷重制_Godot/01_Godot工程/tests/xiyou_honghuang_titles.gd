extends Node
## 【cc·T493／T508·未经审查】洪荒三款称号＋兑换码（XHonghuangTitles）专项：
## 1. 称号表：西游档末尾接 51 洪荒证道、52 洪荒首证、53 洪荒·阿夜；天启篇存档、回退开关关着都不列；
##    选项：53 没拿到也照名字列（标阿夜专属、不可获得），选了不变；52、51 没拿到显示 ???；
## 2. 洪荒证道自动解锁：洪荒开关＋层数 34（含老存档）才解锁、只解锁一次；非洪荒、没到 34、天启篇、开关关都不解锁；
##    真地图空闲时自动补发并弹提示；
## 3. 兑换码（T508 不绑存档）：码规范化（小写、空格、横线）后对；同一存档第二次提示已兑换、不再发；
##    本机兑一次后本机所有存档（别的档、新开档、导入档）都有、再输提示已拥有；本机解锁文件封存、不进存档、不进 options.json；
##    拷到别的设备（设备 ID 不同）、改一个字节、换成明文都不认（文件原样）；别的设备输码照样能兑；没有封存密钥时退回记在存档里；
##    设备 ID 取不到、有密钥但写文件失败：不认、不写、提示重试（返修 P1-1／P2-1）；天启档戴着阿夜不显示（P2-3）；
##    T493 只记在存档里的照旧有、再输码补成本机；T493 v1 绑存档哈希作废；错码无效；
##    天启篇、开关关着都不能兑换；兑换后存档往返仍在；和 07_开发环境/洪荒兑换码.py 同一算法（固定测试向量）；
##    仓库配置能读出（只有哈希，不含码原文）；
## 4. 碑前兑换：真地图 Map004 调查洪荒碑 → 选「输入兑换码」→ 输入 → 解锁；再来一次提示已兑换；天启档没有碑；
## 5. 图标 6426～6428 能取到 32 贴图、互不相同；流光样式与颜色随字、随时间变化，画面特效关着停在一帧。
## --capture-only --out=<目录>：带窗口截名牌三款与称号选项图（交付单用）。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
const TIMEOUT_FRAMES := 1200
## 测试码（不是发行码）：与 Python 版算出的固定向量对照
const TEST_CODE := "ABCD-2345-EFGH-6789"
const TEST_HASH := "23938796a9efeedb67a27f17ec2ade9a0f66dccd4d00a5fc3e3fecef1fbfe4a2"
## T493 v1 算法（sha256("honghuang-redeem-v1|码|orb_seed")）算出的旧式哈希：T508 起作废
const TEST_HASH_V1_12345 := "6b7e39a4a4ff30305c506a46b8d61d5915ae5dcd1f8e81a64644121df3523a68"

var results := []
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	if OS.get_cmdline_user_args().has("--capture-only"):
		_capture.call_deferred()
	else:
		_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)
	return ok


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _make_save(tianqi := false, map_id := 4, x := 18, y := 10) -> XState:
	var s := XState.new_game(3, 1, [8, 9, 10])
	s.set_variable(206, -3000)
	s.set_self_switch(4, 20, "A", true)  # 跳过首次到达自动存档事件
	if tianqi:
		s.flags["tianqi"] = {"rules": 1}
	s.map_id = map_id
	s.x = x
	s.y = y
	s.direction = 8
	return s


func _open_map(s: XState) -> XMapScene:
	XState.current = s
	XHonghuangMonument.reload_map()
	var map := XMapScene.new()
	add_child(map)
	for i in TIMEOUT_FRAMES:
		await frames(1)
		if map.player != null and not map.busy and map.map_id == s.map_id:
			break
	await frames(3)
	return map


func _close(map: XMapScene) -> void:
	if is_instance_valid(map):
		map.queue_free()
	await frames(2)


func _inspect(map: XMapScene, answers: Array) -> String:
	var cell := XHonghuangMonument.CELL
	map.player.locate(cell.x, cell.y + 1)
	map.player.direction = 8
	XMessageBox.transcript.clear()
	XMessageBox.auto_answers = answers.duplicate()
	await map._on_action()
	await frames(2)
	return "\n".join(PackedStringArray(XMessageBox.transcript.map(func(v): return str(v))))


func _ids() -> Array:
	return XDesignation.table().map(func(d): return int(d.id))


func _reset_config() -> void:
	var n := XConfig.designations()
	for k in n.keys():
		n.erase(k)


func _run() -> void:
	TestEnv.isolate("xiyou_honghuang_titles")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(XHonghuangTitles.local_path()))  # T508 本机解锁文件从没有开始
	XHonghuangTitles.machine_id_override = ""
	XHonghuangTitles.reload_local()
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	XFest.ENABLED = false
	XFestLobby.ENABLED = false
	XHonghuangMonument.ENABLED = true
	XHonghuangMonument.NAME_OVERRIDE = ""  # 不弹 T460 播报
	XHonghuangTitles.ENABLED = true
	_reset_config()

	# ==== 1. 称号表与选项 ====
	var sx := _make_save()
	XState.current = sx
	var ids := _ids()
	check("table.tail", ids.slice(ids.size() - 3) == [51, 52, 53], ids.slice(ids.size() - 5))
	var rows := XDesignation.table()
	var by := {}
	for d in rows:
		by[int(d.id)] = d
	check("table.names", by[51].name == "洪荒证道" and by[52].name == "洪荒首证" and by[53].name == "洪荒·阿夜", [by[51].name, by[52].name, by[53].name])
	check("table.icons", int(by[51].icon) == 6426 and int(by[52].icon) == 6427 and int(by[53].icon) == 6428, [by[51].icon, by[52].icon, by[53].icon])
	check("table.zhengdao_purple", by[51].color == "#b44dff", by[51].color)
	var used_colors := {}
	for d in rows:
		if not [51, 52, 53].has(int(d.id)):
			used_colors[str(d.color).to_lower()] = true
	for t in XFest.TITLES:
		used_colors[str(t.color).to_lower()] = true
	for q in XQuality.ICI_COLORS.values():
		used_colors["#" + str(q).to_lower()] = true
	check("table.colors_unique", not used_colors.has("#b44dff") and not used_colors.has("#ffb38a") and not used_colors.has("#a9c8ff"), used_colors.keys())
	var labels := XDesignation.choices()
	var idx53 := ids.find(53)
	check("choice.aye_visible_locked", labels[idx53] == "\\I[6428]洪荒·阿夜（阿夜专属，不可获得）", labels[idx53])
	check("choice.shouzheng_hidden", labels[ids.find(52)] == "\\I[0]???", labels[ids.find(52)])
	check("choice.zhengdao_hidden", labels[ids.find(51)] == "\\I[0]???", labels[ids.find(51)])
	sx.designation = {"name": "", "icon": 0, "color": "#ffffff"}
	XDesignation.apply_choice(sx, idx53)
	check("choice.aye_locked_noop", str(sx.designation.name) == "", sx.designation)
	# 天启篇、回退开关
	var st := _make_save(true)
	XState.current = st
	check("tianqi.no_titles", not _ids().has(51) and not _ids().has(52) and not _ids().has(53), _ids().slice(-3))
	XState.current = sx
	XHonghuangTitles.ENABLED = false
	check("off.no_titles", not _ids().has(51) and not _ids().has(53), _ids().slice(-3))
	check("off.no_flow", XHonghuangTitles.flow_style("洪荒首证") == "")
	XHonghuangTitles.ENABLED = true

	# ==== 2. 洪荒证道自动解锁 ====
	_reset_config()
	var sc := _make_save()
	XState.current = sc
	sc.set_variable(20, 34)
	check("clear.not_honghuang", not XHonghuangTitles.check_clear(sc) and not XDesignation.unlocked(51))
	sc.set_switch(2483, true)
	sc.set_variable(20, 33)
	check("clear.floor33_not_yet", not XHonghuangTitles.check_clear(sc) and not XDesignation.unlocked(51))
	var stq := _make_save(true)
	stq.set_switch(2483, true)
	stq.set_variable(20, 34)
	check("clear.tianqi_never", not XHonghuangTitles.check_clear(stq) and not XDesignation.unlocked(51))
	XHonghuangTitles.ENABLED = false
	sc.set_variable(20, 34)
	check("clear.off_never", not XHonghuangTitles.check_clear(sc) and not XDesignation.unlocked(51))
	XHonghuangTitles.ENABLED = true
	XState.current = sc  # XState.new_game 会把当前存档换成新建的那份
	check("clear.unlock", XHonghuangTitles.check_clear(sc) and XDesignation.unlocked(51))
	check("clear.once", not XHonghuangTitles.check_clear(sc))
	check("clear.choice_named", XDesignation.choices()[_ids().find(51)] == "\\I[6426]洪荒证道", [XDesignation.choices()[_ids().find(51)], XDesignation.unlocked(51), XConfig.designations()])
	# 老存档补发：洪荒 2463（补强）开着、已在 34 层的存档读进来，真地图空闲时补发并弹提示
	_reset_config()
	var sold := _make_save()
	sold.set_switch(2463, true)
	sold.set_variable(20, 34)
	var old_back := XState.from_dict(JSON.parse_string(JSON.stringify(sold.to_dict())))
	var map_old := await _open_map(old_back)
	for i in 90:
		await frames(1)
		if XDesignation.unlocked(51):
			break
	check("clear.old_save_backfill_on_map", XDesignation.unlocked(51))
	check("clear.toast", map_old.toasts.any(func(t): return str(t).contains("洪荒证道")), map_old.toasts.slice(-3))
	await _close(map_old)

	# ==== 3. 兑换码 ====
	check("hash.matches_python_tool", XHonghuangTitles.code_hash(TEST_CODE) == TEST_HASH, XHonghuangTitles.code_hash(TEST_CODE))
	check("hash.normalize", XHonghuangTitles.normalize(" abcd-2345 efgh_6789 ") == "ABCD2345EFGH6789")
	XHonghuangTitles.codes_override = null
	XHonghuangTitles._codes = null
	var file_codes := XHonghuangTitles.codes()
	check("config.loaded_hash_only", file_codes.size() >= 1 and file_codes.all(func(e): return str(e.hash).length() == 64 and e.titles is Array and not e.has("code")), file_codes.size())
	var raw_cfg := FileAccess.get_file_as_string(XHonghuangTitles.CODES_PATH)
	check("config.no_plain_code", not RegEx.create_from_string("[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}").search(raw_cfg))

	var sa := _make_save()
	sa.orb_seed = 12345
	var sb := _make_save()
	sb.orb_seed = 67890
	# T493 v1 绑存档的旧哈希作废：配置里只有旧式条目时，原存档（同 orb_seed）输入旧码也不对
	XHonghuangTitles.codes_override = [{"hash": TEST_HASH_V1_12345, "titles": [52, 53]}]
	XState.current = sa
	var rv1 := XHonghuangTitles.redeem(sa, TEST_CODE)
	check("redeem.v1_retired", not rv1.ok and rv1.text == XHonghuangTitles.MSG_INVALID and not sa.flags.has(XHonghuangTitles.FLAG_KEY), rv1)
	XHonghuangTitles.codes_override = [{"hash": XHonghuangTitles.code_hash(TEST_CODE), "titles": [52, 53]}]
	var rbad := XHonghuangTitles.redeem(sa, "ABCD-2345-EFGH-6780")
	check("redeem.wrong_code", not rbad.ok and rbad.text == XHonghuangTitles.MSG_INVALID, rbad)
	check("redeem.empty", not XHonghuangTitles.redeem(sa, "  ").ok)
	var stq2 := _make_save(true)
	stq2.orb_seed = 12345
	var rt := XHonghuangTitles.redeem(stq2, TEST_CODE)
	check("redeem.tianqi_unavailable", not rt.ok and rt.text == XHonghuangTitles.MSG_UNAVAILABLE and not stq2.flags.has(XHonghuangTitles.FLAG_KEY), rt)
	XHonghuangTitles.ENABLED = false
	var roff := XHonghuangTitles.redeem(sa, TEST_CODE)
	check("redeem.off_unavailable", not roff.ok and not sa.flags.has(XHonghuangTitles.FLAG_KEY), roff)
	XHonghuangTitles.ENABLED = true
	XState.current = sa
	check("local.none_before", not FileAccess.file_exists(XHonghuangTitles.local_path()) and not XDesignation.unlocked(52))
	var ra := XHonghuangTitles.redeem(sa, " abcd 2345-efgh 6789 ")
	check("redeem.ok", ra.ok and ra.titles == [52, 53] and str(ra.text).contains("洪荒首证、洪荒·阿夜"), ra)
	check("redeem.unlocked_here", XDesignation.unlocked(52) and XDesignation.unlocked(53), [XDesignation.unlocked(52), XDesignation.unlocked(53), XState.current == sa])
	check("redeem.not_global", XConfig.designations().get("52") != true and XConfig.designations().get("53") != true)
	# 本机解锁文件：封存格式（不是明文），存档里不记
	var lp := XHonghuangTitles.local_path()
	var lbytes := FileAccess.get_file_as_bytes(lp)
	check("local.file_sealed", FileAccess.file_exists(lp) and XSaveSeal.is_sealed(lbytes) and not lbytes.get_string_from_utf8().contains("\"titles\""), lbytes.size())
	check("local.not_in_save", not sa.flags.has(XHonghuangTitles.FLAG_KEY))
	var ra2 := XHonghuangTitles.redeem(sa, TEST_CODE)
	check("redeem.second_use", not ra2.ok and ra2.text == XHonghuangTitles.MSG_USED and ra2.titles.is_empty(), ra2)
	# 本机别的存档、新开档：不输码就有，再输提示已拥有
	XState.current = sb
	check("local.other_save_has", XDesignation.unlocked(52) and XDesignation.unlocked(53))
	check("local.other_save_used", XHonghuangTitles.redeem(sb, TEST_CODE).text == XHonghuangTitles.MSG_USED)
	var sn := XState.new_game(3, 1, [8, 9, 10])
	XState.current = sn
	check("local.newgame_has", int(sn.orb_seed) != 12345 and not sn.flags.has(XHonghuangTitles.FLAG_KEY) and XDesignation.unlocked(52) and XDesignation.unlocked(53))
	XDesignation.apply_choice(sn, _ids().find(53))
	check("local.newgame_wear", sn.designation.name == "洪荒·阿夜" and XHonghuangTitles.worn_ok(sn), sn.designation)
	# 天启篇存档、回退开关关着：不列、不显示（本机文件原样留着）
	var stq3 := _make_save(true)
	XState.current = stq3
	check("local.tianqi_none", not XHonghuangTitles.save_has(stq3, 52) and not _ids().has(52))
	# 返修 P2-3：天启档带着阿夜佩戴记录，本机解锁也不让它显示
	stq3.designation = {"name": "洪荒·阿夜", "icon": 6428, "color": "#a9c8ff"}
	check("local.tianqi_worn_hidden", XHonghuangTitles.local_has(53) and not XHonghuangTitles.worn_ok(stq3))
	XState.current = sn
	XHonghuangTitles.ENABLED = false
	check("local.off_none", not XHonghuangTitles.save_has(sn, 52) and not XHonghuangTitles.worn_ok(sn) and FileAccess.file_exists(lp))
	XHonghuangTitles.ENABLED = true
	check("local.on_again", XHonghuangTitles.save_has(sn, 52))
	# options.json 里手写 52／53 不算数
	XConfig.designations()["52"] = true
	XConfig.designations()["53"] = true
	var good_bytes := lbytes.duplicate()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lp))
	XHonghuangTitles.reload_local()
	check("local.options_forged_ignored", not XDesignation.unlocked(52) and not XDesignation.unlocked(53))
	XConfig.designations().erase("52")
	XConfig.designations().erase("53")
	# 换一台设备：把本机文件原样拷过去（设备 ID 不同）→ 不认；不带码没有；输码照样能兑（码不绑设备）
	_put_local(good_bytes)
	XHonghuangTitles.machine_id_override = "other-device-for-test"
	XHonghuangTitles.reload_local()
	check("device.copied_file_ignored", not XDesignation.unlocked(52) and not XDesignation.unlocked(53) and not XHonghuangTitles.worn_ok(sn))
	check("device.file_untouched", FileAccess.get_file_as_bytes(lp) == good_bytes)
	var rdev := XHonghuangTitles.redeem(sn, TEST_CODE)
	check("device.redeem_ok", rdev.ok and XDesignation.unlocked(52) and XDesignation.unlocked(53), rdev)
	XHonghuangTitles.machine_id_override = ""
	_put_local(good_bytes)
	XHonghuangTitles.reload_local()
	check("device.back_home", XDesignation.unlocked(52) and XDesignation.unlocked(53))
	# 热修 P1-1：已有缓存时标识变空（不手动 reload）→ 立刻不认，正确码提示重试；恢复后（不手动 reload）原解锁照认
	XHonghuangTitles.machine_id_missing = true
	check("noid.cache_dropped_on_empty", not XDesignation.unlocked(52) and not XDesignation.unlocked(53) and not XHonghuangTitles.worn_ok(sn)
		and XHonghuangTitles.redeem(sn, TEST_CODE).text == XHonghuangTitles.MSG_RETRY and FileAccess.get_file_as_bytes(lp) == good_bytes)
	XHonghuangTitles.machine_id_missing = false
	check("noid.cache_restored", XDesignation.unlocked(52) and XDesignation.unlocked(53) and XHonghuangTitles.worn_ok(sn))
	# 返修 P1-1：设备 ID 取不到 → 已有文件不认；兑换提示稍后重试，什么都不写、不记存档
	XHonghuangTitles.machine_id_missing = true
	XHonghuangTitles.reload_local()
	check("noid.file_ignored", XHonghuangTitles.machine_tag() == "" and not XDesignation.unlocked(52) and not XDesignation.unlocked(53))
	var snid := _make_save()
	XState.current = snid
	var rnid := XHonghuangTitles.redeem(snid, TEST_CODE)
	check("noid.retry", not rnid.ok and rnid.text == XHonghuangTitles.MSG_RETRY and not snid.flags.has(XHonghuangTitles.FLAG_KEY)
		and FileAccess.get_file_as_bytes(lp) == good_bytes and not XDesignation.unlocked(52), rnid)
	XHonghuangTitles.machine_id_missing = false
	XHonghuangTitles.reload_local()
	XState.current = sn
	# 返修 P2-1：有密钥但写文件失败 → 兑换没完成、什么都不改、提示重试；恢复后重试能成
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lp))
	XHonghuangTitles.reload_local()
	XHonghuangTitles.write_fail_for_test = true
	var rwf := XHonghuangTitles.redeem(sn, TEST_CODE)
	check("writefail.retry", not rwf.ok and rwf.text == XHonghuangTitles.MSG_RETRY and not sn.flags.has(XHonghuangTitles.FLAG_KEY)
		and not FileAccess.file_exists(lp) and not XDesignation.unlocked(52), rwf)
	XHonghuangTitles.write_fail_for_test = false
	var rwf2 := XHonghuangTitles.redeem(sn, TEST_CODE)
	check("writefail.retry_ok", rwf2.ok and XHonghuangTitles.local_has(52) and XHonghuangTitles.local_has(53), rwf2)
	good_bytes = FileAccess.get_file_as_bytes(lp)
	XState.current = sn
	# 篡改：改一个字节（签名不对）、换成明文 → 不认，文件原样，存档照常
	var bad := good_bytes.duplicate()
	bad[bad.size() / 2] = (int(bad[bad.size() / 2]) + 1) % 256
	_put_local(bad)
	XHonghuangTitles.reload_local()
	check("tamper.byte_flip_ignored", not XDesignation.unlocked(52) and not XDesignation.unlocked(53) and FileAccess.get_file_as_bytes(lp) == bad)
	_put_local(JSON.stringify({"titles": {"52": true, "53": true}, "used": [], "machine": XHonghuangTitles.machine_tag()}).to_utf8_buffer())
	XHonghuangTitles.reload_local()
	check("tamper.plain_ignored", not XDesignation.unlocked(52) and not XDesignation.unlocked(53))
	# 空设备标记的合法封存文件（别的取不到 ID 的设备写的）：本机取不到 ID 时也不认
	_put_local(XSaveSeal.seal(JSON.stringify({"titles": {"52": true, "53": true}, "used": [], "machine": ""})))
	XHonghuangTitles.machine_id_missing = true
	XHonghuangTitles.reload_local()
	check("noid.empty_tag_file_ignored", not XDesignation.unlocked(52) and not XDesignation.unlocked(53))
	XHonghuangTitles.machine_id_missing = false
	XHonghuangTitles.reload_local()
	check("tamper.save_fine", XHonghuangTitles.worn_ok(XState.from_dict(JSON.parse_string(JSON.stringify(sa.to_dict())))))
	# 没有封存密钥（发行构建没注入密钥）：本机文件写不了 → 退回记在当前存档里（这份存档一次）
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lp))
	XSaveSeal.simulate_template = true
	XSaveSeal.reload_keys()
	XHonghuangTitles.reload_local()
	var snk := _make_save()
	XState.current = snk
	var rk := XHonghuangTitles.redeem(snk, TEST_CODE)
	check("nokey.fallback_save", rk.ok and rk.text == XHonghuangTitles.MSG_OK_SAVE % "洪荒首证、洪荒·阿夜" and XHonghuangTitles._flag_has(snk.flags, 52) and XHonghuangTitles._flag_has(snk.flags, 53) and not FileAccess.file_exists(lp), rk)
	check("nokey.second_use", XHonghuangTitles.redeem(snk, TEST_CODE).text == XHonghuangTitles.MSG_USED_SAVE)
	XSaveSeal.simulate_template = false
	XSaveSeal.reload_keys()
	# T493 只兑在存档里的老存档：照旧有；再输新码补成本机拥有
	check("legacy.save_flag_still_ok", XDesignation.unlocked(52) and XHonghuangTitles.worn_ok(snk))
	var rl := XHonghuangTitles.redeem(snk, TEST_CODE)
	check("legacy.upgrade_to_local", rl.ok and XHonghuangTitles.local_has(52) and XHonghuangTitles.local_has(53), rl)
	# 佩戴：兑换的存档能选 53，选项变成带图标的名字
	XState.current = sa
	var ids_a := _ids()
	check("wear.choice_named", XDesignation.choices()[ids_a.find(53)] == "\\I[6428]洪荒·阿夜", XDesignation.choices()[ids_a.find(53)])
	XDesignation.apply_choice(sa, ids_a.find(53))
	check("wear.aye", sa.designation.name == "洪荒·阿夜" and int(sa.designation.icon) == 6428, sa.designation)
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(sa.to_dict())))
	XState.current = back
	check("save.roundtrip", int(back.orb_seed) == 12345 and XDesignation.unlocked(52) and XDesignation.unlocked(53) and back.designation.name == "洪荒·阿夜", [back.orb_seed, back.designation])
	check("save.roundtrip_still_once", XHonghuangTitles.redeem(back, TEST_CODE).text == XHonghuangTitles.MSG_USED)
	# 封存／明文导入：用 T493 式记在存档里的档（同时戴着阿夜），在「别的设备」上测（本机解锁不掺进来）
	var legacy := XState.from_dict(JSON.parse_string(JSON.stringify(back.to_dict())))
	legacy.flags[XHonghuangTitles.FLAG_KEY] = {"titles": {"52": true, "53": true}, "used": [TEST_HASH]}
	XHonghuangTitles.machine_id_override = "other-device-for-test"
	XHonghuangTitles.reload_local()
	_unsealed_vs_sealed(legacy)
	XHonghuangTitles.machine_id_override = ""
	XHonghuangTitles.reload_local()
	# 导入档（本机）：没兑过的存档封存导出再导入 → 本机解锁，不输码就有
	_imported_has_local()

	# 碑前兑换要从「本机没有」开始
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lp))
	XHonghuangTitles.reload_local()

	# ==== 4. 碑前兑换（真地图）====
	var sm := _make_save()
	sm.orb_seed = 12345
	var map := await _open_map(sm)
	var t1 := await _inspect(map, [0, TEST_CODE])
	check("monument.redeem_ok", XDesignation.unlocked(52) and XDesignation.unlocked(53) and t1.contains("兑换成功"), t1)
	var t2 := await _inspect(map, [0, TEST_CODE])
	check("monument.redeem_used", t2.contains(XHonghuangTitles.MSG_USED), t2)
	var t3 := await _inspect(map, [1])
	check("monument.leave", not t3.contains("兑换"), t3)
	await _close(map)
	var smt := _make_save(true)
	smt.orb_seed = 12345
	var map_t := await _open_map(smt)
	var tt := await _inspect(map_t, [0, TEST_CODE])
	check("monument.tianqi_none", not smt.flags.has(XHonghuangTitles.FLAG_KEY) and not tt.contains("兑换"), tt)
	await _close(map_t)
	XHonghuangTitles.codes_override = null

	# ==== 5. 图标与流光 ====
	var seen := {}
	for id in [6426, 6427, 6428]:
		var tex := XUI.icon_texture(id)
		if tex != null and tex.get_width() == 32 and tex.get_height() == 32:
			seen[tex.get_image().get_data().hex_encode().sha256_text()] = id
	check("icon.three_distinct_32", seen.size() == 3, seen.values())
	check("flow.styles", XHonghuangTitles.flow_style("洪荒首证") == XHonghuangTitles.FLOW_DAWN and XHonghuangTitles.flow_style("洪荒·阿夜") == XHonghuangTitles.FLOW_NIGHT
		and XHonghuangTitles.flow_style("洪荒证道") == "" and XHonghuangTitles.flow_style("征服者") == "")
	var d0 := XHonghuangTitles.flow_color(XHonghuangTitles.FLOW_DAWN, 0, 4, 0.0)
	check("flow.dawn_moves", not d0.is_equal_approx(XHonghuangTitles.flow_color(XHonghuangTitles.FLOW_DAWN, 0, 4, 0.7))
		and not d0.is_equal_approx(XHonghuangTitles.flow_color(XHonghuangTitles.FLOW_DAWN, 3, 4, 0.0)))
	var n0 := XHonghuangTitles.flow_color(XHonghuangTitles.FLOW_NIGHT, 0, 5, 0.0)
	check("flow.night_moves", not n0.is_equal_approx(XHonghuangTitles.flow_color(XHonghuangTitles.FLOW_NIGHT, 0, 5, 1.3)))
	check("flow.dawn_glow_outline", XHonghuangTitles.flow_outline(XHonghuangTitles.FLOW_DAWN, 0.0) is Color and XHonghuangTitles.flow_outline(XHonghuangTitles.FLOW_NIGHT, 0.0) == null)
	var fx_was := XConfig.flag("codexScreenFx")
	XConfig._values["codexScreenFx"] = false
	check("flow.fx_off_frozen", XDesignationPlate.flow_time() == 0.0)
	XConfig._values["codexScreenFx"] = fx_was

	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=", JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


# ---- 截图（交付单用）----

## 玩家头顶名牌那一块（180×110，按名牌画布在屏幕上的位置裁）放大 3 倍
## 返修 P1-1：封存开着时，封存格式导出再导入完整保留 52／53；没签名的明文导入、补签旧明文档都去掉 52／53 记号和佩戴；
## 展示侧戴着 52／53 却没记号的不显示。back：已兑换 52／53、戴着洪荒·阿夜的存档。
func _unsealed_vs_sealed(back: XState) -> void:
	var old_seal := XSaveSeal.ENABLED
	var old_dir := XSave.dir_override
	var dir := OS.get_user_data_dir().path_join("test_honghuang_seal_%d" % OS.get_process_id())
	for sub in ["", "mig"]:
		var dd := dir.path_join(sub)
		if DirAccess.dir_exists_absolute(dd):
			for f in DirAccess.get_files_at(dd):
				DirAccess.remove_absolute(dd.path_join(f))
	DirAccess.make_dir_recursive_absolute(dir.path_join("mig"))
	XSave.dir_override = dir
	XSaveSeal.ENABLED = true
	XSaveSeal.key_file_override = ""
	XSaveSeal.reload_keys()
	XSaveSeal.forget_dirs()
	check("seal.active", XSaveSeal.active_now())
	# 封存档：存进第 7 格、导出（封存格式）、再导入 → 52／53 与佩戴都在
	XState.current = back
	XSave.save(7)
	var ex := XSaveTransfer.export_text(7)
	check("seal.export_sealed", str(ex.get("text", "")).contains(XSaveTransfer.FORMAT_SEALED), ex.keys())
	var imp_sealed := XSaveTransfer.parse_import(str(ex.get("text", "")))
	var ds = imp_sealed.get("data", {})
	check("seal.sealed_import_keeps", ds is Dictionary and XHonghuangTitles._flag_has(ds.get("flags"), 52) and XHonghuangTitles._flag_has(ds.get("flags"), 53)
		and str(ds.get("designation", {}).get("name", "")) == "洪荒·阿夜", imp_sealed.get("error", ""))
	# 明文导入（旧 v1 明文导出格式、直接一份明文存档）：同样内容 → 记号删掉、佩戴清空
	var forged: Dictionary = JSON.parse_string(JSON.stringify(back.to_dict()))  # 深拷贝：to_dict 的 flags 是同一个字典
	for text in [JSON.stringify({"format": XSaveTransfer.FORMAT, "game": XSaveTransfer.GAME, "slot": 1, "data": forged}), JSON.stringify(forged)]:
		var r := XSaveTransfer.parse_import(text)
		var d = r.get("data", {})
		check("seal.plain_import_stripped", d is Dictionary and not (d.get("flags", {}) as Dictionary).has(XHonghuangTitles.FLAG_KEY)
			and str(d.get("designation", {}).get("name", "")) == "", [r.get("error", ""), d.get("designation") if d is Dictionary else null])
	# 只改佩戴（不带记号）也清
	var only_wear: Dictionary = JSON.parse_string(JSON.stringify(back.to_dict()))  # 深拷贝：to_dict 的 flags 是同一个字典
	(only_wear.flags as Dictionary).erase(XHonghuangTitles.FLAG_KEY)
	var rw := XSaveTransfer.parse_import(JSON.stringify(only_wear))
	check("seal.plain_wear_only_stripped", str(rw.get("data", {}).get("designation", {}).get("name", "")) == "", rw.get("error", ""))
	# 别的称号不动
	var other: Dictionary = JSON.parse_string(JSON.stringify(back.to_dict()))  # 深拷贝：to_dict 的 flags 是同一个字典
	(other.flags as Dictionary).erase(XHonghuangTitles.FLAG_KEY)
	other["designation"] = {"name": "洪荒证道", "icon": 6426, "color": "#b44dff"}
	var ro := XSaveTransfer.parse_import(JSON.stringify(other))
	check("seal.plain_other_title_kept", str(ro.get("data", {}).get("designation", {}).get("name", "")) == "洪荒证道", ro.get("error", ""))
	# 补签：目录里留一份明文 save_3.json（带伪造记号），迁移后 .ksv 里没有
	var mig := dir.path_join("mig")
	var f := FileAccess.open(mig.path_join("save_3.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(forged))
	f.close()
	check("seal.migrate_done", XSaveSeal.ensure_dir(mig), XSaveSeal.last_migration)
	var ur := XSaveSeal.unseal(FileAccess.get_file_as_bytes(mig.path_join("save_3" + XSaveSeal.EXT)))
	var md = JSON.parse_string(str(ur.get("text", ""))) if ur.ok else null
	check("seal.migrate_stripped", md is Dictionary and not (md.get("flags", {}) as Dictionary).has(XHonghuangTitles.FLAG_KEY)
		and str(md.get("designation", {}).get("name", "")) == "", ur.ok)
	# 封存关着（开发版、回退）：明文导入原样（明文本来就能改，不清）
	XSaveSeal.ENABLED = false
	var rp := XSaveTransfer.parse_import(JSON.stringify(forged))
	check("seal.off_plain_untouched", XHonghuangTitles._flag_has(rp.get("data", {}).get("flags"), 53))
	XSaveSeal.ENABLED = old_seal
	XSaveSeal.reload_keys()
	XSaveSeal.forget_dirs()
	XSave.dir_override = old_dir
	for sub in ["mig", ""]:
		var dd := dir.path_join(sub)
		for fn in DirAccess.get_files_at(dd):
			DirAccess.remove_absolute(dd.path_join(fn))
		DirAccess.remove_absolute(dd)
	# 展示侧：戴着洪荒·阿夜却没记号 → 不算数（名牌、侧栏不显示）；有记号、别的称号照常
	var sf := XState.from_dict(JSON.parse_string(JSON.stringify(back.to_dict())))
	check("worn.legit_ok", XHonghuangTitles.worn_ok(sf))
	sf.flags.erase(XHonghuangTitles.FLAG_KEY)
	check("worn.forged_hidden", not XHonghuangTitles.worn_ok(sf))
	sf.designation = {"name": "洪荒证道", "icon": 6426, "color": "#b44dff"}
	check("worn.other_ok", XHonghuangTitles.worn_ok(sf))
	XState.current = back


func _put_local(bytes: PackedByteArray) -> void:
	var f := FileAccess.open(XHonghuangTitles.local_path(), FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


## T508 导入档：本机已兑过，一份没兑过的存档封存导出再导入 → 不输码就有，再输提示已拥有
func _imported_has_local() -> void:
	var old_seal := XSaveSeal.ENABLED
	XSaveSeal.ENABLED = true
	var fresh := _make_save()
	fresh.orb_seed = 24680
	XState.current = fresh
	XSave.save(8)
	var ex8 := XSaveTransfer.export_text(8)
	var imp8 := XSaveTransfer.parse_import(str(ex8.get("text", "")))
	var d8 = imp8.get("data", {})
	check("import.fresh_sealed", str(ex8.get("text", "")).contains(XSaveTransfer.FORMAT_SEALED) and d8 is Dictionary and not (d8.get("flags", {}) as Dictionary).has(XHonghuangTitles.FLAG_KEY), imp8.get("error", ""))
	if d8 is Dictionary:
		var imp := XState.from_dict(JSON.parse_string(JSON.stringify(d8)))
		XState.current = imp
		check("import.local_has", XDesignation.unlocked(52) and XDesignation.unlocked(53))
		check("import.used", XHonghuangTitles.redeem(imp, TEST_CODE).text == XHonghuangTitles.MSG_USED)
	XSave.remove(8)
	XSaveSeal.ENABLED = old_seal


func _plate_crop(map: XMapScene) -> Image:
	RenderingServer.force_draw()
	var img := get_viewport().get_texture().get_image()
	var xf := map.player_plate.get_global_transform_with_canvas()
	var area := Rect2i(Vector2i(xf.origin) - Vector2i(0, 4), Vector2i(roundi(180 * xf.get_scale().x), roundi(100 * xf.get_scale().y))).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(area)
	crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
	return crop


func _save_strip(tiles: Array[Image], filename: String) -> void:
	if out_dir == "" or tiles.is_empty():
		return
	var w := 0
	var h := 0
	for t in tiles:
		w += t.get_width() + 6
		h = maxi(h, t.get_height())
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.1, 0.1, 0.1))
	var x := 0
	for t in tiles:
		t.convert(Image.FORMAT_RGBA8)
		out.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i(x, 0))
		x += t.get_width() + 6
	DirAccess.make_dir_recursive_absolute(out_dir)
	out.save_png(out_dir.path_join(filename))


func shot(filename: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(filename))


func _quiet(map: XMapScene) -> void:
	var toast_layer := get_tree().root.get_node_or_null("XToast")
	if toast_layer != null:
		toast_layer.visible = false
	if is_instance_valid(map.difficulty_notice):
		map.difficulty_notice.visible = false


func _capture() -> void:
	TestEnv.isolate("xiyou_honghuang_titles_shots")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(XHonghuangTitles.local_path()))
	XHonghuangTitles.reload_local()
	XMessageBox.auto = true
	XGuide.MILESTONE_ENABLED = false
	XFest.ENABLED = false
	XFestLobby.ENABLED = false
	XHonghuangMonument.NAME_OVERRIDE = ""
	XConfig._values["codexScreenFx"] = true
	XDesignation.unlock(51)
	var s := _make_save(false, 4, 15, 12)
	s.direction = 2
	s.flags[XHonghuangTitles.FLAG_KEY] = {"titles": {"52": true, "53": true}, "used": []}
	s.actor_name = "玩家名"
	var map := await _open_map(s)
	_quiet(map)
	# 名牌三款（旧界面、新界面各一张拼图：每款裁玩家头顶一块、放大 3 倍；流光两款各取两帧）
	for skin in [false, true]:
		XUiSkin.FORCE = skin
		var tiles: Array[Image] = []
		for t in XHonghuangTitles.TITLES:
			s.designation = {"name": t.name, "icon": t.icon, "color": t.color}
			for k in (2 if t.has("flow") else 1):
				await frames(24)
				tiles.append(_plate_crop(map))
		await _save_strip(tiles, "t493_plates_%s.png" % ("new_skin" if skin else "old_skin"))
	XUiSkin.FORCE = false
	# 称号选项（别的存档看到的样子：阿夜专属不可获得）
	var s2 := _make_save(false, 4, 15, 12)
	s2.direction = 2
	await _close(map)
	var map2 := await _open_map(s2)
	_quiet(map2)
	XMessageBox.auto = false
	var list := [{"code": 101, "indent": 0, "parameters": ["", 0, 0, 2]}, {"code": 401, "indent": 0, "parameters": [XDesignation.show_text()]},
		{"code": 102, "indent": 0, "parameters": [XDesignation.choices(), -2, _ids().find(53), 1, 0]}, {"code": 0, "indent": 0, "parameters": []}]
	var sub := MVInterpreter.new(map2, 4, 0, list)
	sub.run()  # 默认选中 53，列表滚到最后（洪荒三款在末尾）
	await frames(40)
	await shot("t493_choice_list_other_save.png")
	get_tree().quit(0)
