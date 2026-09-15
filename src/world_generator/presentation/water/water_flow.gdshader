shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// =============================================================================
// SHADER ESTILIZADO DE AGUA  (Zelda / Genshin / Anime Watercolor)
//
// Arquitectura de 4 capas independientes:
//   [1] SHORELINE  — silueta organica via SDF (multi-zona: discard, fade, foam, shallow, deep)
//   [2] DEPTH      — profundidad vertical real en world-space y gradiente multi-tono
//   [3] NOISE      — causticas sedosas + oleaje suave alineado sutilmente al flujo
//   [4] FOAM       — cinta de ribera organica desmenuzada con ruido + contacto 3D
//
// El SDF se codifica en COLOR.a como packed_sdf ∈ [0,1]:
//   > 0.5  → interior de agua  (signed_dist > 0)
//   = 0.5  → linea de costa exacta
//   < 0.5  → tierra (descartada o desvanecida en la orilla)
// =============================================================================

// ---------------------------------------------------------------------------
// [1] SHORELINE — parametros de silueta y borde
// ---------------------------------------------------------------------------
uniform float shore_noise_strength  : hint_range(0.0, 0.5) = 0.14; // Irregularidad organica de la orilla
uniform float shore_edge_fade       : hint_range(0.01, 0.3) = 0.08; // Anchura del fade alpha en el borde

// ---------------------------------------------------------------------------
// [2] DEPTH — gradiente de color y profundidad vertical
// ---------------------------------------------------------------------------
uniform vec4  color_shore           : source_color = vec4(0.25, 0.86, 0.88, 0.85); // Turquesa transparente de orilla
uniform vec4  color_shallow         : source_color = vec4(0.14, 0.74, 0.84, 0.88); // Azul poco profundo
uniform vec4  color_mid             : source_color = vec4(0.08, 0.52, 0.72, 0.92); // Azul intermedio
uniform vec4  color_deep            : source_color = vec4(0.04, 0.32, 0.52, 0.96); // Azul profundo
uniform vec4  shore_rim_color       : source_color = vec4(0.35, 0.92, 0.90, 0.90);
uniform float depth_max_distance    : hint_range(0.5, 10.0) = 2.8;

// ---------------------------------------------------------------------------
// [3] NOISE — superficie y movimiento
// ---------------------------------------------------------------------------
uniform sampler2D noise_texture     : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture     : hint_depth_texture, filter_nearest;
uniform vec2  noise_scale           = vec2(0.06, 0.06);
uniform float flow_speed            : hint_range(0.0, 3.0) = 0.45;
uniform float roughness             : hint_range(0.0, 1.0) = 0.08;
uniform float metallic              : hint_range(0.0, 1.0) = 0.02;
uniform float wave_normal_strength  : hint_range(0.0, 1.0) = 0.12;
uniform float caustic_intensity     : hint_range(0.0, 1.0) = 0.50;

// ---------------------------------------------------------------------------
// [4] FOAM — cinta de ribera + contacto
// ---------------------------------------------------------------------------
uniform vec4  foam_color            : source_color = vec4(0.96, 0.99, 1.0, 1.0);
uniform float shore_foam_width      : hint_range(0.02, 1.0) = 0.18; // Ancho de la cinta cremosa
uniform float shore_foam_intensity  : hint_range(0.0, 1.5) = 0.90;
uniform float contact_foam_width    : hint_range(0.02, 0.6) = 0.12; // Espuma contra obstaculos 3D

// ---------------------------------------------------------------------------
// Varyings
// ---------------------------------------------------------------------------
varying vec3 v_world_pos;
varying vec2 v_flow_dir;
varying float v_shore_sdf; // packed_sdf codificado en COLOR.a por ShorelineResolver

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_flow_dir  = UV2;
	v_shore_sdf = COLOR.a;
}

// =============================================================================
// fragment — 4 capas procesadas en orden armonico
// =============================================================================
void fragment() {

	// =========================================================================
	// [3] NOISE & FLOW — muestreo sutil y sereno (Block D.1)
	// =========================================================================
	vec2 base_uv = v_world_pos.xz * noise_scale;
	float flow_len = length(v_flow_dir);
	vec2 flow_dir_norm = flow_len > 0.001 ? (v_flow_dir / flow_len) : vec2(0.0);

	// Deriva ambiental suave (mantiene rios y lagos serenos)
	vec2 drift_uv1 = base_uv + vec2(TIME * 0.022,  TIME * 0.018);
	vec2 drift_uv2 = base_uv * 1.35 + vec2(-TIME * 0.016, TIME * 0.022);

	// Alineacion sutil de flujo para rios sin ondulaciones agresivas
	float flow_influence = smoothstep(0.0, 0.5, flow_len) * 0.40;
	vec2 flow_uv1 = base_uv + flow_dir_norm * (TIME * flow_speed * 0.22);
	vec2 flow_uv2 = base_uv * 1.35 - flow_dir_norm * (TIME * flow_speed * 0.12);

	vec2 final_uv1 = mix(drift_uv1, flow_uv1, flow_influence);
	vec2 final_uv2 = mix(drift_uv2, flow_uv2, flow_influence);

	float n1 = texture(noise_texture, final_uv1).r;
	float n2 = texture(noise_texture, final_uv2).r;
	float noise_val = (n1 + n2) * 0.5;

	// =========================================================================
	// [1] SHORELINE — Multi-zona SDF y silueta organica (Block C)
	// =========================================================================
	float shore_dist = (v_shore_sdf - 0.5) * 6.0;

	// Perturbacion organica leve de la orilla
	float shore_noise = (n1 - 0.5) * shore_noise_strength * 1.10
	                  + (n2 - 0.5) * shore_noise_strength * 0.60;
	float effective_dist = shore_dist + shore_noise;

	// Zona Discard: fragmentos mas alla de -0.05m se descartan
	if (effective_dist < -0.05) {
		discard;
	}

	// =========================================================================
	// [2] DEPTH — Profundidad vertical en World Space (Block E)
	// =========================================================================
	float depth_raw = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4  terrain_ndc  = vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vec4  terrain_view = INV_PROJECTION_MATRIX * terrain_ndc;
	terrain_view.xyz  /= terrain_view.w;
	vec4  terrain_world = INV_VIEW_MATRIX * vec4(terrain_view.xyz, 1.0);

	// Profundidad vertical real (independiente de la inclinacion de camara)
	float water_depth = max(v_world_pos.y - terrain_world.y, 0.0);

	// Gradiente de 3 tramos (Block D.3): shore -> shallow -> mid -> deep
	float depth_factor = clamp(water_depth / depth_max_distance, 0.0, 1.0);
	float depth_curve  = smoothstep(0.0, 1.0, depth_factor);

	vec3 water_color;
	if (depth_curve < 0.30) {
		water_color = mix(color_shore.rgb, color_shallow.rgb, depth_curve / 0.30);
	} else if (depth_curve < 0.70) {
		water_color = mix(color_shallow.rgb, color_mid.rgb, (depth_curve - 0.30) / 0.40);
	} else {
		water_color = mix(color_mid.rgb, color_deep.rgb, (depth_curve - 0.70) / 0.30);
	}

	// Resplandor cian suave cerca de la orilla
	float rim = smoothstep(0.35, 0.02, water_depth);
	water_color = mix(water_color, shore_rim_color.rgb, rim * 0.25);

	// =========================================================================
	// [3] NOISE — causticas y normales de oleaje
	// =========================================================================
	float caustic_a = smoothstep(0.48, 0.62, n1) * 0.14;
	float caustic_b = smoothstep(0.52, 0.66, n2) * 0.09;
	water_color += vec3(0.18, 0.35, 0.38) * (caustic_a + caustic_b) * caustic_intensity;

	vec2 eps = vec2(0.04, 0.0);
	float np_x = texture(noise_texture, final_uv1 + eps.xy).r
	           - texture(noise_texture, final_uv1 - eps.xy).r;
	float np_z = texture(noise_texture, final_uv1 + eps.yx).r
	           - texture(noise_texture, final_uv1 - eps.yx).r;
	vec3 ripple_norm = normalize(vec3(np_x * wave_normal_strength, 0.92, np_z * wave_normal_strength));
	NORMAL = normalize(mix(NORMAL, ripple_norm, 0.45));

	// =========================================================================
	// [4] FOAM — cinta cremosa desmenuzada con ruido (Block D.2) + contacto 3D
	// =========================================================================
	// Zona de cinta de orilla
	float foam_band = smoothstep(-0.01, 0.02, effective_dist)
	                * (1.0 - smoothstep(0.02, shore_foam_width, effective_dist));

	// Desmenuzado organico con ruido (clusters & gaps en la cinta)
	float foam_noise = texture(noise_texture, base_uv * 2.6 + vec2(TIME * 0.025, 0.0)).r;
	float foam_broken = foam_band * smoothstep(0.26, 0.54, foam_noise);

	float shore_breath = 0.88 + 0.12 * sin(TIME * 1.5 + dot(v_world_pos.xz, vec2(0.35, 0.25)));
	float shore_foam  = foam_broken * shore_breath * shore_foam_intensity;

	// Espuma de contacto con obstaculos
	float obstacle_depth = water_depth + (noise_val - 0.5) * 0.04;
	float contact_foam   = (1.0 - smoothstep(0.01, contact_foam_width, obstacle_depth)) * 0.60;

	float total_foam = clamp(max(shore_foam, contact_foam), 0.0, 1.0);

	// Espuma suprime las causticas para mantener orilla limpia
	water_color -= vec3(0.18, 0.35, 0.38) * (caustic_a + caustic_b) * caustic_intensity * total_foam;

	// =========================================================================
	// Composicion final (Multi-zona: fade_in, shallow, deep)
	// =========================================================================
	vec3 final_color = mix(water_color, foam_color.rgb, total_foam);

	// Zona fade_in [-0.05, 0.02]
	float visibility  = smoothstep(-0.05, 0.02, effective_dist);
	float edge_fade   = smoothstep(0.0, shore_edge_fade, effective_dist);
	float base_alpha  = mix(color_shore.a, color_deep.a, depth_curve);
	float final_alpha = clamp(max(base_alpha * edge_fade, total_foam) * visibility, 0.0, 1.0);

	ALBEDO    = final_color;
	ALPHA     = final_alpha;
	ROUGHNESS = mix(roughness, 0.85, total_foam);
	METALLIC  = metallic;
	SPECULAR  = 0.40;
}

// =============================================================================
// light — Difusa Half-Lambert + Especular estilizado
// =============================================================================
void light() {
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ALBEDO * (NdotL * 0.70 + 0.30) * ATTENUATION;

	vec3  H     = normalize(LIGHT + VIEW);
	float NdotH = max(dot(NORMAL, H), 0.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * pow(NdotH, 36.0) * 0.35;
}
