// Terrain: the Part 4a sRGB vertex colours, plus near-ground detail so the
// ground visibly slides past the rider even at a walk (Part 4b ground cue).
// World-space noise at two scales, faded out by fade_end_m: no extra draw
// calls, no texture on disk (Terrain makes the noise at runtime).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail_noise : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// Metres of ground per repeat of the noise texture for each octave.
uniform float fine_tile_m = 6.0;
uniform float grain_tile_m = 1.3;
uniform float coarse_tile_m = 41.0;
// Peak brightness change (share of albedo) right under the horse.
uniform float strength = 0.35;
// Mean of the noise texture, so the detail averages out to the plain
// vertex colour (no brightness shift where the mipmaps blur it).
uniform float noise_mean = 0.5;
// Dark green tufts: share of the ground they cover (via a noise threshold)
// and how much darker they are.
uniform float tuft_threshold = 0.16;
uniform float tuft_darken = 0.3;
uniform float tuft_tile_m = 2.3;
uniform float fade_start_m = 12.0;
uniform float fade_end_m = 60.0;

varying vec3 world_pos;

vec3 srgb_to_linear(vec3 c) {
	vec3 lo = c / 12.92;
	vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
	return mix(hi, lo, vec3(lessThan(c, vec3(0.04045))));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	COLOR.rgb = srgb_to_linear(COLOR.rgb);
}

void fragment() {
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(fade_start_m, fade_end_m, dist);
	vec2 xz = world_pos.xz;
	float fine = texture(detail_noise, xz / fine_tile_m).r - noise_mean;
	float grain = texture(detail_noise, xz / grain_tile_m + vec2(0.37, 0.71)).r - noise_mean;
	float coarse = texture(detail_noise, xz / coarse_tile_m + vec2(0.11, 0.53)).r - noise_mean;
	float tuft_n = texture(detail_noise, xz / tuft_tile_m + vec2(0.61, 0.19)).r - noise_mean;
	float detail = (fine * 0.5 + grain * 0.35 + coarse * 0.3) * fade;
	float tuft = smoothstep(tuft_threshold, tuft_threshold + 0.08, tuft_n) * fade;
	vec3 albedo = COLOR.rgb * (1.0 + 2.0 * strength * detail);
	// Darker patches lean greener, lighter ones drier: grass, not grey noise.
	albedo *= vec3(1.0 + 0.2 * detail, 1.0, 1.0 - 0.3 * detail);
	albedo *= mix(vec3(1.0), vec3(0.62, 0.78, 0.55), tuft * tuft_darken / 0.3);
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
