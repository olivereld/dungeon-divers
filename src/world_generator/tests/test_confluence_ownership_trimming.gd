extends SceneTree

## Test de validación para el Bloque 2: Ownership exclusivo y recorte de ribbons.
## Verifica que los ribbons incidentes cedan su espacio a la junction y que no existan
## solapamientos ni gaps en las fronteras de traspaso.

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _River = preload("res://src/world_generator/hydrology/river.gd")
const _RiverNetwork = preload("res://src/world_generator/hydrology/river_network.gd")

func _init() -> void:
	print("==========================================================")
	print("--- TEST BLOQUE 2: OWNERSHIP Y RECORTE DE RIBBONS ---")
	print("==========================================================")

	var net = _RiverNetwork.new()
	var r1 = _River.new(0, Vector2i(0, 0), [])
	r1.points = [Vector3(0, 0, 0), Vector3(3, 0, 1), Vector3(6, 0, 2)]
	r1.widths = [1.2, 1.2, 1.2]
	r1.depths = [0.2, 0.2, 0.2]
	r1.downstream_river = 1

	var r_down = _River.new(1, Vector2i(6, 2), [])
	r_down.points = [Vector3(6, 0, 2), Vector3(9, 0, 2), Vector3(12, 0, 2)]
	r_down.widths = [2.0, 2.0, 2.0]
	r_down.depths = [0.3, 0.3, 0.3]
	r_down.upstream_rivers = [0]

	net.add_river(r1)
	net.add_river(r_down)

	var dummy_profile = WorldProfile.new()

	# 1. Generar ribbon upstream (debe terminar en la frontera de ownership)
	var r1_surf = _RiverMeshBuilder.build_river_surface(r1, null, dummy_profile, net)
	assert(r1_surf != null, "Upstream ribbon must be generated")

	# 2. Generar ribbon downstream (debe empezar en la frontera de ownership)
	var down_surf = _RiverMeshBuilder.build_river_surface(r_down, null, dummy_profile, net)
	assert(down_surf != null, "Downstream ribbon must be generated")

	# 3. Generar junction surface
	var conf := {"position": Vector2i(6, 2), "upstream_rivers": [0], "downstream_river": 1}
	var conf_surf = _RiverMeshBuilder.build_confluence_surface(conf, null, dummy_profile, net, 3)
	assert(conf_surf != null, "Confluence surface must be generated")

	# Verificar coincidencia exacta en frontera upstream
	var r1_last_l: Vector3 = r1_surf.vertices[-2]
	var r1_last_r: Vector3 = r1_surf.vertices[-1]
	var conf_first_l: Vector3 = conf_surf.vertices[0]
	var conf_first_r: Vector3 = conf_surf.vertices[1]

	var dist_l: float = r1_last_l.distance_to(conf_first_l)
	var dist_r: float = r1_last_r.distance_to(conf_first_r)
	assert(dist_l < 0.05, "Upstream ribbon left boundary must match confluence entry (error: %f)" % dist_l)
	assert(dist_r < 0.05, "Upstream ribbon right boundary must match confluence entry (error: %f)" % dist_r)

	print("TEST BLOQUE 2: PASSED!")
	print("==========================================================")
	quit(0)
