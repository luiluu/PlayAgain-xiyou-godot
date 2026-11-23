shader_type canvas_item;
// 【小A·未经审查】三阶徐凤年回归漫画动画 P1 实时入格黑白半调网点着色器（T428；分镜 v0.5 拆卡 3）。
// 兼容 gl_compatibility（GLES3 / OpenGL 3.3 Core）：
// - 4 邻亮度梯度勾勒墨线轮廓（#0B0B0E）
// - 45° 旋转半调网点呈黑白灰漫画质感（#F4F2EC 纸白 / #0B0B0E 墨点）
// - 仅中心二阶漩涡高紫度区域保留克制幽紫微点（#8F5CEB），其余画面纯黑白网点
// - mix_amount 支持 P1 前 0.3s 实机彩色平滑收束进漫画网点；zoom 支持格内 1.00x -> 1.04x 居中缓推

uniform float mix_amount : hint_range(0.0, 1.0) = 1.0;
uniform float zoom : hint_range(1.0, 1.25) = 1.0;
uniform vec2 panel_size = vec2(550.0, 430.0);
uniform float dot_spacing : hint_range(3.0, 12.0) = 5.5;
uniform float edge_strength : hint_range(0.0, 3.0) = 1.45;
uniform float edge_threshold : hint_range(0.05, 0.5) = 0.16;
uniform float vortex_keep : hint_range(0.0, 1.0) = 0.78;
uniform vec3 ink_color : source_color = vec3(0.043, 0.043, 0.055);
uniform vec3 paper_color : source_color = vec3(0.957, 0.949, 0.925);
uniform vec3 purple_color : source_color = vec3(0.561, 0.361, 0.922);

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

float luma_of(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 z_uv = (UV - vec2(0.5)) / max(zoom, 1.0) + vec2(0.5);
	vec2 clamped_uv = clamp(z_uv, vec2(0.0), vec2(1.0));
	vec4 src = texture(TEXTURE, clamped_uv);
	float luma = luma_of(src.rgb);

	// 1) 高对比漫画明暗曲线，拉开纸白高光、灰阶网点与深墨阴影层次
	float tone = clamp((luma - 0.10) * 1.26, 0.0, 1.0);
	tone = mix(tone, smoothstep(0.06, 0.94, tone), 0.48);

	// 2) 四邻亮度梯度勾勒墨线，保住实机方桌大厅石砖与家具轮廓清晰度
	vec2 px = TEXTURE_PIXEL_SIZE * 1.25;
	float l_r = luma_of(texture(TEXTURE, clamp(clamped_uv + vec2(px.x, 0.0), vec2(0.0), vec2(1.0))).rgb);
	float l_l = luma_of(texture(TEXTURE, clamp(clamped_uv - vec2(px.x, 0.0), vec2(0.0), vec2(1.0))).rgb);
	float l_d = luma_of(texture(TEXTURE, clamp(clamped_uv + vec2(0.0, px.y), vec2(0.0), vec2(1.0))).rgb);
	float l_u = luma_of(texture(TEXTURE, clamp(clamped_uv - vec2(0.0, px.y), vec2(0.0), vec2(1.0))).rgb);
	float grad = length(vec2(l_r - l_l, l_d - l_u));
	float ink_edge = smoothstep(edge_threshold, edge_threshold + 0.16, grad * edge_strength);

	// 3) 45° 旋转半调网点（按格内像素尺寸计算，避免贴图分辨率变化导致网点发糊）
	vec2 p = clamped_uv * max(panel_size, vec2(64.0, 64.0));
	vec2 rot_p = vec2(p.x * 0.70710678 - p.y * 0.70710678, p.x * 0.70710678 + p.y * 0.70710678);
	vec2 cell = fract(rot_p / max(dot_spacing, 2.0)) - vec2(0.5);
	float dist = length(cell);
	float dot_radius = clamp((1.0 - tone) * 0.62, 0.0, 0.58);
	float dot_mask = 1.0 - smoothstep(dot_radius - 0.08, dot_radius + 0.08, dist);

	// 极暗部压实墨黑、极亮部留净纸白、中间灰阶走经典半调网点
	vec3 halftone_rgb = mix(paper_color, ink_color, dot_mask);
	float deep_shadow = 1.0 - smoothstep(0.08, 0.22, tone);
	float clean_hi = smoothstep(0.88, 0.99, tone);
	halftone_rgb = mix(halftone_rgb, ink_color, deep_shadow);
	halftone_rgb = mix(halftone_rgb, paper_color, clean_hi * 0.88);

	// 叠加墨线轮廓与极轻四边印刷暗框
	vec3 comic_rgb = mix(halftone_rgb, ink_color, ink_edge * 0.90);
	vec2 edge_d = min(clamped_uv, vec2(1.0) - clamped_uv);
	float border_vignette = smoothstep(0.0, 0.045, min(edge_d.x, edge_d.y));
	comic_rgb = mix(mix(comic_rgb, ink_color, 0.22), comic_rgb, border_vignette);

	// 4) 仅中心二阶漩涡高紫度区域保留极淡幽紫微点（#8F5CEB），其余画面严格黑白
	float min_rb = min(src.r, src.b);
	float purple_excess = clamp((min_rb - src.g) * 3.6, 0.0, 1.0) * smoothstep(0.20, 0.62, src.b);
	float center_bias = 1.0 - smoothstep(0.18, 0.60, length(clamped_uv - vec2(0.5, 0.44)));
	float purple_mask = clamp(purple_excess * (0.45 + 0.55 * center_bias) * vortex_keep, 0.0, 0.88);
	vec3 purple_dot = mix(purple_color, paper_color, 0.20 * (1.0 - dot_mask));
	comic_rgb = mix(comic_rgb, purple_dot, purple_mask * (0.40 + 0.60 * dot_mask));

	vec3 final_rgb = mix(src.rgb, comic_rgb, mix_amount);
	COLOR = vec4(final_rgb * v_modulate.rgb, src.a * v_modulate.a);
}
