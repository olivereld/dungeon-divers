extends SceneTree

const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")

func _init() -> void:
	var seed_val = 12345
	var profile = _AutumnForestWorldProfileScript.new()
	var config = _ChunkConfigScript.new(16, 1, 2)
	var shared_hydrology = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)

	print("hydro.shoreline_sdf size: ", shared_hydrology.shoreline_sdf.size())
	print("hydro.extended_water_heights size: ", shared_hydrology.extended_water_heights.size())

	# Now build chunk (1, 1) covering [16..31] x [16..31]
	# Let's inspect what chunk_world or WaterMeshBuilder does
	var chunk_world = _ChunkWorldScript.new()
	chunk_world.initialize(seed_val, profile, config, shared_hydrology, 2)
	chunk_world.load_initial_area(Vector2i.ZERO, 2)

	print("AFTER chunk load:")
	print("hydro.shoreline_sdf size: ", shared_hydrology.shoreline_sdf.size())
	print("hydro.extended_water_heights size: ", shared_hydrology.extended_water_heights.size())

	quit(0)
