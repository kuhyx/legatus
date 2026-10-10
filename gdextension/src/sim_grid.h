// Uniform spatial grid over the battlefield, rebuilt every tick by a serial
// counting sort. Key = cell * 2 + side, so one cell's soldiers of BOTH sides
// form one contiguous run (separation queries) and each side's soldiers in a
// cell are a sub-run of it (enemy search touches only the enemy half).
// Serial on purpose: ~0.5 ms for 100k and it keeps cell order deterministic.
#pragma once

#include <cstdint>
#include <vector>

namespace legatus {

class SimGrid {
public:
	void configure(float p_min_x, float p_min_z, float p_max_x, float p_max_z, float p_cell);

	// Inserts every soldier whose `alive` flag is non-zero; dead are skipped.
	void build(const float *p_x, const float *p_z, const uint8_t *p_side, const uint8_t *p_alive,
			int32_t p_count);

	int32_t cell_x(float p_x) const;
	int32_t cell_z(float p_z) const;
	int32_t width() const { return w; }
	int32_t height() const { return h; }
	float cell_size() const { return cell; }
	float min_x() const { return origin_x; }
	float min_z() const { return origin_z; }
	float max_x() const { return origin_x + cell * float(w); }
	float max_z() const { return origin_z + cell * float(h); }

	// Range [begin, end) into items() for cell (cx, cz); side -1 = both sides.
	void range(int32_t p_cx, int32_t p_cz, int p_side, int32_t &r_begin, int32_t &r_end) const;

	const int32_t *items() const { return sorted_id.data(); }
	const float *item_x() const { return sorted_x.data(); }
	const float *item_z() const { return sorted_z.data(); }

private:
	float origin_x = 0.0f;
	float origin_z = 0.0f;
	float cell = 2.0f;
	int32_t w = 1;
	int32_t h = 1;
	std::vector<int32_t> start; // w*h*2 + 1 prefix offsets
	std::vector<int32_t> keys; // per soldier, -1 when not inserted
	std::vector<int32_t> sorted_id;
	std::vector<float> sorted_x; // positions copied in cell order: cache-friendly scans
	std::vector<float> sorted_z;
};

} // namespace legatus
