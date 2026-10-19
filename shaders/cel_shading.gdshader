// Cel-shading 3 paliers, un seul passage (DESIGN.md § 5 et § 20.14).
// Sur personnages provisoires ET finaux : uniforme albedo_tex pour les vrais
// modèles texture .glb, uniforme tint pour les mocks sans texture (PHASE 0.5).
//
// render_mode unshaded : l'éclairage est calculé ici même (NdotL + paliers).
// C'est obligatoire pour le moteur Compatibility (OpenGL ES 3.0, § 4) : le
// built-in LIGHT du fragment n'y existe pas, le shader ne compilait pas.
// Avantage : un rendu identique sur tous les moteurs et sur tous les téléphones.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D albedo_tex : source_color;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.12, 0.16, 0.36, 1.0);
// Direction du soleil (monde), alignée sur la DirectionalLight3D des scènes
// (pitch −45° : la lumière vient d'au-dessus et de derrière la caméra).
uniform vec3 light_direction = vec3(0.0, 0.707, 0.707);
uniform float steps = 3.0;

varying vec3 world_normal;

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb * tint.rgb;
	float ndl = clamp(dot(normalize(world_normal), normalize(light_direction)), 0.0, 1.0);
	float band = floor(ndl * steps) / steps;
	vec3 shadowed = mix(base * shadow_color.rgb, base, band);
	ALBEDO = clamp(shadowed, 0.0, 1.0);
}
