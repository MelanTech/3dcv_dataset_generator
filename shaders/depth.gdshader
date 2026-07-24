shader_type spatial;
render_mode unshaded, depth_draw_never;

// 世界单位 -> 真实米 的缩放系数（含 shader 反投影的系统放大修正）。
// 由引擎内射线定标得出：中心命中桌面真实 11.75 世界单位(=1.175m)，反推系数 ≈0.0445。
uniform float world_scale : hint_range(0.0001, 0.1, 0.0001) = 0.0445;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture;

void fragment() {
	// 读取当前像素的非线性深度（逐像素，不做降采样，保证与 RGB 对齐）
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;

	// Godot4 使用 reverse-Z。用投影矩阵把 [0,1] 深度还原为视图空间线性深度（米前的世界单位）。
	// 视图空间线性深度 = 1 / (depth * INV[2].w + INV[3].w) 对应的 -z。
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	float linear_depth = -(view.z / view.w);

	// 世界单位 -> 真实米 -> 毫米，并裁剪到 16-bit 范围
	float depth_mm = clamp(linear_depth * world_scale * 1000.0, 0.0, 65535.0);

	// 16-bit 拆成高/低字节，分别写入 R、G 通道（RGB8 PNG 无损承载）
	float hi = floor(depth_mm / 256.0);
	float lo = depth_mm - hi * 256.0;

	ALBEDO = vec3(hi / 255.0, lo / 255.0, 0.0);
}
