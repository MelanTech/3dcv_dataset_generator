shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
// 噪点强度（真实传感器噪点通常较弱）。建议 0.05 - 0.3。
uniform float strength : hint_range(0.0, 1.0, 0.001) = 0.15;
// 噪点颗粒大小（像素）。>1 时噪点变粗，像高 ISO 照片的大颗粒。建议 1.5 - 4。
uniform float grain_size : hint_range(1.0, 8.0, 0.1) = 4;

// 每像素伪随机数
float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 screen = texture(SCREEN_TEXTURE, SCREEN_UV);
	// 以 grain_size 为单位把屏幕划分为方块，同一方块共享噪声 -> 更粗的颗粒
	vec2 grain_uv = floor(FRAGCOORD.xy / grain_size);
	// 逐帧变化的随机种子
	float t = floor(TIME * 24.0);
	// 每个颜色通道独立取随机值 -> 彩色噪点
	float nr = rand(grain_uv + vec2(t, t * 0.7)) - 0.5;
	float ng = rand(grain_uv + vec2(t + 17.0, t * 0.7 + 5.0)) - 0.5;
	float nb = rand(grain_uv + vec2(t + 43.0, t * 0.7 + 11.0)) - 0.5;
	screen.rgb += vec3(nr, ng, nb) * strength;
	COLOR = vec4(clamp(screen.rgb, 0.0, 1.0), screen.a);
}
