shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 color_shallow : source_color = vec4(0.18, 0.45, 0.75, 0.95);
uniform vec4 color_deep : source_color = vec4(0.08, 0.22, 0.42, 0.98);
uniform float flow_speed : hint_range(0.0, 3.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.18;
uniform float metallic : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	vec2 flow_dir = UV2;
	float speed = (length(flow_dir) > 0.01) ? flow_speed : 0.05;
	vec2 moving_uv = UV + flow_dir * (TIME * speed);

	// Sutiles ondas direccionales según el vector de flujo
	float wave1 = sin(moving_uv.y * 5.0 + TIME * 1.5) * 0.03;
	float wave2 = cos(moving_uv.x * 4.0 - TIME * 1.0) * 0.02;

	// Gradiente de color y profundidad
	vec3 base_col = mix(color_shallow.rgb, color_deep.rgb, COLOR.r);
	ALBEDO = base_col + vec3(wave1 + wave2);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.45;
}
