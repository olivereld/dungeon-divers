class_name CompositionStrategy
extends RefCounted

## Genera posiciones candidatas para habitaciones usando una distribución
## espacial intencional en lugar de aleatoriedad pura o espiral radial.
##
## La estrategia decide el patrón de distribución (scattered, grid, clustered,
## directional) y genera candidatos. El placement loop de SpaceGrammar
## selecciona el primer candidato válido (sin colisión).

var _rng: RandomNumberGenerator

func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


## Genera posiciones candidatas para colocar todas las habitaciones.
## Retorna un Array de Vector2i con las posiciones absolutas en el grid.
## El orden importa: las primeras posiciones son para las primeras habitaciones.
func generate_candidates(
	room_count: int,
	room_sizes: Array[Vector2i],
	bounds: Rect2i,
) -> Array[Vector2i]:
	# Elegir estrategia según semilla y cantidad
	var strategy_index: int = _rng.randi_range(0, 3)
	match strategy_index:
		0:
			return _scattered(room_count, room_sizes, bounds)
		1:
			return _grid_aligned(room_count, room_sizes, bounds)
		2:
			return _clustered(room_count, room_sizes, bounds)
		_:
			return _directional(room_count, room_sizes, bounds)


## ─── Estrategia 0: Scattered ────────────────────────────────────────
## Posiciones dispersas con jitter controlado. Similar al actual pero
## sin center bias y con distribución más uniforme.
func _scattered(
	room_count: int,
	room_sizes: Array[Vector2i],
	bounds: Rect2i,
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var margin: int = 2

	# Generar posiciones en espiral invertida desde un punto aleatorio
	# (no siempre el centro del grid)
	var origin := Vector2i(
		_rng.randi_range(bounds.position.x + 8, bounds.end.x - 8),
		_rng.randi_range(bounds.position.y + 8, bounds.end.y - 8),
	)

	for i in range(room_count):
		var size: Vector2i = room_sizes[i] if i < room_sizes.size() else Vector2i(7, 7)
		var placed := false

		# Intentar con offsets crecientes desde origin
		for radius in range(0, 30, 2):
			for _attempt in range(8):
				var angle: float = _rng.randf() * TAU
				var ox: int = int(cos(angle) * radius)
				var oy: int = int(sin(angle) * radius)
				var pos := origin + Vector2i(ox, oy) - size / 2

				if _is_valid_position(pos, size, bounds, margin, candidates):
					candidates.append(pos)
					placed = true
					break
			if placed:
				break

		if not placed:
			# Fallback: random dentro de bounds
			for _attempt in range(50):
				var pos := Vector2i(
					_rng.randi_range(bounds.position.x, bounds.end.x - size.x),
					_rng.randi_range(bounds.position.y, bounds.end.y - size.y),
				)
				if _is_valid_position(pos, size, bounds, margin, candidates):
					candidates.append(pos)
					placed = true
					break

		if not placed:
			candidates.append(origin - size / 2)

	return candidates


## ─── Estrategia 1: Grid-aligned ─────────────────────────────────────
## Divide el espacio en una grilla y coloca habitaciones en celdas,
## con jitter para evitar monotonia. Produce layouts más ordenados.
func _grid_aligned(
	room_count: int,
	room_sizes: Array[Vector2i],
	bounds: Rect2i,
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var margin: int = 2

	# Calcular dimensiones de la grilla
	var cols: int = maxi(2, int(ceil(sqrt(float(room_count)))))
	var rows: int = maxi(2, int(ceil(float(room_count) / float(cols))))

	var cell_w: int = bounds.size.x / cols
	var cell_h: int = bounds.size.y / rows

	# Generar orden aleatorio de celdas
	var cell_indices: Array[int] = []
	for i in range(cols * rows):
		cell_indices.append(i)
	_shuffle(cell_indices)

	for i in range(room_count):
		var size: Vector2i = room_sizes[i] if i < room_sizes.size() else Vector2i(7, 7)
		var cell_idx: int = cell_indices[i % cell_indices.size()]
		var col: int = cell_idx % cols
		var row: int = cell_idx / cols

		# Centro de la celda + jitter
		var cell_center_x: int = bounds.position.x + col * cell_w + cell_w / 2
		var cell_center_y: int = bounds.position.y + row * cell_h + cell_h / 2
		var jitter_x: int = _rng.randi_range(-cell_w / 4, cell_w / 4)
		var jitter_y: int = _rng.randi_range(-cell_h / 4, cell_h / 4)

		var pos := Vector2i(
			clampi(cell_center_x + jitter_x - size.x / 2, bounds.position.x, bounds.end.x - size.x),
			clampi(cell_center_y + jitter_y - size.y / 2, bounds.position.y, bounds.end.y - size.y),
		)

		if _is_valid_position(pos, size, bounds, margin, candidates):
			candidates.append(pos)
		else:
			# Buscar posición válida cerca del centro de celda
			var found := false
			for r in range(1, 6):
				for _attempt in range(8):
					var angle: float = _rng.randf() * TAU
					var ox: int = int(cos(angle) * r)
					var oy: int = int(sin(angle) * r)
					var near := pos + Vector2i(ox, oy)
					if _is_valid_position(near, size, bounds, margin, candidates):
						candidates.append(near)
						found = true
						break
				if found:
					break
			if not found:
				candidates.append(pos)

	return candidates


## ─── Estrategia 2: Clustered ────────────────────────────────────────
## Agrupa habitaciones por tipo: START lejos del centro, boss en esquina,
## explore/combat dispersos. Produce layouts con zonas diferenciadas.
func _clustered(
	room_count: int,
	room_sizes: Array[Vector2i],
	bounds: Rect2i,
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var margin: int = 2

	# Definir zonas del grid
	var zones: Array[Vector2i] = [
		Vector2i(bounds.position.x, bounds.position.y),                                       # top-left
		Vector2i(bounds.end.x - 20, bounds.position.y),                                       # top-right
		Vector2i(bounds.position.x, bounds.end.y - 20),                                       # bottom-left
		Vector2i(bounds.end.x - 20, bounds.end.y - 20),                                       # bottom-right
		Vector2i(bounds.position.x + bounds.size.x / 2 - 10, bounds.position.y + bounds.size.y / 2 - 10), # center
	]
	_shuffle(zones)

	for i in range(room_count):
		var size: Vector2i = room_sizes[i] if i < room_sizes.size() else Vector2i(7, 7)
		var zone: Vector2i = zones[i % zones.size()]

		# Colocar dentro de la zona con jitter
		var pos := Vector2i(
			_rng.randi_range(zone.x, zone.x + 18),
			_rng.randi_range(zone.y, zone.y + 18),
		)

		if _is_valid_position(pos, size, bounds, margin, candidates):
			candidates.append(pos)
		else:
			# Expandir búsqueda dentro de la zona
			var found := false
			for expand in range(5, 20, 3):
				for _attempt in range(10):
					var ex := Vector2i(
						_rng.randi_range(zone.x - expand, zone.x + 18 + expand),
						_rng.randi_range(zone.y - expand, zone.y + 18 + expand),
					)
					if _is_valid_position(ex, size, bounds, margin, candidates):
						candidates.append(ex)
						found = true
						break
				if found:
					break
			if not found:
				candidates.append(pos)

	return candidates


## ─── Estrategia 3: Directional ──────────────────────────────────────
## Coloca habitaciones a lo largo de un eje principal (horizontal,
## vertical o diagonal), con variación perpendicular. Produce layouts
## lineales o en "L".
func _directional(
	room_count: int,
	room_sizes: Array[Vector2i],
	bounds: Rect2i,
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var margin: int = 2

	# Eje principal aleatorio
	var axis_choice: int = _rng.randi_range(0, 2)
	var primary_horizontal: bool = axis_choice != 1  # 0 o 2 = horizontal
	var diagonal: bool = axis_choice == 2

	var total_width: int = bounds.size.x
	var total_height: int = bounds.size.y

	# Espaciamiento entre habitaciones
	var spacing: int = maxi(3, total_width / (room_count + 1)) if primary_horizontal else maxi(3, total_height / (room_count + 1))

	for i in range(room_count):
		var size: Vector2i = room_sizes[i] if i < room_sizes.size() else Vector2i(7, 7)

		# Posición a lo largo del eje
		var along: int = (i + 1) * spacing
		var perp: int = total_height / 2 if primary_horizontal else total_width / 2

		# Variación perpendicular
		var perp_range: int = maxi(4, (total_height if primary_horizontal else total_width) / 4)
		perp += _rng.randi_range(-perp_range, perp_range)

		# Variación diagonal
		if diagonal:
			perp = along + _rng.randi_range(-perp_range, perp_range)

		var pos: Vector2i
		if primary_horizontal:
			pos = Vector2i(
				clampi(bounds.position.x + along - size.x / 2, bounds.position.x, bounds.end.x - size.x),
				clampi(bounds.position.y + perp - size.y / 2, bounds.position.y, bounds.end.y - size.y),
			)
		else:
			pos = Vector2i(
				clampi(bounds.position.x + perp - size.x / 2, bounds.position.x, bounds.end.x - size.x),
				clampi(bounds.position.y + along - size.y / 2, bounds.position.y, bounds.end.y - size.y),
			)

		if _is_valid_position(pos, size, bounds, margin, candidates):
			candidates.append(pos)
		else:
			# Buscar cerca
			var found := false
			for r in range(1, 8):
				for _attempt in range(6):
					var angle: float = _rng.randf() * TAU
					var ox: int = int(cos(angle) * r)
					var oy: int = int(sin(angle) * r)
					var near := pos + Vector2i(ox, oy)
					if _is_valid_position(near, size, bounds, margin, candidates):
						candidates.append(near)
						found = true
						break
				if found:
					break
			if not found:
				candidates.append(pos)

	return candidates


## ─── Helpers ─────────────────────────────────────────────────────────

func _is_valid_position(
	pos: Vector2i,
	size: Vector2i,
	bounds: Rect2i,
	margin: int,
	existing: Array[Vector2i],
) -> bool:
	# Check bounds
	if pos.x < bounds.position.x or pos.y < bounds.position.y:
		return false
	if pos.x + size.x > bounds.end.x or pos.y + size.y > bounds.end.y:
		return false

	# Check collision with existing candidates
	var candidate_rect := Rect2i(pos, size)
	for other_pos in existing:
		# Usar tamaño promedio para la separación (aproximación)
		var avg_size := Vector2i(7, 7)
		var other_rect := Rect2i(other_pos, avg_size)
		if candidate_rect.intersects(other_rect.expanded(margin)):
			return false

	return true


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp
