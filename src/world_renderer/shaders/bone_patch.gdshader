shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform vec3 tint_color : source_color = vec3(0.72, 0.70, 0.62);
uniform float threshold : hint_range(0.01, 0.4) = 0.06;
uniform float softness : hint_range(0.01, 0.3) = 0.10;
uniform float roughness : hint_range(0.0, 1.0) = 0.92;

void fragment() {
	vec4 col = texture(texture_albedo, UV);
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float a = smoothstep(threshold, threshold + softness, lum);
	
	// Sombra de contacto / Ambient occlusion hacia los bordes de los huesos sobre la tierra
	float edge_ao = smoothstep(threshold, threshold + softness * 2.0, lum);
	ALBEDO = col.rgb * tint_color * mix(0.40, 1.0, edge_ao);
	ALPHA = a;
	ROUGHNESS = roughness;
	SPECULAR = 0.05;
}
