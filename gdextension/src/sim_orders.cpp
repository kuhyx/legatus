// Orders and the serial halt / rally step. sim_formation_order runs between
// ticks (from GDScript); sim_orders_pass runs at the end of the serial
// formation pass. Both write per-soldier anchors in soldier index order, so
// the result stays independent of chunking and thread count.
#include <algorithm>
#include <cmath>

#include "sim_state.h"

namespace legatus {

namespace {

constexpr float MAX_STRESS = 2.0f;
constexpr float ARRIVE_M = 2.0f; // a withdrawal's centroid this close to its goal halts
constexpr float FILE_GAP = 1.0f; // re-formed ranks: the spacing setup_lines deploys
constexpr float RANK_GAP = 1.1f;

float advance_sign(const SimState &s, int32_t p_f) {
	return s.forms.side[p_f] == 0 ? 1.0f : -1.0f;
}

float clamp_x(const SimState &s, float p_x) {
	return std::clamp(p_x, s.grid.min_x() + 1.0f, s.grid.max_x() - 1.0f);
}

float clamp_z(const SimState &s, float p_z) {
	return std::clamp(p_z, s.grid.min_z() + 1.0f, s.grid.max_z() - 1.0f);
}

// Every man's anchor withdraw_dist to his own rear (inside the box); the
// formation halts when its centroid reaches the mean of them.
void set_withdraw_goal(SimState &s, int32_t p_f) {
	FormationState &fs = s.forms;
	const float back = -advance_sign(s, p_f) * fs.params.withdraw_dist;
	double gx = 0.0;
	double gz = 0.0;
	int32_t n = 0;
	for (int32_t i = 0; i < s.count; i++) {
		if (s.formation[i] != p_f) {
			continue;
		}
		s.anchor_x[i] = s.px[i];
		s.anchor_z[i] = clamp_z(s, s.pz[i] + back);
		if (s.alive[i]) {
			gx += double(s.anchor_x[i]);
			gz += double(s.anchor_z[i]);
			n++;
		}
	}
	fs.goal_x[p_f] = n > 0 ? float(gx / double(n)) : fs.cx[p_f];
	fs.goal_z[p_f] = n > 0 ? float(gz / double(n)) : fs.cz[p_f];
}

bool near_formation(const FormationState &fs, int32_t p_f, bool p_enemy, float p_radius) {
	for (int32_t g = 0; g < fs.count; g++) {
		if (g == p_f || fs.routed[g] || fs.living[g] == 0 ||
				(fs.side[g] != fs.side[p_f]) != p_enemy) {
			continue;
		}
		const float dx = fs.cx[g] - fs.cx[p_f];
		const float dz = fs.cz[g] - fs.cz[p_f];
		if (dx * dx + dz * dz < p_radius * p_radius) {
			return true;
		}
	}
	return false;
}

// The survivors stop running and form up around their centroid: front-most
// men in the front rank, each rank ordered left to right so few cross.
void reform(SimState &s, int32_t p_f) {
	const FormationState &fs = s.forms;
	const float adv = advance_sign(s, p_f);
	std::vector<int32_t> men;
	float lo = 1e30f;
	float hi = -1e30f;
	for (int32_t i = 0; i < s.count; i++) {
		if (s.formation[i] == p_f && s.alive[i]) {
			men.push_back(i);
			lo = std::min(lo, s.home_x[i]);
			hi = std::max(hi, s.home_x[i]);
		}
	}
	const int32_t n = int32_t(men.size());
	if (n == 0) {
		return;
	}
	const int32_t files = std::clamp(int32_t(std::lround((hi - lo) / FILE_GAP)) + 1, 1, n);
	const int32_t ranks = (n + files - 1) / files;
	std::sort(men.begin(), men.end(), [&](int32_t a, int32_t b) {
		const float da = adv * s.pz[a];
		const float db = adv * s.pz[b];
		return da != db ? da > db : a < b;
	});
	const float front = fs.cz[p_f] + adv * 0.5f * float(ranks - 1) * RANK_GAP;
	for (int32_t r = 0; r < ranks; r++) {
		const auto b = men.begin() + r * files;
		const auto e = men.begin() + std::min(n, (r + 1) * files);
		std::sort(b, e, [&](int32_t a, int32_t c) {
			return s.px[a] != s.px[c] ? s.px[a] < s.px[c] : a < c;
		});
		const float left = fs.cx[p_f] - 0.5f * float(int32_t(e - b) - 1) * FILE_GAP;
		for (auto it = b; it != e; ++it) {
			const int32_t i = *it;
			s.anchor_x[i] = clamp_x(s, left + float(it - b) * FILE_GAP);
			s.anchor_z[i] = clamp_z(s, front - adv * float(r) * RANK_GAP);
			s.home_x[i] = s.anchor_x[i];
			s.state[i] = ST_ADVANCE; // no longer running
		}
	}
}

void rally(SimState &s, int32_t p_f) {
	FormationState &fs = s.forms;
	fs.routed[p_f] = 0;
	fs.rallied[p_f] = 1;
	fs.order[p_f] = ORDER_HOLD;
	fs.loss_base[p_f] = fs.losses(p_f); // a fresh threshold from here on
	fs.stress[p_f] = 1.0f - fs.params.rally_cohesion;
	fs.cohesion[p_f] = fs.params.rally_cohesion;
	fs.clear[p_f] = 0.0f;
	reform(s, p_f);
}

} // namespace

bool sim_formation_order(SimState &s, int32_t p_f, uint8_t p_order) {
	FormationState &fs = s.forms;
	if (fs.routed[p_f]) {
		return false;
	}
	if (p_order == ORDER_WITHDRAW && fs.order[p_f] != ORDER_WITHDRAW && fs.engaged[p_f] > 0) {
		// Turning away from men still swinging at you (DOCS-design-command §3).
		fs.stress[p_f] = std::min(MAX_STRESS, fs.stress[p_f] + fs.params.withdraw_shock);
		fs.cohesion[p_f] = std::clamp(fs.cohesion_of(p_f), 0.0f, 1.0f);
	}
	if (p_order == ORDER_HOLD) { // stand where the order found each man
		for (int32_t i = 0; i < s.count; i++) {
			if (s.formation[i] == p_f) {
				s.anchor_x[i] = s.px[i];
				s.anchor_z[i] = s.pz[i];
			}
		}
	}
	if (p_order == ORDER_WITHDRAW) {
		set_withdraw_goal(s, p_f);
	}
	fs.order[p_f] = p_order;
	return true;
}

void sim_orders_pass(SimState &s) {
	FormationState &fs = s.forms;
	const FormationParams &fp = fs.params;
	for (int32_t f = 0; f < fs.count; f++) {
		if (fs.living[f] == 0) {
			continue;
		}
		if (!fs.routed[f]) {
			const float dx = fs.cx[f] - fs.goal_x[f];
			const float dz = fs.cz[f] - fs.goal_z[f];
			if (fs.order[f] == ORDER_WITHDRAW && dx * dx + dz * dz < ARRIVE_M * ARRIVE_M) {
				fs.order[f] = ORDER_HOLD; // anchors already stand on the goal
			}
			continue;
		}
		if (fs.rallied[f]) {
			continue; // a formation rallies once; a second rout is final
		}
		const bool pursued = near_formation(fs, f, true, fp.rally_enemy_radius);
		fs.clear[f] = pursued ? 0.0f : fs.clear[f] + s.dt;
		if (fs.clear[f] >= fp.rally_clear && near_formation(fs, f, false, fp.rally_friend_radius)) {
			rally(s, f);
		}
	}
}

} // namespace legatus
