class_name TerrainColorResolver
extends RefCounted

## Resolves authentic, procedural terrain albedo colors per vertex based on
## elevation, slope, moisture, and ecology canopy zones without storing Color
## data inside WorldCell or the generator core stages.
static func resolve_vertex_color(cell: WorldCell, profile: WorldProfile) -> Color:
	if cell == null:
		return profile.terrain_mid_color if profile != null else Color(0.27, 0.35, 0.21)

	if profile == null:
		profile = WorldProfile.new()

	# 1. Base Altimetric Color
	# 8-zone height gradient matching Lab UI palette:
	# deepWater: 0 - 0.27
	# water:     0.27 - 0.35
	# sand:      0.35 - 0.41
	# ground:    0.41 - 0.50
	# grass:     0.50 - 0.67
	# forest:    0.67 - 0.77
	# rock:      0.77 - 0.88
	# snow:      0.88 - 1.00
	var base_col: Color
	var nh: float = clampf(cell.normalized_height, 0.0, 1.0)
	if nh < 0.27:
		base_col = profile.color_deep_water.lerp(profile.color_water, nh / 0.27)
	elif nh < 0.35:
		base_col = profile.color_water.lerp(profile.color_sand, (nh - 0.27) / 0.08)
	elif nh < 0.41:
		base_col = profile.color_sand.lerp(profile.color_ground, (nh - 0.35) / 0.06)
	elif nh < 0.50:
		base_col = profile.color_ground.lerp(profile.color_grass, (nh - 0.41) / 0.09)
	elif nh < 0.67:
		base_col = profile.color_grass.lerp(profile.color_forest, (nh - 0.50) / 0.17)
	elif nh < 0.77:
		base_col = profile.color_forest.lerp(profile.color_rock, (nh - 0.67) / 0.10)
	elif nh < 0.88:
		base_col = profile.color_rock.lerp(profile.color_snow, (nh - 0.77) / 0.11)
	else:
		base_col = profile.color_snow

	# 2. Ecological Canopy Modulation (Forest understory vs Open lichen clearing)
	if cell.forest_density > 0.0:
		base_col = base_col.lerp(profile.color_forest, clampf(cell.forest_density * 0.45, 0.0, 0.70))
	if cell.clearing_density > 0.0:
		base_col = base_col.lerp(profile.clearing_color, clampf(cell.clearing_density * 0.40, 0.0, 0.60))

	# 3. Hygrometric Moisture Tint
	var moisture_factor: float = (cell.moisture - 0.5) * 0.15
	base_col.r = clampf(base_col.r - moisture_factor * 0.5, 0.0, 1.0)
	base_col.g = clampf(base_col.g + moisture_factor * 0.5, 0.0, 1.0)
	base_col.b = clampf(base_col.b + moisture_factor * 0.2, 0.0, 1.0)

	# 4. Slope & Rock Exposure
	var slope_factor: float = smoothstep(14.0, 32.0, cell.slope)
	var final_col: Color = base_col.lerp(profile.color_rock, slope_factor)
	final_col.a = 1.0

	return final_col
