shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

// =============================================================================
// SHADER ESTILIZADO DE AGUA  (Zelda / Genshin / Anime Watercolor)
//
// Arquitectura de 4 capas independientes:
//   [1] SHORELINE  — silueta organica via SDF (discard + fade de borde)
//   [2] DEPTH      — gradiente de color segun profundidad submarina
//   [3] NOISE      — causticas suaves + normales de oleaje sedoso
//   [4] FOAM       — cinta cremosa de ribera + espuma de contacto 3D
//
// El SDF se codifica en COLOR.a como packed_sdf ∈ [0,1]:
//   > 0.5  → interior de agua  (signed_dist > 0)
//   = 0.5  → linea de costa exacta
//   < 0.5  → tierra (sera descartada por la capa Shoreline)
// =============================================================================

// ---------------------------------------------------------------------------
// [1] SHORELINE — parametros de silueta y borde
// ---------------------------------------------------------------------------
uniform float shore_noise_strength  : hint_range(0.0, 0.5) = 0.14; // Irregularidad organica de la orilla
uniform float shore_edge_fade       : hint_range(0.01, 0.3) = 0.06; // Anchura del fade alpha en el borde

// ---------------------------------------------------------------------------
// [2] DEPTH — gradiente de color y opacidad
// ---------------------------------------------------------------------------
uniform vec4  color_shallow         : source_color = vec4(0.14, 0.78, 0.86, 0.82);
uniform vec4  color_deep            : source_color = vec4(0.04, 0.38, 0.58, 0.96);
uniform vec4  shore_rim_color       : source_color = vec4(0.35, 0.92, 0.90, 0.90);
uniform float depth_max_distance    : hint_range(0.5, 10.0) = 2.8;

// ---------------------------------------------------------------------------
// [3] NOISE — superficie y movimiento
// ---------------------------------------------------------------------------
uniform sampler2D noise_texture     : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture     : hint_depth_texture, filter_nearest;
uniform vec2  noise_scale           = vec2(0.06, 0.06);
uniform float flow_speed            : hint_range(0.0, 3.0) = 0.55;
uniform float roughness             : hint_range(0.0, 1.0) = 0.08;
uniform float metallic              : hint_range(0.0, 1.0) = 0.02;
uniform float wave_normal_strength  : hint_range(0.0, 1.0) = 0.14;
uniform float caustic_intensity     : hint_range(0.0, 1.0) = 0.55; // Escala de causticas

// ---------------------------------------------------------------------------
// [4] FOAM — cinta de ribera + contacto
// ---------------------------------------------------------------------------
uniform vec4  foam_color            : source_color = vec4(0.96, 0.99, 1.0, 1.0);
uniform float shore_foam_width      : hint_range(0.02, 1.0) = 0.16; // Ancho de la cinta cremosa
uniform float shore_foam_intensity  : hint_range(0.0, 1.5) = 0.85;
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
// fragment — 4 capas procesadas en orden de dependencia
// =============================================================================
void fragment() {

	// =========================================================================
	// [3] NOISE — muestrear texturas antes de usarlas en otras capas
	// =========================================================================
	vec2 uv_offset1 = vec2(TIME * 0.025,  TIME * 0.020);
	vec2 uv_offset2 = vec2(-TIME * 0.018, TIME * 0.025);
	vec2 base_uv    = v_world_pos.xz * noise_scale;

	float n1 = texture(noise_texture, base_uv            + uv_offset1).r;
	float n2 = texture(noise_texture, base_uv * 1.35     + uv_offset2).r;
	float noise_val = (n1 + n2) * 0.5;

	// =========================================================================
	// [1] SHORELINE — determinar si este fragmento esta dentro o fuera del agua
	// =========================================================================
	// Convertir packed_sdf de [0,1] → distancia en metros reales
	// shore_dist > 0: interior del agua / shore_dist < 0: tierra
	float shore_dist = (v_shore_sdf - 0.5) * 6.0;

	// Perturbacion organica leve de la orilla con el ruido de la capa NOISE
	float shore_noise = (n1 - 0.5) * shore_noise_strength * 1.25
	                  + (n2 - 0.5) * shore_noise_strength * 0.70;
	float effective_dist = shore_dist + shore_noise;

	// Descartar fragmentos fuera del agua (silueta exacta del SDF + ruido)
	if (effective_dist < -0.01) {
		discard;
	}

	// =========================================================================
	// [2] DEPTH — color y opacidad segun profundidad submarina
	// =========================================================================
	// Reconstruccion de profundidad lineal del fondo submarino
	float depth_raw = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec3  ndc       = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4  view_pos  = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz   /= view_pos.w;
	float water_depth = max(VERTEX.z - view_pos.z, 0.0);

	float depth_factor = clamp(water_depth / depth_max_distance, 0.0, 1.0);
	float depth_curve  = smoothstep(0.0, 1.0, depth_factor);
	vec3  water_color  = mix(color_shallow.rgb, color_deep.rgb, depth_curve);

	// Resplandor cian suave cerca de la orilla (shallow rim)
	float rim = smoothstep(0.35, 0.02, water_depth);
	water_color = mix(water_color, shore_rim_color.rgb, rim * 0.30);

	// =========================================================================
	// [3] NOISE — causticas y normales de oleaje (continua)
	// =========================================================================
	// Causticas: franjas de brillo suave que simulan refraccion en el fondo
	float caustic_a = smoothstep(0.48, 0.62, n1) * 0.14;
	float caustic_b = smoothstep(0.52, 0.66, n2) * 0.09;
	// caustic_intensity escala ambas capas independientemente del foam
	water_color += vec3(0.18, 0.35, 0.38) * (caustic_a + caustic_b) * caustic_intensity;

	// Normales de oleaje suaves: perturbacion diferencial del muestreador de ruido
	vec2 eps = vec2(0.04, 0.0);
	float np_x = texture(noise_texture, base_uv + uv_offset1 + eps.xy).r
	           - texture(noise_texture, base_uv + uv_offset1 - eps.xy).r;
	float np_z = texture(noise_texture, base_uv + uv_offset1 + eps.yx).r
	           - texture(noise_texture, base_uv + uv_offset1 - eps.yx).r;
	vec3 ripple_norm = normalize(vec3(np_x * wave_normal_strength, 0.90, np_z * wave_normal_strength));
	NORMAL = normalize(mix(NORMAL, ripple_norm, 0.50));

	// =========================================================================
	// [4] FOAM — cinta cremosa en la orilla + espuma de contacto con obstaculos
	// =========================================================================

	// [4a] Cinta de ribera: banda entre effective_dist = 0 y shore_foam_width
	//      Respira con un seno suave (animacion lenta, no agresiva)
	float foam_band   = smoothstep(0.0, 0.02, effective_dist)
	                  * (1.0 - smoothstep(0.02, shore_foam_width, effective_dist));
	float shore_breath = 0.88 + 0.12 * sin(TIME * 1.8 + dot(v_world_pos.xz, vec2(0.35, 0.25)));
	float shore_foam  = foam_band * shore_breath * shore_foam_intensity;

	// [4b] Espuma de contacto: aparece donde un objeto 3D emerge cerca de la superficie
	float obstacle_depth = water_depth + (noise_val - 0.5) * 0.04;
	float contact_foam   = (1.0 - smoothstep(0.01, contact_foam_width, obstacle_depth)) * 0.65;

	// Combinar ambas capas de espuma (max, sin over-blend)
	float total_foam = clamp(max(shore_foam, contact_foam), 0.0, 1.0);

	// Espuma suprime las causticas para mantener la lectura limpia de la orilla
	water_color -= vec3(0.18, 0.35, 0.38) * (caustic_a + caustic_b) * caustic_intensity * total_foam;

	// =========================================================================
	// Composicion final
	// =========================================================================
	vec3 final_color = mix(water_color, foam_color.rgb, total_foam);

	// Fade de alpha en el borde del agua (suaviza el corte del discard)
	float edge_fade       = smoothstep(-0.02, shore_edge_fade, effective_dist);
	float base_alpha      = mix(color_shallow.a, color_deep.a, depth_curve);
	float final_alpha     = clamp(max(base_alpha * edge_fade, total_foam * edge_fade), 0.0, 1.0);

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
	// Difusa suave Half-Lambert (evita negros absolutos)
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ALBEDO * (NdotL * 0.70 + 0.30) * ATTENUATION;

	// Especular nitido estilizado (sin ruido centelleante)
	vec3  H     = normalize(LIGHT + VIEW);
	float NdotH = max(dot(NORMAL, H), 0.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * pow(NdotH, 36.0) * 0.35;
}
