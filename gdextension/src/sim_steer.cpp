// Steering: what a soldier wants to do this tick, from his formation's order
// and morale. Called by the move kernel for living soldiers only. Writes only
// soldier i's own state; reads the frozen formation tables.
#include <algorithm>
#include <cmath>

#include "sim_state.h"

namespace legatus {

namespace {

constexpr float ANCHOR_SLACK = 0.3f; // m: close enough to the HOLD position
constexpr float FILE_PULL = 0.2f; // 1/s: drift back to one's own file
constexpr float FILE_PULL_MAX = 0.5f; // m/s

float keep_file(const SimState &s, int32_t i) {
	return std::clamp((s.home_x[i] - s.ox[i]) * FILE_PULL, -FILE_PULL_MAX, FILE_PULL_MAX);
}

bool should_rout(const SimState &s, int32_t i, int32_t f) {
	const FormationState &fs = s.forms;
	if (fs.routed[f]) {
		return true;
	}
	// A man runs on his own only when his unit is already wavering.
	return s.morale[i] < s.params.rout_morale &&
			fs.cohesion[f] < fs.params.soldier_rout_cohesion;
}

} // namespace

Steer sim_steer(SimState &s, int32_t p_index, int32_t p_target, float p_tdx, float p_tdz,
		float p_dist) {
	const SimParams &p = s.params;
	const FormationState &fs = s.forms;
	const int32_t i = p_index;
	const int32_t t = p_target;
	const int32_t f = s.formation[i];
	const float adv = s.side[i] == 0 ? 1.0f : -1.0f;
	const float vigour = 1.0f - 0.5f * s.fatigue[i];
	Steer out;
	if (s.state[i] == ST_ROUT || should_rout(s, i, f)) {
		// Fleeing to the own rear; each man at his own pace, so the slow are caught.
		const float pace = 1.0f + p.rout_spread * (2.0f * sim_rand(s.seed, 0, i, 12) - 1.0f);
		s.state[i] = ST_ROUT;
		out.vz = -adv * p.rout_speed * pace * vigour;
		return out;
	}
	const uint8_t order = fs.order[f];
	if (order == ORDER_WITHDRAW) { // back to the own rear in good order, no blows
		s.state[i] = ST_ADVANCE;
		out.vx = keep_file(s, i);
		out.vz = -adv * p.walk_speed * vigour;
		return out;
	}
	if (order == ORDER_HOLD) {
		const float ax = s.anchor_x[i] - s.ox[i];
		const float az = s.anchor_z[i] - s.oz[i];
		const float ad = std::sqrt(ax * ax + az * az);
		// Engage only what comes within charge range, on a leash to the anchor.
		if (t < 0 || p_dist >= p.charge_dist || ad >= p.charge_dist) {
			s.state[i] = ST_ADVANCE;
			const float k = ad > ANCHOR_SLACK ? std::min(p.walk_speed * vigour, ad) / ad : 0.0f;
			out.vx = ax * k;
			out.vz = az * k;
			out.face_target = t >= 0;
			out.face_front = true;
			return out;
		}
	}
	if (t >= 0) {
		const bool pursuing = fs.routed[s.formation[t]] != 0;
		const float hold = 0.8f * p.reach;
		const float run = pursuing ? p.pursuit_speed
								   : (p_dist < p.charge_dist ? p.charge_speed : p.walk_speed);
		const float k = p_dist > hold ? run * vigour / std::max(p_dist, 1e-3f) : 0.0f;
		out.vx = p_tdx * k;
		out.vz = p_tdz * k;
		out.face_target = p_dist < p.charge_dist;
		s.state[i] = p_dist <= p.reach ? ST_FIGHT : ST_ADVANCE;
		return out;
	}
	s.state[i] = ST_ADVANCE;
	out.vx = keep_file(s, i);
	out.vz = adv * p.walk_speed * vigour;
	return out;
}

} // namespace legatus
