#include "sim_grid.h"

#include <algorithm>
#include <cmath>

namespace legatus {

void SimGrid::configure(float p_min_x, float p_min_z, float p_max_x, float p_max_z, float p_cell) {
	cell = p_cell;
	origin_x = p_min_x;
	origin_z = p_min_z;
	w = std::max(1, int32_t(std::ceil((p_max_x - p_min_x) / p_cell)));
	h = std::max(1, int32_t(std::ceil((p_max_z - p_min_z) / p_cell)));
	start.assign(size_t(w) * size_t(h) * 2 + 1, 0);
}

int32_t SimGrid::cell_x(float p_x) const {
	const int32_t c = int32_t(std::floor((p_x - origin_x) / cell));
	return std::clamp(c, 0, w - 1);
}

int32_t SimGrid::cell_z(float p_z) const {
	const int32_t c = int32_t(std::floor((p_z - origin_z) / cell));
	return std::clamp(c, 0, h - 1);
}

void SimGrid::build(const float *p_x, const float *p_z, const uint8_t *p_side,
		const uint8_t *p_alive, int32_t p_count) {
	keys.resize(size_t(p_count));
	std::fill(start.begin(), start.end(), 0);
	int32_t inserted = 0;
	for (int32_t i = 0; i < p_count; i++) {
		if (!p_alive[i]) {
			keys[i] = -1;
			continue;
		}
		const int32_t k = (cell_z(p_z[i]) * w + cell_x(p_x[i])) * 2 + p_side[i];
		keys[i] = k;
		start[size_t(k) + 1]++;
		inserted++;
	}
	for (size_t k = 1; k < start.size(); k++) {
		start[k] += start[k - 1];
	}
	sorted_id.resize(size_t(inserted));
	sorted_x.resize(size_t(inserted));
	sorted_z.resize(size_t(inserted));
	// Scatter using a running cursor per key; `start` is restored afterwards.
	for (int32_t i = 0; i < p_count; i++) {
		const int32_t k = keys[i];
		if (k < 0) {
			continue;
		}
		const int32_t slot = start[k]++;
		sorted_id[slot] = i;
		sorted_x[slot] = p_x[i];
		sorted_z[slot] = p_z[i];
	}
	for (size_t k = start.size() - 1; k > 0; k--) {
		start[k] = start[k - 1];
	}
	start[0] = 0;
}

void SimGrid::range(int32_t p_cx, int32_t p_cz, int p_side, int32_t &r_begin,
		int32_t &r_end) const {
	const int32_t base = (p_cz * w + p_cx) * 2;
	if (p_side < 0) {
		r_begin = start[base];
		r_end = start[base + 2];
	} else {
		r_begin = start[base + p_side];
		r_end = start[base + p_side + 1];
	}
}

} // namespace legatus
