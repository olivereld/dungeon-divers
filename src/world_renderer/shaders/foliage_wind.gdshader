shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_toon, specular_disabled;

// --- Parámetros de textura y alpha mask ---
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform bool use_black_as_alpha = true;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.08;

// --- Colores y Gradiente Vertical ---
uniform bool use_gradient_texture = false;
uniform sampler2D gradient_texture : source_color, filter_linear_mipmap;
uniform float gradient_influence : hint_range(0.0, 1.0) = 0.20;
uniform bool use_upward_normals = true;
uniform vec4 color_bottom : source_color = vec4(0.20, 0.20, 0.10, 1.0);
uniform vec4 color_top : source_color = vec4(0.38, 0.44, 0.18, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.18, 0.20, 0.10, 1.0);
uniform float shadow_wrap : hint_range(0.0, 1.0) = 0.45;
uniform float direct_light_strength : hint_range(0.0, 2.0) = 0.75;

// --- Parámetros de Viento Procedural en GPU ---
uniform vec2 wind_direction = vec2(1.0, 0.3);
uniform float wind_strength : hint_range(0.0, 2.0) = 0.25;
uniform float wind_speed : hint_range(0.0, 10.0) = 1.6;
uniform float wind_frequency : hint_range(0.01, 2.0) = 0.30;

// --- Parámetros de Sombras de Nubes (Cloud Shadow) ---
uniform bool use_cloud_shadow = true;
uniform float cloud_shadow_intensity : hint_range(0.0, 1.0) = 0.28;
uniform float cloud_scale : hint_range(0.001, 0.1) = 0.035;
uniform vec2 cloud_speed = vec2(0.02, 0.012);

varying float v_height_ratio;
varying vec3 v_world_pos;
varying float v_cloud_factor;

void vertex() {
	// UV2.y almacena la fracción de altura (0.0 en la raíz, 1.0 en la punta)
	v_height_ratio = UV2.y;
	// Ponderación cúbica: la base se mantiene completamente firme en el suelo y solo ondea la punta
	float wind_weight = v_height_ratio * v_height_ratio * v_height_ratio;

	// Coordenadas de mundo para desfasar ondas de viento por instancia
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_pos = world_pos;
	float phase = dot(world_pos.xz, vec2(0.5, 0.7)) * wind_frequency;

	// Brisa lenta, suave y continua (sin rebotes ni quiebres bruscos)
	float wave1 = sin(TIME * wind_speed + phase);
	float wave2 = sin(TIME * (wind_speed * 0.65) + phase * 1.4) * 0.25;
	float total_wave = (wave1 + wave2) * wind_strength * wind_weight;

	vec2 dir = normalize(wind_direction);
	VERTEX.x += dir.x * total_wave;
	VERTEX.z += dir.y * total_wave;
	// Caída suave cuadrática (C1 continua, sin discontinuidad en cero)
	VERTEX.y -= (total_wave * total_wave) * 0.35;

	// Cálculo eficiente de sombra de nubes por vértice en espacio de mundo
	if (use_cloud_shadow) {
		vec2 cloud_uv = (world_pos.xz + TIME * cloud_speed) * cloud_scale;
		float c1 = sin(cloud_uv.x * 3.1415 + cloud_uv.y * 1.5);
		float c2 = cos(cloud_uv.x * 1.8 - cloud_uv.y * 2.7);
		float c_raw = smoothstep(-0.25, 0.65, (c1 + c2) * 0.5);
		v_cloud_factor = 1.0 - (c_raw * cloud_shadow_intensity);
	} else {
		v_cloud_factor = 1.0;
	}
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

	// Upward normals estilizadas: mezcla suave entre la normal del quad y la normal vertical del mundo
	// Otorga iluminación envolvente y esponjosa sin aplanar la tridimensionalidad individual de cada brizna
	if (use_upward_normals) {
		vec3 world_up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
		NORMAL = normalize(mix(NORMAL, world_up_view, 0.65));
	}

	// Gradiente vertical calibrado con el bioma (raíz fusionada con el suelo, punta iluminada)
	vec3 base_gradient = mix(color_bottom.rgb, color_top.rgb, v_height_ratio);
	vec3 gradient_col = base_gradient;

	if (use_gradient_texture) {
		// Muestreo macro en coordenadas mundiales para generar parches naturales
		float macro_var = sin(v_world_pos.x * 0.07 + v_world_pos.z * 0.11) * 0.5 + 0.5;
		float u = clamp(0.20 + macro_var * 0.60, 0.05, 0.95);
		float v = clamp(1.0 - v_height_ratio, 0.02, 0.98);
		vec3 tex_grad = texture(gradient_texture, vec2(u, v)).rgb;

		// Modulación con textura de gradiente botánico
		gradient_col = mix(base_gradient, tex_grad, gradient_influence);
	}

	// El detalle de la textura monocromática añade las hebras sin aplastar la raíz a negro
	float blade_detail = mix(0.75, 1.0, tex_color.r);
	ALBEDO = gradient_col * blade_detail * COLOR.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	// Iluminación Half-Lambert envolvente toon con sombras de nubes
	float NdotL = dot(NORMAL, LIGHT);
	float wrapped = clamp((NdotL + shadow_wrap) / (1.0 + shadow_wrap), 0.0, 1.0);
	vec3 direct_light = LIGHT_COLOR * ATTENUATION * (wrapped * direct_light_strength * v_cloud_factor);
	vec3 shadow_fill = shadow_tint.rgb * (1.0 - wrapped) * 0.35;
	// Calibrado idéntico a pino_foliage.gdshader (45% ambiente + contribución directa y sombras)
	DIFFUSE_LIGHT = DIFFUSE_LIGHT * 0.45 + ALBEDO * (direct_light + shadow_fill);
}
