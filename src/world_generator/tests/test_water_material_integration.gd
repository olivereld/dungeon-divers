extends SceneTree

## Contractual test suite for BLOQUE 11: Existing Material Integration & Decoupling.
##
## Closing Criteria:
## 1. Single productive path:
##    HydrologyResult -> water_cells -> WaterMeshBuilder -> 1 global ArrayMesh -> 1 MeshInstance3D -> existing WaterMaterial
## 2. WaterMeshBuilder has NO knowledge/import of:
##    - water_material.gd
##    - ShaderMaterial
##    - StandardMaterial3D
## 3. WaterRenderer is solely responsible for instantiating MeshInstance3D and attaching WaterMaterial.
## 4. WaterMaterial has NO knowledge/dependency on:
##    - River
##    - Lake
##    - WaterField
##    - bed_height
##    - hydrology
##    - carving
## 5. Material receives exclusively the final geometry without altering any height or hydraulic state.

const _WorldGenerationContextScript = preload("res://src/world_generator/core/world_generation_context.gd")
const _TerrainStageScript = preload("res://src/world_generator/stages/terrain_stage.gd")
const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldRendererScript = preload("res://src/world_renderer/world_renderer.gd")
const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")
const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")
const _WaterMaterialScript = preload("res://src/world_generator/presentation/water/water_material.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Water Material Integration (Bloque 11)")
	print("==================================================")

	_test_source_code_cleanliness()
	_test_productive_pipeline_integration()

	print("==================================================")
	print(" ALL BLOQUE 11 WATER MATERIAL TESTS PASSED!")
	print("==================================================")
	quit(0)

## Verifies that WaterMeshBuilder is 100% free of material dependencies
func _test_source_code_cleanliness() -> void:
	print("\n--- Check 1: Static Decoupling Analysis ---")

	var builder_file = FileAccess.open("res://src/world_generator/presentation/water/water_mesh_builder.gd", FileAccess.READ)
	assert(builder_file != null, "Could not open water_mesh_builder.gd")
	var builder_code: String = builder_file.get_as_text()
	builder_file.close()

	assert(not builder_code.contains("water_material"), "WaterMeshBuilder must NOT import water_material.gd")
	assert(not builder_code.contains("ShaderMaterial"), "WaterMeshBuilder must NOT import or instantiate ShaderMaterial")
	assert(not builder_code.contains("StandardMaterial3D"), "WaterMeshBuilder must NOT import or instantiate StandardMaterial3D")
	print("  [PASS] WaterMeshBuilder has zero material dependencies.")

	var material_file = FileAccess.open("res://src/world_generator/presentation/water/water_material.gd", FileAccess.READ)
	assert(material_file != null, "Could not open water_material.gd")
	var mat_code: String = material_file.get_as_text()
	material_file.close()

	assert(not mat_code.contains("River"), "WaterMaterial must not contain River logic")
	assert(not mat_code.contains("Lake"), "WaterMaterial must not contain Lake logic")
	assert(not mat_code.contains("WaterField"), "WaterMaterial must not contain WaterField logic")
	assert(not mat_code.contains("bed_height"), "WaterMaterial must not reference bed_height")
	assert(not mat_code.contains("carving"), "WaterMaterial must not reference carving")
	print("  [PASS] WaterMaterial has zero geometry/hydrology dependencies.")

## Verifies that the Taiga production pipeline attaches existing WaterMaterial to UnifiedWaterSurface
func _test_productive_pipeline_integration() -> void:
	print("\n--- Check 2: Productive Taiga Pipeline Verification ---")

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.cell_size = 2.0
	profile.hydrology_enabled = true

	var test_seeds = [4242, 12345]

	for s in test_seeds:
		var ctx = _WorldGenerationContextScript.new(s, profile)
		var terrain_stage = _TerrainStageScript.new()
		terrain_stage.execute(ctx)
		var hydro_stage = _HydrologyStageScript.new()
		hydro_stage.execute(ctx)

		var result: WorldResult = ctx.result

		# Render using canonical WorldRenderer
		var renderer = _WorldRendererScript.new()
		var world_node: Node3D = renderer.render_world(result, profile, false)
		assert(world_node != null, "WorldRenderer must produce valid root")

		# Locate WaterRoot
		var water_root: Node3D = world_node.get_node_or_null("WaterRoot") as Node3D
		assert(water_root != null, "RenderedWorld must contain WaterRoot child")

		# Locate UnifiedWaterSurface MeshInstance3D
		var mi: MeshInstance3D = water_root.get_node_or_null("UnifiedWaterSurface") as MeshInstance3D
		assert(mi != null, "WaterRoot must contain UnifiedWaterSurface MeshInstance3D")

		# Verify mesh is from WaterMeshBuilder
		assert(mi.mesh is ArrayMesh, "UnifiedWaterSurface mesh must be an ArrayMesh")
		assert(mi.mesh.get_surface_count() == 1, "UnifiedWaterSurface must have exactly 1 surface")

		# Verify material is the existing ShaderMaterial
		var mat: Material = mi.get_surface_override_material(0)
		assert(mat != null, "UnifiedWaterSurface must have material override at surface 0")
		assert(mat is ShaderMaterial, "Existing water material must be ShaderMaterial")

		var sm: ShaderMaterial = mat as ShaderMaterial
		assert(sm.shader != null, "ShaderMaterial must have an assigned shader")
		assert(sm.shader.resource_path.ends_with("water_flow.gdshader"), "Shader must be water_flow.gdshader")

		# Verify shader uniforms are bound without modifying geometry
		var c_shallow: Variant = sm.get_shader_parameter("color_shallow")
		var c_deep: Variant = sm.get_shader_parameter("color_deep")
		var noise_tex: Variant = sm.get_shader_parameter("noise_texture")
		assert(c_shallow != null and c_deep != null and noise_tex != null, "Shader uniforms must be configured")

		# Ensure no legacy river or lake mesh builders were invoked in this node
		assert(water_root.get_node_or_null("RiverMesh") == null, "RiverMesh must not exist in unified water presentation")
		assert(water_root.get_node_or_null("LakeMesh") == null, "LakeMesh must not exist in unified water presentation")

		renderer.queue_free()
		world_node.queue_free()

		print("  Seed %d: Single UnifiedWaterSurface with existing water_flow.gdshader verified!" % s)
