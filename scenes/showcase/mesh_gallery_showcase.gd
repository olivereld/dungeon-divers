class_name MeshGalleryShowcase
extends Node3D

## Mesh Generation Lab (Showcase & Geometry Inspection Studio).
## Escena de depuración y análisis para examinar de forma aislada e interactiva
## los modelos 3D y clusters procedurales generados por el motor del Dungeon.

const _CatalogScript = preload("res://src/presentation/showcase/mesh_gallery_catalog.gd")
const _RendererScript = preload("res://src/presentation/showcase/mesh_gallery_renderer.gd")
const _MetricsScript = preload("res://src/presentation/showcase/mesh_gallery_metrics.gd")
const _EntryScript = preload("res://src/presentation/showcase/mesh_gallery_entry.gd")

@onready var camera_rig: Node3D = $IsometricCameraRig
@onready var gallery_root: Node3D = $GalleryRoot
@onready var active_preview: Node3D = $GalleryRoot/ActivePreview
@onready var prop_anchor: Node3D = $GalleryRoot/ActivePreview/PropAnchor
@onready var debug_bounds_mesh: MeshInstance3D = $GalleryRoot/ActivePreview/DebugBounds

# UI References
@onready var ui_category_list: VBoxContainer = $UI/PanelContainer/Margin/HBox/Sidebar/CategoryList
@onready var ui_item_list: VBoxContainer = $UI/PanelContainer/Margin/HBox/Sidebar/Scroll/ItemList
@onready var ui_title_label: Label = $UI/PanelContainer/Margin/HBox/InfoPanel/TitleLabel
@onready var ui_script_label: Label = $UI/PanelContainer/Margin/HBox/InfoPanel/ScriptLabel
@onready var ui_stats_label: Label = $UI/PanelContainer/Margin/HBox/InfoPanel/StatsLabel
@onready var ui_bounds_label: Label = $UI/PanelContainer/Margin/HBox/InfoPanel/BoundsLabel
@onready var ui_desc_label: Label = $UI/PanelContainer/Margin/HBox/InfoPanel/DescLabel
@onready var ui_rotate_check: CheckBox = $UI/PanelContainer/Margin/HBox/InfoPanel/Controls/RotateCheck
@onready var ui_wireframe_check: CheckBox = $UI/PanelContainer/Margin/HBox/InfoPanel/Controls/WireframeCheck
@onready var ui_bounds_check: CheckBox = $UI/PanelContainer/Margin/HBox/InfoPanel/Controls/BoundsCheck
@onready var ui_seed_spin: SpinBox = $UI/PanelContainer/Margin/HBox/InfoPanel/Controls/SeedHBox/SeedSpin
@onready var ui_clusters_container: VBoxContainer = $UI/PanelContainer/Margin/HBox/InfoPanel/ClusterSection/ClusterList
@onready var ui_clusters_header: Label = $UI/PanelContainer/Margin/HBox/InfoPanel/ClusterSection/ClusterHeader

var _catalog: MeshGalleryCatalog = null
var _renderer: MeshGalleryRenderer = null
var _current_category_idx: int = 0
var _current_item_idx: int = 0
var _current_entry: MeshGalleryEntry = null
var _current_seed: int = 1337
var _auto_rotate: bool = true
var _rotation_speed: float = 0.8
var _is_wireframe: bool = false
var _show_bounds: bool = false

func _ready() -> void:
	_catalog = _CatalogScript.new()
	_renderer = _RendererScript.new()

	_build_category_buttons()
	_setup_controls()
	_select_category(0)

func _process(delta: float) -> void:
	if _auto_rotate and prop_anchor != null:
		prop_anchor.rotation.y += _rotation_speed * delta

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if camera_rig != null and camera_rig.has_method("zoom_in"):
				camera_rig.zoom_in(2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if camera_rig != null and camera_rig.has_method("zoom_out"):
				camera_rig.zoom_out(2.0)

# ==============================================================================
# UI & NAVEGACIÓN
# ==============================================================================

func _build_category_buttons() -> void:
	for child in ui_category_list.get_children():
		child.queue_free()

	var categories = _catalog.get_categories()
	for i in range(categories.size()):
		var cat = categories[i]
		var btn := Button.new()
		btn.text = cat.name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 38)
		btn.pressed.connect(_on_category_button_pressed.bind(i))
		ui_category_list.add_child(btn)

func _on_category_button_pressed(idx: int) -> void:
	_select_category(idx)

func _select_category(idx: int) -> void:
	_current_category_idx = idx
	_build_item_buttons()
	_select_item(0)

func _build_item_buttons() -> void:
	for child in ui_item_list.get_children():
		child.queue_free()

	var categories = _catalog.get_categories()
	if _current_category_idx >= categories.size():
		return

	var cat = categories[_current_category_idx]
	var entries: Array = cat.entries

	for i in range(entries.size()):
		var entry: MeshGalleryEntry = entries[i]
		var btn := Button.new()
		btn.text = "• " + entry.name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_item_button_pressed.bind(i))
		ui_item_list.add_child(btn)

func _on_item_button_pressed(idx: int) -> void:
	_select_item(idx)

func _select_item(idx: int) -> void:
	_current_item_idx = idx
	var categories = _catalog.get_categories()
	if _current_category_idx >= categories.size():
		return

	var cat = categories[_current_category_idx]
	var entries: Array = cat.entries
	if idx >= entries.size():
		return

	_current_entry = entries[idx]

	ui_title_label.text = _current_entry.name
	ui_script_label.text = "Script: " + _current_entry.script_path
	ui_desc_label.text = _current_entry.description

	_regenerate_active_preview()

# ==============================================================================
# ACTIVE PREVIEW & REGENERACIÓN GRANULAR
# ==============================================================================

func _regenerate_active_preview() -> void:
	if _current_entry == null or prop_anchor == null:
		return

	# 1. Limpiar geometría previa en el ancla
	for child in prop_anchor.get_children():
		child.queue_free()

	# 2. Renderizar mediante el despachador central
	var rendered_node: Node3D = _renderer.render_entry(_current_entry, _current_seed)
	if rendered_node != null:
		prop_anchor.add_child(rendered_node)

	# 3. Extraer y actualizar métricas
	var metrics = _MetricsScript.calculate_node_metrics(rendered_node)
	ui_stats_label.text = metrics.to_summary_string()
	ui_bounds_label.text = metrics.to_bounds_string()

	# 4. Actualizar visualizador de bounds AABB
	_update_debug_bounds(metrics.bounds)

	# 5. Poblar inspección de clusters
	_build_cluster_toggles(rendered_node)

	# 6. Aplicar modo wireframe si está activo
	_apply_wireframe_mode()

	# 7. Enfocar cámara isométrica
	if camera_rig != null:
		if camera_rig.has_method("set_target"):
			camera_rig.set_target(active_preview)
			camera_rig.teleport_to_target()
		else:
			camera_rig.global_position = active_preview.global_position

func _build_cluster_toggles(root: Node3D) -> void:
	for child in ui_clusters_container.get_children():
		child.queue_free()

	if root == null:
		ui_clusters_header.visible = false
		return

	var clusters_node = root.find_child("Clusters", true, false)
	if clusters_node == null or clusters_node.get_child_count() == 0:
		ui_clusters_header.visible = false
		return

	ui_clusters_header.visible = true
	var count = clusters_node.get_child_count()

	for i in range(count):
		var cluster_mi = clusters_node.get_child(i) as MeshInstance3D
		if cluster_mi == null:
			continue

		var chk := CheckBox.new()
		chk.text = cluster_mi.name
		chk.button_pressed = true
		chk.toggled.connect(func(val: bool):
			cluster_mi.visible = val
			var m = _MetricsScript.calculate_node_metrics(root)
			ui_stats_label.text = m.to_summary_string()
		)
		ui_clusters_container.add_child(chk)

func _update_debug_bounds(aabb: AABB) -> void:
	if debug_bounds_mesh == null:
		return

	if not _show_bounds or aabb.size == Vector3.ZERO:
		debug_bounds_mesh.visible = false
		return

	debug_bounds_mesh.visible = true
	var box := BoxMesh.new()
	box.size = aabb.size
	debug_bounds_mesh.mesh = box
	debug_bounds_mesh.position = aabb.position + aabb.size * 0.5

func _apply_wireframe_mode() -> void:
	if prop_anchor == null:
		return

	var mesh_instances = prop_anchor.find_children("*", "MeshInstance3D", true, false)
	for mi in mesh_instances:
		if mi.material_override != null and mi.material_override is StandardMaterial3D:
			(mi.material_override as StandardMaterial3D).wireframe = _is_wireframe
		elif mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var mat = mi.mesh.surface_get_material(s)
				if mat != null and mat is StandardMaterial3D:
					(mat as StandardMaterial3D).wireframe = _is_wireframe

func _setup_controls() -> void:
	if ui_rotate_check != null:
		ui_rotate_check.toggled.connect(func(val: bool): _auto_rotate = val)
	if ui_wireframe_check != null:
		ui_wireframe_check.toggled.connect(func(val: bool):
			_is_wireframe = val
			_apply_wireframe_mode()
		)
	if ui_bounds_check != null:
		ui_bounds_check.toggled.connect(func(val: bool):
			_show_bounds = val
			var metrics = _MetricsScript.calculate_node_metrics(prop_anchor)
			_update_debug_bounds(metrics.bounds)
		)
	if ui_seed_spin != null:
		ui_seed_spin.value = _current_seed
		ui_seed_spin.value_changed.connect(func(val: float):
			_current_seed = int(val)
			_regenerate_active_preview()
		)
