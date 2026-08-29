extends SceneTree

const _LabStateScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_lab_state.gd")
const _RepositoryScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_repository.gd")
const _ShapeCarverScript = preload("res://src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd")

func _init() -> void:
	print("--- Running test_custom_layout_persistence ---")
	var state := _LabStateScript.new()
	var repo := _RepositoryScript.new()

	state.template_id = &"test_hollow_template"
	state.display_name = "Hollow Template"

	# Paint a 6x6 ring of floor cells with a 2x2 hole in the center (from 0 to 5)
	# Hole at (2,2), (2,3), (3,2), (3,3)
	for y in range(6):
		for x in range(6):
			if not (x in [2, 3] and y in [2, 3]):
				state.set_cell(Vector2i(x, y), 1)

	assert(state.get_painted_cell_count() == 32, "FAIL: 32 floor cells should be painted")

	# Place anchor at (1, 1) and entrance at (2, 5)
	state.set_anchor(&"relic", Vector2i(1, 1))
	state.add_entrance(Vector2i(2, 5))

	# 1. Build template with custom layout
	var tpl = state.build_template_from_state()
	assert(tpl != null, "FAIL: template is null")
	assert(tpl.custom_layout is Dictionary, "FAIL: custom_layout missing")
	assert(tpl.custom_layout["cells"].size() == 32, "FAIL: custom_layout should have 32 cells")

	# 2. Serialize & Deserialize JSON
	var json_dict = repo.template_to_dictionary(tpl)
	assert(json_dict.has("custom_layout"), "FAIL: json dictionary missing custom_layout")

	var loader := RoomTemplateLoader.new()
	var reloaded_tpl = loader.parse_template_dictionary(json_dict)
	assert(reloaded_tpl != null, "FAIL: reloaded template is null")
	assert(reloaded_tpl.custom_layout["cells"].size() == 32, "FAIL: reloaded custom_layout cell count mismatch")

	# 3. Carve room using custom layout and verify hole is preserved
	var grid := CellGrid.new(10, 10, CellGrid.CellType.WALL)
	var room := RoomData.new(1, Rect2i(2, 2, 6, 6), &"tomb")
	var carve_res = _ShapeCarverScript.carve(grid, room, reloaded_tpl, [Vector2i(4, 7)], null, 0)
	assert(carve_res != null, "FAIL: carve_res is null")

	# Check outer cells are floor
	assert(grid.get_cell(Vector2i(2, 2)) == CellGrid.CellType.FLOOR, "FAIL: (2,2) should be floor")
	# Check center hole cells are WALL (not floor)
	assert(grid.get_cell(Vector2i(4, 4)) == CellGrid.CellType.WALL, "FAIL: center hole at (4,4) should remain WALL")
	assert(grid.get_cell(Vector2i(5, 4)) == CellGrid.CellType.WALL, "FAIL: center hole at (5,4) should remain WALL")

	# Check custom anchor resolved
	assert(carve_res.resolved_anchors.has(&"relic"), "FAIL: relic anchor should be resolved")
	assert(carve_res.resolved_anchors[&"relic"] == Vector2i(3, 3), "FAIL: relic anchor offset mismatch")

	print("PASS: test_custom_layout_persistence passed successfully!")
	quit(0)
