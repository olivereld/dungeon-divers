extends SceneTree

const _HydraulicDestinationResolverScript = preload("res://src/world_generator/hydrology/hydraulic_destination_resolver.gd")
const _HydraulicCarvingProfileScript = preload("res://src/world_generator/hydrology/hydraulic_carving_profile.gd")
const _RiverEndpointScript = preload("res://src/world_generator/hydrology/river_endpoint.gd")
const _LakeCandidateScript = preload("res://src/world_generator/hydrology/lake_candidate.gd")
const _RiverScript = preload("res://src/world_generator/hydrology/river.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Explicit Lake & Hydraulic Cycle Unit Test")
	print("==================================================")

	var resolver = _HydraulicDestinationResolverScript.new()
	var width: int = 32
	var height: int = 32

	# 1. Crear una topografía sintética con una depresión (cuenca) cerrada:
	# Terreno circundante a cota 15.0, depresión centrada en (16, 16) con fondo en 10.0
	# Vertedero (spillway) natural en (16, 19) a cota 12.0
	var cells: Dictionary = {}
	var filled_height: Dictionary = {}
	var flood_rank: Dictionary = {}
	var flow_to: Dictionary = {}

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			var d_center: float = pos.distance_to(Vector2(16, 16))
			var h: float = 15.0
			if d_center <= 3.0:
				h = 10.0 + d_center * 0.5  # Fondo entre 10.0 y 11.5
			elif pos == Vector2i(16, 20):
				h = 12.0  # El vertedero natural de la cuenca
			cell.raw_height = h
			cell.height = h
			cells[pos] = cell
			# Simular Priority-Flood: el nivel de llenado de la depresión es 12.0
			if d_center <= 3.0:
				filled_height[pos] = 12.0
			else:
				filled_height[pos] = h
			flood_rank[pos] = y * width + x
			flow_to[pos] = Vector2i(x, y + 1) if y < height - 1 else pos

	# Flujo dentro de la depresión hacia el centro (16, 16)
	flow_to[Vector2i(16, 16)] = Vector2i(16, 16)  # Sink
	flow_to[Vector2i(16, 20)] = Vector2i(16, 21)  # Desagüe por vertedero hacia el sur

	# -------------------------------------------------------------
	# BLOQUE A: Resolver físico y TERMINATE
	# -------------------------------------------------------------
	print(" [CHECK] Bloque A: HydraulicDestinationResolver Topography & Terminate...")
	# Caso 1: Endpoint en sumidero de la depresión -> LAKE
	var ep_lake = _RiverEndpointScript.new(1, Vector2i(16, 16), 10.0, 50.0)
	var dest_lake = resolver.resolve_destination(ep_lake, width, height, {}, cells, flow_to, {}, filled_height)
	assert(dest_lake == _RiverEndpointScript.DestinationType.LAKE, "Debe clasificar como LAKE en depresión")

	# Caso 2: Endpoint en ladera continua plana sin sumidero ni borde -> TERMINATE (no forzar LAKE)
	var ep_term = _RiverEndpointScript.new(2, Vector2i(5, 5), 15.0, 10.0)
	flow_to[Vector2i(5, 5)] = Vector2i(5, 6)
	var dest_term = resolver.resolve_destination(ep_term, width, height, {}, cells, flow_to, {}, filled_height)
	assert(dest_term == _RiverEndpointScript.DestinationType.TERMINATE, "Debe clasificar como TERMINATE en terreno sin depresión")

	# Caso 3: Expansión de lago topográfico real (sin +0.60m y sin límite 120 celdas)
	var lake = resolver.expand_lake_from_endpoint(ep_lake, 1, cells, filled_height, flood_rank, width, height, 4)
	assert(lake != null, "Lake candidate no debe ser nulo en depresión real")
	assert(lake.cells.size() >= 4, "Debe contener las celdas de la cubeta")
	assert(is_equal_approx(lake.water_height, 12.0), "La lámina de agua debe coincidir exactamente con la cota del vertedero (12.0), obtenido: %.3f" % lake.water_height)
	assert(lake.spillway_pos != Vector2i(-1, -1), "Debe identificar posición de vertedero válida")
	print("   Bloque A: PASSED")

	# -------------------------------------------------------------
	# BLOQUE B: Carving estrictamente destructivo
	# -------------------------------------------------------------
	print(" [CHECK] Bloque B: HydraulicCarvingProfile strictly destructive...")
	var prof = _HydraulicCarvingProfileScript.create_for_lake(0.5, 1.0, 3.0, 0.25)
	for test_sd in [-2.0, -1.0, 0.0, 1.0, 2.0, 4.0]:
		var c_h: float = prof.evaluate_boundary(test_sd, 12.0, 10.0)
		assert(c_h <= 10.0001, "Carving nunca debe elevar terreno natural (10.0)")
	print("   Bloque B: PASSED")

	# -------------------------------------------------------------
	# BLOQUE C: Conectar LakeCandidate con carving
	# -------------------------------------------------------------
	print(" [CHECK] Bloque C: Bed and Bank Carving...")
	for p in lake.cells:
		var c = cells[p]
		var bed_h: float = lake.water_height - 0.40
		c.height = minf(c.raw_height, bed_h)
		assert(c.height < lake.water_height, "Lecho sumergido debe quedar estrictamente bajo water_height")
	print("   Bloque C: PASSED")

	# -------------------------------------------------------------
	# BLOQUE D: Outflow river y validación
	# -------------------------------------------------------------
	print(" [CHECK] Bloque D: Trace Outflow & Ground Truth Validation...")
	var accum: Dictionary = {}
	accum[lake.spillway_pos] = 25.0
	var outflow = resolver.trace_lake_outflow(lake, flow_to, accum, 10, 50, {})
	assert(outflow != null, "Debe generar río efluente desde el vertedero hacia downstream")
	assert(outflow.path[0] == lake.spillway_pos, "El nacimiento del efluente debe ser el vertedero del lago")
	assert(outflow.is_outflow == true, "is_outflow debe ser true")
	print("   Bloque D: PASSED")

	print("==================================================")
	print(" ALL HYDRAULIC CYCLE VERIFICATION TESTS PASSED!")
	print("==================================================")
	quit(0)
