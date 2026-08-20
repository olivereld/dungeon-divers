class_name DungeonGeometryGenerator
extends RefCounted

## Fachada central unificada de alto nivel para la generación procedural de geometría 3D (Fase M5 & Hardening).
## Orquesta BoundaryExtractor -> ComponentExtractor -> WallGeometryBuilder -> WallCollisionBuilder -> BrickDecorator -> MaterialResolver.

const _BoundaryExtractorScript = preload("res://src/geometry_generator/extraction/boundary_extractor.gd")
const _ComponentExtractorScript = preload("res://src/geometry_generator/extraction/component_extractor.gd")
const _WallGeometryBuilderScript = preload("res://src/geometry_generator/geometry/wall_geometry_builder.gd")
const _WallCollisionBuilderScript = preload("res://src/geometry_generator/collision/wall_collision_builder.gd")
const _BrickDecoratorScript = preload("res://src/geometry_generator/decoration/brick_decorator.gd")
const _MaterialResolverScript = preload("res://src/geometry_generator/decoration/material_resolver.gd")

const _GeometryResultScript = preload("res://src/geometry_generator/data/geometry_result.gd")
const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _CollisionConfigScript = preload("res://src/geometry_generator/config/collision_config.gd")
const _DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")

var _boundary_extractor := _BoundaryExtractorScript.new()
var _component_extractor := _ComponentExtractorScript.new()
var _geometry_builder := _WallGeometryBuilderScript.new()
var _collision_builder := _WallCollisionBuilderScript.new()
var _decorator := _BrickDecoratorScript.new()
var _material_resolver := _MaterialResolverScript.new()

## Genera los clusters de geometría de muros para un CellGrid y los retorna en un GeometryResult.
func generate_wall_clusters(
	grid: CellGrid,
	opening_manifest: WallOpeningManifest = null,
	wall_config: WallGeometryConfig = null,
	col_config: CollisionConfig = null,
	dec_config: DecorationConfig = null,
	material_preset: int = 0
) -> GeometryResult:
	var result := _GeometryResultScript.new()
	if grid == null:
		result.add_diagnostic("NULL_GRID", "FATAL", "Grid provided is null")
		return result

	# Normalización estricta de parámetros
	if wall_config == null:
		wall_config = _WallGeometryConfigScript.new()
	if col_config == null:
		col_config = _CollisionConfigScript.new()
	if dec_config == null:
		dec_config = _DecorationConfigScript.new()

	# 1. Extracción Topológica (Grafo de aristas)
	var graph = _boundary_extractor.extract_graph(grid, opening_manifest)
	if graph.get_edge_count() == 0:
		return result

	# 2. Descomposición en Componentes Conexas (Clusters)
	var components: Array = _component_extractor.extract_components(graph)

	# 3. Generación por cada cluster
	for comp in components:
		# 3.1 Malla estructural pura
		var g_mesh: GeneratedMesh = _geometry_builder.build_component_mesh(comp, wall_config)
		if g_mesh.mesh == null:
			continue

		# 3.2 Decoración superficial (Ladrillos)
		_decorator.decorate_component(g_mesh, comp, wall_config, dec_config)

		# 3.3 Materiales PBR
		_material_resolver.resolve_materials_for_mesh(g_mesh, material_preset)

		# 3.4 Colisión física
		_collision_builder.build_collision_for_component(comp, wall_config, col_config, g_mesh)

		result.generated_meshes.append(g_mesh)

	return result

## Genera y añade directamente los nodos 3D (MeshInstance3D + StaticBody3D) a un nodo padre.
func generate_and_attach_wall_nodes(
	grid: CellGrid,
	parent_node: Node3D,
	opening_manifest: WallOpeningManifest = null,
	wall_config: WallGeometryConfig = null,
	col_config: CollisionConfig = null,
	dec_config: DecorationConfig = null,
	material_preset: int = 0
) -> Array[MeshInstance3D]:
	var created_nodes: Array[MeshInstance3D] = []

	# Normalización única y homogénea antes de cualquier procesamiento
	if wall_config == null:
		wall_config = _WallGeometryConfigScript.new()
	if col_config == null:
		col_config = _CollisionConfigScript.new()
	if dec_config == null:
		dec_config = _DecorationConfigScript.new()

	var res := generate_wall_clusters(grid, opening_manifest, wall_config, col_config, dec_config, material_preset)

	for g_mesh in res.generated_meshes:
		var inst: MeshInstance3D = g_mesh.to_mesh_instance("WallCluster")
		if col_config.mode != _CollisionConfigScript.CollisionMode.NONE:
			var static_body := g_mesh.create_collision_body()
			inst.add_child(static_body)

		if parent_node != null:
			parent_node.add_child(inst)
		created_nodes.append(inst)

	return created_nodes
