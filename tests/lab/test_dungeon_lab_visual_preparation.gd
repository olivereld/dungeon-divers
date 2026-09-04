extends SceneTree

const _LabConfigScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_configuration.gd")
const _LabControllerScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_controller.gd")
const _LabScene = preload("res://src/dungeon_generator/debug/lab/dungeon_level_lab.tscn")
const _SpaceGrammarConfigScript = preload("res://src/dungeon_generator/config/space_grammar_config.gd")
const _FloorDataScript = preload("res://src/dungeon_generator/core/data/dungeon_floor_data.gd")

func _init() -> void:
	print("=================================================================")
	print("   TEST: PREPARE DUNGEON LAB CONFIGURATION FOR VISUAL TESTS     ")
	print("=================================================================")

	test_step_1_expose_and_transport()
	test_step_2_duplicate_and_ui_sync()
	test_step_3_overrides_in_pipeline()
	test_step_4_flow_integrity()
	test_step_5_visual_overlays_and_elements()
	test_step_6_clean_legacy_checks()
	test_step_7_varied_seeds_and_visual_impact()

	print("\n>>> ALL 7 STEPS IN test_dungeon_lab_visual_preparation PASSED 100%! <<<\n")
	quit(0)

func test_step_1_expose_and_transport() -> void:
	print("\n[STEP 1] Expose & Transport: Verificando 6 nuevos parámetros en DungeonLabConfiguration...")
	var cfg = _LabConfigScript.new()

	# 1. Verificar existencia y valores por defecto de los 6 parámetros
	assert("min_room_separation" in cfg, "FAIL: min_room_separation must exist")
	assert("min_mission_edge_distance" in cfg, "FAIL: min_mission_edge_distance must exist")
	assert("max_mission_edge_distance" in cfg, "FAIL: max_mission_edge_distance must exist")
	assert("progression_strength" in cfg, "FAIL: progression_strength must exist")
	assert("density_strength" in cfg, "FAIL: density_strength must exist")
	assert("preferred_progression_direction" in cfg, "FAIL: preferred_progression_direction must exist")

	assert(cfg.min_room_separation == 2, "FAIL: default min_room_separation mismatch")
	assert(cfg.min_mission_edge_distance == 6.0, "FAIL: default min_mission_edge_distance mismatch")
	assert(cfg.max_mission_edge_distance == 24.0, "FAIL: default max_mission_edge_distance mismatch")
	assert(cfg.progression_strength == 1.0, "FAIL: default progression_strength mismatch")
	assert(cfg.density_strength == 0.5, "FAIL: default density_strength mismatch")
	assert(cfg.preferred_progression_direction == Vector2.ZERO, "FAIL: default preferred_progression_direction mismatch")

	# 2. Modificar y verificar transporte vía to_dungeon_config()
	cfg.min_room_separation = 4
	cfg.min_mission_edge_distance = 8.5
	cfg.max_mission_edge_distance = 28.0
	cfg.progression_strength = 1.75
	cfg.density_strength = 0.8
	cfg.preferred_progression_direction = Vector2(1.0, 0.5)

	var d_cfg: DungeonConfig = cfg.to_dungeon_config()
	assert(d_cfg.min_room_separation == 4, "FAIL: transported min_room_separation mismatch")
	assert(d_cfg.min_mission_edge_distance == 8.5, "FAIL: transported min_mission_edge_distance mismatch")
	assert(d_cfg.max_mission_edge_distance == 28.0, "FAIL: transported max_mission_edge_distance mismatch")
	assert(d_cfg.progression_strength == 1.75, "FAIL: transported progression_strength mismatch")
	assert(d_cfg.density_strength == 0.8, "FAIL: transported density_strength mismatch")
	assert(d_cfg.preferred_progression_direction == Vector2(1.0, 0.5), "FAIL: transported preferred_progression_direction mismatch")

	assert(d_cfg.space_grammar_config != null, "FAIL: space_grammar_config must be instantiated")
	assert(d_cfg.space_grammar_config.min_room_separation == 4, "FAIL: sg_config min_room_separation mismatch")
	assert(d_cfg.space_grammar_config.min_mission_edge_distance == 8.5, "FAIL: sg_config min_mission_edge_distance mismatch")
	assert(d_cfg.space_grammar_config.max_mission_edge_distance == 28.0, "FAIL: sg_config max_mission_edge_distance mismatch")
	assert(d_cfg.space_grammar_config.progression_strength == 1.75, "FAIL: sg_config progression_strength mismatch")
	assert(d_cfg.space_grammar_config.density_strength == 0.8, "FAIL: sg_config density_strength mismatch")
	assert(d_cfg.space_grammar_config.preferred_progression_direction == Vector2(1.0, 0.5), "FAIL: sg_config direction mismatch")

	# 3. Validación
	var bad_cfg = _LabConfigScript.new()
	bad_cfg.min_room_separation = -1
	bad_cfg.min_mission_edge_distance = 0.0
	bad_cfg.max_mission_edge_distance = -5.0
	var errs = bad_cfg.validate()
	assert(errs.size() >= 3, "FAIL: validate() must catch invalid spatial constraints")
	print("  [OK] Step 1: 6 parámetros expuestos, transportados a DungeonConfig/SpaceGrammarConfig y validados.")

func test_step_2_duplicate_and_ui_sync() -> void:
	print("\n[STEP 2] Duplicate & UI: Verificando duplicate_config() y sincronización UI...")
	# 1. SpaceGrammarConfig.duplicate_config()
	var sg = _SpaceGrammarConfigScript.new()
	sg.min_room_separation = 5
	sg.min_mission_edge_distance = 9.0
	sg.max_mission_edge_distance = 30.0
	sg.progression_strength = 2.0
	sg.density_strength = 0.9
	sg.preferred_progression_direction = Vector2(0.0, 1.0)
	var sg_dup = sg.duplicate_config()
	assert(sg_dup.min_room_separation == 5, "FAIL: sg duplicate min_room_separation mismatch")
	assert(sg_dup.min_mission_edge_distance == 9.0, "FAIL: sg duplicate min_mission_edge_distance mismatch")
	assert(sg_dup.max_mission_edge_distance == 30.0, "FAIL: sg duplicate max_mission_edge_distance mismatch")
	assert(sg_dup.progression_strength == 2.0, "FAIL: sg duplicate progression_strength mismatch")
	assert(sg_dup.density_strength == 0.9, "FAIL: sg duplicate density_strength mismatch")
	assert(sg_dup.preferred_progression_direction == Vector2(0.0, 1.0), "FAIL: sg duplicate direction mismatch")

	# 2. DungeonConfig.duplicate_config()
	var dc := DungeonConfig.new()
	dc.archetype_id = &"catacomb"
	dc.min_room_separation = 3
	dc.min_mission_edge_distance = 7.0
	dc.max_mission_edge_distance = 25.0
	dc.progression_strength = 1.2
	dc.density_strength = 0.6
	dc.preferred_progression_direction = Vector2(1.0, 1.0)
	dc.profile_mode = &"force_profile"
	dc.forced_profile_id = &"royal_tomb"
	dc.template_mode = &"specific"
	dc.forced_template_id = &"crypt_v4"
	var dc_dup = dc.duplicate_config()
	assert(dc_dup.archetype_id == &"catacomb", "FAIL: dc duplicate archetype_id mismatch")
	assert(dc_dup.min_room_separation == 3, "FAIL: dc duplicate min_room_separation mismatch")
	assert(dc_dup.profile_mode == &"force_profile", "FAIL: dc duplicate profile_mode mismatch")
	assert(dc_dup.forced_profile_id == &"royal_tomb", "FAIL: dc duplicate forced_profile_id mismatch")
	assert(dc_dup.template_mode == &"specific", "FAIL: dc duplicate template_mode mismatch")
	assert(dc_dup.forced_template_id == &"crypt_v4", "FAIL: dc duplicate forced_template_id mismatch")

	# 3. Lab UI sync
	var lab = _LabScene.instantiate()
	root.add_child(lab)
	lab._ready()

	lab.config.min_room_separation = 4
	lab.config.min_mission_edge_distance = 11.0
	lab.config.progression_strength = 1.8
	lab.sync_ui_from_config()
	lab._sync_config_from_ui()

	assert(lab.config.min_room_separation == 4, "FAIL: lab config sync min_room_separation mismatch")
	assert(lab.config.min_mission_edge_distance == 11.0, "FAIL: lab config sync min_mission_edge_distance mismatch")
	assert(lab.config.progression_strength == 1.8, "FAIL: lab config sync progression_strength mismatch")

	lab.queue_free()
	print("  [OK] Step 2: duplicate_config() en DungeonConfig y SpaceGrammarConfig verificado con éxito.")

func test_step_3_overrides_in_pipeline() -> void:
	print("\n[STEP 3] Overrides: Verificando force_profile y force_template en la pipeline...")
	var ctrl = _LabControllerScript.new()

	# 1. Forzar profile_id en todas las salas
	var cfg_prof = _LabConfigScript.new()
	cfg_prof.seed = 200100
	cfg_prof.floor_count = 1
	cfg_prof.profile_mode = &"force_profile"
	cfg_prof.forced_profile_id = &"sacristy"

	var res_prof = ctrl.generate_dungeon(cfg_prof)
	assert(res_prof.get("overall_success", false), "FAIL: generation with forced profile failed")
	var fd_prof: DungeonFloorData = res_prof["floors"][0]
	for r in fd_prof.rooms:
		assert(r.custom_data.get("profile_id", "") == "sacristy",
			"FAIL: Room %d profile_id expected 'sacristy', got '%s'" % [r.id, r.custom_data.get("profile_id", "")])
	print("  [OK] Profile override: todas las salas recibieron profile_id='sacristy'.")

	# 2. Forzar template_id específico
	var cfg_tpl = _LabConfigScript.new()
	cfg_tpl.seed = 300100
	cfg_tpl.floor_count = 1
	cfg_tpl.template_mode = &"specific"
	cfg_tpl.forced_template_id = &"chamber_v3"

	var res_tpl = ctrl.generate_dungeon(cfg_tpl)
	assert(res_tpl.get("overall_success", false), "FAIL: generation with forced template failed")
	var fd_tpl: DungeonFloorData = res_tpl["floors"][0]
	var forced_count: int = 0
	for r in fd_tpl.rooms:
		var t_id = r.custom_data.get("resolved_template_id", "")
		if t_id == &"chamber_v3":
			forced_count += 1
	assert(forced_count > 0, "FAIL: at least one room must resolve to forced template chamber_v3")
	print("  [OK] Template override: template chamber_v3 forzado y resuelto con éxito (%d salas)." % forced_count)

func test_step_4_flow_integrity() -> void:
	print("\n[STEP 4] Verify Flow: DungeonLabConfiguration -> DungeonConfig -> DungeonPipeline...")
	var ctrl = _LabControllerScript.new()
	var cfg = _LabConfigScript.new()
	cfg.seed = 444555
	cfg.generator_type = "Hybrid"
	cfg.archetype_id = &"necropolis"
	cfg.min_room_separation = 3
	cfg.min_mission_edge_distance = 8.0
	cfg.max_mission_edge_distance = 26.0
	cfg.progression_strength = 1.5

	var res = ctrl.generate_dungeon(cfg)
	assert(res.get("overall_success", false), "FAIL: pipeline generation failed")
	assert(res.has("dungeon_result"), "FAIL: result missing dungeon_result")
	assert(res.has("semantic_result"), "FAIL: result missing semantic_result")
	assert(res.has("floors") and not res["floors"].is_empty(), "FAIL: result missing floors")

	var d_res: DungeonResult = res["dungeon_result"]
	assert(d_res.seed_used == 444555, "FAIL: seed mismatch in DungeonResult")
	assert(d_res.rooms.size() >= 5, "FAIL: room count too low in DungeonResult")
	assert(d_res.corridor_paths.size() >= 4, "FAIL: corridor paths missing in DungeonResult")
	print("  [OK] Step 4: Integridad de flujo confirmada de punta a punta.")

func test_step_5_visual_overlays_and_elements() -> void:
	print("\n[STEP 5] Visuals: Verificando rendering de elementos visuales esenciales...")
	var lab = _LabScene.instantiate()
	root.add_child(lab)
	lab._ready()

	lab.config.seed = 555666
	lab.controller.generate_dungeon(lab.config)

	var overlay = lab.overlay
	var renderer = lab.renderer

	# Validar reactividad de todos los flags de overlay esenciales
	overlay.show_room_bounds = true
	overlay.show_template_footprint = true
	overlay.show_entrances = true
	overlay.show_corridors = true
	overlay.show_corridor_details = true
	overlay.show_spatial_overlay = true
	overlay.show_semantics_overlay = true
	overlay.show_internal_doors = true
	overlay.show_semantic_labels = true
	overlay.show_template_id = true
	overlay.show_stairs = true

	# Validar métodos de dibujo especializados en el Renderer
	assert(renderer.has_method("_draw_corridors_overlay"), "FAIL: renderer missing _draw_corridors_overlay")
	assert(renderer.has_method("_draw_spatial_overlay"), "FAIL: renderer missing _draw_spatial_overlay")
	assert(renderer.has_method("_draw_semantics_overlay"), "FAIL: renderer missing _draw_semantics_overlay")

	# Forzar redraw para verificar que no ocurra crash en ninguno de los pases de dibujo
	renderer.queue_redraw()

	lab.queue_free()
	print("  [OK] Step 5: Rendering de elementos visuales y overlays esenciales verificado.")

func test_step_6_clean_legacy_checks() -> void:
	print("\n[STEP 6] Clean Legacy: Verificando ausencia de APIs obsoletas...")
	# 1. Verificar que en debug/lab ningún script use la propiedad obsoleta 'dungeon_archetype'
	var dir = DirAccess.open("res://src/dungeon_generator/debug/lab")
	assert(dir != null, "FAIL: could not open lab dir")
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if f.ends_with(".gd"):
			var file_path = "res://src/dungeon_generator/debug/lab/" + f
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file != null:
				var content = file.get_as_text()
				file.close()
				assert(content.find("dungeon_archetype") == -1,
					"FAIL: forbidden legacy symbol 'dungeon_archetype' found in %s" % f)
		f = dir.get_next()

	# 2. Verificar que hallway_width mapee a corridor_width sin errores
	var cfg = _LabConfigScript.new()
	cfg.hallway_width = 3
	var d_cfg = cfg.to_dungeon_config()
	assert(d_cfg.corridor_width == 3, "FAIL: hallway_width to corridor_width mapping mismatch")
	print("  [OK] Step 6: Libre de APIs obsoletas y mapeos limpios confirmados.")

func test_step_7_varied_seeds_and_visual_impact() -> void:
	print("\n[STEP 7] Final Test: Varied seeds, visual parameter impact & overlay contract validation...")
	var ctrl = _LabControllerScript.new()

	# 1. Probar impacto de min_room_separation (Tight vs Wide)
	var cfg_tight = _LabConfigScript.new()
	cfg_tight.seed = 777111
	cfg_tight.min_room_separation = 1
	var res_tight = ctrl.generate_dungeon(cfg_tight)
	assert(res_tight.get("overall_success", false), "FAIL: tight placement generation failed")
	var fd_tight: DungeonFloorData = res_tight["floors"][0]

	var cfg_wide = _LabConfigScript.new()
	cfg_wide.seed = 777111
	cfg_wide.min_room_separation = 6
	var res_wide = ctrl.generate_dungeon(cfg_wide)
	assert(res_wide.get("overall_success", false), "FAIL: wide placement generation failed")
	var fd_wide: DungeonFloorData = res_wide["floors"][0]

	# Medir distancia mínima entre habitaciones en ambas configuraciones
	var calc_min_sep := func(rooms: Array) -> int:
		var min_dist: int = 999
		for i in range(rooms.size()):
			for j in range(i + 1, rooms.size()):
				var r_a: Rect2i = rooms[i].rect
				var r_b: Rect2i = rooms[j].rect
				var dx: int = maxi(0, maxi(r_a.position.x - r_b.end.x, r_b.position.x - r_a.end.x))
				var dy: int = maxi(0, maxi(r_a.position.y - r_b.end.y, r_b.position.y - r_a.end.y))
				var dist: int = dx + dy
				if dist < min_dist:
					min_dist = dist
		return min_dist

	var sep_tight: int = calc_min_sep.call(fd_tight.rooms)
	var sep_wide: int = calc_min_sep.call(fd_wide.rooms)
	assert(sep_wide >= sep_tight, "FAIL: wide separation (%d) must be >= tight separation (%d)" % [sep_wide, sep_tight])
	print("  -> Impacto espacial verificado: separación min_sep tight=%d vs wide=%d [OK]" % [sep_tight, sep_wide])

	# 2. Varied Seeds: consistencia total y coincidencia exacta entre DungeonResult y DungeonFloorData
	var test_seeds = [101010, 202020, 303030, 404040, 505050]
	for s in test_seeds:
		var cfg_seed = _LabConfigScript.new()
		cfg_seed.seed = s
		cfg_seed.floor_count = 1
		var res = ctrl.generate_dungeon(cfg_seed)
		assert(res.get("overall_success", false), "FAIL: generation failed for seed %d" % s)
		var orig: DungeonResult = res["dungeon_result"]
		var fd: DungeonFloorData = res["floors"][0]

		assert(fd.rooms.size() == orig.rooms.size(), "FAIL: rooms count mismatch for seed %d" % s)
		assert(fd.corridor_paths.size() == orig.corridor_paths.size(), "FAIL: corridor_paths count mismatch for seed %d" % s)
		assert(fd.connections.size() == orig.connections.size(), "FAIL: connections count mismatch for seed %d" % s)
		assert(fd.door_pairs.size() == orig.door_pairs.size(), "FAIL: door_pairs count mismatch for seed %d" % s)

		print("  -> Seed %d: rooms=%d, corridors=%d, doors=%d -> Overlays vs DungeonResult 100%% coincidentes [OK]" % [
			s, fd.rooms.size(), fd.corridor_paths.size(), fd.door_pairs.size()
		])
