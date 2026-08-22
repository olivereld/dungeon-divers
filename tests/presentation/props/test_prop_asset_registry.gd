extends SceneTree

const PropAssetRegistryScript = preload("res://src/presentation/props/prop_asset_registry.gd")
const PropAssetProviderScript = preload("res://src/presentation/props/prop_asset_provider.gd")
const PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const PropCollisionModeScript = preload("res://src/presentation/props/prop_collision_mode.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_prop_asset_registry ---")
	print("==================================================================")

	var registry := PropAssetRegistryScript.new()

	# 1. Verificar fábricas por defecto
	assert(registry.has_factory(&"sarcophagus_prop"), "FAIL: Missing sarcophagus_prop factory")
	assert(registry.has_factory(&"bench_prop"), "FAIL: Missing bench_prop factory")
	assert(registry.has_factory(&"altar_prop"), "FAIL: Missing altar_prop factory")
	assert(registry.has_factory(&"tombstone_prop"), "FAIL: Missing tombstone_prop factory")
	assert(registry.has_factory(&"chest_prop"), "FAIL: Missing chest_prop factory")
	assert(registry.has_factory(&"crate_prop"), "FAIL: Missing crate_prop factory")
	assert(registry.has_factory(&"barrel_prop"), "FAIL: Missing barrel_prop factory")
	assert(registry.has_factory(&"rubble_prop"), "FAIL: Missing rubble_prop factory")
	print("  [OK] Default procedural prop factories verified in registry.")

	# 2. Instanciación vía Registry
	var sarc_node = registry.create_node(&"sarcophagus_prop", {"style": 0, "is_open": false})
	assert(sarc_node != null and sarc_node is Node3D, "FAIL: Failed to create sarcophagus node")
	sarc_node.free()

	var bench_node = registry.create_node(&"bench_prop", {"style": 0})
	assert(bench_node != null and bench_node is Node3D, "FAIL: Failed to create bench node")
	bench_node.free()
	print("  [OK] Procedural Node3D creation from registry verified.")

	# 3. Registro dinámico de fábrica personalizada
	registry.register_factory(&"custom_pedestal", func(params: Dictionary) -> Node3D:
		var n := Node3D.new()
		n.name = "CustomPedestal"
		return n
	)
	assert(registry.has_factory(&"custom_pedestal"), "FAIL: Custom factory registration failed")
	var custom_n = registry.create_node(&"custom_pedestal", {})
	assert(custom_n != null and custom_n.name == "CustomPedestal", "FAIL: Custom factory invocation failed")
	custom_n.free()
	print("  [OK] Dynamic factory extension verified.")

	# 4. Verificación de PropAssetProvider
	var provider := PropAssetProviderScript.new()
	var style := PropStyleScript.new(
		&"test_sarc", PropStyleScript.Type.SARCOPHAGUS, PropPlacementModeScript.Mode.CENTER,
		PropCollisionModeScript.Mode.BLOCKING, null, &"sarcophagus_prop", {"style": 0}
	)
	var directive := PropDirectiveScript.new(
		&"test_sarc", 1, style, Vector3(0, 0, 0), 0.0, [Vector2i(0, 0)],
		PropPlacementModeScript.Mode.CENTER, PropCollisionModeScript.Mode.BLOCKING
	)
	var node = provider.create_prop_node(directive)
	assert(node != null, "FAIL: PropAssetProvider failed to create node from directive")
	node.free()
	print("  [OK] PropAssetProvider decoupled node generation verified.")

	print("[PASS] test_prop_asset_registry completed successfully!")
	quit(0)
