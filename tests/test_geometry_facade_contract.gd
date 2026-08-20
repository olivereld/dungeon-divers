extends SceneTree

## Test suite para validar el Contrato Público de la Fachada DungeonGeometryGenerator.
## Verifica inmunidad a argumentos nulos, normalización de colisiones por defecto y contrato GeometryResult.

const DungeonGeometryGenerator = preload("res://src/geometry_generator/facade/dungeon_geometry_generator.gd")
const CellGrid = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const GeometryResult = preload("res://src/geometry_generator/data/geometry_result.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_geometry_facade_contract (Public API & Nulls) ---")
	print("==================================================================")

	var generator := DungeonGeometryGenerator.new()

	# 1. Caso A: Invocar con grid nulo -> Retorna GeometryResult con diagnóstico FATAL seguro
	var null_res: GeometryResult = generator.generate_wall_clusters(null)
	assert(null_res != null, "Result should not be null")
	assert(null_res.success == false, "Result must fail on null grid")
	assert(null_res.has_errors() == true, "Must flag error diagnostics")
	print("  [OK] Caso A: Grid nulo manejado de forma segura sin excepciones.")

	# 2. Caso B: Invocar generate_and_attach_wall_nodes() pasando TODOS los configs en NULL
	# (Valida la corrección del Bug #3 de la auditoría)
	var grid := CellGrid.new(10, 10)
	for y in range(2, 5):
		for x in range(2, 5):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	var parent := Node3D.new()
	root.add_child(parent)

	var attached_nodes: Array[MeshInstance3D] = generator.generate_and_attach_wall_nodes(
		grid,
		parent,
		null, # opening_manifest = null
		null, # wall_config = null
		null, # col_config = null -> DEBE NORMALIZARSE A COMPOUND_BOX POR DEFECTO
		null, # dec_config = null
		0
	)

	assert(attached_nodes.size() == 1, "Expected 1 cluster node attached, got %d" % attached_nodes.size())
	assert(parent.get_child_count() == 1, "Parent must have 1 child")
	var node: MeshInstance3D = attached_nodes[0]
	assert(node.mesh != null, "MeshInstance3D must have a mesh")

	# Verificar que el StaticBody3D y sus CollisionShape3D fueron generados a pesar de col_config = null
	assert(node.get_child_count() == 1, "MeshInstance3D MUST have 1 StaticBody3D child (bug fix verified)")
	var body = node.get_child(0)
	assert(body is StaticBody3D, "Child must be StaticBody3D")
	assert(body.get_child_count() > 0, "StaticBody3D must contain CollisionShape3D children")

	parent.free()
	print("  [OK] Caso B: Normalización con configs nulos validada (StaticBody3D y colisiones creadas con éxito).")

	# 3. Caso C: Contrato GeometryResult
	var res: GeometryResult = generator.generate_wall_clusters(grid, null, null, null, null, 0)
	assert(res.success == true)
	assert(res.generated_meshes.size() == 1)
	var g_mesh = res.generated_meshes[0]
	assert(g_mesh.mesh != null)
	assert(not g_mesh.collision_shapes.is_empty())
	assert(g_mesh.bounds.size.x > 0.0)

	print("  [OK] Caso C: Contrato público GeometryResult congelado y verificado.")

	print("==================================================================")
	print("[PASS] test_geometry_facade_contract completado con 100% éxito!")
	print("==================================================================")
	quit(0)
