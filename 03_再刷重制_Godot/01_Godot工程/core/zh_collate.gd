class_name XZhCollate
## 中文排序：等同原版 a.localeCompare(b, 'zh-Hans')（ICU 拼音序；汉字在拉丁字母前，数字逐位比）。
## 字表 XZhCollateData 由 07_开发环境/生成中文排序表.cjs 用 Intl.Collator 生成，并以原版全部状态名自检、
## 另用 Chrome 核过同序（rules-passive-order1）。先逐字比一级序（再比长度），相同再逐字比三级序；表外的字按码位排在最后。

const _BIG := 1 << 24
static var _rank := {}   # 码位 → Vector2i(一级序, 三级序)
static var _ignore := {}


static func _ensure() -> void:
	if not _rank.is_empty():
		return
	var order: String = XZhCollateData.ORDER
	var ps: String = XZhCollateData.PSTEP
	var ts: String = XZhCollateData.TSTEP
	var p := 0
	var t := 0
	for i in order.length():
		if ps.unicode_at(i) == 49:  # "1"
			p += 1
		if ts.unicode_at(i) == 49:
			t += 1
		_rank[order.unicode_at(i)] = Vector2i(p, t)
	var ign: String = XZhCollateData.IGNORE
	for i in ign.length():
		_ignore[ign.unicode_at(i)] = true


static func _keys(s: String) -> Array:
	var out := []
	for i in s.length():
		var c := s.unicode_at(i)
		if _ignore.has(c):
			continue
		out.append(_rank.get(c, Vector2i(_BIG + c, _BIG + c)))
	return out


## 小于 0：a 在前；0：同序；大于 0：b 在前
static func compare(a: String, b: String) -> int:
	if a == b:
		return 0
	_ensure()
	var ka := _keys(a)
	var kb := _keys(b)
	for lv in 2:
		for i in mini(ka.size(), kb.size()):
			var x: int = ka[i][lv]
			var y: int = kb[i][lv]
			if x != y:
				return x - y
		if ka.size() != kb.size():
			return ka.size() - kb.size()
	return 0


## 稳定排序（同 V8 Array.prototype.sort，相等的保持原顺序）：cmp(a, b) 返回整数
static func stable_sort(arr: Array, cmp: Callable) -> Array:
	var idx := range(arr.size())
	idx.sort_custom(func(i, j):
		var r: int = cmp.call(arr[i], arr[j])
		return r < 0 if r != 0 else i < j)
	return idx.map(func(i): return arr[i])
