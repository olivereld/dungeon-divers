class_name DungeonLightingController
extends RefCounted

## Translates an ArchetypeLightingProfile (defined in Archetype JSON) into active Godot Environment & DirectionalLight3D settings.
## Guarantees visual identity of archetypes without hardcoded visual parameters in scenes.

const _ArchetypeLightingProfileScript = preload("res://src/dungeon_generator/profiles/archetype_lighting_profile.gd")

func apply_lighting(
	profile: _ArchetypeLightingProfileScript,
	world_environment: WorldEnvironment,
	directional_light: DirectionalLight3D
) -> void:
	if profile == null:
		push_warning("[DungeonLightingController] ArchetypeLightingProfile is null. Using default fallback.")
		profile = _ArchetypeLightingProfileScript.new()

	# 1. Configure WorldEnvironment
	if world_environment != null:
		if world_environment.environment == null:
			world_environment.environment = Environment.new()

		var env: Environment = world_environment.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.01, 0.015, 0.02, 1.0)

		# Ambient Light
		if profile.ambient_enabled:
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = profile.ambient_color
			env.ambient_light_energy = profile.ambient_energy
		else:
			env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
			env.ambient_light_energy = 0.0

		# Fog
		env.fog_enabled = profile.fog_enabled
		if profile.fog_enabled:
			env.fog_light_color = profile.fog_color
			env.fog_density = profile.fog_density

		# Tonemap & Atmosphere
		env.tonemap_exposure = profile.exposure
		match profile.tonemap.to_upper():
			"ACES":
				env.tonemap_mode = Environment.TONE_MAPPER_ACES
			"FILMIC":
				env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			"REINHARD", "REINHARDT":
				env.tonemap_mode = Environment.TONE_MAPPER_REINHARDT
			_:
				env.tonemap_mode = Environment.TONE_MAPPER_LINEAR

		# Glow & SSAO for richness and dark crevice shadows
		env.glow_enabled = true
		env.glow_normalized = true
		env.glow_intensity = 0.7
		env.glow_bloom = 0.2
		env.ssao_enabled = true
		env.ssao_radius = 1.5
		env.ssao_intensity = 2.0

	# 2. Configure DirectionalLight3D
	if directional_light != null:
		directional_light.visible = profile.directional_enabled
		if profile.directional_enabled:
			directional_light.light_color = profile.directional_color
			directional_light.light_energy = profile.directional_energy
			directional_light.shadow_enabled = profile.directional_shadows
			directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
