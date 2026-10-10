#include "sim_state.h"

#include <utility>

namespace legatus {

void SimState::resize(int32_t p_count) {
	count = p_count;
	const size_t n = size_t(p_count);
	for (std::vector<float> *v : { &px, &pz, &ox, &oz, &vx, &vz, &ovx, &ovz, &facing, &ofacing,
				 &fatigue, &morale, &cooldown, &phase, &home_x }) {
		v->assign(n, 0.0f);
	}
	for (std::vector<int32_t> *v : { &hp, &dmg_in, &target, &formation }) {
		v->assign(n, 0);
	}
	for (std::vector<uint8_t> *v : { &side, &state, &alive }) {
		v->assign(n, 0);
	}
}

void SimState::swap_buffers() {
	std::swap(px, ox);
	std::swap(pz, oz);
	std::swap(vx, ovx);
	std::swap(vz, ovz);
	std::swap(facing, ofacing);
}

float sim_rand(uint64_t p_seed, uint32_t p_tick, int32_t p_index, uint32_t p_salt) {
	// splitmix64 finaliser over a mixed key: cheap, stateless, well distributed.
	uint64_t z = p_seed ^ (uint64_t(p_tick) * 0x9E3779B97F4A7C15ull) ^
			(uint64_t(uint32_t(p_index)) * 0xC2B2AE3D27D4EB4Full) ^
			(uint64_t(p_salt) * 0x165667B19E3779F9ull);
	z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ull;
	z = (z ^ (z >> 27)) * 0x94D049BB133111EBull;
	z ^= z >> 31;
	return float(z >> 40) * (1.0f / 16777216.0f);
}

void sim_kernel_damage(SimState &s, int32_t p_begin, int32_t p_end, int32_t r_deaths[2]) {
	r_deaths[0] = 0;
	r_deaths[1] = 0;
	for (int32_t i = p_begin; i < p_end; i++) {
		const int32_t d = s.dmg_in[i];
		if (d == 0) {
			continue;
		}
		s.dmg_in[i] = 0;
		if (!s.alive[i]) {
			continue;
		}
		s.hp[i] -= d;
		s.morale[i] -= 0.08f; // each wound shakes the man
		if (s.hp[i] <= 0) {
			s.hp[i] = 0;
			s.alive[i] = 0;
			s.state[i] = ST_DEAD;
			r_deaths[s.side[i]]++;
		}
	}
}

} // namespace legatus
