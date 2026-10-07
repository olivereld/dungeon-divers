class_name WorldNavigationVisualizer
extends Node3D

## Visualizador 3D de celdas de navegación para depuración en tiempo real.
## Renderiza sobre el terreno una cuadrícula táctica semitransparente:
## - Verde: celda transitable plana (WALKABLE)
## - Azul: borde saltable hacia abajo o escalable hacia arriba (JUMPABLE EDGE)
## - Rojo: celda bloqueada (OBSTACLE / WATER / UNWALKABLE)
## - Amarillo: celda actual del jugador (PLAYER)
## - Naranja/Gris: celda fuera de chunks cargados (UNAVAILABLE)

const _WorldNavGridScript = preload("res://src/world_generator/navigation/world_navigation_grid.gd")
const _ProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")

const _NEIGHBOR_DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(1, -1),
	Vector2i(-1, -1),
]

@export var enabled: bool = false:
	set(val):
		enabled = val
		visible = enabled
		if enabled:
			refresh()

@export var view_radius: int = 14
@export var cell_inset: float = 0.06
@export var y_elevation_offset: float = 0.06

@export_group("Colors")
@export var color_walkable := Color(0.18, 0.85, 0.28, 0.38) # Verde
@export var color_blocked := Color(0.92, 0.16, 0.16, 0.42)  # Rojo
@export var color_player := Color(1.0, 0.88, 0.15, 0.70)   # Amarillo
@export var color_unavailable := Color(0.65, 0.65, 0.65, 0.20) # Gris
@export var color_jump_down := Color(0.12, 0.65, 0.98, 0.48) # Azul cian (salto hacia abajo)
@export var color_jump_up := Color(0.22, 0.45, 0.98, 0.48)   # Azul cobalto (escalón hacia arriba)
@export var color_jump_both := Color(0.16, 0.55, 0.98, 0.50) # Azul (ambas transiciones)
@export var highlight_jumpable_edges: bool = true

var grid: Object = null
var tracked_target: Node3D = null

var _mesh_instance: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _last_rendered_cell: Vector2i = Vector2i(999999, 999999)

func _ready() -> void:
	_setup_mesh_instance()
	visible = enabled

func _setup_mesh_instance() -> void:
	if _mesh_instance != null:
		return

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "NavDebugMeshInstance"

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS

	_mesh_instance.material_override = _material
	add_child(_mesh_instance)

func setup(p_grid: Object, p_target: Node3D = null) -> void:
	grid = p_grid
	tracked_target = p_target
	if grid != null and grid.has_signal("chunk_registered"):
		if not grid.chunk_registered.is_connected(_on_chunk_registered):
			grid.chunk_registered.connect(_on_chunk_registered)
	refresh()

func toggle() -> bool:
	enabled = not enabled
	return enabled

func _on_chunk_registered(_coord: Vector2i) -> void:
	if enabled:
		refresh(true)

func _process(_delta: float) -> void:
	if not enabled or grid == null:
		return

	var current_cell := _get_target_cell()
	if current_cell != _last_rendered_cell:
		refresh()

func _get_target_cell() -> Vector2i:
	if tracked_target != null and is_instance_valid(tracked_target):
		var pos: Vector3 = tracked_target.global_position if tracked_target.is_inside_tree() else tracked_target.position
		if grid != null and grid.has_method("world_to_cell"):
			return grid.world_to_cell(pos)
	return Vector2i.ZERO

func refresh(force: bool = false) -> void:
	if not enabled or grid == null:
		if _mesh_instance != null:
			_mesh_instance.mesh = null
		return

	var center_cell := _get_target_cell()
	if not force and center_cell == _last_rendered_cell:
		return

	_last_rendered_cell = center_cell
	_rebuild_mesh(center_cell)

func _rebuild_mesh(center: Vector2i) -> void:
	if _mesh_instance == null:
		_setup_mesh_instance()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_size: float = grid.cell_size if "cell_size" in grid else 1.0
	var origin: Vector3 = grid.world_origin if "world_origin" in grid else Vector3.ZERO
	var inset: float = clampf(cell_inset, 0.0, 0.4)
	var active_profile: MovementProfile = _get_active_profile()

	var min_x := center.x - view_radius
	var max_x := center.x + view_radius
	var min_y := center.y - view_radius
	var max_y := center.y + view_radius

	for cy in range(min_y, max_y + 1):
		for cx in range(min_x, max_x + 1):
			var cell := Vector2i(cx, cy)
			var is_player_cell := (cell == center)

			# 1. Determinar disponibilidad y transitabilidad
			var is_avail := true
			if grid.has_method("get_cell_availability"):
				var a: int = grid.get_cell_availability(cell)
				is_avail = (a == 0) # 0 = READY
			elif grid.has_method("has_cell"):
				is_avail = grid.has_cell(cell)

			var color: Color
			if not is_avail:
				color = color_unavailable
			elif is_player_cell:
				color = color_player
			else:
				var walkable: bool = grid.is_walkable(cell) if grid.has_method("is_walkable") else false
				if not walkable:
					color = color_blocked
				elif highlight_jumpable_edges:
					var jump_info := _evaluate_jumpable_edges(cell, active_profile)
					if jump_info.can_jump_down and jump_info.can_jump_up:
						color = color_jump_both
					elif jump_info.can_jump_down:
						color = color_jump_down
					elif jump_info.can_jump_up:
						color = color_jump_up
					else:
						color = color_walkable
				else:
					color = color_walkable

			var h: float = grid.get_height(cell) if grid.has_method("get_height") else 0.0
			var y_pos: float = h + origin.y + y_elevation_offset

			# Coordenadas XZ con inset
			var x0: float = (float(cx) + inset) * c_size + origin.x
			var x1: float = (float(cx + 1) - inset) * c_size + origin.x
			var z0: float = (float(cy) + inset) * c_size + origin.z
			var z1: float = (float(cy + 1) - inset) * c_size + origin.z

			var v0 := Vector3(x0, y_pos, z0)
			var v1 := Vector3(x1, y_pos, z0)
			var v2 := Vector3(x1, y_pos, z1)
			var v3 := Vector3(x0, y_pos, z1)

			# Triángulo 1 (v0, v1, v2)
			st.set_color(color)
			st.add_vertex(v0)
			st.set_color(color)
			st.add_vertex(v1)
			st.set_color(color)
			st.add_vertex(v2)

			# Triángulo 2 (v0, v2, v3)
			st.set_color(color)
			st.add_vertex(v0)
			st.set_color(color)
			st.add_vertex(v2)
			st.set_color(color)
			st.add_vertex(v3)

	_mesh_instance.mesh = st.commit()

func _get_active_profile() -> MovementProfile:
	if tracked_target != null and is_instance_valid(tracked_target):
		if "movement_component" in tracked_target and tracked_target.movement_component != null:
			if tracked_target.movement_component.profile != null:
				return tracked_target.movement_component.profile
	return null

## Evalúa si una celda transitable tiene vecinos con desniveles válidos para saltar hacia abajo o subir.
func _evaluate_jumpable_edges(cell: Vector2i, p_profile: MovementProfile) -> Dictionary:
	var res := {"can_jump_down": false, "can_jump_up": false}
	if grid == null or not grid.has_method("get_elevation_level"):
		return res

	var cur_level: int = grid.get_elevation_level(cell)
	var max_up: int = p_profile.max_step_up if p_profile != null else 1
	var max_down: int = p_profile.max_step_down if p_profile != null else 1
	var can_drop: bool = p_profile.can_drop if p_profile != null else true
	var max_drop: int = p_profile.max_drop_distance if p_profile != null else 4

	for dir in _NEIGHBOR_DIRS:
		var n_cell := cell + dir

		if grid.has_method("get_cell_availability"):
			if grid.get_cell_availability(n_cell) != 0:
				continue
		elif grid.has_method("has_cell"):
			if not grid.has_cell(n_cell):
				continue

		if grid.has_method("is_walkable") and not grid.is_walkable(n_cell):
			continue

		if grid.has_method("is_water") and grid.is_water(n_cell):
			var water_mode: int = p_profile.water_mode if p_profile != null else _ProfileScript.WaterMode.LAND
			if water_mode == _ProfileScript.WaterMode.LAND:
				continue

		var n_level: int = grid.get_elevation_level(n_cell)
		var delta: int = n_level - cur_level

		# 1. Bajar (STEP_DOWN o salto DROP hacia abajo)
		if delta < 0:
			if delta >= -max_down or (can_drop and absi(delta) <= max_drop):
				res.can_jump_down = true

		# 2. Subir (escalón STEP_UP hacia arriba)
		elif delta > 0:
			if delta <= max_up:
				res.can_jump_up = true

		if res.can_jump_down and res.can_jump_up:
			break

	return res
