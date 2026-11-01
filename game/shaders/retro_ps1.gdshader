shader_type canvas_item;
// Pós-processo retrô estilo PS1 sobre a imagem 3D em baixa resolução (ampliada com NEAREST):
// quantização de cor com dithering ordenado Bayer 4x4 (no pixel da resolução interna) e vinheta leve.
uniform vec2 res = vec2(640.0, 360.0);
uniform float levels = 32.0;      // tons por canal (32 = 5 bits)
uniform float dither = 1.0;       // força do pontilhado
uniform float vignette = 0.35;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	vec2 px = floor(UV * res);
	c += bayer4(px) * dither / levels;
	c = floor(c * levels + 0.5) / levels;
	vec2 d = UV - 0.5;
	c *= 1.0 - vignette * dot(d, d) * 1.6;
	COLOR = vec4(c, 1.0);
}
