extends SceneTree

## Test suite para validar la Decoración Superficial y Asignación de Materiales (Fase M4).
## Verifica que BrickDecorator añade ladrillos procedimentales y MaterialResolver asigna materiales PBR.

const WallComponent = preload("res://src/geometry_generator/data/wall_component.gd")
const WallGeometryConfig = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const DecorationConfig = preload("res://src/geometry_generator/config/decoration_config.gd")
const WallGeometryBuilder = preload("res://src/geometry_generator/geometry/wall_geometry_builder.gd")
const BrickDecorator = preload("res://src/geometry_generator/decoration/brick_decorator.gd")
const MaterialResolver = preload("res://src/geometry_generator/decoration/material_resolver.gd")
const GeneratedMesh = preload("res://src/geometry_generator/data/generated_mesh.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_surface_decoration (Fase M4: Decoration & Mat) ---")
	print("==================================================================")

	var geom_builder := WallGeometryBuilder.new()
	var decorator := BrickDecorator.new()
	var mat_resolver := MaterialResolver.new()

	var wall_cfg := WallGeometryConfig.new()
	wall_cfg.cube_size = 2.0
	wall_cfg.cubes_high = 2

	var comp := WallComponent.new(0)
	comp.add_loop([
		Vector2i(2, 2),
		Vector2i(8, 2),
		Vector2i(8, 8),
		Vector2i(2, 8)
	])

	# 1. Caso A: Decoración habilitada -> Añade superficie "Bricks"
	var g_mesh_a: GeneratedMesh = geom_builder.build_component_mesh(comp, wall_cfg)
	assert(g_mesh_a.mesh.get_surface_count() == 2, "Initially 2 surfaces (Trims, WallPanel)")

	var dec_cfg_a := DecorationConfig.new()
	dec_cfg_a.enabled = true
	dec_cfg_a.brick_density = 0.8 # Alta densidad para asegurar generación
	decorator.decorate_component(g_mesh_a, comp, wall_cfg, dec_cfg_a)

	assert(g_mesh_a.mesh.get_surface_count() == 3, "Expected 3 surfaces after decoration (Trims, WallPanel, Bricks), got %d" % g_mesh_a.mesh.get_surface_count())
	assert(g_mesh_a.mesh.surface_get_name(2) == "Bricks", "Surface 2 must be named 'Bricks'")

	# Resolver materiales
	mat_resolver.resolve_materials_for_mesh(g_mesh_a, 0)
	assert(g_mesh_a.material_slots.size() == 3, "All 3 surfaces should have resolved materials")
	for s in range(3):
		assert(g_mesh_a.mesh.surface_get_material(s) != null, "Surface %d material must not be null" % s)

	print("  [OK] Caso A: Ladrillos procedimentales añadidos como superficie independiente y materiales asignados.")

	# 2. Caso B: Decoración deshabilitada -> Permanece con 2 superficies
	var g_mesh_b: GeneratedMesh = geom_builder.build_component_mesh(comp, wall_cfg)
	var dec_cfg_b := DecorationConfig.new()
	dec_cfg_b.enabled = false
	decorator.decorate_component(g_mesh_b, comp, wall_cfg, dec_cfg_b)
	assert(g_mesh_b.mesh.get_surface_count() == 2, "Disabled decoration must keep 2 surfaces")
	print("  [OK] Caso B: Decoración deshabilitada respetada.")

	print("==================================================================")
	print("[PASS] test_surface_decoration completado exitosamente!")
	print("==================================================================")
	quit(0)
