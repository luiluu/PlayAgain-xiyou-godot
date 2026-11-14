class_name XTianqiSave
extends RefCounted
## 【cc·未经审查】天启篇存档门面（架构二第五节「存档门面」；方案见 cc/save-rng-facade 交付单）。flags.tianqi 的分区登记、默认值、版本与迁移。
##
## 规矩（车道须知短表「存档字段写哪」的目标写法）：
## - 新存档字段放 flags.tianqi.<分区> 一个字典里，先在下面 SECTIONS 登记一行（版本、归谁）；根上的散键只认 ROOT_KEYS，
##   计数类认 COUNTER_KEYS；flags 顶层归天启篇的认 OUTSIDE_KEYS。没登记的键 07_开发环境/天启篇存档登记.py 会报。
## - 取分区一律 section(s, 名)：缺了按默认建、记现行版本；缺键按默认补（_fill，逐行直呼各模块的补法）。
##   只想看「有没有」（有没有账就是判断条件的，如招牌掉落「没账不新建」）用 peek(s, 名)，不建。
## - 分区不在读档时一次建全：用到时才建（lazy）。读档只给已经存在的分区跑迁移。
## - 版本：一般分区记在 flags.tianqi.v[名]；登记了 vkey 的分区（五条悟 gojo_adv_v、难度被动 no_diff_passive）沿用模块原来的
##   标记键存版本，门面只是统一读写和一处看全（versions）——不搬标记，开关回退时模块旧写法照样认。
## - 读档后入口：after_load(s)，挂在 XState.from_dict 末尾（to_dict→from_dict 的测试也走得到）。按 SECTIONS 次序，
##   对已存在的分区「档里版本 < 现行版本」就跑迁移，跑完记现行版本；关了开关的模块跑它的反迁移（revert）。幂等，读两次和读一次一样。
##   难度被动的剥／补仍在 XState.sync_difficulty_after_load（要在角色能力刷新之前），门面只登记它的版本。
##   要存档原文或存档位的（五条悟试炼现场还原、星辰仓库取出事务）留在 XSave._load_data。
## - 装备上的键登记在 GEAR_KEYS：copy＝false 的在复制装备（魔冠重发、云裳发货、仓库原版复制）时由 strip_on_copy 去掉。
## 开关（O-待定）：ENABLED＝false 时 after_load 不跑迁移、section 不记版本（各模块取分区时照旧就地补，结果相同）。

static var ENABLED := true

const VKEY := "v"

## 分区登记：名 → {v 现行版本, owner 归谁, vkey 版本存在哪个键（缺省记在 v[名]）, keys 归这个分区的根上散键（老键，不搬）}
## 次序就是 after_load 的迁移次序。迁移 v0→v1 一律就是「缺键按默认补」，结果与各模块原来的就地补逐键相同。
const SECTIONS := {
	"war": {"v": 1, "owner": "XTianqiLine"},
	"famine": {"v": 1, "owner": "XTianqiLine"},
	"plague": {"v": 1, "owner": "XTianqiLine"},
	"death": {"v": 1, "owner": "XTianqiLine"},
	"famine_prologue": {"v": 1, "owner": "XTianqiFamineLine", "array": true},
	"summit": {"v": 1, "owner": "XTianqiSummit"},
	"weak_clear": {"v": 1, "owner": "XTianqiWeakClear"},
	"rewards": {"v": 1, "owner": "XTianqiRewards"},
	"qiyin": {"v": 1, "owner": "XTianqiQiyin"},
	"drop": {"v": 1, "owner": "XTianqiDrop"},
	"elements": {"v": 1, "owner": "XTianqiElements"},
	"money": {"v": 1, "owner": "XTianqiMoney"},
	"trumpet": {"v": 1, "owner": "XTianqiTrumpet"},
	"skill_grow": {"v": 1, "owner": "XTianqiSkills"},
	"no_diff_passive": {"v": 1, "owner": "XTianqiNoDiffPassive", "vkey": "no_diff_passive"},
	"gojo": {"v": 3, "owner": "XTianqiGojoTrial", "vkey": "gojo_adv_v", "keys": ["gojo_trials"]},
}
## 已接进门面（section／after_load 管迁移）的分区；其余只登记，模块里照旧就地补（S2 批逐个接）
const WIRED := ["qiyin", "drop", "gojo"]
## 根上的散键（开局写一次或单值）：rules 规则版本、difficulty、lineup、line、draws／offer 抽角色、reincarnate
const ROOT_KEYS := ["rules", "difficulty", "lineup", "line", "draws", "offer", "reincarnate", VKEY]
## 根上的随机计数（随机门面 XTianqi.save_stream 一族，cc/tianqi-seed-fix）：不搬位置，老档缺当 0
const COUNTER_KEYS := ["affix_roll_n", "affix_src_n", "src_n"]
## flags 顶层归天启篇的键（不在 tianqi 区里）：_gojoTrial 进行中的五条悟试炼
const OUTSIDE_KEYS := ["_gojoTrial"]

## 装备字典上的天启篇键：键 → {owner 归谁, copy 复制装备时带不带走}
const GEAR_KEYS := {
	"tianqi_affixes": {"owner": "XTianqiAffixRoll", "copy": true},
	"tianqi_prefix": {"owner": "XTianqiAffixRoll", "copy": true},
	"tianqi_desc_base": {"owner": "XTianqiAffixRoll", "copy": true},
	"qiyin": {"owner": "XTianqiQiyinEquip", "copy": true},
	"tq_reward": {"owner": "XTianqiRewards", "copy": true},
	"tq_reforges": {"owner": "XTianqiMoney", "copy": true},
	"tq_bought": {"owner": "XTianqiDrop", "copy": true},
	"tq_buy_price": {"owner": "XTianqiDrop", "copy": true},
	"tq_seed_id": {"owner": "XTianqi", "copy": false},  # 随机身份（cc/tianqi-seed-fix）：复制品另拿新号
	"tq_rng_n": {"owner": "XTianqi", "copy": false},  # 装备上的随机计数：复制品从 0 起
}


static func registered(name: String) -> bool:
	return SECTIONS.has(name)


static func wired(name: String) -> bool:
	return ENABLED and WIRED.has(name)


## 天启篇区：天启篇档（XTianqi.active）返回 flags.tianqi 本体；否则返回不落盘的空表
static func root(s: XState) -> Dictionary:
	if s != null and XTianqi.active(s):
		return s.flags.tianqi
	return {}


## 只看不建：分区不存在返回 null
static func peek(s: XState, name: String):
	if s == null or not s.flags.get("tianqi") is Dictionary:
		return null
	var v = s.flags.tianqi.get(name)
	return v if v is Dictionary or v is Array else null


## 取分区：缺了按默认建并记现行版本，缺键按默认补。非天启篇档（没有 flags.tianqi）返回不落盘的空分区
static func section(s: XState, name: String) -> Dictionary:
	assert(SECTIONS.has(name), "XTianqiSave: 未登记的分区 " + name)
	if s == null or not s.flags.get("tianqi") is Dictionary:
		var tmp := {}
		_fill(s, name, tmp, true)
		return tmp
	var tq: Dictionary = s.flags.tianqi
	var made := false
	if not tq.get(name) is Dictionary:
		tq[name] = {}
		made = true
	var d: Dictionary = tq[name]
	_fill(s, name, d, made)
	if made and ENABLED and not SECTIONS[name].has("vkey"):
		set_version(s, name, int(SECTIONS[name].v))
	return d


## 档里这个分区的版本（没有记录＝0）
static func version(s: XState, name: String) -> int:
	if s == null or not s.flags.get("tianqi") is Dictionary:
		return 0
	var tq: Dictionary = s.flags.tianqi
	var row: Dictionary = SECTIONS.get(name, {})
	if row.has("vkey"):
		return int(tq.get(str(row.vkey), 0))
	var vs = tq.get(VKEY)
	return int(vs.get(name, 0)) if vs is Dictionary else 0


static func set_version(s: XState, name: String, v: int) -> void:
	if s == null or not s.flags.get("tianqi") is Dictionary:
		return
	var tq: Dictionary = s.flags.tianqi
	var row: Dictionary = SECTIONS.get(name, {})
	if row.has("vkey"):
		tq[str(row.vkey)] = v
		return
	if not tq.get(VKEY) is Dictionary:
		tq[VKEY] = {}
	tq[VKEY][name] = v


## 一处看全：本档各分区 → 版本（只列存在的分区和有标记的）
static func versions(s: XState) -> Dictionary:
	var out := {}
	if s == null or not s.flags.get("tianqi") is Dictionary:
		return out
	var tq: Dictionary = s.flags.tianqi
	for name in SECTIONS:
		var row: Dictionary = SECTIONS[name]
		if tq.has(name) or (row.has("vkey") and tq.has(str(row.vkey))):
			out[name] = version(s, name)
	return out


## 唯一的读档后入口（XState.from_dict 末尾）。幂等
static func after_load(s: XState) -> void:
	if not ENABLED or s == null or not XTianqi.active(s):
		return
	var tq: Dictionary = s.flags.tianqi
	for name in SECTIONS:
		if not WIRED.has(name):
			continue
		match name:
			"gojo":
				XTianqiGojoTrial.migrate(s)  # 自带版本（vkey）、档型判断和关开关反迁移；以前在 XSave._load_data
			_:
				if tq.get(name) is Dictionary and version(s, name) < int(SECTIONS[name].v):
					_fill(s, name, tq[name], false)
					set_version(s, name, int(SECTIONS[name].v))


## 缺键按默认补（逐行直呼各模块；结果与模块原来的就地补逐键相同）。made＝这个分区是刚建的空表
static func _fill(s: XState, name: String, d: Dictionary, made: bool) -> void:
	match name:
		"qiyin":
			XTianqiQiyin.fill(s, d)
		"drop":
			XTianqiDrop.fill(s, d, made)


## 复制装备时去掉 copy＝false 的键（复制品另拿随机身份）
static func strip_on_copy(item) -> void:
	if not item is Dictionary:
		return
	for k in GEAR_KEYS:
		if not bool(GEAR_KEYS[k].copy):
			item.erase(k)
