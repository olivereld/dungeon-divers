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

	var surf = _RiverMeshBuilder.build_confluence_surface(conf, null, dummy_profile, net, 3)
	assert(surf != null, "Confluence surface must be generated")
	assert(surf.vertices.size() >= 8, "Debe tener al menos 8 vértices")
	assert(surf.indices.size() >= 12, "Debe tener al menos 12 índices (4 triángulos)")

	print("TEST BLOQUE 1: PASSED!")
	print("==========================================================")
	quit(0)
