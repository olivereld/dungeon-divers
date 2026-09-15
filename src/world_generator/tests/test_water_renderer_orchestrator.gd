extends SceneTree

## Contractual test suite for BLOQUE 10: WaterRenderer as a Pure Orchestrator.
##
## Closing Criteria:
## 1. WaterRenderer has NO productive dependency on RiverMeshBuilder, LakeMeshBuilder, or WaterField.
## 2. Geometry belongs entirely to WaterMeshBuilder.
## 3. WaterRenderer.build_water_node delegates exclusively to WaterMeshBuilder.build_mesh(result, profile).
## 4. If valid ArrayMesh is returned, creates a single MeshInstance3D ("UnifiedWaterSurface") and assigns the canonical material.
## 5. WorldRenderer contract is preserved.

const _WorldGenerationContextScript = preload("res://src/world_generator/core/world_generation_context.gd")
const _TerrainStageScript = preload("res://src/world_generator/stages/terrain_stage.gd")
const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")
const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: WaterRenderer Orchestrator (Bloque 10)")
	print("==================================================")

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.cell_size = 2.0
	profile.hydrology_enabled = true

	var ctx = _WorldGenerationContextScript.new(4242, profile)
	var terrain_stage = _TerrainStageScript.new()
	terrain_stage.execute(ctx)
	var hydro_stage = _HydrologyStageScript.new()
	hydro_stage.execute(ctx)

	var result: WorldResult = ctx.result

	# [CHECK 1] Null safety
	assert(_WaterRendererScript.build_water_node(null) == null, "Null result must return null")
	var dummy_result := WorldResult.new()
	assert(_WaterRendererScript.build_water_node(dummy_result) == null, "Result without hydrology must return null")
	print("  [PASS] Check 1: Null safety verified.")

	# [CHECK 2] Direct Delegation: WaterMeshBuilder vs WaterRenderer
	var direct_mesh: ArrayMesh = _WaterMeshBuilderScript.build_mesh(result, profile)
	assert(direct_mesh != null and direct_mesh.get_surface_count() > 0, "WaterMeshBuilder must return valid ArrayMesh")

	var water_root: Node3D = _WaterRendererScript.build_water_node(result, profile)
	assert(water_root != null, "WaterRenderer must return valid Node3D")
	assert(water_root.name == "WaterRoot", "WaterRoot node name must match convention")

	# [CHECK 3] Single MeshInstance3D named "UnifiedWaterSurface"
	var mi: MeshInstance3D = water_root.get_node_or_null("UnifiedWaterSurface") as MeshInstance3D
	assert(mi != null, "WaterRoot must contain a MeshInstance3D child named 'UnifiedWaterSurface'")
	assert(mi.mesh != null, "MeshInstance3D must have a valid mesh")
	assert(mi.get_surface_override_material(0) != null, "MeshInstance3D must have material override at surface 0")

	# Verify vertex counts match between direct build_mesh and the orchestrated mesh
	var direct_arrays: Array = direct_mesh.surface_get_arrays(0)
	var mi_arrays: Array = mi.mesh.surface_get_arrays(0)
	var direct_v_count: int = (direct_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var mi_v_count: int = (mi_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	assert(direct_v_count == mi_v_count, "Orchestrated vertex count (%d) must match WaterMeshBuilder (%d)" % [mi_v_count, direct_v_count])
	print("  [PASS] Check 2 & 3: Direct delegation and single UnifiedWaterSurface MeshInstance3D verified.")

	# [CHECK 4] Wireframe Overlay option
	var water_root_wire: Node3D = _WaterRendererScript.build_water_node(result, profile, true)
	var wire_child: Node3D = water_root_wire.get_node_or_null("WaterWireframeOverlay") as Node3D
	assert(wire_child != null, "When show_wireframe=true, WaterWireframeOverlay must be present")
	print("  [PASS] Check 4: Optional wireframe inspection overlay verified.")

	print("==================================================")
	print(" ALL BLOQUE 10 WATER RENDERER TESTS PASSED!")
	print("==================================================")
	quit(0)
