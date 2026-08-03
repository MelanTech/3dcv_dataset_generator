shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_disabled, depth_draw_never;

// 世界单位 -> 真实米 的缩放系数（含 shader 反投影的系统放大修正）。
// 由引擎内射线定标得出：中心命中桌面真实 11.75 世界单位(=1.175m)，反推系数 ≈0.0445。
uniform float world_scale : hint_range(0.0001, 0.1, 0.0001) = 0.0445;
uniform float distortion_strength = 0.0;
uniform float distortion_zoom = 1.0;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, repeat_disable, filter_nearest;


void vertex() {
	// Godot 4.3+ uses reversed-Z. Write the quad directly in clip space so this
	// pass always covers the viewport and samples the current viewport depth.
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}


float srgb_to_linear_channel(float value) {
	if (value <= 0.04045) {
		return value / 12.92;
	}
	return pow((value + 0.055) / 1.055, 2.4);
}


vec3 raw_bytes_to_output_color(vec3 raw_color) {
	// Forward+/Mobile render in linear space then convert to sRGB for the
	// captured viewport texture. Depth bytes are data, not display color, so
	// pre-convert them to preserve the final 8-bit channel values.
	if (OUTPUT_IS_SRGB) {
		return raw_color;
	}
	return vec3(
		srgb_to_linear_channel(raw_color.r),
		srgb_to_linear_channel(raw_color.g),
		srgb_to_linear_channel(raw_color.b)
	);
}


vec2 distort_uv(vec2 uv) {
	vec2 centered = uv * 2.0 - 1.0;
	float r2 = dot(centered, centered);
	vec2 distorted = centered * (1.0 + distortion_strength * r2);
	vec2 sample_uv = distorted / max(distortion_zoom, 0.001) * 0.5 + 0.5;
	return clamp(sample_uv, vec2(0.0), vec2(1.0));
}

void fragment() {
	vec2 depth_uv = distort_uv(SCREEN_UV);
	// 读取当前像素的非线性深度（逐像素，不做降采样，保证与 RGB 对齐）
	float depth = texture(DEPTH_TEXTURE, depth_uv).r;

	// Godot4 使用 reverse-Z：背景/远平面处 depth≈0。此类像素无有效几何，
	// 按深度相机约定输出 0（无效/无测量），与 OpenNI 参考图一致。
	if (depth <= 0.0) {
		ALBEDO = vec3(0.0, 0.0, 0.0);
	} else {
		// 用投影矩阵把 [0,1] 深度还原为视图空间线性深度（米前的世界单位）。
		vec3 ndc = vec3(depth_uv * 2.0 - 1.0, depth);
		vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view.xyz /= view.w;
		float linear_depth = -view.z;

		// 世界单位 -> 真实米 -> 毫米，并裁剪到 16-bit 范围
		float depth_mm = clamp(round(linear_depth * world_scale * 1000.0), 0.0, 65535.0);

		// 16-bit 拆成高/低字节，分别写入 R、G 通道（RGB8 PNG 无损承载）
		float hi = floor(depth_mm / 256.0);
		float lo = mod(depth_mm, 256.0);

		ALBEDO = raw_bytes_to_output_color(vec3(hi / 255.0, lo / 255.0, 0.0));
	}
}
