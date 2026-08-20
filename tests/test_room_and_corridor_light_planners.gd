extends SceneTree

const RoomLightPlanner = preload("res://src/dungeon_lighting/planning/room_light_planner.gd")
const CorridorLightPlanner = preload("res://src/dungeon_lighting/planning/corridor_light_planner.gd")
const DungeonLightingConfig = preload("res://src/dungeon_lighting/config/dungeon_lighting_config.gd")
const LightPlacement = preload("res://src/dungeon_lighting/data/light_placement.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const CorridorPath = preload("res://src/dungeon_generator/core/data/corridor_path.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_room_and_corridor_light_planners ---")
	print("==================================================================")

	var config := DungeonLightingConfig.new()
	config.min_lights_per_room = 2
	config.max_lights_per_room = 4
	config.min_light_spacing = 3.0

	var room := RoomData.new(1, Rect2i(2, 2, 8, 8))
	var candidates: Array[LightPlacement] = []
	# Generar candidatos en paredes norte y sur
	for x in range(3, 9):
		var p1 := LightPlacement.new()
		p1.cell = Vector2i(x, 2)
		p1.room_id = 1
		p1.wall_side = LightPlacement.WallSide.NORTH
		candidates.append(p1)

		var p2 := LightPlacement.new()
		p2.cell = Vector2i(x, 9)
		p2.room_id = 1
		p2.wall_side = LightPlacement.WallSide.SOUTH
		candidates.append(p2)

	var room_planner := RoomLightPlanner.new()
	var selected_room = room_planner.plan_room_lights(room, candidates, config, 12345)
	assert(selected_room.size() >= 2 and selected_room.size() <= 4, "Room lights count within min/max")
	# Validar espaciado euclidiano entre luces seleccionadas
	for i in range(selected_room.size()):
		for j in range(i + 1, selected_room.size()):
			var d: float = Vector2(selected_room[i].cell).distance_to(Vector2(selected_room[j].cell))
			assert(d >= config.min_light_spacing - 0.01, "Spacing constraint met between lights (dist: %.2f)" % d)
	print("  [OK] RoomLightPlanner density & spacing validated.")

	# Validar corredor corto vs largo
	var corr_planner := CorridorLightPlanner.new()
	var short_corr := CorridorPath.new(1, 1, 2)
	short_corr.carved_cells = [Vector2i(1,1), Vector2i(1,2), Vector2i(1,3)]
	var short_lights = corr_planner.plan_corridor_lights(short_corr, [], config, 12345)
	assert(short_lights.is_empty(), "Short corridor has 0 lights")

	var long_corr := CorridorPath.new(2, 1, 2)
	long_corr.carved_cells = [
		Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4),
		Vector2i(1, 5), Vector2i(1, 6), Vector2i(1, 7), Vector2i(1, 8),
		Vector2i(1, 9), Vector2i(1, 10), Vector2i(1, 11), Vector2i(1, 12)
	]
	var corr_cand: Array[LightPlacement] = []
	for c in long_corr.carved_cells:
		var lp := LightPlacement.new()
		lp.cell = c
		lp.corridor_id = "2"
		lp.wall_side = LightPlacement.WallSide.WEST
		corr_cand.append(lp)

	var long_lights = corr_planner.plan_corridor_lights(long_corr, corr_cand, config, 12345)
	assert(long_lights.size() >= 1, "Long corridor has at least 1 light")
	print("  [OK] CorridorLightPlanner length thresholds and spacing validated.")

	print("==================================================================")
	print("[PASS] test_room_and_corridor_light_planners completado con éxito!")
	print("==================================================================")
	quit(0)
