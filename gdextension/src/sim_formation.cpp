// The serial formation pass: once per tick, after the damage phase, in
// soldier index order (no per-chunk float reductions, so any chunking gives
// bit-identical results). Takes fled men off the field, recounts every
// formation, then updates stress, cohesion and routs in formation order.
#include <algorithm>
#include <cmath>

#include "sim_state.h"

namespace legatus {

namespace {

constexpr uint32_t SALT_BREAK = 13;
constexpr float MAX_STRESS = 2.0f;

// Living / dead / fled / engaged and the centroid of the living, per formation.
void tally(SimState &s, int32_t r_fled[2]) {
	FormationState &fs = s.forms;
	std::fill(fs.living.begin(), fs.living.end(), 0);
	std::fill(fs.dead.begin(), fs.dead.end(), 0);
	std::fill(fs.fled.begin(), fs.fled.end(), 0);
	std::fill(fs.engaged.begin(), fs.engaged.end(), 0);
	std::vector<double> sx(size_t(fs.count), 0.0);
	std::vector<double> sz(size_t(fs.count), 0.0);
	for (int32_t i = 0; i < s.count; i++) {
		const int32_t f = s.formation[i];
		const uint8_t st = s.state[i];
		if (st == ST_DEAD) {
			fs.dead[f]++;
			continue;
		}
		if (st == ST_FLED) {
			if (s.alive[i]) { // left the field this tick: no longer in the battle
				s.alive[i] = 0;
				r_fled[s.side[i]]++;
			}
			fs.fled[f]++;
			continue;
		}
		fs.living[f]++;
		sx[size_t(f)] += double(s.px[i]);
		sz[size_t(f)] += double(s.pz[i]);
		const int32_t t = s.target[i];
		if (st == ST_FIGHT && t >= 0 && !fs.routed[s.formation[t]]) {
			fs.engaged[f]++; // trading blows with men who still fight back
		}
	}
	for (int32_t f = 0; f < fs.count; f++) {
		if (fs.living[f] > 0) {
			fs.cx[f] = float(sx[size_t(f)] / double(fs.living[f]));
			fs.cz[f] = float(sz[size_t(f)] / double(fs.living[f]));
		}
	}
}

// Stress per second from routing formations near f's centroid: a friend
// running is contagious, an enemy running is a relief.
float contagion(const FormationState &fs, int32_t p_f) {
	const FormationParams &fp = fs.params;
	float shock = 0.0f;
	for (int32_t g = 0; g < fs.count; g++) {
		if (g == p_f || !fs.routed[g] || fs.living[g] == 0) {
			continue;
		}
		const float dx = fs.cx[g] - fs.cx[p_f];
		const float dz = fs.cz[g] - fs.cz[p_f];
		const float d = std::sqrt(dx * dx + dz * dz);
		if (d < fp.contagion_radius) {
			const float near = 1.0f - d / fp.contagion_radius;
			shock += (fs.side[g] == fs.side[p_f] ? fp.contagion : -fp.enemy_relief) * near;
		}
	}
	return shock;
}

// The moment f breaks, every formation within the radius sees it: a one-off
// shock to its own side, a one-off relief to the enemy's.
void break_shock(FormationState &fs, int32_t p_f) {
	const FormationParams &fp = fs.params;
	for (int32_t g = 0; g < fs.count; g++) {
		if (g == p_f || fs.routed[g] || fs.living[g] == 0) {
			continue;
		}
		const float dx = fs.cx[g] - fs.cx[p_f];
		const float dz = fs.cz[g] - fs.cz[p_f];
		const float d = std::sqrt(dx * dx + dz * dz);
		if (d < fp.contagion_radius) {
			const float near = 1.0f - d / fp.contagion_radius;
			const float jolt = fs.side[g] == fs.side[p_f] ? fp.rout_shock : -fp.rout_relief;
			fs.stress[g] = std::clamp(fs.stress[g] + jolt * near, 0.0f, MAX_STRESS);
		}
	}
}

float cohesion_of(const FormationState &fs, int32_t p_f) {
	return 1.0f - fs.losses(p_f) / fs.threshold[p_f] - fs.stress[p_f];
}

} // namespace

void FormationState::resize(int32_t p_count) {
	count = p_count;
	const size_t n = size_t(p_count);
	for (std::vector<uint8_t> *v : { &side, &order, &routed }) {
		v->assign(n, 0);
	}
	for (std::vector<int32_t> *v : { &start, &living, &dead, &fled, &engaged }) {
		v->assign(n, 0);
	}
	for (std::vector<float> *v : { &stress, &threshold, &cx, &cz }) {
		v->assign(n, 0.0f);
	}
	cohesion.assign(n, 1.0f);
	break_losses.assign(n, -1.0f);
}

bool sim_formation_setup(SimState &s) {
	FormationState &fs = s.forms;
	int32_t n = 0;
	for (int32_t i = 0; i < s.count; i++) {
		if (s.formation[i] < 0) {
			return false;
		}
		n = std::max(n, s.formation[i] + 1);
	}
	fs.resize(n);
	std::vector<uint8_t> seen(size_t(n), 0);
	for (int32_t i = 0; i < s.count; i++) {
		const int32_t f = s.formation[i];
		if (seen[size_t(f)] && fs.side[f] != s.side[i]) {
			return false; // a formation belongs to one side
		}
		seen[size_t(f)] = 1;
		fs.side[f] = s.side[i];
		fs.start[f] += s.state[i] == ST_DEAD ? 0 : 1;
		s.anchor_x[i] = s.px[i];
		s.anchor_z[i] = s.pz[i];
	}
	const FormationParams &fp = fs.params;
	for (int32_t f = 0; f < n; f++) {
		fs.threshold[f] = fp.break_min + (fp.break_max - fp.break_min) * sim_rand(s.seed, 0, f, SALT_BREAK);
	}
	int32_t fled[2] = { 0, 0 };
	tally(s, fled);
	return true;
}

void sim_formation_pass(SimState &s, int32_t r_fled[2]) {
	FormationState &fs = s.forms;
	const FormationParams &fp = fs.params;
	tally(s, r_fled);
	for (int32_t f = 0; f < fs.count; f++) {
		if (fs.routed[f] || fs.start[f] == 0) {
			continue;
		}
		float stress = fs.stress[f];
		if (fs.engaged[f] > 0) {
			const float full = std::max(1.0f, fp.engaged_full * float(fs.living[f]));
			stress += fp.engaged_stress * std::min(1.0f, float(fs.engaged[f]) / full) * s.dt;
		} else {
			stress -= fp.recover * s.dt;
		}
		stress += contagion(fs, f) * s.dt;
		fs.stress[f] = std::clamp(stress, 0.0f, MAX_STRESS);
		const float c = cohesion_of(fs, f);
		if (c <= 0.0f) { // the formation breaks: every man of it runs
			fs.routed[f] = 1;
			fs.break_losses[f] = fs.losses(f);
			fs.cohesion[f] = 0.0f;
			break_shock(fs, f);
		} else {
			fs.cohesion[f] = std::min(1.0f, c);
		}
	}
}

bool sim_formation_order(SimState &s, int32_t p_f, uint8_t p_order) {
	FormationState &fs = s.forms;
	if (fs.routed[p_f]) {
		return false;
	}
	if (p_order == ORDER_WITHDRAW && fs.order[p_f] != ORDER_WITHDRAW && fs.engaged[p_f] > 0) {
		// Turning away from men still swinging at you (DOCS-design-command §3).
		fs.stress[p_f] = std::min(MAX_STRESS, fs.stress[p_f] + fs.params.withdraw_shock);
		fs.cohesion[p_f] = std::clamp(cohesion_of(fs, p_f), 0.0f, 1.0f);
	}
	if (p_order == ORDER_HOLD) { // stand where the order found each man
		for (int32_t i = 0; i < s.count; i++) {
			if (s.formation[i] == p_f) {
				s.anchor_x[i] = s.px[i];
				s.anchor_z[i] = s.pz[i];
			}
		}
	}
	fs.order[p_f] = p_order;
	return true;
}

} // namespace legatus
