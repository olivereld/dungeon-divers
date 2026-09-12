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

void fragment() {
	vec4 tex_color = texture(texture_albedo, UV);
	if (tex_color.a < alpha_scissor_threshold) {
		discard;
	}
	ALBEDO = tex_color.rgb * foliage_tint.rgb;
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
