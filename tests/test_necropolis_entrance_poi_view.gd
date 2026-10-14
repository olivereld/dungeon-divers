extends SceneTree

const _POIViewScript = preload("res://src/world_generator/presentation/dungeon_entrance_poi_view.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

func _init() -> void:
	print("Running test_necropolis_entrance_poi_view...")
	
	var identity = _DungeonIdentityScript.new(&"necropolis_crypt_01", Vector2i(1, 1), 0, 12345)
	var poi = _DungeonPOIScript.new(
		identity,
		Vector3(10.0, 5.0, 10.0),
		Transform3D.IDENTITY,
		&"necropolis",
		1
	)

	var view = _POIViewScript.new(poi)
	assert(view != null, "View must instantiate")
	
	view._ready()
	
	# Verify that the 3D model node was instantiated
	var model_node = view.get_node_or_null("NecropolisModel")
	assert(model_node != null, "Must contain 'NecropolisModel' node")
	assert(model_node.scale.x >= 4.0, "Model must be scaled appropriately (got scale %s)" % str(model_node.scale))
	
	# Verify that the placeholder red cube is NOT present
	var red_cube = view.get_node_or_null("EntranceCube")
	assert(red_cube == null, "EntranceCube placeholder should be replaced by the 3D model")
	
	# Verify prompt label, atmospheric light and interaction trigger exist
	var label = view.get_node_or_null("PromptLabel")
	assert(label != null, "PromptLabel must exist")
	var area = view.get_node_or_null("InteractionArea")
	assert(area != null, "InteractionArea must exist")
	var glow = view.get_node_or_null("EntranceGlow")
	assert(glow != null, "Atmospheric EntranceGlow light must exist")
	
	view.free()

	# Test fallback for other archetypes (e.g. fortress/catacombs)
	var poi_other = _DungeonPOIScript.new(
		identity,
		Vector3(20.0, 5.0, 20.0),
		Transform3D.IDENTITY,
		&"catacombs",
		1
	)
	var view_other = _POIViewScript.new(poi_other)
	view_other._ready()
	var fallback_cube = view_other.get_node_or_null("EntranceCube")
	assert(fallback_cube != null, "Other archetypes should use fallback EntranceCube until they have 3D models")
	var other_model = view_other.get_node_or_null("NecropolisModel")
	assert(other_model == null, "Other archetypes must not instantiate NecropolisModel")
	view_other.free()

	print("[PASS] test_necropolis_entrance_poi_view")
	quit(0)
