shader_type spatial;
// Marcador de entrada das portas (ícone próprio): seta de neon apontando para a porta, flutuando acima
// do batente, girando devagar, balançando e pulsando. Um MultiMesh com todas as portas (1 draw), cor
// por instância (tipo de lugar). Sem névoa e com um mínimo de tamanho na tela para ler a 30 m ou mais.
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform float spin = 1.1;          // rad/s
uniform float bob = 0.07;          // m
uniform float min_px_dist = 12.0;  // a partir desta distância o marcador cresce um pouco
uniform float max_grow = 2.2;      // e para aqui (de longe; a origem é a ponta, então só cresce para cima)
varying float v_glow;
varying float v_far;

void vertex() {
	float ph = float(INSTANCE_ID) * 1.7;
	float a = TIME * spin + ph;
	float c = cos(a);
	float s = sin(a);
	vec3 p = vec3(VERTEX.x * c + VERTEX.z * s, VERTEX.y, -VERTEX.x * s + VERTEX.z * c);
	vec3 org = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = distance(org, CAMERA_POSITION_WORLD);
	float k = clamp(d / min_px_dist, 1.0, max_grow);
	VERTEX = p * k + vec3(0.0, sin(TIME * 2.1 + ph) * bob, 0.0);
	NORMAL = vec3(NORMAL.x * c + NORMAL.z * s, NORMAL.y, -NORMAL.x * s + NORMAL.z * c);
	v_glow = 0.8 + 0.35 * sin(TIME * 3.2 + ph);
	v_far = clamp((d - 6.0) / 20.0, 0.0, 1.0);
}

void fragment() {
	// faces viradas para a câmera um pouco mais claras: dá volume sem luz
	float f = 0.75 + 0.25 * abs(dot(normalize(NORMAL), normalize(VIEW)));
	// COLOR.a < 1: lugar já visitado (mais apagado)
	// de perto mais contido (lê a forma da seta, sem estourar no brilho); de longe forte, para furar a névoa
	ALBEDO = COLOR.rgb * (mix(1.5, 3.6, v_far) * v_glow * f) * mix(0.45, 1.0, COLOR.a);
}
