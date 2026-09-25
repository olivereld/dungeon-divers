shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Shader para rocas estilizadas Taiga con paleta por gradiente
// Combina orientación de la normal de cara (flat shading), altura local
// y variación determinista por instancia (INSTANCE_CUSTOM).

uniform sampler2D gradient_palette : source_color, filter_linear_mipmap, repeat_disable;
uniform float min_height = -0.5;
uniform float max_height = 3.5;
uniform float normal_weight : hint_range(0.0, 1.0) = 0.55;
uniform float height_weight : hint_range(0.0, 1.0) = 0.45;
uniform float variation_strength : hint_range(0.0, 0.5) = 0.15;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float specular : hint_range(0.0, 1.0) = 0.15;

// Variables interpoladas desde vertex a fragment
varying float v_height_factor;
varying float v_instance_variation;
varying vec3 v_world_normal;

void vertex() {
	// Altura local normalizada de la malla (la geometría base de RockMeshBuilder va de Y ~ -0.2 a Y ~ 1.6)
	float h_range = max(0.01, max_height - min_height);
	v_height_factor = clamp((VERTEX.y - min_height) / h_range, 0.0, 1.0);

	// Variación por instancia (INSTANCE_CUSTOM.r en MultiMesh)
	if (INSTANCE_CUSTOM.r > 0.001) {
		v_instance_variation = (INSTANCE_CUSTOM.r - 0.5) * 2.0; // [-1.0, 1.0]
	} else {
		v_instance_variation = 0.0;
	}

	// Normal en espacio de mundo
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Orientación de la normal respecto al eje UP
	// up_dot va de -1.0 a 1.0
	float up_dot = dot(v_world_normal, vec3(0.0, 1.0, 0.0));
	
	// Caras superiores (up_dot > 0.3) reciben lectura clara; paredes (up_dot ~ 0) tono medio; base oscura
	float up_factor = clamp((up_dot + 0.35) / 1.35, 0.0, 1.0);

	// Combinación armónica: 55% orientación de cara, 45% altura local
	float raw_brightness = (up_factor * normal_weight) + (pow(v_height_factor, 0.8) * height_weight);
	raw_brightness += v_instance_variation * variation_strength;
	
	// Mapear al rango activo del gradiente (0.10 a 0.88 para evitar los extremos quemados)
	float brightness = clamp(mix(0.12, 0.88, raw_brightness), 0.05, 0.95);

	// En la textura gradient_rocks_01.jpg: V=0.0 es CLARO (cima), V=1.0 es OSCURO (base)
	float palette_v = 1.0 - brightness;
	vec4 rock_color = texture(gradient_palette, vec2(0.5, palette_v));

	ALBEDO = rock_color.rgb;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
