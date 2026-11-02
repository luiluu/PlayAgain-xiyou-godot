class_name FixedMidStream
extends XRandomStream
## 测试公用的固定随机流（tools42，白龙_14 提）：整数随机取区间的 value 处（默认中点，floor(n × 0.5)），浮点随机恒为 value。
## 专项比伤害时别用 XRandomStream 默认的原始 uint 余数（结果乱跳）；各专项原来各抄一份，现在 `rand.rule = FixedMidStream.new()`，
## 要别的点改 `.value`。draws 照旧累计，供断言「抽了几次」。
var value := 0.5

func _take(kind: String, _reason: String, _event_key: String):
	draws += 1
	return value if kind == "float" else 2147483648

func next_index_mod(n: int, reason: String, event_key := "") -> int:
	_take("uint32", reason, event_key)
	return floori(n * value) if n > 0 else 0

func next_int_inclusive(lo: int, hi: int, reason: String, event_key := "") -> int:
	_take("uint32", reason, event_key)
	return lo + floori((hi - lo + 1) * value)
