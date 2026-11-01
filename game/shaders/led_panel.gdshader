shader_type spatial;
render_mode unshaded, cull_back;
// Frente de rack de servidor: grade de LEDs piscando (verde/âmbar/vermelho) e baias escuras.
uniform vec4 base : source_color = vec4(0.05, 0.06, 0.09, 1.0);
uniform float units = 14.0;
uniform float seed = 0.0;

float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float u = floor(uv.y * units);
	vec2 c = fract(vec2(uv.x * 10.0, uv.y * units));
	vec3 col = base.rgb + vec3(0.02) * step(0.92, c.y);
	float led = floor(uv.x * 10.0);
	float r = h(vec2(led, u));
	float blink = step(0.5, fract(TIME * (0.6 + r * 5.0) + r * 9.0));
	if (led < 4.0 && length(c - vec2(0.5, 0.5)) < 0.22) {
		vec3 lc = r < 0.65 ? vec3(0.2, 1.0, 0.4) : (r < 0.88 ? vec3(1.0, 0.7, 0.15) : vec3(1.0, 0.2, 0.25));
		col = mix(col, lc * 2.2, blink * step(0.15, r));
	}
	// ventilação
	if (led > 5.0 && fract(uv.x * 40.0) < 0.5 && c.y > 0.2 && c.y < 0.8) col *= 0.6;
	ALBEDO = col;
}
