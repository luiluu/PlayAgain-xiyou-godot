class_name XRx
## 正则按写法只编译一次（O-待定-1）：原来每次用到都 RegEx.create_from_string 现编，一次行动结算里编上千次
##（skills() 每个技能过一遍真气道法的备注正则、_num 每个被动值编一次……），手机上很慢。编好的 RegEx 只读（search／sub 不改它），
## 同一写法共用一个对象结果不变。回退：CACHE = false（每次现编，同原来）。
static var CACHE := true
const MAX := 4096
static var _cache := {}


static func re(pattern: String) -> RegEx:
	if not CACHE:
		return RegEx.create_from_string(pattern)
	var r = _cache.get(pattern)
	if r == null:
		if _cache.size() >= MAX:
			_cache.clear()  # 现拼的写法（带编号的）太多时整表重来，不让它一直长
		r = RegEx.create_from_string(pattern)
		_cache[pattern] = r
	return r
