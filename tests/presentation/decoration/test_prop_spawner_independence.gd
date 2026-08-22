extends SceneTree

const PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const PropAssetDefinitionScript = preload("res://src/presentation/decoration/assets/prop_asset_definition.gd")
const PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const PropCollisionModeScript = preload("res://src/presentation/props/prop_collision_mode.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_prop_spawner_independence ---")
	print("==================================================================")

	# 1. Crear un registry aislado con un prop completamente desconocido
	var custom_reg := PropAssetRegistryScript.new()
	var custom_scene := PackedScene.new()
	var custom_template := Node3D.new()
	custom_template.name = "AlienRelic"
	custom_scene.pack(custom_template)
	custom_template.free()

	var custom_def := PropAssetDefinitionScript.create_scene_definition(&"alien_relic_omega", custom_scene)
	custom_reg.register_definition(custom_def)

	var custom_provider := PropAssetProviderScript.new()
	custom_provider.set_registry(custom_reg)

	# 2. Inyectar provider en PropSpawner
	var spawner := PropSpawnerScript.new(custom_provider)

	# 3. Crear directiva para este prop desconocido
	var style := PropStyleScript.new(
		&"alien_relic_omega", PropStyleScript.Type.SARCOPHAGUS, PropPlacementModeScript.Mode.CENTER,
		PropCollisionModeScript.Mode.BLOCKING, null, &"", {}, 0
	)
	var directive := PropDirectiveScript.new(
		&"alien_relic_omega", 42, style, Vector3(10, 0, 20), 45.0,
		[Vector2i(5, 10)], PropPlacementModeScript.Mode.CENTER, PropCollisionModeScript.Mode.BLOCKING
	)

	# 4. Spawner debe materializarlo con éxito sin conocer el prop de antemano
	var spawned_node = spawner.spawn_prop(directive, null)
	assert(spawned_node != null and spawned_node is Node3D, "FAIL: Spawner failed to spawn uncoupled prop")
	assert(spawned_node.name == "Prop_alien_relic_omega_Room42", "FAIL: Node name mismatch")
	assert(spawned_node.has_meta("prop_directive"), "FAIL: Missing prop_directive metadata")
	assert(spawned_node.get_meta("room_id") == 42, "FAIL: Room ID metadata mismatch")

	spawned_node.free()
	print("  [OK] PropSpawner boundary independence verified with novel uncoupled asset.")

	print("[PASS] test_prop_spawner_independence completed successfully!")
	quit(0)
