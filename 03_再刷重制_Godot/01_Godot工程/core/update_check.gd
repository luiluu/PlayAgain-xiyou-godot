class_name XUpdateCheck
extends RefCounted
## 自动更新第①批（Kyo 2026-11-11 批准；方案见私密仓库 重制设定/重制版_自动更新方案_v0.2.md）：
## 版本清单（channel.json）的验签、版本比较和「该提示什么」的判断。全是纯函数，不联网、不读写文件；
## 联网在 XUpdateClient，界面在 XUpdatePage。
##
## 清单格式（schema 1）：
##   {"schema": 1,
##    "latest": {"version": "0.470", "code": 470, "date": "2026-11-20", "notes": ["……"]},
##    "bases": {"453": {"patch": {"code": 470, "size": 123, "sha256": "…", "urls": ["…"]}}},
##    "min_base": 453, "revoked": [468]}
## 同目录的 channel.sig 是对 channel.json 原始字节的 SHA256withRSA 签名（PKCS#1 v1.5，`openssl dgst -sha256 -sign` 的输出）。
## 公钥写在这里；私钥只在 Kyo 的 Mac 上仓库之外，不进任何仓库。验签不过的清单一律当读不到。

const SCHEMA := 1
const PUBLIC_KEY := """-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv9EIRElfaFHqp5aAlHyI
wzU/7YoiD0E7ftj4WVS5nufJkJFOKhnzT2596xhUaNW2m2j2gA7RJP6FFQtVzr3F
5O730zdYwwtbeAh/EXRhz8sMg5pKQtUH186a5aWU90J9ANwjGNQIZAx/zLy+n5uD
3qNE3/xFbfC5Pu+D8uQcu0KhhjiDCwUSEZRUye7tlaT5xXlwN56qxempPhf6ipaV
XMaVjULjb9I7QcjkMeWS19tCu2o4/hWCVpWLQvKGkmAGCLBE0PLaw/BGXoGChEDT
4BofCQK9nCwOsMn2DuEOpK5Lj3IIN6nFVCuDPmJfJ6VV98IciitSbKQ6jOuxD018
uBaARf5SYTDP8m5YIhKqvyKvp17ode6nCjHv0aRCEPqh1Ph+wJ4PNcj1B6bAT1CW
+3wHqLqM8xB09+OroPm0KYF9JGV8MroyHVbTwE0umpJqRMOvsQqo4myypRUT7Zf+
RePBWuuZ54b+TvKNe9C2K1zyWPBIEc6QP27ZOcxD2cU6YytCvW6/F7ojVuWjsFWS
+lZi2hCzErPTBX+idAyKqQ7SOlN7KAe3VT8p7o8i8vv+dh7NXjXtySc8+IuG21PU
d0HpaovaEJPUEhw+9hP6sGyxTfOlAu1n89UmcLYVLrMl8Z2YHwAjmdX7paA84GZG
akk2RNB99i+gyZxyxyvEbwsCAwEAAQ==
-----END PUBLIC KEY-----
"""

## 判断结果的 state
const LATEST := "latest"   # 已是最新
const PATCH := "patch"     # 有能在游戏内装的补丁
const FULL := "full"       # 要换整包（去 QQ 群）
const BAD := "bad"         # 读不到、验签不过或格式坏


## 版本号按段比较（0.62.12 < 0.62.13 < 0.63.0；0.9 < 0.10），不是按字符串比。开头的 v 去掉；缺的段当 0；非数字段当 0。
## 返回 -1／0／1。
static func compare_versions(a: String, b: String) -> int:
	var pa := a.strip_edges().trim_prefix("v").trim_prefix("V").split(".")
	var pb := b.strip_edges().trim_prefix("v").trim_prefix("V").split(".")
	for i in range(maxi(pa.size(), pb.size())):
		var x := (pa[i].to_int() if i < pa.size() and pa[i].is_valid_int() else 0)
		var y := (pb[i].to_int() if i < pb.size() and pb[i].is_valid_int() else 0)
		if x != y:
			return -1 if x < y else 1
	return 0


## 开发编号 → 玩家看到的版本号（Mac／Windows 0.<号>，安卓 versionCode＝号）。
static func version_of(code: int) -> String:
	return "0.%d" % code


## 验签：sig 是对 json_bytes 的 SHA256withRSA 签名。公钥可换，给测试用。
static func verify(json_bytes: PackedByteArray, sig: PackedByteArray, public_key_pem: String = PUBLIC_KEY) -> bool:
	if json_bytes.is_empty() or sig.is_empty() or not public_key_pem.strip_edges().begins_with("-----BEGIN PUBLIC KEY-----"):
		return false
	var key := CryptoKey.new()
	if key.load_from_string(public_key_pem, true) != OK:
		return false
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(json_bytes)
	return Crypto.new().verify(HashingContext.HASH_SHA256, ctx.finish(), sig, key)


## 解析清单文本；格式不对返回空字典（不打引擎报错）。
static func parse(json_text: String) -> Dictionary:
	var j := JSON.new()
	if j.parse(json_text) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = j.data
	if int(d.get("schema", 0)) != SCHEMA or typeof(d.get("latest")) != TYPE_DICTIONARY:
		return {}
	var latest: Dictionary = d["latest"]
	if int(latest.get("code", 0)) <= 0 or not (latest.get("version") is String):
		return {}
	return d


## 几个源各自读到的清单里，挑验签通过、版本最高的一份。sources：[{ "json": PackedByteArray, "sig": PackedByteArray }]。
## 都不行返回空字典。
static func pick_best(sources: Array, public_key_pem: String = PUBLIC_KEY) -> Dictionary:
	var best := {}
	for s in sources:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var raw: PackedByteArray = s.get("json", PackedByteArray())
		if not verify(raw, s.get("sig", PackedByteArray()), public_key_pem):
			continue
		var d := parse(raw.get_string_from_utf8())
		if d.is_empty():
			continue
		if best.is_empty() or _newer(d["latest"], best["latest"]):
			best = d
	return best


static func _newer(a: Dictionary, b: Dictionary) -> bool:
	var c := compare_versions(str(a["version"]), str(b["version"]))
	return c > 0 or (c == 0 and int(a["code"]) > int(b["code"]))


## 该提示什么。manifest 是 parse／pick_best 的结果（空＝读不到）；base_code 是安装包自带的开发编号，
## current_code 是现在实际运行的（装了补丁就是补丁的号）。
## 返回 {"state", "current", "version", "code", "date", "notes", "patch", "revoked"}：
##   current／version 是给玩家看的版本号；patch 只在 state＝patch 时非空（code、size、sha256、urls）；
##   revoked＝现在运行的这一版被撤回了（第②批用它自动退回）。
static func evaluate(manifest: Dictionary, base_code: int, current_code: int) -> Dictionary:
	var out := {"state": BAD, "current": version_of(current_code), "version": "", "code": 0, "date": "",
		"notes": PackedStringArray(), "patch": {}, "revoked": false}
	if manifest.is_empty():
		return out
	var latest: Dictionary = manifest["latest"]
	out["version"] = str(latest["version"])
	out["code"] = int(latest["code"])
	out["date"] = str(latest.get("date", ""))
	var notes := PackedStringArray()
	if typeof(latest.get("notes")) == TYPE_ARRAY:
		for n in latest["notes"]:
			if n is String:
				notes.append(n)
	out["notes"] = notes
	if typeof(manifest.get("revoked")) == TYPE_ARRAY:
		for r in manifest["revoked"]:
			if int(r) == current_code and current_code != base_code:
				out["revoked"] = true
	if compare_versions(out["version"], out["current"]) <= 0:
		out["state"] = LATEST
		return out
	out["state"] = FULL
	if base_code < int(manifest.get("min_base", 0)):
		return out
	var bases = manifest.get("bases")
	if typeof(bases) != TYPE_DICTIONARY or typeof(bases.get(str(base_code))) != TYPE_DICTIONARY:
		return out
	var p = bases[str(base_code)].get("patch")
	if not valid_patch(p) or int(p["code"]) <= current_code:
		return out
	out["state"] = PATCH
	out["patch"] = {"code": int(p["code"]), "size": int(p["size"]), "sha256": str(p["sha256"]).to_lower(), "urls": p["urls"].duplicate()}
	return out


## 补丁条目是否完整：编号、字节数为正，SHA-256 是 64 位十六进制，至少一个 https 地址。
static func valid_patch(p: Variant) -> bool:
	if typeof(p) != TYPE_DICTIONARY:
		return false
	if int(p.get("code", 0)) <= 0 or int(p.get("size", 0)) <= 0:
		return false
	var sha = p.get("sha256")
	if not (sha is String) or sha.length() != 64 or not sha.is_valid_hex_number():
		return false
	var urls = p.get("urls")
	if typeof(urls) != TYPE_ARRAY or urls.is_empty():
		return false
	for u in urls:
		if not (u is String) or not u.begins_with("https://"):
			return false
	return true
