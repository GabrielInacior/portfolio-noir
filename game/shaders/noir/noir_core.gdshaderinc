// núcleo do mundo noir: dados de luz (textura 4 x 17) e a conta de luz do Godot 4.7 replicada.
// Incluído pelos shaders do mundo (noir_inc) e pelos shaders próprios com luz (toon, screen_fx).
uniform sampler2D noir_lights : filter_nearest, repeat_disable;

const float NPI = 3.14159265359;

vec3 n_cubic(vec3 c) { return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878); }

// inversa da cúbica do motor (o motor aplica a cúbica no ALBEDO de um material unshaded)
vec3 n_inv(vec3 l) {
	l = max(l, vec3(0.0));
	vec3 x = max(vec3(1.055) * pow(l, vec3(0.416666667)) - vec3(0.055), vec3(0.0));
	for (int i = 0; i < 2; i++) {
		vec3 f = n_cubic(x) - l;
		vec3 fp = x * (x * 0.915918033 + 1.364342222) + 0.012522878;
		x -= f / max(fp, vec3(1e-4));
	}
	return max(x, vec3(0.0));
}

float n_att(float d, float inv_r, float decay) {
	float nd = d * inv_r;
	nd *= nd;
	nd *= nd;
	nd = max(1.0 - nd, 0.0);
	nd *= nd;
	return nd * pow(max(d, 0.0001), -decay);
}

float n_schlick(float u) { float m = 1.0 - u; float m2 = m * m; return m2 * m2 * m; }

void n_light(vec3 N, vec3 L, vec3 V, vec3 col, float att, vec3 f0, float rough, float metal, float spec_amt, bool spec_on, inout vec3 dif, inout vec3 spe) {
	float cNdotL = clamp(dot(N, L), 0.0, 1.0);
	float cNdotV = max(dot(N, V), 1e-4);
	vec3 H = normalize(V + L);
	float cLdotH = clamp(dot(L, H), 0.0, 1.0);
	if (metal < 1.0) {
		float fd90 = 2.0 * cLdotH * cLdotH * rough - 0.5;
		float fdv = 1.0 + fd90 * n_schlick(cNdotV);
		float fdl = 1.0 + fd90 * n_schlick(cNdotL);
		dif += col * ((1.0 / NPI) * fdv * fdl * cNdotL) * att;
	}
	if (spec_on && rough > 0.0) {
		float cNdotH = clamp(dot(N, H), 0.0, 1.0);
		float a = rough * rough;
		float ah = cNdotH * a;
		float k = a / (1.0 - cNdotH * cNdotH + ah * ah);
		float D = k * k * (1.0 / NPI);
		float G = 0.5 / mix(2.0 * cNdotL * cNdotV, cNdotL + cNdotV, a);
		float f90 = clamp(50.0 * f0.g, 0.0, 1.0);
		vec3 F = f0 + (f90 - f0) * n_schlick(cLdotH);
		spe += cNdotL * D * F * G * col * att * spec_amt;
	}
}

// Layout da textura (4 colunas x 121 linhas):
//   linha 0          cabeçalho: (qtd. perto, qtd. móveis), ambiente, lua (direção), lua (cor)
//   linhas 1..16     as 16 luzes FIXAS mais relevantes para a câmera (objetos sem conjunto próprio)
//   linhas 17..24    luzes que se MEXEM (faróis), as 8 mais perto da câmera: valem para todos
//   linhas 25..120   todas as luzes fixas, uma por vaga (índice estável)
// Cada objeto fixo leva no seu material (cópia do mesmo shader, nl_a e nl_b) as vagas das suas até 8 omni + 8 spot, escolhidas
// como o Compatibility escolhe (as de menor distância ao centro do objeto / (alcance x energia)):
// assim a luz cai nos mesmos lugares que antes (pedido: visual igual).
const int N_NEAR0 = 1;
const int N_DYN0 = 17;
const int N_SLOT0 = 25;
uniform vec4 nl_a = vec4(-2.0);   // duas vagas por número: (a+1) + (b+1)*128; 0 = nenhuma
uniform vec4 nl_b = vec4(0.0);
uniform float nl_free = 99.0;     // vagas omni livres no conjunto: faróis só entram se couberem (como no motor)

// luz da linha `row` vista do ponto P: direção, cor x energia x PI, atenuação (omni/spot) e especular
bool n_row(int row, vec3 P, out vec3 L, out vec3 col, out float att, out float spec) {
	vec4 t0 = texelFetch(noir_lights, ivec2(0, row), 0);
	vec3 rel = t0.xyz - P;
	float d = length(rel);
	L = rel / max(d, 1e-4);
	col = vec3(0.0);
	att = 0.0;
	spec = 0.0;
	if (d * t0.w >= 1.0) {
		return false;
	}
	vec4 t1 = texelFetch(noir_lights, ivec2(1, row), 0);
	vec4 t2 = texelFetch(noir_lights, ivec2(2, row), 0);
	vec4 t3 = texelFetch(noir_lights, ivec2(3, row), 0);
	att = n_att(d, t0.w, t1.w);
	if (t2.w > -1.5) {
		float scos = max(dot(-L, t2.xyz), t2.w);
		float rim = max(0.0001, (1.0 - scos) / (1.0 - t2.w));
		att *= 1.0 - pow(rim, t3.x);
	}
	col = t1.rgb;
	spec = t3.y;
	return att > 0.0;
}

// lua (direcional): direção para a luz e cor x energia x PI
bool n_moon(out vec3 L, out vec3 col) {
	vec4 h3 = texelFetch(noir_lights, ivec2(3, 0), 0);
	L = texelFetch(noir_lights, ivec2(2, 0), 0).xyz;
	col = h3.rgb;
	return h3.a > 0.5;
}

// quantidade de luzes a percorrer (k = 0..n_total()-1) e a linha de cada uma, para este objeto
int n_total() {
	vec4 h0 = texelFetch(noir_lights, ivec2(0, 0), 0);
	if (h0.z > 0.5) {
		return 0;   // PC sem placa: sem luzes pontuais (só lua e ambiente), como antes
	}
	int nd = min(int(h0.y + 0.5), int(nl_free + 0.5));
	return (nl_a.x < -1.5 ? int(h0.x + 0.5) : 16) + nd;
}

int n_row_of(int k) {
	vec4 h0 = texelFetch(noir_lights, ivec2(0, 0), 0);
	int ns = nl_a.x < -1.5 ? int(h0.x + 0.5) : 16;
	if (k >= ns) {
		return N_DYN0 + (k - ns);
	}
	if (nl_a.x < -1.5) {
		return N_NEAR0 + k;
	}
	int j = k / 2;
	vec4 q = j < 4 ? nl_a : nl_b;
	int c = j % 4;
	float v = c == 0 ? q.x : (c == 1 ? q.y : (c == 2 ? q.z : q.w));
	int iv = int(v + 0.5);
	int s = (k % 2 == 0) ? (iv % 128) : (iv / 128);
	return s == 0 ? -1 : N_SLOT0 + s - 1;
}

// soma de todas as luzes (lua + omni/spot) num ponto do mundo
void n_lights(vec3 P, vec3 N, vec3 V, vec3 f0, float rough, float metal, bool spec_on, bool lambert, inout vec3 dif, inout vec3 spe) {
	vec3 L;
	vec3 col;
	float att;
	float sp;
	if (n_moon(L, col)) {
		if (lambert) {
			dif += col * max(dot(N, L), 0.0) * (1.0 / NPI);
		} else {
			n_light(N, L, V, col, 1.0, f0, rough, metal, 1.0, spec_on, dif, spe);
		}
	}
	int n = n_total();
	for (int k = 0; k < 24; k++) {
		if (k >= n) {
			break;
		}
		int row = n_row_of(k);
		if (row < 0 || !n_row(row, P, L, col, att, sp)) {
			continue;
		}
		if (lambert) {
			dif += col * max(dot(N, L), 0.0) * (1.0 / NPI) * att;
		} else {
			n_light(N, L, V, col, att, f0, rough, metal, sp, spec_on, dif, spe);
		}
	}
}

vec3 n_ambient() {
	return texelFetch(noir_lights, ivec2(1, 0), 0).rgb;
}


