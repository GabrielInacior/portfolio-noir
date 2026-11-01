shader_type spatial;
render_mode unshaded, cull_back;
// Chuva de caracteres estilo Matrix, procedural (sem textura): colunas de "glifos" em blocos que caem.
uniform vec4 tint : source_color = vec4(0.22, 1.0, 0.42, 1.0);
uniform float cols = 28.0;
uniform float rows = 22.0;
uniform float speed = 1.0;
uniform float seed = 0.0;
uniform float energy = 1.6;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 13.1) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float cx = floor(uv.x * cols);
	float sp = 0.5 + h(vec2(cx, 1.0)) * 1.5;
	float y = uv.y * rows + TIME * speed * sp * 6.0 + h(vec2(cx, 2.0)) * 50.0;
	float cy = floor(y);
	vec2 cell = fract(vec2(uv.x * cols, y));
	// glifo: bloquinhos que trocam com o tempo
	float g = h(vec2(cx, cy + floor(TIME * 4.0 * h(vec2(cx, cy)))));
	vec2 q = floor(cell * vec2(3.0, 4.0));
	float on = step(0.45, h(q + g * 17.0)) * step(0.12, cell.x) * step(cell.x, 0.88) * step(0.1, cell.y) * step(cell.y, 0.9);
	// rastro: mais claro na cabeça da coluna
	float trail = fract(-y / 18.0 + h(vec2(cx, 3.0)));
	float head = smoothstep(0.92, 1.0, trail);
	float a = on * pow(trail, 2.2);
	vec3 col = tint.rgb * a + vec3(0.85, 1.0, 0.9) * head * on;
	col += tint.rgb * 0.03;
	ALBEDO = col * energy;
}
