// Formations: order and morale groups over individual soldiers. Ids are
// contiguous 0..F-1, side 0's first. Every per-formation number lives here;
// the parallel kernels only READ it (frozen for the whole move/damage phase)
// and the serial formation pass after the damage phase is its only writer,
// so the result stays independent of chunking and thread count.
#pragma once

#include <cstdint>
#include <vector>

namespace legatus {

enum FormationOrder : uint8_t {
	ORDER_ADVANCE = 0,
	ORDER_HOLD = 1,
	ORDER_WITHDRAW = 2,
};

// [design guess] cohesion constants; the rows live in DOCS-design.md.
struct FormationParams {
	float break_min = 0.04f; // loss fraction a formation can take, sampled per formation
	float break_max = 0.10f; // "at or before 10 % losses" (Part IIIc)
	float engaged_stress = 0.0015f; // cohesion lost per second of line contact
	float engaged_full = 0.02f; // engaged share of the living for full contact stress
	float recover = 0.004f; // stress shed per second out of contact
	float contagion = 0.0f; // per second, a routing friend at distance 0 (off: see DOCS)
	float contagion_radius = 150.0f; // m between centroids
	float enemy_relief = 0.03f; // per second, an enemy formation routing at distance 0
	float rout_shock = 0.5f; // once, when a friend breaks at distance 0
	float rout_relief = 0.5f; // once, when an enemy breaks at distance 0
	float withdraw_shock = 0.4f; // ordered back while in contact
	float soldier_rout_cohesion = 0.1f; // a frightened man runs alone only below this
	float withdraw_dist = 150.0f; // m an ordered withdrawal walks back, then holds
	float rally_enemy_radius = 60.0f; // m: an unrouted enemy this close = still pursued
	float rally_clear = 20.0f; // s unpursued before a routed formation can rally
	float rally_friend_radius = 150.0f; // m: an unrouted friend in sight to rally on
	float rally_cohesion = 0.3f; // cohesion a rallied formation comes back with
};

struct FormationState {
	FormationParams params;
	int32_t count = 0;
	std::vector<uint8_t> side, order, routed, rallied;
	// Enemy formations whose box lies within nearest-enemy search reach of
	// this one's: up to NEAR_MAX ids per formation; near_n = NEAR_MAX + 1
	// means "more than that, always search". A man farther than the reach
	// from all of them skips the search (it could only find nobody).
	static constexpr int32_t NEAR_MAX = 8;
	std::vector<int32_t> near_n, near_ids;
	float search_reach = 0.0f;
	// Recounted every tick by the serial pass (living = alive and not fled).
	std::vector<int32_t> start, living, dead, fled, engaged;
	// stress: recoverable strain (contact, contagion, orders). cohesion =
	// 1 - (losses - loss_base) / threshold - stress, clamped to [0, 1]; 0 =
	// the formation routs.
	std::vector<float> stress, cohesion, threshold, break_losses, cx, cz;
	// loss_base: losses already counted when it rallied (only later ones
	// count against the threshold again); clear: seconds a routed formation
	// has gone unpursued; goal_*: centroid a withdrawal halts at.
	std::vector<float> loss_base, clear, goal_x, goal_z;
	std::vector<float> lo_x, lo_z, hi_x, hi_z; // box of the living, this tick

	void resize(int32_t p_count);
	float losses(int32_t p_f) const {
		return start[p_f] > 0 ? float(dead[p_f] + fled[p_f]) / float(start[p_f]) : 0.0f;
	}
	float cohesion_of(int32_t p_f) const {
		return 1.0f - (losses(p_f) - loss_base[p_f]) / threshold[p_f] - stress[p_f];
	}
	// Friends walk through each other's ranks while one of them is routed or
	// withdrawing (the gaps a real line opened for it).
	bool passing(int32_t p_f) const { return routed[p_f] || order[p_f] == ORDER_WITHDRAW; }
};

} // namespace legatus
