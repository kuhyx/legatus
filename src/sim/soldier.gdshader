// Soldier vertex animation driven by per-instance custom data
// (x = animation phase, y = state: 0 advance, 1 fight, 2 rout, 3 dead,
//  z = fatigue). Procedural bob/stride/thrust for the spike; real
// vertex-animation textures replace this later.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform vec3 tint : source_color = vec3(0.6, 0.1, 0.08);

// rgb = albedo, a = how much the side tint replaces it. Indexed by UV.y
// (SoldierMesh parts): legs, tunic, skin, bronze, shield, iron.
const vec4 PALETTE[6] = {
	vec4(0.55, 0.42, 0.3, 0.0), vec4(0.5, 0.2, 0.15, 0.7), vec4(0.75, 0.58, 0.45, 0.0),
	vec4(0.62, 0.47, 0.2, 0.0), vec4(0.4, 0.3, 0.2, 1.0), vec4(0.72, 0.72, 0.74, 0.0)
};

void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float state = INSTANCE_CUSTOM.y;
	float upright = 1.0 - step(2.5, state);
	float fighting = step(0.5, state) * (1.0 - step(1.5, state));
	float stride = sin(phase);
	// Legs (below the hips) swing in opposition while walking.
	float leg = (1.0 - step(0.86, VERTEX.y)) * sign(VERTEX.x);
	VERTEX.z += upright * (1.0 - fighting) * leg * stride * 0.2 * (0.86 - VERTEX.y);
	VERTEX.y += upright * (1.0 - fighting) * abs(stride) * 0.04;
	// Weapon arm thrusts on the strike half of the cycle.
	VERTEX.z += upright * fighting * UV.x * max(0.0, sin(phase)) * 0.45;
	// Tired men stoop.
	VERTEX.z += upright * INSTANCE_CUSTOM.z * 0.12 * clamp(VERTEX.y - 0.9, 0.0, 1.0);
}

void fragment() {
	vec4 paint = PALETTE[clamp(int(UV.y + 0.5), 0, 5)];
	ALBEDO = mix(paint.rgb, tint, paint.a);
	ROUGHNESS = 0.9;
}
