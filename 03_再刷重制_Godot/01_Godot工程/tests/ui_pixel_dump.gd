extends RefCounted
## 界面像素对照的窗口矩形读数（白龙 ui-pixel2）：收场景树里所有可见、开着的 XMVWindow／XHelpCard（及说明卡的品质框）的全局矩形，
## 给 03_转换工具/ui_reference/ui_pixel_compare.py 配原版 readout。各专项的 --out 截图点在 save_png 后调 dump(根, <名>.win.json)。


## overlay：成就弹窗、提示条底下的窗口记成 type「Overlay」（时序噪声：原版截图时多半已消失），对照时单列、不算没配上
static func collect(node: Node, out: Array = [], overlay := false) -> Array:
	overlay = overlay or node is XAchievementPopup or node is XToast
	if node is Control and (node is XMVWindow or node is XHelpCard) and (node as Control).is_visible_in_tree():
		var c := node as Control
		var op = c.get("openness")
		if op == null or float(op) > 0.0:
			var kind := "Overlay" if overlay else ("XHelpCard" if node is XHelpCard else "XMVWindow")
			out.append({"type": kind, "name": str(node.name), "rect": grect(c), "openness": op, "path": str(node.get_path())})
			# 说明卡的品质框是卡的子节点（本体外扩 10），对应原版单独的 Window_ItemHelp
			if node is XHelpCard and (node as XHelpCard).frame != null and (node as XHelpCard).frame.is_visible_in_tree():
				out.append({"type": "XHelpCardFrame", "name": "", "rect": grect((node as XHelpCard).frame), "openness": null})
	# 制作页数量按钮是页面自己画的（不是窗口），对应原版五个 Sprite_Button
	if node is XCraftingScene and (node as XCraftingScene).buttons_visible and (node as Control).is_visible_in_tree():
		for r in XCraftingScene.button_rects():
			out.append({"type": "Sprite_Button", "name": "", "rect": [r.position.x + (node as Control).global_position.x, r.position.y + (node as Control).global_position.y, r.size.x, r.size.y], "openness": null})
	for ch in node.get_children():
		collect(ch, out, overlay)
	return out


static func grect(w: Control) -> Array:
	var r := w.get_global_rect()
	return [r.position.x, r.position.y, r.size.x, r.size.y]


static func dump(root: Node, path: String, shot := "") -> Array:
	var wins := collect(root)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"shot": shot, "windows": wins}, "  "))
	return wins
