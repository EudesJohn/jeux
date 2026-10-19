// Outline par coque inversée (DOSSIER.md § 20.15) : mesh dupliqué visuellement
// via next_pass du matériau du personnage. À désactiver en qualité « Faible ».
shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(0.1, 0.08, 0.06, 1.0);
uniform float thickness = 0.02;
