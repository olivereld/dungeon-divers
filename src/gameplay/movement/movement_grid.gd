class_name MovementGrid
extends RefCounted

## Adaptador de geometría y datos espaciales para el movimiento por celdas.
## Es la ÚNICA autoridad para conversiones cell <-> world y consultas de celda.
## Permite consultar el terreno directamente desde WorldResult, ChunkWorld o WorldChunkManager
## de forma dinámica y streaming, sin duplicar colecciones de celdas.

const _WorldResultScript = preload("res://src/world_generator/data/world_result.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")

var cell_size: float = 1.0
var world_origin: Vector3 = Vector3.ZERO

## Fuente de mundo procedural dinámica (ChunkWorld, WorldChunkManager o WorldResult)
var world_source: Object = null

## Callbacks delegados opcionales para inyección o testing desacoplado
var cell_provider: Callable = Callable() # func(cell: Vector2i) -> WorldCell
var water_provider: Callable = Callable() # func(cell: Vector2i) -> bool

## Almacén estático fallback de celdas (para mapas fijos, laboratorios o tests sintéticos)
var _cells: Dictionary = {} # Vector2i -> WorldCell
var _hydrology: RefCounted = null # HydrologyResult
var _dimensions: Vector2i = Vector2i.ZERO
var _bounds: Rect2i = Rect2i()
var _has_explicit_bounds: bool = false

func _init(
	p_cell_size: float = 1.0,
	p_origin: Vector3 = Vector3.ZERO
) -> void:
	cell_size = maxf(p_cell_size, 0.001)
	world_origin = p_origin

## Configuración universal desde cualquier fuente de mundo procedural (WorldResult, ChunkWorld, etc.).
func setup_from_source(p_source: Object, p_cell_size: float = 1.0, p_origin: Vector3 = Vector3.ZERO) -> void:
	cell_size = maxf(p_cell_size, 0.001)
	world_origin = p_origin
	world_source = p_source

	if p_source is _WorldResultScript:
		setup_from_world_result(p_source as WorldResult, p_cell_size, p_origin)
	else:
		_cells = {}
		_hydrology = null
		_has_explicit_bounds = false

## Configura el adaptador a partir de un WorldResult generado estático.
func setup_from_world_result(result: WorldResult, p_cell_size: float = 1.0, p_origin: Vector3 = Vector3.ZERO) -> void:
	cell_size = maxf(p_cell_size, 0.001)
	world_origin = p_origin
	world_source = result
	if result != null:
		_cells = result.cells
		_hydrology = result.hydrology
		_dimensions = result.dimensions
		_bounds = Rect2i(0, 0, _dimensions.x, _dimensions.y)
		_has_explicit_bounds = (_dimensions.x > 0 and _dimensions.y > 0)
	else:
		_cells = {}
		_hydrology = null
		_dimensions = Vector2i.ZERO
		_has_explicit_bounds = false

## Configura el adaptador a partir de un diccionario de celdas existente (para tests o escenas aisladas).
func setup_from_cells(
	cells_dict: Dictionary,
	hydrology_source: RefCounted = null,
	p_cell_size: float = 1.0,
	p_origin: Vector3 = Vector3.ZERO,
	bounds: Rect2i = Rect2i()
) -> void:
	cell_size = maxf(p_cell_size, 0.001)
	world_origin = p_origin
	world_source = null
	_cells = cells_dict
	_hydrology = hydrology_source
	_bounds = bounds
	_has_explicit_bounds = (bounds.size.x > 0 and bounds.size.y > 0)

# ==============================================================================
# Autoridad de Transformación Espacial (Cell <-> World)
# ==============================================================================

## Convierte una coordenada de celda a la posición central en el mundo 3D.
## Eje X = (cell.x + 0.5) * cell_size + origin.x
## Eje Z = (cell.y + 0.5) * cell_size + origin.z
## Eje Y = cota de elevación física del terreno en dicha celda + y_offset
func cell_to_world(cell: Vector2i, y_offset: float = 0.0) -> Vector3:
	var h: float = get_height(cell)
	var wx: float = (float(cell.x) + 0.5) * cell_size + world_origin.x
	var wz: float = (float(cell.y) + 0.5) * cell_size + world_origin.z
	var wy: float = h + world_origin.y + y_offset
	return Vector3(wx, wy, wz)

## Convierte una coordenada 3D continua del mundo a la celda discreta correspondiente.
func world_to_cell(world_pos: Vector3) -> Vector2i:
	var local_x: float = (world_pos.x - world_origin.x) / cell_size
	var local_z: float = (world_pos.z - world_origin.z) / cell_size
	return Vector2i(int(floor(local_x)), int(floor(local_z)))

# ==============================================================================
# Consultas de Celdas (Resolución Dinámica o Estática)
# ==============================================================================

func _get_nav_grid() -> Object:
	if world_source != null:
		if "navigation_grid" in world_source and world_source.navigation_grid != null:
			return world_source.navigation_grid
		var cm = world_source.get("chunk_manager")
		if cm != null and "navigation_grid" in cm and cm.navigation_grid != null:
			return cm.navigation_grid
	return null

func get_cell_availability(cell: Vector2i) -> int:
	var nav: Object = _get_nav_grid()
	if nav != null and nav.has_method("get_cell_availability"):
		return nav.get_cell_availability(cell)
	return -1

func find_lower_support(cell: Vector2i, max_depth: int = 6) -> Dictionary:
	var nav: Object = _get_nav_grid()
	if nav != null and nav.has_method("find_lower_support"):
		return nav.find_lower_support(cell, max_depth)
	if has_cell(cell):
		return {
			"found": true,
			"elevation_level": get_elevation_level(cell),
			"height": get_height(cell),
			"walkable": is_walkable(cell)
		}
	return {"found": false, "elevation_level": 0, "height": 0.0, "walkable": false}

func has_cell(cell: Vector2i) -> bool:
	if _has_explicit_bounds and not _bounds.has_point(cell):
		return false
	var nav: Object = _get_nav_grid()
	if nav != null and nav.has_method("has_cell"):
		return nav.has_cell(cell)
	if cell_provider.is_valid() or world_source != null:
		return get_cell(cell) != null
	return _cells.has(cell)

func get_cell(cell: Vector2i) -> WorldCell:
	# 1. Consulta por callback personalizado
	if cell_provider.is_valid():
		return cell_provider.call(cell)

	# 2. Consulta dinámica por fuente procedural (ChunkWorld, WorldChunkManager, etc.)
	if world_source != null:
		if world_source.has_method("get_cell"):
			var c = world_source.get_cell(cell)
			if c != null:
				return c
		if world_source.has_method("get_cell_at_world_pos"):
			var c = world_source.get_cell_at_world_pos(cell)
			if c != null:
				return c
		var cm = world_source.get("chunk_manager")
		if cm != null and cm.has_method("get_cell"):
			var c = cm.get_cell(cell)
			if c != null:
				return c

	# 3. Fallback en almacén estático
	return _cells.get(cell, null)

func is_walkable(cell: Vector2i) -> bool:
	var nav: Object = _get_nav_grid()
	if nav != null and nav.has_method("is_walkable"):
		return nav.is_walkable(cell)
	var c: WorldCell = get_cell(cell)
	if c == null:
		return false
	return c.is_walkable

func get_elevation_level(cell: Vector2i) -> int:
	var nav: Object = _get_nav_grid()
	if nav != null and nav.has_method("get_elevation_level"):
		return nav.get_elevation_level(cell)
	var c: WorldCell = get_cell(cell)
	if c == null:
		return 0
	return c.elevation_level

func get_height(cell: Vector2i) -> float:
	var nav: Object = _get_nav_grid()
	if nav != null and nav.has_method("get_height"):
		return nav.get_height(cell)
	var c: WorldCell = get_cell(cell)
	if c == null:
		return 0.0
	return c.height

func is_water(cell: Vector2i) -> bool:
	# 1. Callback personalizado
	if water_provider.is_valid():
		return water_provider.call(cell)

	# 2. Consulta en fuente procedural
	if world_source != null:
		if world_source.has_method("is_water"):
			return world_source.is_water(cell.x, cell.y)
		var cm = world_source.get("chunk_manager")
		if cm != null and cm.has_method("is_water"):
			return cm.is_water(cell.x, cell.y)

	# 3. Consulta en hidrología compartida o celda
	if _hydrology != null and _hydrology.has_method("is_water"):
		return _hydrology.is_water(cell)

	var c := get_cell(cell)
	if c != null and "is_water" in c:
		return c.is_water

	return false

func get_bounds() -> Rect2i:
	return _bounds
