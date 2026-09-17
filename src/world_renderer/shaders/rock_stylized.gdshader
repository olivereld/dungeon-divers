shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// =============================================================================
// SHADER INTELIGENTE DE ROCAS ESTILIZADAS (HAND-PAINTED CHISELED ROCKS)
// Inspirado en las referencias visuales de rocas esculpidas:
// - Bordes filosos sutiles con opacidad controlada (chisel highlights suaves)
// - Grandes facetas cinceladas que atrapan la luz según orientación
// - Gradiente en altura (base oscura con oclusión vs cresta iluminada)
// - Vetas geológicas horizontales y textura hand-painted de piedra
// - Resalte de silueta (fresnel rim)
// =============================================================================

// 1. Texturas y Proyección
uniform sampler2D stone_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float triplanar_scale : hint_range(0.1, 4.0) = 0.90;
uniform float triplanar_sharpness : hint_range(1.0, 16.0) = 4.0;

// 2. Paleta de Colores de Pizarra / Grafito (Afinada a las referencias visuales)
uniform vec4 color_highlight : source_color = vec4(0.85, 0.90, 0.96, 1.0); // Filo suave azul hielo
uniform vec4 color_top : source_color = vec4(0.48, 0.54, 0.62, 1.0);       // Planos superiores / cielo
uniform vec4 color_mid : source_color = vec4(0.26, 0.30, 0.36, 1.0);       // Tono medio grafito / pizarra
uniform vec4 color_bottom : source_color = vec4(0.13, 0.15, 0.19, 1.0);    // Base inferior en sombra
uniform vec4 color_crevice : source_color = vec4(0.07, 0.08, 0.11, 1.0);   // Oclusión profunda de suelo

// 3. Control de Filos y Bordes (Líneas finas, suaves y semi-transparentes)
uniform float edge_opacity : hint_range(0.0, 1.0) = 0.35;                   // Opacidad reducida y suave
uniform float edge_width : hint_range(0.005, 0.12) = 0.038;                 // Línea fina no invasiva
uniform float edge_texture_influence : hint_range(0.0, 1.0) = 0.50;         // Modulación con textura mineral

// 4. Parámetros de Orientación y Posición
uniform float orientation_contrast : hint_range(0.0, 2.5) = 1.30;
uniform float height_gradient_strength : hint_range(0.0, 1.0) = 0.65;
uniform float sun_direction_influence : hint_range(0.0, 1.0) = 0.35;
uniform vec3 sun_direction = vec3(0.45, 0.75, 0.45);

// 5. Vetas y Relieve Geológico
uniform float strata_strength : hint_range(0.0, 0.5) = 0.14;
uniform float strata_frequency : hint_range(1.0, 25.0) = 7.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.20;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.88;
uniform float roughness_edge : hint_range(0.0, 1.0) = 0.65;

varying vec3 v_local_pos;
varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec3 v_local_normal;
varying vec3 v_edge_sharpness;
varying float v_height_factor;
varying vec2 v_barycentric;

void vertex() {
	v_local_pos = VERTEX;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_local_normal = NORMAL;
	v_edge_sharpness = COLOR.rgb;
	v_height_factor = COLOR.a;
	v_barycentric = UV2;
}

void fragment() {
	// 1. Coordenadas baricéntricas de la faceta
	vec3 bary = vec3(v_barycentric.x, v_barycentric.y, max(0.0, 1.0 - v_barycentric.x - v_barycentric.y));

	// 2. Muestreo Triplanar local de la textura de piedra (gira con cada roca)
	vec3 blend_weights = pow(abs(v_local_normal), vec3(triplanar_sharpness));
	blend_weights = max(blend_weights, vec3(0.0001));
	blend_weights /= (blend_weights.x + blend_weights.y + blend_weights.z);

	vec4 tex_x = texture(stone_texture, v_local_pos.yz * triplanar_scale);
	vec4 tex_y = texture(stone_texture, v_local_pos.xz * triplanar_scale);
	vec4 tex_z = texture(stone_texture, v_local_pos.xy * triplanar_scale);
	vec3 stone_tex = tex_x.rgb * blend_weights.x + tex_y.rgb * blend_weights.y + tex_z.rgb * blend_weights.z;
	float tex_luma = dot(stone_tex, vec3(0.299, 0.587, 0.114));

	// 3. Gradiente de Orientación 3D (Cielo cenital vs Suelo vs Sol clave)
	float normal_up = clamp(v_world_normal.y, -1.0, 1.0);

	// Alineación hacia la dirección solar
	vec3 sun_dir = normalize(sun_direction);
	float sun_align = clamp(dot(v_world_normal, sun_dir), -1.0, 1.0);
	float orientation_val = normal_up * 0.70 + sun_align * sun_direction_influence * 0.30;
	orientation_val = clamp(orientation_val * orientation_contrast, -1.0, 1.0);

	vec3 orientation_color;
	if (orientation_val >= 0.0) {
		// Facetas superiores iluminadas por cielo y sol (pizarra suave)
		orientation_color = mix(color_mid.rgb, color_top.rgb, orientation_val);
	} else {
		// Facetas inferiores en sombra propia
		orientation_color = mix(color_mid.rgb, color_bottom.rgb, -orientation_val);
	}

	// 4. Gradiente de Posición en Altura (Base enterrada en suelo vs Cima)
	float height_t = clamp(v_height_factor, 0.0, 1.0);
	float base_occlusion = smoothstep(0.40, 0.0, height_t);
	vec3 base_shaded = mix(orientation_color, color_crevice.rgb, base_occlusion * height_gradient_strength);

	// 5. Vetas geológicas horizontales sutiles (estratificación natural)
	float strata = sin(v_local_pos.y * strata_frequency + v_local_pos.x * 1.5 + v_local_pos.z * 1.2);
	float strata_factor = (strata * 0.5 + 0.5);
	base_shaded = mix(base_shaded, base_shaded * (0.88 + 0.24 * strata_factor), strata_strength);

	// 6. Fusión con la Textura Hand-Painted de Piedra
	vec3 textured_body = base_shaded * (stone_tex * 1.40 + 0.12);

	// 7. Detección Inteligente de Bordes Filosos con Opacidad Suave Controlada
	// Solo aristas con nitidez angular real (v_edge_sharpness > 0.18)
	float s0 = smoothstep(0.18, 0.65, v_edge_sharpness.r);
	float s1 = smoothstep(0.18, 0.65, v_edge_sharpness.g);
	float s2 = smoothstep(0.18, 0.65, v_edge_sharpness.b);

	// Distancia geométrica y en espacio de pantalla (línea fina y antialiased)
	vec3 d_bary = fwidth(bary);
	vec3 pixel_dist = bary / max(d_bary, vec3(0.0001));

	float geom_e0 = 1.0 - smoothstep(0.0, edge_width, bary.z);
	float geom_e1 = 1.0 - smoothstep(0.0, edge_width, bary.x);
	float geom_e2 = 1.0 - smoothstep(0.0, edge_width, bary.y);

	float pix_e0 = 1.0 - smoothstep(0.35, 1.35, pixel_dist.z);
	float pix_e1 = 1.0 - smoothstep(0.35, 1.35, pixel_dist.x);
	float pix_e2 = 1.0 - smoothstep(0.35, 1.35, pixel_dist.y);

	float e0 = max(geom_e0, pix_e0 * 0.70) * s0;
	float e1 = max(geom_e1, pix_e1 * 0.70) * s1;
	float e2 = max(geom_e2, pix_e2 * 0.70) * s2;

	// Agregación con curva suave (evita líneas duras / artificiales)
	float edge_raw = clamp(max(e0, max(e1, e2)), 0.0, 1.0);
	float edge_feathered = pow(edge_raw, 1.5);

	// Modulación de los bordes con la textura de piedra (mellas minerales y variabilidad natural)
	float edge_tex_mod = mix(0.70, tex_luma * 1.40, edge_texture_influence);

	// Opacidad sutil y translúcida (bajada de opacidad solicitada por el usuario):
	float edge_alpha = edge_feathered * edge_opacity * edge_tex_mod;

	// 8. Resalte Fresnel de Silueta (Rim lighting de las referencias)
	vec3 view_dir = normalize(VIEW);
	float fresnel = pow(1.0 - clamp(dot(v_world_normal, view_dir), 0.0, 1.0), 3.0);
	float rim = fresnel * rim_strength * (normal_up * 0.5 + 0.5);

	// 9. Composición Final del Albedo
	// Fusión suave semi-transparente sobre la roca (no reemplaza a 100% de blanco):
	vec3 final_albedo = mix(textured_body, color_highlight.rgb, edge_alpha);
	// Destello especular delicado en el canto
	final_albedo += color_highlight.rgb * (edge_alpha * 0.20);
	final_albedo += color_highlight.rgb * (rim * 0.40);

	ALBEDO = final_albedo;
	ROUGHNESS = mix(roughness_base, roughness_edge, edge_alpha);
	METALLIC = 0.0;
	SPECULAR = 0.05;
}
