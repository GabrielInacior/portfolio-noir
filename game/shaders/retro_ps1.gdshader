shader_type canvas_item;
// Pós-processo retrô estilo PS1 sobre a imagem 3D em baixa resolução (ampliada com NEAREST):
// quantização de cor com dithering ordenado Bayer 4x4 (no pixel da resolução interna) e vinheta leve.
// Rodada 4: filtro de fita VHS / TV antiga NESTA mesma composição (sem passada extra), tudo sutil:
// vinheta, scanlines finas, aberração cromática que cresce para as bordas, sangramento de cor na
// horizontal, grão e ruído de fita animados e uma linha de tracking ocasional (fraca, sem piscar).
// fx: 0 = desligado, 1 = mínimo (batata/sem placa: vinheta + scanline), 2 = celular (+ grão), 3 = completo.
uniform vec2 res = vec2(640.0, 360.0);
uniform float levels = 32.0;      // tons por canal (32 = 5 bits)
uniform float dither = 1.0;       // força do pontilhado
uniform float vignette = 0.35;
uniform float fx = 0.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	vec2 d = UV - 0.5;
	float r2 = dot(d, d);
	// linha de tracking: a cada ~13 s uma faixa fina desce pela tela por ~2 s, deslocando a imagem de leve
	float trk = 0.0;
	if (fx > 2.5) {
		float ph = fract(TIME / 13.0);
		if (ph < 0.16) {
			float y = 1.15 - ph / 0.16 * 1.3;
			trk = exp(-pow((UV.y - y) * 60.0, 2.0));
			uv.x += trk * (hash12(vec2(floor(UV.y * res.y), floor(TIME * 24.0))) - 0.5) * 0.012;
		}
	}
	vec3 c;
	if (fx > 2.5) {
		// aberração cromática radial (cresce para as bordas) + sangramento de cor horizontal
		vec2 ca = d * r2 * 0.045;
		float px = 1.0 / res.x;
		vec3 mid = texture(TEXTURE, uv).rgb;
		c.r = texture(TEXTURE, uv + ca).r;
		c.g = mid.g;
		c.b = texture(TEXTURE, uv - ca).b;
		vec3 side = texture(TEXTURE, uv - vec2(px * 1.5, 0.0)).rgb;
		float y0 = dot(c, vec3(0.299, 0.587, 0.114));
		vec3 chroma = mix(c - y0, side - dot(side, vec3(0.299, 0.587, 0.114)), 0.35);
		c = y0 + chroma;
	} else {
		c = texture(TEXTURE, uv).rgb;
	}
	vec2 pxi = floor(uv * res);
	c += bayer4(pxi) * dither / levels;
	c = floor(c * levels + 0.5) / levels;
	if (fx > 0.5) {
		// scanlines finas na resolução da tela (não da imagem interna)
		c *= 1.0 - 0.11 * (0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159));
	}
	if (fx > 1.5) {
		// grão e ruído de fita (muda 24 vezes por segundo, amplitude baixa)
		float g = hash12(FRAGCOORD.xy + floor(TIME * 24.0) * 37.0) - 0.5;
		c += g * 0.045;
		c += trk * 0.05;
	}
	c *= 1.0 - (fx > 0.5 ? vignette + 0.28 : vignette) * r2 * 1.6;
	COLOR = vec4(c, 1.0);
}
