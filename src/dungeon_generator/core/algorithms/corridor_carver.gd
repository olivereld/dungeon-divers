class_name CorridorCarver
extends RefCounted

## Tallador de corredores entre habitaciones para CellGrid.
## Soporta estilos en L, recto y orgánico con cuellos de botella de 1 celda en las puertas.

enum Style {
	L_SHAPED,
	STRAIGHT,
	ORGANIC
}

var style: Style = Style.L_SHAPED
var width: int = 2
var wiggle: float = 0.2

func carve(grid: CellGrid, from: Vector2i, to: Vector2i, rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()

	# Asegurar que los umbrales de inicio y fin sean exactamente de 1 celda de ancho
	if grid.is_in_bounds(from) and grid.get_cell(from) == CellGrid.CellType.WALL:
		grid.set_cell(from, CellGrid.CellType.CORRIDOR)
	if grid.is_in_bounds(to) and grid.get_cell(to) == CellGrid.CellType.WALL:
		grid.set_cell(to, CellGrid.CellType.CORRIDOR)

	match style:
		Style.L_SHAPED:
			var h_first: bool = rng.randf() > 0.5
			_carve_l_shaped(grid, from, to, h_first)
		Style.STRAIGHT:
			_carve_straight(grid, from, to)
		Style.ORGANIC:
			_carve_organic(grid, from, to, rng)

	# Re-asegurar que las celdas de umbral inicial y final queden perfectamente como 1 celda
	if grid.is_in_bounds(from) and grid.get_cell(from) == CellGrid.CellType.WALL:
		grid.set_cell(from, CellGrid.CellType.CORRIDOR)
	if grid.is_in_bounds(to) and grid.get_cell(to) == CellGrid.CellType.WALL:
		grid.set_cell(to, CellGrid.CellType.CORRIDOR)

func _carve_cell(grid: CellGrid, pos: Vector2i) -> void:
	if grid.is_in_bounds(pos) and grid.get_cell(pos) == CellGrid.CellType.WALL:
		grid.set_cell(pos, CellGrid.CellType.CORRIDOR)

func _carve_brush(grid: CellGrid, center: Vector2i, from_pt: Vector2i, to_pt: Vector2i) -> void:
	# Si estamos exactamente en el umbral de entrada o salida, tallar solo 1 celda
	if center == from_pt or center == to_pt:
		_carve_cell(grid, center)
		return

	if width <= 1:
		_carve_cell(grid, center)
		return

	var half_w: int = width / 2
	for dy in range(-half_w, half_w + (width % 2)):
		for dx in range(-half_w, half_w + (width % 2)):
			var p := center + Vector2i(dx, dy)
			# Evitar ensanchar si toca directamente el perímetro inmediato de los umbrales
			if p == from_pt or p == to_pt or (p - from_pt).length_squared() <= 1 or (p - to_pt).length_squared() <= 1:
				if p == center:
					_carve_cell(grid, p)
			else:
				_carve_cell(grid, p)

func _carve_l_shaped(grid: CellGrid, from: Vector2i, to: Vector2i, h_first: bool) -> void:
	if h_first:
		# Horizontal primero
		var x_step: int = 1 if to.x >= from.x else -1
		var x := from.x
		while x != to.x + x_step:
			_carve_brush(grid, Vector2i(x, from.y), from, to)
			x += x_step

		# Vertical después
		var y_step: int = 1 if to.y >= from.y else -1
		var y := from.y
		while y != to.y + y_step:
			_carve_brush(grid, Vector2i(to.x, y), from, to)
			y += y_step
	else:
		# Vertical primero
		var y_step: int = 1 if to.y >= from.y else -1
		var y := from.y
		while y != to.y + y_step:
			_carve_brush(grid, Vector2i(from.x, y), from, to)
			y += y_step

		# Horizontal después
		var x_step: int = 1 if to.x >= from.x else -1
		var x := from.x
		while x != to.x + x_step:
			_carve_brush(grid, Vector2i(x, to.y), from, to)
			x += x_step

func _carve_straight(grid: CellGrid, from: Vector2i, to: Vector2i) -> void:
	var dx: int = absi(to.x - from.x)
	var dy: int = -absi(to.y - from.y)
	var sx: int = 1 if from.x < to.x else -1
	var sy: int = 1 if from.y < to.y else -1
	var err: int = dx + dy

	var curr := from
	while true:
		_carve_brush(grid, curr, from, to)
		if curr == to:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			curr.x += sx
		if e2 <= dx:
			err += dx
			curr.y += sy

func _carve_organic(grid: CellGrid, from: Vector2i, to: Vector2i, rng: RandomNumberGenerator) -> void:
	var curr := from
	var max_steps: int = (absi(to.x - from.x) + absi(to.y - from.y)) * 3
	var steps: int = 0

	while curr != to and steps < max_steps:
		steps += 1
		_carve_brush(grid, curr, from, to)

		var diff := to - curr
		var next_step := Vector2i.ZERO

		if rng.randf() < wiggle:
			var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			next_step = dirs[rng.randi() % dirs.size()]
		else:
			if absi(diff.x) > absi(diff.y):
				next_step = Vector2i(1 if diff.x > 0 else -1, 0)
			elif diff.y != 0:
				next_step = Vector2i(0, 1 if diff.y > 0 else -1)
			elif diff.x != 0:
				next_step = Vector2i(1 if diff.x > 0 else -1, 0)

		var target_pos := curr + next_step
		if grid.is_in_bounds(target_pos):
			curr = target_pos

	_carve_brush(grid, to, from, to)
