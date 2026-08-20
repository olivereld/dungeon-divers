class_name DungeonDoorEntity
extends Node3D

## Entidad física e interactiva de puerta para mazmorras (Fase 9).
## Soporta:
## 1. Apertura y cierre interactivo con rotación suave alrededor del pivote de bisagra (Hinge).
## 2. Bloqueo semántico (LockData / Keys).
## 3. Sistema de daño y destrucción (Destructible Door).

signal door_opened
signal door_closed
signal door_damaged(current_health: float, max_health: float)
signal door_destroyed

@export_group("Estado de Puerta")
@export var is_open: bool = false
@export var is_locked: bool = false
@export var key_id_required: String = ""

@export_group("Comportamiento Físico")
@export var open_angle_degrees: float = 90.0
@export var animation_duration: float = 0.45

@export_group("Salud y Destrucción")
@export var max_health: float = 100.0
@export var is_destructible: bool = true

var current_health: float = 100.0
var _is_destroyed: bool = false
var _tween: Tween = null

@onready var hinge_pivot: Node3D = $HingePivot
@onready var door_mesh: MeshInstance3D = $HingePivot/DoorMesh
@onready var static_body: StaticBody3D = $HingePivot/StaticBody3D
@onready var collision_shape: CollisionShape3D = $HingePivot/StaticBody3D/CollisionShape3D

func _ready() -> void:
	current_health = max_health
	if is_open:
		open(true)

const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

func setup_procedural_door(
	mesh: ArrayMesh,
	width: float = 1.04,
	height: float = 2.40,
	thickness: float = 0.12
) -> void:
	if hinge_pivot == null:
		hinge_pivot = Node3D.new()
		hinge_pivot.name = "HingePivot"
		# Situar la bisagra en el marco lateral izquierdo
		hinge_pivot.position = Vector3(-width * 0.5, 0.0, 0.0)
		add_child(hinge_pivot)

	if door_mesh == null:
		door_mesh = MeshInstance3D.new()
		door_mesh.name = "DoorMesh"
		door_mesh.mesh = mesh
		_WallMaterialFactoryScript.apply_materials_to_mesh_instance(door_mesh)
		# Desplazar la malla para que pivote alrededor del borde izquierdo
		door_mesh.position = Vector3(width * 0.5, 0.0, 0.0)
		hinge_pivot.add_child(door_mesh)

	if static_body == null:
		static_body = StaticBody3D.new()
		static_body.name = "StaticBody3D"
		hinge_pivot.add_child(static_body)

		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(width, height, thickness)
		collision_shape.shape = box
		collision_shape.position = Vector3(width * 0.5, height * 0.5, 0.0)
		static_body.add_child(collision_shape)

## Interacción básica (abrir/cerrar al interactuar el jugador o la IA).
func interact() -> bool:
	if _is_destroyed or is_locked:
		return false
	toggle()
	return true

## Alterna entre abierto y cerrado.
func toggle() -> void:
	if is_open:
		close()
	else:
		open()

## Abre la puerta rotando suavemente la bisagra.
func open(instant: bool = false) -> void:
	if _is_destroyed:
		return
	is_open = true

	var target_rot_y: float = deg_to_rad(open_angle_degrees)
	if instant:
		if hinge_pivot != null:
			hinge_pivot.rotation.y = target_rot_y
		door_opened.emit()
	else:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(hinge_pivot, "rotation:y", target_rot_y, animation_duration)
		_tween.tween_callback(func(): door_opened.emit())

## Cierra la puerta rotando la bisagra a 0°.
func close(instant: bool = false) -> void:
	if _is_destroyed:
		return
	is_open = false

	if instant:
		if hinge_pivot != null:
			hinge_pivot.rotation.y = 0.0
		door_closed.emit()
	else:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(hinge_pivot, "rotation:y", 0.0, animation_duration)
		_tween.tween_callback(func(): door_closed.emit())

## Aplica daño a la puerta (destructibilidad).
func take_damage(amount: float) -> void:
	if not is_destructible or _is_destroyed:
		return

	current_health = maxf(0.0, current_health - amount)
	door_damaged.emit(current_health, max_health)

	if current_health <= 0.0:
		destroy()

## Destruye la puerta (desactiva colisión y oculta/destruye la hoja).
func destroy() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	is_open = true

	if collision_shape != null:
		collision_shape.disabled = true

	if _tween != null and _tween.is_valid():
		_tween.kill()

	# Efecto de caída / desvanecimiento
	if hinge_pivot != null:
		_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_property(hinge_pivot, "position:y", -0.4, 0.3)
		_tween.parallel().tween_property(hinge_pivot, "rotation:x", deg_to_rad(85.0), 0.3)
		_tween.tween_callback(func():
			if door_mesh != null:
				door_mesh.visible = false
			door_destroyed.emit()
		)
	else:
		door_destroyed.emit()

func is_destroyed() -> bool:
	return _is_destroyed
