shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// 1. Texturas Hand-Painted
// Cauce sumergido (Piedras de río / Stone_01)
uniform sampler2D riverbed_texture : source_color, filter_linear_mipmap, repeat_enable;
// Ribera / orilla inmediata (Tierra de orilla / Dirt_01)
uniform sampler2D sand_texture : source_color, filter_linear_mipmap, repeat_enable;
// Pradera / tierra plana abierta (Césped abierto / Grass_01)
uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_enable;
// Debajo de los árboles (Césped de sotobosque / Grass_03 y Tierra de pinar / Dirt_04)
uniform sampler2D forest_grass_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_dirt_texture : source_color, filter_linear_mipmap, repeat_enable;
// Acantilados / paredes verticales de roca (cliff_02.jpg)
uniform sampler2D cliff_texture : source_color, filter_linear_mipmap, repeat_enable;

// 2. Escalas de UV (Coordenadas de mundo XZ/YZ/XY)
uniform float riverbed_uv_scale : hint_range(0.05, 2.0) = 0.35;
uniform float sand_uv_scale : hint_range(0.05, 2.0) = 0.40;
uniform float grass_uv_scale : hint_range(0.05, 2.0) = 0.35;
uniform float forest_grass_uv_scale : hint_range(0.05, 2.0) = 0.35;
uniform float forest_dirt_uv_scale : hint_range(0.05, 2.0) = 0.35;
uniform float cliff_uv_scale : hint_range(0.05, 2.0) = 0.25;

// 3. Rangos métricos de orilla (en metros relativos a la línea de agua/espuma)
// Distancia positiva = dentro del agua; distancia negativa = tierra seca fuera del agua.
// Las rocas se mantienen sumergidas bajo el agua (a partir de +0.35m dentro del cauce)
uniform float rock_edge_offset : hint_range(-1.5, 1.5) = 0.35;
uniform float rock_to_sand_fade : hint_range(0.05, 1.0) = 0.25;

// La tierra cubre una franja sutil e inmediata de la orilla (~0.55m) antes de fundirse al césped
uniform float sand_edge_offset : hint_range(-3.0, 0.0) = -0.55;
uniform float sand_to_land_fade : hint_range(0.05, 1.0) = 0.35;

// 4. Parámetros PBR
uniform float roughness_land : hint_range(0.0, 1.0) = 0.88;
uniform float roughness_grass : hint_range(0.0, 1.0) = 0.85;
uniform float roughness_forest_grass : hint_range(0.0, 1.0) = 0.86;
uniform float roughness_forest_dirt : hint_range(0.0, 1.0) = 0.88;
uniform float roughness_sand : hint_range(0.0, 1.0) = 0.82;
uniform float roughness_riverbed : hint_range(0.0, 1.0) = 0.58;
uniform float roughness_cliff : hint_range(0.0, 1.0) = 0.86;

// Tintes opcionales
uniform vec4 riverbed_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 sand_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 grass_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 forest_grass_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 forest_dirt_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cliff_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 5. Parámetros de Integración Roca-Hierba (Overhang & Rim de contacto estilo Stylized Anime)
uniform float elevation_step_height : hint_range(0.5, 10.0) = 2.0;
uniform float base_height : hint_range(0.0, 10.0) = 2.0;
uniform float overhang_depth : hint_range(0.05, 1.0) = 0.35;
uniform float overhang_noise_scale : hint_range(0.5, 10.0) = 1.8;
uniform float dirt_rim_width : hint_range(0.02, 0.5) = 0.12;

varying vec3 v_world_pos;
varying vec3 v_normal;
varying vec4 v_color;
varying float v_tree_factor;
varying float v_cliff_dist;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_color = COLOR;
	v_tree_factor = clamp(UV2.x, 0.0, 1.0);
	v_cliff_dist = UV2.y;
}

void fragment() {
	// 1. Albedo base del terreno (césped, musgo, tierra y roca procedural)
	vec3 land_albedo = v_color.rgb;

	// 2. Muestreo Triplanar para evitar estiramientos en laderas
	vec3 blend_weights = abs(v_normal);
	blend_weights = normalize(max(blend_weights, 0.00001));
	float b_sum = blend_weights.x + blend_weights.y + blend_weights.z;
	blend_weights /= b_sum;

	// Muestreo Riverbed (Piedras del cauce / Stone_01)
	vec4 r_x = texture(riverbed_texture, v_world_pos.yz * riverbed_uv_scale);
	vec4 r_y = texture(riverbed_texture, v_world_pos.xz * riverbed_uv_scale);
	vec4 r_z = texture(riverbed_texture, v_world_pos.xy * riverbed_uv_scale);
	vec3 river_color = (r_x.rgb * blend_weights.x + r_y.rgb * blend_weights.y + r_z.rgb * blend_weights.z) * riverbed_tint.rgb;

	// Muestreo Sand (Tierra de ribera / orilla / Dirt_01)
	vec4 s_x = texture(sand_texture, v_world_pos.yz * sand_uv_scale);
	vec4 s_y = texture(sand_texture, v_world_pos.xz * sand_uv_scale);
	vec4 s_z = texture(sand_texture, v_world_pos.xy * sand_uv_scale);
	vec3 sand_color = (s_x.rgb * blend_weights.x + s_y.rgb * blend_weights.y + s_z.rgb * blend_weights.z) * sand_tint.rgb;

	// Muestreo Grass abierto (Grass_01 para tierra abierta con variación tonal y piedrecillas de Imagen 2)
	vec4 g_x = texture(grass_texture, v_world_pos.yz * grass_uv_scale);
	vec4 g_y = texture(grass_texture, v_world_pos.xz * grass_uv_scale);
	vec4 g_z = texture(grass_texture, v_world_pos.xy * grass_uv_scale);
	vec3 base_grass_sample = (g_x.rgb * blend_weights.x + g_y.rgb * blend_weights.y + g_z.rgb * blend_weights.z) * grass_tint.rgb;

	// Variación tonal orgánica y pequeñas manchas de tierra/gravilla en el césped superior (como en Imagen 2)
	float grass_micro_var = sin(v_world_pos.x * 2.2 + sin(v_world_pos.z * 1.8) * 1.5)
	                      * cos(v_world_pos.z * 2.2 + cos(v_world_pos.x * 1.8) * 1.5);
	float grass_micro_factor = clamp(grass_micro_var * 0.5 + 0.5, 0.0, 1.0);
	// Manchas de hierba tierna / más cálida
	vec3 enriched_grass = mix(base_grass_sample, base_grass_sample * 1.15, grass_micro_factor * 0.35);
	// Toques sutiles de tierra/piedrecillas incrustadas en el césped abierto
	float pebble_mask = smoothstep(0.72, 0.85, s_y.r * (1.0 - g_y.g * 0.5));
	vec3 open_grass_color = mix(enriched_grass, sand_color * 0.95, pebble_mask * 0.45);

	// Muestreo Forest Grass (Grass_03 para sotobosque bajo árboles)
	vec4 fg_x = texture(forest_grass_texture, v_world_pos.yz * forest_grass_uv_scale);
	vec4 fg_y = texture(forest_grass_texture, v_world_pos.xz * forest_grass_uv_scale);
	vec4 fg_z = texture(forest_grass_texture, v_world_pos.xy * forest_grass_uv_scale);
	vec3 forest_grass_color = (fg_x.rgb * blend_weights.x + fg_y.rgb * blend_weights.y + fg_z.rgb * blend_weights.z) * forest_grass_tint.rgb;

	// Muestreo Forest Dirt (Dirt_04 para tierra bajo árboles)
	vec4 fd_x = texture(forest_dirt_texture, v_world_pos.yz * forest_dirt_uv_scale);
	vec4 fd_y = texture(forest_dirt_texture, v_world_pos.xz * forest_dirt_uv_scale);
	vec4 fd_z = texture(forest_dirt_texture, v_world_pos.xy * forest_dirt_uv_scale);
	vec3 forest_dirt_color = (fd_x.rgb * blend_weights.x + fd_y.rgb * blend_weights.y + fd_z.rgb * blend_weights.z) * forest_dirt_tint.rgb;

	// Muestreo Cliff (Roca de acantilado / cliff_02.jpg)
	// Se invierte la coordenada vertical (-v_world_pos.y) porque en espacio UV el 0.0 está arriba,
	// alineando la cima iluminada de las rocas con la parte superior de los acantilados (+Y).
	vec4 c_x = texture(cliff_texture, vec2(v_world_pos.z, -v_world_pos.y) * cliff_uv_scale);
	vec4 c_y = texture(cliff_texture, v_world_pos.xz * cliff_uv_scale);
	vec4 c_z = texture(cliff_texture, vec2(v_world_pos.x, -v_world_pos.y) * cliff_uv_scale);
	vec3 cliff_color = (c_x.rgb * blend_weights.x + c_y.rgb * blend_weights.y + c_z.rgb * blend_weights.z) * cliff_tint.rgb;

	// 3. Combinación orgánica de Grass_03 y Dirt_04 debajo de los árboles:
	// Patrones de variación espacial / acumulación irregular de acículas y suelo húmedo
	float patch_noise = sin(v_world_pos.x * 0.75 + sin(v_world_pos.z * 0.5) * 2.0)
	                  * cos(v_world_pos.z * 0.75 + cos(v_world_pos.x * 0.5) * 2.0);
	float patch_factor = patch_noise * 0.5 + 0.5;

	// Cerca del tronco domina más Dirt_04, combinándose armónicamente con manchas de Grass_03
	float under_tree_dirt_weight = clamp(v_tree_factor * 0.40 + patch_factor * 0.60, 0.0, 1.0);
	vec3 under_tree_floor = mix(forest_grass_color, forest_dirt_color, under_tree_dirt_weight);
	float roughness_under_tree = mix(roughness_forest_grass, roughness_forest_dirt, under_tree_dirt_weight);

	// Transición suave entre césped abierto (Grass_01) y suelo bajo copa (Grass_03 + Dirt_04)
	vec3 land_floor = mix(open_grass_color, under_tree_floor, v_tree_factor);
	float land_floor_roughness = mix(roughness_grass, roughness_under_tree, v_tree_factor);

	// Acantilados muy pronunciados y paredes verticales revelan la roca de acantilado (cliff_02.jpg)
	float cliff_factor = 1.0 - smoothstep(0.35, 0.75, v_normal.y);
	vec3 cliff_blended = mix(cliff_color, land_albedo * cliff_color * 1.35, 0.20);

	// =========================================================================
	// INTEGRACIÓN ROCA-HIERBA: Grass Overhang & Contact Dirt Rim (Imagen 2)
	// =========================================================================
	// 1. Distancia vertical exacta desde la arista superior de esta pared
	float dist_from_top = v_cliff_dist;

	// 2. Ruido orgánico para la silueta irregular de flecos de hierba que cuelgan
	// Se proyecta a lo largo del plano horizontal perpendicular a la pared
	float wall_horiz = (abs(v_normal.x) > 0.5) ? v_world_pos.z : v_world_pos.x;
	float edge_wave1 = sin(wall_horiz * overhang_noise_scale * 3.14159);
	float edge_wave2 = sin(wall_horiz * overhang_noise_scale * 6.28318 + 1.2) * 0.4;
	float edge_noise = (edge_wave1 + edge_wave2) * 0.5; // [-0.7, 0.7]

	// Profundidad dinámica del borde que cuelga (Overhang)
	float dynamic_overhang = max(overhang_depth + edge_noise * (overhang_depth * 0.45), 0.05);

	// Factor de hierba que se derrama hacia abajo por el acantilado (solo en caras verticales)
	float overhang_mask = 1.0 - smoothstep(dynamic_overhang * 0.65, dynamic_overhang, dist_from_top);

	// Franja de tierra de contacto (Dirt Rim) justo en el límite inferior del fleco de hierba
	float dirt_rim_start = dynamic_overhang;
	float dirt_rim_end = dynamic_overhang + dirt_rim_width;
	float dirt_rim_mask = smoothstep(dynamic_overhang * 0.70, dirt_rim_start, dist_from_top)
	                    * (1.0 - smoothstep(dirt_rim_start, dirt_rim_end, dist_from_top));

	// Color de la pared del acantilado con el fleco de hierba y la franja de tierra integrados
	vec3 cliff_surface = cliff_blended;
	// Aplicar franja de tierra oscura / oclusión en el borde de contacto
	vec3 dirt_contact_color = mix(forest_dirt_color * 0.75, sand_color * 0.85, 0.40);
	cliff_surface = mix(cliff_surface, dirt_contact_color, dirt_rim_mask * 0.85);
	// Aplicar la hierba que cuelga encima
	cliff_surface = mix(cliff_surface, land_floor, overhang_mask);

	vec3 land_surface = mix(land_floor, cliff_surface, cliff_factor);
	float land_roughness = mix(land_floor_roughness, roughness_cliff, cliff_factor);
	if (cliff_factor > 0.5) {
		land_roughness = mix(land_roughness, roughness_grass, overhang_mask);
	}

	// 4. Factores de mezcla basados en el campo de distancia métrico (SDF en v_color.a)
	// v_color.a codifica el SDF normalizado de ShorelineResolver:
	// > 0.5: interior de agua; = 0.5: línea de orilla exacta; < 0.5: tierra seca.
	// Convertir a distancia con signo en metros (alcance +/- 3.0m):
	float shore_dist = (v_color.a - 0.5) * 6.0;

	// Las rocas de río cubren el lecho y sobresalen levemente de la espuma (-0.35m hacia afuera)
	float river_weight = smoothstep(rock_edge_offset - rock_to_sand_fade, rock_edge_offset, shore_dist);
	vec3 shore_color = mix(sand_color, river_color, river_weight);
	float roughness_shore = mix(roughness_sand, roughness_riverbed, river_weight);

	// La arena/tierra cubre la orilla inmediata y se funde hacia el césped hand-painted en tierra firme
	float shore_weight = smoothstep(sand_edge_offset - sand_to_land_fade, sand_edge_offset, shore_dist);

	// Mezcla armónica final: tierra firme (césped abierto o bajo árboles) -> tierra de ribera -> rocas de río
	ALBEDO = mix(land_surface, shore_color, shore_weight);
	ROUGHNESS = mix(land_roughness, roughness_shore, shore_weight);
	METALLIC = mix(0.0, 0.02, river_weight * shore_weight);
	SPECULAR = 0.05;
}
