class_name XEquipmentView
extends RefCounted
## CP_MagicWeapon instance level, independent of upgrade-slot boostCount.
static func level(item: Dictionary):
	if not item.get("meta", {}).has("Magic Weapon"):
		return -1.0
	if item.has("level"):
		return item.level
	# Database initialization in CP_MagicWeapon sets Init Level before instances
	# exist. Legacy Godot gear has no magic-level field; reading it never migrates it.
	var value := float(item.get("meta", {}).get("Init Level", XDB.plugin("CP_MagicWeapon").get("Init Level", 1)))
	return floorf(value + 0.5) if value != 0.0 else 1.0

static func first_armor_level(rows: Array, base_id: int):
	for item in rows:
		if item is Dictionary and item.get("kind") == "armor" and int(item.get("baseItemId", item.get("base", item.get("id", 0)))) == base_id:
			return item.get("instanceLevel", level(item))
	return 0.0
