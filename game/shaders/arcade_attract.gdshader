shader_type spatial;
render_mode unshaded, cull_back;
// Tela de fliperama em modo demonstração: grade neon em perspectiva, sol listrado e pixels.
uniform vec4 c1 : source_color = vec4(1.0, 0.3, 0.7, 1.0);
uniform vec4 c2 : source_color = vec4(0.3, 0.9, 1.0, 1.0);
void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	vec3 col = vec3(0.04, 0.02, 0.08);
	if (uv.y < 0.45) {
		float z = 0.45 / max(0.45 - uv.y, 0.01);
		float gx = abs(fract((uv.x - 0.5) * z * 3.0) - 0.5);
		float gz = abs(fract(z + TIME * 1.5) - 0.5);
		col += c1.rgb * (smoothstep(0.05, 0.0, gx) + smoothstep(0.06, 0.0, gz)) * 0.8;
	} else {
		float d = length(uv - vec2(0.5, 0.55));
		if (d < 0.22 && fract(uv.y * 14.0 - TIME * 0.2) > 0.25) col = mix(c2.rgb, c1.rgb, (uv.y - 0.45) * 3.0);
	}
	col *= 0.85 + 0.15 * sin(uv.y * 400.0);
	ALBEDO = col * 1.5;
}
