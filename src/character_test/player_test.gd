class_name PlayerTest
extends CharacterBody3D

## Personaje de prueba 3D para testing y exploración en la dungeon y mundos procedurales.
## Incorpora el modelo rigged 3D Aldeano, animación esqueletal BlendSpace1D
## y aceleración natural para transiciones fluidas de Idle -> Caminar -> Trotar -> Correr.

# --- Constantes de Assets ---
const MODEL_PATH = "res://assets/models/character/Test/Aldeano_rigged_v1.glb"
const MODEL_SCALE = Vector3(175.0, 175.0, 175.0)
const MODEL_ROTATION_Y = PI # 180° para alinear la orientación frontal (+Z del modelo a -Z de Godot)
const MODEL_Y_OFFSET = 0.58 # Compensa la altura para que las suelas de los pies toquen Y=0 exactamente

const ANIM_SOURCES: Dictionary = {
	"idle": "res://assets/animations/human/human_01_Idle.fbx",
	"walk": "res://assets/animations/human/human_01_walk.fbx",
	"trot": "res://assets/animations/human/human_01_slow_run.fbx",
	"run": "res://assets/animations/human/human_01_fast_run.fbx",
	"stop": "res://assets/animations/human/human_01_run_stop.fbx",
}

const _MovementComponentScript = preload("res://src/gameplay/movement/movement_component.gd")
const _MovementRequestScript = preload("res://src/gameplay/movement/movement_request.gd")
const _MovementProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")
const _MovementGridScript = preload("res://src/gameplay/movement/movement_grid.gd")
const _MovementOccupancyScript = preload("res://src/gameplay/movement/movement_occupancy.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")

# Caché estática compartida de la biblioteca de animaciones para evitar reimportaciones y retargeting redundantes
static var _cached_anim_library: AnimationLibrary = null

# --- Parámetros de Movimiento por Celdas ---
@export_group("Cell Movement")
@export var walk_cells_per_second: float = 2.5
@export var normal_cells_per_second: float = 4.2
@export var sprint_cells_per_second: float = 7.0
@export var turn_speed: float = 14.0

# Aliases para configuración del AnimationTree y compatibilidad
@export_group("Animation Speeds")
@export var walk_speed: float = 2.5
@export var trot_speed: float = 4.2
@export var run_speed: float = 7.0
@export var speed: float = 7.0

@export_group("Collision")
@export var capsule_radius: float = 0.38
@export var capsule_height: float = 1.75

# --- Componente de Movimiento y Nodos Internos ---
const DIRECTIONS_8: Array[Vector2i] = [
	Vector2i(1, 0),   # 0: Este (+X)
	Vector2i(1, 1),   # 1: Sureste (+X, +Z)
	Vector2i(0, 1),   # 2: Sur (+Z)
	Vector2i(-1, 1),  # 3: Suroeste (-X, +Z)
	Vector2i(-1, 0),  # 4: Oeste (-X)
	Vector2i(-1, -1), # 5: Noroeste (-X, -Z)
	Vector2i(0, -1),  # 6: Norte (-Z)
	Vector2i(1, -1),  # 7: Noreste (+X, -Z)
]

var movement_component: MovementComponent = null
var _last_8way_index: int = -1 # -1=sin input previo
var _last_frame_position: Vector3 = Vector3.ZERO

var _visual_root: Node3D = null
var _character_model: Node3D = null
var _anim_player: AnimationPlayer = null
var _anim_tree: AnimationTree = null
var _anim_playback: AnimationNodeStateMachinePlayback = null

func _ready() -> void:
	_setup_visuals_and_collision()
	_setup_movement_component()

func _setup_visuals_and_collision() -> void:
	# 1. CollisionShape3D (Cápsula de colisión física para el CharacterBody3D)
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

	# 2. Contenedor visual
	_visual_root = get_node_or_null("Visuals")
	if _visual_root == null:
		_visual_root = Node3D.new()
		_visual_root.name = "Visuals"
		add_child(_visual_root)

	# 3. Carga e instanciación del modelo 3D Aldeano
	_character_model = _visual_root.get_node_or_null("CharacterModel")
	if _character_model == null:
		var model_scene: PackedScene = load(MODEL_PATH)
		if model_scene != null:
			_character_model = model_scene.instantiate()
			_character_model.name = "CharacterModel"
			_character_model.scale = MODEL_SCALE
			_character_model.rotation.y = MODEL_ROTATION_Y
			_character_model.position = Vector3(0, MODEL_Y_OFFSET, 0)

			# Neutralizar la rotación inicial del nodo Armature en el GLB (que venía en 90° de Blender)
			# para que las animaciones esqueletales FBX se reproduzcan de pie y no acostadas
			var arm = _character_model.get_node_or_null("Armature")
			if arm != null:
				arm.rotation = Vector3.ZERO

			_visual_root.add_child(_character_model)
			_setup_animations_and_tree(_character_model)
		else:
			# Fallback a cápsula estilizada si el archivo 3D no estuviera disponible
			_setup_fallback_capsule()

## Configura la biblioteca de animaciones retargeteadas y el AnimationTree con StateMachine y BlendSpace1D
func _setup_animations_and_tree(model: Node3D) -> void:
	_anim_player = model.get_node_or_null("AnimationPlayer")
	if _anim_player == null:
		return

	# Obtener o construir la biblioteca retargeteada en caché
	var lib := _get_or_create_anim_library()
	if _anim_player.has_animation_library(""):
		var existing_lib = _anim_player.get_animation_library("")
		for anim_name in lib.get_animation_list():
			if not existing_lib.has_animation(anim_name):
				existing_lib.add_animation(anim_name, lib.get_animation(anim_name))
	else:
		_anim_player.add_animation_library("", lib)

	# Construir la StateMachine de Animación
	var state_machine := AnimationNodeStateMachine.new()

	# Estado Idle
	var idle_node := AnimationNodeAnimation.new()
	idle_node.animation = &"idle"
	state_machine.add_node("Idle", idle_node)

	# Estado Locomotion: BlendSpace1D entre Caminar (Walk), Trotar (Trot) y Correr (Run)
	var blend_space := AnimationNodeBlendSpace1D.new()
	blend_space.min_space = 0.0
	blend_space.max_space = maxf(run_speed, speed)

	var walk_node_zero := AnimationNodeAnimation.new()
	walk_node_zero.animation = &"walk"
	blend_space.add_blend_point(walk_node_zero, 0.0)

	var walk_node := AnimationNodeAnimation.new()
	walk_node.animation = &"walk"
	blend_space.add_blend_point(walk_node, walk_speed)

	var trot_node := AnimationNodeAnimation.new()
	trot_node.animation = &"trot"
	blend_space.add_blend_point(trot_node, trot_speed)

	var run_node := AnimationNodeAnimation.new()
	run_node.animation = &"run"
	blend_space.add_blend_point(run_node, maxf(run_speed, speed))

	state_machine.add_node("Locomotion", blend_space)

	# Transiciones suaves (crossfade)
	var trans_idle_to_loco := AnimationNodeStateMachineTransition.new()
	trans_idle_to_loco.xfade_time = 0.2
	state_machine.add_transition("Idle", "Locomotion", trans_idle_to_loco)

	var trans_loco_to_idle := AnimationNodeStateMachineTransition.new()
	trans_loco_to_idle.xfade_time = 0.25
	state_machine.add_transition("Locomotion", "Idle", trans_loco_to_idle)

	var trans_start := AnimationNodeStateMachineTransition.new()
	state_machine.add_transition("Start", "Idle", trans_start)

	# Instanciar y conectar AnimationTree
	_anim_tree = model.get_node_or_null("AnimationTree")
	if _anim_tree == null:
		_anim_tree = AnimationTree.new()
		_anim_tree.name = "AnimationTree"
		model.add_child(_anim_tree)

	_anim_tree.tree_root = state_machine
	_anim_tree.anim_player = NodePath("../AnimationPlayer")
	_anim_tree.active = true

	_anim_playback = _anim_tree.get("parameters/playback")
	if _anim_playback != null:
		_anim_playback.start("Idle")

## Retargetea y empaqueta las animaciones FBX para que coincidan con la estructura esqueletal de Aldeano
static func _get_or_create_anim_library() -> AnimationLibrary:
	if _cached_anim_library != null:
		return _cached_anim_library

	_cached_anim_library = AnimationLibrary.new()

	for anim_name in ANIM_SOURCES:
		var p: String = ANIM_SOURCES[anim_name]
		var scn: PackedScene = load(p)
		if scn == null:
			continue
		var inst = scn.instantiate()
		var src_ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		if src_ap != null and src_ap.has_animation("mixamo_com"):
			var anim: Animation = src_ap.get_animation("mixamo_com").duplicate()
			if anim_name == "stop":
				anim.loop_mode = Animation.LOOP_NONE
			else:
				anim.loop_mode = Animation.LOOP_LINEAR

			# Retargetear pistas: "Skeleton3D:" -> "Armature/Skeleton3D:"
			for t in range(anim.get_track_count()):
				var track_path = String(anim.track_get_path(t))
				if track_path.begins_with("Skeleton3D:"):
					var bone_name = track_path.substr("Skeleton3D:".length())
					anim.track_set_path(t, NodePath("Armature/Skeleton3D:" + bone_name))

			_cached_anim_library.add_animation(anim_name, anim)
		inst.free()

	return _cached_anim_library

## Fallback visual en caso de ausencia de los assets 3D
func _setup_fallback_capsule() -> void:
	var body_mesh_instance := MeshInstance3D.new()
	body_mesh_instance.name = "BodyMesh"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = capsule_radius
	body_mesh.height = capsule_height
	body_mesh_instance.mesh = body_mesh
	body_mesh_instance.position = Vector3(0, capsule_height * 0.5, 0)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.1, 0.75, 0.95, 1.0)
	body_mesh_instance.material_override = body_mat
	_visual_root.add_child(body_mesh_instance)

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
	movement_component.profile.cells_per_second = normal_cells_per_second
	movement_component.profile.turn_speed = turn_speed
	if not movement_component.movement_started.is_connected(_on_movement_started):
		movement_component.movement_started.connect(_on_movement_started)
	if not movement_component.movement_finished.is_connected(_on_movement_finished):
		movement_component.movement_finished.connect(_on_movement_finished)
	_last_frame_position = global_position if is_inside_tree() else position

## Configura el componente de movimiento con el MovementGrid y MovementOccupancy del mundo activo.
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

func get_current_cell() -> Vector2i:
	return movement_component.current_cell if movement_component != null else Vector2i.ZERO

func get_target_cell() -> Vector2i:
	return movement_component.target_cell if movement_component != null else Vector2i.ZERO

func is_moving() -> bool:
	return movement_component.is_moving if movement_component != null else false

func _ensure_grid_exists() -> void:
	if movement_component != null and movement_component.grid == null:
		var fallback_grid: MovementGrid = _MovementGridScript.new(1.0, Vector3.ZERO)
		var center_cell := fallback_grid.world_to_cell(global_position)
		var dummy_cells := {}
		for cy in range(center_cell.y - 40, center_cell.y + 41):
			for cx in range(center_cell.x - 40, center_cell.x + 41):
				var c = _WorldCellScript.new(Vector2i(cx, cy))
				c.height = global_position.y
				c.elevation_level = 0
				c.is_walkable = true
				dummy_cells[Vector2i(cx, cy)] = c
		fallback_grid.setup_from_cells(dummy_cells)
		movement_component.setup(fallback_grid, null, null, center_cell, 0.0)

func _physics_process(delta: float) -> void:
	if not is_visible_in_tree():
		velocity = Vector3.ZERO
		return

	_ensure_grid_exists()

	# 1. Ignorar input si el foco está en un campo de texto de UI
	var vp = get_viewport()
	if vp != null:
		var focus_owner = vp.gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is TextEdit:
			_update_animation_state()
			return

	# 2. Orientación de cámara activa
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

	# 3. Captura de Input (WASD y Teclas de Flecha)
	var raw_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		raw_input.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		raw_input.y += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		raw_input.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		raw_input.x += 1.0

	# 4. Proyección a plano XZ y cuantización 8-way con histéresis angular
	if raw_input != Vector2.ZERO:
		var move_intent_3d: Vector3 = (right * raw_input.x) + (forward * -raw_input.y)
		var v := Vector2(move_intent_3d.x, move_intent_3d.z)

		if v.length() >= 0.2:
			var angle: float = atan2(v.y, v.x) # Rango [-PI, PI]
			var chosen_octant: int = -1

			# Histéresis angular: si ya había una dirección activa, aplicar zona de adherencia (+/- 8°)
			# evitando alternancias indeseadas entre diagonal y cardinal al mantener el input
			if _last_8way_index >= 0 and _last_8way_index < 8:
				var current_center_angle: float = wrapf(float(_last_8way_index) * (PI / 4.0), -PI, PI)
				var angle_diff: float = absf(wrapf(angle - current_center_angle, -PI, PI))
				var sticky_threshold: float = (PI / 8.0) + deg_to_rad(8.0) # ~30.5°
				if angle_diff <= sticky_threshold:
					chosen_octant = _last_8way_index

			if chosen_octant == -1:
				chosen_octant = posmod(int(round(angle / (PI / 4.0))), 8)
				_last_8way_index = chosen_octant

			var grid_dir: Vector2i = DIRECTIONS_8[chosen_octant]

			# 5. Modificadores de velocidad (Sprint / Caminata forzada)
			var is_sprinting: bool = Input.is_key_pressed(KEY_SHIFT)
			var is_walking_forced: bool = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT)

			var cps: float = normal_cells_per_second
			if is_walking_forced:
				cps = walk_cells_per_second
			elif is_sprinting:
				cps = sprint_cells_per_second

			if movement_component != null and movement_component.profile != null:
				movement_component.profile.cells_per_second = cps

			# 6. Envío de MovementRequest de 8 direcciones
			if movement_component != null:
				var req := _MovementRequestScript.new(grid_dir, &"player")
				movement_component.request_movement(req)
	else:
		_last_8way_index = -1

	# 7. Velocidad aparente para shaders/efectos de agua (no gobierna la física)
	if delta > 0.0 and movement_component != null and movement_component.is_moving:
		velocity = (global_position - _last_frame_position) / delta
	else:
		velocity = Vector3.ZERO
	_last_frame_position = global_position

	# 8. Actualización de animaciones según estado de movimiento
	_update_animation_state()

func _on_movement_started(_from: Vector2i, _to: Vector2i) -> void:
	if _anim_playback != null:
		_anim_playback.travel("Locomotion")

func _on_movement_finished(_from: Vector2i, _to: Vector2i) -> void:
	if movement_component != null and not movement_component.is_moving:
		if _anim_playback != null:
			_anim_playback.travel("Idle")

## Actualiza el AnimationTree sincronizando Idle y Locomotion según el estado del MovementComponent
func _update_animation_state() -> void:
	if _anim_tree == null or _anim_playback == null or movement_component == null:
		return

	if movement_component.is_moving:
		_anim_playback.travel("Locomotion")
		var blend_pos: float = movement_component.profile.cells_per_second if movement_component.profile != null else normal_cells_per_second
		_anim_tree.set("parameters/Locomotion/blend_position", blend_pos)
	else:
		_anim_playback.travel("Idle")

