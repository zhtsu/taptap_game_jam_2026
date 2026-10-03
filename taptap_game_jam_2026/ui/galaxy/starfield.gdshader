// 宇宙星空背景：程序化生成星点 + 淡淡星云。
// 用法：赋给 WorldEnvironment 的 Environment.sky 的 Sky.sky_material（shader_type sky）。
//
// 为什么用 sky shader 而不是贴一张背景图：
//   1) 相机旋转时星空跟着动（有真实的空间感），贴图做不到；
//   2) 分辨率无关，1080x2400 到 4K 都不会糊；
//   3) 参数（密度/亮度/大小/星云）可以从 galaxy_config.gd 里直接调。
//
// 星点做法：把方向向量按 density 量化成格子，每格用 hash 决定这格里有没有星星。
// 相比"随机采样噪声+阈值"，这样星星是**离散的点**而不是斑块，更像星空。
//
// 想调星星多少：改 density（格子粗细）配合 threshold（出现门槛）。
//   density 越大格子越细 → 同样 threshold 下星越多越密；
//   threshold 越大 → 出现门槛越高 → 星越少。

shader_type sky;

uniform vec3 top_color : source_color = vec3(0.01, 0.012, 0.035);
uniform vec3 bottom_color : source_color = vec3(0.025, 0.02, 0.05);
uniform vec3 star_color : source_color = vec3(1.0, 0.97, 0.92);
uniform float density : hint_range(10.0, 400.0) = 80.0;
uniform float brightness : hint_range(0.0, 4.0) = 1.15;
uniform float star_size : hint_range(0.01, 1.0) = 0.22;
uniform float threshold : hint_range(0.0, 0.99) = 0.975;
uniform float nebula_strength : hint_range(0.0, 1.0) = 0.25;
uniform float nebula_scale : hint_range(0.5, 12.0) = 2.4;
uniform vec3 nebula_color : source_color = vec3(0.18, 0.10, 0.30);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

// 值噪声：用于星云
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z);
}

void sky() {
	vec3 dir = normalize(EYEDIR);

	// 底色：上下渐变（y 方向）
	vec3 base = mix(bottom_color, top_color, clamp(dir.y * 1.4 + 0.5, 0.0, 1.0));

	// 星云：两层噪声叠加，只在银河盘面附近偏强（|y| 小）
	float nebula = noise3(dir * nebula_scale) * 0.6 + noise3(dir * nebula_scale * 2.7) * 0.4;
	float band = 1.0 - clamp(abs(dir.y) * 2.2, 0.0, 1.0);
	base += nebula_color * nebula * nebula_strength * (0.35 + 0.65 * band);

	// 星点：把方向量化成格子，每格一个 hash 决定是否有星
	vec3 cell = floor(dir * density);
	float h = hash13(cell);
	float star = step(threshold, h);
	// 星点大小：同一格内按方向的小数部分做一个圆点
	vec3 within = fract(dir * density) - 0.5;
	float dot_shape = 1.0 - smoothstep(0.0, star_size, length(within));
	float twinkle = 0.75 + 0.25 * hash13(cell + 7.0);
	base += star_color * star * dot_shape * brightness * twinkle;

	COLOR = base;
}
