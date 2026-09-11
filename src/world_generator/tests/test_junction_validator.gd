extends SceneTree

## Test de validación para el Bloque 3: Validador específico de Junctions.
## Verifica que JunctionValidator detecte quads válidos y capture correctamente:
## - quads con aristas cruzadas (bowtie)
## - triángulos degenerados
## - progreso longitudinal nulo o negativo

const _JunctionValidator = preload("res://src/world_generator/validation/junction_validator.gd")
const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _River = preload("res://src/world_generator/hydrology/river.gd")
const _RiverNetwork = preload("res://src/world_generator/hydrology/river_network.gd")

func _init() -> void:
	print("==========================================================")
	print("--- TEST BLOQUE 3: VALIDADOR ESPECÍFICO DE JUNCTIONS ---")
	print("==========================================================")

	# 1. Quad válido
	var q_l0 := Vector3(-1, 0, 0)
	var q_r0 := Vector3(1, 0, 0)
	var q_l1 := Vector3(-1, 0, 2)
	var q_r1 := Vector3(1, 0, 2)
	var res_valid = _JunctionValidator.validate_quad(q_l0, q_r0, q_l1, q_r1)
	assert(res_valid["valid"], "Quad normal debe ser válido")

	# 2. Quad con aristas cruzadas (bowtie / auto-intersección lateral)
	var l1_crossed := Vector3(1.5, 0, 2)
	var r1_crossed := Vector3(-1.5, 0, 2)
	var res_crossed = _JunctionValidator.validate_quad(q_l0, q_r0, l1_crossed, r1_crossed)
	assert(not res_crossed["valid"], "Quad cruzado debe ser inválido")
	assert(res_crossed["errors"].size() > 0, "Debe reportar error de cruce")

	# 3. Quad colapsado sin avance longitudinal
	var res_zero_step = _JunctionValidator.validate_quad(q_l0, q_r0, q_l0, q_r0)
	assert(not res_zero_step["valid"], "Quad sin avance longitudinal debe ser inválido")

	# 4. Validar una junction surface real construida con RiverMeshBuilder
	var net = _RiverNetwork.new()
	var r1 = _River.new(0, Vector2i(0, 0), [])
	r1.points = [Vector3(0, 0, 0), Vector3(5, 0, 2)]
	r1.widths = [1.2, 1.2]
	r1.depths = [0.2, 0.2]
	r1.downstream_river = 2

	var r2 = _River.new(1, Vector2i(0, 4), [])
	r2.points = [Vector3(0, 0, 4), Vector3(5, 0, 2)]
	r2.widths = [1.2, 1.2]
	r2.depths = [0.2, 0.2]
	r2.downstream_river = 2

	var r_down = _River.new(2, Vector2i(5, 2), [])
	r_down.points = [Vector3(5, 0, 2), Vector3(10, 0, 2)]
	r_down.widths = [2.0, 2.0]
	r_down.depths = [0.3, 0.3]
	r_down.upstream_rivers = [0, 1]

	net.add_river(r1)
	net.add_river(r2)
	net.add_river(r_down)

	var conf := {"position": Vector2i(5, 2), "upstream_rivers": [0, 1], "downstream_river": 2}
	var dummy_profile = WorldProfile.new()
	var surf = _RiverMeshBuilder.build_confluence_surface(conf, null, dummy_profile, net, 3)

	var res_surface = _JunctionValidator.validate_junction_surface(surf, 2, 3)
	assert(res_surface["valid"], "Junction surface generada debe pasar validación completa (errores: %s)" % str(res_surface["errors"]))
	assert(res_surface["metrics"]["degenerate_triangles"] == 0, "No debe haber triángulos degenerados")

	print("TEST BLOQUE 3: PASSED!")
	print("==========================================================")
	quit(0)
