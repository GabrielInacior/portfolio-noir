shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;
// Contorno do objeto mirado (casca invertida inflada), pulsando de leve.
uniform vec4 color : source_color = vec4(1.0, 0.78, 0.24, 1.0);
uniform float width = 0.025;
void vertex() {
	VERTEX += NORMAL * width * (1.0 + 0.35 * sin(TIME * 6.0));
}
void fragment() {
	ALBEDO = color.rgb * 2.0;
}
