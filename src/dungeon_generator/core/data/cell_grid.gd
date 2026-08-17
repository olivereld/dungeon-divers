class_name CellGrid
extends RefCounted

## Modelo de datos central: rejilla 2D desacoplada del renderizador.
## Utiliza un PackedInt32Array plano para máxima eficiencia de memoria e iteración.

enum CellType {
	VOID = -1,         # Fuera de límites / no inicializado
	WALL = 0,          # Muro sólido
	FLOOR = 1,         # Suelo transitable normal
	DOOR = 2,          # Puerta normal
	LOCKED_DOOR = 3,   # Puerta que requiere llave
	STAIRS_DOWN = 4,   # Pasaje al siguiente piso (descenso)
	STAIRS_UP = 5,     # Retorno al piso anterior (ascenso)
	SPAWN = 6,         # Punto de aparición del jugador
	OBJECTIVE = 7,     # Objetivo de misión
	CORRIDOR = 8,      # Suelo de pasillo / corredor
	COLUMN = 9,        # Columna o pilar estructural
	OBSTACLE = 10,     # Obstáculo no perteneciente a pared
}

var width: int = 0
var height: int = 0
var _cells: PackedInt32Array = PackedInt32Array()
var _metadata: Dictionary = {}

func _init(w: int = 32, h: int = 32, default_type: CellType = CellType.WALL) -> void:
	width = maxi(1, w)
	height = maxi(1, h)
	var total_cells: int = width * height
	_cells.resize(total_cells)
	_cells.fill(int(default_type))
	_metadata.clear()

func clear(default_type: CellType = CellType.VOID) -> void:
	_cells.fill(int(default_type))
	_metadata.clear()

func get_width() -> int:
	return width

func get_height() -> int:
	return height

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func _get_index(pos: Vector2i) -> int:
	return pos.y * width + pos.x

func get_cell(pos: Vector2i) -> CellType:
	if not is_in_bounds(pos):
		return CellType.VOID
	return _cells[_get_index(pos)] as CellType

func set_cell(pos: Vector2i, type: CellType) -> void:
	if is_in_bounds(pos):
		_cells[_get_index(pos)] = int(type)

func is_walkable(pos: Vector2i) -> bool:
	var t: CellType = get_cell(pos)
	return t == CellType.FLOOR or t == CellType.DOOR or t == CellType.CORRIDOR \
		or t == CellType.STAIRS_DOWN or t == CellType.STAIRS_UP \
		or t == CellType.SPAWN or t == CellType.OBJECTIVE

func is_solid(pos: Vector2i) -> bool:
	var t: CellType = get_cell(pos)
	return t == CellType.WALL or t == CellType.COLUMN or t == CellType.OBSTACLE or t == CellType.VOID

func get_neighbors_4(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var offsets: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(-1, 0),
		Vector2i(1, 0)
	]
	for offset in offsets:
		var n: Vector2i = pos + offset
		if is_in_bounds(n):
			result.append(n)
	return result

func get_neighbors_8(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var n: Vector2i = pos + Vector2i(dx, dy)
			if is_in_bounds(n):
				result.append(n)
	return result

func count_neighbors(pos: Vector2i, type: CellType, use_8: bool = true) -> int:
	var count: int = 0
	if use_8:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var n := pos + Vector2i(dx, dy)
				if not is_in_bounds(n):
					if type == CellType.WALL:
						count += 1
				elif get_cell(n) == type:
					count += 1
	else:
		var n4 := get_neighbors_4(pos)
		for n in n4:
			if get_cell(n) == type:
				count += 1
	return count

func count_walkable_neighbors(pos: Vector2i, use_8: bool = true) -> int:
	var count: int = 0
	var neighbors: Array[Vector2i] = get_neighbors_8(pos) if use_8 else get_neighbors_4(pos)
	for n in neighbors:
		if is_walkable(n):
			count += 1
	return count

func set_metadata(pos: Vector2i, key: String, value: Variant) -> void:
	if not _metadata.has(pos):
		_metadata[pos] = {}
	_metadata[pos][key] = value

func get_metadata(pos: Vector2i, key: String, default_value: Variant = null) -> Variant:
	if _metadata.has(pos) and _metadata[pos].has(key):
		return _metadata[pos][key]
	return default_value

func get_cell_metadata_dict(pos: Vector2i) -> Dictionary:
	if _metadata.has(pos):
		return _metadata[pos].duplicate(true)
	return {}

func set_cell_metadata_dict(pos: Vector2i, data: Dictionary) -> void:
	if data.is_empty():
		_metadata.erase(pos)
	else:
		_metadata[pos] = data.duplicate(true)

func find_cells_of_type(type: CellType) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var target_int: int = int(type)
	for y in range(height):
		var row_offset: int = y * width
		for x in range(width):
			if _cells[row_offset + x] == target_int:
				result.append(Vector2i(x, y))
	return result

func duplicate_grid() -> CellGrid:
	var copy := CellGrid.new(width, height, CellType.WALL)
	copy._cells = _cells.duplicate()
	copy._metadata = _metadata.duplicate(true)
	return copy

func get_bounds() -> Rect2i:
	return Rect2i(0, 0, width, height)

func fill_rect(rect: Rect2i, type: CellType) -> void:
	var clipped := rect.intersection(get_bounds())
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			set_cell(Vector2i(x, y), type)

func to_debug_string() -> String:
	var lines: PackedStringArray = []
	for y in range(height):
		var line_chars: PackedStringArray = []
		var row_offset: int = y * width
		for x in range(width):
			var cell: CellType = _cells[row_offset + x] as CellType
			match cell:
				CellType.VOID:
					line_chars.append(" ")
				CellType.WALL:
					line_chars.append("#")
				CellType.FLOOR, CellType.CORRIDOR:
					line_chars.append(".")
				CellType.DOOR:
					line_chars.append("D")
				CellType.LOCKED_DOOR:
					line_chars.append("L")
				CellType.COLUMN:
					line_chars.append("C")
				CellType.OBSTACLE:
					line_chars.append("X")
				CellType.SPAWN:
					line_chars.append("S")
				CellType.OBJECTIVE:
					line_chars.append("O")
				CellType.STAIRS_DOWN:
					line_chars.append(">")
				CellType.STAIRS_UP:
					line_chars.append("<")
				_:
					line_chars.append("?")
		lines.append("".join(line_chars))
	return "\n".join(lines)
