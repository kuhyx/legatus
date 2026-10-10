// Formations: order and morale groups over individual soldiers. Ids are
// contiguous 0..F-1, side 0's first. Every per-formation number lives here;
// the parallel kernels only READ it (frozen for the whole move/damage phase)
// and the serial formation pass after the damage phase is its only writer,
// so the result stays independent of chunking and thread count.
#pragma once

#include <cstdint>
#include <vector>

namespace legatus {

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
};

struct FormationState {
	FormationParams params;
	int32_t count = 0;
	std::vector<uint8_t> side, order, routed;
	// Recounted every tick by the serial pass (living = alive and not fled).
	std::vector<int32_t> start, living, dead, fled, engaged;
	// stress: recoverable strain (contact, contagion, orders). cohesion =
	// 1 - losses / threshold - stress, clamped to [0, 1]; 0 = the formation routs.
	std::vector<float> stress, cohesion, threshold, break_losses, cx, cz;

	void resize(int32_t p_count);
	float losses(int32_t p_f) const {
		return start[p_f] > 0 ? float(dead[p_f] + fled[p_f]) / float(start[p_f]) : 0.0f;
	}
};

} // namespace legatus
