shader_type spatial;
// Personagem low-poly (estilo POLYGON): cor chapada por face, luz em 3 faixas suaves com sombra
// puxando para o azul-noite, e luz de borda colorida (neon) para recortar a silhueta no escuro.
render_mode cull_back, specular_disabled;
uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.07, 0.08, 0.2, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.25, 0.55, 1.0);
uniform float rim_strength = 0.9;
uniform float rim_width = 0.42;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	// borda: mais forte nas faces que viram de lado para a câmera
	float f = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float r = smoothstep(1.0 - rim_width, 1.0, f);
	EMISSION = rim_color.rgb * r * rim_strength * 0.6;
}

void light() {
	float nl = dot(NORMAL, LIGHT);
	// sombreamento suave e limpo (estilo personagem moderno), com leve degrau
	float band = smoothstep(-0.25, 0.85, nl);
	band = mix(band, floor(band * 3.0 + 0.5) / 3.0, 0.25);
	vec3 lit = mix(shadow_tint.rgb * 2.2, vec3(1.0), band);
	DIFFUSE_LIGHT += ALBEDO * lit * LIGHT_COLOR * ATTENUATION * 0.9;
}
