extends "res://tests/xiyou_actor_book.gd"
## 只扩充窗口取证；沿用生产场景与原专项，不改原fixture或实现。

func _run() -> void:
	var s := XState.new_game_blank()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	var book := XActorBook.new()
	add_child(book)
	await frames(3)
	book.select(1)
	await frames(3)
	await shot("actor_book_1")
	book.ok()
	await frames(3)
	await shot("actor_book_1_skills")
	book.cancel()
	await frames(3)
	await shot("actor_book_back")
	check("returned_card_hidden", book.index_win.visible and not book.help_card.visible)
	print("TEST_RESULT=" + JSON.stringify({"passed": results.filter(func(x): return x.passed).size(), "total": results.size()}))
	get_tree().quit.call_deferred(0 if results.all(func(x): return x.passed) else 1)


func shot(name: String) -> void:
	if out_dir == "":
		return
	var book: XActorBook
	for child in get_children():
		if child is XActorBook:
			book = child
	if book == null:
		return
	var rect := func(w: Control) -> Array: return [w.position.x, w.position.y, w.size.x, w.size.y]
	var data := {"index": rect.call(book.index_win), "status": rect.call(book.status_win),
		"header": rect.call(book.header_win), "list": rect.call(book.list_win),
		"help": rect.call(book.help_card), "lineHeight": XActorBook.LH,
		"visible": [book.index_win.visible, book.status_win.visible, book.header_win.visible,
			book.list_win.visible, book.help_card.visible],
		"actor": book.index, "skill": int(book.skill_list[book.skill_index].id) if book.skill_index >= 0 else 0,
		"statusOps": to_ref(book._status_ops), "headerOps": to_ref(book.header_ops(book.index))}
	check(name + "_mode", book.mode == ("skills" if name.ends_with("skills") else "index"))
	# 内联取图，避免父类窗口shot的异步分派与状态推进交错；取数和图像来自同一状态。
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	var f := FileAccess.open(out_dir.path_join(name + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
