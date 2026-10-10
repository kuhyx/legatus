// BattleSim: the battle scene's deployment. Each side stands in lines one
// behind the other (triplex acies), every line `frontage` wide, cut into
// ~60-file blocks like setup_lines. setup_lines itself stays untouched: the
// bench and the morale calibration are measured on it.
#include "battle_sim.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cmath>
#include <vector>

namespace godot {

namespace {

constexpr float FILE_GAP = 1.0f; // m between files, as setup_lines
constexpr float RANK_GAP = 1.1f; // m between ranks
constexpr int32_t BLOCK_FILES = 60; // ~cohort-wide blocks
constexpr float SIDE_MARGIN = 80.0f; // m of box beside the line
constexpr float REAR_MARGIN = 60.0f; // m of box behind the rear line's withdrawal

// Soldiers per line from the shares (normalised); the last line takes the rest.
std::vector<int32_t> line_counts(int32_t p_per_side, const PackedFloat32Array &p_shares) {
	float total = 0.0f;
	for (int64_t l = 0; l < p_shares.size(); l++) {
		total += std::max(0.0f, p_shares[l]);
	}
	std::vector<int32_t> out(size_t(p_shares.size()), 0);
	int32_t left = p_per_side;
	for (size_t l = 0; l + 1 < out.size(); l++) {
		const float share = total > 0.0f ? std::max(0.0f, p_shares[int64_t(l)]) / total : 0.0f;
		out[l] = std::min(left, int32_t(std::lround(float(p_per_side) * share)));
		left -= out[l];
	}
	out.back() = left;
	return out;
}

} // namespace

void BattleSim::_bind_setup_methods() {
	ClassDB::bind_method(D_METHOD("setup_array", "per_side", "frontage", "gap", "line_gap",
								 "lines_0", "lines_1", "seed"),
			&BattleSim::setup_array);
	ClassDB::bind_method(D_METHOD("get_formation_bounds", "formation"),
			&BattleSim::get_formation_bounds);
}

void BattleSim::setup_array(int32_t p_per_side, float p_frontage, float p_gap, float p_line_gap,
		const PackedFloat32Array &p_lines_0, const PackedFloat32Array &p_lines_1, int64_t p_seed) {
	ERR_FAIL_COND_MSG(p_lines_0.is_empty() || p_lines_1.is_empty(), "each side needs a line");
	legatus::SimState &s = state;
	const int32_t per = std::max(1, p_per_side);
	s.resize(per * 2);
	s.seed = uint64_t(p_seed);
	const int32_t files = std::max(1, int32_t(p_frontage / FILE_GAP));
	int32_t i = 0;
	int32_t first_block = 0; // formation ids: contiguous, side 0 first, front line first
	float rear = 0.0f; // deepest rear rank of either side, m from the centre
	for (int32_t side = 0; side < 2; side++) {
		const std::vector<int32_t> counts = line_counts(per, side == 0 ? p_lines_0 : p_lines_1);
		float front = 0.5f * p_gap;
		for (const int32_t n : counts) {
			if (n == 0) {
				continue;
			}
			const int32_t ranks = (n + files - 1) / files;
			for (int32_t k = 0; k < n; k++, i++) {
				const int32_t file = k % files;
				const float jitter_x = (legatus::sim_rand(s.seed, 0, i, 7) - 0.5f) * 0.2f;
				const float jitter_z = (legatus::sim_rand(s.seed, 0, i, 8) - 0.5f) * 0.2f;
				const float x = (float(file) - 0.5f * float(files - 1)) * FILE_GAP + jitter_x;
				const float depth = front + float(k / files) * RANK_GAP + jitter_z;
				s.side[i] = uint8_t(side);
				s.px[i] = x;
				s.home_x[i] = x;
				s.pz[i] = side == 0 ? -depth : depth;
				s.facing[i] = side == 0 ? 0.0f : float(Math_PI);
				s.formation[i] = first_block + file / BLOCK_FILES;
			}
			first_block += (std::min(n, files) + BLOCK_FILES - 1) / BLOCK_FILES;
			const float line_rear = front + float(ranks - 1) * RANK_GAP;
			rear = std::max(rear, line_rear);
			front = line_rear + p_line_gap; // the gap runs rear rank to next front rank
		}
	}
	const float half_w = 0.5f * float(files) * FILE_GAP + SIDE_MARGIN;
	const float depth = rear + s.forms.params.withdraw_dist + REAR_MARGIN;
	finish_setup(-half_w, -depth, half_w, depth);
}

Rect2 BattleSim::get_formation_bounds(int32_t p_f) const {
	ERR_FAIL_INDEX_V(p_f, state.forms.count, Rect2());
	const legatus::SimState &s = state;
	float lo_x = 1e30f, lo_z = 1e30f, hi_x = -1e30f, hi_z = -1e30f;
	for (int32_t i = 0; i < s.count; i++) {
		if (s.formation[i] == p_f && s.alive[i]) {
			lo_x = std::min(lo_x, s.px[i]);
			lo_z = std::min(lo_z, s.pz[i]);
			hi_x = std::max(hi_x, s.px[i]);
			hi_z = std::max(hi_z, s.pz[i]);
		}
	}
	return hi_x < lo_x ? Rect2() : Rect2(lo_x, lo_z, hi_x - lo_x, hi_z - lo_z);
}

} // namespace godot
