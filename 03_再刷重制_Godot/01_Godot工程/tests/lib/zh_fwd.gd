extends RefCounted
## 文字批 2／3（T027，Kyo D104／D105）后，对着「冻结原版参照」比文字的专项用：把参照里的旧用词换成新口径再比。
## 不加 class_name：只给测试 preload。用法：const Z := preload("res://tests/lib/zh_fwd.gd")；Z.fwd(参照里读出的值)。
## 规则与 text_fix/rules.json 末尾几条、代码里直接改的字一致：Boss／BOSS／boss→首领（【超级Boss】【DOTABOSS】前缀按 D126 改为【霸主】【远古首领】，所以先换前缀再换 Boss）、天道使者→见证使者（Map046 那句讨债台词除外）、天道币→晨星币、
## 「终伤／最终伤害」后面直接跟加减数值→伤害、「终伤加成」→「伤害加成」、「游戏结束」（主菜单项）→「回到标题」。
static var _boss := RegEx.create_from_string("(?<!超级)(?<!DOTA)(?i:boss)")
static var _prefix := RegEx.create_from_string("超级[Bb]oo?s+")
static var _witness := RegEx.create_from_string("天道使者(?!>嘿嘿，你居然打过了深渊骑士)")
static var _fin := RegEx.create_from_string("(?:最终伤害|终伤)(?=[+＋\\-−]\\d)")


static var _pct_fin := RegEx.create_from_string("(?<=%)终伤")


static func text(t: String) -> String:
	if t == "终伤":
		return "伤害"  # 表头单元格（难度对照页）
	t = _prefix.sub(t, "霸主", true).replace("【DOTABOSS】", "【远古首领】")
	t = _witness.sub(t, "见证使者", true).replace("天道币", "晨星币")
	t = _boss.sub(t, "首领", true)
	t = _fin.sub(t, "伤害", true)
	t = t.replace("终伤加成", "伤害加成").replace("专属魔法最终伤害×", "专属魔法伤害×")
	return _pct_fin.sub(t, "伤害", true)


## 递归：字符串值换词，键与数字不动
static func fwd(v):
	if v is String:
		return text(v)
	if v is Array:
		return v.map(func(x): return fwd(x))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = fwd(v[k])
		return out
	return v


## 只换代码里直接改掉的写法（对着「关了 XTextFix 的原版」比的专项用：text_fix 规则那几条不算）
static var _code_fin := RegEx.create_from_string("(?<=[；、])终伤(?=[＋+])")


static func code_text(t: String) -> String:
	return _code_fin.sub(t, "伤害", true).replace("专属魔法最终伤害×", "专属魔法伤害×")
