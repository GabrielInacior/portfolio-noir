shader_type spatial;
render_mode unshaded, cull_back;
// Painel de métricas: barras animadas, linha de tendência e grade (dashboard procedural).
uniform vec4 bg : source_color = vec4(0.04, 0.05, 0.09, 1.0);
uniform vec4 accent : source_color = vec4(0.31, 0.61, 1.0, 1.0);
uniform vec4 accent2 : source_color = vec4(1.0, 0.44, 0.68, 1.0);
uniform float seed = 0.0;
float h(float x) { return fract(sin(x * 91.7 + seed * 3.1) * 43758.5); }
void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	vec3 col = bg.rgb;
	if (fract(uv.y * 6.0) < 0.02 || fract(uv.x * 8.0) < 0.01) col += vec3(0.04);
	if (uv.y < 0.55) {
		float b = floor(uv.x * 16.0);
		float v = 0.1 + 0.4 * h(b) + 0.06 * sin(TIME * (1.0 + h(b + 3.0)) + b);
		if (fract(uv.x * 16.0) > 0.2 && uv.y < v) col = mix(accent.rgb, accent2.rgb, uv.y * 1.6);
	} else {
		float t = uv.x * 10.0 + TIME * 0.4;
		float line = 0.72 + 0.12 * sin(t) * h(floor(t)) + 0.05 * sin(t * 3.1);
		if (abs(uv.y - line) < 0.012) col = accent2.rgb * 1.5;
	}
	ALBEDO = col * 1.3;
}
