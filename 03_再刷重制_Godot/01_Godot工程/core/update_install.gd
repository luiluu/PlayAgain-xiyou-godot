class_name XUpdateInstall
extends Node
## 自动更新第②批：补丁下载（多源、断点续传、校验）、登记、存档备份、退回。
## 补丁只写用户目录 user://updates/，不碰安装目录；登记好的补丁下次启动由 core/boot_patch.gd 载入。
##
## 下载：依次试清单里的每个地址。已下的字节留在 <名字>.part，重试或下次再点时带 Range 头接着下
## （新收到的字节先落在 <名字>.chunk，收完或中断后并进 .part）；服务器不认 Range（回 200）就整份重下。
## 下完比字节数和 SHA-256，对上才改名成正式文件；对不上删掉重来一次，再不行换下一个地址。
## 登记：先备份存档目录（留最近 KEEP_BACKUPS 份），再写 active.json（confirmed=false，prev＝原来那份），提示重启。
## 退回：rollback() 回上一份或安装包自带内容，下次启动生效。

signal progress(done: int, total: int)
signal finished(ok: bool, message: String)

const BootPatchScript := preload("res://core/boot_patch.gd")
const NODE_NAME := "UpdateInstall"
const KEEP_BACKUPS := 3
const SAVE_DIR := "user://modes"
const BACKUP_DIR_NAME := "save_backup"
const STALL_SEC := 30
const MAX_REDIRECTS := 4

## O-待定·补丁下载 开关：false 回退为不在游戏内装补丁（检查更新页照「要换整包」提示去 QQ 群）。
static var ENABLED := true
static var dir := BootPatchScript.DIR
## 只给测试用：允许本机 http 地址（正式清单的补丁地址必须全是 https，XUpdateCheck.valid_patch 管着）。
static var allow_http_for_tests := false
## 要备份的存档目录（所有模式的存档都在它下面）；测试里换成假目录。
static var save_dir := SAVE_DIR

var busy := false
var _cancelled := false
var _cut_code := 0
var _url_re := RegEx.create_from_string("^(https?)://([^/:]+)(?::(\\d+))?(/.*)?$")


static func instance(tree: SceneTree) -> XUpdateInstall:
	var n := tree.root.get_node_or_null(NODE_NAME) as XUpdateInstall
	if n == null:
		n = XUpdateInstall.new()
		n.name = NODE_NAME
		n.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(n)
	return n


static func state_path() -> String:
	return dir.path_join("active.json")


static func file_name(base: int, code: int) -> String:
	return "patch_%d_%d.pck" % [base, code]


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var j := JSON.new()
	return j.data if j.parse(FileAccess.get_file_as_string(path)) == OK else null


static func _file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f else 0


## 把 src 的内容接到 dst 后面（分块，不整份读进内存），然后删掉 src。
static func _append(dst: String, src: String) -> void:
	if not FileAccess.file_exists(src):
		return
	var r := FileAccess.open(src, FileAccess.READ)
	var w := FileAccess.open(dst, FileAccess.READ_WRITE) if FileAccess.file_exists(dst) else FileAccess.open(dst, FileAccess.WRITE)
	if r and w:
		w.seek_end()
		while r.get_position() < r.get_length():
			w.store_buffer(r.get_buffer(1 << 20))
	r = null
	w = null
	DirAccess.remove_absolute(src)


## 剩余空间够不够（至少补丁的 2 倍；查不到剩余空间时不拦）。
static func enough_space(size: int) -> bool:
	var da := DirAccess.open("user://")
	var free := da.get_space_left() if da else 0
	return free <= 0 or free >= size * 2


func cancel() -> void:
	_cancelled = true


## 下载并校验。patch：{code, size, sha256, urls}（XUpdateCheck.evaluate 给的）。成功返回正式文件路径，失败返回 ""。
## 已下的部分留着（取消、断网、关游戏都一样），下次接着下。
func download(patch: Dictionary, base: int) -> String:
	if busy or not ENABLED or not (XUpdateCheck.valid_patch(patch) or (allow_http_for_tests and patch.get("urls") is Array)):
		return ""
	busy = true
	_cancelled = false
	DirAccess.make_dir_recursive_absolute(dir)
	var total := int(patch["size"])
	var sha := str(patch["sha256"]).to_lower()
	var final := dir.path_join(file_name(base, int(patch["code"])))
	var part := final + ".part"
	var chunk := final + ".chunk"
	var ok := FileAccess.file_exists(final) and _file_size(final) == total and FileAccess.get_sha256(final) == sha
	var restarted := false
	var i := 0
	var urls: Array = patch["urls"]
	_append(part, chunk)  # 上次关游戏时留下的续传字节
	while not ok and not _cancelled and i < urls.size():
		var have := _file_size(part)
		if have > total:
			DirAccess.remove_absolute(part)
			have = 0
		if have < total:
			var code := await _fetch_to(str(urls[i]), chunk, have, total)
			var got := _file_size(chunk)
			if code == 206 and have > 0 and got > 0:
				_append(part, chunk)            # 续上了
			elif code == 200 and got == total:
				DirAccess.remove_absolute(part)  # 服务器不认 Range 或本来就是从头下：整份换上
				DirAccess.rename_absolute(chunk, part)
			elif code == 0 and _cut_code == 206 and have > 0 and got > 0:
				_append(part, chunk)            # 续传到一半断了：收到的是好的，接上，换下一个地址
				i += 1
			elif code == 0 and _cut_code == 200 and got > have:
				DirAccess.remove_absolute(part)  # 从头下到一半断了（比已有的多）：当新的开头留着，换下一个地址接着下
				DirAccess.rename_absolute(chunk, part)
				i += 1
			else:
				DirAccess.remove_absolute(chunk)  # 连不上、状态码不对、200 但不是整份（如占位页）：这次收到的不要
				i += 1
			progress.emit(mini(_file_size(part), total), total)
			continue
		if FileAccess.get_sha256(part) == sha:
			DirAccess.remove_absolute(final)
			ok = DirAccess.rename_absolute(part, final) == OK
		else:
			DirAccess.remove_absolute(part)  # 内容不对：同一个地址整份重来一次，再不对换地址
			if restarted:
				i += 1
			restarted = true
	busy = false
	return final if ok else ""


## 发一次 GET，边收边写到 to（HTTPRequest 的 download_file 在断线时会把没下完的文件删掉，续不了，所以这里用 HTTPClient 自己写）。
## have>0 时带 Range。返回状态码；连不上、超时（STALL_SEC 秒没有新字节）、半路断线、取消都返回 0，已收到的字节留在 to 里。
func _fetch_to(url: String, to: String, have: int, total: int) -> int:
	var redirects := 0
	while redirects <= MAX_REDIRECTS:
		var m := _url_re.search(url)
		if m == null:
			return 0
		var tls := m.get_string(1) == "https"
		var port := m.get_string(3).to_int() if m.get_string(3) != "" else (443 if tls else 80)
		var path := m.get_string(4) if m.get_string(4) != "" else "/"
		_cut_code = 0
		var hc := HTTPClient.new()
		if hc.connect_to_host(m.get_string(2), port, TLSOptions.client() if tls else null) != OK:
			return 0
		if not await _poll_until(hc, [HTTPClient.STATUS_CONNECTED]):
			return 0
		var headers := PackedStringArray(["Accept: */*", "User-Agent: xiyou-godot-update"])
		if have > 0:
			headers.append("Range: bytes=%d-" % have)
		if hc.request(HTTPClient.METHOD_GET, path, headers) != OK:
			return 0
		if not await _poll_until(hc, [HTTPClient.STATUS_BODY, HTTPClient.STATUS_CONNECTED]):
			return 0
		var code := hc.get_response_code()
		if code in [301, 302, 303, 307, 308]:
			var loc := ""
			for h in hc.get_response_headers():
				if h.to_lower().begins_with("location:"):
					loc = h.substr(9).strip_edges()
			hc.close()
			if not loc.begins_with("http"):
				return 0
			if tls and not loc.begins_with("https://"):
				return 0  # 不从 https 降到 http
			url = loc
			redirects += 1
			continue
		var f := FileAccess.open(to, FileAccess.WRITE)
		if f == null:
			hc.close()
			return 0
		var got := 0
		var last_ms := Time.get_ticks_msec()
		var last_report := 0
		var complete := false
		while not _cancelled:
			hc.poll()
			var st := hc.get_status()
			if st == HTTPClient.STATUS_BODY:
				var chunk := hc.read_response_body_chunk()
				if chunk.size() > 0:
					f.store_buffer(chunk)
					got += chunk.size()
					last_ms = Time.get_ticks_msec()
					if last_ms - last_report >= 250:
						last_report = last_ms
						progress.emit(mini(have + got, total) if code == 206 else mini(got, total), total)
					continue
			elif st == HTTPClient.STATUS_CONNECTED:
				complete = true
				break
			else:
				break  # 断线或出错
			if Time.get_ticks_msec() - last_ms > STALL_SEC * 1000:
				break
			await get_tree().process_frame
		f.close()
		var expect := hc.get_response_body_length()
		hc.close()
		_cut_code = code  # 半路断了也记下状态码：206 的半截能直接接上，200 的半截是文件开头
		if _cancelled or not complete or (expect >= 0 and got != expect):
			return 0
		return code
	return 0


## 轮询到某个状态；出错、超时、取消返回 false。
func _poll_until(hc: HTTPClient, want: Array) -> bool:
	var start := Time.get_ticks_msec()
	while not _cancelled:
		hc.poll()
		var st := hc.get_status()
		if want.has(st) and st != HTTPClient.STATUS_REQUESTING:
			return true
		if not [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_REQUESTING].has(st):
			return false
		if Time.get_ticks_msec() - start > STALL_SEC * 1000:
			return false
		await get_tree().process_frame
	return false


## 备份存档目录到 updates/save_backup/<时间>_to<号>/，只留最近 KEEP_BACKUPS 份。返回备份目录（没有存档目录返回 ""）。
static func backup_saves(code: int, src := save_dir) -> String:
	if not DirAccess.dir_exists_absolute(src):
		return ""
	var root := dir.path_join(BACKUP_DIR_NAME)
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "_")
	var dst := root.path_join("%s_to%d" % [stamp, code])
	var n := 1
	while DirAccess.dir_exists_absolute(dst):
		n += 1
		dst = root.path_join("%s_%d_to%d" % [stamp, n, code])
	if not _copy_dir(src, dst):
		return ""
	var da := DirAccess.open(root)
	var names := Array(da.get_directories())
	names.sort()
	while names.size() > KEEP_BACKUPS:
		_remove_dir(root.path_join(names.pop_front()))
	return dst


static func _copy_dir(src: String, dst: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(dst) != OK:
		return false
	var da := DirAccess.open(src)
	if da == null:
		return false
	for f in da.get_files():
		if da.copy(src.path_join(f), dst.path_join(f)) != OK:
			return false
	for d in da.get_directories():
		if not _copy_dir(src.path_join(d), dst.path_join(d)):
			return false
	return true


static func _remove_dir(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	for f in da.get_files():
		da.remove(f)
	for d in da.get_directories():
		_remove_dir(path.path_join(d))
	DirAccess.remove_absolute(path)


## 登记补丁（文件已在 dir 里并校验过）。先备份存档；备份失败就不登记。prev 记下现在生效的那份，给退回用。
static func register(patch: Dictionary, base: int) -> bool:
	var name := file_name(base, int(patch["code"]))
	var path := dir.path_join(name)
	if _file_size(path) != int(patch["size"]) or FileAccess.get_sha256(path) != str(patch["sha256"]).to_lower():
		return false
	if DirAccess.dir_exists_absolute(save_dir) and backup_saves(int(patch["code"])) == "":
		return false
	var cur = _read_json(state_path())
	var prev = null
	if typeof(cur) == TYPE_DICTIONARY and cur.get("file") is String and cur.get("confirmed", true) == true and cur["file"] != name:
		prev = {"file": cur["file"], "sha256": cur.get("sha256", ""), "size": cur.get("size", 0), "base": cur.get("base", 0), "code": cur.get("code", 0)}
	elif typeof(cur) == TYPE_DICTIONARY and typeof(cur.get("prev")) == TYPE_DICTIONARY:
		prev = cur["prev"]  # 现在这份还没确认过：上一份仍是它的上一份
	var st := {"file": name, "sha256": str(patch["sha256"]).to_lower(), "size": int(patch["size"]), "base": base,
		"code": int(patch["code"]), "confirmed": false, "boots": 0, "prev": prev}
	var f := FileAccess.open(state_path(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(st))
	f.close()
	DirAccess.remove_absolute(dir.path_join(BootPatchScript.ROLLED_BACK_NAME))
	_prune([name, str(prev["file"]) if prev != null else ""])
	return true


## 删掉用不到的旧补丁文件（现在这份和上一份留着；正在被引擎占用删不掉的不管，下次再删）。
static func _prune(keep: Array) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	for f in da.get_files():
		if (f.ends_with(".pck") or f.ends_with(".part") or f.ends_with(".chunk")) and not keep.has(f):
			da.remove(f)


## 现在登记着的补丁编号（没有为 0）。
static func registered_code() -> int:
	var cur = _read_json(state_path())
	return int(cur.get("code", 0)) if typeof(cur) == TYPE_DICTIONARY else 0


## 已登记、还没重启生效的补丁编号（没有为 0）。
static func pending_code() -> int:
	var c := registered_code()
	var running := int(BootPatchScript.result.get("code", 0)) if BootPatchScript.result.get("loaded", false) else 0
	return c if c != running else 0


## 退回：to_base＝true 直接回安装包自带内容；否则回上一份（没有上一份也回自带内容）。下次启动生效。
## 返回退回后登记的编号（0＝安装包自带）。
static func rollback(to_base := false, reason := "手动退回") -> int:
	var cur = _read_json(state_path())
	if typeof(cur) != TYPE_DICTIONARY:
		return 0
	var prev = cur.get("prev")
	var note := FileAccess.open(dir.path_join(BootPatchScript.ROLLED_BACK_NAME), FileAccess.WRITE)
	if note:
		note.store_string(JSON.stringify({"code": int(cur.get("code", 0)), "reason": reason}))
		note.close()
	if not to_base and typeof(prev) == TYPE_DICTIONARY and prev.get("file") is String:
		prev["confirmed"] = true
		prev["prev"] = null
		var f := FileAccess.open(state_path(), FileAccess.WRITE)
		f.store_string(JSON.stringify(prev))
		f.close()
		return int(prev.get("code", 0))
	DirAccess.remove_absolute(state_path())
	return 0


## 自动退回后留下的提示（读一次就删）：{"code", "reason"}；没有返回空字典。
static func take_rollback_notice() -> Dictionary:
	var p := dir.path_join(BootPatchScript.ROLLED_BACK_NAME)
	var d = _read_json(p)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	return d if typeof(d) == TYPE_DICTIONARY else {}


## 重启游戏让补丁生效：桌面端自动重开，安卓只能退出让玩家自己再点开。
static func restart(tree: SceneTree) -> void:
	if OS.get_name() != "Android":
		OS.set_restart_on_exit(true, OS.get_cmdline_args())
	tree.quit()

