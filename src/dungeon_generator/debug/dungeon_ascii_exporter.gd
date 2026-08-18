class_name DungeonAsciiExporter
extends RefCounted

## Exportador de plano de mazmorra a texto / ASCII estructurado para análisis y depuración rápida.

static func export_ascii(result: DungeonResult, semantic: DungeonSemanticResult = null, crop_bounds: bool = true) -> String:
	if result == null or result.grid == null:
		return "Error: Sin datos de mazmorra para exportar."

	var grid := result.grid
	var gw: int = grid.width
	var gh: int = grid.height

	# Mapear puertas
	var DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")
	var door_map: Dictionary = {}
	if result.door_pairs != null:
		for dp in result.door_pairs:
			if dp != null:
				if dp.door_a != null:
					var is_open_a: bool = (dp.door_a.door_type == DoorTypeScript.DoorType.OPEN_PASSAGE)
					door_map[dp.door_a.position] = "O" if is_open_a else "D"
				if dp.door_b != null:
					var is_open_b: bool = (dp.door_b.door_type == DoorTypeScript.DoorType.OPEN_PASSAGE)
					door_map[dp.door_b.position] = "O" if is_open_b else "D"

	# Mapear objetivos
	var obj_map: Dictionary = {}
	var spawn_pos := Vector2i(-1, -1)
	if semantic != null and semantic.objectives != null:
		for obj in semantic.objectives:
			match obj.type:
				ObjectiveData.ObjectiveType.SPAWN:
					obj_map[obj.position] = "S"
					spawn_pos = obj.position
				ObjectiveData.ObjectiveType.BOSS:
					obj_map[obj.position] = "B"
				ObjectiveData.ObjectiveType.TREASURE, ObjectiveData.ObjectiveType.QUEST_ITEM:
					obj_map[obj.position] = "K"
				ObjectiveData.ObjectiveType.STAIRS_DOWN, ObjectiveData.ObjectiveType.STAIRS_UP:
					obj_map[obj.position] = "E"

	if spawn_pos == Vector2i(-1, -1) and not result.rooms.is_empty():
		spawn_pos = result.rooms[0].get_center()
		obj_map[spawn_pos] = "S"

	# Calcular bounding box ocupado por el suelo y pasillos
	var min_x: int = 0
	var min_y: int = 0
	var max_x: int = gw - 1
	var max_y: int = gh - 1

	if crop_bounds:
		var found_any := false
		var b_min_x: int = gw
		var b_min_y: int = gh
		var b_max_x: int = 0
		var b_max_y: int = 0

		for y in range(gh):
			for x in range(gw):
				var p := Vector2i(x, y)
				var ctype: int = grid.get_cell(p)
				if ctype != CellGrid.CellType.VOID and ctype != CellGrid.CellType.WALL:
					found_any = true
					b_min_x = mini(b_min_x, x)
					b_min_y = mini(b_min_y, y)
					b_max_x = maxi(b_max_x, x)
					b_max_y = maxi(b_max_y, y)

		if found_any:
			min_x = maxi(0, b_min_x - 2)
			min_y = maxi(0, b_min_y - 2)
			max_x = mini(gw - 1, b_max_x + 2)
			max_y = mini(gh - 1, b_max_y + 2)

	# Construir encabezado
	var out := "```text\n"
	out += "=== DUNGEON ASCII MAP ===\n"
	out += "Semilla: %d | Piso: %d\n" % [result.seed_used, result.floor_number]
	out += "Habitaciones: %d | Corredores: %d | Puertas: %d\n" % [result.rooms.size(), result.corridor_paths.size(), result.door_pairs.size()]
	out += "Spawn: (%d, %d) | Dimensiones: %dx%d (Visual: %d..%d, %d..%d)\n" % [spawn_pos.x, spawn_pos.y, gw, gh, min_x, max_x, min_y, max_y]
	out += "Leyenda: [#] Muro  [.] Sala  [=] Pasillo  [D] Puerta Roja  [O] Arco Azul  [S] Spawn  [B] Boss  [K] Llave/Tesoro  [E] Salida\n"
	out += "--------------------------------------------------------------------------------\n"

	# Dibujar filas del mapa
	for y in range(min_y, max_y + 1):
		var row_str: String = "%2d: " % y
		for x in range(min_x, max_x + 1):
			var p := Vector2i(x, y)

			if obj_map.has(p):
				row_str += obj_map[p]
			elif door_map.has(p):
				row_str += door_map[p]
			else:
				var ctype: int = grid.get_cell(p)
				match ctype:
					CellGrid.CellType.FLOOR:
						row_str += "."
					CellGrid.CellType.CORRIDOR:
						row_str += "="
					CellGrid.CellType.DOOR:
						row_str += "="
					CellGrid.CellType.WALL:
						row_str += "#"
					CellGrid.CellType.COLUMN:
						row_str += "C"
					_:
						row_str += " "
		out += row_str + "\n"

	out += "--------------------------------------------------------------------------------\n"
	out += "Salas:\n"
	for r in result.rooms:
		if r != null:
			var c: Vector2i = r.get_center()
			out += "  • Sala #%d (%s): Pos=(%d,%d), Tamaño=(%dx%d), Centro=(%d,%d)\n" % [
				r.id, r.room_type, r.rect.position.x, r.rect.position.y, r.rect.size.x, r.rect.size.y, c.x, c.y
			]
	out += "```\n"

	return out
