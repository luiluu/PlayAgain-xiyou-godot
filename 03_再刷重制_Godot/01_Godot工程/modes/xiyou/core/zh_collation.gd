class_name XZhCollation
extends RefCounted
## 中文拼音排序：正式版 String.localeCompare(…, 'zh-Hans')（Chromium ICU pinyin 排序）的 Godot 版本。
## 表 modes/xiyou/zh_collation.json 由 03_转换工具/zh_collation_table.cjs 用 Intl.Collator('zh-Hans') 生成：
## 每个字的一级权重名次（同组 = 只差大小写/全半角），ignorable 为跳过的字。比较时先逐字比名次，
## 名次全同再按码位，ASCII 大小写互换后比（ICU 三级权重小写在前；其余二三级差异只在这里近似）。生成脚本自检：正式源 15,117 个名字与 ICU 排序一致。

const PATH := "res://modes/xiyou/zh_collation.json"
static var _rank := {}
static var _skip := {}
static var _size := 0


static func _ensure() -> void:
	if _size > 0:
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (data is Dictionary):
		push_error("XZhCollation: 读取失败 " + PATH)
		_size = 1
		return
	var groups: PackedStringArray = str(data.order).split("\n")
	for i in range(groups.size()):
		for ch in groups[i]:
			_rank[ch] = i + 1
	for ch in str(data.ignorable):
		_skip[ch] = true
	_size = groups.size()


## 表里没有的字排在最后，按码位
static func _key(s: String) -> PackedInt32Array:
	_ensure()
	var out := PackedInt32Array()
	for ch in s:
		if _skip.has(ch):
			continue
		out.append(int(_rank.get(ch, _size + 1 + ch.unicode_at(0))))
	return out


## 同 localeCompare：a 在前为负、相同为 0、a 在后为正
static func compare(a: String, b: String) -> int:
	if a == b:
		return 0
	var ka := _key(a)
	var kb := _key(b)
	for i in range(mini(ka.size(), kb.size())):
		if ka[i] != kb[i]:
			return -1 if ka[i] < kb[i] else 1
	if ka.size() != kb.size():
		return -1 if ka.size() < kb.size() else 1
	var sa := _swap_ascii_case(a)
	var sb := _swap_ascii_case(b)
	if sa != sb:
		return -1 if sa < sb else 1
	return -1 if a < b else 1


static func _swap_ascii_case(s: String) -> String:
	var out := ""
	for ch in s:
		var c := ch.unicode_at(0)
		out += ch.to_upper() if c >= 97 and c <= 122 else (ch.to_lower() if c >= 65 and c <= 90 else ch)
	return out


static func less(a: String, b: String) -> bool:
	return compare(a, b) < 0
