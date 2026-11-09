shader_type spatial;
// Sombreamento "pintado" para celular: luz em faixas (sem degradê), borda das faixas quebrada por
// pincelada, sombra puxando para azul-noite e retícula de quadrinho nas partes escuras.
// Opcional: textura pintada (madeira, reboco, ladrilho...) em projeção TRIPLANAR no espaço do mundo,
// porque as cenas são caixas e cilindros sem UV boa. A textura é um mapa de valor neutro (média 0.5):
// a cor continua vindo de "albedo", a textura só traz pincelada, tom e estrutura.
// Custo: sem textura = 1 amostra (pincelada); com textura = +3 amostras. Nenhum laço.
render_mode cull_back, unshaded;
// mundo noir: sem luz do motor; a mesma conta de faixas roda aqui sobre as luzes-dados (noir_core)
#include "res://shaders/noir/noir_core.gdshaderinc"
uniform vec4 albedo : source_color = vec4(0.4, 0.5, 0.75, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.05, 0.09, 0.22, 1.0);
uniform float brush = 0.18;
uniform float emission_energy = 0.0;
uniform vec4 emission_color : source_color = vec4(1.0, 0.78, 0.24, 1.0);
uniform float halftone = 1.0;
// textura pintada da superfície (triplanar só quando use_tex = true)
uniform bool use_tex = false;
uniform sampler2D albedo_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float tex_scale = 0.5;      // repetições por metro
uniform float tex_strength = 1.0;   // 0 = cor lisa, 1 = textura inteira
// pincelada neutra (textura de tela). brush_amount = 0 mantém o ruído procedural antigo
// (é o caso do personagem, que se mexe e não pode ter textura "nadando" no mundo).
uniform sampler2D brush_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float brush_amount = 0.0;
uniform float brush_scale = 0.6;
varying vec3 wpos;
varying vec3 wnrm;
varying float bn;   // pincelada calculada uma vez no fragment e reaproveitada em cada luz

float hash3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float vnoise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x), mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x), mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// faixa de luz quebrada pela pincelada + retícula (era a função light() do motor)
vec3 toon_light(vec3 N, vec3 L, vec3 LC, float A, vec3 al, vec2 fc, float bv, vec3 wp) {
	float n = bv >= 0.0 ? (bv - 0.5) * 1.6 : vnoise(wp * vec3(4.0, 12.0, 4.0)) - 0.5;
	float ndl = dot(N, L) * 0.5 + 0.5;
	float v = clamp(ndl * A + n * brush, 0.0, 1.0);
	float band = v < 0.42 ? 0.0 : (v < 0.62 ? 0.45 : (v < 0.86 ? 0.8 : 1.05));
	vec2 p = mat2(vec2(0.707, -0.707), vec2(0.707, 0.707)) * (fc / 6.0);
	float dotd = length(fract(p) - 0.5);
	float ht = step(dotd, (1.0 - v) * 0.42) * halftone;
	vec3 lit = al * LC / PI * band;
	return lit * (1.0 - ht * 0.45);
}

void fragment() {
	vec3 col = albedo.rgb;
	vec3 an = abs(normalize(wnrm));
	if (brush_amount > 0.0) {
		// pincelada de tela: uma amostra só, projetada pelo eixo dominante da normal
		vec2 buv = (an.x > an.y && an.x > an.z) ? vec2(wpos.z, -wpos.y) : ((an.y > an.z) ? wpos.xz : vec2(wpos.x, -wpos.y));
		bn = texture(brush_tex, buv * brush_scale).r;
		col *= 1.0 + (bn - 0.5) * brush_amount;
	} else {
		// mancha de pincel na cor base: duas escalas de ruído esticadas (visual original do personagem)
		float n = vnoise(wpos * vec3(3.0, 9.0, 3.0)) * 0.6 + vnoise(wpos * 11.0) * 0.4;
		bn = -1.0;
		col *= 0.88 + n * 0.22;
	}
	if (use_tex) {
		// triplanar com transição curta (caixas quase sempre caem num plano só)
		vec3 w = an * an; w *= w;
		w /= (w.x + w.y + w.z);
		vec3 tx = texture(albedo_tex, vec2(wpos.z, -wpos.y) * tex_scale).rgb;
		vec3 ty = texture(albedo_tex, wpos.xz * tex_scale).rgb;
		vec3 tz = texture(albedo_tex, vec2(wpos.x, -wpos.y) * tex_scale).rgb;
		vec3 t = tx * w.x + ty * w.y + tz * w.z;
		col *= mix(vec3(1.0), t * 2.0, tex_strength);
	}
	vec3 al = n_cubic(col);
	vec3 P = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 N = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 dif = vec3(0.0);
	vec3 L;
	vec3 lc;
	float att;
	float sp;
	if (n_moon(L, lc)) {
		dif += toon_light(N, L, lc, 1.0, al, FRAGCOORD.xy, bn, wpos);
	}
	int cnt = n_total();
	for (int k = 0; k < 24; k++) {
		if (k >= cnt) {
			break;
		}
		int row = n_row_of(k);
		if (row >= 0 && n_row(row, P, L, lc, att, sp)) {
			dif += toon_light(N, L, lc, att, al, FRAGCOORD.xy, bn, wpos);
		}
	}
	// o motor multiplicava a luz difusa pelo albedo de novo (DIFFUSE_LIGHT * albedo): mantido
	vec3 lin = dif * al + n_cubic(emission_color.rgb * emission_energy) + n_ambient() * al;
	ALBEDO = n_inv(lin);
}

