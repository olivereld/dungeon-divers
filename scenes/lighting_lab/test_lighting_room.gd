extends Node3D

## Escena de Calibración: Habitación Cuadrada Standalone (Diorama de Iluminación 3D).
## Genera exclusivamente una sala cuadrada aislada (sin mazmorra externa) para calibrar la iluminación.

const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPresentationBuilder = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const BiomeProfile = preload("res://src/dungeon_generator/presentation/biome_profile.gd")
const DungeonLightingConfig = preload("res://src/dungeon_lighting/config/dungeon_lighting_config.gd")
const LightingProfile = preload("res://src/dungeon_lighting/config/lighting_profile.gd")
const CellGrid = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const DungeonSemanticResult = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")
const TorchLightController = preload("res://src/dungeon_lighting/presentation/torch_light_controller.gd")

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var dir_light: DirectionalLight3D = $DirectionalLight3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var dungeon_holder: Node3D = $DungeonHolder

# Controles UI
@onready var slider_torch_energy: HSlider = %SliderTorchEnergy
@onready var label_torch_energy: Label = %LabelTorchEnergy
@onready var slider_torch_range: HSlider = %SliderTorchRange
@onready var label_torch_range: Label = %LabelTorchRange
@onready var slider_torch_attenuation: HSlider = %SliderTorchAttenuation
@onready var label_torch_attenuation: Label = %LabelTorchAttenuation
@onready var picker_torch_color: ColorPickerButton = %PickerTorchColor
@onready var check_shadows: CheckBox = %CheckShadows
@onready var check_flicker: CheckBox = %CheckFlicker
@onready var slider_flicker_amp: HSlider = %SliderFlickerAmp
@onready var label_flicker_amp: Label = %LabelFlickerAmp

@onready var slider_ambient_energy: HSlider = %SliderAmbientEnergy
@onready var label_ambient_energy: Label = %LabelAmbientEnergy
@onready var picker_ambient_color: ColorPickerButton = %PickerAmbientColor
@onready var slider_rim_energy: HSlider = %SliderRimEnergy
@onready var label_rim_energy: Label = %LabelRimEnergy
@onready var picker_rim_color: ColorPickerButton = %PickerRimColor
@onready var slider_fog_density: HSlider = %SliderFogDensity
@onready var label_fog_density: Label = %LabelFogDensity

@onready var btn_regenerate: Button = %BtnRegenerate

var _lighting_profile := LightingProfile.new()
var _is_dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _torch_count: int = 2

func _ready() -> void:
	_init_ui_defaults()
	_connect_ui_signals()
	_build_standalone_square_room()

func _init_ui_defaults() -> void:
	if picker_torch_color:
		picker_torch_color.color = _lighting_profile.light_color
	if slider_torch_energy:
		slider_torch_energy.value = _lighting_profile.energy
		label_torch_energy.text = "%.2f" % _lighting_profile.energy
	if slider_torch_range:
		slider_torch_range.value = _lighting_profile.omni_range
		label_torch_range.text = "%.1f m" % _lighting_profile.omni_range
	if slider_torch_attenuation:
		slider_torch_attenuation.value = _lighting_profile.attenuation
		label_torch_attenuation.text = "%.2f" % _lighting_profile.attenuation
	if check_shadows:
		check_shadows.button_pressed = _lighting_profile.shadow_enabled
	if check_flicker:
		check_flicker.button_pressed = _lighting_profile.flicker_enabled
	if slider_flicker_amp:
		slider_flicker_amp.value = _lighting_profile.flicker_amplitude
		label_flicker_amp.text = "%.2f" % _lighting_profile.flicker_amplitude

	if world_env and world_env.environment:
		var env = world_env.environment
		if slider_ambient_energy:
			slider_ambient_energy.value = env.ambient_light_energy
			label_ambient_energy.text = "%.2f" % env.ambient_light_energy
		if picker_ambient_color:
			picker_ambient_color.color = env.ambient_light_color
		if slider_fog_density:
			slider_fog_density.value = env.fog_density
			label_fog_density.text = "%.4f" % env.fog_density

	if dir_light:
		if slider_rim_energy:
			slider_rim_energy.value = dir_light.light_energy
			label_rim_energy.text = "%.2f" % dir_light.light_energy
		if picker_rim_color:
			picker_rim_color.color = dir_light.light_color

func _connect_ui_signals() -> void:
	slider_torch_energy.value_changed.connect(_on_torch_energy_changed)
	slider_torch_range.value_changed.connect(_on_torch_range_changed)
	slider_torch_attenuation.value_changed.connect(_on_torch_attenuation_changed)
	picker_torch_color.color_changed.connect(_on_torch_color_changed)
	check_shadows.toggled.connect(_on_shadows_toggled)
	check_flicker.toggled.connect(_on_flicker_toggled)
	slider_flicker_amp.value_changed.connect(_on_flicker_amp_changed)

	slider_ambient_energy.value_changed.connect(_on_ambient_energy_changed)
	picker_ambient_color.color_changed.connect(_on_ambient_color_changed)
	slider_rim_energy.value_changed.connect(_on_rim_energy_changed)
	picker_rim_color.color_changed.connect(_on_rim_color_changed)
	slider_fog_density.value_changed.connect(_on_fog_density_changed)

	btn_regenerate.pressed.connect(_build_standalone_square_room)

## Construye exclusivamente una habitación cuadrada aislada (6x6 celdas) con sus 4 muros perimetrales.
func _build_standalone_square_room() -> void:
	for child in dungeon_holder.get_children():
		child.queue_free()

	var grid_w: int = 8
	var grid_h: int = 8
	var room_size: int = 6

	var grid := CellGrid.new(grid_w, grid_h, CellGrid.CellType.WALL)
	# Llenar el interior (1,1 a 6,6) con suelo
	for y in range(1, 1 + room_size):
		for x in range(1, 1 + room_size):
			var cell := Vector2i(x, y)
			grid.set_cell(cell, CellGrid.CellType.FLOOR)
			grid.set_room_owner(cell, 1)

	var room := RoomData.new(1, Rect2i(1, 1, room_size, room_size))

	var sem_res := DungeonSemanticResult.new()
	sem_res.grid = grid
	sem_res.rooms = [room]
	sem_res.connections = []
	sem_res.corridor_paths = []
	sem_res.door_pairs = []
	sem_res.keys = []
	sem_res.locks = []
	sem_res.objectives = []
	sem_res.gameplay_valid = true

	var cfg := DungeonConfig.new()
	cfg.seed = randi() % 100000
	cfg.grid_width = grid_w
	cfg.grid_height = grid_h
	cfg.wall_height = 2

	var l_cfg := DungeonLightingConfig.new()
	l_cfg.min_lights_per_room = _torch_count
	l_cfg.max_lights_per_room = _torch_count
	l_cfg.min_light_spacing = 3.0
	cfg.lighting_config = l_cfg

	var biome := BiomeProfile.new()
	biome.lighting_profile = _lighting_profile

	var builder := DungeonPresentationBuilder.new()
	var pres = builder.build_presentation(sem_res, dungeon_holder, biome, cfg)

	# Centrar pivote de la cámara en el centro exacto de la habitación (6x6 celdas * 2m = 12m)
	var center_x: float = float(grid_w) * 0.5 * 2.0
	var center_z: float = float(grid_h) * 0.5 * 2.0
	camera_pivot.position = Vector3(center_x, 0.0, center_z)

	_apply_live_lighting_updates()

func _apply_live_lighting_updates() -> void:
	var omnis = dungeon_holder.find_children("*", "OmniLight3D", true, false)
	for omni in omnis:
		omni.light_color = _lighting_profile.light_color
		omni.light_energy = _lighting_profile.energy
		omni.omni_range = _lighting_profile.omni_range
		omni.omni_attenuation = _lighting_profile.attenuation
		omni.shadow_enabled = _lighting_profile.shadow_enabled

	var controllers = dungeon_holder.find_children("*", "TorchLightController", true, false)
	for ctrl in controllers:
		ctrl.base_energy = _lighting_profile.energy
		ctrl.flicker_amplitude = _lighting_profile.flicker_amplitude if _lighting_profile.flicker_enabled else 0.0

func _on_torch_energy_changed(val: float) -> void:
	_lighting_profile.energy = val
	label_torch_energy.text = "%.2f" % val
	_apply_live_lighting_updates()

func _on_torch_range_changed(val: float) -> void:
	_lighting_profile.omni_range = val
	label_torch_range.text = "%.1f m" % val
	_apply_live_lighting_updates()

func _on_torch_attenuation_changed(val: float) -> void:
	_lighting_profile.attenuation = val
	label_torch_attenuation.text = "%.2f" % val
	_apply_live_lighting_updates()

func _on_torch_color_changed(c: Color) -> void:
	_lighting_profile.light_color = c
	_apply_live_lighting_updates()

func _on_shadows_toggled(pressed: bool) -> void:
	_lighting_profile.shadow_enabled = pressed
	_apply_live_lighting_updates()

func _on_flicker_toggled(pressed: bool) -> void:
	_lighting_profile.flicker_enabled = pressed
	_apply_live_lighting_updates()

func _on_flicker_amp_changed(val: float) -> void:
	_lighting_profile.flicker_amplitude = val
	label_flicker_amp.text = "%.2f" % val
	_apply_live_lighting_updates()

func _on_ambient_energy_changed(val: float) -> void:
	if world_env and world_env.environment:
		world_env.environment.ambient_light_energy = val
	label_ambient_energy.text = "%.2f" % val

func _on_ambient_color_changed(c: Color) -> void:
	if world_env and world_env.environment:
		world_env.environment.ambient_light_color = c

func _on_rim_energy_changed(val: float) -> void:
	if dir_light:
		dir_light.light_energy = val
	label_rim_energy.text = "%.2f" % val

func _on_rim_color_changed(c: Color) -> void:
	if dir_light:
		dir_light.light_color = c

func _on_fog_density_changed(val: float) -> void:
	if world_env and world_env.environment:
		world_env.environment.fog_density = val
	label_fog_density.text = "%.4f" % val

# Control de Cámara Orbital con Ratón
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = event.pressed
			_last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(8.0, camera.size - 1.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(50.0, camera.size + 1.5)

	elif event is InputEventMouseMotion and _is_dragging:
		var delta = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		camera_pivot.rotation.y -= delta.x * 0.008
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - delta.y * 0.008, -PI * 0.45, -PI * 0.1)
