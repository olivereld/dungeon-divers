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
	"jump_down_takeoff": "res://assets/animations/human/human_01_jump_down_takeoff.res",
	"jump_down_start": "res://assets/animations/human/human_01_jump_down_takeoff.res",
	"jump_down_air": "res://assets/animations/human/human_01_jump_down_air.res",
	"jump_down_fall": "res://assets/animations/human/human_01_jump_down_air.res",
	"jump_down_land": "res://assets/animations/human/human_01_jump_down_land.res",
	"stand_up": "res://assets/animations/human/human_01_stand_up.res",
}

const _MovementComponentScript = preload("res://src/gameplay/movement/movement_component.gd")
const _MovementRequestScript = preload("res://src/gameplay/movement/movement_request.gd")
const _MovementProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")
const _MovementResultScript = preload("res://src/gameplay/movement/movement_result.gd")
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
var _move_initiating_octant: int = -1 # Octante que inició el paso activo
var _space_was_down: bool = false
var _is_dropping: bool = false
var _is_landing: bool = false
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

	# Estados de Salto hacia abajo (Jump Down)
	var takeoff_node := AnimationNodeAnimation.new()
	takeoff_node.animation = &"jump_down_takeoff"
	state_machine.add_node("Takeoff", takeoff_node)

	var air_tree := AnimationNodeBlendTree.new()
	var air_anim := AnimationNodeAnimation.new()
	air_anim.animation = &"jump_down_air"
	var air_scale := AnimationNodeTimeScale.new()
	air_tree.add_node("Anim", air_anim)
	air_tree.add_node("TimeScale", air_scale)
	air_tree.connect_node("TimeScale", 0, "Anim")
	air_tree.connect_node("output", 0, "TimeScale")
	state_machine.add_node("Air", air_tree)

	var land_node := AnimationNodeAnimation.new()
	land_node.animation = &"jump_down_land"
	state_machine.add_node("Land", land_node)

	var stand_tree := AnimationNodeBlendTree.new()
	var stand_anim := AnimationNodeAnimation.new()
	stand_anim.animation = &"stand_up"
	var stand_scale := AnimationNodeTimeScale.new()
	stand_tree.add_node("Anim", stand_anim)
	stand_tree.add_node("TimeScale", stand_scale)
	stand_tree.connect_node("TimeScale", 0, "Anim")
	stand_tree.connect_node("output", 0, "TimeScale")
	state_machine.add_node("StandUp", stand_tree)

	# Transiciones suaves (crossfade)
	var trans_idle_to_loco := AnimationNodeStateMachineTransition.new()
	trans_idle_to_loco.xfade_time = 0.2
	state_machine.add_transition("Idle", "Locomotion", trans_idle_to_loco)

	var trans_loco_to_idle := AnimationNodeStateMachineTransition.new()
	trans_loco_to_idle.xfade_time = 0.25
	state_machine.add_transition("Locomotion", "Idle", trans_loco_to_idle)

	var trans_start := AnimationNodeStateMachineTransition.new()
	state_machine.add_transition("Start", "Idle", trans_start)

	# Anticipación y despegue en el borde (0.15s crossfade)
	var trans_to_takeoff := AnimationNodeStateMachineTransition.new()
	trans_to_takeoff.xfade_time = 0.15
	state_machine.add_transition("Idle", "Takeoff", trans_to_takeoff)
	state_machine.add_transition("Locomotion", "Takeoff", trans_to_takeoff)

	# Despegue hacia Vuelo en el aire: cambio inmediato al despegar (o auto al terminar)
	var trans_takeoff_to_air := AnimationNodeStateMachineTransition.new()
	trans_takeoff_to_air.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	trans_takeoff_to_air.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	trans_takeoff_to_air.xfade_time = 0.05
	state_machine.add_transition("Takeoff", "Air", trans_takeoff_to_air)

	# Vuelo hacia Aterrizaje al impactar con el suelo
	var trans_air_to_land := AnimationNodeStateMachineTransition.new()
	trans_air_to_land.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	trans_air_to_land.xfade_time = 0.06
	state_machine.add_transition("Air", "Land", trans_air_to_land)
	state_machine.add_transition("Takeoff", "Land", trans_air_to_land)

	# Aterrizaje hacia Levantarse (StandUp): AUTO al terminar la absorción de impacto (0.37s)
	var trans_land_to_stand := AnimationNodeStateMachineTransition.new()
	trans_land_to_stand.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	trans_land_to_stand.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	trans_land_to_stand.xfade_time = 0.20
	state_machine.add_transition("Land", "StandUp", trans_land_to_stand)

	# Levantarse hacia Idle: AUTO al completar la incorporación erguida
	var trans_stand_to_idle := AnimationNodeStateMachineTransition.new()
	trans_stand_to_idle.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	trans_stand_to_idle.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	trans_stand_to_idle.xfade_time = 0.35
	state_machine.add_transition("StandUp", "Idle", trans_stand_to_idle)

	# Cancelación fluida a Locomotion si el jugador presiona WASD
	var trans_land_to_loco := AnimationNodeStateMachineTransition.new()
	trans_land_to_loco.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	trans_land_to_loco.xfade_time = 0.15
	state_machine.add_transition("Land", "Locomotion", trans_land_to_loco)

	var trans_stand_to_loco := AnimationNodeStateMachineTransition.new()
	trans_stand_to_loco.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	trans_stand_to_loco.xfade_time = 0.15
	state_machine.add_transition("StandUp", "Locomotion", trans_stand_to_loco)

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
	_anim_tree.set("parameters/StandUp/TimeScale/scale", 1.35)
	_anim_tree.set("parameters/Air/TimeScale/scale", 1.0)

## Retargetea y empaqueta las animaciones FBX para que coincidan con la estructura esqueletal de Aldeano
static func _get_or_create_anim_library() -> AnimationLibrary:
	if _cached_anim_library != null:
		return _cached_anim_library

	_cached_anim_library = AnimationLibrary.new()

	for anim_name in ANIM_SOURCES:
		var p: String = ANIM_SOURCES[anim_name]
		if p.ends_with(".res"):
			var anim_res: Animation = load(p)
			if anim_res != null:
				_cached_anim_library.add_animation(anim_name, anim_res)
			continue

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
	movement_component.profile.can_drop = true
	movement_component.profile.max_drop_distance = 4
	movement_component.profile.drop_arc_height = 0.35
	movement_component.profile.drop_windup_time = 0.35
	movement_component.profile.drop_flight_time = 0.48
	movement_component.profile.drop_speed_multiplier = 1.0
	movement_component.profile.jump_up_speed_multiplier = 0.85
	movement_component.profile.require_jump_for_elevation = true
	if not movement_component.movement_started.is_connected(_on_movement_started):
		movement_component.movement_started.connect(_on_movement_started)
	if not movement_component.movement_finished.is_connected(_on_movement_finished):
		movement_component.movement_finished.connect(_on_movement_finished)
	if not movement_component.drop_started.is_connected(_on_drop_started):
		movement_component.drop_started.connect(_on_drop_started)
	if not movement_component.drop_takeoff.is_connected(_on_drop_takeoff):
		movement_component.drop_takeoff.connect(_on_drop_takeoff)
	if not movement_component.drop_finished.is_connected(_on_drop_finished):
		movement_component.drop_finished.connect(_on_drop_finished)
	if not movement_component.jump_up_started.is_connected(_on_jump_up_started):
		movement_component.jump_up_started.connect(_on_jump_up_started)
	if not movement_component.jump_up_finished.is_connected(_on_jump_up_finished):
		movement_component.jump_up_finished.connect(_on_jump_up_finished)
	_last_frame_position = global_position if is_inside_tree() else position

## Configura el componente de movimiento con la autoridad de navegación (WorldNavigationGrid o MovementGrid).
func setup_movement(
	p_grid: Object,
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

func _find_world_navigation_grid() -> Object:
	# 1. Buscar en la jerarquía de ancestros (padre, abuelo, etc.)
	var p: Node = get_parent()
	while p != null:
		if "navigation_grid" in p and p.navigation_grid != null:
			return p.navigation_grid
		if "chunk_world" in p and p.chunk_world != null and "navigation_grid" in p.chunk_world and p.chunk_world.navigation_grid != null:
			return p.chunk_world.navigation_grid
		if p.has_node("ChunkWorld"):
			var cw = p.get_node("ChunkWorld")
			if "navigation_grid" in cw and cw.navigation_grid != null:
				return cw.navigation_grid
		p = p.get_parent()

	# 2. Buscar en la raíz de la escena actual
	if is_inside_tree() and get_tree() != null:
		var scene_root: Node = get_tree().current_scene
		if scene_root != null:
			if "navigation_grid" in scene_root and scene_root.navigation_grid != null:
				return scene_root.navigation_grid
			if "chunk_world" in scene_root and scene_root.chunk_world != null and "navigation_grid" in scene_root.chunk_world and scene_root.chunk_world.navigation_grid != null:
				return scene_root.chunk_world.navigation_grid
			var cw: Node = scene_root.find_child("ChunkWorld", true, false)
			if cw != null and "navigation_grid" in cw and cw.navigation_grid != null:
				return cw.navigation_grid

	return null

func _ensure_grid_exists() -> void:
	if movement_component == null or movement_component.grid != null:
		return

	# Resolver la autoridad de navegación procedural del mundo activo en lugar de generar un grid local ficticio
	var nav_grid: Object = _find_world_navigation_grid()
	if nav_grid != null:
		var current_pos: Vector3 = global_position if is_inside_tree() else position
		var initial_cell: Vector2i = nav_grid.world_to_cell(current_pos)
		setup_movement(nav_grid, null, initial_cell)

func _is_jump_active() -> bool:
	if _is_dropping:
		return true
	if movement_component != null and movement_component.is_moving:
		var tt: int = movement_component.current_transition_type
		if tt == _MovementResultScript.TransitionType.DROP or tt == _MovementResultScript.TransitionType.JUMP_UP or tt == _MovementResultScript.TransitionType.FALL:
			return true
	return false

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

	# 3. Captura de Input Direccional (WASD y Teclas de Flecha)
	var raw_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		raw_input.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		raw_input.y += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		raw_input.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		raw_input.x += 1.0

	var grid_dir: Vector2i = Vector2i.ZERO
	var chosen_octant: int = -1
	var is_new_press: bool = false

	# 4. Proyección a plano XZ y cuantización 8-way con histéresis angular
	if raw_input != Vector2.ZERO:
		var move_intent_3d: Vector3 = (right * raw_input.x) + (forward * -raw_input.y)
		var v := Vector2(move_intent_3d.x, move_intent_3d.z)

		if v.length() >= 0.2:
			var angle: float = atan2(v.y, v.x) # Rango [-PI, PI]
			is_new_press = (_last_8way_index == -1)

			# Histéresis angular: si ya había una dirección activa, aplicar zona de adherencia (+/- 8°)
			if _last_8way_index >= 0 and _last_8way_index < 8:
				var current_center_angle: float = wrapf(float(_last_8way_index) * (PI / 4.0), -PI, PI)
				var angle_diff: float = absf(wrapf(angle - current_center_angle, -PI, PI))
				var sticky_threshold: float = (PI / 8.0) + deg_to_rad(8.0) # ~30.5°
				if angle_diff <= sticky_threshold:
					chosen_octant = _last_8way_index

			if chosen_octant == -1:
				chosen_octant = posmod(int(round(angle / (PI / 4.0))), 8)

			_last_8way_index = chosen_octant
			grid_dir = DIRECTIONS_8[chosen_octant]
	else:
		_last_8way_index = -1
		_move_initiating_octant = -1
		if movement_component != null and not _is_jump_active():
			movement_component.clear_buffer()

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

	# 6. Acción de Salto Explícito (Spacebar / ui_accept)
	var space_down: bool = Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_accept")
	var jump_just_pressed: bool = (space_down and not _space_was_down) or Input.is_action_just_pressed("ui_accept")
	_space_was_down = space_down

	var jumped_this_frame: bool = false
	if jump_just_pressed and movement_component != null and not movement_component.is_moving and not _is_jump_active():
		var preferred_dir: Vector2i = Vector2i.ZERO
		if chosen_octant >= 0 and chosen_octant < 8:
			preferred_dir = DIRECTIONS_8[chosen_octant]
		elif _last_8way_index >= 0 and _last_8way_index < 8:
			preferred_dir = DIRECTIONS_8[_last_8way_index]

		var jump_res := movement_component.request_jump(preferred_dir)
		if jump_res != null and jump_res.accepted:
			jumped_this_frame = true

	# 7. Envío de MovementRequest de 8 direcciones (solo en tierra y si no está en salto)
	if not jumped_this_frame and not _is_jump_active() and movement_component != null and movement_component.grid != null:
		if chosen_octant != -1 and grid_dir != Vector2i.ZERO:
			var should_send: bool = false
			if not movement_component.is_moving:
				should_send = true
			else:
				var is_same_held_input: bool = (chosen_octant == _move_initiating_octant) and not is_new_press
				if not is_same_held_input or movement_component.progress >= 0.65:
					should_send = true

			if should_send:
				var req := _MovementRequestScript.new(grid_dir, &"player")
				var res := movement_component.request_movement(req)
				if res != null and res.accepted:
					_is_landing = false
					_move_initiating_octant = chosen_octant

	# 8. Velocidad aparente para shaders/efectos de agua (no gobierna la física)
	if delta > 0.0 and movement_component != null and movement_component.is_moving:
		velocity = (global_position - _last_frame_position) / delta
	else:
		velocity = Vector3.ZERO
	_last_frame_position = global_position

	# 9. Actualización de animaciones según estado de movimiento
	_update_animation_state()

func _on_movement_started(from: Vector2i, to: Vector2i) -> void:
	var dir := to - from
	var idx: int = DIRECTIONS_8.find(dir)
	if idx != -1:
		_move_initiating_octant = idx
	if _anim_playback != null and not _is_jump_active():
		_anim_playback.travel("Locomotion")

func _on_movement_finished(_from: Vector2i, _to: Vector2i) -> void:
	if movement_component != null and not movement_component.is_moving:
		_move_initiating_octant = -1
		if _anim_playback != null and not _is_jump_active() and not _is_landing:
			_anim_playback.travel("Idle")

func _on_drop_started(_from: Vector2i, _to: Vector2i) -> void:
	_is_dropping = true
	_is_landing = false
	if _anim_playback != null:
		_anim_playback.travel("Takeoff")

func _on_drop_takeoff(_from: Vector2i, _to: Vector2i) -> void:
	if _anim_playback != null:
		if _anim_tree != null and movement_component != null and movement_component.grid != null:
			var drop_levels: int = 1
			if movement_component.grid.has_method("get_cell_elevation"):
				drop_levels = maxi(1, int(abs(movement_component.grid.get_cell_elevation(_from) - movement_component.grid.get_cell_elevation(_to))))
			var total_flight: float = 0.48 + float(drop_levels - 1) * 0.06
			_anim_tree.set("parameters/Air/TimeScale/scale", 0.48 / total_flight)
		_anim_playback.travel("Air")

func _on_drop_finished(_from: Vector2i, _to: Vector2i) -> void:
	_is_dropping = false
	_is_landing = true
	if _anim_playback != null:
		_anim_playback.travel("Land")

func _on_jump_up_started(_from: Vector2i, _to: Vector2i) -> void:
	_is_dropping = true
	_is_landing = false
	if _anim_playback != null:
		_anim_playback.travel("Air")

func _on_jump_up_finished(_from: Vector2i, _to: Vector2i) -> void:
	_is_dropping = false
	_is_landing = true
	if _anim_playback != null:
		_anim_playback.travel("Land")

## Actualiza el AnimationTree sincronizando Idle, Locomotion o Salto según el estado del MovementComponent
func _update_animation_state() -> void:
	if _anim_tree == null or _anim_playback == null or movement_component == null:
		return

	var current_node := String(_anim_playback.get_current_node())

	# 1. Si está activo un salto o en fases de despegue/vuelo, preservar y salir de inmediato
	if _is_jump_active() or current_node == "Takeoff" or current_node == "Air":
		return

	# 2. Si ya volvió a Idle tras StandUp o reposo, resetear banderas
	if current_node == "Idle":
		_is_landing = false
		_is_dropping = false

	# 3. Si está en fase de aterrizaje o reincorporación (Land o StandUp)
	if _is_landing or current_node == "Land" or current_node == "StandUp":
		# Solo permitir interrupción si el jugador inicia una caminata real en tierra
		if movement_component.is_moving and not _is_jump_active():
			_is_landing = false
			_anim_playback.travel("Locomotion")
			var blend_pos: float = movement_component.profile.cells_per_second if movement_component.profile != null else normal_cells_per_second
			_anim_tree.set("parameters/Locomotion/blend_position", blend_pos)
		return

	# 4. Movimiento normal en tierra vs Idle
	if movement_component.is_moving and not _is_jump_active():
		_anim_playback.travel("Locomotion")
		var blend_pos: float = movement_component.profile.cells_per_second if movement_component.profile != null else normal_cells_per_second
		_anim_tree.set("parameters/Locomotion/blend_position", blend_pos)
	elif not _is_jump_active() and not _is_landing:
		_anim_playback.travel("Idle")
