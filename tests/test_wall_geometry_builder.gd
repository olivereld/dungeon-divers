extends SceneTree

## Test suite para validar la Extrusión Continua Desacoplada (Fase M2: WallGeometryBuilder).
## Verifica que se genera geometría 3D pura con superficies indexadas, tangentes y bounds calculados.

const WallComponent = preload("res://src/geometry_generator/data/wall_component.gd")
const WallGeometryConfig = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const WallGeometryBuilder = preload("res://src/geometry_generator/geometry/wall_geometry_builder.gd")
const GeneratedMesh = preload("res://src/geometry_generator/data/generated_mesh.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_geometry_builder (Fase M2: Mesh Extrusion) ---")
	print("==================================================================")

	var builder := WallGeometryBuilder.new()
	var config := WallGeometryConfig.new()
	config.cube_size = 2.0
	config.cubes_high = 2

	# 1. Caso A: Componente cuadrado de 3x3 celdas (6.0m x 6.0m)
	var comp := WallComponent.new(1)
	comp.add_loop([
		Vector2i(2, 2),
		Vector2i(5, 2),
		Vector2i(5, 5),
		Vector2i(2, 5)
	])

	var g_mesh: GeneratedMesh = builder.build_component_mesh(comp, config)

	assert(g_mesh != null, "GeneratedMesh should not be null")
	assert(g_mesh.component_id == 1, "component_id must match WallComponent id")
	assert(g_mesh.mesh != null, "ArrayMesh must not be null")

	var mesh: ArrayMesh = g_mesh.mesh
	assert(mesh.get_surface_count() == 2, "Expected exactly 2 surfaces (Trims, WallPanel), got %d" % mesh.get_surface_count())
	assert(mesh.surface_get_name(0) == "Trims", "Surface 0 should be named 'Trims'")
	assert(mesh.surface_get_name(1) == "WallPanel", "Surface 1 should be named 'WallPanel'")

	# Verificar que ambas superficies contienen vértices y triángulos
	var arrays_0 = mesh.surface_get_arrays(0)
	var verts_0: PackedVector3Array = arrays_0[Mesh.ARRAY_VERTEX]
	var indices_0: PackedInt32Array = arrays_0[Mesh.ARRAY_INDEX]
	assert(verts_0.size() > 0, "Trims must have vertices")
	assert(indices_0.size() > 0, "Trims must have triangle indices")

	var arrays_1 = mesh.surface_get_arrays(1)
	var verts_1: PackedVector3Array = arrays_1[Mesh.ARRAY_VERTEX]
	var indices_1: PackedInt32Array = arrays_1[Mesh.ARRAY_INDEX]
	assert(verts_1.size() > 0, "WallPanel must have vertices")
	assert(indices_1.size() > 0, "WallPanel must have triangle indices")

	# Validar límites 3D del cluster
	var bounds: AABB = g_mesh.bounds
	assert(bounds.size.x >= 5.9, "Bounds X should be at least 6.0m (got %.2f)" % bounds.size.x)
	assert(bounds.size.z >= 5.9, "Bounds Z should be at least 6.0m (got %.2f)" % bounds.size.z)
	assert(bounds.size.y >= config.get_total_height() - 0.1, "Bounds Y should match wall height")

	print("  [OK] Caso A: Malla de cluster extruida correctamente con 2 superficies y bounds calculados.")

	# 2. Caso B: Componente vacío -> Retorna GeneratedMesh seguro con mesh nulo
	var empty_comp := WallComponent.new(99)
	var empty_g_mesh: GeneratedMesh = builder.build_component_mesh(empty_comp, config)
	assert(empty_g_mesh != null and empty_g_mesh.mesh == null, "Empty component must return empty mesh safely")

	print("  [OK] Caso B: Componente vacío manejado de forma robusta.")

	print("==================================================================")
	print("[PASS] test_wall_geometry_builder completado exitosamente!")
	print("==================================================================")
	quit(0)
