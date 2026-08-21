class_name PlayerTest
extends CharacterBody3D

## Personaje de prueba (cápsula 3D) para testing y exploración en la dungeon.
## Controlado exclusivamente con las flechas del teclado (UP, DOWN, LEFT, RIGHT).

@export var speed: float = 7.0
@export var acceleration: float = 25.0
@export var gravity: float = 20.0
@export var capsule_radius: float = 0.35
@export var capsule_height: float = 1.4

var _visual_root: Node3D = null

func _ready() -> void:
	_setup_visuals_and_collision()

func _setup_visuals_and_collision() -> void:
	# 1. CollisionShape3D
	var col_shape = get_node_or_null("CollisionShape3D")
	if col_shape == null:
		col_shape = CollisionShape3D.new()
		col_shape.name = "CollisionShape3D"
		var capsule_shape := CapsuleShape3D.new()
		capsule_shape.radius = capsule_radius
		capsule_shape.height = capsule_height
		col_shape.shape = capsule_shape
		col_shape.position = Vector3(0, capsule_height * 0.5, 0)
		add_child(col_shape)

	# 2. Visuales (Cápsula + Visor indicador de orientación)
	_visual_root = get_node_or_null("Visuals")
	if _visual_root == null:
		_visual_root = Node3D.new()
		_visual_root.name = "Visuals"
		add_child(_visual_root)

		# Cuerpo Cápsula
		var body_mesh_instance := MeshInstance3D.new()
		body_mesh_instance.name = "BodyMesh"
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = capsule_radius
		body_mesh.height = capsule_height
		body_mesh_instance.mesh = body_mesh
		body_mesh_instance.position = Vector3(0, capsule_height * 0.5, 0)

		# Material estilizado (Cyan brillante para alto contraste)
		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.1, 0.75, 0.95, 1.0)
		body_mat.roughness = 0.3
		body_mat.metallic = 0.2
		body_mat.emission_enabled = true
		body_mat.emission = Color(0.05, 0.3, 0.5, 1.0)
		body_mat.emission_energy_multiplier = 0.5
		body_mesh_instance.material_override = body_mat
		_visual_root.add_child(body_mesh_instance)

		# Visor (Frontal -Z)
		var visor_mesh_instance := MeshInstance3D.new()
		visor_mesh_instance.name = "VisorMesh"
		var visor_mesh := BoxMesh.new()
		visor_mesh.size = Vector3(capsule_radius * 1.2, 0.15, capsule_radius * 0.6)
		visor_mesh_instance.mesh = visor_mesh
		visor_mesh_instance.position = Vector3(0, capsule_height * 0.7, -capsule_radius * 0.8)

		var visor_mat := StandardMaterial3D.new()
		visor_mat.albedo_color = Color(0.08, 0.1, 0.15, 1.0)
		visor_mat.emission_enabled = true
		visor_mat.emission = Color(1.0, 0.6, 0.1, 1.0)
		visor_mat.emission_energy_multiplier = 1.8
		visor_mesh_instance.material_override = visor_mat
		_visual_root.add_child(visor_mesh_instance)

func _physics_process(delta: float) -> void:
	if not is_visible_in_tree():
		velocity = Vector3.ZERO
		return

	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	var vp = get_viewport()

	# No mover si el foco está en un LineEdit/TextEdit de la UI
	if vp != null:
		var focus_owner = vp.gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is TextEdit:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
			move_and_slide()
			return

	# Obtener orientación de la cámara activa
	var forward := Vector3(0, 0, -1)
	var right := Vector3(1, 0, 0)

	if vp != null:
		var cam: Camera3D = vp.get_camera_3d()
		if cam != null:
			var cam_basis = cam.global_transform.basis
			forward = -cam_basis.z
			forward.y = 0.0
			forward = forward.normalized()
			right = cam_basis.x
			right.y = 0.0
			right = right.normalized()

	# Input exclusivo con flechas del teclado
	var move_intent := Vector3.ZERO
	if Input.is_key_pressed(KEY_UP):
		move_intent += forward
	if Input.is_key_pressed(KEY_DOWN):
		move_intent -= forward
	if Input.is_key_pressed(KEY_LEFT):
		move_intent -= right
	if Input.is_key_pressed(KEY_RIGHT):
		move_intent += right

	if move_intent != Vector3.ZERO:
		move_intent = move_intent.normalized()
		velocity.x = move_toward(velocity.x, move_intent.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_intent.z * speed, acceleration * delta)

		# Rotación suave hacia la dirección de movimiento
		var target_angle: float = atan2(-move_intent.x, -move_intent.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 14.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

	if is_inside_tree():
		move_and_slide()
