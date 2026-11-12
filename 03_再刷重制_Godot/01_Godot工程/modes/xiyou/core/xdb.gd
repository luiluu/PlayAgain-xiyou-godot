class_name XDB
extends RefCounted
## 西游模式数据库：读取转换器生成的 generated/db/*.json（原 MV 数据，ID 不变）。
## 表按需加载并缓存；JSON 数字一律是 float，取 ID 时用 int()。

const BASE := "res://modes/xiyou/generated/"
static var _tables := {}
## 解析结果的只读缓存（木吒 2026-10-25）：大 JSON 每个测试场景、每次启动都要重新解析（Skills 23 MB 约 1.2 秒，
## slice_d* 150 MB 约 5 秒）。按文件内容 SHA-256 与引擎版本作键，把 JSON.parse_string 的结果 var_to_bytes 后 zstd 压缩存起来，
## 命中时 bytes_to_var 还原（同一份 Variant，回归 xiyou_json_cache 逐字节比对）。键只看内容，不看修改时间；缓存坏了就照常解析再重写。
## 回退：环境变量 XIYOU_JSON_CACHE=0，或把 json_cache 设为 false，即与原来一样每次直接解析。
const CACHE_FORMAT := 1
const CACHE_MAGIC := "XJC1"
static var json_cache := OS.get_environment("XIYOU_JSON_CACHE") != "0"
static var cache_dir_override := ""  # 测试用；空＝默认目录


static func available() -> bool:
	return FileAccess.file_exists(BASE + "db/System.json")


static func load_json(rel: String) -> Variant:
	return parse_file(BASE + rel)


## 读一份 JSON；与 JSON.parse_string(FileAccess.get_file_as_string(path)) 相同，读不到返回 null 并报错。
static func parse_file(path: String) -> Variant:
	if json_cache:
		var bytes := FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			var file := _cache_file(path, bytes)
			var hit = _cache_read(file)
			if hit[0]:
				return hit[1]
			var value = _parse(path)
			if value != null:
				_cache_write(path, file, value)
			return value
	return _parse(path)


static func _parse(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("XDB: 读取失败 " + path.trim_prefix(BASE))
		return null
	return JSON.parse_string(text)


static func cache_dir() -> String:
	if cache_dir_override != "":
		return cache_dir_override
	# 导出版 res:// 只读，放用户目录；开发与测试放工程的 .godot（不入 Git，各工作树各一份，测试的临时 HOME 不影响）
	return "user://xiyou_json_cache" if OS.has_feature("template") else ProjectSettings.globalize_path("res://.godot/xiyou_json_cache")


static func _cache_file(path: String, bytes: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(("%d|%s|%s|" % [CACHE_FORMAT, Engine.get_version_info().hash, path]).to_utf8_buffer())
	h.update(bytes)
	return cache_dir().path_join(path.trim_prefix("res://").replace("/", "__") + "." + h.finish().hex_encode() + ".bin")


## 返回 [是否命中, 值]；文件不在、头不对、解压或还原失败都算未命中。
static func _cache_read(file: String) -> Array:
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null or f.get_length() <= 12:
		return [false, null]
	var head := f.get_buffer(4).get_string_from_ascii()
	var size := f.get_64()
	var packed := f.get_buffer(f.get_length() - 12)
	f.close()
	if head != CACHE_MAGIC or size <= 0 or packed.is_empty():
		return [false, null]
	var raw := packed.decompress(size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != size:
		return [false, null]
	return [true, bytes_to_var(raw)]


static func _cache_write(path: String, file: String, value: Variant) -> void:
	var dir := file.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return
	var raw := var_to_bytes(value)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	# 先写临时文件再改名：几个测试同时写同一份时，读者只会看到完整文件或没有文件
	var temp := "%s.%d.%d.tmp" % [file, OS.get_process_id(), Time.get_ticks_usec()]
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(CACHE_MAGIC.to_ascii_buffer())
	f.store_64(raw.size())
	f.store_buffer(packed)
	f.close()
	if DirAccess.rename_absolute(temp, file) != OK:
		DirAccess.remove_absolute(temp)
		return
	# 同一源文件的旧版本缓存删掉，免得目录越积越大
	var prefix := path.trim_prefix("res://").replace("/", "__") + "."
	for name in DirAccess.get_files_at(dir):
		if name.begins_with(prefix) and name.ends_with(".bin") and dir.path_join(name) != file and name.count(".") == prefix.count(".") + 1:
			DirAccess.remove_absolute(dir.path_join(name))


static func table(name: String) -> Variant:
	if not _tables.has(name):
		_tables[name] = load_json("db/%s.json" % name)
		if name == "Skills" and _tables[name] is Array:
			XZhenqi.patch_rewards(_tables[name])  # 真气突破奖励的数值（CodexZhenqi.patchRewards）
			XCanglong.patch_skills(_tables[name])  # 苍龙破晓重做（O-314，开关 XCanglong.REWORK）
		if name == "Classes":
			XCanglong.patch_classes(_tables[name])
		if _tables[name] is Array:  # 天启篇五条悟 180（重制新角色，XGojo）
			match name:
				"Actors": XGojo.patch_actors(_tables[name])
				"Classes": XGojo.patch_classes(_tables[name])
				"Skills": XGojo.patch_skills(_tables[name])
				"States": XGojo.patch_states(_tables[name])
		if name == "Plugins" and _tables[name] is Dictionary:
			XGojo.patch_plugins(_tables[name])  # 五条悟的进阶行
		if name == "Armors" and _tables[name] is Array:
			# H／U.describe 在 isDatabaseLoaded 里就地改四件成长装备原件的说明与成长行（installNativeHeartsteel／HubrisRuntime；
			# v0.62.12 数据库里狂妄原件写「物理伤害忽略18%目标物防」，开机后才改成「效果：物防穿透18%」，锻造出的实例照抄改过的）
			for id in [XHeartsteel.ARMOR, XHeartsteel.LEVIATHAN, XHubris.ARMOR, XHubris.ATARAXIA]:
				if id < _tables[name].size() and _tables[name][id] is Dictionary:
					XGrowthHelp.describe(_tables[name][id])
			XCanglong.patch_armors(_tables[name])  # 【上邪】专属名
			XGojo.patch_armors(_tables[name])  # 天启篇五条悟专属法宝「眼罩」
		if name == "CommonEvents":
			XDeadContent.patch_common_events(_tables[name])  # 死内容做活（一护招募置 1309、领域魔攻全队；O-184／O-185）
			XCasinoBatch.fix_abyss_stage2(_tables[name])  # 深渊赌场二阶段先抽再读（新源 v0.62.10 fixAbyssStage2）
	return _tables[name]


## 取一条记录；不存在或为空时返回 {}。
static func rec(name: String, id: int) -> Dictionary:
	var t: Array = table(name)
	if name == "Skills" and id >= t.size() and XTianqiSkills.has_new(id):
		return XTianqiSkills.new_rec(id, t)  # 天启篇技能重构补的招（表外号段，按底号复制）
	if name == "States" and id >= t.size() and XTianqiSkills.has_new_state(id):
		return XTianqiSkills.new_state_rec(id, t)  # 天启篇技能重构新加的状态（表外号段 10801 起）
	if id <= 0 or id >= t.size() or t[id] == null:
		return {}
	if name == "Skills" and XTianqiSkills.has(id):
		return XTianqiSkills.rec(id, t[id])  # 天启篇全角色技能重构：天启篇存档换成改写后的记录
	if name == "States" and XTianqiSkills.has_state(id):
		return XTianqiSkills.rec_state(id, t[id])
	return t[id]


static func system() -> Dictionary:
	return table("System")


static func plugin(name: String) -> Dictionary:
	return table("Plugins").get(name, {})


static func map(map_id: int) -> Dictionary:
	var key := "map:%d" % map_id
	if not _tables.has(key):
		_tables[key] = load_json("maps/Map%03d.json" % map_id)
		XDeadContent.patch_map(map_id, _tables[key])  # 死内容做活（一护卍解 Map213；O-184）
		XRift.patch_map(map_id, _tables[key])  # 时空漩涡二阶段（Map004；O-312，开关 XRift.STAGE2）
		XLobbyDebugNpc.patch_map(map_id, _tables[key])  # 大厅全图鉴 NPC 只留怪物图鉴（Kyo 11-12）
	return _tables[key] if _tables[key] != null else {}


static func img_path(folder: String, name: String) -> String:
	for ext in [".png", ".jpg"]:
		var p := "%simg/%s/%s%s" % [BASE, folder, name, ext]
		if ResourceLoader.exists(p):
			return p
	# 重制自带的新美术（不在原版里）：时空漩涡二阶段图在 content/rift/（XRift，见该目录 README）
	if folder == "characters" and name.begins_with("!Codex_Rift_"):
		var own := "res://content/rift/%s.png" % name
		if ResourceLoader.exists(own):
			return own
	# 天启篇五条悟（XGojo）：行走图、战斗图、头像在 content/gojo/
	if name.trim_prefix("$").begins_with("Codex_Gojo_"):
		var gojo := "res://content/gojo/%s.png" % name
		if ResourceLoader.exists(gojo):
			return gojo
	# 天启篇七印祭坛的首领新画（XTianqiQiyinArt）：content/tianqi/qiyin/battlers/Tianqi_Qiyin_*
	if folder == "sv_enemies":
		return XTianqiQiyinArt.battler_path(name)
	return ""


## 原版有几首 .ogg 其实是 MP3（如 bgm「fade to black」「Number One」，浏览器按内容播），转换器按内容存成 .mp3
static func audio_path(folder: String, name: String) -> String:
	for ext in [".ogg", ".mp3"]:
		var p := "%saudio/%s/%s%s" % [BASE, folder, name, ext]
		if ResourceLoader.exists(p):
			return p
	return ""
