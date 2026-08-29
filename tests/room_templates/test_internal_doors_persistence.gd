extends SceneTree

const _RoomTemplateLabStateScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_lab_state.gd")
const _RoomTemplateRepoScript = preload("res://src/dungeon_generator/tools/room_template_lab/room_template_repository.gd")
const _RoomTemplateLoaderScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_loader.gd")
const _ShapeCarverScript = preload("res://src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd")

func _init() -> void:
	print("--- Running test_internal_doors_persistence ---")
	var state := _RoomTemplateLabStateScript.new()
	var repo := _RoomTemplateRepoScript.new()
	var loader := _RoomTemplateLoaderScript.new()

	state.template_id = &"test_palace_hall"
	state.display_name = "Test Palace Hall"
	state.tags = [&"custom", &"royal_tomb", &"ceremonial"]

	# Paint 10x10 room
	state.fill_rect(Rect2i(0, 0, 10, 10), 1)

	# Place internal doors
	state.set_internal_door(Vector2i(5, 2), &"door")
	state.set_internal_door(Vector2i(5, 5), &"locked_door")
	state.set_internal_door(Vector2i(5, 8), &"arch")

	assert(state.has_internal_door(Vector2i(5, 2)), "FAIL: state should have door at (5, 2)")
	assert(state.get_internal_door_type(Vector2i(5, 5)) == &"locked_door", "FAIL: state should have locked_door at (5, 5)")
	assert(state.get_internal_door_type(Vector2i(5, 8)) == &"arch", "FAIL: state should have arch at (5, 8)")

	# Build template and verify serialization
	var tpl = state.build_template_from_state()
	var dict = repo.template_to_dictionary(tpl)
	assert(dict.has("custom_layout"), "FAIL: dict must have custom_layout")
	assert(dict["custom_layout"].has("internal_doors"), "FAIL: custom_layout must have internal_doors")
	assert(dict["custom_layout"]["internal_doors"].size() == 3, "FAIL: must have 3 serialized doors")

	# Parse back from dictionary
	var loaded_tpl = loader.parse_template_dictionary(dict)
	assert(loaded_tpl != null, "FAIL: loaded template must not be null")
	assert(loaded_tpl.custom_layout.has("internal_doors"), "FAIL: loaded template must have internal_doors")

	# Test shape carving
	var grid := CellGrid.new(20, 20, CellGrid.CellType.WALL)
	var room := RoomData.new(1, Rect2i(2, 2, 10, 10), &"boss")
	room.custom_data = {}
	var rng := RandomNumberGenerator.new()
	var carve_res = _ShapeCarverScript.carve(grid, room, loaded_tpl, [], rng, 0)
	assert(carve_res != null, "FAIL: carve_res must not be null")

	# Check door stamping and room metadata
	assert(room.custom_data.has("internal_doors"), "FAIL: room.custom_data must have internal_doors")
	var doors_meta: Array = room.custom_data["internal_doors"]
	assert(doors_meta.size() == 3, "FAIL: room must record 3 internal doors")
	print("Carved doors metadata: ", doors_meta)

	print("PASS: test_internal_doors_persistence passed successfully!")
	quit(0)
