class_name TerrainColorResolver
extends RefCounted

## Resolves authentic, procedural terrain albedo colors per vertex based on
## elevation, slope, moisture, and ecology canopy zones without storing Color
## data inside WorldCell or the generator core stages.
static func resolve_vertex_color(cell: WorldCell, profile: WorldProfile) -> Color:
	if cell == null:
		return profile.terrain_grass_color if profile != null else Color(0.25, 0.31, 0.20)

	if profile == null:
		profile = WorldProfile.new()

	# 1. Base Altimetric Land Substrate (Strictly Land: Loam -> Moss -> Grass -> Snow)
	# Absolutely no water or sand colors in terrain mesh.
	var base_col: Color
	var nh: float = clampf(cell.normalized_height, 0.0, 1.0)
	if nh < 0.20:
		# Valley bottoms / depressions: rich humus, peat, dark loam
		base_col = profile.terrain_loam_color.lerp(profile.terrain_moss_color, nh / 0.20)
	elif nh < 0.50:
		# Lowlands to rolling hills: moss to boreal meadow grass
		base_col = profile.terrain_moss_color.lerp(profile.terrain_grass_color, (nh - 0.20) / 0.30)
	elif nh < 0.80:
		# Slopes and upper plateau: boreal grass to rocky frost
		base_col = profile.terrain_grass_color.lerp(profile.terrain_rock_color, (nh - 0.50) / 0.30)
	else:
		# High peaks and ridges: cold exposed rock to snow / permafrost
		base_col = profile.terrain_rock_color.lerp(profile.terrain_snow_color, (nh - 0.80) / 0.20)

	# 2. Ecological Canopy Modulation (Forest understory vs Open lichen clearing)
	if cell.forest_density > 0.0:
		base_col = base_col.lerp(profile.forest_floor_color, clampf(cell.forest_density * 0.55, 0.0, 0.80))
	if cell.clearing_density > 0.0:
		base_col = base_col.lerp(profile.terrain_moss_color, clampf(cell.clearing_density * 0.40, 0.0, 0.60))

	# 3. Hygrometric Moisture Modulation (Moist soil darkens into rich humus)
	var moisture_delta: float = cell.moisture - 0.5
	if moisture_delta > 0.0:
		# Damp terrain leans towards darker loam
		base_col = base_col.lerp(profile.terrain_loam_color, moisture_delta * 0.40)
	else:
		# Dry terrain becomes slightly lighter / paler
		base_col = base_col.lightened(-moisture_delta * 0.08)

	# 4. Slope & Rock Exposure (Cliffs expose cold granite)
	var slope_factor: float = smoothstep(14.0, 32.0, cell.slope)
	var final_col: Color = base_col.lerp(profile.terrain_rock_color, slope_factor)
	final_col.a = 1.0

	return final_col

