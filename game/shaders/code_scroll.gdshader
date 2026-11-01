shader_type spatial;
render_mode unshaded, cull_back;
// Tela de código rolando (procedural): linhas indentadas com "tokens" coloridos e cursor.
uniform vec4 bg : source_color = vec4(0.03, 0.04, 0.07, 1.0);
uniform vec4 c1 : source_color = vec4(0.36, 0.83, 0.54, 1.0);
uniform vec4 c2 : source_color = vec4(0.31, 0.61, 1.0, 1.0);
uniform vec4 c3 : source_color = vec4(1.0, 0.78, 0.24, 1.0);
uniform vec4 c4 : source_color = vec4(1.0, 0.44, 0.68, 1.0);
uniform float lines = 26.0;
uniform float speed = 0.6;
uniform float seed = 0.0;
uniform float energy = 1.4;

float h(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1)) + seed * 7.7) * 15731.743); }

void fragment() {
	vec2 uv = UV;
	float y = uv.y * lines + TIME * speed;
	float ln = floor(y);
	float fy = fract(y);
	float indent = floor(h(vec2(ln, 1.0)) * 4.0) * 0.05;
	float len = 0.15 + h(vec2(ln, 2.0)) * 0.6;
	float x = uv.x - 0.06 - indent;
	vec3 col = bg.rgb;
	// número da linha
	if (uv.x < 0.045 && fy > 0.3 && fy < 0.7) col = mix(col, vec3(0.3, 0.33, 0.45), step(0.4, h(vec2(ln, 9.0))));
	if (x > 0.0 && x < len && fy > 0.28 && fy < 0.72) {
		float tok = floor(x * 18.0);
		float r = h(vec2(ln, tok));
		float gap = step(0.18, fract(x * 18.0)) * step(0.15, r);
		vec3 tc = r < 0.3 ? c1.rgb : (r < 0.55 ? c2.rgb : (r < 0.8 ? c3.rgb : c4.rgb));
		col = mix(col, tc, gap);
	}
	// cursor piscando na última linha visível
	if (abs(uv.y - 0.92) < 0.012 && uv.x > 0.06 && uv.x < 0.075 && fract(TIME * 1.5) < 0.5) col = vec3(0.9);
	// scanlines
	col *= 0.9 + 0.1 * sin(uv.y * 600.0);
	ALBEDO = col * energy;
}
