shader_type spatial;
// Foule des arènes (ANNEXE §2.3) : l'animation est 100 % GPU, aucun coût CPU.
// Un seul MultiMeshInstance3D dessine toute la foule ; la couleur de chaque
// spectateur vient de l'instance, la phase du rebond du custom data.
render_mode unshaded, cull_back;

uniform float excitement : hint_range(0.0, 1.0) = 0.2;
uniform float bob_height = 0.18;
uniform float base_speed = 2.0;
uniform float max_speed = 9.0;

varying vec3 tint;

void vertex() {
	float phase = INSTANCE_CUSTOM.x * 6.2831;
	float speed = mix(base_speed, max_speed, excitement);
	// Seule la partie haute du corps rebondit : les pieds restent au sol.
	float upper = step(0.6, VERTEX.y);
	VERTEX.y += abs(sin(TIME * speed + phase)) * bob_height * (0.3 + excitement) * upper;
	// Léger balancement latéral quand la foule est surexcitée.
	VERTEX.x += sin(TIME * speed * 0.5 + phase) * 0.02 * excitement;
	tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = tint;
}
