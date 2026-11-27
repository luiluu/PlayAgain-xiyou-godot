extends "res://tests/xiyou_virtual_player.gd"
## 【cc·T533 R2】虚拟玩家薄包装：多一个参数 --t533=off 把 XDamage.MAIN_STAT_PASS 关掉，其余参数同 xiyou_virtual_player。
## 只给「角色 162 生命高于上限」开／关对照用；不是专项（不在 tests/ 顶层）。单独跑务必带 --audio-driver Dummy、临时 HOME。


func _ready() -> void:
	XDamage.MAIN_STAT_PASS = not OS.get_cmdline_user_args().has("--t533=off")
	print("T533_VP|switch=%s" % ("on" if XDamage.MAIN_STAT_PASS else "off"))
	super._ready()
