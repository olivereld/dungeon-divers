shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform vec3 tint_color : source_color = vec3(0.92, 0.90, 0.85);
uniform float threshold : hint_range(0.01, 0.4) = 0.06;
uniform float softness : hint_range(0.01, 0.3) = 0.10;
uniform float roughness : hint_range(0.0, 1.0) = 0.92;

void fragment() {
	vec4 col = texture(texture_albedo, UV);
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float a = smoothstep(threshold, threshold + softness, lum);
	
	ALBEDO = col.rgb * tint_color;
	ALPHA = a;
	ROUGHNESS = roughness;
	SPECULAR = 0.05;
}
