shader_type canvas_item;
// 序列帧遮罩：白透黑不透，所有帧横排一行
uniform sampler2D mask_tex : filter_nearest, repeat_disable, hint_default_black;
uniform int hframes = 1;
uniform int frame = 0;
uniform float radius : hint_range(0.0, 2048.0) = 0.0;
uniform vec2 rect_size = vec2(2048.0, 2048.0);

void fragment() {
	float a = 1.0; // 默认全黑
	if (radius >= 0.5) {
		vec2 local = (UV - vec2(0.5)) * rect_size - 0.5; // 以玩家为中心的像素坐标
		vec2 uv = local / (radius * 2.0) + vec2(0.5); // 一格贴图的边长等于直径
		if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
			int n = max(hframes, 1);
			int f = clamp(frame, 0, n - 1);
			uv.x = (uv.x + float(f)) / float(n); // 切到当前那一格
			a = 1.0 - texture(mask_tex, uv).r;
		}
	}
	COLOR = vec4(0.0, 0.0, 0.0, a);
}