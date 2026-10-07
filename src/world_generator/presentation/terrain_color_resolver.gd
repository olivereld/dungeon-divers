class_name TerrainColorResolver
extends RefCounted

const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")

## Resolves authentic, procedural terrain albedo colors per vertex based on
## biome rendering profile, elevation, slope, moisture, and ecology canopy zones.
static func resolve_vertex_color(cell: WorldCell, profile: WorldProfile) -> Color:
	if cell == null:
		return profile.terrain_grass_color if profile != null else Color(0.25, 0.31, 0.20)

	if profile == null:
		profile = WorldProfile.new()

	# 0. Obtener paleta cromática del RenderingProfile del bioma asignado
	var ground_col: Color = profile.terrain_grass_color
	var forest_col: Color = profile.forest_floor_color
	var clearing_col: Color = profile.terrain_moss_color
	var rock_col: Color = profile.terrain_rock_color
	var loam_col: Color = profile.terrain_loam_color
	var snow_col: Color = profile.terrain_snow_color

	if cell.biome_id != StringName():
		var reg: RefCounted = _BiomeRegistryScript.get_default()
		var biome_def = reg.get_definition(cell.biome_id)
		if biome_def != null and biome_def.rendering_profile != null:
			var rend = biome_def.rendering_profile
			ground_col = rend.ground_color
			forest_col = rend.forest_floor_color
			clearing_col = rend.clearing_color
			rock_col = rend.rock_color

	# 1. Base Altimetric Land Substrate (Strictly Land: Loam -> Moss/Clearing -> Grass/Ground -> Snow)
	# Absolutely no water or sand colors in terrain mesh.
	var base_col: Color
	var nh: float = clampf(cell.normalized_height, 0.0, 1.0)
	if nh < 0.20:
		# Valley bottoms / depressions: rich humus, peat, dark loam
		base_col = loam_col.lerp(clearing_col, nh / 0.20)
	elif nh < 0.50:
		# Lowlands to rolling hills: moss to boreal meadow grass
		base_col = clearing_col.lerp(ground_col, (nh - 0.20) / 0.30)
	elif nh < 0.80:
		# Slopes and upper plateau: boreal grass to rocky frost
		base_col = ground_col.lerp(rock_col, (nh - 0.50) / 0.30)
	else:
		# High peaks and ridges: cold exposed rock to snow / permafrost
		base_col = rock_col.lerp(snow_col, (nh - 0.80) / 0.20)

	# 2. Ecological Canopy Modulation (Forest understory vs Open lichen clearing)
	if cell.forest_density > 0.0:
		base_col = base_col.lerp(forest_col, clampf(cell.forest_density * 0.55, 0.0, 0.80))
	if cell.clearing_density > 0.0:
		base_col = base_col.lerp(clearing_col, clampf(cell.clearing_density * 0.40, 0.0, 0.60))

	# 3. Hygrometric Moisture Modulation (Moist soil darkens into rich humus)
	var moisture_delta: float = cell.moisture - 0.5
	if moisture_delta > 0.0:
		# Damp terrain leans towards darker loam
		base_col = base_col.lerp(loam_col, moisture_delta * 0.40)
	else:
		# Dry terrain becomes slightly lighter / paler
		base_col = base_col.lightened(-moisture_delta * 0.08)

	# 4. Slope & Rock Exposure (Cliffs expose cold granite)
	var slope_factor: float = smoothstep(14.0, 32.0, cell.slope)
	var final_col: Color = base_col.lerp(rock_col, slope_factor)
	final_col.a = 1.0

	return final_col

