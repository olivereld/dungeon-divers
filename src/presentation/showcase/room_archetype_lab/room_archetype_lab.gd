class_name RoomArchetypeLab
extends Node3D

## Controlador visual y de depuración interactivo del Room Archetype Lab.
## Permite seleccionar arquetipos, propósitos compatibles y semillas, mostrando
## la sala 3D resultante con overlays de ocupación y diagnósticos en tiempo real.

const _RoomArchetypeLabGeneratorScript = preload("res://src/presentation/showcase/room_archetype_lab/room_archetype_lab_generator.gd")
const _RoomPreviewRequestScript = preload("res://src/presentation/showcase/room_archetype_lab/room_preview_request.gd")
const _RoomPreviewResultScript = preload("res://src/presentation/showcase/room_archetype_lab/room_preview_result.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _ArchetypeCatalogScript = preload("res://src/dungeon_generator/profiles/archetype_catalog.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

@onready var room_root: Node3D = $RoomRoot
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

@onready var archetype_option: OptionButton = $UI/ControlPanel/VBox/ArchetypeOption
@onready var purpose_option: OptionButton = $UI/ControlPanel/VBox/PurposeOption
@onready var seed_spinbox: SpinBox = $UI/ControlPanel/VBox/SeedSpinBox
@onready var generate_btn: Button = $UI/ControlPanel/VBox/GenerateBtn
@onready var next_seed_btn: Button = $UI/ControlPanel/VBox/NextSeedBtn
@onready var clear_btn: Button = $UI/ControlPanel/VBox/ClearBtn

@onready var toggle_debug: CheckBox = $UI/ControlPanel/VBox/Toggles/ToggleDebug
@onready var toggle_fixtures: CheckBox = $UI/ControlPanel/VBox/Toggles/ToggleFixtures
@onready var toggle_props: CheckBox = $UI/ControlPanel/VBox/Toggles/ToggleProps

@onready var diagnostics_label: RichTextLabel = $UI/DebugPanel/DiagnosticsLabel

var _generator := _RoomArchetypeLabGeneratorScript.new()
var _current_result: _RoomPreviewResultScript = null

# Controles de cámara orbital
var _is_orbiting: bool = false
var _is_panning: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _cam_rot_x: float = -35.0
var _cam_rot_y: float = 45.0
var _cam_dist: float = 24.0

func _ready() -> void:
	_populate_archetype_dropdown()
	_on_archetype_selected(0)

	if generate_btn != null:
		generate_btn.pressed.connect(_on_generate_pressed)
	if next_seed_btn != null:
		next_seed_btn.pressed.connect(_on_next_seed_pressed)
	if clear_btn != null:
		clear_btn.pressed.connect(_on_clear_pressed)
	if archetype_option != null:
		archetype_option.item_selected.connect(_on_archetype_selected)
	if toggle_debug != null:
		toggle_debug.toggled.connect(_on_toggle_debug)
	if toggle_fixtures != null:
		toggle_fixtures.toggled.connect(_on_toggle_fixtures)
	if toggle_props != null:
		toggle_props.toggled.connect(_on_toggle_props)

	_update_camera_transform()
	_on_generate_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_is_orbiting = event.pressed
			_last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
			_last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cam_dist = maxf(6.0, _cam_dist - 2.0)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cam_dist = minf(60.0, _cam_dist + 2.0)
			_update_camera_transform()

	elif event is InputEventMouseMotion:
		if _is_orbiting:
			var delta: Vector2 = event.position - _last_mouse_pos
			_cam_rot_y -= delta.x * 0.4
			_cam_rot_x = clampf(_cam_rot_x - delta.y * 0.4, -85.0, 10.0)
			_last_mouse_pos = event.position
			_update_camera_transform()
		elif _is_panning and camera_pivot != null:
			var delta: Vector2 = event.position - _last_mouse_pos
			var right = camera.global_transform.basis.x * (-delta.x * 0.03)
			var up = camera.global_transform.basis.y * (delta.y * 0.03)
			camera_pivot.position += right + up
			_last_mouse_pos = event.position

func _update_camera_transform() -> void:
	if camera_pivot == null or camera == null:
		return
	camera_pivot.rotation_degrees = Vector3(_cam_rot_x, _cam_rot_y, 0.0)
	camera.position = Vector3(0.0, 0.0, _cam_dist)

func _populate_archetype_dropdown() -> void:
	if archetype_option == null:
		return
	archetype_option.clear()
	var catalog := _ArchetypeCatalogScript.new()
	var loader := _ProfileLoaderScript.new()
	var ids := catalog.get_ids()
	var idx := 0
	for id in ids:
		var arch = loader.load_archetype(str(id))
		var display_name: String = str(id).capitalize()
		if arch != null and not arch.display_name.is_empty():
			display_name = str(arch.display_name)
		archetype_option.add_item(display_name, idx)
		archetype_option.set_item_metadata(idx, id)
		idx += 1

func _on_archetype_selected(idx: int) -> void:
	if archetype_option == null or purpose_option == null:
		return
	var arch_id = archetype_option.get_item_metadata(idx)
	purpose_option.clear()

	var valid_purposes = _RoomPreviewRequestScript.get_valid_purposes_for_archetype(arch_id)
	var p_idx := 0
	for p_id in valid_purposes:
		var p_name = _RoomPurposeScript.to_name(p_id).capitalize()
		purpose_option.add_item(p_name, p_idx)
		purpose_option.set_item_metadata(p_idx, p_id)
		p_idx += 1

func _on_generate_pressed() -> void:
	if archetype_option == null or purpose_option == null:
		return

	var arch_idx = archetype_option.selected
	var purp_idx = purpose_option.selected
	var arch_id = archetype_option.get_item_metadata(arch_idx) if arch_idx >= 0 else &"necropolis"
	var purp_id: int = int(purpose_option.get_item_metadata(purp_idx)) if purp_idx >= 0 else 0
	var seed_val: int = int(seed_spinbox.value) if seed_spinbox != null else 12345

	generate_preview(arch_id, purp_id, seed_val)

func generate_preview(arch: Variant, purp: int, seed_val: int) -> _RoomPreviewResultScript:
	_clear_room()

	var req := _RoomPreviewRequestScript.new(arch, purp, seed_val, Vector2i(10, 8), 2.0, true, false)
	_current_result = _generator.generate_preview(req)

	if _current_result.success and _current_result.room_root != null:
		if room_root != null:
			room_root.add_child(_current_result.room_root)

		# Centrar cámara en el centro de la sala
		if camera_pivot != null and _current_result.room_geometry != null:
			var center_x = (_current_result.room_geometry.bounds.size.x * 0.5) * req.tile_size
			var center_z = (_current_result.room_geometry.bounds.size.y * 0.5) * req.tile_size
			camera_pivot.position = Vector3(center_x, 0.0, center_z)

		_update_toggles()
		_display_diagnostics(_current_result.diagnostics)
	else:
		if diagnostics_label != null:
			diagnostics_label.text = "[color=red]Error: %s[/color]" % _current_result.error_message

	return _current_result

func _on_next_seed_pressed() -> void:
	if seed_spinbox != null:
		seed_spinbox.value = int(seed_spinbox.value) + 1
	_on_generate_pressed()

func _on_clear_pressed() -> void:
	_clear_room()
	if diagnostics_label != null:
		diagnostics_label.text = "[color=gray]Laboratorio limpio.[/color]"

func _clear_room() -> void:
	if room_root != null:
		for child in room_root.get_children():
			child.queue_free()
	_current_result = null

func _on_toggle_debug(toggled: bool) -> void:
	if _current_result != null and _current_result.room_root != null:
		var node = _current_result.room_root.get_node_or_null("DebugOverlay")
		if node != null:
			node.visible = toggled

func _on_toggle_fixtures(toggled: bool) -> void:
	if _current_result != null and _current_result.room_root != null:
		var node = _current_result.room_root.get_node_or_null("Fixtures")
		if node != null:
			node.visible = toggled

func _on_toggle_props(toggled: bool) -> void:
	if _current_result != null and _current_result.room_root != null:
		var node = _current_result.room_root.get_node_or_null("Props")
		if node != null:
			node.visible = toggled

func _update_toggles() -> void:
	if toggle_debug != null:
		_on_toggle_debug(toggle_debug.button_pressed)
	if toggle_fixtures != null:
		_on_toggle_fixtures(toggle_fixtures.button_pressed)
	if toggle_props != null:
		_on_toggle_props(toggle_props.button_pressed)

func _display_diagnostics(diag: Dictionary) -> void:
	if diagnostics_label == null:
		return

	var arch_str = str(_DungeonArchetypeScript.resolve_id(diag.get("archetype", &"generic"))).to_upper()
	var purp_str = _RoomPurposeScript.to_name(diag.get("purpose", 0)).to_upper()

	var text := ""
	text += "[b][color=yellow]═══ ROOM ARCHETYPE LAB ═══[/color][/b]\n"
	text += "[b]Archetype:[/b] %s\n" % arch_str
	text += "[b]Purpose:[/b]   %s\n" % purp_str
	text += "[b]Seed:[/b]      %d\n\n" % diag.get("seed", 0)

	text += "[b][color=cyan]GEOMETRY[/color][/b]\n"
	text += "Dimensions: %d × %d\n" % [diag.get("width", 0), diag.get("depth", 0)]
	text += "Floor Cells: %d\n\n" % diag.get("floor_cells", 0)

	text += "[b][color=green]COMPOSITION (Production Engine)[/color][/b]\n"
	text += "Fixtures: %d\n" % diag.get("fixtures_count", 0)
	text += "Props:    %d\n" % diag.get("props_count", 0)
	text += "  👑 [b]Focal:[/b]      %d\n" % diag.get("focal_count", 0)
	text += "  📦 [b]Support:[/b]    %d\n" % diag.get("support_count", 0)
	text += "  🪨 [b]Ambient:[/b]    %d\n" % diag.get("ambient_count", 0)
	text += "  ⚙️ [b]Functional:[/b] %d\n\n" % diag.get("functional_count", 0)

	text += "[b][color=orange]OCCUPANCY & CLEARANCES[/color][/b]\n"
	text += "Occupied Cells: %d\n" % diag.get("occupied_cells_count", 0)
	text += "Reserved Cells: %d\n" % diag.get("reserved_cells_count", 0)
	text += "Rejections Avoided: %d\n" % diag.get("rejected_placements", 0)

	diagnostics_label.text = text
