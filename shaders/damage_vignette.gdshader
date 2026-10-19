// Vignette de dégâts (DESIGN.md § 16 : lisibilité du combat).
// Rouge sur les bords de l'écran, plus intense quand la joueuse encaisse.
// Compatible Compatibility (OpenGL ES 3.0, § 4) : un seul étage de calcul par
// fragment, aucune texture, aucun échantillonnage.
shader_type canvas_item;
render_mode blend_mix;

uniform vec4 tint : source_color = vec4(0.72, 0.15, 0.12, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.05, 1.0) = 0.45;

void fragment() {
	// Écran 16/9 : on étire l'axe horizontal pour une vignette bien ronde.
	vec2 uv = UV - vec2(0.5);
	uv.x *= 1.45;
	float dist = length(uv) * 1.7;
	float edge = smoothstep(0.75 - softness, 1.0, dist);
	COLOR = vec4(tint.rgb, edge * intensity * tint.a);
}
