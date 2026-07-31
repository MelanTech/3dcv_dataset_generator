shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float distortion_strength = 0.0;
uniform float distortion_zoom = 1.0;
uniform vec3 white_balance = vec3(1.0, 1.0, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv * 2.0 - 1.0;
	float r2 = dot(centered, centered);
	vec2 distorted = centered * (1.0 + distortion_strength * r2);
	vec2 sample_uv = distorted / max(distortion_zoom, 0.001) * 0.5 + 0.5;

	// Clamp instead of cropping so lens perturbation never produces black borders.
	sample_uv = clamp(sample_uv, vec2(0.0), vec2(1.0));

	vec4 color = texture(screen_texture, sample_uv);
	color.rgb = clamp(color.rgb * white_balance, vec3(0.0), vec3(1.0));
	COLOR = color;
}
