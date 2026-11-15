class_name XFestReward
extends RefCounted
## 【cc·未经审查】冠军庆典的签到、贺礼、兑换店、剩币自动换、读档提醒、成就、天启篇存档纪念品（Kyo 11-15 定 D46「丰富」档；
## 方案：私密设计仓 重制设定/冠军庆典活动_v0.3.1.md 2.3～2.6、第 4 节）。文字全在 XFestText。
##
## - 签到（2.3）：活动进行中，累计 3 天（不用连续），第 1、2、3 天各 70／70／60 庆典币，第 3 天另给称号「全勤观众」（44）。
## - 贺礼（2.4）：每个存档一次。庆典币 50、精魂 5 万、副本挑战符文 ×2（按等级挑档）、肝帝积分抽奖券（1639）×10。XFestLobby.give_gift 调 gift。
## - 兑换店（2.5）：SHOP 六样，前五样限购（全买下 480 币），精魂兜底 10 币＝1 万精魂不限。进行中和收尾期都开。
## - 庆典币收支（2.6）：一个存档最多 750（贺礼 50＋签到 200＋三档 200／150／150）。
## - 剩币（2.6）：收尾期过后，下一次读档自动按 10 币＝1 万精魂换掉，进地图弹一条提示（after_load → map_start）。
##   不看 XFest.ENABLED：币是玩家已经拿到的东西，开关关了也照换（换法只有这一个，不会多给）。
## - 读档提醒（2.3）：活动进行中，每天第一次读档进地图时提示一次「回大厅看庆典」（记在这次运行里，不写进存档）。
## - 天启篇存档（第 4 节）：不开冠军之路、签到、兑换店；使者直接送称号「冠军观赛团」（43）和成就「我在现场」，不发币、精魂、门票、戒指。
## - 成就（144～147，类型「节日」，不带奖励）：我在现场、冠军之路、一穿四、全勤观众。XAchievement 读表时并进来（活动结束照列；总开关关掉不列）。
## - 迁移：改三档前分支里的称号 45「冠军之路·洪荒」没发给玩家，并进 41；读档时手里有 45 没有 41 的补 41。

## 签到每天给的庆典币（累计第几天）
const SIGN_COINS := [70, 70, 60]
## 贺礼（每个存档一次）
const GIFT_COINS := 50
const GIFT_GOLD := 50000
const GIFT_RUNES := 2
const GIFT_ITEMS := [[1639, 10]]
## 副本挑战符文：初级 24（10～20 级）、中级 64（20～30 级）、高级 110（30～40 级）、特级 171（40～50 级）。按出战队伍里的最高等级挑
const RUNES := [[30, 24], [40, 64], [50, 110], [9999, 171]]
## 剩币兜底：10 币换 1 万精魂
const GOLD_PRICE := 10
const GOLD_PER := 10000

## 兑换店（v0.3.1 2.5）：key 对应 XFestText.SHOP_NAMES；limit 0＝不限
const SHOP := [
	{"key": "title", "price": 100, "limit": 1},
	{"key": "rune", "price": 50, "limit": 2},
	{"key": "ticket", "price": 50, "limit": 2},
	{"key": "shard", "price": 60, "limit": 2},
	{"key": "party", "price": 60, "limit": 1},
	{"key": "gold", "price": GOLD_PRICE, "limit": 0},
]
const TICKET := 1639
const SHARD := 180
const PARTY := 179

## 成就编号（接在原版 1～141、重制 142／143 之后）
const ACHIEVEMENT_IDS := {"scene": 144, "road": 145, "one_four": 146, "attend": 147}
const ACHIEVEMENT_TYPE := "节日"
const ACHIEVEMENT_ICONS := {"scene": 1800, "road": 1469, "one_four": 2506, "attend": 2607}

## 读档后要在进地图时弹的提示（after_load 填，map_start 放）
static var _pending: Array = []
## 读档提醒这次运行里提示过的那天（不写进存档：读档本身不改存档内容；重开游戏同一天会再提示一次）
static var _reminded_day := ""


static func tianqi(s) -> bool:
	return s != null and XTianqi.active(s)


# ==== 成就 ====

## XAchievement._ensure 并进来的定义：{编号: 原版插件同格式的字段}。活动总开关关着时不并（和称号一样「整件不存在」；成就记录留在配置里，开回来照显示）
static func achievement_defs() -> Dictionary:
	var out := {}
	if not XFest.ENABLED:
		return out
	for a in XFestText.ACHIEVEMENTS:
		var id := int(ACHIEVEMENT_IDS.get(str(a.key), 0))
		if id > 0:
			out[id] = {"AcName": str(a.name), "AcType": ACHIEVEMENT_TYPE, "AcIconId": int(ACHIEVEMENT_ICONS.get(str(a.key), 0)),
				"AcTriggerT": str(a.desc), "AcShowText": ""}
	return out


static func achieve(s, key: String) -> void:
	if s != null and ACHIEVEMENT_IDS.has(key):
		XAchievement.reward(int(ACHIEVEMENT_IDS[key]), s)


# ==== 签到 ====

static func sign_days(s) -> int:
	return int(XFest.data(s).get("sign_days", 0)) if s != null else 0


## 今天能不能签：活动进行中、重制版存档、还没满 3 天、今天没签过
static func can_sign(s) -> bool:
	return s != null and XFest.active() and not tianqi(s) and sign_days(s) < SIGN_COINS.size() \
		and str(XFest.data(s).get("sign_last", "")) != XFest.today()


## 签一次。返回 {ok, day, coins, title(bool)}；不能签返回 ok=false 和 why（"today"／"full"／"closed"）
static func sign_in(s) -> Dictionary:
	if s == null or not XFest.active() or tianqi(s):
		return {"ok": false, "why": "closed"}
	if sign_days(s) >= SIGN_COINS.size():
		return {"ok": false, "why": "full"}
	var d := XFest.data(s)
	if str(d.get("sign_last", "")) == XFest.today():
		return {"ok": false, "why": "today"}
	var day := sign_days(s) + 1
	d["sign_days"] = day
	d["sign_last"] = XFest.today()
	var coins := int(SIGN_COINS[day - 1])
	XFest.add_coins(s, coins)
	var title := false
	if day >= SIGN_COINS.size():
		title = not XDesignation.unlocked(XFest.TITLE_ATTEND)
		XFest.unlock_title(XFest.TITLE_ATTEND)
		achieve(s, "attend")
	return {"ok": true, "day": day, "coins": coins, "title": title}


# ==== 贺礼 ====

## 出战队伍（没有就全队）里的最高等级
static func top_level(s) -> int:
	var list: Array = s.battle_members() if not s.battle_members().is_empty() else s.members()
	return list.reduce(func(acc, a): return maxi(acc, int(a.level)), 1)


## 按等级挑一种副本挑战符文
static func rune_item(s) -> int:
	var lv := top_level(s)
	for r in RUNES:
		if lv < int(r[0]):
			return int(r[1])
	return int(RUNES.back()[1])


static func _item_name(id: int) -> String:
	return str(XDB.rec("Items", id).get("name", ""))


## 贺礼（重制版存档）：每个存档一次。返回提示条文字（发过返回 ""）
static func gift(s) -> String:
	var d := XFest.data(s)
	if bool(d.get("envoy_gift", false)):
		return ""
	d["envoy_gift"] = true
	XFest.add_coins(s, GIFT_COINS)
	s.gain_gold(GIFT_GOLD)
	var items := "、精魂 ×%d" % GIFT_GOLD
	var rune := rune_item(s)
	s.gain_item(rune, GIFT_RUNES)
	items += "、%s ×%d" % [_item_name(rune), GIFT_RUNES]
	for it in GIFT_ITEMS:
		s.gain_item(int(it[0]), int(it[1]))
		items += "、%s ×%d" % [_item_name(int(it[0])), int(it[1])]
	return XFestText.ENVOY_GIFT_TOAST.replace("{coins}", str(GIFT_COINS)).replace("{items}", items)


## 天启篇存档的纪念品：称号「冠军观赛团」＋成就「我在现场」，每个存档一次。返回提示条文字（给过返回 ""）
static func tianqi_gift(s) -> String:
	var d := XFest.data(s)
	if bool(d.get("envoy_gift", false)):
		return ""
	d["envoy_gift"] = true
	XFest.unlock_title(XFest.TITLE_WATCH)
	achieve(s, "scene")
	return XFestText.ENVOY_TIANQI_TOAST.replace("{title}", str(XFestText.TITLE_TEXTS[XFest.TITLE_WATCH].name))


# ==== 兑换店 ====

static func shop_row(key: String) -> Dictionary:
	for r in SHOP:
		if str(r.key) == key:
			return r
	return {}


static func bought(s, key: String) -> int:
	var b = XFest.data(s).get("shop")
	return int((b as Dictionary).get(key, 0)) if b is Dictionary else 0


## 还能换几次（不限的返回 -1）
static func left(s, key: String) -> int:
	var r := shop_row(key)
	if r.is_empty():
		return 0
	if int(r.limit) <= 0:
		return -1
	return maxi(0, int(r.limit) - bought(s, key))


## 兑换店开不开：重制版存档、活动进行中或收尾期
static func shop_open(s) -> bool:
	return s != null and XFest.visible() and not tianqi(s)


## 换 n 份。返回 "" 成功；否则返回原因（"closed"／"sold_out"／"coins"／"bad"），什么都不动
static func buy(s, key: String, n := 1) -> String:
	var r := shop_row(key)
	if r.is_empty() or n <= 0:
		return "bad"
	if not shop_open(s):
		return "closed"
	var l := left(s, key)
	if l >= 0 and l < n:
		return "sold_out"
	var cost := int(r.price) * n
	if XFest.coins(s) < cost:
		return "coins"
	XFest.add_coins(s, -cost)
	var d := XFest.data(s)
	if not d.get("shop") is Dictionary:
		d["shop"] = {}
	d.shop[key] = bought(s, key) + n
	_deliver(s, key, n)
	return ""


static func _deliver(s, key: String, n: int) -> void:
	match key:
		"title":
			XFest.unlock_title(XFest.TITLE_WATCH)
		"rune":
			s.gain_item(rune_item(s), 2 * n)
		"ticket":
			s.gain_item(TICKET, 10 * n)
		"shard":
			s.gain_item(SHARD, 4 * n)
		"party":
			s.gain_item(PARTY, 2 * n)
		"gold":
			s.gain_gold(GOLD_PER * n)


# ==== 读档 ====

## 收尾期已经过了（活动日期写错时不算）
static func ended() -> bool:
	var i := XFest.day_index()
	return i != -9999 and i > XFest.DAYS + XFest.GRACE_DAYS


## 剩币按兜底价换成精魂（收尾期过后）。返回 [换掉的币, 精魂]；没有可换的返回 [0, 0]
static func convert_leftover(s) -> Array:
	if s == null or not ended():
		return [0, 0]
	var c := XFest.coins(s)
	var n := c / GOLD_PRICE
	if n <= 0:
		return [0, 0]
	XFest.add_coins(s, -n * GOLD_PRICE)
	s.gain_gold(n * GOLD_PER)
	XFest.data(s)["leftover_done"] = true
	return [n * GOLD_PRICE, n * GOLD_PER]


## 读档后（XSave._load_data）：称号迁移、剩币自动换、当天第一次读档的提醒。提示条攒到进地图时再放（map_start）
static func after_load(s) -> void:
	_pending.clear()
	if s == null:
		return
	if XDesignation.unlocked(XFest.TITLE_ROAD_HARD) and not XDesignation.unlocked(XFest.TITLE_ROAD):
		XDesignation.unlock(XFest.TITLE_ROAD)  # 45 并进 41（v0.3.1 第 7 节第 1 条）
	var got := convert_leftover(s)
	if int(got[0]) > 0:
		_pending.append(XFestText.LEFTOVER_TOAST.replace("{coins}", str(got[0])).replace("{gold}", str(got[1])))
	var msg := remind_text(s)
	if msg != "":
		_reminded_day = XFest.today()
		_pending.append(msg)


## 今天要不要提醒（活动进行中、这次运行今天还没提醒过）；要就返回文字
static func remind_text(s) -> String:
	if s == null or not XFest.active() or _reminded_day == XFest.today():
		return ""
	if tianqi(s):
		return "" if bool(XFest.data(s).get("envoy_gift", false)) else XFestText.REMIND_TOAST_TIANQI
	return XFestText.REMIND_TOAST


## 地图场景建好（map_scene，读档提示之后）：放出读档时攒下的提示
static func map_start() -> void:
	for m in _pending:
		XToast.show_text(str(m))
	_pending.clear()


## 测试看
static func pending() -> Array:
	return _pending.duplicate()


# ==== 使者菜单（XFestLobby._menu 调）====

## 当前存档能用的附加项：[{label, act}]（act：sign／shop）
static func menu(s) -> Array:
	var out := []
	if s == null or tianqi(s):
		return out
	if XFest.active():
		out.append({"label": XFestText.SIGN_MENU, "act": "sign"})
	if shop_open(s):
		out.append({"label": XFestText.SHOP_MENU, "act": "shop"})
	return out


static func run_menu(interp, act: String) -> void:
	var s := XState.current
	match act:
		"sign":
			await _sign(interp, s)
		"shop":
			await _shop(interp, s)


static func _sign(interp, s) -> void:
	var r := sign_in(s)
	if not bool(r.ok):
		await XFestLobby.say(interp, XFestText.SIGN_FULL if str(r.why) == "full" else XFestText.SIGN_DONE_TODAY)
		return
	interp.host.toast(XFestText.SIGN_OK.replace("{day}", str(r.day)).replace("{coins}", str(r.coins)).replace("{total}", str(XFest.coins(s))))
	if bool(r.title):
		interp.host.toast(XFestText.SIGN_TITLE)


static func _row_text(s, r: Dictionary) -> String:
	var l := left(s, str(r.key))
	var tail := "" if l < 0 else (XFestText.SHOP_SOLD_OUT if l == 0 else XFestText.SHOP_LEFT.replace("{n}", str(l)))
	return XFestText.SHOP_ROW.replace("{name}", str(XFestText.SHOP_NAMES[r.key])).replace("{price}", str(r.price)).replace("{left}", tail)


static func _shop(interp, s) -> void:
	while interp.host_alive():
		await XFestLobby.say(interp, [["庆典使者", XFestText.SHOP_GREET.replace("{coins}", str(XFest.coins(s)))]])
		var opts: Array = SHOP.map(func(r): return _row_text(s, r))
		opts.append(XFestText.SHOP_BACK)
		var pick := await XFestLobby.choose(interp, opts)
		if pick < 0 or pick >= SHOP.size():
			return
		var r: Dictionary = SHOP[pick]
		var key := str(r.key)
		var n := 1
		await XFestLobby.say(interp, [["庆典使者", str(XFestText.SHOP_HELP[key])]])
		if key == "gold":
			var all := XFest.coins(s) / GOLD_PRICE
			var gopts := [XFestText.GOLD_ONE, XFestText.GOLD_ALL.replace("{coins}", str(all * GOLD_PRICE)).replace("{gold}", str(all * GOLD_PER)), XFestText.SHOP_CANCEL]
			var g := await XFestLobby.choose(interp, gopts)
			if g == 1:
				n = maxi(1, all)
			elif g != 0:
				continue
		else:
			var c := await XFestLobby.choose(interp, [XFestText.SHOP_CONFIRM, XFestText.SHOP_CANCEL])
			if c != 0:
				continue
		var why := buy(s, key, n)
		match why:
			"":
				interp.host.toast(XFestText.SHOP_OK.replace("{name}", str(XFestText.SHOP_NAMES[key]) + ("" if n == 1 else " ×%d" % n)).replace("{coins}", str(XFest.coins(s))))
			"sold_out":
				await XFestLobby.say(interp, XFestText.SHOP_SOLD_OUT_LINE)
			"coins":
				await XFestLobby.say(interp, XFestText.SHOP_NO_COINS)
			_:
				return
