class_name XGearInfo
extends RefCounted
## 品质、实例词缀和套装说明共用已转换的规则数据。
const XNAMES := ["命中","闪避","暴击","暴击回避","魔法闪避","魔法反射","反击","生命再生","魔法再生","怒气再生"]
const SNAMES := ["受击概率","防御效果","回复效果","药品效果","魔法消耗","怒气充能","物理承伤","魔法承伤","地形承伤","经验获得"]
static func text(parent: Control, value: String, color := XUI.TEXT, size := 22) -> void:
	var label := XUI.label(value,size,color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(label)
static func button_color(b: Button, item: Dictionary) -> void:
	b.add_theme_color_override("font_color",XGear.color(item))
	b.add_theme_color_override("font_hover_color",XGear.color(item))
	b.add_theme_color_override("font_focus_color",XGear.color(item))
static func details(parent: Control, item: Dictionary, a: XActor = null) -> void:
	text(parent,str(item.name),XGear.color(item),26)
	text(parent,"品质："+XGear.quality_name(item),XGear.color(item))
	text(parent,"强化插槽：%d / %d"%[int(item.get("upgradeSlots",6)),int(item.get("originalUpgradeSlots",6))],XUI.SYSTEM)
	var names := []
	for affix in item.get("affixIds",[]):
		var rec := XDB.rec(str(affix.table),int(affix.id))
		names.append(str(rec.get("meta",{}).get("prefixSuffixName",rec.get("name",""))))
	if not names.is_empty():text(parent,"词缀："+"、".join(names))
	if item.has("runewordName"):text(parent,"符文之语："+str(item.runewordName),XUI.SYSTEM)
	var req := int(item.get("meta",{}).get("req_level",0))
	if req>0:text(parent,"需求等级：%d"%req)
	for i in range(8):
		if int(item.params[i])!=0:text(parent,"%s  %+d"%[XMenu.PARAM_NAMES[i],int(item.params[i])])
	for suit_id in item.get("equipment",{}).get("suits",[]):
		var suit := XDB.rec("EquipSuits",int(suit_id))
		if suit.is_empty():continue
		var count := int(XEquipSuits.counts(a).get(int(suit_id),0)) if a!=null else 0
		text(parent,"%s（已装备 %d 件）"%[suit.name,count] if a!=null else str(suit.name),XUI.SYSTEM)
		for bonus in suit.bonuses:
			text(parent,"%d 件：%s"%[int(bonus.requirePieces),bonus_text(bonus)],XUI.POWER_UP if count>=int(bonus.requirePieces) else XUI.DIM,20)
	if not item.get("upgrades",[]).is_empty():
		text(parent,"已镶嵌："+"、".join(item.upgrades.map(func(u):return str(u.name))),XUI.DIM,20)
static func bonus_text(b: Dictionary) -> String:
	var parts := []
	for group in ["param","xparam","sparam","bResult"]:
		var labels: Array={"param":XMenu.PARAM_NAMES,"xparam":XNAMES,"sparam":SNAMES,"bResult":["队伍经验","队伍金钱","队伍掉率"]}[group]
		for i in range(labels.size()):
			var plus := float(b[group+"Plus"][i]);var rate := float(b[group+"Rate"][i])
			if plus!=0:parts.append("%s %s%s%s"%[labels[i],"+" if plus>0 else "",str(plus),"" if group=="param" else "%"])
			if rate!=1:parts.append("%s ×%s"%[labels[i],str(rate)])
	for id in b.skills:
		var skill := XDB.rec("Skills",int(id))
		parts.append("获得 "+str(skill.get("name","技能%d"%int(id))))
	for id in b.states:
		parts.append("状态 "+str(XDB.rec("States",int(id)).get("name",id)))
	for id in b.statesResist:
		parts.append("免疫 "+str(XDB.rec("States",int(id)).get("name",id)))
	return "、".join(parts) if not parts.is_empty() else "无额外加成"
