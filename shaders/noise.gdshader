shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, ambient_light_disabled;

// 声明屏幕纹理，解决Godot 4中的SCREEN_TEXTURE移除问题
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// 噪点强度控制
uniform float noise_strength : hint_range(0, 0.5) = 0.1;
// 噪点颗粒大小
uniform float grain_size : hint_range(0.1, 512.0) = 2.0;
// 噪点随时间变化的速度
uniform float time_speed : hint_range(0, 5.0) = 1.0;
// 噪点颜色偏向（0为黑白，1为彩色）
uniform float color_noise : hint_range(0, 1.0) = 0.2;

// 简单的随机函数
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// 生成更自然的噪点图案
float noise(vec2 uv) {
    // 缩放UV坐标以控制噪点大小
    uv *= grain_size;
    
    // 添加时间变化，使噪点动态变化
    float time = TIME * time_speed;
    
    // 创建多层噪点以获得更自然的效果
    float n = rand(floor(uv) + vec2(time, -time));
    n += rand(floor(uv) + vec2(-time, time)) * 0.5;
    n += rand(floor(uv + 0.5) + vec2(time * 0.7, -time * 0.7)) * 0.25;
    
    return n / 1.75; // 归一化
}

// 彩色噪点生成函数
vec3 generate_color_noise(vec2 uv) {
    float time = TIME * time_speed;
    uv *= grain_size;
    
    // 为RGB三个通道生成不同的噪点
    float r = rand(floor(uv) + vec2(time, -time * 1.1));
    float g = rand(floor(uv) + vec2(-time * 1.2, time * 1.3));
    float b = rand(floor(uv) + vec2(time * 1.4, -time * 1.5));
    
    return vec3(r, g, b);
}

void fragment() {
    // 获取UV坐标
    vec2 uv = UV;
    
    // 生成基础噪点
    float base_noise = noise(uv) * 2.0 - 1.0; // 范围调整到[-1, 1]
    
    // 生成彩色噪点
    vec3 c_noise = generate_color_noise(uv) * 2.0 - 1.0;
    
    // 混合黑白噪点和彩色噪点
    vec3 final_noise = mix(vec3(base_noise), c_noise, color_noise);
    
    // 应用噪点强度
    final_noise *= noise_strength;
    
    // 获取背景颜色（通过深度纹理采样背后的颜色）
    vec3 background = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0).rgb;
    
    // 将噪点应用到背景上
    vec3 col = background + final_noise;
    
    // 确保颜色值在有效范围内
    col = clamp(col, 0.0, 1.0);
    
    // 输出最终颜色
    ALBEDO = col;
    // 设置透明度为1，确保噪点完全可见
    ALPHA = 1.0;
}
