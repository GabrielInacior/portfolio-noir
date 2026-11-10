// ─────────────────────────────────────────────────────────────────────────────
// NOIR WORLD: um shader só para o mundo inteiro (cidade e lojas), `unshaded` com iluminação PRÓPRIA.
// Por quê: no Compatibility cada combinação de flags do StandardMaterial3D vira um programa e cada
// programa com luz real ganha variantes por tipo/quantidade de luz (omni, spot, direcional, passadas
// aditivas). No Windows (ANGLE/D3D11) cada programa com luz custava ~2,5 s de compilação na 1ª visita.
// Aqui: 5 programas (opaco, opaco dupla face, recorte, mistura, aditivo), nenhum com variante de luz.
// As luzes viram DADOS: uma textura 4 x 17 (half float) atualizada pela CPU uma vez por quadro
// (scripts/render/noir.gd): linha 0 = cabeçalho (quantidade, ambiente, lua), linhas 1..16 = luzes.
// A conta de luz replica a do Godot 4.7 (scene.glsl do GLES3): Burley + Schlick-GGX, atenuação
// omni/spot, energia x PI, cor em espaço "sRGB" convertida pela mesma cúbica do motor. Assim o visual
// fica igual ao dos StandardMaterial3D que este shader substitui.
// Variação por material: SÓ uniformes (nunca define), e na geometria fundida pela cor/CUSTOM0/CUSTOM1
// de vértice (use_custom): cor, emissão, rugosidade, metal, sem luz, luz por vértice.
// ─────────────────────────────────────────────────────────────────────────────

#include "res://shaders/noir/noir_core.gdshaderinc"

uniform vec4 albedo_color = vec4(1.0);
uniform sampler2D albedo_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float use_tex = 0.0;
uniform float tex_nearest = 0.0;   // emula TEXTURE_FILTER_NEAREST (amostra no centro do texel, mip 0)
uniform float use_vc = 0.0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float triplanar = 0.0;     // 0 = UV, 1 = triplanar local, 2 = triplanar no mundo
uniform float tri_sharp = 1.0;
uniform vec4 emission_c = vec4(0.0);   // rgb = cor de emissão x energia; a = energia da emissão pela textura
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform float specular_amt = 0.5;
uniform float unshaded = 0.0;
uniform float vertex_lit = 0.0;
uniform float spec_off = 0.0;
uniform float use_custom = 0.0;
uniform float alpha_cut = 0.5;
uniform float pulse_seed = -1.0;   // >= 0: neon pulsando (+-8%, 3 rad/s) no próprio shader, sem CPU

varying vec4 v_c0;      // emissão rgb, rugosidade (-1 = sem luz)
varying vec4 v_c1;      // metal, especular, luz por vértice, especular desligado
varying vec3 v_vlit;    // luz difusa calculada no vértice (props estilo PS1)
varying vec3 v_tpos;
varying vec3 v_tw;

void vertex() {
	if (use_custom > 0.5) {
		v_c0 = CUSTOM0;
		v_c1 = CUSTOM1;
	} else {
		v_c0 = vec4(emission_c.rgb, unshaded > 0.5 ? -1.0 : roughness);
		v_c1 = vec4(metallic, specular_amt, vertex_lit, spec_off);
	}
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
	v_vlit = vec3(0.0);
	if (v_c1.z > 0.5 && v_c0.w >= 0.0) {
		vec3 sp = vec3(0.0);
		n_lights(wp, wn, normalize(CAMERA_POSITION_WORLD - wp), vec3(0.0), 1.0, 0.0, false, true, v_vlit, sp);
	}
	if (triplanar > 0.5) {
		vec3 nn = triplanar > 1.5 ? wn : NORMAL;
		v_tw = pow(abs(nn), vec3(tri_sharp));
		v_tw /= dot(v_tw, vec3(1.0));
		v_tpos = (triplanar > 1.5 ? wp : VERTEX) * uv_scale + uv_offset;
		v_tpos *= vec3(1.0, -1.0, 1.0);
	}
}

// texel exato do nível de mip certo (estilo PS1 sem cintilar ao longe): tex_nearest = 2
vec4 n_tex_px(vec2 uv) {
	vec2 sz = vec2(textureSize(albedo_tex, 0));
	vec2 dx = dFdx(uv * sz);
	vec2 dy = dFdy(uv * sz);
	float lod = max(0.0, floor(0.5 * log2(max(dot(dx, dx), dot(dy, dy))) + 0.5));
	vec2 msz = max(sz / exp2(lod), vec2(1.0));
	return textureLod(albedo_tex, (floor(uv * msz) + 0.5) / msz, lod);
}

vec4 n_tex(vec2 uv) {
	if (tex_nearest > 1.5) {
		return n_tex_px(uv);
	}
	if (tex_nearest > 0.5) {
		vec2 sz = vec2(textureSize(albedo_tex, 0));
		return textureLod(albedo_tex, (floor(uv * sz) + 0.5) / sz, 0.0);
	}
	return texture(albedo_tex, uv);
}

void fragment() {
	vec4 tex = vec4(1.0);
	if (use_tex > 0.5) {
		if (triplanar > 0.5) {
			tex = n_tex(v_tpos.xy) * v_tw.z + n_tex(v_tpos.xz) * v_tw.y + n_tex(v_tpos.zy * vec2(-1.0, 1.0)) * v_tw.x;
		} else {
			tex = n_tex(UV * uv_scale.xy + uv_offset.xy);
		}
	}
	vec4 alb = albedo_color * tex;
	if (pulse_seed >= 0.0) {
		alb.rgb *= 1.0 + sin(TIME * 3.0 + pulse_seed) * 0.08;
	}
	if (use_vc > 0.5) {
		alb *= COLOR;
	}
#ifdef NOIR_ALPHA
	ALPHA = alb.a;
#endif
#ifdef NOIR_SCISSOR
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
#endif
	if (v_c0.w < 0.0) {
		ALBEDO = alb.rgb;   // sem luz: igual ao unshaded do motor
	} else {
		vec3 al = n_cubic(alb.rgb);
		float rough = v_c0.w;
		float metal = v_c1.x;
		vec3 dif = vec3(0.0);
		vec3 spe = vec3(0.0);
		if (v_c1.z > 0.5) {
			dif = v_vlit;
		} else {
			vec3 P = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
			vec3 N = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
			vec3 V = normalize(CAMERA_POSITION_WORLD - P);
			float sp = v_c1.y;
			vec3 f0 = mix(vec3(0.16 * sp * sp), al, vec3(metal));
			n_lights(P, N, V, f0, rough, metal, v_c1.w < 0.5, false, dif, spe);
		}
		vec3 e = n_cubic(v_c0.rgb + emission_c.a * tex.rgb);
		vec3 lin = dif * al * (1.0 - metal) + spe + e + n_ambient() * al * (1.0 - metal);
		ALBEDO = n_inv(lin);
	}
}
