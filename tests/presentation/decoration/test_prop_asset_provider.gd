extends SceneTree

const PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const PropAssetDefinitionScript = preload("res://src/presentation/decoration/assets/prop_asset_definition.gd")
const PropAssetSourceScript = preload("res://src/presentation/decoration/assets/prop_asset_source.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_prop_asset_provider ---")
	print("==================================================================")

	var provider := PropAssetProviderScript.new()

	# 1. Materializar por ID procedural registrado
	var sarc_node = provider.materialize_by_id(&"sarcophagus_stone_closed")
	assert(sarc_node != null and sarc_node is Node3D, "FAIL: Failed to materialize procedural sarcophagus")
	sarc_node.free()
	print("  [OK] Procedural prop materialization verified.")

	var altar_node = provider.materialize_by_id(&"stone_altar_center")
	assert(altar_node != null and altar_node is Node3D, "FAIL: Failed to materialize procedural altar")
	altar_node.free()
	print("  [OK] Procedural altar materialization verified.")

	# 2. Materializar desde PackedScene
	var packed_scene := PackedScene.new()
	var template_node := Node3D.new()
	template_node.name = "PackedTemplate"
	packed_scene.pack(template_node)
	template_node.free()

	var scene_def := PropAssetDefinitionScript.create_scene_definition(&"test_packed_prop", packed_scene)
	var scene_node = provider.instantiate(scene_def)
	assert(scene_node != null and scene_node is Node3D, "FAIL: Failed to instantiate PackedScene prop")
	assert(scene_node.name == "PackedTemplate", "FAIL: Instantiated node name mismatch")
	scene_node.free()
	print("  [OK] PackedScene prop materialization verified.")

	# 3. Manejo resiliente de errores: ID desconocido
	var unknown_node = provider.materialize_by_id(&"fake_nonexistent_prop")
	assert(unknown_node == null, "FAIL: Unknown prop ID must return null safely")
	print("  [OK] Unknown ID returns null without crashing.")

	# 4. Manejo resiliente de errores: Definición nula
	var null_node = provider.instantiate(null)
	assert(null_node == null, "FAIL: Null definition must return null safely")
	print("  [OK] Null definition returns null safely.")

	print("[PASS] test_prop_asset_provider completed successfully!")
	quit(0)
