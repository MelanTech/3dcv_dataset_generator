shader_type canvas_item;

// 把深度编码图（R=毫米高字节, G=低字节）解码为灰度做可视化预览。
// 仅用于屏幕显示，不影响保存的 16-bit PNG 数据。
// 近处亮、远处暗；无效(=0)显示为黑。

// 可视化归一化范围（毫米）。低于 near 记为最亮，高于 far 记为最暗。
uniform float near_mm = 300.0;
uniform float far_mm = 15000.0;


float linear_to_srgb_channel(float value) {
	if (value <= 0.0031308) {
		return value * 12.92;
	}
	return 1.055 * pow(value, 1.0 / 2.4) - 0.055;
}


vec3 encoded_texture_to_raw_bytes(vec3 encoded_color) {
	// The depth pass pre-converts byte values before writing to the linear 3D
	// framebuffer. Canvas sampling returns linearized texture values, so convert
	// back to byte/sRGB space before unpacking R/G as high/low uint16 bytes.
	return vec3(
		linear_to_srgb_channel(encoded_color.r),
		linear_to_srgb_channel(encoded_color.g),
		linear_to_srgb_channel(encoded_color.b)
	);
}


void fragment() {
	vec4 enc = texture(TEXTURE, UV);
	vec3 raw = encoded_texture_to_raw_bytes(enc.rgb);
	// 通道值是 [0,1]，还原为 0..255 字节再组 16-bit 毫米
	float hi = floor(raw.r * 255.0 + 0.5);
	float lo = floor(raw.g * 255.0 + 0.5);
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
