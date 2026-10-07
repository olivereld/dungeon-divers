shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_toon, specular_disabled;

// --- Parámetros de textura y alpha mask ---
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform bool use_black_as_alpha = true;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.08;

// --- Colores y Gradiente Vertical ---
uniform vec4 color_bottom : source_color = vec4(0.18, 0.25, 0.14, 1.0);
uniform vec4 color_top : source_color = vec4(0.48, 0.65, 0.32, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.18, 0.32, 0.24, 1.0);
uniform float shadow_wrap : hint_range(0.0, 1.0) = 0.45;
uniform float direct_light_strength : hint_range(0.0, 2.0) = 0.85;

// --- Parámetros de Viento Procedural en GPU ---
uniform vec2 wind_direction = vec2(1.0, 0.3);
uniform float wind_strength : hint_range(0.0, 2.0) = 0.35;
uniform float wind_speed : hint_range(0.0, 10.0) = 2.0;
uniform float wind_frequency : hint_range(0.01, 2.0) = 0.35;

varying float v_height_ratio;

void vertex() {
	// UV2.y almacena la fracción de altura (0.0 en la raíz, 1.0 en la punta)
	v_height_ratio = UV2.y;
	float wind_weight = v_height_ratio * v_height_ratio;

	// Coordenadas de mundo para desfasar ondas de viento por instancia
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = dot(world_pos.xz, vec2(0.5, 0.7)) * wind_frequency;

	// Onda principal + armónico de ráfaga
	float wave1 = sin(TIME * wind_speed + phase);
	float wave2 = sin(TIME * wind_speed * 1.6 + phase * 1.3) * 0.35;
	float total_wave = (wave1 + wave2) * wind_strength * wind_weight;

	vec2 dir = normalize(wind_direction);
	VERTEX.x += dir.x * total_wave;
	VERTEX.z += dir.y * total_wave;
	VERTEX.y -= abs(total_wave) * 0.20;
}

void fragment() {
	vec4 tex_color = texture(texture_albedo, UV);

	// Soporte de transparencia tanto por canal alfa como por máscara negra en JPEGs
	float alpha_val = tex_color.a;
	if (use_black_as_alpha) {
		float max_channel = max(tex_color.r, max(tex_color.g, tex_color.b));
		alpha_val = min(alpha_val, max_channel);
	}

	if (alpha_val < alpha_scissor_threshold) {
		discard;
	}

	// Gradiente vertical de color desde la base hasta la punta
	vec3 gradient_col = mix(color_bottom.rgb, color_top.rgb, v_height_ratio);

	// Combinamos la textura con el gradiente y el color de instancia (COLOR.rgb) de MultiMesh
	ALBEDO = tex_color.rgb * gradient_col * COLOR.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	// Iluminación Half-Lambert envolvente toon matching pino_foliage.gdshader
	float NdotL = dot(NORMAL, LIGHT);
	float wrapped = clamp((NdotL + shadow_wrap) / (1.0 + shadow_wrap), 0.0, 1.0);
	vec3 direct_light = LIGHT_COLOR * ATTENUATION * (wrapped * direct_light_strength);
	vec3 shadow_fill = shadow_tint.rgb * (1.0 - wrapped) * 0.35;
	DIFFUSE_LIGHT = DIFFUSE_LIGHT * 0.45 + ALBEDO * (direct_light + shadow_fill);
}
