extends SceneTree

## Suite de integración End-to-End para la Fase 10: Verticalidad y Multi-Floor.
## Valida el pipeline completo multinivel: MultiFloorGenerator -> MultiFloorValidator -> Presentation (Multi-Floor + Stairs + Atomic Swap).

func _init() -> void:
	print("================================================================")
	print("   EJECUTANDO SUITE DE INTEGRACION E2E - FASE 10 (VERTICAL)    ")
	print("================================================================")

	var multi_generator := MultiFloorGenerator.new()
	var multi_validator := MultiFloorValidator.new()
	var presentation_builder := DungeonPresentationBuilder.new()

	var biome := BiomeProfile.new()
	biome.name = "TestMultiFloorDungeon"
	biome.id = &"test_multifloor"

	var config := DungeonConfig.new()
	config.grid_width = 48
	config.grid_height = 48
	config.total_floors = 3
	config.floor_height = 6.0
	config.mission_depth = 4
	config.seed = 133742
	config.use_fixed_seed = true

	# 1. Generación Lógica Multinivel (Core)
	print("\n[PASO 1] Generación Lógica de 3 Pisos con Escaleras...")
	var multi_res: DungeonMultiFloorResult = multi_generator.generate_multi_floor(config)
	assert(multi_res != null, "DungeonMultiFloorResult must not be null")
	assert(multi_res.is_valid, "DungeonMultiFloorResult must be marked valid")
	assert(multi_res.get_floor_count() == 3, "Must generate exactly 3 floors")
	assert(multi_res.vertical_connections.size() == 2, "Must contain 2 vertical connections")
	print("  [OK] 3 floors generated with %d vertical connections and seed trace v1" % multi_res.vertical_connections.size())

	# 2. Validación Formal de Alcanzabilidad y Topología Vertical
	print("\n[PASO 2] Validación Formal del Grafo Multi-Piso...")
	var v_res: MultiFloorValidationResult = multi_validator.validate(multi_res)
	assert(v_res.is_valid, "Multi-floor validation must pass: %s" % v_res.to_debug_string())
	assert(v_res.is_connected, "Floors graph must be fully connected")
	assert(v_res.endpoints_valid, "All stair endpoints must be valid")
	assert(v_res.path_exists, "Continuous path between floors must exist")
	print("  [OK] Formal topology validation PASSED")

	# 3. Materialización 3D Multinivel y Atomic Swap en Presentation
	print("\n[PASO 3] Materialización 3D en Staging y Atomic Swap...")
	var root_node := Node3D.new()

	var pres_res: DungeonPresentationResult = presentation_builder.build_multi_floor_presentation(
		multi_res, root_node, biome, config, null
	)

	assert(pres_res.success, "Multi-floor presentation must succeed")
	assert(pres_res.staging_committed, "Staging root must be committed via Atomic Swap")
	assert(pres_res.presentation_root != null, "Presentation root must exist")

	var pres_root: Node3D = pres_res.presentation_root
	assert(root_node.get_child_count() == 1, "Root node must contain the committed presentation")

	# 4. Verificar Estructura de Pisos y Cotas de Altura 3D
	for f_num in range(3):
		var floor_node: Node3D = pres_root.get_node_or_null("Floor_%d" % f_num)
		assert(floor_node != null, "Floor container 'Floor_%d' must exist" % f_num)

		var expected_x: float = float(f_num) * ((float(config.grid_width) * config.cell_size) + 80.0)
		assert(is_equal_approx(floor_node.position.x, expected_x), "Floor %d X-position must be %.1fm (got %.1fm)" % [
			f_num, expected_x, floor_node.position.x
		])

		var floor_grid_map = floor_node.get_node_or_null("FloorGridMap")
		assert(floor_grid_map != null, "Floor %d must have FloorGridMap" % f_num)

		var walls = floor_node.get_node_or_null("ContinuousWalls")
		assert(walls != null, "Floor %d must have ContinuousWalls" % f_num)

	# 5. Verificar Escaleras Materializadas, Metadatos de Transición e InteractionArea
	var f0_node: Node3D = pres_root.get_node_or_null("Floor_0")
	var f1_node: Node3D = pres_root.get_node_or_null("Floor_1")
	var f2_node: Node3D = pres_root.get_node_or_null("Floor_2")

	var f0_stairs = f0_node.get_node_or_null("Stairs")
	var f1_stairs = f1_node.get_node_or_null("Stairs")
	var f2_stairs = f2_node.get_node_or_null("Stairs")

	assert(f0_stairs != null and f0_stairs.get_child_count() > 0, "Floor 0 must contain Stairs")
	assert(f1_stairs != null and f1_stairs.get_child_count() > 0, "Floor 1 must contain Stairs")
	assert(f2_stairs != null and f2_stairs.get_child_count() > 0, "Floor 2 must contain Stairs")

	var first_stair = f0_stairs.get_child(0)
	assert(first_stair.has_meta("connection_id"), "Stair must have connection_id metadata")
	assert(first_stair.has_meta("target_floor"), "Stair must have target_floor metadata")
	assert(first_stair.get_meta("target_floor") == 1, "Floor 0 stair must target Floor 1")
	assert(first_stair.get_node_or_null("InteractionArea") != null, "Stair must have InteractionArea child trigger")

	print("  [OK] Multi-floor presentation 3D successfully rendered 3 elevated floors with stairs, transition metadata and InteractionAreas")

	root_node.free()
	print("\n================================================================")
	print(">>> TODAS LAS PRUEBAS DE INTEGRACION DE LA FASE 10 PASARON CON EXITO! <<<")
	print("================================================================\n")
	quit(0)
