extends SceneTree

## Suite de pruebas de integración multinivel: Alineación vertical de escaleras en DungeonPresentationBuilder.

func _init() -> void:
	print("--- Running test_stair_multifloor_vertical_alignment ---")

	var config_script = preload("res://src/dungeon_generator/config/dungeon_config.gd")
	var multi_generator_script = preload("res://src/dungeon_generator/core/multi_floor_generator.gd")
	var presentation_builder_script = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
	var profile_loader_script = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

	var cfg = config_script.new()
	cfg.seed = 998877
	cfg.min_target_rooms = 5
	cfg.max_target_rooms = 8
	cfg.total_floors = 3
	cfg.floor_height = 6.0
	cfg.wall_height = 3 # 3 * 2.0 = 6.0m de altura

	var loader = profile_loader_script.new()
	var bundle = loader.load_full_archetype_bundle("mausoleum")

	# 1. Generar resultado de datos multinivel (3 pisos)
	var multi_gen = multi_generator_script.new()
	var multi_result = multi_gen.generate_multi_floor(cfg)
	assert(multi_result != null, "MultiFloor result must be non-null")
	assert(multi_result.get_floor_count() == 3, "Must have 3 floors")

	# 2. Materializar presentación 3D
	var pres_builder = presentation_builder_script.new()
	var active_root := Node3D.new()
	var pres_res = pres_builder.build_multi_floor_presentation(multi_result, null, null, cfg, active_root)
	assert(pres_res.success, "Presentation build must succeed")

	var root_3d: Node3D = pres_res.presentation_root
	assert(root_3d != null, "Presentation root must exist")

	# 3. Validar cada piso y sus escaleras
	for f_num in range(3):
		var floor_node: Node3D = root_3d.get_node_or_null("Floor_%d" % f_num)
		assert(floor_node != null, "Floor_%d container must exist" % f_num)

		var stairs_container: Node3D = floor_node.get_node_or_null("Stairs")
		if stairs_container != null:
			for stair_node in stairs_container.get_children():
				if stair_node is Node3D:
					assert(is_equal_approx(stair_node.position.y, 0.0),
						"Stair %s in Floor_%d must have local Y=0.0, but got %f" % [stair_node.name, f_num, stair_node.position.y]
					)
					var is_down = stair_node.get_meta("is_downward", false)
					print("  [OK] Floor_%d %s (%s) local Y = 0.0 (Global X=%f, Y=%f, Z=%f)" % [
						f_num, stair_node.name, "DOWN" if is_down else "UP",
						stair_node.global_position.x, stair_node.global_position.y, stair_node.global_position.z
					])

	root_3d.free()
	active_root.free()

	print("\n==================================================================")
	print("[PASS] test_stair_multifloor_vertical_alignment passed 100%!")
	print("==================================================================\n")
	quit(0)
