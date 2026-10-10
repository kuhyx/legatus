// Phase A of the tick: nearest-enemy search, steering, separation (friends and
// enemies both push), melee blows. Reads previous-tick buffers only.
#include <algorithm>
#include <cmath>

#include "sim_state.h"

namespace legatus {

namespace {

constexpr float TAU = 6.28318530718f;

struct Contact {
	float push_x = 0.0f;
	float push_z = 0.0f;
};

// Overlap correction from every living soldier in the 3x3 cells around i.
Contact separate(const SimState &s, int32_t i, float x, float z) {
	const SimGrid &g = s.grid;
	const float min_d = 2.0f * s.params.body_radius;
	const float min_d2 = min_d * min_d;
	const int32_t cx = g.cell_x(x);
	const int32_t cz = g.cell_z(z);
	const int32_t *ids = g.items();
	const float *ix = g.item_x();
	const float *iz = g.item_z();
	Contact c;
	for (int32_t gz = std::max(0, cz - 1); gz <= std::min(g.height() - 1, cz + 1); gz++) {
		for (int32_t gx = std::max(0, cx - 1); gx <= std::min(g.width() - 1, cx + 1); gx++) {
			int32_t b = 0;
			int32_t e = 0;
			g.range(gx, gz, -1, b, e);
			for (int32_t k = b; k < e; k++) {
				const float dx = x - ix[k];
				const float dz = z - iz[k];
				const float d2 = dx * dx + dz * dz;
				if (d2 >= min_d2 || ids[k] == i) {
					continue;
				}
				if (d2 < 1e-8f) { // coincident: split deterministically by index
					c.push_x += (ids[k] < i ? 0.5f : -0.5f) * min_d;
					continue;
				}
				const float d = std::sqrt(d2);
				const float overlap = 0.5f * (min_d - d) / d;
				c.push_x += dx * overlap;
				c.push_z += dz * overlap;
			}
		}
	}
	return c;
}

void attack(SimState &s, int32_t i, int32_t t) {
	const SimParams &p = s.params;
	const float f = s.fatigue[i];
	s.cooldown[i] = p.attack_interval * (1.0f + f) * (0.8f + 0.4f * sim_rand(s.seed, s.tick, i, 1));
	s.fatigue[i] = std::min(1.0f, f + 0.03f);
	if (sim_rand(s.seed, s.tick, i, 2) >= p.hit_chance * (1.0f - 0.4f * f)) {
		return;
	}
	const float roll = sim_rand(s.seed, s.tick, i, 3);
	const float dmg = (float(p.dmg_min) + float(p.dmg_max - p.dmg_min) * roll) * (1.0f - 0.4f * f);
	// Integer add is commutative: the sum is identical whatever the thread order.
	__atomic_fetch_add(&s.dmg_in[t], int32_t(dmg), __ATOMIC_RELAXED);
}

} // namespace

int32_t sim_find_enemy(const SimState &s, int32_t p_index) {
	const SimGrid &g = s.grid;
	const float x = s.ox[p_index];
	const float z = s.oz[p_index];
	const int enemy = 1 - s.side[p_index];
	const int32_t cx = g.cell_x(x);
	const int32_t cz = g.cell_z(z);
	const int32_t *ids = g.items();
	const float *ix = g.item_x();
	const float *iz = g.item_z();
	int32_t best = -1;
	float best_d2 = 1e30f;
	for (int32_t r = 0; r <= s.params.search_cells; r++) {
		for (int32_t dz = -r; dz <= r; dz++) {
			const int32_t gz = cz + dz;
			if (gz < 0 || gz >= g.height()) {
				continue;
			}
			const bool edge_row = (dz == -r || dz == r);
			const int32_t step = edge_row ? 1 : std::max(1, 2 * r);
			for (int32_t dx = -r; dx <= r; dx += step) {
				const int32_t gx = cx + dx;
				if (gx < 0 || gx >= g.width()) {
					continue;
				}
				int32_t b = 0;
				int32_t e = 0;
				g.range(gx, gz, enemy, b, e);
				for (int32_t k = b; k < e; k++) {
					const float d2 = (x - ix[k]) * (x - ix[k]) + (z - iz[k]) * (z - iz[k]);
					if (d2 < best_d2 || (d2 == best_d2 && ids[k] < best)) {
						best_d2 = d2;
						best = ids[k];
					}
				}
			}
		}
		// Every cell of ring r+1 is at least r*cell away from x,z.
		const float reach_r = float(r) * g.cell_size();
		if (best >= 0 && best_d2 <= reach_r * reach_r) {
			break;
		}
	}
	return best;
}

void sim_kernel_move(SimState &s, int32_t p_begin, int32_t p_end) {
	const SimParams &p = s.params;
	const SimGrid &g = s.grid;
	for (int32_t i = p_begin; i < p_end; i++) {
		const float x = s.ox[i];
		const float z = s.oz[i];
		if (!s.alive[i]) {
			s.px[i] = x;
			s.pz[i] = z;
			s.vx[i] = 0.0f;
			s.vz[i] = 0.0f;
			s.facing[i] = s.ofacing[i];
			continue;
		}
		const float adv = s.side[i] == 0 ? 1.0f : -1.0f;
		const float vigour = 1.0f - 0.5f * s.fatigue[i];
		int32_t t = s.target[i];
		if (t < 0 || !s.alive[t] || (s.tick + uint32_t(i)) % uint32_t(p.retarget_period) == 0) {
			t = sim_find_enemy(s, i);
		}
		s.target[i] = t;
		float dvx = 0.0f;
		float dvz = adv * p.walk_speed * vigour;
		float tdx = 0.0f;
		float tdz = 0.0f;
		float dist = 1e9f;
		if (s.morale[i] < p.rout_morale) {
			s.state[i] = ST_ROUT;
		}
		if (t >= 0) {
			tdx = s.ox[t] - x;
			tdz = s.oz[t] - z;
			dist = std::sqrt(tdx * tdx + tdz * tdz);
		}
		if (s.state[i] == ST_ROUT) {
			dvz = -adv * p.rout_speed * vigour;
		} else if (t >= 0) {
			const float hold = 0.8f * p.reach;
			const float speed = (dist < p.charge_dist ? p.charge_speed : p.walk_speed) * vigour;
			const float k = dist > hold ? speed / std::max(dist, 1e-3f) : 0.0f;
			dvx = tdx * k;
			dvz = tdz * k;
			s.state[i] = dist <= p.reach ? ST_FIGHT : ST_ADVANCE;
		} else {
			dvx = std::clamp((s.home_x[i] - x) * 0.2f, -0.5f, 0.5f); // keep the file
			s.state[i] = ST_ADVANCE;
		}
		const float nvx = s.ovx[i] + (dvx - s.ovx[i]) * p.accel;
		const float nvz = s.ovz[i] + (dvz - s.ovz[i]) * p.accel;
		Contact c = separate(s, i, x, z);
		const float push = std::sqrt(c.push_x * c.push_x + c.push_z * c.push_z);
		if (push > p.max_push) {
			c.push_x *= p.max_push / push;
			c.push_z *= p.max_push / push;
		}
		s.vx[i] = nvx;
		s.vz[i] = nvz;
		s.px[i] = std::clamp(x + nvx * s.dt + c.push_x, g.min_x() + 0.01f, g.max_x() - 0.01f);
		s.pz[i] = std::clamp(z + nvz * s.dt + c.push_z, g.min_z() + 0.01f, g.max_z() - 0.01f);
		const float sp2 = nvx * nvx + nvz * nvz;
		const bool facing_foe = t >= 0 && dist < p.charge_dist && s.state[i] != ST_ROUT;
		s.facing[i] = facing_foe ? std::atan2(tdx, tdz)
								 : (sp2 > 0.01f ? std::atan2(nvx, nvz) : s.ofacing[i]);
		const bool fighting = s.state[i] == ST_FIGHT;
		s.cooldown[i] = std::max(0.0f, s.cooldown[i] - s.dt);
		if (fighting && s.cooldown[i] <= 0.0f) {
			attack(s, i, t);
		}
		const float tire = fighting ? 0.0015f : (sp2 > 4.0f ? 0.001f : -0.0005f);
		s.fatigue[i] = std::clamp(s.fatigue[i] + tire, 0.0f, 1.0f);
		const float mood = fighting ? -0.0008f * (1.0f + s.fatigue[i]) : 0.0005f;
		s.morale[i] = std::min(1.0f, s.morale[i] + mood);
		const float anim = std::sqrt(sp2) * 3.5f + (fighting ? 4.0f : 0.0f);
		s.phase[i] = std::fmod(s.phase[i] + anim * s.dt, 2.0f * TAU);
	}
}

} // namespace legatus
