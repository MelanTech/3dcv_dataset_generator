shader_type canvas_item;

// 把深度编码图（R=毫米高字节, G=低字节）解码为灰度做可视化预览。
// 仅用于屏幕显示，不影响保存的 16-bit PNG 数据。
// 近处亮、远处暗；无效(=0)显示为黑。

// 可视化归一化范围（毫米）。低于 near 记为最亮，高于 far 记为最暗。
uniform float near_mm = 300.0;
uniform float far_mm = 15000.0;

void fragment() {
	vec4 enc = texture(TEXTURE, UV);
	// 通道值是 [0,1]，还原为 0..255 字节再组 16-bit 毫米
	float hi = floor(enc.r * 255.0 + 0.5);
	float lo = floor(enc.g * 255.0 + 0.5);
	float depth_mm = hi * 256.0 + lo;

	if (depth_mm <= 0.0) {
		// 无效/背景：黑
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		float t = clamp((depth_mm - near_mm) / max(far_mm - near_mm, 1.0), 0.0, 1.0);
		// 近处亮、远处暗
		float g = 1.0 - t;
		COLOR = vec4(g, g, g, 1.0);
	}
}
