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

# Caché estática compartida de la biblioteca de animaciones para evitar reimportaciones y retargeting redundantes
static var _cached_anim_library: AnimationLibrary = null

# --- Parámetros de Movimiento y Aceleración ---
@export_group("Movement Speeds")
@export var walk_speed: float = 2.0
@export var trot_speed: float = 4.2
@export var run_speed: float = 7.0
@export var speed: float = 7.0 # Alias retrocompatible para velocidad máxima

@export_group("Acceleration & Physics")
## Tasa de aceleración estándar que permite pasar naturalmente de caminar a trotar a correr
@export var acceleration: float = 7.5
## Aceleración rápida al usar la tecla de Sprint (Shift)
@export var sprint_acceleration: float = 14.0
## Fricción / desaceleración al soltar los controles
@export var friction: float = 14.0
## Velocidad de rotación suave hacia la dirección de movimiento
@export var turn_speed: float = 14.0
@export var gravity: float = 20.0
@export var jump_velocity: float = 7.5

@export_group("Collision")
@export var capsule_radius: float = 0.38
@export var capsule_height: float = 1.75

# --- Nodos Internos ---
var _visual_root: Node3D = null
var _character_model: Node3D = null
var _anim_player: AnimationPlayer = null
var _anim_tree: AnimationTree = null
var _anim_playback: AnimationNodeStateMachinePlayback = null

func _ready() -> void:
	_setup_visuals_and_collision()

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

func _physics_process(delta: float) -> void:
	if not is_visible_in_tree():
		velocity = Vector3.ZERO
		return

	# 1. Gravedad y Salto
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = jump_velocity

	# 2. Ignorar input si el foco está en un campo de texto de UI
	var vp = get_viewport()
	if vp != null:
		var focus_owner = vp.gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is TextEdit:
			_apply_deceleration(delta)
			_update_animation_state(delta)
			move_and_slide()
			return

	# 3. Orientación relativa a la cámara activa
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

	# 4. Captura de Input (WASD y Teclas de Flecha)
	var move_intent := Vector3.ZERO
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		move_intent += forward
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		move_intent -= forward
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		move_intent -= right
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		move_intent += right

	# 5. Modificadores de velocidad (Shift = Sprint inmediato, Ctrl/Alt = Caminata forzada)
	var is_sprinting: bool = Input.is_key_pressed(KEY_SHIFT)
	var is_walking_forced: bool = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT)

	var target_speed: float = maxf(run_speed, speed)
	var current_accel: float = acceleration

	if is_walking_forced:
		target_speed = walk_speed
		current_accel = acceleration * 1.5
	elif is_sprinting:
		target_speed = maxf(run_speed, speed)
		current_accel = sprint_acceleration
	else:
		# Aceleración progresiva natural: al mantener presionado, gana impulso pasando por trote y carrera
		target_speed = maxf(run_speed, speed)
		current_accel = acceleration

	# 6. Aplicación de aceleración o deceleración
	if move_intent != Vector3.ZERO:
		move_intent = move_intent.normalized()
		velocity.x = move_toward(velocity.x, move_intent.x * target_speed, current_accel * delta)
		velocity.z = move_toward(velocity.z, move_intent.z * target_speed, current_accel * delta)

		# Rotación suave hacia la dirección de movimiento
		var target_angle: float = atan2(-move_intent.x, -move_intent.z)
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)
	else:
		_apply_deceleration(delta)

	# 7. Actualización del sistema de animaciones
	_update_animation_state(delta)

	# 8. Movimiento físico
	if is_inside_tree():
		move_and_slide()

func _apply_deceleration(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	velocity.z = move_toward(velocity.z, 0.0, friction * delta)

## Actualiza el AnimationTree sincronizando Idle, Caminar, Trotar y Correr según la velocidad real
func _update_animation_state(_delta: float) -> void:
	if _anim_tree == null or _anim_playback == null:
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()

	if horizontal_speed < 0.15:
		_anim_playback.travel("Idle")
	else:
		_anim_playback.travel("Locomotion")
		_anim_tree.set("parameters/Locomotion/blend_position", horizontal_speed)
