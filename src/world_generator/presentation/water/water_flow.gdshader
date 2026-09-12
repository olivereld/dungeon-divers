shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

// =============================================================================
// SHADER ESTILIZADO DE AGUA (ZELDA / GENSHIN STYLE)
// - Gradiente de profundidad física con aguas someras turquesa y fondo azul marino.
// - Espuma de contacto nítida e irregular en orillas, rocas y muros.
// - Onda / ola dinámica que viaja rítmicamente hacia la ribera.
// - Normales animadas con ruido seamless de doble capa.
// - Destellos de sol centelleantes (sparkles) sobre la superficie.
// - Soporte direccional para ríos (UV2) y reposo en lagos.
// =============================================================================

// --- Colores y Gradiente ---
uniform vec4 color_shallow : source_color = vec4(0.13, 0.72, 0.78, 0.85); // Turquesa radiante somero
uniform vec4 color_deep : source_color = vec4(0.03, 0.23, 0.37, 0.98);    // Azul profundo oceánico
uniform vec4 shore_rim_color : source_color = vec4(0.24, 0.91, 0.86, 0.90); // Resplandor en la orilla
uniform vec4 foam_color : source_color = vec4(0.96, 0.99, 1.0, 1.0);        // Espuma blanca nítida
uniform float depth_max_distance : hint_range(0.5, 10.0) = 2.8;

// --- Espuma y Ondas de Orilla ---
uniform float foam_edge_width : hint_range(0.02, 0.8) = 0.22; // Espesor de contacto
uniform float wave_frequency : hint_range(0.5, 10.0) = 4.2;   // Frecuencia de la ola
uniform float wave_speed : hint_range(0.1, 5.0) = 1.6;        // Velocidad hacia la orilla
uniform float wave_max_depth : hint_range(0.2, 5.0) = 1.6;    // Rango de acción de la ola
uniform float wave_intensity : hint_range(0.0, 1.5) = 0.90;

// --- Superficie y Ruido ---
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

uniform vec2 noise_scale = vec2(0.07, 0.07);
uniform float flow_speed : hint_range(0.0, 3.0) = 0.6;
uniform float roughness : hint_range(0.0, 1.0) = 0.06;
uniform float metallic : hint_range(0.0, 1.0) = 0.05;
uniform float wave_normal_strength : hint_range(0.0, 1.0) = 0.32;
uniform float sparkle_strength : hint_range(0.0, 3.0) = 1.6;

varying vec3 v_world_pos;
varying vec2 v_flow_dir;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_flow_dir = UV2;
}

void fragment() {
	// 1. Reconstrucción de profundidad lineal del fondo submarino
	float depth_raw = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	float water_depth = max(VERTEX.z - view_pos.z, 0.0);

	// 2. Coordenadas de ruido animadas (según flujo fluvial o reposo lacustre)
	vec2 uv_offset1;
	vec2 uv_offset2;
	if (length(v_flow_dir) > 0.01) {
		vec2 flow_norm = normalize(v_flow_dir);
		uv_offset1 = flow_norm * (TIME * flow_speed);
		uv_offset2 = flow_norm * (TIME * flow_speed * 0.72) + vec2(sin(TIME * 0.4) * 0.03, 0.0);
	} else {
		uv_offset1 = vec2(TIME * 0.035, TIME * 0.025);
		uv_offset2 = vec2(-TIME * 0.025, TIME * 0.035);
	}

	vec2 base_uv = v_world_pos.xz * noise_scale;
	vec2 uv1 = base_uv + uv_offset1;
	vec2 uv2 = base_uv * 1.35 + uv_offset2;

	float n1 = texture(noise_texture, uv1).r;
	float n2 = texture(noise_texture, uv2).r;
	float noise_val = (n1 + n2) * 0.5;

	// 3. Efecto de ola y espuma de orilla
	// A) Espuma de contacto con rocas, orillas y muros (con perturbación de ruido)
	float dist_depth = water_depth + (noise_val - 0.5) * 0.16;
	float contact_foam = 1.0 - smoothstep(0.0, foam_edge_width, dist_depth);

	// B) Ola que viaja hacia la ribera
	float wave_phase = (water_depth * wave_frequency) - (TIME * wave_speed);
	float wave_sine = sin(wave_phase);
	float wave_crest = smoothstep(0.72, 0.95, wave_sine);
	float shore_band = smoothstep(wave_max_depth, 0.10, water_depth);
	float shore_wave = wave_crest * shore_band * wave_intensity * (n1 * 0.4 + 0.6);

	float total_foam = clamp(contact_foam + shore_wave, 0.0, 1.0);

	// 4. Gradiente de color según profundidad
	float depth_factor = clamp(water_depth / depth_max_distance, 0.0, 1.0);
	float depth_curve = smoothstep(0.0, 1.0, depth_factor);
	vec3 water_color = mix(color_shallow.rgb, color_deep.rgb, depth_curve);

	// Resplandor cian en la orilla somera
	float rim = smoothstep(0.5, 0.04, water_depth);
	water_color = mix(water_color, shore_rim_color.rgb, rim * 0.40);

	// Mezcla con la espuma blanca nítida
	vec3 final_color = mix(water_color, foam_color.rgb, total_foam);

	// Transparencia gradual
	float base_alpha = mix(color_shallow.a, color_deep.a, depth_curve);
	float final_alpha = clamp(max(base_alpha, total_foam), 0.0, 1.0);

	// 5. Normales de oleaje en la superficie
	vec2 eps = vec2(0.035, 0.0);
	float np_x = texture(noise_texture, uv1 + eps.xy).r - texture(noise_texture, uv1 - eps.xy).r;
	float np_z = texture(noise_texture, uv1 + eps.yx).r - texture(noise_texture, uv1 - eps.yx).r;
	vec3 ripple_norm = normalize(vec3(np_x * wave_normal_strength, 0.85, np_z * wave_normal_strength));
	NORMAL = normalize(mix(NORMAL, ripple_norm, 0.65));

	ALBEDO = final_color;
	ALPHA = final_alpha;
	ROUGHNESS = mix(roughness, 0.85, total_foam);
	METALLIC = metallic;
	SPECULAR = 0.50;
}

void light() {
	// Difusa Half-Lambert suave
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ALBEDO * (NdotL * 0.70 + 0.30) * ATTENUATION;

	// Especular nítido con destellos solares (sparkles)
	vec3 H = normalize(LIGHT + VIEW);
	float NdotH = max(dot(NORMAL, H), 0.0);
	float spec = pow(NdotH, 48.0);

	// Centelleo de partículas solares
	float sparkle_sample = texture(noise_texture, v_world_pos.xz * 0.35 + vec2(TIME * 0.15, -TIME * 0.12)).r;
	float sparkle = step(0.68, sparkle_sample) * pow(NdotH, 12.0) * sparkle_strength;

	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * (spec * 0.7 + sparkle * 1.4);
}
