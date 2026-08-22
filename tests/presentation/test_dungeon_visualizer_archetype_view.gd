extends SceneTree

## Test suite para validar la integración de la Vista de Arquetipos y el sistema interactivo de Hover/Tooltips en DungeonVisualizer.

const DungeonVisualizer = preload("res://src/dungeon_generator/debug/dungeon_visualizer.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestrator = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_visualizer_archetype_view ---")
	print("==================================================================")

	var visualizer := DungeonVisualizer.new()
	var root := Control.new()
	root.add_child(visualizer)

	# 1. Validar pestañas de la sidebar (Parámetros, Suelos, Arquetipos)
	assert(visualizer._tab_btn_params != null, "FAIL: Params tab button exists")
	assert(visualizer._tab_btn_floors != null, "FAIL: Floors tab button exists")
	assert(visualizer._tab_btn_archetypes != null, "FAIL: Archetypes tab button exists")
	assert(visualizer._tab_archetypes_container != null, "FAIL: Archetypes container exists")

	visualizer._switch_tab(2)
	assert(visualizer._tab_params_container.visible == false, "FAIL: Params hidden on archetypes tab")
	assert(visualizer._tab_floors_container.visible == false, "FAIL: Floors hidden on archetypes tab")
	assert(visualizer._tab_archetypes_container.visible == true, "FAIL: Archetypes visible on archetypes tab")
	print("  [OK] 3-Tab sidebar switching (Parámetros / Suelos / Arquetipos) validated.")

	# 2. Validar botones y modos de vista (Generación vs Arquetipos)
	assert(visualizer._btn_view_generation != null, "FAIL: View mode Generation button exists")
	assert(visualizer._btn_view_archetypes != null, "FAIL: View mode Archetypes button exists")
	assert(visualizer._current_view_mode == DungeonVisualizer.ViewMode.GENERATION, "FAIL: Default view mode is GENERATION")

	visualizer.set_view_mode(DungeonVisualizer.ViewMode.ARCHETYPE)
	assert(visualizer._current_view_mode == DungeonVisualizer.ViewMode.ARCHETYPE, "FAIL: View mode changed to ARCHETYPE")
	assert(visualizer._legend_label.text.contains("ENTRANCE"), "FAIL: Legend updated for archetype view")

	visualizer.set_view_mode(DungeonVisualizer.ViewMode.GENERATION)
	assert(visualizer._current_view_mode == DungeonVisualizer.ViewMode.GENERATION, "FAIL: View mode returned to GENERATION")
	assert(visualizer._legend_label.text.contains("Habitación"), "FAIL: Legend updated for generation view")
	print("  [OK] View mode switching and dynamic legend validated.")

	# 3. Generar mazmorra de prueba y alimentar el visualizador
	var cfg := DungeonConfig.new()
	cfg.seed = 1337
	cfg.use_fixed_seed = true
	cfg.dungeon_archetype = 1 # MAUSOLEUM

	var pipeline := DungeonPipeline.new()
	var res = pipeline.generate(cfg, 5, true)
	assert(res != null, "FAIL: Dungeon generated")

	var orchestrator := SemanticOrchestrator.new()
	var sem = orchestrator.generate_semantics(res, cfg)
	assert(sem != null, "FAIL: Semantics generated")

	visualizer.show_2d_preview(res, sem)
	assert(visualizer.is_2d_preview_mode == true, "FAIL: Visualizer in 2D preview mode")
	assert(visualizer._arch_info_header.text.contains("Mausoleum") or visualizer._arch_info_header.text.contains("MAUSOLEUM") or visualizer._arch_info_header.text.contains("Crypt"), "FAIL: Archetype header populated")
	assert(visualizer._arch_dist_container.get_child_count() > 0, "FAIL: Purpose distribution badges created")
	assert(visualizer._arch_rooms_list.get_child_count() > 0, "FAIL: Room list items created in Archetypes tab")
	print("  [OK] Semantic data feeding and Archetype Tab UI population verified.")

	# 4. Validar Hover y Detección de Salas
	if res.rooms.size() > 0:
		var target_room = res.rooms[0]
		visualizer._build_hover_room_data(target_room, 0, sem)
		assert(not visualizer._hovered_room_data.is_empty(), "FAIL: Hover room data populated")
		assert(visualizer._hovered_room_data.room_id == target_room.id, "FAIL: Hover room id matches")
		assert(visualizer._hovered_room_data.has("purpose_name"), "FAIL: Hover data contains purpose name")
		assert(visualizer._hovered_room_data.has("wall_style"), "FAIL: Hover data contains wall style")
		assert(visualizer._hovered_room_data.has("floor_style"), "FAIL: Hover data contains floor style")
		assert(visualizer._hovered_room_data.has("door_style"), "FAIL: Hover data contains door style")
		print("  [OK] Hover data inspection & architectural profiling verified.")

	root.free()
	print("==================================================================")
	print("[PASS] test_dungeon_visualizer_archetype_view completado con 100% éxito!")
	print("==================================================================")
	quit(0)
