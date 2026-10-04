class_name MovementGrid
extends RefCounted

## Adaptador de geometría y datos espaciales para el movimiento por celdas.
## Es la ÚNICA autoridad para conversiones cell <-> world y consultas de celda.
## No duplica datos de WorldCell ni decide reglas de gameplay.

const _WorldResultScript = preload("res://src/world_generator/data/world_result.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")

var cell_size: float = 1.0
var world_origin: Vector3 = Vector3.ZERO

## Fuente de datos subyacente
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

## Configura el adaptador a partir de un WorldResult generado.
func setup_from_world_result(result: WorldResult, p_cell_size: float = 1.0, p_origin: Vector3 = Vector3.ZERO) -> void:
	cell_size = maxf(p_cell_size, 0.001)
	world_origin = p_origin
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
	_cells = cells_dict
	_hydrology = hydrology_source
	_bounds = bounds
	_has_explicit_bounds = (bounds.size.x > 0 and bounds.size.y > 0)

# ==============================================================================
# Autoridad de Transformación Espacial (Cell <-> World)
# ==============================================================================

## Convierte una coordenada de celda a la posición central en el mundo 3D.
## Eje X = cell.x * cell_size
## Eje Z = cell.y * cell_size
## Eje Y = cota de elevación del terreno en dicha celda
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
# Consultas de Celdas
# ==============================================================================

func has_cell(cell: Vector2i) -> bool:
	if _has_explicit_bounds and not _bounds.has_point(cell):
		return false
	return _cells.has(cell)

func get_cell(cell: Vector2i) -> WorldCell:
	return _cells.get(cell, null)

func is_walkable(cell: Vector2i) -> bool:
	var c: WorldCell = get_cell(cell)
	if c == null:
		return false
	return c.is_walkable

func get_elevation_level(cell: Vector2i) -> int:
	var c: WorldCell = get_cell(cell)
	if c == null:
		return 0
	return c.elevation_level

func get_height(cell: Vector2i) -> float:
	var c: WorldCell = get_cell(cell)
	if c == null:
		return 0.0
	return c.height

func is_water(cell: Vector2i) -> bool:
	if _hydrology != null and _hydrology.has_method("is_water"):
		return _hydrology.is_water(cell)
	return false

func get_bounds() -> Rect2i:
	return _bounds
