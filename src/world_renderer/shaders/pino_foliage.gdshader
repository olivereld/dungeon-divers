shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_toon, specular_disabled;

// --- Parámetros de textura y alpha scissor ---
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

// --- Ajustes estilizados de iluminación ---
uniform vec4 foliage_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Tinte fresco bosque/esmeralda para sombras profundas (evita negros planos)
uniform vec4 shadow_tint : source_color = vec4(0.18, 0.32, 0.24, 1.0);
// Half-Lambert wrap: expande la difusión de luz sobre las ramas
uniform float shadow_wrap : hint_range(0.0, 1.0) = 0.45;
// Atenuación de luz directa para no quemar los colores pintados a mano
uniform float direct_light_strength : hint_range(0.0, 2.0) = 0.85;

// --- Parámetros de Viento Procedural en GPU (Copas y Follaje) ---
uniform vec2 wind_direction = vec2(1.0, 0.3);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.08;
uniform float wind_speed : hint_range(0.0, 10.0) = 1.4;
uniform float wind_frequency : hint_range(0.01, 2.0) = 0.20;
uniform float trunk_height_threshold : hint_range(0.0, 3.0) = 0.5;
uniform float canopy_height_range : hint_range(0.5, 8.0) = 3.5;

void vertex() {
	// Anclaje al suelo: el tronco inferior no se desplaza
	float height_above_trunk = max(0.0, VERTEX.y - trunk_height_threshold);
	float canopy_factor = clamp(height_above_trunk / canopy_height_range, 0.0, 1.0);
	float wind_weight = canopy_factor * canopy_factor;

	// Coordenadas de mundo para mantener el mismo frente de onda y sincronización que el césped
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = dot(world_pos.xz, vec2(0.5, 0.7)) * wind_frequency;

	// Onda suave y con inercia para árboles grandes
	float wave1 = sin(TIME * wind_speed + phase);
	float wave2 = sin(TIME * (wind_speed * 1.5) + phase * 1.2) * 0.30;
	float total_wave = (wave1 + wave2) * wind_strength * wind_weight;

	// Micro-aleteo sutil en las puntas de las ramas
	float branch_flutter = sin(TIME * (wind_speed * 2.2) + VERTEX.y * 2.5 + phase) * (wind_strength * 0.12) * canopy_factor;

	vec2 dir = normalize(wind_direction);
	VERTEX.x += dir.x * (total_wave + branch_flutter);
	VERTEX.z += dir.y * (total_wave + branch_flutter);
	VERTEX.y -= abs(total_wave) * 0.10;
}

void fragment() {
	vec4 tex_color = texture(texture_albedo, UV);
	if (tex_color.a < alpha_scissor_threshold) {
		discard;
	}
	ALBEDO = tex_color.rgb * foliage_tint.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	// Iluminación Half-Lambert: envuelve la luz de forma continua y suave
	float NdotL = dot(NORMAL, LIGHT);
	float wrapped = clamp((NdotL + shadow_wrap) / (1.0 + shadow_wrap), 0.0, 1.0);

	// Luz directa calibrada: evita sobre-exposición blanca en la textura
	vec3 direct_light = LIGHT_COLOR * ATTENUATION * (wrapped * direct_light_strength);

	// Relleno estilizado en sombra con tono bosque profundo
	vec3 shadow_fill = shadow_tint.rgb * (1.0 - wrapped) * 0.35;

	// Moderamos la luz ambiente base y agregamos la contribución de la luz
	DIFFUSE_LIGHT = DIFFUSE_LIGHT * 0.45 + ALBEDO * (direct_light + shadow_fill);
}
