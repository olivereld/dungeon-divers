class_name SemanticArchetypeLabView
extends Control

## Semantic Archetype Laboratory (Herramienta de Inspección y Análisis Semántico).
## Visualiza y valida de forma interactiva la asignación determinista de propósitos de sala
## y la identidad arquitectónica de la mazmorra sin requerir renderizado 3D de escena.

const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _PresentationProfileResolverScript = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _DecorationCompositionResolverScript = preload("res://src/presentation/decoration/decoration_composition_resolver.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

# Pipeline & State
var _pipeline := _DungeonPipelineScript.new()
var _orchestrator := _SemanticOrchestratorScript.new()
var _profile_resolver := _PresentationProfileResolverScript.new()
var _dec_resolver := _DecorationPaletteResolverScript.new()
var _comp_resolver := _DecorationCompositionResolverScript.new()
var current_dungeon_result: DungeonResult = null
var current_semantic_result: DungeonSemanticResult = null
var current_seed: int = 1337
var current_archetype: int = 1 # MAUSOLEUM default

# UI Nodes
@onready var ui_archetype_opt: OptionButton = $Margin/VBox/TopBar/ArchetypeOpt
@onready var ui_seed_spin: SpinBox = $Margin/VBox/TopBar/SeedSpin
@onready var ui_gen_btn: Button = $Margin/VBox/TopBar/GenBtn
@onready var ui_rnd_btn: Button = $Margin/VBox/TopBar/RndBtn

@onready var ui_map_canvas: Control = $Margin/VBox/ContentHBox/LeftMapPanel/MapCanvas
@onready var ui_info_header: Label = $Margin/VBox/ContentHBox/RightInfoPanel/VBox/HeaderLabel
@onready var ui_dist_container: HFlowContainer = $Margin/VBox/ContentHBox/RightInfoPanel/VBox/DistributionFlow
@onready var ui_rooms_list: VBoxContainer = $Margin/VBox/ContentHBox/RightInfoPanel/VBox/Scroll/RoomsList
@onready var ui_trace_label: Label = $Margin/VBox/ContentHBox/RightInfoPanel/VBox/TraceLabel

func _ready() -> void:
	if ui_archetype_opt != null:
		_setup_ui()
		generate_dungeon_with_params(current_archetype, current_seed)

func _setup_ui() -> void:
	ui_archetype_opt.clear()
	ui_archetype_opt.add_item("GENERIC", _DungeonArchetypeScript.Type.GENERIC)
	ui_archetype_opt.add_item("MAUSOLEUM", _DungeonArchetypeScript.Type.MAUSOLEUM)
	ui_archetype_opt.add_item("FORTRESS", _DungeonArchetypeScript.Type.FORTRESS)
	ui_archetype_opt.add_item("TEMPLE", _DungeonArchetypeScript.Type.TEMPLE)
	ui_archetype_opt.add_item("MINE", _DungeonArchetypeScript.Type.MINE)
	ui_archetype_opt.select(current_archetype)

	ui_archetype_opt.item_selected.connect(_on_archetype_selected)
	ui_seed_spin.value = current_seed
	ui_seed_spin.value_changed.connect(_on_seed_changed)
	ui_gen_btn.pressed.connect(_on_generate_pressed)
	ui_rnd_btn.pressed.connect(_on_random_pressed)

	if ui_map_canvas != null:
		ui_map_canvas.draw.connect(_on_map_draw)

func generate_dungeon_with_params(archetype_idx: int, seed_val: int) -> void:
	current_archetype = archetype_idx
	current_seed = seed_val

	if ui_seed_spin != null and int(ui_seed_spin.value) != current_seed:
		ui_seed_spin.value = current_seed

	var cfg := _DungeonConfigScript.new()
	cfg.seed = current_seed
	cfg.use_fixed_seed = true
	cfg.dungeon_archetype = current_archetype

	current_dungeon_result = _pipeline.generate(cfg, 5, true)
	if current_dungeon_result != null and current_dungeon_result.grid != null:
		current_semantic_result = _orchestrator.generate_semantics(current_dungeon_result, cfg)
	else:
		current_semantic_result = null

	_refresh_display()

func _refresh_display() -> void:
	if ui_map_canvas != null:
		ui_map_canvas.queue_redraw()

	if ui_info_header == null or current_semantic_result == null:
		return

	# Header Info
	var arch_name: String = current_semantic_result.dungeon_archetype_name
	var room_cnt: int = current_semantic_result.rooms.size()
	var is_valid_str: String = "VALID" if current_semantic_result.gameplay_valid else "INVALID"
	ui_info_header.text = "🏛️ Arquetipo: %s | Semilla: %d | Salas: %d | Estado: %s" % [
		arch_name, current_seed, room_cnt, is_valid_str
	]

	# Purpose Distribution
	for c in ui_dist_container.get_children():
		c.queue_free()

	var dist := current_semantic_result.get_purpose_distribution()
	for p_type in dist:
		var p_name: String = _RoomPurposeScript.to_name(int(p_type) as _RoomPurposeScript.Type)
		var p_count: int = int(dist[p_type])
		var badge := Label.new()
		badge.text = " [%s: %d] " % [p_name, p_count]
		badge.add_theme_color_override("font_color", _get_purpose_color(int(p_type)))
		ui_dist_container.add_child(badge)

	# Rooms List Table
	for c in ui_rooms_list.get_children():
		c.queue_free()

	var sorted_ids: Array = current_semantic_result.room_purposes.keys()
	sorted_ids.sort()

	for r_id in sorted_ids:
		var purpose_id: int = int(current_semantic_result.room_purposes[r_id])
		var p_name: String = current_semantic_result.get_room_purpose_name(r_id)
		var role: String = "EXPLORE"

		if r_id == current_semantic_result.start_room_id:
			role = "START"
		elif r_id == current_semantic_result.boss_room_id:
			role = "BOSS"
		else:
			for obj in current_semantic_result.objectives:
				if obj.room_id == r_id:
					role = "TREASURE" if obj.type == 0 else "COMBAT"
					break

		var row := VBoxContainer.new()
		var top_line := HBoxContainer.new()

		var lbl_id := Label.new()
		lbl_id.custom_minimum_size.x = 65
		lbl_id.text = "Sala #%d" % r_id

		var lbl_role := Label.new()
		lbl_role.custom_minimum_size.x = 90
		lbl_role.text = "[%s]" % role
		lbl_role.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3) if role == "START" or role == "BOSS" else Color(0.75, 0.75, 0.75))

		var lbl_purpose := Label.new()
		lbl_purpose.text = "→ %s" % p_name
		lbl_purpose.add_theme_color_override("font_color", _get_purpose_color(purpose_id))

		top_line.add_child(lbl_id)
		top_line.add_child(lbl_role)
		top_line.add_child(lbl_purpose)

		# Resolver perfil arquitectónico y paleta de decoración
		var arch_prof = _profile_resolver.resolve(current_semantic_result.dungeon_archetype, purpose_id)
		var dec_palette = _dec_resolver.resolve_palette(current_semantic_result.dungeon_archetype, purpose_id, arch_prof)

		# Construir r_geom para resolver la composición
		var r_geom = _PresentationRoomGeometryScript.new()
		r_geom.room_id = r_id
		for r_data in current_semantic_result.rooms:
			if r_data.id == r_id:
				r_geom.bounds = r_data.rect
				for x in range(r_data.rect.position.x, r_data.rect.end.x):
					for y in range(r_data.rect.position.y, r_data.rect.end.y):
						if current_semantic_result.grid != null and current_semantic_result.grid.get_cell(Vector2i(x, y)) == 1:
							r_geom.floor_cells.append(Vector2i(x, y))
				break

		for dp in current_semantic_result.door_pairs:
			if dp is Dictionary:
				r_geom.door_positions.append(dp.get("pos_a", Vector2i.ZERO))
				r_geom.door_positions.append(dp.get("pos_b", Vector2i.ZERO))
			elif dp != null:
				if dp.door_a != null:
					r_geom.door_positions.append(dp.door_a.position)
				if dp.door_b != null:
					r_geom.door_positions.append(dp.door_b.position)

		var r_ctx = _PresentationRoomContextScript.new()
		r_ctx.room_id = r_id
		r_ctx.purpose = purpose_id
		r_ctx.profile = arch_prof

		var comp = _comp_resolver.resolve_room_composition(r_ctx, dec_palette, r_geom, null, current_seed, 2.0)
		var focal_cnt: int = comp.get_focal_props().size()
		var support_cnt: int = comp.get_support_props().size()
		var ambient_cnt: int = comp.get_ambient_props().size()
		var occ_cnt: int = comp.get_occupied_cell_count()
		var rej_cnt: int = comp.rejected_placements

		var bot_line := Label.new()
		bot_line.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
		bot_line.text = "    🧱 %s | 🔲 %s | 🚪 %s | 👑 Focal: %d | 📦 Support: %d | 🪨 Ambient: %d | 📐 Ocup: %d | ⛔ Rej: %d" % [
			_ArchitecturalStyleScript.wall_to_name(arch_prof.wall_style),
			_ArchitecturalStyleScript.floor_to_name(arch_prof.floor_style),
			_ArchitecturalStyleScript.door_to_name(arch_prof.door_style),
			focal_cnt,
			support_cnt,
			ambient_cnt,
			occ_cnt,
			rej_cnt
		]

		row.add_child(top_line)
		row.add_child(bot_line)
		ui_rooms_list.add_child(row)

	if ui_trace_label != null:
		ui_trace_label.text = "Start Room: %d | Boss Room: %d | Camino Crítico: %s" % [
			current_semantic_result.start_room_id,
			current_semantic_result.boss_room_id,
			str(current_semantic_result.critical_path_rooms)
		]

func _on_map_draw() -> void:
	if current_semantic_result == null or current_dungeon_result == null or current_dungeon_result.grid == null:
		return

	var gw: float = float(current_dungeon_result.grid.width)
	var gh: float = float(current_dungeon_result.grid.height)
	var canvas_size: Vector2 = ui_map_canvas.size
	var scale_factor: float = minf((canvas_size.x - 40.0) / gw, (canvas_size.y - 40.0) / gh)
	var offset := Vector2(20.0, 20.0)

	# Dibujar corredores
	for cp in current_dungeon_result.corridor_paths:
		if cp != null and cp.carved_cells != null:
			for cell in cp.carved_cells:
				var c_rect := Rect2(offset + Vector2(cell.x, cell.y) * scale_factor, Vector2(scale_factor, scale_factor))
				ui_map_canvas.draw_rect(c_rect, Color(0.25, 0.25, 0.30, 0.6))

	# Dibujar salas
	for room in current_semantic_result.rooms:
		var r_rect := Rect2(
			offset + Vector2(room.rect.position.x, room.rect.position.y) * scale_factor,
			Vector2(room.rect.size.x, room.rect.size.y) * scale_factor
		)
		var purpose_id: int = current_semantic_result.get_room_purpose(room.id)
		var color := _get_purpose_color(purpose_id)

		ui_map_canvas.draw_rect(r_rect, Color(color.r, color.g, color.b, 0.35))
		ui_map_canvas.draw_rect(r_rect, color, false, 2.0)

		var center := r_rect.position + r_rect.size * 0.5
		var txt := "#%d\n%s" % [room.id, current_semantic_result.get_room_purpose_name(room.id)]
		ui_map_canvas.draw_string(ThemeDB.fallback_font, center - Vector2(25, 5), str(room.id), HORIZONTAL_ALIGNMENT_CENTER, 50, 14, Color.WHITE)

func _get_purpose_color(p: int) -> Color:
	match p:
		_RoomPurposeScript.Type.ENTRANCE: return Color(0.3, 0.8, 0.4) # Verde
		_RoomPurposeScript.Type.THRONE_ROOM, _RoomPurposeScript.Type.ROYAL_TOMB, _RoomPurposeScript.Type.SANCTUM, _RoomPurposeScript.Type.FORGE:
			return Color(0.95, 0.3, 0.3) # Rojo / Jefe
		_RoomPurposeScript.Type.ARMORY, _RoomPurposeScript.Type.GUARD_ROOM, _RoomPurposeScript.Type.CRYPT, _RoomPurposeScript.Type.EXCAVATION:
			return Color(0.9, 0.6, 0.2) # Naranja / Combate
		_RoomPurposeScript.Type.TOMB, _RoomPurposeScript.Type.STORAGE, _RoomPurposeScript.Type.LIBRARY, _RoomPurposeScript.Type.MINE_STORAGE:
			return Color(0.3, 0.7, 0.95) # Azul / Tesoro
		_RoomPurposeScript.Type.SHRINE, _RoomPurposeScript.Type.ALTAR_ROOM, _RoomPurposeScript.Type.SACRISTY, _RoomPurposeScript.Type.MEDITATION_ROOM:
			return Color(0.8, 0.4, 0.9) # Púrpura / Sagrado
		_: return Color(0.7, 0.7, 0.75) # Gris / Neutro

func _on_archetype_selected(idx: int) -> void:
	var arch_id: int = ui_archetype_opt.get_item_id(idx)
	var s_val: int = int(ui_seed_spin.value)
	generate_dungeon_with_params(arch_id, s_val)

func _on_seed_changed(val: float) -> void:
	current_seed = int(val)

func _on_generate_pressed() -> void:
	var arch_id: int = ui_archetype_opt.get_selected_id()
	var s_val: int = int(ui_seed_spin.value)
	generate_dungeon_with_params(arch_id, s_val)

func _on_random_pressed() -> void:
	var r_seed: int = randi() % 999999 + 1
	var arch_id: int = ui_archetype_opt.get_selected_id()
	generate_dungeon_with_params(arch_id, r_seed)
