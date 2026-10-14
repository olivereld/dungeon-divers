class_name DungeonEntrancePOIView
extends Node3D

## Vista exterior e interactiva para una entrada de mazmorra (POI).
## Carga el modelo 3D detallado de cripta para el arquetipo necropolis,
## con iluminación atmosférica espectral, colisión física, área de detección
## y etiqueta interactiva para descender a la mazmorra.

signal dungeon_enter_requested(poi: RefCounted, dungeon_result: RefCounted, player_node: Node3D)

const _DungeonWorldBridgeScript = preload("res://src/world_generator/poi/dungeon_world_bridge.gd")
const NECROPOLIS_MODEL_PATH: String = "res://models/dungeon/necropolis_entrance/entrance_dungeon_necropolis.glb"

static var _cached_necropolis_scene: PackedScene = null

var poi: RefCounted = null
var _player_inside: bool = false
var _player_node: CharacterBody3D = null
var _prompt_label: Label3D = null

func _init(p_poi: RefCounted = null) -> void:
	poi = p_poi

func _ready() -> void:
	var d_id: String = String(poi.identity.dungeon_id) if (poi != null and "identity" in poi and poi.identity != null) else "unknown"
	name = "DungeonEntrance_%s" % d_id
	_build_visuals()
	_build_trigger()

static func _get_necropolis_scene() -> PackedScene:
	if _cached_necropolis_scene == null and ResourceLoader.exists(NECROPOLIS_MODEL_PATH):
		_cached_necropolis_scene = load(NECROPOLIS_MODEL_PATH) as PackedScene
	return _cached_necropolis_scene

func _build_visuals() -> void:
	var arch: String = String(poi.archetype_id) if (poi != null and "archetype_id" in poi) else "necropolis"
	var necropolis_scene := _get_necropolis_scene()

	if arch == "necropolis" and necropolis_scene != null:
		_build_necropolis_visuals(necropolis_scene)
	else:
		_build_fallback_visuals()

	# Etiqueta flotante con datos del POI y aviso para interactuar
	_prompt_label = Label3D.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.no_depth_test = true
	_prompt_label.position = Vector3(0.0, 5.6, 0.0)
	_prompt_label.pixel_size = 0.015
	_prompt_label.font_size = 28
	_prompt_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_prompt_label.outline_render_priority = 10
	_prompt_label.outline_modulate = Color.BLACK
	_prompt_label.outline_size = 6
	
	var d_id: String = String(poi.identity.dungeon_id) if (poi != null and "identity" in poi and poi.identity != null) else "Dungeon"
	var tier: int = poi.tier if (poi != null and "tier" in poi) else 1
	_prompt_label.text = "[ %s ]\nArquetipo: %s (Tier %d)\nAcércate para interactuar" % [d_id, arch.capitalize(), tier]
	add_child(_prompt_label)

func _build_necropolis_visuals(scene: PackedScene) -> void:
	# 1. Instanciar el modelo 3D detallado de la cripta
	var model_inst = scene.instantiate()
	model_inst.name = "NecropolisModel"
	# Escala a proporciones monumentales (~3.3m ancho, ~4.8m alto, ~5.0m fondo)
	model_inst.scale = Vector3(5.0, 5.0, 5.0)
	# Asentar firmemente sobre el terreno (-0.07m bajo la cota Y para evitar que flote en pendientes)
	model_inst.position = Vector3(0.0, 2.30, 0.0)
	add_child(model_inst)

	# 2. Resplandor místico atmosférico saliendo del portal de la cripta
	var glow := OmniLight3D.new()
	glow.name = "EntranceGlow"
	glow.position = Vector3(0.0, 2.2, -0.6)
	glow.light_color = Color(0.25, 0.90, 0.75) # Cian / verde espectral necromántico
	glow.light_energy = 2.5
	glow.omni_range = 6.0
	add_child(glow)

	# 3. Baliza vertical mística estilizada
	var beacon := MeshInstance3D.new()
	beacon.name = "EntranceBeacon"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 14.0
	beacon.mesh = cyl
	beacon.position = Vector3(0.0, 8.5, 0.0)
	var b_mat := StandardMaterial3D.new()
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b_mat.albedo_color = Color(0.20, 0.90, 0.75, 0.35)
	b_mat.emission_enabled = true
	b_mat.emission = Color(0.10, 0.85, 0.65, 1.0)
	b_mat.emission_energy_multiplier = 3.5
	beacon.material_override = b_mat
	add_child(beacon)

	# 4. Colisión física ajustada a la volumetría de la cripta
	var static_body := StaticBody3D.new()
	static_body.name = "EntranceCollision"
	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(3.6, 5.0, 4.8)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 2.4, -2.4)
	static_body.add_child(col_shape)
	add_child(static_body)

func _build_fallback_visuals() -> void:
	# Fallback para arquetipos que aún no tienen modelo 3D dedicado
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "EntranceCube"
	var box := BoxMesh.new()
	box.size = Vector3(4.0, 5.0, 4.0)
	mesh_inst.mesh = box
	mesh_inst.position = Vector3(0.0, 2.3, 0.0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.15, 0.15, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.roughness = 0.25
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	var beacon := MeshInstance3D.new()
	beacon.name = "EntranceBeacon"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 0.8
	cyl.height = 14.0
	beacon.mesh = cyl
	beacon.position = Vector3(0.0, 7.0, 0.0)
	var b_mat := StandardMaterial3D.new()
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.45)
	b_mat.emission_enabled = true
	b_mat.emission = Color(1.0, 0.1, 0.1, 1.0)
	b_mat.emission_energy_multiplier = 4.0
	beacon.material_override = b_mat
	add_child(beacon)

	var static_body := StaticBody3D.new()
	static_body.name = "EntranceCollision"
	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	col_shape.shape = box_shape
	col_shape.position = mesh_inst.position
	static_body.add_child(col_shape)
	add_child(static_body)

func _build_trigger() -> void:
	# Área de interacción
	var area := Area3D.new()
	area.name = "InteractionArea"
	var trigger_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 6.0
	trigger_shape.shape = sphere
	trigger_shape.position = Vector3(0.0, 1.5, 0.0)
	area.add_child(trigger_shape)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _on_body_entered(body: Node) -> void:
	if body.name.to_lower().contains("player") or body is CharacterBody3D:
		_player_inside = true
		if body is CharacterBody3D:
			_player_node = body as CharacterBody3D
		if _prompt_label != null:
			var d_id: String = String(poi.identity.dungeon_id) if (poi != null and "identity" in poi and poi.identity != null) else "Dungeon"
			_prompt_label.text = "[ %s ]\nPulsa [ INTRO / ENTER ] para entrar a la Mazmorra" % d_id
			_prompt_label.modulate = Color(1.0, 0.9, 0.2, 1.0)

func _on_body_exited(body: Node) -> void:
	if body.name.to_lower().contains("player") or body is CharacterBody3D:
		_player_inside = false
		_player_node = null
		if _prompt_label != null:
			var d_id: String = String(poi.identity.dungeon_id) if (poi != null and "identity" in poi and poi.identity != null) else "Dungeon"
			var arch: String = String(poi.archetype_id) if (poi != null and "archetype_id" in poi) else "necropolis"
			var tier: int = poi.tier if (poi != null and "tier" in poi) else 1
			_prompt_label.text = "[ %s ]\nArquetipo: %s (Tier %d)\nAcércate para interactuar" % [d_id, arch.capitalize(), tier]
			_prompt_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_enter_dungeon()

func _enter_dungeon() -> void:
	if poi == null:
		return
	print("[DungeonEntrance] ¡Jugador pulsó INTRO! Generando y accediendo a la mazmorra %s..." % (poi.identity.dungeon_id if ("identity" in poi and poi.identity != null) else "unknown"))
	
	# Invocar el DungeonWorldBridge determinista
	var dungeon_res = _DungeonWorldBridgeScript.generate_dungeon_from_poi(poi)
	if dungeon_res != null:
		print("[DungeonEntrance] ¡Interior generado con éxito! Checksum: %s, Salas: %d" % [dungeon_res.checksum, dungeon_res.rooms.size()])
		if _prompt_label != null:
			_prompt_label.text = "¡ENTRANDO A LA MAZMORRA!\nChecksum: %s (%d salas)" % [dungeon_res.checksum, dungeon_res.rooms.size()]
			_prompt_label.modulate = Color(0.2, 1.0, 0.4, 1.0)
	
	dungeon_enter_requested.emit(poi, dungeon_res, _player_node)
