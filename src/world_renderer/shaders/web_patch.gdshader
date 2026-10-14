shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(0.65, 0.68, 0.72, 0.40);
uniform float brightness_boost : hint_range(0.5, 3.0) = 0.85;
uniform float threshold : hint_range(0.0, 0.3) = 0.04;
uniform float softness : hint_range(0.01, 0.3) = 0.15;

void fragment() {
	vec4 col = texture(texture_albedo, UV);
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float a = smoothstep(threshold, threshold + softness, lum);
	
	ALBEDO = col.rgb * tint_color.rgb * brightness_boost;
	ALPHA = a * tint_color.a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
