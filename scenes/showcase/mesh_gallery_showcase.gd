class_name MeshGalleryShowcase
extends Node3D

## Mesh Generation Lab (Showcase & Geometry Inspection Studio).
## Escena de depuración y análisis para examinar de forma aislada e interactiva
## los modelos 3D y clusters procedurales generados por el motor del Dungeon.
## Soporta scroll vertical en la lista izquierda y selector de variantes a la derecha.

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

@onready var ui_variant_section: VBoxContainer = $UI/PanelContainer/Margin/HBox/InfoPanel/VariantSection
@onready var ui_variant_dropdown: OptionButton = $UI/PanelContainer/Margin/HBox/InfoPanel/VariantSection/VariantDropdown

@onready var ui_rotate_check: CheckBox = $UI/PanelContainer/Margin/HBox/InfoPanel/Controls/RotateCheck
@onready var ui_wireframe_check: CheckBox = $UI/PanelContainer/Margin/HBox/InfoPanel/Controls/WireframeCheck
@onready var ui_bounds_check: CheckBox = $UI/PanelContainer/Margin/HBox/InfoPanel/Controls/BoundsCheck
@onready var ui_seed_spin: SpinBox = $UI/PanelContainer/Margin/HBox/InfoPanel/Controls/SeedHBox/SeedSpin
@onready var ui_clusters_container: VBoxContainer = $UI/PanelContainer/Margin/HBox/InfoPanel/ClusterSection/ClusterList
@onready var ui_clusters_header: Label = $UI/PanelContainer/Margin/HBox/InfoPanel/ClusterSection/ClusterHeader

@onready var ui_export_button: Button = $UI/PanelContainer/Margin/HBox/InfoPanel/ExportSection/ExportButtonsHBox/ExportButton
@onready var ui_open_folder_button: Button = $UI/PanelContainer/Margin/HBox/InfoPanel/ExportSection/ExportButtonsHBox/OpenFolderButton
@onready var ui_export_status_label: Label = $UI/PanelContainer/Margin/HBox/InfoPanel/ExportSection/ExportStatusLabel

var _catalog: MeshGalleryCatalog = null

var _renderer: MeshGalleryRenderer = null
var _current_category_idx: int = 0
var _current_group_idx: int = 0
var _current_variant_idx: int = 0
var _current_groups: Array[Dictionary] = []
var _current_entry: MeshGalleryEntry = null
var _current_seed: int = 1337
var _auto_rotate: bool = true
var _rotation_speed: float = 0.8
var _is_wireframe: bool = false
var _show_bounds: bool = false
var _is_dragging: bool = false
var _mouse_drag_sensitivity: float = 0.008

func _ready() -> void:
	_catalog = _CatalogScript.new()
	_renderer = _RendererScript.new()

	_setup_controls()
	_build_category_buttons()
	_select_category(0)

func _process(delta: float) -> void:
	if _auto_rotate and not _is_dragging and prop_anchor != null:
		prop_anchor.rotation.y += _rotation_speed * delta

	# Rotación manual por teclado con Q / E
	if Input.is_key_pressed(KEY_Q) and prop_anchor != null:
		prop_anchor.rotation.y -= 2.0 * delta
	elif Input.is_key_pressed(KEY_E) and prop_anchor != null:
		prop_anchor.rotation.y += 2.0 * delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if camera_rig != null and camera_rig.has_method("zoom_in"):
				camera_rig.zoom_in(1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if camera_rig != null and camera_rig.has_method("zoom_out"):
				camera_rig.zoom_out(1.0)
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_is_dragging = event.pressed
	elif event is InputEventMouseMotion and _is_dragging:
		if prop_anchor != null:
			prop_anchor.rotation.y += event.relative.x * _mouse_drag_sensitivity

# ==============================================================================
# UI & NAVEGACIÓN JERÁRQUICA (CATEGORÍAS -> OBJETOS -> VARIANTES)
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
	var categories = _catalog.get_categories()
	if idx >= categories.size():
		return

	var cat_id: StringName = categories[idx].id
	_current_groups = _catalog.get_grouped_entries_for_category(cat_id)
	_build_group_buttons()
	_select_group(0)

func _build_group_buttons() -> void:
	for child in ui_item_list.get_children():
		child.queue_free()

	for i in range(_current_groups.size()):
		var g_dict: Dictionary = _current_groups[i]
		var v_count: int = (g_dict.variants as Array).size()
		var btn := Button.new()
		var badge: String = " (%d)" % v_count if v_count > 1 else ""
		btn.text = "• " + str(g_dict.group_name) + badge
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.clip_text = true
		btn.pressed.connect(_on_group_button_pressed.bind(i))
		ui_item_list.add_child(btn)

func _on_group_button_pressed(idx: int) -> void:
	_select_group(idx)

func _select_group(idx: int) -> void:
	_current_group_idx = idx
	if idx >= _current_groups.size():
		return

	var g_dict: Dictionary = _current_groups[idx]
	var variants: Array = g_dict.variants

	# Poblar dropdown de variantes
	_populate_variant_dropdown(variants)
	_select_variant(0)

func _populate_variant_dropdown(variants: Array) -> void:
	ui_variant_dropdown.clear()
	for i in range(variants.size()):
		var v_entry: MeshGalleryEntry = variants[i]
		ui_variant_dropdown.add_item("%d. %s" % [i + 1, v_entry.variant_name], i)

	ui_variant_dropdown.selected = 0
	# Si solo hay 1 variante, se muestra deshabilitado o con estilo discreto
	ui_variant_section.visible = (variants.size() > 0)

func _on_variant_dropdown_selected(idx: int) -> void:
	_select_variant(idx)

func _select_variant(idx: int) -> void:
	_current_variant_idx = idx
	if _current_group_idx >= _current_groups.size():
		return

	var g_dict: Dictionary = _current_groups[_current_group_idx]
	var variants: Array = g_dict.variants
	if idx >= variants.size():
		return

	_current_entry = variants[idx]

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
	var vp := get_viewport()
	if vp != null:
		vp.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME if _is_wireframe else Viewport.DEBUG_DRAW_DISABLED

func _setup_controls() -> void:
	if ui_variant_dropdown != null:
		ui_variant_dropdown.item_selected.connect(_on_variant_dropdown_selected)

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

	if ui_export_button != null:
		ui_export_button.pressed.connect(_on_export_glb_pressed)
	if ui_open_folder_button != null:
		ui_open_folder_button.pressed.connect(_on_open_folder_pressed)

# ==============================================================================
# EXPORTACIÓN GLB
# ==============================================================================

func _on_export_glb_pressed() -> void:
	export_current_model_to_glb()

func _on_open_folder_pressed() -> void:
	var export_dir = _get_export_directory()
	var global_dir = ProjectSettings.globalize_path(export_dir)
	DirAccess.make_dir_recursive_absolute(global_dir)
	OS.shell_open(global_dir)

func _get_export_directory() -> String:
	return "user://exports/glb"

func export_current_model_to_glb() -> String:
	if _current_entry == null or prop_anchor == null:
		_set_export_status("❌ No hay modelo seleccionado.", Color(1.0, 0.4, 0.4))
		return ""

	if prop_anchor.get_child_count() == 0:
		_set_export_status("❌ El ancla de previsualización está vacía.", Color(1.0, 0.4, 0.4))
		return ""

	var model_node = prop_anchor.get_child(0)
	if model_node == null:
		_set_export_status("❌ Error al obtener el modelo 3D.", Color(1.0, 0.4, 0.4))
		return ""

	var export_dir = _get_export_directory()
	var global_dir = ProjectSettings.globalize_path(export_dir)
	var dir_err = DirAccess.make_dir_recursive_absolute(global_dir)
	if dir_err != OK and not DirAccess.dir_exists_absolute(global_dir):
		_set_export_status("❌ Error al crear carpeta de exportación.", Color(1.0, 0.4, 0.4))
		return ""

	# Sanitizar nombre de archivo
	var safe_name = str(_current_entry.id).validate_node_name()
	var safe_var = str(_current_entry.variant_name).validate_node_name().replace(" ", "_").to_lower()
	var filename = "%s_%s_seed_%d.glb" % [safe_name, safe_var, _current_seed]
	var full_export_path = global_dir.path_join(filename)

	# Exportar mediante GLTFDocument
	var gltf_doc := GLTFDocument.new()
	var gltf_state := GLTFState.new()

	var append_err = gltf_doc.append_from_scene(model_node, gltf_state)
	if append_err != OK:
		_set_export_status("❌ Error al preparar GLTF (código %d)" % append_err, Color(1.0, 0.4, 0.4))
		return ""

	var write_err = gltf_doc.write_to_filesystem(gltf_state, full_export_path)
	if write_err != OK:
		_set_export_status("❌ Error al escribir archivo GLB (código %d)" % write_err, Color(1.0, 0.4, 0.4))
		return ""

	_set_export_status("✓ Guardado: %s" % filename, Color(0.4, 0.9, 0.5))
	print("[MeshGalleryShowcase] Modelo exportado exitosamente a: %s" % full_export_path)
	return full_export_path

func _set_export_status(msg: String, color: Color) -> void:
	if ui_export_status_label != null:
		ui_export_status_label.text = msg
		ui_export_status_label.set("theme_override_colors/font_color", color)
