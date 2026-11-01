class_name MVScript
extends RefCounted
## 事件脚本（MV 指令 355/655 的 JavaScript）的翻译：不执行 JS，只认正式版里出现过的写法，按语义改成 Godot 版操作。
## 认不出的语句原样记进解释器的 skipped，便于之后逐条补齐。目前认得：
## - 所有角色学会/忘记技能的循环（$dataActors.length 带或不带名字检查、j < 999、按 ID 列表 forEach、列表外的角色）→ XState.add_actor_op；
##   `$gameActors.length+1` 的循环（length 未定义，原版一次也不执行）→ 无操作。
## - 固定存档位存档：$gamePlayer.SaveGameId = N; DataManager.saveGame(...) 成功/失败分支（音效与提示）。
## - $gamePlayer.SaveActorName = prompt(提示, 默认) → 输入名字窗口。
## - $.toaster({message: '...'}) → 右上角提示；$gameParty.gainItem($dataItems[$gameVariables.value(N)], n) 与对应的提示。
## - $gameParty.DCultyL1～8 等标记、ConfigManager 界面选项（无对应设置，忽略）、$gameSystem.onBeforeSave()（无操作）、
##   Star_RomGetItems 的 RomGet 预掷池初始化。
## - v0.27 轮回入口（installReincarnationRandomRuntime）：CodexReincarnationRandom.open(this) → 选「轮回普通／困难」再选阵容规则；
##   条件 entryAccepted()／entryHard() 读选择结果；finishEntry() 无操作。随机角色模式暂不开放（O-035），菜单只列「常规阵容」。
## - $gameVariables.setValue(N, 数字) → XState.set_variable（跨存档变量 900／899／1476 靠它存进 XGlobalVars）。
## - 副本 Boss 奖励（CE1439）：CodexEconomy.bossReward、CodexOrbs.rollInt、CodexV010Fixes.rewardNotice／awardQuantity、
##   甚尔／宿傩 rollAdvanceStone（见 XDungeon）；洪荒的 grantTicketBonus／rollPower 在非洪荒难度无操作。
## - 修炼：Star.ActorAttributePlusPoints.XiuLian = [...] → XTraining.xiulian；SceneManager.push(Scene_ActorAttributePlusPoints) → 修炼界面（host.open_training）。
## - 成就：Star.AchievementSystem.GetAcReward(N) → XAchievement.reward；SceneManager.push(Scene_AchievementBook) → 成就界面（host.open_achievements）。
## - 装备镶嵌图鉴：SceneManager.push(Scene_EquipInlayBook) → host.open_inlay_book（XInlayBook）。
## - 角色仓库：SceneManager.push(Star_Scene_ActorWarehouse) → host.open_actor_warehouse（XActorWarehouse）。
## - 星级仓库：SceneManager.push(Scene_StarSaveWarehouse／Scene_StarWarehouse) → host.open_star_warehouse(存放?)（XStarWarehouse）。
## - 更衣：if(ConfigManager.ChangeClothesLite.indexOf(N) == -1){ ConfigManager.ChangeClothesLite.push(N); } → XChangeClothes.unlock；
##   SceneManager.push(Scene_ChangeClothes) → host.open_change_clothes（XChangeClothes）。
## - 角色进阶：SceneManager.push(Scene_ActorAdvanced) → host.open_actor_advanced（XAdvance）。
## - 魔兽要诀：Star.PetSystem.ComEveLearnSkill(N) → XPets.learn_book（出战宠物学技能，提示走 host.toast）。
## - 已移除地图提示：CodexMapRemoval.notice(N) → 文字「【区域已移除】…」（Map080 王座宝箱，见 MVInterpreter.removed_gate_fix）。

const _NAMED := "\\$dataActors\\[j\\]\\.name\\s*!==?\\s*['\"]{2}"
## 正式版移除的地图（Codex_StabilityPerformancePatch 1.1）：地图 ID → 名字
const REMOVED_MAPS := {103: "巨人山脉", 108: "深渊:魔神之渊"}
## CodexReincarnationRandom.entry：open 之后的选择结果 {accepted, hard}
static var reincarnation_entry := {}
## 编译好的正则（按模式串缓存）：脚本每条语句都要试一遍全部写法，不再逐条现编译
static var _re_cache := {}


static func _re(pattern: String) -> RegEx:
	var r: RegEx = _re_cache.get(pattern)
	if r == null:
		r = RegEx.create_from_string(pattern)
		_re_cache[pattern] = r
	return r


## installBossDifficultyRuntime 的 D.recruitments（角色, 号角物品, 模块）：这些模块的 recruit() 外面包了一层——角色是超强者且没开
## 挑战（XItemMarks.can_acquire_actor 为假）就提示「超强者仅限地狱及以上难度获取。」并返回 false，模块本身不跑。
## 谷雨／屠苏／璇的号角脚本写 X.ids().horn（模块按物品名现找），这里取同一张表里的号角号。
const _RECRUITMENTS := {"CodexRaven": [167, 2902], "CodexMira": [168, 2904], "CodexYomi": [169, 2931], "CodexJingliu": [170, 2932],
	"CodexToji": [171, 2936], "CodexSukuna": [172, 2938], "CodexGarou": [173, 2940], "CodexYunshang": [174, 2941], "Guyu": [175, 2943],
	"CodexTusu": [176, 2945], "CodexXuan": [177, 2946]}


## 包装那一层：挡下时提示并返回 true（recruit() 视为返回 false）
static func _recruit_blocked(module: String, interp) -> bool:
	if not _RECRUITMENTS.has(module) or XItemMarks.can_acquire_actor(XState.current, int(_RECRUITMENTS[module][0])):
		return false
	interp.host.toast(XItemMarks.SUPER_NOTICE)
	return true


## 角色在队且达到等级（openCrafting／startTrial 的前置）
static func _actor_ready(s: XState, actor_id: int, level: int) -> bool:
	return s.party.has(actor_id) and s.actor(actor_id).level >= level


## 专属角色模块的 recruit()：返回 func(s, interp) -> bool（入队了为 true）；认不得的模块返回空 Callable
static func _module_recruit(module: String) -> Callable:
	match module:
		"CodexGarou":
			return func(s: XState, interp) -> bool:
				if not XGarou.recruit(s):
					return false
				await interp.host.show_text("", 0, [XGarou.RECRUIT_TEXT])  # $gameMessage.add
				return true
		"CodexToji":
			return func(s: XState, interp) -> bool:
				var lines := XToji.recruit(s)
				for line in lines:
					interp.host.toast(line)  # $.toaster
				return not lines.is_empty()
		"Guyu":
			return func(s: XState, interp) -> bool:
				var text := XGuyu.recruit(s)
				if text != "":
					interp.host.toast(text)  # $.toaster
				return text != ""
		"CodexSukuna":
			return func(s: XState, interp) -> bool:
				if not XSukuna.recruit(s):
					return false
				interp.host.toast(XSukuna.RECRUIT_TEXT)  # $.toaster
				return true
	return Callable()


## 执行一段脚本；返回认不出的语句（空数组表示全部认得）。
static func run(code: String, interp) -> Array:
	var js := _strip_comments(code).strip_edges()
	if js == "":
		return []
	var s := XState.current
	# CE1317: selected actor is shared with the item-effect capacity check.
	if js == "var actor = $gameActors.actor($gameParty._targetActorId);\n$.toaster({ message : ''+actor.name()+' 能学习的抽奖被动技能已经达到'+$gameVariables.value(9)+'上限！'});":
		interp.host.toast(XPassiveBooks.limit_message(s))
		return []
	# ---- 整段写法 ----
	if js == "Star.RunForgetSkill();":  # 遗忘河之水 CE83：选中角色的遗忘界面（Star_Scene_ForgetSkill）
		if interp.host.has_method("open_forget_skill"):
			await interp.host.open_forget_skill(s.item_target_actor_id)
		return []
	# 藏宝图（Star.RomGetItems.RunGetFun，CE117、174～189、1381～1384）：见 XTreasureMap
	var dig := _re("^Star\\.RomGetItems\\.RunGetFun\\((\\d+)\\s*,\\s*(\\d+)\\);?$").search(js)
	if dig:
		var r := XTreasureMap.run(s, int(dig.get_string(1)), int(dig.get_string(2)))
		for t in r.toasts:
			interp.host.toast(t)
		if int(r.reserve) > 0:
			s.reserve_common_event(int(r.reserve))
		return []
	# 指定一个角色（变量里存角色 ID）学会/忘记技能：var actor = $gameActors.actor($gameVariables.value(N)); [actor.forgetSkill(A);] actor.learnSkill(B);（传承人的学习公共事件 1348～1368）
	var one := _actor_by_variable(js)
	if not one.is_empty():
		var aid := int(s.variable(int(one.variable)))
		if not XDB.rec("Actors", aid).is_empty():
			var who := s.actor(aid)
			for call in one.calls:
				if call[0] == "forgetSkill":
					who.forget_skill(int(call[1]))
				elif call[0] == "removeState":  # 心法 CE1003～1018：学新心法时解除另两种心法状态
					who.remove_state(int(call[1]))
				else:
					who.learn_skill(int(call[1]))
			who.refresh_passive()
		return []
	var loop := _actor_loop(js)
	if not loop.is_empty():
		for op in loop:
			s.add_actor_op(op)
		return []
	# 物品选中的角色（$gameParty._targetActorId）遗忘／学会技能：元素转换、小药丸、滑稽拳、技能书等（见 _target_actor_script）
	if js.contains("$gameParty._targetActorId"):
		var picked = await _target_actor_script(js, interp)
		if picked != null:
			return picked
	if js.contains("$gameActors.length+1") or js.contains("$gameActors.length + 1"):
		return []
	if js.contains("$gameParty.RomGet") and js.contains("Math.random"):
		if s.rom.get("g", []).size() < 35:
			var pool := []
			for i in range(35):
				pool.append(MVInterpreter.random_int(1, 9999, s))
			s.rom.g = pool
			s.rom.gn = 0
		return []
	var roster := _re("^if\\(window\\.CodexBossDifficulty\\)\\{CodexBossDifficulty\\.showRoster\\('(strong|super)'\\);\\}else\\{.*\\}this\\.setWaitMode\\('message'\\);?$").search(js)
	if roster:
		await _boss_roster(roster.get_string(1), interp)
		return []
	# 更衣解锁（Star_ChangeClothes，见 XChangeClothes）：衣橱管理员 Map4 EV17 与各层宝箱、特殊事件，全游戏只这一种写法（CE367 两号不同）
	var lite := _re("^if\\s*\\(\\s*ConfigManager\\.ChangeClothesLite\\.indexOf\\((-?\\d+)\\)\\s*==\\s*-1\\s*\\)\\s*\\{\\s*ConfigManager\\.ChangeClothesLite\\.push\\((-?\\d+)\\);?\\s*\\}$").search(js)
	if lite:
		# 判断号与写入号一般相同；CE367 牛头人酋长写成 indexOf(-33)==-1 才 push(-12)，照原文：-33 不在表里才加 -12
		if not XChangeClothes.unlocked(int(lite.get_string(1))):
			XChangeClothes.unlock(int(lite.get_string(2)))
		return []
	# 专属角色号角（公共事件 9006～9016）：try { if (!X.recruit()) $gameParty.gainItem($dataItems[号角或 X.ids().horn],1); } catch(error) {…}
	# 招募没成功（已在队、超强者门槛挡下）就还号角；catch 分支是脚本出错时的返还，重制不会走到。
	# 模块没移植的（屠苏、璇）只有门槛挡下这一支能照做，放行时照旧算没认出
	var horn := _re("^try\\s*\\{\\s*if\\s*\\(\\s*!\\s*(\\w+)\\.recruit\\(\\)\\s*\\)\\s*\\$gameParty\\.gainItem\\(\\$dataItems\\[(\\d+|\\1\\.ids\\(\\)\\.horn)\\]\\s*,\\s*1\\);?\\s*\\}\\s*catch\\s*\\(\\s*error\\s*\\)\\s*\\{.*\\}$").search(js)
	if horn:
		var module := horn.get_string(1)
		var horn_id := int(horn.get_string(2)) if horn.get_string(2).is_valid_int() else int(_RECRUITMENTS.get(module, [0, 0])[1])
		var recruit := _module_recruit(module)
		if horn_id > 0 and (recruit.is_valid() or _RECRUITMENTS.has(module)):
			if _recruit_blocked(module, interp):
				s.gain_item(horn_id, 1)
				return []
			if recruit.is_valid():
				var joined: bool = await recruit.call(s, interp)
				if not joined:
					s.gain_item(horn_id, 1)
				return []
	var unknown := []
	# 存档分支：if (DataManager.saveGame($gamePlayer.SaveGameId)) { …成功… } else { …失败… }
	var at := js.find("DataManager.saveGame(")
	if at >= 0:
		var if_at := js.rfind("if", at)
		var ok_block := _block(js, js.find("{", at))
		var end: int = ok_block[1]
		var fail := ""
		var tail := js.substr(end).strip_edges()
		if tail.begins_with("else"):
			var fail_block := _block(js, js.find("{", end))
			fail = fail_block[0]
			end = fail_block[1]
		unknown.append_array(await _statements(js.substr(0, if_at), interp))
		var ok: bool = interp.host.save_game(int(s.flags.get("SaveGameId", 0)))
		XSound.system(5 if ok else 3)
		var msg := _toaster_text(ok_block[0] if ok else fail)
		if msg != "":
			interp.host.toast(msg)
		unknown.append_array(await _statements(js.substr(end), interp))
		return unknown
	return await _statements(js, interp)


## 逐条处理简单语句（分号或换行分隔）
static func _statements(js: String, interp) -> Array:
	var s := XState.current
	var unknown := []
	for raw in js.replace("\n", ";").split(";"):
		var st := raw.strip_edges()
		if st == "" or st == "}" or st == "{":
			continue
		var m := _re("^\\$gameParty\\.(DCultyL\\d+)\\s*=\\s*(true|false)$").search(st)
		if m:
			s.flags[m.get_string(1)] = m.get_string(2) == "true"
			continue
		m = _re("^\\$gamePlayer\\.SaveGameId\\s*=\\s*(\\d+)$").search(st)
		if m:
			s.flags["SaveGameId"] = int(m.get_string(1))
			continue
		m = _re("^ConfigManager\\.MapXy\\s*=\\s*(true|false)$").search(st)
		if m:
			XConfig.set_map_xy(m.get_string(1) == "true")
			continue
		if _re("^ConfigManager\\.\\w+\\s*=\\s*\\w+$").search(st) or st == "$gameSystem.onBeforeSave()":
			continue
		m = _re("^\\$gamePlayer\\.SaveActorName\\s*=\\s*prompt\\(\\s*\"([^\"]*)\"\\s*,\\s*\"([^\"]*)\"\\s*\\)$").search(st)
		if m:
			s.actor_name = await interp.host.input_text(m.get_string(1), m.get_string(2))
			continue
		# 超强者号角（公共事件 2501～2526）：没持有（含身上装备）才给专属装备
		m = _re("^if\\s*\\(\\s*!\\$gameParty\\.hasItem\\(\\$data(Weapons|Armors)\\[(\\d+)\\]\\s*,\\s*true\\)\\s*\\)\\s*\\$gameParty\\.gainItem\\(\\$data\\1\\[\\2\\]\\s*,\\s*(\\d+)\\s*,\\s*false\\)$").search(st)
		if m:
			var kind := "weapon" if m.get_string(1) == "Weapons" else "armor"
			if not _has_gear(s, kind, int(m.get_string(2))):
				s.gain_gear(kind, int(m.get_string(2)), int(m.get_string(3)))
			continue
		m = _re("^\\$gameParty\\.gainItem\\(\\$dataItems\\[\\$gameVariables\\.value\\((\\d+)\\)\\]\\s*,\\s*(\\d+)").search(st)
		if m:
			s.gain_item(int(s.variable(int(m.get_string(1)))), int(m.get_string(2)))
			continue
		# ---- 副本 Boss 胜利奖励（CE1439 肝帝积分券里的 Codex 脚本，见 XDungeon） ----
		if st == "if(window.CodexEconomy)CodexEconomy.bossReward()":
			for t in XDungeon.boss_reward(s):
				interp.host.toast(t)
			continue
		# 洪荒（难度 8）的诅咒加成券与不朽之力：其他难度不做任何事
		if st in ["if(window.CodexHonghuang)CodexHonghuang.grantTicketBonus()", "if(window.CodexHonghuang)CodexHonghuang.rollPower()"] and s.difficulty != 8:
			continue
		m = _re("^\\$gameVariables\\.setValue\\((\\d+),window\\.CodexOrbs&&CodexOrbs\\.rollInt\\?CodexOrbs\\.rollInt\\('(\\w+)',(\\d+),(\\d+)\\):1\\+Math\\.randomInt\\(\\d+\\)\\)$").search(st)
		if m:
			s.set_variable(int(m.get_string(1)), XOrbs.roll_int(s, m.get_string(2), int(m.get_string(3)), int(m.get_string(4))))
			continue
		# CodexV010Fixes.rewardNotice(this, '前'+CodexV010Fixes.awardQuantity(this,'种类',ID,默认)+'后')：宝箱里不提示；数量取本解释器最近一次实际所得
		m = _re("^CodexV010Fixes\\.rewardNotice\\(this,\\s*'([^']*)'\\s*\\+\\s*CodexV010Fixes\\.awardQuantity\\(this,'(\\w+)',(\\d+),(\\d+)\\)\\s*\\+\\s*'([^']*)'\\)$").search(st)
		if m:
			if interp.receipt == null:
				var g: Dictionary = interp.last_gain
				var qty := int(g.amount) if str(g.get("kind", "")) == m.get_string(2) and int(g.get("id", -1)) == int(m.get_string(3)) else int(m.get_string(4))
				interp.host.toast(m.get_string(1) + str(qty) + m.get_string(5))
			continue
		m = _re("^\\$gameVariables\\.setValue\\((\\d+),window\\.CodexMijing\\?CodexMijing\\.pick(Here\\(\\)|\\((\\d+)\\)):(\\d+)\\)$").search(st)
		if m:
			# pickHere() 按所在塔层，pick(档位) 按给定档位（深渊主席抽奖公共事件 1421～1424）
			var tier := m.get_string(3)
			s.set_variable(int(m.get_string(1)), XDungeon.mijing_pick_here(s) if tier == "" else XDungeon.mijing_pick(s, int(tier)))
			continue
		# $gameVariables.setValue(N, 数字)：玉皇大帝礼物 900、奇异石碑 899、Map158 古龙祭坛 1476 等。经 set_variable 才会记进跨存档（XGlobalVars）
		m = _re("^\\$gameVariables\\.setValue\\((\\d+)\\s*,\\s*(-?\\d+(?:\\.\\d+)?)\\)$").search(st)
		if m:
			s.set_variable(int(m.get_string(1)), float(m.get_string(2)))
			continue
		# Codex_StabilityPerformancePatch 已移除地图（Map103、108）的提示：$gameMessage.add，下一条要等待的指令前显示（Map080 王座宝箱的深渊之门）
		m = _re("^CodexMapRemoval\\.notice\\((\\d+)\\)$").search(st)
		if m and REMOVED_MAPS.has(int(m.get_string(1))):
			interp.pending_lines.append("【区域已移除】%s因地图文件损坏，已从当前版本移除。" % REMOVED_MAPS[int(m.get_string(1))])
			continue
		if st == "CodexToji.rollAdvanceStone()" or st == "CodexSukuna.rollAdvanceStone()":
			var got := XDungeon.roll_advance_stone(s, XDungeon.TOJI if st.begins_with("CodexToji") else XDungeon.SUKUNA)
			if got != "":
				interp.host.toast(got)
			continue
		# 公共事件 9011 天衣铺、9018 小猫试炼：只移植了条件不够时的提示（installNativeYunshangRuntime openCrafting：174 云裳在队且
		# 20 级；installImportedBalanceRuntime startTrial：178 在队、35 级且武器槽是剑）。条件够时的天衣铺页面与试炼战斗没移植，照旧算没认出。
		# 两处原版还判 $gameParty.inBattle()，重制的脚本翻译只在地图上跑，不用判
		if st == "CodexYunshang.openCrafting()" and not _actor_ready(s, 174, 20):
			interp.host.toast("云裳达到20级后，可在战斗外使用天衣铺")
			continue
		if st == "CodexCat.startTrial(this)" and not (_actor_ready(s, XCat.ACTOR, 35) and XCat.has_sword(s.actor(XCat.ACTOR))):
			interp.host.toast("小猫剑圣达到35级并装备剑后，才能挑战。")
			continue
		if st == "CodexCat.recruit()":  # 公共事件 9017：178 哈基米入队（见 XCat.recruit）
			XCat.recruit(s)
			continue
		if st in ["CodexMira.recruit()", "CodexYomi.recruit()", "CodexJingliu.recruit()", "CodexRaven.recruit()", "CodexYunshang.recruit()"] \
				and _recruit_blocked(st.get_slice(".", 0), interp):
			continue  # 超强者门槛（见 _RECRUITMENTS）
		if st == "CodexMira.recruit()":  # 公共事件 9003：168 米拉入队（见 XMira.recruit）
			XMira.recruit(s)
			continue
		if st == "CodexYomi.recruit()" or st == "CodexJingliu.recruit()":  # 公共事件 9004／9005：169 黄泉、170 镜流入队并装上专属法宝（见 XYomiJingliu.recruit；两条 $.toaster 提示）
			for line in XYomiJingliu.recruit(s, XYomiJingliu.YOMI if st.begins_with("CodexYomi") else XYomiJingliu.JINGLIU):
				interp.host.toast(line)
			continue
		if st == "CodexYunshang.recruit()":  # 公共事件 9010：174 云裳入队（见 XYunshang.recruit；$.toaster 提示）
			XYunshang.recruit(s)
			interp.host.toast(XYunshang.RECRUIT_TEXT)
			continue
		if st == "CodexRaven.recruit()":  # 公共事件 9002：167 渡鸦入队（见 XRaven.recruit；$.toaster 提示）
			if XRaven.recruit(s):
				interp.host.toast(XRaven.RECRUIT_TEXT)
			continue
		if st == "CodexGuide.advise(this)":
			await _guide_advise(interp)  # 方桌大厅「商店向导」→「下一步建议」
			continue
		if st == "CodexZhenqi.retreat(this)":
			await XZhenqiRetreat.run(interp.host)  # 方桌大厅「闭关」NPC
			continue
		if st == "CodexReincarnationRandom.open(this)":
			await _reincarnation_open(interp)
			continue
		if st == "CodexReincarnationRandom.finishEntry()":
			continue
		# 魔兽要诀（Star_PetSystem，公共事件 190～292）：出战宠物学技能，见 XPets.learn_book
		m = _re("^Star\\.PetSystem\\.ComEveLearnSkill\\((\\d+)\\)$").search(st)
		if m:
			interp.host.toast(XPets.learn_book(s, int(m.get_string(1))))
			continue
		# 成就（Star_AchievementSystem，见 XAchievement）：宝箱、守层者、传送等事件里的 GetAcReward(N)；公共事件 431 打开成就界面
		m = _re("^Star\\.AchievementSystem\\.GetAcReward\\((\\d+)\\)$").search(st)
		if m:
			XAchievement.reward(XAchievement.event_id_fix(int(m.get_string(1)), interp.map_id, interp.event_id), s)
			continue
		if st == "SceneManager.push(Scene_AchievementBook)" and interp.host.has_method("open_achievements"):
			await interp.host.open_achievements()
			continue
		# 人物图鉴（Star_ActorsBook）：公共事件 3
		if st == "SceneManager.push(Scene_ActorBook)" and interp.host.has_method("open_actor_book"):
			await interp.host.open_actor_book()
			continue
		# 装备镶嵌图鉴（Star_EquipInlayBook）：方桌大厅魂灯商人 Map4 EV40 p1／p3 等
		if st == "SceneManager.push(Scene_EquipInlayBook)" and interp.host.has_method("open_inlay_book"):
			await interp.host.open_inlay_book()
			continue
		# 角色仓库（Star_ActorWarehouse，见 XActorWarehouse）：方桌大厅仓库管理员 Map4 EV8「角色仓库」
		if st == "SceneManager.push(Star_Scene_ActorWarehouse)" and interp.host.has_method("open_actor_warehouse"):
			await interp.host.open_actor_warehouse()
			continue
		# 星级仓库（Star_Warehouse 通用仓库，见 XStarWarehouse）：黄金大厅通用仓库管理员 Map041 EV1「存放」「取出」
		if (st == "SceneManager.push(Scene_StarSaveWarehouse)" or st == "SceneManager.push(Scene_StarWarehouse)") and interp.host.has_method("open_star_warehouse"):
			await interp.host.open_star_warehouse(st.contains("Save"))
			continue
		# 称号（Star_Designation，见 XDesignation）：方桌大厅 Map4 EV1「更换称号」；原版预约公共事件、本事件结束后弹，那一支后面没有别的指令，这里当场弹
		if st == "Star.Designation.ChooseTitle()":
			await XDesignation.choose(interp)
			continue
		if st == "$gamePlayer.DesignationN = $gamePlayer.DesignationN || []":
			continue  # 原版给 $gamePlayer 挂的空数组，没人读
		var title := _re("^ConfigManager\\.DesignationN\\[(\\d+)\\]\\s*=\\s*true$").search(st)
		if title:
			XDesignation.unlock(int(title.get_string(1)))  # 各处称号奖励：Map4 EV55、CE367／434 等 59 处
			continue
		# 更衣（Star_ChangeClothes，见 XChangeClothes）：方桌大厅衣橱管理员 Map4 EV17「查看衣橱」
		if st == "SceneManager.push(Scene_ChangeClothes)" and interp.host.has_method("open_change_clothes"):
			await interp.host.open_change_clothes()
			continue
		# 角色进阶（Star_ActorAdvanced，见 XAdvance）：兑换大厅奉神老妪 Map132 EV6「进阶」
		if st == "SceneManager.push(Scene_ActorAdvanced)" and interp.host.has_method("open_actor_advanced"):
			await interp.host.open_actor_advanced()
			continue
		# 宠物（Star_PetSystem）：公共事件 169
		if st == "SceneManager.push(Scene_PetSystem)" and interp.host.has_method("open_pets"):
			await interp.host.open_pets()
			continue
		# 修炼（Star_ActorAttributePlusPoints，见 XTraining）：魔塔教师、二十六层小萝莉等先设列出的表项再打开
		m = _re("^Star\\.ActorAttributePlusPoints\\.XiuLian\\s*=\\s*\\[([\\d,\\s]*)\\]$").search(st)
		if m:
			XTraining.xiulian = Array(m.get_string(1).split(",", false)).map(func(v): return int(v))
			continue
		if st == "SceneManager.push(Scene_ActorAttributePlusPoints)" and interp.host.has_method("open_training"):
			await interp.host.open_training()
			continue
		# 种族祝福（installNativeRaceRuntime）：种族向导 Map4 EV22、进阶石公共事件 openMenu({rank:N})、开局默认公共事件 841～847
		m = _re("^CodexRaces\\.openMenu\\((?:\\{rank:(\\d)\\})?\\)$").search(st)
		if m and interp.host.has_method("open_race_menu"):
			await interp.host.open_race_menu(int(m.get_string(1)) if m.get_string(1) != "" else 0)
			continue
		m = _re("^CodexRaces\\.setDefault\\((\\d)\\)$").search(st)
		if m:
			XRace.set_default(s, int(m.get_string(1)))
			continue
		if st.begins_with("$.toaster"):
			var text := _toaster_text(st)
			if text != "":
				interp.host.toast(text)
			else:
				unknown.append(st)
			continue
		unknown.append(st)
	return unknown


## CodexGuide.advise：interp.setupChild 插入建议文字（每段一页），显示完回到原事件
static func _guide_advise(interp) -> void:
	var sub := MVInterpreter.new(interp.host, interp.map_id, interp.event_id, XGuide.page_list(XGuide.advice_texts(XState.current)), interp._depth + 1)
	sub.pending_lines = interp.pending_lines
	await sub.run()
	interp.skipped.append_array(sub.skipped)


## CodexBossDifficulty.showRoster（破阵·投影的强者／超强者名单）：名单 ＋ 导入角色哈基米（强者）＋ 备注带 <CodexSuperStrong> 的角色（超强者），
## 停用角色（XImportedBalance.DISABLED_ACTORS）名字后加「（停用）」，每行不超过 24 字，之后接固定说明
const _STRONG_IDS := [1, 8, 9, 10, 11, 13, 17, 38, 45, 47, 50, 59, 70, 71, 82, 84, 85, 92, 93, 95, 99, 109, 110, 111, 112, 113, 114, 115, 117, 118, 119, 128, 129, 130, 131, 170]


static func _boss_roster(kind: String, interp) -> void:
	var is_super := kind == "super"
	var ids: Array = (XItemMarks.super_strong_ids() if is_super else _STRONG_IDS).duplicate()
	if not is_super:
		ids.append(XCat.ACTOR)
	var lines := ["\\n<破阵·投影>%s（%d人）" % ["超强者名单" if is_super else "强者名单", ids.size()]]
	var line := ""
	for id in ids:
		var nm := str(XDB.rec("Actors", int(id)).get("name", ""))
		if XImportedBalance.DISABLED_ACTORS.has(int(id)):
			nm += "（停用）"
		if line != "" and line.length() + nm.length() + 1 > 24:
			lines.append(line)
			line = ""
		line += ("、" if line != "" else "") + nm
	if line != "":
		lines.append(line)
	if is_super:
		lines.append_array(["超强者仅限地狱及以上难度出战。", "每名出战超强者：Boss八项属性+20%。", "第2、4、6…回合霸体，持续一整回合。",
			"霸体回合每名超强者再令Boss输出+20%。", "洪荒以下路线压制：灭世微幅、天灾小幅、地狱大幅。", "天灾、地狱：受到伤害×1.2、×1.5，", "给队友的治疗、护盾、增益×0.8、×0.5。"])
	else:
		lines.append_array(["镜流属于强者，不计入超强者难度加成。", "强者在普通、困难、地狱路线有小幅压制。"])
	var list := [{"code": 101, "indent": 0, "parameters": ["SF_People2", 5, 0, 2]}]
	for l in lines:
		list.append({"code": 401, "indent": 0, "parameters": [l]})
	list.append({"code": 0, "indent": 0, "parameters": []})
	var sub := MVInterpreter.new(interp.host, interp.map_id, interp.event_id, list, interp._depth + 1)
	sub.pending_lines = interp.pending_lines
	await sub.run()
	interp.skipped.append_array(sub.skipped)


## CodexReincarnationRandom.open（Scene_ReincarnationDraft）：本局已开启轮回（开关 2307／2303）时提示后关闭；
## 否则先选难度（轮回普通／轮回困难／返回），再选阵容规则（常规阵容／返回：回到难度）。随机角色（9 选 5）暂不开放（O-035）。
static func _reincarnation_open(interp) -> void:
	var s := XState.current
	reincarnation_entry = {"accepted": false, "hard": false}
	if s.switch(2307) or s.switch(2303):
		interp.host.toast("本局轮回已经开启，阵容规则不能中途更换。")
		return
	while true:
		var d: int = await interp.host.show_text_with_choices("", 0, ["选择轮回难度，再选择阵容规则。"], ["轮回普通", "轮回困难", "返回"], 2)
		if d < 0 or d == 2:
			return
		var m: int = await interp.host.show_text_with_choices("", 0, ["请选择本局阵容规则。"], ["常规阵容", "返回"], 1)
		if m == 0:
			reincarnation_entry = {"accepted": true, "hard": d == 1}
			return


## $.toaster({ message : '…' })：字面文字与下列部分用 + 拼接（引号里的 + 不算）：
## $dataItems[$gameVariables.value(N)].name、$gameVariables.value(N)（JS 数字写法）
static func _toaster_text(js: String) -> String:
	var m := _re("\\$\\.toaster\\(\\s*\\{\\s*message\\s*:\\s*(.*?)\\s*\\}\\s*\\)").search(js)
	if m == null:
		return ""
	var out := ""
	for part in _concat_parts(_before_option(m.get_string(1))):
		var p := str(part).strip_edges()
		var lit := _re("^['\"](.*)['\"]$").search(p)
		if lit:
			out += lit.get_string(1)
			continue
		var item := _re("^\\$dataItems\\[\\$gameVariables\\.value\\((\\d+)\\)\\]\\.name$").search(p)
		if item:
			out += str(XDB.rec("Items", int(XState.current.variable(int(item.get_string(1))))).get("name", ""))
			continue
		# $gameActors.actor($gameVariables.value(N)).name()：角色不存在时原版读 null 出错，整句不提示
		var who := _re("^\\$gameActors\\.actor\\(\\$gameVariables\\.value\\((\\d+)\\)\\)\\.name\\(\\)$").search(p)
		if who:
			var aid := int(XState.current.variable(int(who.get_string(1))))
			if aid <= 0 or XDB.rec("Actors", aid).is_empty():
				return ""
			out += XState.current.actor(aid).display_name()
			continue
		var skill := _re("^\\$dataSkills\\[(\\d+)\\]\\.name$").search(p)
		if skill:
			out += str(XDB.rec("Skills", int(skill.get_string(1))).get("name", ""))
			continue
		var v := _re("^\\$gameVariables\\.value\\((\\d+)\\)$").search(p)
		if v:
			out += js_number(XState.current.variable(int(v.get_string(1))))
			continue
		# (变量 N * 常数)：封刀奖励 CE999～1001 的「肝帝积分」提示
		var mul := _re("^\\(\\s*\\$gameVariables\\.value\\((\\d+)\\)\\s*\\*\\s*(\\d+)\\s*\\)$").search(p)
		if mul:
			out += js_number(XState.current.variable(int(mul.get_string(1))) * float(mul.get_string(2)))
			continue
		return ""
	return out


## message 后面跟的 ,color:'yellow' 之类选项不是文字：在引号和括号外的第一个逗号处截断
static func _before_option(expr: String) -> String:
	var quote := ""
	var depth := 0
	for i in range(expr.length()):
		var ch := expr[i]
		if quote != "":
			if ch == quote:
				quote = ""
		elif ch == "'" or ch == "\"":
			quote = ch
		elif ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
		elif ch == "," and depth <= 0:
			return expr.left(i)
	return expr


## 按引号外的 + 切开字符串拼接表达式
static func _concat_parts(expr: String) -> Array:
	var parts := []
	var cur := ""
	var quote := ""
	for ch in expr:
		if quote != "":
			cur += ch
			if ch == quote:
				quote = ""
		elif ch == "'" or ch == "\"":
			quote = ch
			cur += ch
		elif ch == "+":
			parts.append(cur)
			cur = ""
		else:
			cur += ch
	parts.append(cur)
	return parts


## JS 数字转字符串（整数不带小数点）
static func js_number(v: float) -> String:
	return "%d" % int(v) if v == floorf(v) and absf(v) < 9.0e18 else str(v)


## 只认白名单的简单 JS 表达式（事件条件 111 脚本、变量操作数 122 脚本）：数字、+ - * / ( )、比较、&& || !，
## 以及 $gameVariables.value(N)、$gameSwitches.value(N)、$gameSystem.playtime()、$gameParty.gold()/steps()/size()、
## $gameMap.mapId()、$gameParty.numItems($dataItems[N])、Math.floor/ceil/max/min/abs。认不出返回 null（调用方记进 skipped）。
static func eval_expr(js: String) -> Variant:
	var e := js.strip_edges()
	while e.ends_with(";"):
		e = e.left(-1).strip_edges()
	if e == "" or e.contains("%") or e.contains("=>") or e.contains("\"") or e.contains("'"):
		return null
	var subs := [["$gameVariables.value(", "v("], ["$gameSwitches.value(", "sw("], ["$gameSystem.playtime()", "playtime()"],
		["$gameParty.gold()", "gold()"], ["$gameParty.steps()", "steps()"], ["$gameParty.size()", "party_size()"],
		["$gameMap.mapId()", "map_id()"], ["$gameMap._mapId", "map_id()"], ["Math.floor(", "floor("], ["Math.ceil(", "ceil("],
		["Math.max(", "max("], ["Math.min(", "min("], ["Math.abs(", "abs("], ["===", "=="], ["!==", "!="], ["&&", " and "], ["||", " or "],
		["CodexReincarnationRandom.entryAccepted()", "entry_accepted()"], ["CodexReincarnationRandom.entryHard()", "entry_hard()"]]
	for s in subs:
		e = e.replace(s[0], s[1])
	e = _re("\\$gameParty\\.numItems\\(\\$dataItems\\[(\\d+)\\]\\)").sub(e, "items($1)", true)
	e = _re("ConfigManager\\.DesignationN\\[(\\d+)\\]").sub(e, "designation($1)", true)  # 称号解锁（Map2 EV2 条件）
	e = _re("!(?!=)").sub(e, " not ", true)
	var allowed := ["v", "sw", "designation", "playtime", "gold", "steps", "party_size", "map_id", "items", "entry_accepted", "entry_hard", "floor", "ceil", "max", "min", "abs", "true", "false", "and", "or", "not"]
	for w in _re("[A-Za-z_$][A-Za-z_0-9$.]*").search_all(e):
		if not allowed.has(w.get_string()):
			return null
	# JS 除法是浮点：整数字面量一律写成浮点
	e = _re("(?<![\\d.])(\\d+)(?![\\d.])").sub(e, "$1.0", true)
	var ex := Expression.new()
	if ex.parse(e) != OK:
		return null
	var r = ex.execute([], ExprEnv.new(), false)
	return null if ex.has_execute_failed() else r


class ExprEnv:
	extends RefCounted
	func v(id: float) -> float: return XState.current.variable(int(id))
	func designation(id: float) -> bool: return XDesignation.unlocked(int(id))
	func sw(id: float) -> bool: return XState.current.switch(int(id))
	func playtime() -> float: return floorf(XState.current.play_seconds)
	func gold() -> float: return float(XState.current.gold)
	func steps() -> float: return float(XState.current.steps)
	func party_size() -> float: return float(XState.current.members().size())
	func map_id() -> float: return float(XState.current.map_id)
	func items(id: float) -> float: return float(XState.current.item_count(int(id)))
	func entry_accepted() -> bool: return bool(MVScript.reincarnation_entry.get("accepted", false))
	func entry_hard() -> bool: return bool(MVScript.reincarnation_entry.get("hard", false))


## var actor = $gameActors.actor($gameVariables.value(N)); 后跟若干 actor.learnSkill(X)/forgetSkill(X)/removeState(X)；认不出返回空
static func _actor_by_variable(js: String) -> Dictionary:
	var flat := js.replace("\n", ";")
	var head := _re("^var\\s+actor\\s*=\\s*\\$gameActors\\.actor\\(\\$gameVariables\\.value\\((\\d+)\\)\\)\\s*;(.*)$").search(flat.strip_edges())
	if head == null:
		return {}
	var calls := []
	for st in head.get_string(2).split(";", false):
		var m := _re("^\\s*actor\\.(learnSkill|forgetSkill|removeState)\\((\\d+)\\)\\s*$").search(st)
		if m == null:
			return {}
		calls.append([m.get_string(1), m.get_string(2)])
	return {} if calls.is_empty() else {"variable": int(head.get_string(1)), "calls": calls}


## 物品选中角色（$gameParty._targetActorId，重制为 XState.item_target_actor_id）的技能脚本（CE623、637～648、941～947、1003～1018、
## 1160～1185、1343、1378～1380 等）：先整段检查只用到下列写法，认得才执行（认不得返回 null 交给通用翻译，不会执行一半）。
## 没有选中角色时 $gameActors.actor 得 null，原版读 actor 抛错、YEP command355 吞掉，本段其余语句不再执行（这里同样就此结束）。
## 语句：var x = $gameParty._targetActorId／数字／$gameVariables.value(N)；var actor = $gameActors.actor(x 或 $gameParty._targetActorId)；
## var m = $dataSkills[x].description（无操作）；$gameVariables.setValue(N, 值)；for (var i = A; i < B; i++) {…}；break；
## if (条件) {…} [else {…}]，条件为 & 或 && 连起来的 actor.hasSkill(x)、值 == 值、值 != 值；actor.forgetSkill(x)／learnSkill(x)；
## if(actor)actor.learnSkill(x)；$gameParty.gainItem($dataItems[N], n[, true])；$.toaster。值：数字、变量名、$gameVariables.value(N)、
## $gameParty._targetActorId、x+数字。
static func _target_actor_script(js: String, interp) -> Variant:
	if await _target_block(js, {}, interp, false) == null:
		return null
	var env := {}
	await _target_block(js, env, interp, true)
	if env.get("actor") is XActor:
		env.actor.refresh_passive()
	return []


## run＝false 只检查写法（两个分支、循环体都走一遍，不改状态）；返回 null＝有认不出的写法，"throw"＝读了 null 的 actor（停），
## "break"＝循环里 break，"ok"
static func _target_block(js: String, env: Dictionary, interp, run: bool) -> Variant:
	var s := XState.current
	var pos := 0
	var flat := js  # 换行也是语句结尾（原文 var m = $dataSkills[i].description 不带分号）
	while pos < flat.length():
		var rest := flat.substr(pos).strip_edges(true, false)
		if rest.strip_edges() == "":
			break
		pos = flat.length() - rest.length()
		var head := _re("^(for|if)\\s*\\((.*?)\\)\\s*\\{").search(rest)
		if head:
			var body: Array = _block(flat, pos + head.get_end() - 1)
			pos = body[1]
			if head.get_string(1) == "for":
				var loop := _re("^var\\s+(\\w+)\\s*=\\s*(\\d+)\\s*;\\s*\\1\\s*<\\s*(\\d+)\\s*;\\s*\\1\\+\\+\\s*$").search(head.get_string(2).strip_edges())
				if loop == null:
					return null
				if not run:
					if await _target_block(body[0], env, interp, false) == null:
						return null
					continue
				for i in range(int(loop.get_string(2)), int(loop.get_string(3))):
					env[loop.get_string(1)] = i
					var r = await _target_block(body[0], env, interp, true)
					if r == "break":
						break
					if r != "ok":
						return r
				continue
			var else_body := ""
			if flat.substr(pos).strip_edges().begins_with("else"):
				var after := _block(flat, flat.find("{", pos))
				else_body = after[0]
				pos = after[1]
			var cond = _target_cond(head.get_string(2).strip_edges(), env, run)
			if cond == null:
				return null
			if not run:
				if await _target_block(body[0], env, interp, false) == null or await _target_block(else_body, env, interp, false) == null:
					return null
				continue
			if cond is String:  # "throw"
				return "throw"
			var r = await _target_block(body[0] if cond else else_body, env, interp, true)
			if r != "ok":
				return r
			continue
		if rest.begins_with("$.toaster"):
			# 提示文字里可能有分号：取到配对的右括号为止整句拼
			var call_end := _paren_end(flat, pos + rest.find("("))
			var call := flat.substr(pos, call_end - pos)
			pos = call_end
			if not run:
				if _re("^\\$\\.toaster\\(\\s*\\{\\s*message\\s*:").search(call) == null:
					return null
				continue
			var text := _toaster_text(call)
			if text == "":
				return "throw"  # 读 null 的角色名等：原版抛错
			interp.host.toast(text)
			continue
		var end := _statement_end(rest)
		var st := (rest if end < 0 else rest.left(end)).strip_edges()
		pos += rest.length() if end < 0 else end + 1
		if st == "" or st == "}" or st.begins_with("//"):
			continue
		if st == "break":
			if run:
				return "break"
			continue
		var m := _re("^var\\s+(\\w+)\\s*=\\s*(.+)$").search(st)
		if m and m.get_string(1) != "actor":
			if _re("^\\$dataSkills\\[\\w+\\]\\.description$").search(m.get_string(2)):
				continue
			var v = _target_value(m.get_string(2), env, run)
			if v == null:
				return null
			env[m.get_string(1)] = v
			continue
		m = _re("^var\\s+actor\\s*=\\s*\\$gameActors\\.actor\\((.+)\\)$").search(st)
		if m:
			var aid = _target_value(m.get_string(1), env, run)
			if aid == null:
				return null
			env.actor = s.actor(aid) if run and aid > 0 and not XDB.rec("Actors", aid).is_empty() else null
			continue
		m = _re("^\\$gameVariables\\.setValue\\((\\d+)\\s*,\\s*(.+)\\)$").search(st)
		if m:
			var v = _target_value(m.get_string(2), env, run)
			if v == null:
				return null
			if run:
				s.set_variable(int(m.get_string(1)), float(v))
			continue
		m = _re("^(if\\s*\\(\\s*actor\\s*\\)\\s*)?actor\\.(forgetSkill|learnSkill)\\((\\w+)\\)$").search(st)
		if m:
			if not run:
				continue
			if not env.get("actor") is XActor:
				if m.get_string(1) != "":
					continue
				return "throw"
			var sid: int = _target_value(m.get_string(3), env, true)
			if m.get_string(2) == "forgetSkill":
				env.actor.forget_skill(sid)
			else:
				env.actor.learn_skill(sid)
			continue
		m = _re("^\\$gameParty\\.gainItem\\(\\$dataItems\\[(\\d+)\\]\\s*,\\s*(\\d+)(?:\\s*,\\s*(?:true|false))?\\)$").search(st)
		if m:
			if run:
				s.gain_item(int(m.get_string(1)), int(m.get_string(2)))
			continue
		return null
	return "ok"


## if 条件：& 或 && 连起来的 actor.hasSkill(x)、值 == 值、值 != 值。返回 null＝认不得；"throw"＝读了 null 的 actor；否则 bool
static func _target_cond(text: String, env: Dictionary, run: bool) -> Variant:
	var all := true
	for term in _re("\\s*&&?\\s*").sub(text, "\u0001", true).split("\u0001"):
		term = term.strip_edges()
		var has := _re("^actor\\.hasSkill\\((\\w+)\\)$").search(term)
		if has:
			if not run:
				continue
			if not env.get("actor") is XActor:
				return "throw"
			var sid: int = _target_value(has.get_string(1), env, true)
			all = all and env.actor.skills().any(func(sk): return int(sk.id) == sid)
			continue
		var cmp := _re("^(.+?)\\s*(==|!=)\\s*(.+)$").search(term)
		if cmp == null:
			return null
		var a = _target_value(cmp.get_string(1), env, run)
		var b = _target_value(cmp.get_string(3), env, run)
		if a == null or b == null:
			return null
		if run:
			all = all and ((a == b) == (cmp.get_string(2) == "=="))
	return all


## 值：数字、env 里的变量（没有的是 JS undefined，按 0）、$gameVariables.value(N)、$gameParty._targetActorId、x+数字；认不得返回 null。
## run＝false 只看写法（认得的返回 0）
static func _target_value(token: String, env: Dictionary, run: bool) -> Variant:
	var t := token.strip_edges()
	if t.is_valid_int():
		return int(t)
	if t == "$gameParty._targetActorId":
		return XState.current.item_target_actor_id if run else 0
	var v := _re("^\\$gameVariables\\.value\\((\\d+)\\)$").search(t)
	if v:
		return int(XState.current.variable(int(v.get_string(1)))) if run else 0
	var plus := _re("^(\\w+)\\s*\\+\\s*(\\d+)$").search(t)
	if plus:
		var base = _target_value(plus.get_string(1), env, run)
		return null if base == null else int(base) + int(plus.get_string(2))
	if _re("^[A-Za-z_]\\w*$").search(t):
		return int(env.get(t, 0)) if run else 0
	return null


## 语句结尾：第一个分号或换行；都没有为 -1
static func _statement_end(text: String) -> int:
	var a := text.find(";")
	var b := text.find("\n")
	return b if a < 0 else (a if b < 0 else mini(a, b))


## from 处是「(」：返回配对右括号之后的位置（跳过引号里的括号）
static func _paren_end(js: String, from: int) -> int:
	var depth := 0
	var quote := ""
	for i in range(from, js.length()):
		var ch := js[i]
		if quote != "":
			if ch == quote:
				quote = ""
		elif ch == "'" or ch == "\"":
			quote = ch
		elif ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
			if depth == 0:
				return i + 1
	return js.length()


## $gameParty.hasItem($dataXxx[id], true)：背包里或队伍成员身上有这件（独立装备按原装备编号）
static func _has_gear(s: XState, kind: String, base_id: int) -> bool:
	if s.gear_count(kind, base_id) > 0:
		return true
	for a in s.members():
		for e in a.equip_list():
			if e is Dictionary and str(e.get("kind", "")) == kind and int(e.get("base", 0)) == base_id:
				return true
	return false


## 「所有角色学会/忘记技能」的几种循环写法 → actor_op 列表；认不出返回空
static func _actor_loop(js: String) -> Array:
	var flat := js.replace("\n", " ")
	# 按 ID 列表：var ids = [..]; ids.forEach(function(actorId){ …forgetSkill(A); learnSkill(B); }); 以及列表外有名字的角色 learnSkill(C)
	var list := _re("var\\s+(\\w+)\\s*=\\s*\\[([\\d,\\s]*)\\]").search(flat)
	if list and flat.contains(list.get_string(1) + ".forEach"):
		var name := list.get_string(1)
		var ids := Array(list.get_string(2).split(",", false)).map(func(v): return int(v.strip_edges()))
		var ops := []
		var each := _re(name + "\\.forEach\\(function\\s*\\(\\w+\\)\\s*\\{(.*?)\\}\\s*\\)").search(flat)
		if each == null:
			return []
		for call in _re("(forgetSkill|learnSkill)\\((\\d+)\\)").search_all(each.get_string(1)):
			ops.append({"op": "forget" if call.get_string(1) == "forgetSkill" else "learn", "skill": int(call.get_string(2)), "ids": ids, "exclude": [], "named": false})
		var rest := flat.substr(each.get_end())
		if rest.contains("!" + name + ".includes"):
			var others := _re("learnSkill\\((\\d+)\\)").search(rest)
			if others:
				ops.append({"op": "learn", "skill": int(others.get_string(1)), "ids": [], "exclude": ids, "named": _re(_NAMED).search(rest) != null})
		return ops
	# for (var j = 1; j < $dataActors.length 或 999; j++) { [if (名字非空)] …actor(j)…learnSkill(N) / forgetSkill(N) }
	var head := _re("^for\\s*\\(\\s*(?:var|let)\\s+j\\s*=\\s*1\\s*;\\s*j\\s*<\\s*(\\$dataActors\\.length|\\d+)\\s*;\\s*j\\+\\+\\s*\\)\\s*\\{(.*)\\}$").search(flat.strip_edges().trim_prefix("var j = $gameParty._targetActorId;").strip_edges())
	if head == null:
		return []
	var body := head.get_string(2)
	var calls := _re("(forgetSkill|learnSkill)\\((\\d+)\\)").search_all(body)
	if calls.is_empty() or _re("\\b(if|else)\\b").search(body.replace("if($dataActors[j].name != '')", "").replace("if ($dataActors[j].name != '')", "")):
		return []
	var named := _re(_NAMED).search(body) != null
	var out := []
	for call in calls:
		out.append({"op": "forget" if call.get_string(1) == "forgetSkill" else "learn", "skill": int(call.get_string(2)), "ids": [], "exclude": [], "named": named})
	return out


## from 处是「{」：返回 [括号里的内容, 右括号之后的位置]
static func _block(js: String, from: int) -> Array:
	var depth := 0
	for i in range(from, js.length()):
		if js[i] == "{":
			depth += 1
		elif js[i] == "}":
			depth -= 1
			if depth == 0:
				return [js.substr(from + 1, i - from - 1), i + 1]
	return [js.substr(from + 1), js.length()]


## 去掉 // 行注释（引号里的 // 不算，如提示文字里的网址）
static func _strip_comments(code: String) -> String:
	var out := []
	for line in code.split("\n"):
		var quote := ""
		var cut := line.length()
		var i := 0
		while i < line.length():
			var ch := line[i]
			if quote != "":
				if ch == "\\":
					i += 1
				elif ch == quote:
					quote = ""
			elif ch == "'" or ch == "\"":
				quote = ch
			elif ch == "/" and i + 1 < line.length() and line[i + 1] == "/":
				cut = i
				break
			i += 1
		out.append(line.substr(0, cut))
	return "\n".join(out)
