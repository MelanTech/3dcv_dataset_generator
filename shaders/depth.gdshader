shader_type spatial;
render_mode unshaded, depth_draw_never;

uniform float depth_factor : hint_range(0.0, 256.0, 0.1) = 80.0;
// 控制像素大小，值越大分辨率越低
uniform int pixel_size : hint_range(2, 32, 1) = 4;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture;

void fragment() {
    // 获取屏幕尺寸（纹素数量）
    ivec2 texture_size_i = textureSize(DEPTH_TEXTURE, 0);
    vec2 screen_size = vec2(texture_size_i);

    // 将当前 SCREEN_UV 转换为像素坐标
    vec2 pixel_coord = SCREEN_UV * screen_size;

    // 对像素坐标进行降采样和对齐：每 pixel_size 区域取左上角纹素
    ivec2 snapped_coord_i = (ivec2(pixel_coord / float(pixel_size))) * pixel_size;

    // 使用 texelFetch 精确获取该位置的深度值（nearest neighbor）
    float depth = texelFetch(DEPTH_TEXTURE, snapped_coord_i, 0).r;

    // 计算线性深度
    float linear_depth = 1.0 / (depth * INV_PROJECTION_MATRIX[2].w + INV_PROJECTION_MATRIX[3].w);

    // 输出伪彩色深度
    ALBEDO = vec3(linear_depth / depth_factor);
}