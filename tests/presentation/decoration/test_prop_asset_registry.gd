extends SceneTree

const PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const PropAssetDefinitionScript = preload("res://src/presentation/decoration/assets/prop_asset_definition.gd")
const PropAssetSourceScript = preload("res://src/presentation/decoration/assets/prop_asset_source.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_prop_asset_registry ---")
	print("==================================================================")

	var registry := PropAssetRegistryScript.new()

	# 1. Comprobar definiciones estándar pre-registradas
	assert(registry.has_definition(&"sarcophagus_stone_closed"), "FAIL: Missing sarcophagus_stone_closed")
	assert(registry.has_definition(&"sarcophagus_stone_open"), "FAIL: Missing sarcophagus_stone_open")
	assert(registry.has_definition(&"stone_altar_center"), "FAIL: Missing stone_altar_center")
	assert(registry.has_definition(&"church_pew_wall"), "FAIL: Missing church_pew_wall")
	assert(registry.has_definition(&"tombstone_classic_wall"), "FAIL: Missing tombstone_classic_wall")
	assert(registry.has_definition(&"fortress_table_center"), "FAIL: Missing fortress_table_center")
	assert(registry.has_definition(&"fortress_chest_corner"), "FAIL: Missing fortress_chest_corner")
	assert(registry.has_definition(&"mine_crate_corner"), "FAIL: Missing mine_crate_corner")
	assert(registry.has_definition(&"mine_barrel_wall"), "FAIL: Missing mine_barrel_wall")
	print("  [OK] Default standard definitions present in registry.")

	# 2. Consultar definición concreta
	var sarc_def = registry.get_definition(&"sarcophagus_stone_closed")
	assert(sarc_def != null, "FAIL: Sarcophagus definition is null")
	assert(sarc_def.source_type == PropAssetSourceScript.SourceType.PROCEDURAL, "FAIL: Expected PROCEDURAL source type")
	assert(sarc_def.procedural_builder_id == &"sarcophagus_prop", "FAIL: Builder ID mismatch")
	assert(sarc_def.procedural_params.get("style", -1) == 0, "FAIL: Param mismatch")
	print("  [OK] PropAssetDefinition fields verified.")

	# 3. Consultar ID desconocido: debe retornar null sin fallar
	var unknown_def = registry.get_definition(&"unknown_nonexistent_prop_xyz")
	assert(unknown_def == null, "FAIL: Unknown ID must return null")
	assert(not registry.has_definition(&"unknown_nonexistent_prop_xyz"), "FAIL: Unknown ID should not be found")
	print("  [OK] Unknown ID query returns null gracefully.")

	# 4. Registrar nueva definición personalizada dinámicamente
	var custom_def := PropAssetDefinitionScript.create_procedural_definition(
		&"custom_statue", &"tombstone_prop", {"style": 1}, Vector3(2, 2, 2)
	)
	registry.register_definition(custom_def)
	assert(registry.has_definition(&"custom_statue"), "FAIL: Custom definition not registered")
	var retrieved = registry.get_definition(&"custom_statue")
	assert(retrieved == custom_def, "FAIL: Retrieved definition does not match")
	print("  [OK] Dynamic custom definition registration verified.")

	print("[PASS] test_prop_asset_registry completed successfully!")
	quit(0)
