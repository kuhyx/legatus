// BattleSim: bindings, setup and read-only queries. Tick and rendering
// fills live in battle_sim_run.cpp.
#include "battle_sim.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cmath>

namespace godot {

void BattleSim::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup_lines", "per_side", "frontage", "gap", "seed"),
			&BattleSim::setup_lines);
	ClassDB::bind_method(D_METHOD("setup_custom", "positions", "sides", "seed"),
			&BattleSim::setup_custom);
	ClassDB::bind_method(D_METHOD("tick", "dt"), &BattleSim::tick);
	ClassDB::bind_method(D_METHOD("fill_transforms", "side", "alpha"), &BattleSim::fill_transforms);
	ClassDB::bind_method(D_METHOD("fill_lod", "side", "alpha", "camera", "near"),
			&BattleSim::fill_lod);
	ClassDB::bind_method(D_METHOD("get_lod_buffer", "side", "far"), &BattleSim::get_lod_buffer);
	ClassDB::bind_method(D_METHOD("get_lod_count", "side", "far"), &BattleSim::get_lod_count);
	ClassDB::bind_method(D_METHOD("get_positions", "alpha"), &BattleSim::get_positions);
	ClassDB::bind_method(D_METHOD("rebuild_grid"), &BattleSim::rebuild_grid);
	ClassDB::bind_method(D_METHOD("query_neighbors", "index", "radius"),
			&BattleSim::query_neighbors);
	ClassDB::bind_method(D_METHOD("find_enemy", "index"), &BattleSim::find_enemy);
	ClassDB::bind_method(D_METHOD("get_count"), &BattleSim::get_count);
	ClassDB::bind_method(D_METHOD("get_side_count", "side"), &BattleSim::get_side_count);
	ClassDB::bind_method(D_METHOD("get_alive", "side"), &BattleSim::get_alive);
	ClassDB::bind_method(D_METHOD("get_hp", "index"), &BattleSim::get_hp);
	ClassDB::bind_method(D_METHOD("get_max_hp"), &BattleSim::get_max_hp);
	ClassDB::bind_method(D_METHOD("get_tick_count"), &BattleSim::get_tick_count);
	ClassDB::bind_method(D_METHOD("get_last_tick_usec"), &BattleSim::get_last_tick_usec);
	ClassDB::bind_method(D_METHOD("get_last_tick_threads"), &BattleSim::get_last_tick_threads);
	ClassDB::bind_method(D_METHOD("set_chunk_count", "chunks"), &BattleSim::set_chunk_count);
	ClassDB::bind_method(D_METHOD("get_chunk_count"), &BattleSim::get_chunk_count);
	ClassDB::bind_method(D_METHOD("set_search_cells", "cells"), &BattleSim::set_search_cells);
	ClassDB::bind_method(D_METHOD("get_search_cells"), &BattleSim::get_search_cells);
	BIND_CONSTANT(STRIDE);
	_bind_view_methods();
}

void BattleSim::setup_lines(int32_t p_per_side, float p_frontage, float p_gap, int64_t p_seed) {
	legatus::SimState &s = state;
	const int32_t per = std::max(1, p_per_side);
	s.resize(per * 2);
	s.seed = uint64_t(p_seed);
	const float file_gap = 1.0f; // m between files
	const float rank_gap = 1.1f; // m between ranks
	const int32_t files = std::max(1, int32_t(p_frontage / file_gap));
	const int32_t ranks = (per + files - 1) / files;
	for (int32_t i = 0; i < s.count; i++) {
		const int32_t side = i < per ? 0 : 1;
		const int32_t k = i - side * per;
		const int32_t file = k % files;
		const int32_t rank = k / files;
		const float jitter_x = (legatus::sim_rand(s.seed, 0, i, 7) - 0.5f) * 0.2f;
		const float jitter_z = (legatus::sim_rand(s.seed, 0, i, 8) - 0.5f) * 0.2f;
		const float x = (float(file) - 0.5f * float(files - 1)) * file_gap + jitter_x;
		const float depth = 0.5f * p_gap + float(rank) * rank_gap + jitter_z;
		s.side[i] = uint8_t(side);
		s.px[i] = x;
		s.home_x[i] = x;
		s.pz[i] = side == 0 ? -depth : depth;
		s.facing[i] = side == 0 ? 0.0f : float(Math_PI);
		s.formation[i] = side * 1000 + file / 60; // ~cohort-wide blocks
	}
	const float half_w = 0.5f * float(files) * file_gap + 80.0f;
	const float depth = 0.5f * p_gap + float(ranks) * rank_gap + 120.0f;
	finish_setup(-half_w, -depth, half_w, depth);
}

void BattleSim::setup_custom(const PackedVector2Array &p_pos, const PackedByteArray &p_sides,
		int64_t p_seed) {
	legatus::SimState &s = state;
	const int32_t n = int32_t(p_pos.size());
	ERR_FAIL_COND_MSG(p_sides.size() != n, "positions and sides differ in length");
	// Soldiers must be grouped by side (all side 0 first) for the side ranges.
	s.resize(n);
	s.seed = uint64_t(p_seed);
	float lo_x = 0.0f, lo_z = 0.0f, hi_x = 0.0f, hi_z = 0.0f;
	for (int32_t i = 0; i < n; i++) {
		const Vector2 p = p_pos[i];
		s.side[i] = uint8_t(p_sides[i] ? 1 : 0);
		ERR_FAIL_COND_MSG(i > 0 && s.side[i] < s.side[i - 1], "sides must be sorted");
		s.px[i] = p.x;
		s.pz[i] = p.y;
		s.home_x[i] = p.x;
		s.facing[i] = s.side[i] == 0 ? 0.0f : float(Math_PI);
		lo_x = std::min(lo_x, p.x);
		lo_z = std::min(lo_z, p.y);
		hi_x = std::max(hi_x, p.x);
		hi_z = std::max(hi_z, p.y);
	}
	finish_setup(lo_x - 50.0f, lo_z - 50.0f, hi_x + 50.0f, hi_z + 50.0f);
}

void BattleSim::finish_setup(float p_min_x, float p_min_z, float p_max_x, float p_max_z) {
	legatus::SimState &s = state;
	s.tick = 0;
	s.side_begin[0] = 0;
	s.side_begin[1] = int32_t(std::find(s.side.begin(), s.side.end(), 1) - s.side.begin());
	s.side_begin[2] = s.count;
	for (int32_t i = 0; i < s.count; i++) {
		s.hp[i] = s.params.max_hp;
		s.morale[i] = 1.0f;
		s.alive[i] = 1;
		s.target[i] = -1;
		s.state[i] = legatus::ST_ADVANCE;
		s.cooldown[i] = s.params.attack_interval * legatus::sim_rand(s.seed, 0, i, 9);
	}
	s.ox = s.px; // prev == current until the first tick: alpha is harmless
	s.oz = s.pz;
	s.ofacing = s.facing;
	s.grid.configure(p_min_x, p_min_z, p_max_x, p_max_z, 2.0f);
	alive_count[0] = s.side_begin[1];
	alive_count[1] = s.count - s.side_begin[1];
	last_tick_usec = 0;
	last_tick_threads = 0;
}

void BattleSim::rebuild_grid() {
	state.grid.build(state.px.data(), state.pz.data(), state.side.data(), state.alive.data(),
			state.count);
}

PackedInt32Array BattleSim::query_neighbors(int32_t p_index, float p_radius) const {
	// Test hook: living soldiers within radius of p_index, from the CURRENT
	// positions as of the last rebuild_grid(). Scans ceil(radius / cell) rings.
	PackedInt32Array out;
	ERR_FAIL_INDEX_V(p_index, state.count, out);
	const legatus::SimGrid &g = state.grid;
	const float x = state.px[p_index];
	const float z = state.pz[p_index];
	const int32_t rings = int32_t(std::ceil(p_radius / g.cell_size()));
	const int32_t cx = g.cell_x(x);
	const int32_t cz = g.cell_z(z);
	for (int32_t gz = std::max(0, cz - rings); gz <= std::min(g.height() - 1, cz + rings); gz++) {
		for (int32_t gx = std::max(0, cx - rings); gx <= std::min(g.width() - 1, cx + rings); gx++) {
			int32_t b = 0;
			int32_t e = 0;
			g.range(gx, gz, -1, b, e);
			for (int32_t k = b; k < e; k++) {
				const float dx = g.item_x()[k] - x;
				const float dz = g.item_z()[k] - z;
				if (g.items()[k] != p_index && dx * dx + dz * dz <= p_radius * p_radius) {
					out.push_back(g.items()[k]);
				}
			}
		}
	}
	return out;
}

int32_t BattleSim::find_enemy(int32_t p_index) const {
	ERR_FAIL_INDEX_V(p_index, state.count, -1);
	return legatus::sim_find_enemy(state, p_index);
}

int32_t BattleSim::get_side_count(int32_t p_side) const {
	ERR_FAIL_INDEX_V(p_side, 2, 0);
	return state.side_begin[p_side + 1] - state.side_begin[p_side];
}

int32_t BattleSim::get_alive(int32_t p_side) const {
	ERR_FAIL_INDEX_V(p_side, 2, 0);
	return alive_count[p_side];
}

int32_t BattleSim::get_hp(int32_t p_index) const {
	ERR_FAIL_INDEX_V(p_index, state.count, 0);
	return state.hp[p_index];
}

void BattleSim::set_chunk_count(int32_t p_chunks) {
	chunks = std::clamp(p_chunks, 1, 4096);
}

void BattleSim::set_search_cells(int32_t p_cells) {
	state.params.search_cells = std::clamp(p_cells, 0, 256);
}

} // namespace godot
