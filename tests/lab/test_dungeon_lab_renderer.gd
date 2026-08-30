extends SceneTree

const _RendererScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_renderer.gd")
const _OverlayScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_overlay.gd")
const _PipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _FloorDataScript = preload("res://src/dungeon_generator/core/data/dungeon_floor_data.gd")

func _init() -> void:
	print("--- Running test_dungeon_lab_renderer ---")
	var pipeline = _PipelineScript.new()
	var cfg := DungeonConfig.new()
	cfg.seed = 100001
	var gen_res = pipeline.generate(cfg)
	assert(gen_res != null, "FAIL: pipeline generate failed")

	var floor_data = _FloorDataScript.new(1, gen_res.grid, gen_res.rooms, gen_res.doors)

	var renderer := _RendererScript.new()
	var overlay: _OverlayScript = _OverlayScript.new()
	var overlay_change_emitted := [false]
	overlay.overlay_changed.connect(func(): overlay_change_emitted[0] = true)
	overlay.show_template_id = false
	assert(overlay_change_emitted[0], "FAIL: overlay_changed signal must fire on property modification")

	renderer.render_floor(floor_data, overlay)
	assert(renderer.get_rendered_room_count() > 0, "FAIL: rooms must be registered in renderer")

	# Test selection
	var first_room = floor_data.rooms[0]
	var room_center_world = (Vector2(first_room.get_center()) + Vector2(0.5, 0.5)) * renderer.transform.cell_size
	var selected = renderer.select_room_at_world(room_center_world)
	assert(selected != null and selected.id == first_room.id, "FAIL: select_room_at_world should select clicked room")

	# Test failure rendering
	renderer.render_failure("Generation failed test")
	assert(renderer.get_rendered_room_count() == 0, "FAIL: failure render must clear room count")
	assert(renderer.has_error_state(), "FAIL: renderer must indicate error state")

	print("PASS: test_dungeon_lab_renderer passed!")
	renderer.free()
	quit(0)
