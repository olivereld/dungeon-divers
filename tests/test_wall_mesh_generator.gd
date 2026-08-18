extends SceneTree

## Suite de pruebas para el módulo wall_mesh_generator (Estilo Estilizado).
## Valida geometría de molduras con juntas, panel de muro, ladrillos en relieve y construcción secuencial.

func _init() -> void:
	print("--- Running test_wall_mesh_generator (Stylized) ---")

	var config_script = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")
	var builder_script = preload("res://src/wall_mesh_generator/core/wall_mesh_builder.gd")
	var seq_script = preload("res://src/wall_mesh_generator/core/wall_sequence_controller.gd")
	var mat_script = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

	# 1. Validar Configuración de 2 Cubos de Alto
	var config: WallMeshConfig = config_script.new()
	config.cube_size = 2.0
	config.cubes_high = 2
	config.wall_length_cubes = 2
	config.seed = 42

	assert(is_equal_approx(config.get_total_height(), 4.0), "Total height must be 4.0m for 2 cubes")
	assert(is_equal_approx(config.get_total_length(), 4.0), "Total length must be 4.0m for 2 cubes")
	print("  [OK] WallMeshConfig dimensions verified (4.0m height, 4.0m length)")

	# 2. Validar Manifiesto de Partes (Zócalo, Panel, Moldura y Ladrillos)
	var builder: WallMeshBuilder = builder_script.new()
	var manifest: Array[Dictionary] = builder.build_brick_manifest(config)
	assert(not manifest.is_empty(), "Manifest must not be empty")

	var has_bottom_trim: bool = false
	var has_wall_panel: bool = false
	var has_top_trim: bool = false
	var brick_count: int = 0

	for p in manifest:
		var cat: StringName = p["category"]
		if cat == &"bottom_trim": has_bottom_trim = true
		elif cat == &"wall_panel": has_wall_panel = true
		elif cat == &"top_trim": has_top_trim = true
		elif cat == &"brick": brick_count += 1

	assert(has_bottom_trim, "Manifest must contain bottom_trim")
	assert(has_wall_panel, "Manifest must contain wall_panel")
	assert(has_top_trim, "Manifest must contain top_trim")
	assert(brick_count >= 6, "Manifest must contain stylized brick clusters")
	print("  [OK] Stylized manifest verified (Trims, WallPanel and %d Bricks)" % brick_count)

	# 3. Validar Generación de ArrayMesh Completo con Superficies Nombradas
	var mesh: ArrayMesh = builder.build_wall_mesh(config)
	assert(mesh != null, "ArrayMesh must not be null")
	assert(mesh.get_surface_count() == 3, "Mesh should have 3 surfaces (Trims, WallPanel, Bricks)")
	assert(mesh.surface_get_name(0) == "Trims", "Surface 0 must be Trims")
	assert(mesh.surface_get_name(1) == "WallPanel", "Surface 1 must be WallPanel")
	assert(mesh.surface_get_name(2) == "Bricks", "Surface 2 must be Bricks")

	var aabb: AABB = mesh.get_aabb()
	assert(aabb.size.y > 3.8 and aabb.size.y <= 4.2, "Mesh AABB height should be approximately 4.0m (got %.2f)" % aabb.size.y)
	assert(aabb.size.x > 3.8 and aabb.size.x <= 4.2, "Mesh AABB length should be approximately 4.0m (got %.2f)" % aabb.size.x)
	print("  [OK] Stylized wall mesh built successfully. AABB: %.2f x %.2f x %.2f m" % [aabb.size.x, aabb.size.y, aabb.size.z])

	# 4. Validar Determinismo
	var config2: WallMeshConfig = config.duplicate_config()
	var manifest2: Array[Dictionary] = builder.build_brick_manifest(config2)
	assert(manifest.size() == manifest2.size(), "Manifests with same seed must have identical element counts")
	for i in range(manifest.size()):
		var p1: Dictionary = manifest[i]
		var p2: Dictionary = manifest2[i]
		assert(p1["category"] == p2["category"], "Category mismatch at %d" % i)
		assert(p1["transform"].origin.is_equal_approx(p2["transform"].origin), "Position mismatch at %d" % i)
	print("  [OK] Determinism verified with identical seed")

	# 5. Validar Generación Secuencial
	var seq: WallSequenceController = seq_script.new()
	seq.setup(config, WallSequenceController.StepMode.BRICK_BY_BRICK)
	assert(seq.get_total_steps() == manifest.size(), "Total steps must match manifest elements")

	var step_0_mesh: ArrayMesh = seq.reset()
	assert(step_0_mesh.get_surface_count() == 0, "Step 0 mesh should be empty")

	var step_1_mesh: ArrayMesh = seq.jump_to_step(1)
	assert(step_1_mesh.get_surface_count() == 1, "Step 1 should render bottom trim")

	var step_3_mesh: ArrayMesh = seq.jump_to_step(3)
	assert(step_3_mesh.get_surface_count() >= 2, "Step 3 should render trims + wall panel")

	var full_seq_mesh: ArrayMesh = seq.complete()
	assert(full_seq_mesh.get_surface_count() == 3, "Complete sequence should render all 3 surfaces")
	print("  [OK] Sequential controller successfully builds: Zócalo ➔ Panel ➔ Moldura ➔ Ladrillos")

	# 6. Validar Generación de Esquina en L (PieceType.CORNER)
	var corner_config: WallMeshConfig = config.duplicate_config()
	corner_config.piece_type = WallMeshConfig.PieceType.CORNER
	var corner_manifest: Array[Dictionary] = builder.build_brick_manifest(corner_config)
	assert(not corner_manifest.is_empty(), "Corner manifest must not be empty")

	var corner_mesh: ArrayMesh = builder.build_wall_mesh(corner_config)
	assert(corner_mesh != null and corner_mesh.get_surface_count() == 3, "Corner mesh must have all 3 surfaces")
	var corner_aabb: AABB = corner_mesh.get_aabb()
	assert(corner_aabb.size.x > 1.8 and corner_aabb.size.z > 1.8, "Corner should span in both X and Z dimensions")
	print("  [OK] L-Corner piece generated successfully. AABB: %.2f x %.2f x %.2f m" % [
		corner_aabb.size.x, corner_aabb.size.y, corner_aabb.size.z
	])

	# 7. Validar Generación de Arco de Entrada (PieceType.ARCH)
	var arch_config: WallMeshConfig = config.duplicate_config()
	arch_config.piece_type = WallMeshConfig.PieceType.ARCH
	var arch_manifest: Array[Dictionary] = builder.build_brick_manifest(arch_config)
	assert(not arch_manifest.is_empty(), "Arch manifest must not be empty")

	var arch_mesh: ArrayMesh = builder.build_wall_mesh(arch_config)
	assert(arch_mesh != null and arch_mesh.get_surface_count() == 3, "Arch mesh must have all 3 surfaces")
	var arch_aabb: AABB = arch_mesh.get_aabb()
	assert(arch_aabb.size.y > 3.5, "Arch height must be 2 cubes tall (~4m)")
	print("  [OK] Arch Doorway piece generated successfully. AABB: %.2f x %.2f x %.2f m" % [
		arch_aabb.size.x, arch_aabb.size.y, arch_aabb.size.z
	])

	# 8. Validar Fábrica de Materiales Estilizados
	var trim_mat = mat_script.create_trim_material(WallMaterialFactory.MaterialPreset.STYLIZED_SLATE)
	var panel_mat = mat_script.create_panel_material(WallMaterialFactory.MaterialPreset.STYLIZED_SLATE)
	var brick_mat = mat_script.create_brick_material(WallMaterialFactory.MaterialPreset.STYLIZED_SLATE)
	assert(trim_mat != null and panel_mat != null and brick_mat != null, "Materials must be created successfully")
	print("  [OK] WallMaterialFactory stylized slate palette verified")

	print("\n>>> ALL STYLIZED WALL MESH GENERATOR TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
