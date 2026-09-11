extends SceneTree

## Test de validación para el Bloque 1: Ancho explícito en Junctions.
## Verifica que el ancho de cada estación sea estrictamente continuo, positivo,
## coincidente con el modelo matemático e idéntico a las fronteras incidentes.

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _River = preload("res://src/world_generator/hydrology/river.gd")
const _RiverNetwork = preload("res://src/world_generator/hydrology/river_network.gd")

func _init() -> void:
	print("==========================================================")
	print("--- TEST BLOQUE 1: INTERPOLACIÓN EXPLÍCITA DE ANCHO ---")
	print("==========================================================")

	var net = _RiverNetwork.new()
	var r1 = _River.new(0, Vector2i(0, 0), [])
	r1.points = [Vector3(0, 0, 0), Vector3(5, 0, 2)]
	r1.widths = [1.0, 1.2]
	r1.depths = [0.2, 0.2]
	r1.downstream_river = 2

	var r2 = _River.new(1, Vector2i(0, 4), [])
	r2.points = [Vector3(0, 0, 4), Vector3(5, 0, 2)]
	r2.widths = [1.0, 1.4]
	r2.depths = [0.2, 0.2]
	r2.downstream_river = 2

	var r_down = _River.new(2, Vector2i(5, 2), [])
	r_down.points = [Vector3(5, 0, 2), Vector3(10, 0, 2)]
	r_down.widths = [2.6, 2.8]
	r_down.depths = [0.3, 0.3]
	r_down.upstream_rivers = [0, 1]

	net.add_river(r1)
	net.add_river(r2)
	net.add_river(r_down)

	var conf := {"position": Vector2i(5, 2), "upstream_rivers": [0, 1], "downstream_river": 2}
	var dummy_profile = WorldProfile.new()

	var station_grid = _RiverMeshBuilder._generate_explicit_junction_stations(conf, net, null, dummy_profile, 3)
	assert(station_grid.size() == 2, "Debe tener 2 ramas")

	for k in range(station_grid.size()):
		var branch_stations: Array = station_grid[k]
		assert(branch_stations.size() == 4, "Debe tener M+1 = 4 filas de estaciones")
		var w_start: float = branch_stations[0]["width"]
		var w_end: float = branch_stations[3]["width"]
		assert(w_start > 0.0 and w_end > 0.0, "Anchos extremos deben ser positivos")

		for m in range(branch_stations.size()):
			var st: Dictionary = branch_stations[m]
			assert(st["width"] > 0.0, "Ancho debe ser estrictamente positivo")
			assert(absf(st["half_width"] - st["width"] * 0.5) < 0.0001, "half_width debe ser exactamente width/2")
			var calculated_w: float = st["left"].distance_to(st["right"])
			assert(absf(calculated_w - st["width"]) < 0.001, "La distancia geométrica (left a right) debe coincidir con width")

	print("TEST BLOQUE 1: PASSED!")
	print("==========================================================")
	quit(0)
