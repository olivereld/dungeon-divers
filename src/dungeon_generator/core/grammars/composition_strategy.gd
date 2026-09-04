class_name CompositionStrategy
extends RefCounted

## Estrategia de Composición Espacial Global (Global Composition-Guided Room Placement).
## Consume la composición espacial global (SpatialComposition) derivada de MissionGraph + SpatialIntent
## para guiar la colocación física de habitaciones mediante evaluación multivariada no mutante.
##
## Principios Arquitectónicos:
## - Guiado global: Utiliza SpatialComposition.get_anchor_target(room_id) como target espacial primario.
## - Sin cálculos locales duplicados: Elimina offsets rígidos locales y proyecciones independientes.
## - Restricciones duras: Límites de bounds, separación mínima entre salas, min_mission_edge_distance y separación START/BOSS.
## - max_mission_edge_distance NO es hard constraint (se maneja por puntuación suave).
## - No muta RoomData, MissionGraph ni CellGrid.
## - Produce un RoomPlacementPlan inmutable y sellado.

const RoomPlacementPlan = preload("res://src/dungeon_generator/core/data/room_placement_plan.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")
const SpaceGrammarConfig = preload("res://src/dungeon_generator/config/space_grammar_config.gd")
const SpatialIntent = preload("res://src/dungeon_generator/core/data/spatial_intent.gd")
const SpatialIntentResult = preload("res://src/dungeon_generator/core/data/spatial_intent_result.gd")
const SpatialIntentBuilder = preload("res://src/dungeon_generator/core/grammars/spatial_intent_builder.gd")
const SpatialComposition = preload("res://src/dungeon_generator/core/data/spatial_composition.gd")
const SpatialCompositionBuilder = preload("res://src/dungeon_generator/core/grammars/spatial_composition_builder.gd")

const REGION_START: StringName = &"region_start"
const REGION_EARLY: StringName = &"region_early"
const REGION_MID: StringName = &"region_mid"
const REGION_LATE: StringName = &"region_late"
const REGION_BOSS: StringName = &"region_boss"
const REGION_BRANCH: StringName = &"region_branch"
const REGION_OPTIONAL: StringName = &"region_optional"
const REGION_MAIN_PATH: StringName = &"region_main_path"

const _DIRECTIONS: Array[Vector2] = [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071),
	Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071)
]

var _rng: RandomNumberGenerator

func _init(rng: RandomNumberGenerator = null) -> void:
	if rng != null:
		_rng = rng
	else:
		_rng = RandomNumberGenerator.new()

static func extract_strengths(config) -> Dictionary:
	var candidate_count: int = 24
	if config != null:
		if "composition_candidate_count" in config and config.composition_candidate_count > 0:
			candidate_count = config.composition_candidate_count
		elif "candidate_count" in config and config.candidate_count > 0:
			candidate_count = config.candidate_count
		elif "mission_aware_candidate_count" in config and config.mission_aware_candidate_count > 0:
			candidate_count = config.mission_aware_candidate_count

	var progression_strength: float = 1.0
	var density_strength: float = 0.5
	var anchor_distance_strength: float = 1.0
	var neighbor_coherence_strength: float = 1.0
	var main_path_alignment_strength: float = 1.0
	var branch_lateral_strength: float = 0.75
	var terminal_spacing_strength: float = 0.75

	if config != null:
		if "progression_strength" in config:
			progression_strength = float(config.progression_strength)
		if "density_strength" in config:
			density_strength = float(config.density_strength)
		if "anchor_distance_strength" in config:
			anchor_distance_strength = float(config.anchor_distance_strength)
		elif "anchor_strength" in config:
			anchor_distance_strength = float(config.anchor_strength)
		if "neighbor_coherence_strength" in config:
			neighbor_coherence_strength = float(config.neighbor_coherence_strength)
		elif "neighbor_strength" in config:
			neighbor_coherence_strength = float(config.neighbor_strength)
		if "main_path_alignment_strength" in config:
			main_path_alignment_strength = float(config.main_path_alignment_strength)
		elif "main_path_strength" in config:
			main_path_alignment_strength = float(config.main_path_strength)
		if "branch_lateral_strength" in config:
			branch_lateral_strength = float(config.branch_lateral_strength)
		elif "branch_strength" in config:
			branch_lateral_strength = float(config.branch_strength)
		if "terminal_spacing_strength" in config:
			terminal_spacing_strength = float(config.terminal_spacing_strength)
		elif "terminal_strength" in config:
			terminal_spacing_strength = float(config.terminal_strength)

	return {
		"candidate_count": candidate_count,
		"progression": progression_strength,
		"anchor_distance": anchor_distance_strength,
		"anchor": anchor_distance_strength,
		"neighbor_coherence": neighbor_coherence_strength,
		"neighbor": neighbor_coherence_strength,
		"main_path_alignment": main_path_alignment_strength,
		"main_path": main_path_alignment_strength,
		"branch_lateral": branch_lateral_strength,
		"branch": branch_lateral_strength,
		"density": density_strength,
		"terminal_spacing": terminal_spacing_strength,
		"terminal": terminal_spacing_strength
	}

## Genera un plan de colocación espacial sellado (RoomPlacementPlan) guiado por SpatialComposition.
## Acepta SpatialComposition directamente, o lo construye desde MissionGraph / SpatialIntent si no se provee.
func create_placement_plan(
	rooms: Array[RoomData],
	mission_graph_or_composition = null,
	bounds: Rect2i = Rect2i(),
	config: SpaceGrammarConfig = null,
	spatial_intent_or_composition = null,
	spatial_composition: SpatialComposition = null
) -> RoomPlacementPlan:
	var plan := RoomPlacementPlan.new()
	if rooms.is_empty():
		plan.seal()
		return plan

	# 1. Resolver MissionGraph y SpatialComposition desde los argumentos polimórficos
	var mission_graph: DungeonGraph = null
	var comp: SpatialComposition = null

	if mission_graph_or_composition is SpatialComposition:
		comp = mission_graph_or_composition
	elif mission_graph_or_composition is DungeonGraph:
		mission_graph = mission_graph_or_composition

	if spatial_composition != null:
		comp = spatial_composition
	elif comp == null and spatial_intent_or_composition is SpatialComposition:
		comp = spatial_intent_or_composition

	# Si aún no tenemos SpatialComposition, construirla canónicamente
	if comp == null:
		var comp_builder := SpatialCompositionBuilder.new(_rng)
		comp = comp_builder.build(mission_graph, spatial_intent_or_composition, config, bounds)

	# 2. Extraer parámetros de configuración
	var preferred_distance: float = config.mission_aware_preferred_distance if config != null else 12.0
	var distance_jitter: float = config.mission_aware_distance_jitter if config != null else 4.0
	var min_separation: int = config.min_room_separation if config != null else 2
	var min_edge_dist: float = config.min_mission_edge_distance if config != null else 6.0

	var max_dim: float = minf(float(bounds.size.x), float(bounds.size.y))
	if max_dim > 0 and max_dim <= 36.0:
		preferred_distance = minf(preferred_distance, max_dim * 0.35)
		min_separation = mini(min_separation, 1)
		min_edge_dist = minf(min_edge_dist, max_dim * 0.22)

	var strengths: Dictionary = extract_strengths(config)
	var candidate_count: int = strengths.get("candidate_count", 24)

	# 3. Indexar salas por ID y por mission_node_id
	var room_by_id: Dictionary = {}
	var room_by_node_id: Dictionary = {}
	for r in rooms:
		if r != null:
			room_by_id[r.id] = r
			if r.mission_node_id >= 0:
				room_by_node_id[r.mission_node_id] = r

	# 4. Orden de procesamiento guiado por SpatialComposition (Main Path primero, luego Branches)
	var ordered_rooms: Array[RoomData] = []
	var visited_rooms: Dictionary = {}

	# 4a. Main Path en orden estricto de progresión
	var main_path_ids: Array[int] = comp.main_path_node_ids
	for nid in main_path_ids:
		var r: RoomData = null
		if room_by_node_id.has(nid):
			r = room_by_node_id[nid]
		elif room_by_id.has(nid):
			r = room_by_id[nid]
		if r != null and not visited_rooms.has(r.id):
			visited_rooms[r.id] = true
			ordered_rooms.append(r)

	# 4b. Ramas secundarias (Side branches) ordenadas por dependencia topológica
	var all_comp_nodes: Array[int] = comp.get_all_node_ids()
	for nid in all_comp_nodes:
		if comp.is_main_path(nid):
			continue
		var r: RoomData = null
		if room_by_node_id.has(nid):
			r = room_by_node_id[nid]
		elif room_by_id.has(nid):
			r = room_by_id[nid]
		if r != null and not visited_rooms.has(r.id):
			visited_rooms[r.id] = true
			ordered_rooms.append(r)

	# 4c. Salas restantes no mapeadas
	for r in rooms:
		if r != null and not visited_rooms.has(r.id):
			visited_rooms[r.id] = true
			ordered_rooms.append(r)

	# 5. Colocación de Salas
	var placed_rects: Dictionary = {} # room_id -> Rect2i
	var start_center := Vector2.ZERO
	var prev_main_center := Vector2.ZERO

	for room in ordered_rooms:
		var size: Vector2i = room.rect.size
		var node_id: int = _resolve_node_id(comp, room)
		var is_main: bool = comp.is_main_path(node_id)
		var region: StringName = comp.get_region(node_id)
		var priority: int = _determine_priority(room, region)

		var global_target: Vector2 = _get_room_target(comp, room)
		var best_pos: Vector2i = Vector2i.MIN

		var is_start_room: bool = (
			room.room_type == RoomData.RoomType.START
			or room.room_type == &"start"
			or region == REGION_START
			or (placed_rects.is_empty() and is_main)
		)

		if is_start_room:
			best_pos = _place_start_room(size, bounds, global_target, comp.progression_direction)
			if best_pos != Vector2i.MIN:
				start_center = Vector2(best_pos) + Vector2(size) / 2.0
				prev_main_center = start_center
		else:
			best_pos = _find_best_position(
				room,
				size,
				node_id,
				comp,
				mission_graph,
				bounds,
				placed_rects,
				room_by_id,
				room_by_node_id,
				start_center,
				prev_main_center,
				preferred_distance,
				candidate_count,
				distance_jitter,
				min_separation,
				min_edge_dist,
				strengths.get("progression", 1.0),
				strengths.get("density", 0.5),
				strengths
			)
			if best_pos != Vector2i.MIN and is_main:
				prev_main_center = Vector2(best_pos) + Vector2(size) / 2.0

		if best_pos != Vector2i.MIN:
			placed_rects[room.id] = Rect2i(best_pos, size)
			plan.add_entry(room.id, best_pos, region, priority)
		else:
			push_warning("[CompositionStrategy] Failed to find valid placement for room %d (type=%s, node=%d). Refusing invalid placement." % [
				room.id, str(room.room_type), node_id
			])

	plan.seal()
	return plan

## Coloca la sala START en torno a su target global dentro de los límites estrictos.
func _place_start_room(size: Vector2i, bounds: Rect2i, target_pos: Vector2, progression_dir: Vector2) -> Vector2i:
	if size.x > bounds.size.x or size.y > bounds.size.y:
		return Vector2i.MIN

	var max_x: int = bounds.end.x - size.x
	var max_y: int = bounds.end.y - size.y
	if max_x < bounds.position.x or max_y < bounds.position.y:
		return Vector2i.MIN

	var base_center := target_pos
	if base_center == Vector2.ZERO:
		base_center = Vector2(bounds.position + bounds.size / 2) - progression_dir * 8.0

	for attempt in range(16):
		var ox: int = 0
		var oy: int = 0
		if attempt > 0:
			var damp: float = 1.0 - float(attempt) / 16.0
			ox = _rng.randi_range(-4, 4) + int(progression_dir.x * -2.0 * damp)
			oy = _rng.randi_range(-4, 4) + int(progression_dir.y * -2.0 * damp)

		var cand := Vector2i(int(base_center.x - size.x / 2.0) + ox, int(base_center.y - size.y / 2.0) + oy)
		if bounds.encloses(Rect2i(cand, size)):
			return cand

	var fallback_center := Vector2i(int(base_center.x - size.x / 2.0), int(base_center.y - size.y / 2.0))
	fallback_center.x = clampi(fallback_center.x, bounds.position.x, bounds.end.x - size.x)
	fallback_center.y = clampi(fallback_center.y, bounds.position.y, bounds.end.y - size.y)
	if bounds.encloses(Rect2i(fallback_center, size)):
		return fallback_center

	return Vector2i.MIN

## Encuentra la mejor posición para una sala evaluando candidatos contra el target global de SpatialComposition.
func _find_best_position(
	room: RoomData,
	size: Vector2i,
	node_id: int,
	comp: SpatialComposition,
	mission_graph: DungeonGraph,
	bounds: Rect2i,
	placed_rects: Dictionary,
	room_by_id: Dictionary,
	room_by_node_id: Dictionary,
	start_center: Vector2,
	prev_main_center: Vector2,
	preferred_distance: float,
	candidate_count: int,
	distance_jitter: float,
	min_separation: int,
	min_edge_dist: float,
	progression_strength: float = 1.0,
	density_strength: float = 0.5,
	strengths: Dictionary = {}
) -> Vector2i:
	var global_target: Vector2 = _get_room_target(comp, room)
	var is_main: bool = comp.is_main_path(node_id)
	var prog_dir: Vector2 = comp.progression_direction
	var perp_dir := Vector2(-prog_dir.y, prog_dir.x)

	# 1. Recopilar vecinos de misión ya colocados
	var neighbor_rects: Array[Rect2i] = []
	if mission_graph != null and node_id >= 0:
		var neighbor_ids: Array[int] = mission_graph.get_neighbors(node_id)
		for other_id in placed_rects:
			var other_room: RoomData = room_by_id.get(other_id)
			if other_room != null:
				var other_node: int = _resolve_node_id(comp, other_room)
				if other_node in neighbor_ids:
					neighbor_rects.append(placed_rects[other_id])

	# 2. Determinar ancla espacial para generación de candidatos
	var anchor: Vector2
	var main_anchor_center := Vector2.ZERO
	if not is_main:
		var branch_anchor_nid: int = comp.get_branch_anchor(node_id)
		if branch_anchor_nid >= 0:
			var anchor_room: RoomData = null
			if room_by_node_id.has(branch_anchor_nid):
				anchor_room = room_by_node_id[branch_anchor_nid]
			elif room_by_id.has(branch_anchor_nid):
				anchor_room = room_by_id[branch_anchor_nid]
			if anchor_room != null and placed_rects.has(anchor_room.id):
				var ar: Rect2i = placed_rects[anchor_room.id]
				main_anchor_center = Vector2(ar.position) + Vector2(ar.size) / 2.0

	if not neighbor_rects.is_empty():
		var sum := Vector2.ZERO
		for nr in neighbor_rects:
			sum += Vector2(nr.position) + Vector2(nr.size) / 2.0
		anchor = sum / float(neighbor_rects.size())
	elif not is_main and main_anchor_center != Vector2.ZERO:
		anchor = main_anchor_center
	elif is_main and prev_main_center != Vector2.ZERO:
		anchor = prev_main_center
	elif global_target != Vector2.ZERO:
		anchor = global_target
	else:
		var sum := Vector2.ZERO
		for pr in placed_rects.values():
			sum += Vector2((pr as Rect2i).position) + Vector2((pr as Rect2i).size) / 2.0
		anchor = sum / float(maxi(1, placed_rects.size()))

	# Dirección orientada hacia el target global
	var to_global: Vector2 = (global_target - anchor).normalized() if global_target != Vector2.ZERO else prog_dir
	if to_global.is_zero_approx():
		to_global = prog_dir if not prog_dir.is_zero_approx() else Vector2(1, 0)

	var best_pos: Vector2i = Vector2i.MIN
	var best_score: float = -INF

	# 3. Búsqueda primaria de candidatos
	var attempts: int = candidate_count * 2
	for i in range(attempts):
		var target_center: Vector2

		if global_target != Vector2.ZERO and (i % 2 == 0 or i < 4):
			# Candidato explorando directamente las proximidades de SpatialComposition.get_anchor_target
			var jitter_radius: float = _rng.randf_range(0.0, maxf(distance_jitter, 3.0))
			var jitter_angle: float = _rng.randf() * TAU
			target_center = global_target + Vector2(cos(jitter_angle), sin(jitter_angle)) * jitter_radius
		else:
			var dir: Vector2
			var roll: float = _rng.randf()

			if not is_main and roll < 0.5:
				# Para ramas secundarias: sesgo lateral para ramificarse perpendicularmente del camino principal
				var lat_sign: float = -1.0 if _rng.randf() < 0.5 else 1.0
				var lat_jitter: float = _rng.randf_range(-0.4, 0.4)
				dir = (perp_dir * lat_sign + prog_dir * 0.3).rotated(lat_jitter).normalized()
			elif roll < 0.45:
				# Sesgo hacia el target global de progresión
				var angle_jitter: float = _rng.randf_range(-0.5, 0.5)
				dir = to_global.rotated(angle_jitter).normalized()
			else:
				# Exploración omnidireccional
				var dir_idx: int = _rng.randi_range(0, _DIRECTIONS.size() - 1)
				var angle_jitter: float = _rng.randf_range(-0.3, 0.3)
				dir = _DIRECTIONS[dir_idx].rotated(angle_jitter).normalized()

			var dist: float = preferred_distance + _rng.randf_range(-distance_jitter, distance_jitter)
			target_center = anchor + dir * dist

		var cand_pos := Vector2i(int(target_center.x - size.x / 2.0), int(target_center.y - size.y / 2.0))

		# RESTRICCIÓN DURA: Descarte inmediato si no satisface todas las condiciones
		if not _passes_hard_constraints(cand_pos, size, bounds, placed_rects, neighbor_rects, min_separation, min_edge_dist, start_center, room.room_type, comp, node_id):
			continue

		# SOFT SCORING: Puntuación guiada por SpatialComposition
		var score: float = _score_candidate(
			cand_pos,
			size,
			bounds,
			room,
			node_id,
			is_main,
			comp,
			global_target,
			anchor,
			main_anchor_center,
			start_center,
			prev_main_center,
			neighbor_rects,
			placed_rects,
			room_by_id,
			room_by_node_id,
			preferred_distance,
			progression_strength,
			density_strength,
			strengths
		)

		if score > best_score:
			best_score = score
			best_pos = cand_pos

	if best_pos != Vector2i.MIN:
		return best_pos

	# 4. Búsqueda expandida determinista (filtrada estrictamente por restricciones duras)
	return _expanded_valid_candidate_search(
		room,
		size,
		node_id,
		is_main,
		comp,
		global_target,
		anchor,
		main_anchor_center,
		bounds,
		placed_rects,
		neighbor_rects,
		room_by_id,
		room_by_node_id,
		min_separation,
		min_edge_dist,
		start_center,
		prev_main_center,
		preferred_distance,
		progression_strength,
		density_strength,
		strengths
	)

## Evaluación de Restricciones Duras (Hard Constraints).
## Rechazo inmediato si viola contención en bounds, separación mínima, min_mission_edge_distance o distancia START/BOSS.
## max_mission_edge_distance NO es hard constraint.
func _passes_hard_constraints(
	pos: Vector2i,
	size: Vector2i,
	bounds: Rect2i,
	placed_rects: Dictionary,
	neighbor_rects: Array[Rect2i],
	min_separation: int,
	min_edge_dist: float,
	start_center: Vector2,
	room_type: Variant,
	comp: SpatialComposition,
	node_id: int
) -> bool:
	var cand_rect := Rect2i(pos, size)
	var cand_center := Vector2(pos) + Vector2(size) / 2.0

	# 1. Contención estricta dentro de los límites
	if not bounds.encloses(cand_rect):
		return false

	# 2. Separación mínima contra TODAS las salas colocadas (sin colisiones con margen)
	for pr in placed_rects.values():
		var target_rect: Rect2i = (pr as Rect2i).grow(min_separation) if min_separation > 0 else (pr as Rect2i)
		if cand_rect.intersects(target_rect):
			return false

	# 3. Restricción dura de distancia mínima para vecinos de misión obligatorios
	if not neighbor_rects.is_empty():
		for nr in neighbor_rects:
			var n_center := Vector2(nr.position) + Vector2(nr.size) / 2.0
			var d: float = cand_center.distance_to(n_center)
			if d < min_edge_dist:
				return false

	# 4. Regla de progresión para el BOSS: debe estar separado del START
	var is_boss: bool = (
		room_type == RoomData.RoomType.BOSS
		or room_type == &"boss"
		or room_type == RoomData.RoomType.GOAL
		or room_type == &"goal"
		or comp.get_region(node_id) == SpatialComposition.REGION_BOSS
	)
	if is_boss and start_center != Vector2.ZERO:
		if cand_center.distance_to(start_center) < (min_edge_dist * 1.8):
			return false

	return true

# Constantes de Ponderación (Weights) para Soft Scoring
const WEIGHT_PROGRESSION: float = 1.0
const WEIGHT_ANCHOR_DISTANCE: float = 1.2
const WEIGHT_NEIGHBOR_COHERENCE: float = 1.0
const WEIGHT_MAIN_PATH_ALIGNMENT: float = 1.1
const WEIGHT_BRANCH_LATERAL: float = 1.0
const WEIGHT_DENSITY: float = 0.8
const WEIGHT_TERMINAL_SPACING: float = 1.3

## Evaluación de Puntuación Suave (Soft Scoring).
## Evalúa calidad espacial calculando 7 términos independientes con pesos para asegurar coherencia global
## sin incurrir en búsquedas exhaustivas ni recocido simulado.
func _score_candidate(
	cand_pos: Vector2i,
	size: Vector2i,
	bounds: Rect2i,
	room: RoomData,
	node_id: int,
	is_main: bool,
	comp: SpatialComposition,
	global_target: Vector2,
	anchor: Vector2,
	main_anchor_center: Vector2,
	start_center: Vector2,
	prev_main_center: Vector2,
	neighbor_rects: Array[Rect2i],
	placed_rects: Dictionary,
	room_by_id: Dictionary,
	room_by_node_id: Dictionary,
	preferred_distance: float,
	progression_strength: float = 1.0,
	density_strength: float = 0.5,
	strengths: Dictionary = {}
) -> float:
	var cand_center := Vector2(cand_pos) + Vector2(size) / 2.0
	var prog_dir: Vector2 = comp.progression_direction
	var perp_dir := Vector2(-prog_dir.y, prog_dir.x)
	var node_density: float = comp.get_density(node_id)
	var factor: float = comp.get_main_path_factor(node_id) if is_main else comp.get_branch_factor(node_id)
	var has_global_target: bool = (global_target != Vector2.ZERO)

	# 1. progression_score: Alineación direccional con progression_direction y factor
	var progression_score: float = _calculate_progression_score(
		cand_center, start_center, prog_dir, factor, is_main
	)

	# 2. anchor_distance_score: Penalización de distancia respecto al target global
	var anchor_distance_score: float = _calculate_anchor_distance_score(
		cand_center, global_target
	)

	# 3. neighbor_coherence_score: Coherencia de distancia a vecinos de MissionGraph
	var neighbor_coherence_score: float = _calculate_neighbor_coherence_score(
		cand_center, neighbor_rects, anchor, preferred_distance, has_global_target
	)

	# 4. main_path_alignment_score: Continuidad espacial y monotonía de nodos consecutivos de main path
	var main_path_alignment_score: float = _calculate_main_path_alignment_score(
		cand_center, prev_main_center, start_center, prog_dir, is_main, preferred_distance, comp, node_id, main_anchor_center, placed_rects, room_by_id, room_by_node_id
	)

	# 5. branch_lateral_score: Desplazamiento lateral desde el eje de progresión principal
	var branch_lateral_score: float = _calculate_branch_lateral_score(
		cand_center, main_anchor_center, start_center, prog_dir, perp_dir, is_main, preferred_distance
	)

	# 6. density_score: Modulación espacial basada en density_by_node
	var density_score: float = _calculate_density_score(
		cand_center, placed_rects, node_density, density_strength, preferred_distance, has_global_target
	)

	# 7. terminal_spacing_score: Separación de BOSS respecto a START, prevención de regresión y contención
	var terminal_spacing_score: float = _calculate_terminal_spacing_score(
		cand_center, room, node_id, comp, start_center, prev_main_center, prog_dir, global_target, preferred_distance, placed_rects, room_by_id
	)

	# Forma Global y Desempate Determinista
	var bounds_center := Vector2(bounds.position) + Vector2(bounds.size) / 2.0
	var bounds_shape_score: float = -cand_center.distance_to(bounds_center) * 0.05
	var jitter: float = _rng.randf() * 0.05

	# Suma ponderada con pesos configurables (o por defecto)
	var w_prog: float = strengths.get("progression", progression_strength * WEIGHT_PROGRESSION)
	var w_anchor: float = strengths.get("anchor_distance", WEIGHT_ANCHOR_DISTANCE)
	var w_neighbor: float = strengths.get("neighbor_coherence", WEIGHT_NEIGHBOR_COHERENCE)
	var w_main: float = strengths.get("main_path_alignment", WEIGHT_MAIN_PATH_ALIGNMENT)
	var w_branch: float = strengths.get("branch_lateral", WEIGHT_BRANCH_LATERAL)
	var w_density: float = strengths.get("density", density_strength * WEIGHT_DENSITY)
	var w_terminal: float = strengths.get("terminal_spacing", WEIGHT_TERMINAL_SPACING)

	var total_score: float = (
		(w_prog * progression_score)
		+ (w_anchor * anchor_distance_score)
		+ (w_neighbor * neighbor_coherence_score)
		+ (w_main * main_path_alignment_score)
		+ (w_branch * branch_lateral_score)
		+ (w_density * density_score)
		+ (w_terminal * terminal_spacing_score)
		+ bounds_shape_score
		+ jitter
	)

	return total_score

func _calculate_progression_score(
	cand_center: Vector2,
	start_center: Vector2,
	prog_dir: Vector2,
	factor: float,
	is_main: bool
) -> float:
	if start_center == Vector2.ZERO or prog_dir.is_zero_approx():
		return 0.0

	var from_start: Vector2 = cand_center - start_center
	if from_start.is_zero_approx():
		return 0.0

	var dir_dot: float = from_start.normalized().dot(prog_dir)
	if is_main:
		return dir_dot * 4.0 * maxf(factor, 0.15)
	return dir_dot * 2.5 * maxf(factor, 0.1)

func _calculate_anchor_distance_score(cand_center: Vector2, global_target: Vector2) -> float:
	if global_target == Vector2.ZERO:
		return 0.0
	var dist: float = cand_center.distance_to(global_target)
	return -dist * 1.5

func _calculate_neighbor_coherence_score(
	cand_center: Vector2,
	neighbor_rects: Array[Rect2i],
	anchor: Vector2,
	preferred_distance: float,
	has_global_target: bool
) -> float:
	var score: float = 0.0
	if not neighbor_rects.is_empty():
		for nr in neighbor_rects:
			var n_center := Vector2(nr.position) + Vector2(nr.size) / 2.0
			var d: float = cand_center.distance_to(n_center)
			score -= abs(d - preferred_distance)
			if d > preferred_distance * 1.8:
				score -= (d - preferred_distance * 1.8) * 1.2
	elif anchor != Vector2.ZERO and not has_global_target:
		var d: float = cand_center.distance_to(anchor)
		score -= abs(d - preferred_distance) * 0.5
	return score

func _calculate_main_path_alignment_score(
	cand_center: Vector2,
	prev_main_center: Vector2,
	start_center: Vector2,
	prog_dir: Vector2,
	is_main: bool,
	preferred_distance: float,
	comp: SpatialComposition,
	node_id: int,
	main_anchor_center: Vector2,
	placed_rects: Dictionary,
	room_by_id: Dictionary,
	room_by_node_id: Dictionary
) -> float:
	var score: float = 0.0

	if is_main:
		if prev_main_center != Vector2.ZERO:
			# Continuidad espacial con el nodo anterior del camino principal
			var d_prev: float = cand_center.distance_to(prev_main_center)
			score -= abs(d_prev - preferred_distance) * 0.75

			# Monotonía en la dirección de progresión
			if not prog_dir.is_zero_approx() and start_center != Vector2.ZERO:
				var cand_proj: float = (cand_center - start_center).dot(prog_dir)
				var prev_proj: float = (prev_main_center - start_center).dot(prog_dir)
				if cand_proj < prev_proj:
					score -= (prev_proj - cand_proj) * 3.5
				else:
					score += minf(cand_proj - prev_proj, preferred_distance) * 0.7
	else:
		# Ramas: Evitar apiñamiento en otros nodos del Main Path
		var branch_anchor_nid: int = comp.get_branch_anchor(node_id)
		for mp_nid in comp.main_path_node_ids:
			if mp_nid == branch_anchor_nid:
				continue
			var mp_room: RoomData = room_by_node_id.get(mp_nid, room_by_id.get(mp_nid, null))
			if mp_room != null and placed_rects.has(mp_room.id):
				var mp_c: Vector2 = Vector2(placed_rects[mp_room.id].position) + Vector2(placed_rects[mp_room.id].size) / 2.0
				var d_mp: float = cand_center.distance_to(mp_c)
				if d_mp < preferred_distance * 0.85:
					score -= (preferred_distance * 0.85 - d_mp) * 2.0

		# Evitar colocarse exactamente entre dos anclas consecutivas del Main Path
		if main_anchor_center != Vector2.ZERO and prev_main_center != Vector2.ZERO and main_anchor_center != prev_main_center:
			var seg_dir := (prev_main_center - main_anchor_center).normalized()
			var to_cand := cand_center - main_anchor_center
			var proj_len: float = to_cand.dot(seg_dir)
			var seg_len: float = main_anchor_center.distance_to(prev_main_center)
			if proj_len > 2.0 and proj_len < seg_len - 2.0:
				var dist_to_segment: float = (to_cand - seg_dir * proj_len).length()
				if dist_to_segment < preferred_distance * 0.6:
					score -= (preferred_distance * 0.6 - dist_to_segment) * 3.0

	return score

func _calculate_branch_lateral_score(
	cand_center: Vector2,
	main_anchor_center: Vector2,
	start_center: Vector2,
	prog_dir: Vector2,
	perp_dir: Vector2,
	is_main: bool,
	preferred_distance: float
) -> float:
	if not is_main:
		var ref_center := main_anchor_center if main_anchor_center != Vector2.ZERO else start_center
		if ref_center != Vector2.ZERO:
			# Proximidad coherente al ancla principal
			var d_anchor: float = cand_center.distance_to(ref_center)
			var score: float = -abs(d_anchor - preferred_distance) * 0.9

			# Desplazamiento lateral desde el eje de progresión
			var lateral_dist: float = abs((cand_center - ref_center).dot(perp_dir))
			score += minf(lateral_dist, preferred_distance) * 1.0

			# Penalizar colinealidad con el eje principal
			if lateral_dist < 3.0:
				score -= (3.0 - lateral_dist) * 2.0

			# Penalizar dominancia por desplazamiento desmedido
			if lateral_dist > preferred_distance * 2.5:
				score -= (lateral_dist - preferred_distance * 2.5) * 1.5

			return score
		return 0.0

	# En main path, penalizar desviaciones laterales excesivas fuera del corredor
	if start_center != Vector2.ZERO:
		var lat_drift: float = abs((cand_center - start_center).dot(perp_dir))
		if lat_drift > preferred_distance * 1.6:
			return -(lat_drift - preferred_distance * 1.6) * 0.5

	return 0.0

func _calculate_density_score(
	cand_center: Vector2,
	placed_rects: Dictionary,
	node_density: float,
	density_strength: float,
	preferred_distance: float,
	has_global_target: bool
) -> float:
	var min_dist_to_any: float = INF
	var close_rooms_count: int = 0
	var clustering_metric: float = 0.0

	for pr in placed_rects.values():
		var p_center := Vector2((pr as Rect2i).position) + Vector2((pr as Rect2i).size) / 2.0
		var d: float = cand_center.distance_to(p_center)
		min_dist_to_any = minf(min_dist_to_any, d)
		if d < 18.0:
			close_rooms_count += 1
		clustering_metric += 1.0 / maxf(d, 1.0)

	var breathing_score: float = min_dist_to_any * 0.35 if min_dist_to_any != INF else 0.0

	# Modulación basada en density_by_node
	var effective_density: float = node_density * density_strength
	var clustering_penalty: float = 0.0
	if node_density < 1.0:
		clustering_penalty = float(close_rooms_count) * 4.0 + clustering_metric * 3.0
	else:
		if close_rooms_count > 2:
			clustering_penalty = float(close_rooms_count - 2) * 5.0 * effective_density
		clustering_penalty += clustering_metric * 2.0 * effective_density

	# Penalización por distancia excesiva
	var max_allowed_dist: float = preferred_distance * 2.2
	if has_global_target:
		max_allowed_dist = maxf(max_allowed_dist, preferred_distance * 3.5)
	var dist_penalty: float = 0.0
	if min_dist_to_any != INF and min_dist_to_any > max_allowed_dist:
		dist_penalty = (min_dist_to_any - max_allowed_dist) * 1.5

	return breathing_score - clustering_penalty - dist_penalty

func _calculate_terminal_spacing_score(
	cand_center: Vector2,
	room: RoomData,
	node_id: int,
	comp: SpatialComposition,
	start_center: Vector2,
	prev_main_center: Vector2,
	prog_dir: Vector2,
	global_target: Vector2,
	preferred_distance: float,
	placed_rects: Dictionary,
	room_by_id: Dictionary
) -> float:
	var score: float = 0.0
	var is_terminal: bool = (
		room.room_type == RoomData.RoomType.BOSS
		or room.room_type == &"boss"
		or room.room_type == RoomData.RoomType.GOAL
		or room.room_type == &"goal"
		or comp.get_region(node_id) == SpatialComposition.REGION_BOSS
	)

	if is_terminal:
		# Penalizar BOSS cerca de START
		if start_center != Vector2.ZERO:
			var d_start: float = cand_center.distance_to(start_center)
			if d_start < preferred_distance * 2.5:
				score -= (preferred_distance * 2.5 - d_start) * 4.0

		# Penalizar BOSS regresivo respecto al camino principal
		if prev_main_center != Vector2.ZERO and not prog_dir.is_zero_approx() and start_center != Vector2.ZERO:
			var boss_proj: float = (cand_center - start_center).dot(prog_dir)
			var prev_proj: float = (prev_main_center - start_center).dot(prog_dir)
			if boss_proj < prev_proj:
				score -= (prev_proj - boss_proj) * 5.0
			else:
				score += minf(boss_proj - prev_proj, preferred_distance * 2.0) * 1.5

		# Penalizar terminal fuera del target de progresión
		if global_target != Vector2.ZERO:
			var d_target: float = cand_center.distance_to(global_target)
			if d_target > preferred_distance * 1.5:
				score -= (d_target - preferred_distance * 1.5) * 2.5
	else:
		# Salas no terminales: evitar acercarse indebidamente a START o a un BOSS ya colocado
		if not comp.is_main_path(node_id) and start_center != Vector2.ZERO:
			var branch_anchor_nid: int = comp.get_branch_anchor(node_id)
			if comp.main_path_node_ids.size() > 0 and branch_anchor_nid != comp.main_path_node_ids[0]:
				var d_start: float = cand_center.distance_to(start_center)
				if d_start < preferred_distance * 0.9:
					score -= (preferred_distance * 0.9 - d_start) * 2.5

		for placed_id in placed_rects:
			var other_r: RoomData = room_by_id.get(placed_id)
			if other_r != null and (other_r.room_type == RoomData.RoomType.BOSS or other_r.room_type == &"boss"):
				var boss_c := Vector2(placed_rects[placed_id].position) + Vector2(placed_rects[placed_id].size) / 2.0
				var d_boss: float = cand_center.distance_to(boss_c)
				if d_boss < preferred_distance * 1.2:
					score -= (preferred_distance * 1.2 - d_boss) * 3.0

	return score

## Búsqueda expandida determinista cuando la búsqueda primaria no encontró candidatos válidos.
func _expanded_valid_candidate_search(
	room: RoomData,
	size: Vector2i,
	node_id: int,
	is_main: bool,
	comp: SpatialComposition,
	global_target: Vector2,
	anchor: Vector2,
	main_anchor_center: Vector2,
	bounds: Rect2i,
	placed_rects: Dictionary,
	neighbor_rects: Array[Rect2i],
	room_by_id: Dictionary,
	room_by_node_id: Dictionary,
	min_separation: int,
	min_edge_dist: float,
	start_center: Vector2,
	prev_main_center: Vector2,
	preferred_distance: float,
	progression_strength: float = 1.0,
	density_strength: float = 0.5,
	strengths: Dictionary = {}
) -> Vector2i:
	var best_pos: Vector2i = Vector2i.MIN
	var best_score: float = -INF

	var search_origins: Array[Vector2] = [anchor]
	if global_target != Vector2.ZERO and global_target != anchor:
		search_origins.append(global_target)

	for origin in search_origins:
		var max_search_radius: int = maxi(int(preferred_distance * 2.8), 40)
		for radius in range(int(min_edge_dist), max_search_radius, 2):
			var steps: int = clampi(int(TAU * radius / 3.0), 8, 36)
			for s in range(steps):
				var angle: float = (float(s) / float(steps)) * TAU
				var cand_pos := Vector2i(
					int(origin.x + cos(angle) * radius - size.x / 2.0),
					int(origin.y + sin(angle) * radius - size.y / 2.0)
				)

				if not _passes_hard_constraints(cand_pos, size, bounds, placed_rects, neighbor_rects, min_separation, min_edge_dist, start_center, room.room_type, comp, node_id):
					continue

				var score: float = _score_candidate(
					cand_pos,
					size,
					bounds,
					room,
					node_id,
					is_main,
					comp,
					global_target,
					origin,
					main_anchor_center,
					start_center,
					prev_main_center,
					neighbor_rects,
					placed_rects,
					room_by_id,
					room_by_node_id,
					preferred_distance,
					progression_strength,
					density_strength,
					strengths
				)

				if score > best_score:
					best_score = score
					best_pos = cand_pos

			if best_pos != Vector2i.MIN:
				return best_pos

	# Fallback para rejillas pequeñas o alta densidad: relajar margen de separación (0)
	if min_separation > 0:
		for origin in search_origins:
			var max_search_radius: int = maxi(int(preferred_distance * 2.8), 40)
			for radius in range(maxi(2, int(min_edge_dist * 0.5)), max_search_radius, 2):
				var steps: int = clampi(int(TAU * radius / 3.0), 8, 36)
				for s in range(steps):
					var angle: float = (float(s) / float(steps)) * TAU
					var cand_pos := Vector2i(
						int(origin.x + cos(angle) * radius - size.x / 2.0),
						int(origin.y + sin(angle) * radius - size.y / 2.0)
					)
					if not _passes_hard_constraints(cand_pos, size, bounds, placed_rects, neighbor_rects, 0, min_edge_dist * 0.5, start_center, room.room_type, comp, node_id):
						continue
					return cand_pos

	# Fallback determinista final: escaneo de rejilla dentro de bounds buscando hueco libre o menor solapamiento
	var min_overlap_area: int = 999999
	var least_overlap_pos: Vector2i = Vector2i.MIN

	for y in range(bounds.position.y, bounds.end.y - size.y + 1):
		for x in range(bounds.position.x, bounds.end.x - size.x + 1):
			var cand_pos := Vector2i(x, y)
			var cand_rect := Rect2i(cand_pos, size)
			var overlap_area: int = 0
			for pr in placed_rects.values():
				if cand_rect.intersects(pr):
					var inter: Rect2i = cand_rect.intersection(pr)
					overlap_area += inter.size.x * inter.size.y
			if overlap_area == 0:
				return cand_pos
			if overlap_area < min_overlap_area:
				min_overlap_area = overlap_area
				least_overlap_pos = cand_pos

	if least_overlap_pos != Vector2i.MIN:
		return least_overlap_pos

	return Vector2i.MIN

func _get_room_target(comp: SpatialComposition, room: RoomData) -> Vector2:
	if comp == null:
		return Vector2.ZERO
	# 1. Consultar por room.id directamente
	var target: Vector2 = comp.get_anchor_target(room.id)
	if target != Vector2.ZERO:
		return target
	# 2. Consultar por mission_node_id si está asociado
	if room.mission_node_id >= 0:
		target = comp.get_anchor_target(room.mission_node_id)
		if target != Vector2.ZERO:
			return target
	return Vector2.ZERO

func _resolve_node_id(comp: SpatialComposition, room: RoomData) -> int:
	if comp != null:
		if comp.has_node(room.id):
			return room.id
		if room.mission_node_id >= 0 and comp.has_node(room.mission_node_id):
			return room.mission_node_id
	return room.mission_node_id if room.mission_node_id >= 0 else room.id

func _determine_priority(room: RoomData, region: StringName) -> int:
	match region:
		REGION_START:
			return 100
		REGION_BOSS:
			return 90
		REGION_LATE:
			return 60
		REGION_MID:
			return 50
		REGION_EARLY:
			return 40
		REGION_BRANCH, REGION_OPTIONAL:
			return 20
		_:
			return 10
