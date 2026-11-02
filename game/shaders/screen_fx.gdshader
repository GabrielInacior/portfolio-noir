shader_type spatial;
// Tela estilizada (telões, TVs, monitores, painéis de LED): subpixels RGB e scanlines de perto,
// curvatura e vinheta de CRT opcionais, brilho de tela e GLITCH em rajadas curtas (0,1 a 0,3 s a
// cada 4 a 10 s, em tempo próprio por tela) + glitch na troca de anúncio. Tudo no fragment.
// Iluminado pela cena e com a névoa do mundo (não é unshaded): o conteúdo continua legível.
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic;
uniform float emit = 0.9;
uniform float seed = 0.0;            // fase própria (telas não sincronizam)
uniform float crt = 0.0;             // 0 = LED plano, 1 = TV de tubo (curvatura + vinheta + estática)
uniform float swap_glitch = 0.0;     // >0 durante a troca de anúncio (o script decai para 0)
uniform vec2 px_res = vec2(320.0, 180.0);  // resolução "física" da grade de pixels
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);  // região no atlas de anúncios (x, y, w, h)

vec3 samp(vec2 u) { return texture(tex, uv_rect.xy + clamp(u, vec2(0.002), vec2(0.998)) * uv_rect.zw).rgb; }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	if (crt > 0.0) {   // curvatura de tubo
		vec2 c = uv * 2.0 - 1.0;
		c *= 1.0 + crt * 0.06 * vec2(c.y * c.y, c.x * c.x);
		uv = c * 0.5 + 0.5;
	}
	// rajada de glitch: janela curta dentro de um período pseudoaleatório por tela
	float t = TIME + seed * 13.7;
	float period = 4.0 + 6.0 * hash(vec2(floor(t / 7.0), seed));
	float ph = mod(t, period);
	float burst = step(ph, 0.1 + 0.2 * hash(vec2(seed, floor(t / period))));
	float g = max(burst, swap_glitch);
	if (g > 0.0) {
		float band = floor(uv.y * 18.0 + floor(t * 30.0));
		float sh = (hash(vec2(band, floor(t * 24.0))) - 0.5) * 0.08 * g;
		uv.x += sh * step(0.55, hash(vec2(band, seed)));
		uv.y += (hash(vec2(floor(t * 12.0), seed)) - 0.5) * 0.02 * g;   // salto de quadro
	}
	vec3 col;
	float ab = 0.004 + 0.012 * g;    // aberração cromática (mais forte no glitch)
	col.r = samp(uv + vec2(ab, 0.0)).r;
	col.g = samp(uv).g;
	col.b = samp(uv - vec2(ab, 0.0)).b;
	if (g > 0.0) {   // ruído digital em blocos
		vec2 blk = floor(uv * vec2(40.0, 24.0));
		float n = hash(blk + floor(t * 20.0));
		col = mix(col, vec3(n, n * 0.6, n), step(0.93, n) * g);
	}
	// subpixels RGB + scanlines (somem de longe pelo mipmap/derivada)
	vec2 pp = uv * px_res;
	float fw = clamp(length(fwidth(pp)), 0.0, 1.0);
	float sub = mod(floor(pp.x * 3.0), 3.0);
	vec3 mask = vec3(sub == 0.0 ? 1.0 : 0.72, sub == 1.0 ? 1.0 : 0.72, sub == 2.0 ? 1.0 : 0.72);
	float scan = 0.78 + 0.22 * sin(pp.y * 6.2831);
	col *= mix(mask * scan, vec3(1.0), fw);
	if (crt > 0.0) {   // vinheta e estática leve de TV
		vec2 c = uv * 2.0 - 1.0;
		col *= 1.0 - crt * 0.35 * dot(c, c);
		col += crt * 0.04 * (hash(uv * 400.0 + floor(t * 30.0)) - 0.5);
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) { col = vec3(0.0); }
	}
	ALBEDO = col * 0.35;
	EMISSION = col * emit;
	ROUGHNESS = 0.35;
}
