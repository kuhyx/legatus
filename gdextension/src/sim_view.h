// What the battle looks like from the general's saddle: the ground the
// soldiers stand on, and which coarse tiles of the battlefield he can see.
// Pure C++ (no Godot calls) so the fill chunks can read it on worker threads.
// GroundField and sight_factor mirror src/general/height_field.gd and
// visibility.gd line for line; tests/unit/test_battle_sight.gd holds them equal.
#pragma once

#include <cstdint>
#include <vector>

namespace legatus {

// Square heightmap, row-major, x fastest, sample (0, 0) at (origin_x, origin_z).
struct GroundField {
	std::vector<float> heights;
	int32_t resolution = 0;
	float spacing = 1.0f;
	float origin_x = 0.0f;
	float origin_z = 0.0f;

	bool empty() const { return resolution < 2; }
	// Bilinear, clamped at the edges; 0 when empty (flat ground at y = 0).
	float height_at(float p_x, float p_z) const;
};

// Coarse visibility mask over the battlefield: 1 = the general sees the tile.
// No mask = everything visible. Points outside the grid count as visible: the
// grid covers the sim bounds, so this only matters for hand-made test masks.
struct SightTiles {
	std::vector<uint8_t> visible;
	float origin_x = 0.0f;
	float origin_z = 0.0f;
	float tile_size = 25.0f;
	int32_t cols = 0;
	int32_t rows = 0;

	bool active() const { return !visible.empty(); }
	bool is_visible(float p_x, float p_z) const;
};

// Constants come from GDScript VisionTable (one source of truth) via set_sight.
struct SightParams {
	float max_distance = 3000.0f;
	float haze_start = 200.0f;
	float threshold = 0.1f;
	float canopy_height = 15.0f;
	float woods_extinction = 12.0f;
	float dust_extinction = 120.0f;
	float terrain_tolerance = 0.1f;
	float end_clearance = 2.0f;
	float earth_radius = 6371000.0f;
	float dust_density = 0.0f;
	float target_height = 1.7f; // sample point above a tile centre's ground
	std::vector<float> woods_x, woods_z, woods_r;
};

struct Vec3f {
	float x, y, z;
};

// 0..1: how clearly p_point stands out from p_eye. 0 = hidden.
float sight_factor(const GroundField &p_ground, const SightParams &p_sight, Vec3f p_eye,
		Vec3f p_point);

} // namespace legatus
