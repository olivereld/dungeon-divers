class_name SpatialCompositionBuilder
extends RefCounted

## Construye una instancia inmutable y sellada de SpatialComposition
## integrando la información de MissionGraph (DungeonGraph), SpatialIntent (SpatialIntentResult),
## DungeonConfig (o SpaceGrammarConfig) y los límites espaciales (Rect2i bounds).
##
## Responsabilidades:
## 1. Determinar dirección global de progresión (configurada o RNG determinista).
## 2. Anclar el camino principal (START = 0.0, Terminal = 1.0, progresión monótona).
## 3. Asignar anclas principales y zonas para ramas secundarias (branches heredan main anchor).
## 4. Asignar densidades espaciales y regiones semánticas.
## 5. Asegurar estricto determinismo y sellar la composición final.
##
## Restricciones Arquitectónicas:
## - No modifica CellGrid ni RoomData.
## - No coloca salas ni calcula posiciones de colisión.
## - No ejecuta A* ni resuelve entradas físicas (entrances).

const SpatialComposition = preload("res://src/dungeon_generator/core/data/spatial_composition.gd")
const SpatialIntent = preload("res://src/dungeon_generator/core/data/spatial_intent.gd")
const SpatialIntentResult = preload("res://src/dungeon_generator/core/data/spatial_intent_result.gd")
const SpatialIntentBuilder = preload("res://src/dungeon_generator/core/grammars/spatial_intent_builder.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")
const MissionNode = preload("res://src/dungeon_generator/core/data/mission_node.gd")

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

## Construye y sella la composición espacial global.
func build(
	mission_graph: DungeonGraph,
	spatial_intent = null, # SpatialIntentResult o null
	config = null, # DungeonConfig o SpaceGrammarConfig o null
	bounds: Rect2i = Rect2i()
) -> SpatialComposition:
	var comp := SpatialComposition.new()

	if mission_graph == null or mission_graph.get_all_node_ids().is_empty():
		comp.seal()
		return comp

	# 1. Resolver o instanciar SpatialIntentResult
	var intent_result: SpatialIntentResult = null
	if spatial_intent is SpatialIntentResult:
		intent_result = spatial_intent
	elif spatial_intent != null and spatial_intent.has_method("get_intent"):
		intent_result = spatial_intent
	else:
		var intent_builder := SpatialIntentBuilder.new()
		intent_result = intent_builder.build(mission_graph)

	# 2. Configurar RNG y parámetros de configuración
	var seed_val: int = 0
	var preferred_dir := Vector2.ZERO
	var density_strength: float = 0.5
	var preferred_dist: float = 12.0

	if config != null:
		if "seed" in config:
			seed_val = int(config.seed)
		if "preferred_progression_direction" in config:
			preferred_dir = config.preferred_progression_direction
		if "density_strength" in config:
			density_strength = float(config.density_strength)
		if "mission_aware_preferred_distance" in config:
			preferred_dist = float(config.mission_aware_preferred_distance)
		# Fallback a space_grammar_config si está anidado
		if "space_grammar_config" in config and config.space_grammar_config != null:
			var sgc = config.space_grammar_config
			if preferred_dir == Vector2.ZERO and "preferred_progression_direction" in sgc:
				preferred_dir = sgc.preferred_progression_direction
			if "density_strength" in sgc:
				density_strength = float(sgc.density_strength)

	# Determinismo del RNG local
	var local_rng := RandomNumberGenerator.new()
	if seed_val != 0:
		local_rng.seed = seed_val
	else:
		local_rng.seed = _rng.seed

	# 3. Determinar Dirección Global de Progresión
	var progression_dir := Vector2.ZERO
	if preferred_dir != Vector2.ZERO:
		progression_dir = preferred_dir.normalized()
	else:
		var dir_idx: int = local_rng.randi_range(0, _DIRECTIONS.size() - 1)
		progression_dir = _DIRECTIONS[dir_idx]

	comp.set_progression_direction(progression_dir)

	# 4. Resolver Límites Espaciales Efectivos
	var effective_bounds := bounds
	if effective_bounds.size.x <= 0 or effective_bounds.size.y <= 0:
		var gw: int = 64
		var gh: int = 64
		if config != null:
			if "grid_width" in config:
				gw = int(config.grid_width)
			if "grid_height" in config:
				gh = int(config.grid_height)
		effective_bounds = Rect2i(0, 0, gw, gh)

	var center := Vector2(effective_bounds.position) + Vector2(effective_bounds.size) * 0.5
	var max_span: float = minf(float(effective_bounds.size.x), float(effective_bounds.size.y)) * 0.65
	var start_origin := center - progression_dir * (max_span * 0.5)
	var perp_dir := Vector2(-progression_dir.y, progression_dir.x)

	# 5. Anclar Camino Principal (Monótono: START=0.0, Terminal=1.0)
	var main_path: Array[int] = []
	if intent_result != null and intent_result.valid:
		main_path = intent_result.main_path
	else:
		var all_ids := mission_graph.get_all_node_ids()
		all_ids.sort()
		if not all_ids.is_empty():
			main_path = [all_ids[0]]

	var main_count: int = main_path.size()
	var main_path_set: Dictionary = {}
	for idx in range(main_count):
		main_path_set[main_path[idx]] = idx

	for idx in range(main_count):
		var nid: int = main_path[idx]
		var factor: float = 0.0
		if main_count > 1:
			factor = float(idx) / float(main_count - 1)
		else:
			factor = 0.0

		# Restricción: START = 0.0, Terminal = 1.0 estricto
		if idx == 0:
			factor = 0.0
		elif idx == main_count - 1:
			factor = 1.0

		# Variación lateral suave para evitar rigidez colineal
		var lateral_offset: float = sin(factor * PI * 1.5) * 6.0
		var anchor_pos: Vector2 = start_origin + progression_dir * (factor * max_span) + perp_dir * lateral_offset

		comp.set_main_path_node(nid, factor, anchor_pos)

		# Clasificar región semántica del nodo en camino principal
		var region: StringName = _classify_main_path_region(idx, main_count, nid, intent_result, mission_graph)
		comp.set_node_region(nid, region)

		# Calcular densidad
		var density: float = _calculate_node_density(nid, mission_graph, density_strength, true)
		comp.set_node_density(nid, density)

	# 6. Asignar Ramas Secundarias (Branches heredan main anchor, NUNCA son main anchors)
	var all_node_ids: Array[int] = mission_graph.get_all_node_ids()
	all_node_ids.sort() # Orden determinista

	var branch_lateral_sign: float = 1.0
	for nid in all_node_ids:
		if main_path_set.has(nid):
			continue

		# Encontrar el nodo ancla en la ruta principal
		var main_anchor_id: int = -1
		if intent_result != null:
			var direct_anchor: int = intent_result.get_anchor_for_node(nid)
			if main_path_set.has(direct_anchor):
				main_anchor_id = direct_anchor

		if main_anchor_id == -1 or not main_path_set.has(main_anchor_id):
			main_anchor_id = _resolve_main_path_ancestor(nid, mission_graph, main_path_set, main_path[0] if not main_path.is_empty() else 0)

		# Regla Crítica: El ancla asignada DEBE ser un nodo del camino principal
		assert(main_path_set.has(main_anchor_id), "Branch anchor must strictly belong to the main path.")

		var anchor_target: Vector2 = comp.get_anchor_target(main_anchor_id)
		var anchor_factor: float = comp.get_main_path_factor(main_anchor_id)
		if anchor_factor < 0.0:
			anchor_factor = 0.5

		# Factor de la rama relativo a su ancla
		var branch_factor: float = anchor_factor
		if intent_result != null:
			var b_intent: SpatialIntent = intent_result.get_intent(nid)
			if b_intent != null:
				branch_factor = b_intent.progression_factor

		# Posición objetivo de anclaje de la rama (desplazamiento lateral respecto al ancla principal)
		branch_lateral_sign = -branch_lateral_sign # Alternar lado para equilibrio espacial
		var lateral_dist: float = preferred_dist * 0.85
		var branch_target: Vector2 = anchor_target + perp_dir * (branch_lateral_sign * lateral_dist) + progression_dir * (preferred_dist * 0.25)

		comp.set_branch_node(nid, main_anchor_id, branch_factor, branch_target)

		# Clasificar región para la rama
		var branch_region: StringName = _classify_branch_region(nid, intent_result, mission_graph)
		comp.set_node_region(nid, branch_region)

		# Calcular densidad para la rama
		var b_density: float = _calculate_node_density(nid, mission_graph, density_strength, false)
		comp.set_node_density(nid, b_density)

	# 7. Sellar Composición Inmutable
	comp.seal()
	return comp

## Resuelve el ancestro más cercano que pertenezca estrictamente al camino principal.
func _resolve_main_path_ancestor(
	node_id: int,
	graph: DungeonGraph,
	main_path_set: Dictionary,
	fallback_id: int
) -> int:
	var queue: Array[int] = [node_id]
	var visited: Dictionary = {node_id: true}

	while not queue.is_empty():
		var curr: int = queue.pop_front()
		var preds: Array[int] = graph.get_predecessors(curr)
		for p in preds:
			if main_path_set.has(p):
				return p
			if not visited.has(p):
				visited[p] = true
				queue.append(p)

	# Si no se encuentra por predecesores, buscar en vecinos no dirigidos
	queue = [node_id]
	visited = {node_id: true}
	while not queue.is_empty():
		var curr: int = queue.pop_front()
		var neighbors: Array[int] = graph.get_neighbors(curr)
		for n in neighbors:
			if main_path_set.has(n):
				return n
			if not visited.has(n):
				visited[n] = true
				queue.append(n)

	return fallback_id

func _classify_main_path_region(
	idx: int,
	total: int,
	node_id: int,
	intent_result: SpatialIntentResult,
	graph: DungeonGraph
) -> StringName:
	if idx == 0:
		return SpatialComposition.REGION_START
	if idx == total - 1:
		return SpatialComposition.REGION_BOSS

	if intent_result != null:
		var intent: SpatialIntent = intent_result.get_intent(node_id)
		if intent != null:
			if intent.path_role == SpatialIntent.ROLE_START:
				return SpatialComposition.REGION_START
			if intent.path_role == SpatialIntent.ROLE_BOSS or intent.path_role == SpatialIntent.ROLE_GOAL:
				return SpatialComposition.REGION_BOSS

	var ratio: float = float(idx) / float(maxi(1, total - 1))
	if ratio <= 0.33:
		return SpatialComposition.REGION_EARLY
	elif ratio <= 0.67:
		return SpatialComposition.REGION_MID
	else:
		return SpatialComposition.REGION_LATE

func _classify_branch_region(
	node_id: int,
	intent_result: SpatialIntentResult,
	graph: DungeonGraph
) -> StringName:
	if intent_result != null:
		var intent: SpatialIntent = intent_result.get_intent(node_id)
		if intent != null and intent.path_role == SpatialIntent.ROLE_OPTIONAL:
			return SpatialComposition.REGION_OPTIONAL

	var node_data: Dictionary = graph.get_node_data(node_id)
	var m_node: MissionNode = MissionNode.from_dictionary(node_data)
	if m_node.is_optional or m_node.action == MissionNode.ActionType.TREASURE or m_node.action == MissionNode.ActionType.PUZZLE:
		return SpatialComposition.REGION_OPTIONAL

	return SpatialComposition.REGION_BRANCH

func _calculate_node_density(
	node_id: int,
	graph: DungeonGraph,
	density_strength: float,
	is_main: bool
) -> float:
	var degree: int = graph.get_neighbors(node_id).size()
	var base_density: float = 1.0
	if degree > 2:
		base_density += float(degree - 2) * (density_strength * 0.3)
	elif degree <= 1 and not is_main:
		base_density -= 0.15 * density_strength

	return clampf(base_density, 0.5, 2.5)
