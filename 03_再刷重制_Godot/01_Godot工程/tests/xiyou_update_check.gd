extends Node
## 自动更新第①批：版本清单验签与判断（XUpdateCheck）、读清单（XUpdateClient，用假的 fetcher，不联网）、检查更新页（XUpdatePage）。
## 只写 user://_test_update_check/，跑完删掉。

const DIR := "user://_test_update_check"
var results: Array = []
var _served := {}   # url → 字节
var _asked: Array = []

func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)

func _check(name: String, ok: bool) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL " + name)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _fake_fetch(url: String) -> PackedByteArray:
	_asked.append(url)
	await get_tree().process_frame
	return _served.get(url, PackedByteArray())

func _manifest(code: int, base: int, patch_code := 0, extra := {}) -> Dictionary:
	var d := {"schema": 1, "latest": {"version": "0.%d" % code, "code": code, "date": "2026-11-20", "notes": ["修了一处", "加了一处"]},
		"bases": {}, "min_base": 0, "revoked": []}
	if patch_code > 0:
		d["bases"][str(base)] = {"patch": {"code": patch_code, "size": 2500000, "sha256": "ab".repeat(32), "urls": ["https://example.invalid/p.pck"]}}
	d.merge(extra, true)
	return d

func _sign(key: CryptoKey, raw: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(raw)
	return Crypto.new().sign(HashingContext.HASH_SHA256, ctx.finish(), key)

func _cleanup() -> void:
	var da := DirAccess.open(DIR)
	if da:
		for n in da.get_files():
			da.remove(n)
		DirAccess.remove_absolute(DIR)

func _run() -> void:
	# 出整包后 build_info 的 releaseVersion 有值（v0.01），检查更新页会把版本号显示成 0.01.N；这里只测按编号的写法，
	# 先占住 release_base，免得 XUpdateClient.init_versions 读进 build_info（发行版本名另有一段专门测）
	XUpdateCheck.release_name = ""
	XUpdateCheck.release_base = 1
	_cleanup()
	var C := XUpdateCheck
	# 版本号按段比
	_check("0.62.12 < 0.62.13", C.compare_versions("0.62.12", "0.62.13") == -1)
	_check("0.62.13 < 0.63.0", C.compare_versions("0.62.13", "0.63.0") == -1)
	_check("0.9 < 0.10（不是按字符串比）", C.compare_versions("0.9", "0.10") == -1)
	_check("0.453 < 0.1000", C.compare_versions("0.453", "0.1000") == -1)
	_check("v0.54 < v0.54.01", C.compare_versions("v0.54", "v0.54.01") == -1)
	_check("相同", C.compare_versions("0.470", "0.470") == 0 and C.compare_versions("0.470", "0.470.0") == 0)
	_check("较新", C.compare_versions("0.471", "0.470") == 1)

	# 发行版本名（Kyo 11-11 整包 v0.01）：版本号只给人看，新旧比开发编号
	var rn := C.release_name
	var rb := C.release_base
	C.release_name = "0.01"
	C.release_base = 470
	_check("整包显示 0.01", C.version_of(470) == "0.01")
	_check("补丁显示 0.01.<多几号>", C.version_of(475) == "0.01.05")
	_check("比整包旧的号照旧 0.<号>", C.version_of(462) == "0.462")
	var rv := C.evaluate(_manifest(475, 470), 470, 470)
	_check("0.01 整包遇到 475：有新版、显示 0.01.05", rv["state"] == C.FULL and rv["version"] == "0.01.05" and rv["current"] == "0.01")
	rv = C.evaluate(_manifest(470, 470), 470, 470)
	_check("同号是最新", rv["state"] == C.LATEST)
	rv = C.evaluate(_manifest(462, 462), 470, 470)
	_check("清单号更小不提示（不按 0.462 > 0.01 判反）", rv["state"] == C.LATEST)
	C.release_name = rn
	C.release_base = rb

	# 验签：真公钥验 openssl 用真私钥签的样例
	var raw := FileAccess.get_file_as_bytes("res://tests/fixtures/update_channel_sample.json")
	var sig := FileAccess.get_file_as_bytes("res://tests/fixtures/update_channel_sample.sig")
	_check("样例清单用内嵌公钥验签通过", C.verify(raw, sig))
	var bad := raw.duplicate()
	bad[bad.size() - 3] = bad[bad.size() - 3] ^ 1
	_check("清单改 1 个字节验签不过", not C.verify(bad, sig))
	var bad_sig := sig.duplicate()
	bad_sig[10] = bad_sig[10] ^ 1
	_check("签名改 1 个字节验签不过", not C.verify(raw, bad_sig))
	_check("没有签名验签不过", not C.verify(raw, PackedByteArray()))
	_check("公钥坏了验签不过", not C.verify(raw, sig, "不是公钥"))

	# 测试自己的密钥：别人的签名不认
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	var pub := key.save_to_string(true)
	_check("别的密钥签的不认", not C.verify(raw, _sign(key, raw)))

	# 解析
	_check("不是 JSON 解析为空", C.parse("{坏的").is_empty())
	_check("schema 不对解析为空", C.parse(JSON.stringify(_manifest(470, 453, 0, {"schema": 2}))).is_empty())
	_check("没有 latest 解析为空", C.parse('{"schema":1}').is_empty())
	_check("latest 没有 code 解析为空", C.parse('{"schema":1,"latest":{"version":"0.470"}}').is_empty())

	# 判断
	var r := C.evaluate({}, 453, 453)
	_check("读不到", r["state"] == C.BAD and r["current"] == "0.453")
	r = C.evaluate(_manifest(453, 453), 453, 453)
	_check("相同＝已是最新", r["state"] == C.LATEST and r["version"] == "0.453")
	r = C.evaluate(_manifest(450, 453), 453, 453)
	_check("清单比本机旧＝已是最新", r["state"] == C.LATEST)
	r = C.evaluate(_manifest(470, 453, 470), 453, 453)
	_check("较新且有本底包的补丁＝补丁", r["state"] == C.PATCH and r["patch"]["code"] == 470 and r["patch"]["size"] == 2500000 and r["notes"].size() == 2 and r["date"] == "2026-11-20")
	r = C.evaluate(_manifest(470, 400, 470), 453, 453)
	_check("较新但没有本底包的补丁＝整包", r["state"] == C.FULL and r["patch"].is_empty())
	r = C.evaluate(_manifest(470, 453, 470, {"min_base": 460}), 453, 453)
	_check("底包太旧＝整包", r["state"] == C.FULL)
	r = C.evaluate(_manifest(470, 453, 470), 453, 470)
	_check("已装这个补丁＝已是最新", r["state"] == C.LATEST)
	r = C.evaluate(_manifest(480, 453, 470), 453, 470)
	_check("补丁已装到头、最新版更高＝整包", r["state"] == C.FULL)
	var m := _manifest(470, 453, 470)
	m["bases"]["453"]["patch"]["urls"] = ["http://example.invalid/p.pck"]
	_check("补丁地址不是 https＝不当补丁", C.evaluate(m, 453, 453)["state"] == C.FULL)
	m = _manifest(470, 453, 470)
	m["bases"]["453"]["patch"]["sha256"] = "xyz"
	_check("补丁 SHA 格式坏＝不当补丁", C.evaluate(m, 453, 453)["state"] == C.FULL)
	r = C.evaluate(_manifest(470, 453, 470, {"revoked": [468]}), 453, 468)
	_check("现在运行的补丁被撤回", r["revoked"] == true and r["state"] == C.PATCH)
	r = C.evaluate(_manifest(470, 453, 470, {"revoked": [453]}), 453, 453)
	_check("底包自己不算被撤回", r["revoked"] == false)

	# 多源取最高
	var a := JSON.stringify(_manifest(460, 453)).to_utf8_buffer()
	var b := JSON.stringify(_manifest(470, 453, 470)).to_utf8_buffer()
	var c := JSON.stringify(_manifest(999, 453)).to_utf8_buffer()
	var best := C.pick_best([{"json": a, "sig": _sign(key, a)}, {"json": c, "sig": _sign(key, a)}, {"json": b, "sig": _sign(key, b)}], pub)
	_check("多个源取验签通过里版本最高的（签名不对的更高版本不算）", not best.is_empty() and best["latest"]["code"] == 470)
	_check("都验不过＝空", C.pick_best([{"json": c, "sig": _sign(key, a)}, "乱的", {}], pub).is_empty())

	# 客户端：假 fetcher
	DirAccess.make_dir_recursive_absolute(DIR)
	var saved := {"urls": XUpdateClient.channel_urls, "key": XUpdateClient.public_key, "stamp": XUpdateClient.stamp_path}
	XUpdateClient.channel_urls = PackedStringArray(["https://a.invalid/godot/channel.json", "https://b.invalid/godot/channel.json", "https://c.invalid/godot/channel.json"])
	XUpdateClient.public_key = pub
	XUpdateClient.stamp_path = DIR.path_join("check.json")
	var client := XUpdateClient.instance(get_tree())
	_check("单例挂在根节点下", client.get_parent() == get_tree().root and XUpdateClient.instance(get_tree()) == client)
	client.fetcher = _fake_fetch
	var base := XUpdateClient.base_code()
	var cur := XUpdateClient.current_code()
	_check("测试里没装补丁，底包号＝运行号", base > 0 and base == cur)
	_check("没查过没有红点", not client.has_update())
	# a 源读不到；b 源旧一版；c 源新版带补丁
	var mb := JSON.stringify(_manifest(cur + 1, base)).to_utf8_buffer()
	var mc := JSON.stringify(_manifest(cur + 5, base, cur + 5)).to_utf8_buffer()
	_served = {"https://b.invalid/godot/channel.json": mb, "https://b.invalid/godot/channel.sig": _sign(key, mb),
		"https://c.invalid/godot/channel.json": mc, "https://c.invalid/godot/channel.sig": _sign(key, mc)}
	r = await client.check()
	_check("一个源读不到不影响，取最高版本", r["state"] == C.PATCH and r["code"] == cur + 5)
	_check("每个源都问了清单，读到清单的才问签名", _asked == ["https://a.invalid/godot/channel.json", "https://b.invalid/godot/channel.json",
		"https://b.invalid/godot/channel.sig", "https://c.invalid/godot/channel.json", "https://c.invalid/godot/channel.sig"])
	_check("查到新版后有红点", client.has_update())
	_check("查到结果就记时间", FileAccess.file_exists(XUpdateClient.stamp_path))
	_check("一天内不到期、满一天到期、时钟回拨算到期", not XUpdateClient.due(1000, 1000 + 86399) and XUpdateClient.due(1000, 1000 + 86400) and XUpdateClient.due(1000, 500) and XUpdateClient.due(0, 1000))
	_check("调试构建或无头不自动查", client.auto_check() == false)
	# 重启后（清掉内存里的结果）红点从记录里来，但不带补丁地址
	client.last = {}
	_check("重启后红点从上次记录来", client.has_update() and client.last.get("stale") == true and client.last["patch"].is_empty())
	# 全读不到
	_served = {}
	FileAccess.open(XUpdateClient.stamp_path, FileAccess.WRITE).store_string("{坏的")
	r = await client.check()
	_check("全读不到＝读不到，不报错", r["state"] == C.BAD and not client.has_update())
	_check("读不到不更新记录", FileAccess.get_file_as_string(XUpdateClient.stamp_path) == "{坏的")
	# 签名被换
	_served = {"https://a.invalid/godot/channel.json": mc, "https://a.invalid/godot/channel.sig": _sign(key, mb)}
	r = await client.check()
	_check("签名对不上＝读不到", r["state"] == C.BAD)
	XUpdateClient.ENABLED = false
	_served = {"https://a.invalid/godot/channel.json": mc, "https://a.invalid/godot/channel.sig": _sign(key, mc)}
	_asked.clear()
	r = await client.check()
	_check("开关关着不联网", r["state"] == C.BAD and _asked.is_empty())
	XUpdateClient.ENABLED = true

	# 页面
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(host)
	XUpdateInstall.ENABLED = false  # 先验「游戏内装补丁关着」时的提示
	var page := XUpdatePage.open(host)
	_check("打开先显示正在检查", page.state == "checking" and (page.get_node("../UpdatePage") == page))
	await _frames(12)
	var body: Label = page.find_child("Body", true, false)
	var title: Label = page.find_child("Title", true, false)
	var primary: Button = page.find_child("Primary", true, false)
	_check("有补丁但下载器没接：提示去 QQ 群，没有立即更新", page.state == C.PATCH and title.text == "有新版本" and body.text.contains("请到 QQ 群文件下载 0.%d" % (cur + 5)) and body.text.contains("· 修了一处") and not primary.visible)
	var called := []
	XUpdatePage.patch_installer = func(p, res): called.append(res["patch"]["code"])
	page.show_result(page.get_meta("result"))
	_check("下载器接上：显示大小和立即更新", primary.visible and primary.text == "立即更新" and body.text.contains("更新大小 2.4 MB") and not body.text.contains("QQ 群"))
	primary.pressed.emit()
	_check("点立即更新把结果交给下载器", called == [cur + 5])
	XUpdatePage.patch_installer = Callable()
	XUpdateInstall.ENABLED = true
	page.show_result({"state": C.LATEST, "current": "0.453", "version": "0.453"})
	_check("已是最新", title.text == "已是最新版本" and body.text == "当前版本 0.453" and not primary.visible)
	page.show_result({"state": C.FULL, "current": "0.453", "version": "0.470", "date": "2026-11-20", "notes": PackedStringArray(["说明"])})
	_check("要换整包", body.text.contains("新版本 0.470（2026-11-20）") and body.text.contains("请到 QQ 群文件下载 0.470") and not primary.visible)
	page.show_result({"state": C.BAD, "current": "0.453"})
	_check("读不到", title.text == "暂时查不到" and body.text.contains("当前版本 0.453") and body.text.contains("QQ 群"))
	_check("大小写法", XUpdatePage.size_text(322000) == "315 KB" and XUpdatePage.size_text(18234567) == "17.4 MB")
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(3)
	_check("取消键关掉这一页", not is_instance_valid(page) or page.is_queued_for_deletion())

	host.queue_free()
	client.fetcher = Callable()
	client.last = {}
	XUpdateClient.channel_urls = saved["urls"]
	XUpdateClient.public_key = saved["key"]
	XUpdateClient.stamp_path = saved["stamp"]
	_cleanup()
	var passed := results.filter(func(x): return x["passed"]).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size(), "results": results}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
