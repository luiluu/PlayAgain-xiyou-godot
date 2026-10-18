class_name XZhenqiRetreat
extends RefCounted
## 闭关（CodexZhenqi.retreat）：方桌大厅「闭关」NPC（Map004 事件 72，<CodexZhenqi: retreat>）与主菜单「真气」共用。
## 按 XZhenqi.menu 的节点逐页显示：文字（下方、窗口背景）＋选项（右侧，取消＝最后一项），瓶颈之战、神兵试炼用 start_battle（不能逃、可以输）；神兵试炼打完不回菜单（next 为空）。
## 记账全在 XZhenqi.menu 里；这里只显示、按选中项走下一个节点。host：XMapScene（或测试用的固定应答宿主）。

static func run(host, node := {"page": "retreat"}) -> void:
	var s := XState.current
	var cur = node
	while cur != null:
		var m: Dictionary = XZhenqi.menu(s, cur)
		if m.is_empty():
			return
		var opts: Array = m.get("options", [])
		if m.has("battle"):
			await host.show_message({"lines": m.lines, "position": 2, "background": 0})
			await host.start_battle(int(m.battle), false, true)
			cur = m.next
			continue
		if opts.is_empty():
			await host.show_message({"lines": m.lines, "position": 2, "background": 0})
			cur = m.get("next")
			continue
		var k: int = await host.show_message({"lines": m.lines, "position": 2, "background": 0, "choices": opts.map(func(o): return o.label),
			"cancel": opts.size() - 1, "default": 0, "choice_position": 2, "choice_background": 0})
		if k < 0 or k >= opts.size():
			k = opts.size() - 1
		cur = opts[k].next
