shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// =============================================================================
// SHADER ESTILIZADO DE AGUA (Zelda / Genshin / Anime Watercolor)
//
// Arquitectura de 5 capas armónicas:
//   [1] SHORELINE  — silueta orgánica via SDF (multi-zona: discard, fade, foam, shallow, deep)
//   [2] DEPTH      — profundidad vertical real en world-space y gradiente cristalino multi-tono
//   [3] NOISE      — caústicas sedosas + oleaje suave multi-frecuencia sereno (estilo lago)
//   [4] FOAM       — cinta de ribera orgánica desmenuzada con ruido + contacto 3D
//   [5] RIPPLES    — oleaje interactivo, estela del personaje y anillos expansivos de pisadas
//
// El SDF se codifica en COLOR.a como packed_sdf ∈ [0,1]:
//   > 0.5  → interior de agua  (signed_dist > 0)
//   = 0.5  → línea de costa exacta
//   < 0.5  → tierra (descartada o desvanecida en la orilla)
// =============================================================================

// ---------------------------------------------------------------------------
// [1] SHORELINE — parámetros de silueta y borde
// ---------------------------------------------------------------------------
uniform float shore_noise_strength  : hint_range(0.0, 0.5) = 0.14; // Irregularidad orgánica de la orilla
uniform float shore_edge_fade       : hint_range(0.01, 0.3) = 0.08; // Anchura del fade alpha en el borde

// ---------------------------------------------------------------------------
// [2] DEPTH — gradiente de color, profundidad vertical y transparencia
// ---------------------------------------------------------------------------
uniform vec4  color_shore           : source_color = vec4(0.25, 0.88, 0.90, 0.45); // Turquesa cristalino y translúcido de orilla
uniform vec4  color_shallow         : source_color = vec4(0.14, 0.74, 0.84, 0.55); // Azul agua somera transparente
uniform vec4  color_mid             : source_color = vec4(0.08, 0.52, 0.72, 0.75); // Azul intermedio
uniform vec4  color_deep            : source_color = vec4(0.04, 0.32, 0.52, 0.88); // Azul profundo
uniform vec4  shore_rim_color       : source_color = vec4(0.35, 0.94, 0.92, 0.85);
uniform float depth_max_distance    : hint_range(0.5, 10.0) = 2.8;

// ---------------------------------------------------------------------------
// [3] NOISE — superficie, caústicas y oleaje sereno
// ---------------------------------------------------------------------------
uniform sampler2D noise_texture     : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture     : hint_depth_texture, filter_nearest;
uniform vec2  noise_scale           = vec2(0.055, 0.055);
uniform float flow_speed            : hint_range(0.0, 3.0) = 0.40;
uniform float roughness             : hint_range(0.0, 1.0) = 0.06;
uniform float metallic              : hint_range(0.0, 1.0) = 0.02;
uniform float wave_normal_strength  : hint_range(0.0, 1.0) = 0.14;
uniform float caustic_intensity     : hint_range(0.0, 1.0) = 0.55;

// ---------------------------------------------------------------------------
// [4] FOAM — cinta de ribera + contacto
// ---------------------------------------------------------------------------
uniform vec4  foam_color            : source_color = vec4(0.96, 0.99, 1.0, 1.0);
uniform float shore_foam_width      : hint_range(0.02, 1.0) = 0.18; // Ancho de la cinta cremosa
uniform float shore_foam_intensity  : hint_range(0.0, 1.5) = 0.90;
uniform float contact_foam_width    : hint_range(0.02, 0.6) = 0.12; // Espuma contra obstáculos 3D

// ---------------------------------------------------------------------------
// [5] INTERACTION — Oleaje interactivo y ondas de pisadas (Ripples)
// ---------------------------------------------------------------------------
uniform vec3  player_pos            = vec3(0.0, -100.0, 0.0);
uniform float player_speed          = 0.0;
uniform float player_in_water       = 0.0; // 1.0 cuando el personaje está en el agua
uniform vec4  ripples[8];                  // xy = world_xz, z = current_radius, w = current_alpha

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
// fragment — 5 capas procesadas en orden armónico
// =============================================================================
void fragment() {

	// =========================================================================
	// [3] NOISE & SURFACE DRIFT — Flujo sereno multi-capa estilo lago (Sin rayas)
	// =========================================================================
	vec2 base_uv = v_world_pos.xz * noise_scale;

	// Deriva ambiental armónica multi-capa (mantiene toda el agua continua y serena como el lago)
	vec2 drift_uv1 = base_uv + vec2(TIME * 0.022,  TIME * 0.017);
	vec2 drift_uv2 = base_uv * 1.36 + vec2(-TIME * 0.016, TIME * 0.021);
	vec2 drift_uv3 = base_uv * 0.72 + vec2(TIME * 0.010, -TIME * 0.014);

	float n1 = texture(noise_texture, drift_uv1).r;
	float n2 = texture(noise_texture, drift_uv2).r;
	float n3 = texture(noise_texture, drift_uv3).r;
	float noise_val = (n1 + n2 * 0.7 + n3 * 0.5) / 2.2;

	// =========================================================================
	// [1] SHORELINE — Multi-zona SDF y silueta orgánica (Block C)
	// =========================================================================
	float shore_dist = (v_shore_sdf - 0.5) * 6.0;

	// Perturbación orgánica suave de la orilla
	float shore_noise = (n1 - 0.5) * shore_noise_strength * 1.10
	                  + (n2 - 0.5) * shore_noise_strength * 0.60;
	float effective_dist = shore_dist + shore_noise;

	// Zona Discard: fragmentos más allá de -0.05m se descartan
	if (effective_dist < -0.05) {
		discard;
	}

	// =========================================================================
	// [2] DEPTH — Profundidad vertical en World Space y Transparencia Cristalina
	// =========================================================================
	float depth_raw = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4  terrain_ndc   = vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vec4  terrain_view  = INV_PROJECTION_MATRIX * terrain_ndc;
	terrain_view.xyz   /= terrain_view.w;
	vec4  terrain_world = INV_VIEW_MATRIX * vec4(terrain_view.xyz, 1.0);

	// Profundidad vertical real (independiente de la inclinación de cámara)
	float water_depth = max(v_world_pos.y - terrain_world.y, 0.0);

	// Gradiente de 3 tramos: shore -> shallow -> mid -> deep
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
	water_color = mix(water_color, shore_rim_color.rgb, rim * 0.20);

	// =========================================================================
	// [5] INTERACTION — Anillos de pisadas en el agua (Ripples estacionarios)
	// =========================================================================
	vec2 ripple_normal_offset = vec2(0.0);
	float ripple_foam = 0.0;

	// Anillo sutil de contacto con las piernas/cuerpo del personaje (delicado, radio ~0.45m)
	if (player_in_water > 0.1) {
		float d_player = length(v_world_pos.xz - player_pos.xz);
		if (d_player < 0.55) {
			float contact_ring = smoothstep(0.48, 0.35, d_player) * smoothstep(0.24, 0.35, d_player);
			ripple_foam += contact_ring * 0.40;
		}
	}

	// Anillos expansivos individuales de pisadas (estacionarios en world-space, sincronizados en GDScript)
	for (int i = 0; i < 8; i++) {
		float radius = ripples[i].z;
		float alpha  = ripples[i].w;
		if (alpha > 0.01 && radius > 0.01) {
			vec2 r_pos = ripples[i].xy;
			float d_rip = length(v_world_pos.xz - r_pos);
			float wave_delta = d_rip - radius;

			// Onda fina, estilizada y proporcionada al personaje
			float ring_pulse = exp(-pow(wave_delta * 9.0, 2.0)) * sin(wave_delta * 22.0);

			vec2 r_dir = d_rip > 0.001 ? (v_world_pos.xz - r_pos) / d_rip : vec2(0.0);
			ripple_normal_offset += r_dir * ring_pulse * alpha * 0.42;
			ripple_foam += max(ring_pulse * 1.5, 0.0) * alpha * 0.55;
		}
	}

	// =========================================================================
	// [3] NOISE — Caústicas acuarela y normales de oleaje
	// =========================================================================
	float caustic_a = smoothstep(0.46, 0.62, n1) * 0.15;
	float caustic_b = smoothstep(0.48, 0.64, n2) * 0.10;
	water_color += vec3(0.18, 0.38, 0.42) * (caustic_a + caustic_b) * caustic_intensity;

	vec2 eps = vec2(0.035, 0.0);
	float np_x = texture(noise_texture, drift_uv1 + eps.xy).r
	           - texture(noise_texture, drift_uv1 - eps.xy).r;
	float np_z = texture(noise_texture, drift_uv1 + eps.yx).r
	           - texture(noise_texture, drift_uv1 - eps.yx).r;

	vec3 wave_norm = normalize(vec3(
		np_x * wave_normal_strength + ripple_normal_offset.x,
		0.90,
		np_z * wave_normal_strength + ripple_normal_offset.y
	));
	NORMAL = normalize(mix(NORMAL, wave_norm, 0.55));

	// =========================================================================
	// [4] FOAM — Cinta cremosa de orilla + contacto 3D + crestas de oleaje
	// =========================================================================
	// Zona de cinta de orilla
	float foam_band = smoothstep(-0.01, 0.02, effective_dist)
	                * (1.0 - smoothstep(0.02, shore_foam_width, effective_dist));

	// Desmenuzado orgánico con ruido (clusters & gaps en la cinta)
	float foam_noise = texture(noise_texture, base_uv * 2.6 + vec2(TIME * 0.025, 0.0)).r;
	float foam_broken = foam_band * smoothstep(0.26, 0.54, foam_noise);

	float shore_breath = 0.88 + 0.12 * sin(TIME * 1.5 + dot(v_world_pos.xz, vec2(0.35, 0.25)));
	float shore_foam  = foam_broken * shore_breath * shore_foam_intensity;

	// Espuma de contacto con obstáculos
	float obstacle_depth = water_depth + (noise_val - 0.5) * 0.04;
	float contact_foam   = (1.0 - smoothstep(0.01, contact_foam_width, obstacle_depth)) * 0.60;

	float total_foam = clamp(max(shore_foam, contact_foam) + ripple_foam, 0.0, 1.0);

	// Espuma suprime las caústicas para mantener orilla limpia
	water_color -= vec3(0.18, 0.35, 0.38) * (caustic_a + caustic_b) * caustic_intensity * total_foam;

	// =========================================================================
	// Composición final (Transparencia gradual cristalina)
	// =========================================================================
	vec3 final_color = mix(water_color, foam_color.rgb, total_foam);

	// Zona fade_in [-0.05, 0.02]
	float visibility  = smoothstep(-0.05, 0.02, effective_dist);
	float edge_fade   = smoothstep(0.0, shore_edge_fade, effective_dist);

	// Curva de transparencia:
	// Aguas someras translúcidas (permite ver lecho y arena), profundizándose hacia aguas hondas
	float base_alpha  = mix(color_shore.a, color_deep.a, depth_curve);
	float final_alpha = clamp(max(base_alpha * edge_fade, total_foam * 0.95) * visibility, 0.0, 1.0);

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
