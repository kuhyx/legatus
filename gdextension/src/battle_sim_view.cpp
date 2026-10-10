// BattleSim: the general's view of the battle. The ground the soldiers are
// drawn on, and the coarse sight tiles that hide whatever he cannot see
// (R4: only what a general on a horse could see is drawn).
#include "battle_sim.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>

namespace godot {

namespace {
float key(const Dictionary &p_dict, const char *p_key, float p_default) {
	return p_dict.has(p_key) ? float(p_dict[p_key]) : p_default;
}
} // namespace

void BattleSim::_bind_view_methods() {
	ClassDB::bind_method(D_METHOD("get_drawn_count", "side"), &BattleSim::get_drawn_count);
	ClassDB::bind_method(D_METHOD("get_visible_alive", "side"), &BattleSim::get_visible_alive);
	ClassDB::bind_method(D_METHOD("set_height_field", "heights", "resolution", "spacing", "origin"),
			&BattleSim::set_height_field);
	ClassDB::bind_method(D_METHOD("get_ground_height", "x", "z"), &BattleSim::get_ground_height);
	ClassDB::bind_method(
			D_METHOD("set_visibility_tiles", "visible", "origin", "tile_size", "cols", "rows"),
			&BattleSim::set_visibility_tiles);
	ClassDB::bind_method(D_METHOD("get_visibility_tiles"), &BattleSim::get_visibility_tiles);
	ClassDB::bind_method(D_METHOD("get_tile_count"), &BattleSim::get_tile_count);
	ClassDB::bind_method(D_METHOD("set_sight", "sight"), &BattleSim::set_sight);
	ClassDB::bind_method(D_METHOD("sight_factor", "eye", "point"), &BattleSim::sight_factor);
	ClassDB::bind_method(D_METHOD("compute_visibility_tiles", "eye", "first", "count"),
			&BattleSim::compute_visibility_tiles);
	ClassDB::bind_method(D_METHOD("get_bounds"), &BattleSim::get_bounds);
}

void BattleSim::set_height_field(const PackedFloat32Array &p_heights, int32_t p_resolution,
		float p_spacing, const Vector2 &p_origin) {
	legatus::GroundField g;
	if (p_resolution >= 2) {
		ERR_FAIL_COND_MSG(p_heights.size() != int64_t(p_resolution) * p_resolution,
				"heights must hold resolution * resolution samples");
		ERR_FAIL_COND_MSG(p_spacing <= 0.0f, "spacing must be positive");
		g.heights.assign(p_heights.ptr(), p_heights.ptr() + p_heights.size());
		g.resolution = p_resolution;
		g.spacing = p_spacing;
		g.origin_x = p_origin.x;
		g.origin_z = p_origin.y;
	}
	ground = std::move(g); // resolution < 2: back to flat ground at y = 0
}

float BattleSim::get_ground_height(float p_x, float p_z) const {
	return ground.height_at(p_x, p_z);
}

void BattleSim::set_visibility_tiles(const PackedByteArray &p_visible, const Vector2 &p_origin,
		float p_tile_size, int32_t p_cols, int32_t p_rows) {
	legatus::SightTiles t;
	if (!p_visible.is_empty()) {
		ERR_FAIL_COND_MSG(p_cols <= 0 || p_rows <= 0 || p_tile_size <= 0.0f, "bad tile grid");
		ERR_FAIL_COND_MSG(p_visible.size() != int64_t(p_cols) * p_rows,
				"visible must hold cols * rows tiles");
		t.visible.assign(p_visible.ptr(), p_visible.ptr() + p_visible.size());
		t.origin_x = p_origin.x;
		t.origin_z = p_origin.y;
		t.tile_size = p_tile_size;
		t.cols = p_cols;
		t.rows = p_rows;
	}
	tiles = std::move(t); // empty mask: culling off, everything drawn
}

PackedByteArray BattleSim::get_visibility_tiles() const {
	PackedByteArray out;
	out.resize(int64_t(tiles.visible.size()));
	std::copy(tiles.visible.begin(), tiles.visible.end(), out.ptrw());
	return out;
}

void BattleSim::set_sight(const Dictionary &p_sight) {
	legatus::SightParams p;
	p.max_distance = key(p_sight, "max_distance", p.max_distance);
	p.haze_start = key(p_sight, "haze_start", p.haze_start);
	p.threshold = key(p_sight, "threshold", p.threshold);
	p.canopy_height = key(p_sight, "canopy_height", p.canopy_height);
	p.woods_extinction = key(p_sight, "woods_extinction", p.woods_extinction);
	p.dust_extinction = key(p_sight, "dust_extinction", p.dust_extinction);
	p.terrain_tolerance = key(p_sight, "terrain_tolerance", p.terrain_tolerance);
	p.end_clearance = key(p_sight, "end_clearance", p.end_clearance);
	p.earth_radius = key(p_sight, "earth_radius", p.earth_radius);
	p.dust_density = key(p_sight, "dust_density", p.dust_density);
	p.target_height = key(p_sight, "target_height", p.target_height);
	const PackedVector2Array centers = p_sight.get("woods_centers", PackedVector2Array());
	const PackedFloat32Array radii = p_sight.get("woods_radii", PackedFloat32Array());
	ERR_FAIL_COND_MSG(centers.size() != radii.size(), "woods centers and radii differ");
	for (int64_t i = 0; i < centers.size(); i++) {
		p.woods_x.push_back(centers[i].x);
		p.woods_z.push_back(centers[i].y);
		p.woods_r.push_back(radii[i]);
	}
	sight = std::move(p);
}

float BattleSim::sight_factor(const Vector3 &p_eye, const Vector3 &p_point) const {
	return legatus::sight_factor(ground, sight, { p_eye.x, p_eye.y, p_eye.z },
			{ p_point.x, p_point.y, p_point.z });
}

int32_t BattleSim::compute_visibility_tiles(const Vector3 &p_eye, int32_t p_first,
		int32_t p_count) {
	const int32_t total = get_tile_count();
	const int32_t end = std::min(total, p_first + std::max(0, p_count));
	const legatus::Vec3f eye = { p_eye.x, p_eye.y, p_eye.z };
	int32_t seen = 0;
	for (int32_t k = std::max(0, p_first); k < end; k++) {
		const float x = tiles.origin_x + (float(k % tiles.cols) + 0.5f) * tiles.tile_size;
		const float z = tiles.origin_z + (float(k / tiles.cols) + 0.5f) * tiles.tile_size;
		const legatus::Vec3f pt = { x, ground.height_at(x, z) + sight.target_height, z };
		const bool vis = legatus::sight_factor(ground, sight, eye, pt) >= sight.threshold;
		tiles.visible[size_t(k)] = vis ? 1 : 0;
		seen += vis ? 1 : 0;
	}
	return seen;
}

Rect2 BattleSim::get_bounds() const {
	const legatus::SimGrid &g = state.grid;
	return Rect2(g.min_x(), g.min_z(), g.max_x() - g.min_x(), g.max_z() - g.min_z());
}

} // namespace godot
