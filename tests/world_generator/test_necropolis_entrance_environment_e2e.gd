extends SceneTree

const _POIViewScript = preload("res://src/world_generator/presentation/dungeon_entrance_poi_view.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

func _init() -> void:
	print("Running test_necropolis_entrance_environment_e2e...")
	var ident = _DungeonIdentityScript.new(&"necropolis_e2e_01", Vector2i(1, 1), 0, 88888)
	var poi = _DungeonPOIScript.new(ident, Vector3(32.0, 4.0, 32.0), Transform3D.IDENTITY, &"necropolis", 1)
	
	var view = _POIViewScript.new(poi)
	view._ready()

	assert(view.get_node_or_null("NecropolisModel") != null, "NecropolisModel must exist")
	assert(view.get_node_or_null("BonePatches") != null, "BonePatches node must be instantiated")
	assert(view.get_node_or_null("DeadTrees") != null, "DeadTrees node must be instantiated")
	assert(view.get_node_or_null("DarkRocks") != null, "DarkRocks node must be instantiated")
	assert(view.get_node_or_null("EntranceGlow") != null, "EntranceGlow must exist")

	view.free()
	print("[PASS] test_necropolis_entrance_environment_e2e")
	quit(0)
