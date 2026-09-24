class_name DungeonGameplayScene
extends Node3D

## Escena independiente dedicada a la exploración y jugabilidad dentro de la Mazmorra.
## Totalmente desacoplada del mundo exterior (chunks, vegetación, hidrología).

const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const _DungeonLightingControllerScript = preload("res://src/dungeon_generator/presentation/dungeon_lighting_controller.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _BiomeProfileScript = preload("res://src/dungeon_generator/presentation/biome_profile.gd")
const _IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")
const _PlayerTestScript = preload("res://src/character_test/player_test.gd")
const _DungeonWorldBridgeScript = preload("res://src/world_generator/poi/dungeon_world_bridge.gd")
const _DungeonSessionDataScript = preload("res://src/world_generator/poi/dungeon_session_data.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")

var dungeon_container: Node3D = null
var player: CharacterBody3D = null
var camera_rig: IsometricCameraRig = null
var world_environment: WorldEnvironment = null
var dungeon_light: DirectionalLight3D = null

# HUD
var _hud_layer: CanvasLayer = null
var _info_label: Label = null

var _dungeon_builder := _DungeonPresentationBuilderScript.new()
var _semantic_orchestrator := _SemanticOrchestratorScript.new()
var _lighting_controller := _DungeonLightingControllerScript.new()
var _profile_loader := _ProfileLoaderScript.new()

var poi: RefCounted = null
var dungeon_result: RefCounted = null
var semantic_result: DungeonSemanticResult = null
var config: DungeonConfig = null
var spawn_world_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	poi = _DungeonSessionDataScript.active_poi
	dungeon_result = _DungeonSessionDataScript.active_dungeon_result

	_setup_lighting_and_env()
	_setup_hud()
	_generate_and_materialize_dungeon()
	_setup_player()


func _setup_lighting_and_env() -> void:
	# Directional light para luces rasantes en muros
	dungeon_light = DirectionalLight3D.new()
	dungeon_light.name = "DungeonLight"
	dungeon_light.transform = Transform3D(
		Vector3(0.707107, 0, -0.707107),
		Vector3(-0.5, 0.707107, -0.5),
		Vector3(0.5, 0.707107, 0.5),
		Vector3(0, 20, 0)
	)
	dungeon_light.light_color = Color(0.85, 0.9, 1.0, 1.0)
	dungeon_light.light_energy = 0.65
	dungeon_light.shadow_enabled = false
	add_child(dungeon_light)

	# WorldEnvironment oscuro con fondo negro/niebla
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.015, 0.02, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.26, 0.35, 1.0)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	world_environment.environment = env
	add_child(world_environment)


func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUDLayer"
	add_child(_hud_layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = 380
	panel.offset_bottom = 240
	_hud_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_info_label = Label.new()
	_info_label.name = "InfoLabel"
	_info_label.text = "Materializando mazmorra 3D..."
	vbox.add_child(_info_label)

	var exit_btn := Button.new()
	exit_btn.text = "🚪 Salir al Mundo Exterior [ESC]"
	exit_btn.focus_mode = Control.FOCUS_NONE
	exit_btn.pressed.connect(_return_to_overworld)
	vbox.add_child(exit_btn)


func _generate_and_materialize_dungeon() -> void:
	# 1. Configuración de la mazmorra
	if poi != null:
		config = _DungeonWorldBridgeScript.create_dungeon_config(poi)
	else:
		config = _DungeonConfigScript.new()
		config.dungeon_id = &"standalone_necropolis"
		config.archetype_id = &"necropolis"
		config.seed = 12345
		config.use_fixed_seed = true

	# 2. Generación o reutilización del DungeonResult
	var raw_res = dungeon_result
	if raw_res == null:
		if poi != null:
			raw_res = _DungeonWorldBridgeScript.generate_dungeon_from_poi(poi)
		else:
			var pipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd").new()
			raw_res = pipeline.generate(config)

	if raw_res == null:
		push_error("[DungeonGameplayScene] Falló la generación de la mazmorra.")
		return

	# 3. Fase Semántica
	if raw_res is DungeonSemanticResult:
		semantic_result = raw_res as DungeonSemanticResult
	else:
		semantic_result = _semantic_orchestrator.generate_semantics(raw_res, config)

	if semantic_result == null:
		push_error("[DungeonGameplayScene] Falló la fase semántica.")
		return

	# 4. Contenedor de la mazmorra
	dungeon_container = Node3D.new()
	dungeon_container.name = "DungeonPresentationRoot"
	add_child(dungeon_container)

	# 5. Materialización 3D con PresentationBuilder
	var biome := _BiomeProfileScript.new()
	var pres_res = _dungeon_builder.build_presentation(semantic_result, dungeon_container, biome, config, null, true)
	if pres_res == null or not pres_res.success:
		push_error("[DungeonGameplayScene] Error en PresentationBuilder.")

	# 6. Iluminación temática del arquetipo
	var arch_id: StringName = semantic_result.get_archetype_id() if semantic_result.has_method("get_archetype_id") else &"necropolis"
	var arch_prof = _profile_loader.load_archetype(arch_id)
	if arch_prof != null and arch_prof.lighting != null:
		_lighting_controller.apply_lighting(arch_prof.lighting, world_environment, dungeon_light)

	# 7. Cálculo del punto de spawn de la sala inicial 'start'
	var cell_size: float = config.cell_size if config != null else 2.0
	var target_room = null
	if semantic_result.start_room_id >= 0:
		for r in semantic_result.rooms:
			if r.id == semantic_result.start_room_id:
				target_room = r
				break
	if target_room == null:
		for r in semantic_result.rooms:
			if ("room_type" in r and r.room_type == &"start") or ("purpose" in r and r.purpose == "start"):
				target_room = r
				break
	if target_room == null and not semantic_result.rooms.is_empty():
		target_room = semantic_result.rooms[0]

	if target_room != null and ("rect" in target_room):
		var r_rect: Rect2i = target_room.rect
		var sx: float = (float(r_rect.position.x) + float(r_rect.size.x) * 0.5) * cell_size
		var sz: float = (float(r_rect.position.y) + float(r_rect.size.y) * 0.5) * cell_size
		spawn_world_pos = Vector3(sx, 0.8, sz)
	else:
		spawn_world_pos = Vector3(0.0, 0.8, 0.0)


func _setup_player() -> void:
	player = _PlayerTestScript.new()
	player.name = "Player"
	player.position = spawn_world_pos
	add_child(player)

	camera_rig = _IsometricCameraRigScript.new()
	camera_rig.name = "IsometricCameraRig"
	camera_rig.yaw_degrees = 45.0
	camera_rig.pitch_degrees = 35.264
	camera_rig.zoom_min = 6.0
	camera_rig.zoom_max = 60.0
	camera_rig.default_zoom = 18.0
	camera_rig.zoom_step = 4.0
	camera_rig.zoom_smoothing = 14.0
	camera_rig.follow_speed = 12.0
	add_child(camera_rig)

	camera_rig.set_target(player)
	camera_rig.set_follow_enabled(true)
	camera_rig.teleport_to_target()


func _process(_delta: float) -> void:
	_update_hud()


func _update_hud() -> void:
	if _info_label == null or player == null:
		return

	var fps: int = int(Engine.get_frames_per_second())
	var p_pos: Vector3 = player.global_position
	var d_id: String = String(poi.identity.dungeon_id) if (poi != null and poi.identity != null) else (config.dungeon_id if config != null else "Dungeon")
	var arch: String = String(poi.archetype_id) if poi != null else (config.archetype_id if config != null else "necropolis")
	var room_count: int = semantic_result.rooms.size() if semantic_result != null else 0

	var text := "=== 🏰 MAZMORRA (ESCENA INDEPENDIENTE) ===\n"
	text += "FPS: %d\n" % fps
	text += "ID: %s | Salas: %d\n" % [d_id, room_count]
	text += "Arquetipo: %s\n" % arch.capitalize()
	text += "Posición: (%.1f, %.1f, %.1f)\n" % [p_pos.x, p_pos.y, p_pos.z]
	text += "-----------------------------------\n"
	text += "[WASD / Flechas]: Mover personaje\n"
	text += "[Q / E]: Rotar cámara orbital 45°\n"
	text += "[Rueda Mouse]: Zoom In / Out\n"
	text += "[Espacio]: Saltar\n"
	text += "[R]: Reaparecer al inicio de la mazmorra\n"
	text += "[ESC / Backspace]: SALIR AL MUNDO EXTERIOR\n"
	_info_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_ESCAPE or ke.keycode == KEY_BACKSPACE:
			_return_to_overworld()
			return
		elif ke.keycode == KEY_R:
			_respawn_player()
			return
		elif ke.keycode == KEY_Q:
			if camera_rig != null:
				camera_rig.yaw_degrees -= 45.0
		elif ke.keycode == KEY_E:
			if camera_rig != null:
				camera_rig.yaw_degrees += 45.0

	if camera_rig != null and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.is_pressed():
			camera_rig.zoom_in()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.is_pressed():
			camera_rig.zoom_out()


func _respawn_player() -> void:
	if player != null:
		player.velocity = Vector3.ZERO
		player.global_position = spawn_world_pos
		if camera_rig != null:
			camera_rig.teleport_to_target()


func _return_to_overworld() -> void:
	print("[DungeonGameplayScene] Regresando a la escena del mundo exterior...")
	var return_path: String = _DungeonSessionDataScript.return_scene_path
	if return_path.is_empty():
		return_path = "res://src/world_generator/scenes/chunk_world_integration.tscn"
	get_tree().change_scene_to_file(return_path)
