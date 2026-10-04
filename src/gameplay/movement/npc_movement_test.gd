class_name NPCTest
extends CharacterBody3D

## NPC mínimo de prueba que utiliza exactamente la misma arquitectura de movimiento por celdas:
## MovementComponent, MovementGrid, MovementRules y MovementOccupancy.
## No implementa pathfinding ni navegación avanzada; únicamente genera MovementRequest.

const _MovementComponentScript = preload("res://src/gameplay/movement/movement_component.gd")
const _MovementRequestScript = preload("res://src/gameplay/movement/movement_request.gd")
const _MovementProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")
const _MovementGridScript = preload("res://src/gameplay/movement/movement_grid.gd")
const _MovementOccupancyScript = preload("res://src/gameplay/movement/movement_occupancy.gd")

@export var cells_per_second: float = 3.0
@export var auto_patrol: bool = false
@export var patrol_interval: float = 1.2
@export var patrol_directions: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1)
]

var movement_component: MovementComponent = null
var _visual_mesh: MeshInstance3D = null
var _patrol_timer: float = 0.0
var _patrol_index: int = 0

func _ready() -> void:
	_setup_visuals()
	_setup_movement_component()

func _setup_visuals() -> void:
	if _visual_mesh != null:
		return
	_visual_mesh = MeshInstance3D.new()
	_visual_mesh.name = "NPCMesh"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	_visual_mesh.mesh = capsule
	_visual_mesh.position = Vector3(0, 0.8, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.45, 0.15, 1.0) # Naranja distintivo para el NPC
	mat.roughness = 0.4
	_visual_mesh.material_override = mat
	add_child(_visual_mesh)

func _setup_movement_component() -> void:
	movement_component = get_node_or_null("MovementComponent")
	if movement_component == null:
		movement_component = _MovementComponentScript.new()
		movement_component.name = "MovementComponent"
		add_child(movement_component)
	movement_component.target_actor = self
	movement_component.y_offset = 0.0
	if movement_component.profile == null:
		movement_component.profile = _MovementProfileScript.new()
	movement_component.profile.cells_per_second = cells_per_second
	movement_component.profile.turn_speed = 12.0

func setup_movement(
	p_grid: MovementGrid,
	p_occupancy: MovementOccupancy = null,
	p_initial_cell: Vector2i = Vector2i.ZERO
) -> void:
	if movement_component == null:
		_setup_movement_component()
	movement_component.setup(p_grid, p_occupancy, null, p_initial_cell, 0.0)

func teleport_to_cell(cell: Vector2i) -> void:
	if movement_component != null:
		movement_component.teleport_to_cell(cell)

func step(direction: Vector2i) -> MovementResult:
	if movement_component == null:
		return null
	var req := _MovementRequestScript.new(direction, &"npc")
	return movement_component.request_movement(req)

func _physics_process(delta: float) -> void:
	if not auto_patrol or movement_component == null or movement_component.grid == null:
		return

	if movement_component.is_moving:
		return

	_patrol_timer += delta
	if _patrol_timer >= patrol_interval:
		_patrol_timer = 0.0
		if not patrol_directions.is_empty():
			var dir := patrol_directions[_patrol_index % patrol_directions.size()]
			var res := step(dir)
			if res != null and res.accepted:
				_patrol_index += 1
			else:
				# Si la celda está bloqueada u ocupada, intenta la siguiente dirección en la lista
				_patrol_index += 1
