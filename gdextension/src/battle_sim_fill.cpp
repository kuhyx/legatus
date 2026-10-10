// BattleSim: the per-frame MultiMesh fills. Two chunked passes per side:
// classify every soldier (near / far / hidden behind the general's sight
// tiles), prefix-sum the per-chunk counts, then write each drawn soldier into
// its compacted slot, standing on the height field.
#include "battle_sim.h"

#include <godot_cpp/classes/worker_thread_pool.hpp>

#include <algorithm>
#include <cfloat>
#include <cmath>

namespace godot {

namespace {
constexpr float PI_F = 3.14159265359f;
constexpr float FALLEN_LIFT = 0.22f; // a body on its back, off the ground

float lerp_angle(float p_from, float p_to, float p_alpha) {
	float d = std::fmod(p_to - p_from, 2.0f * PI_F);
	d = std::fmod(2.0f * d, 2.0f * PI_F) - d; // shortest signed difference
	return p_from + d * p_alpha;
}
} // namespace

void BattleSim::classify_chunk(uint32_t p_chunk, int32_t p_begin, int32_t p_end) {
	const legatus::SimState &s = state;
	const int32_t lo = s.side_begin[job_side];
	const float a = job_alpha;
	int32_t near = 0;
	int32_t far = 0;
	int32_t seen = 0;
	for (int32_t i = p_begin; i < p_end; i++) {
		const float x = s.ox[i] + (s.px[i] - s.ox[i]) * a;
		const float z = s.oz[i] + (s.pz[i] - s.oz[i]) * a;
		uint8_t cls = DRAW_HIDDEN;
		if (tiles.is_visible(x, z)) {
			const float dx = x - job_camera.x;
			const float dz = z - job_camera.z;
			cls = dx * dx + dz * dz < job_near2 ? DRAW_NEAR : DRAW_FAR;
			near += cls == DRAW_NEAR ? 1 : 0;
			far += cls == DRAW_FAR ? 1 : 0;
			seen += s.alive[i] ? 1 : 0;
		}
		lod_class[size_t(i - lo)] = cls;
	}
	chunk_near[p_chunk] = near;
	chunk_far[p_chunk] = far;
	chunk_seen[p_chunk] = seen;
}

void BattleSim::write_chunk(uint32_t p_chunk, int32_t p_begin, int32_t p_end) {
	const int32_t lo = state.side_begin[job_side];
	int32_t near_at = chunk_near[p_chunk];
	int32_t far_at = chunk_far[p_chunk];
	for (int32_t i = p_begin; i < p_end; i++) {
		const uint8_t cls = lod_class[size_t(i - lo)];
		if (cls == DRAW_HIDDEN) {
			continue;
		}
		const int32_t slot = cls == DRAW_NEAR ? near_at++ : far_at++;
		write_instance(i, job_out[cls] + size_t(slot) * STRIDE);
	}
}

void BattleSim::write_instance(int32_t p_index, float *r_out) const {
	const legatus::SimState &s = state;
	const float a = job_alpha;
	const float x = s.ox[p_index] + (s.px[p_index] - s.ox[p_index]) * a;
	const float z = s.oz[p_index] + (s.pz[p_index] - s.oz[p_index]) * a;
	const float y = ground.height_at(x, z);
	const float f = lerp_angle(s.ofacing[p_index], s.facing[p_index], a);
	const float c = std::cos(f);
	const float sn = std::sin(f);
	// Row-major 3x4: basis rows with origin x/y/z in slots 3/7/11.
	if (s.alive[p_index]) { // upright, yawed: local +Z faces the enemy
		const float m[12] = { c, 0.0f, sn, x, 0.0f, 1.0f, 0.0f, y, -sn, 0.0f, c, z };
		std::copy(m, m + 12, r_out);
	} else { // fallen on his back: yaw * (-90 deg about X), lifted off the ground
		const float m[12] = { c, -sn, 0.0f, x, 0.0f, 0.0f, 1.0f, y + FALLEN_LIFT, -sn, -c, 0.0f, z };
		std::copy(m, m + 12, r_out);
	}
	r_out[12] = s.phase[p_index];
	r_out[13] = float(s.state[p_index]);
	r_out[14] = s.fatigue[p_index];
	r_out[15] = float(s.side[p_index]);
}

int32_t BattleSim::fill_side(int32_t p_side, float p_alpha, float p_near2) {
	const int32_t n = get_side_count(p_side);
	job_side = p_side;
	job_alpha = std::clamp(p_alpha, 0.0f, 1.0f);
	job_near2 = p_near2;
	lod_class.resize(size_t(n));
	run_parallel(PH_CLASSIFY, n);
	int32_t near_total = 0;
	int32_t far_total = 0;
	int32_t seen_total = 0;
	for (size_t c = 0; c < chunk_near.size(); c++) { // serial prefix sums over chunks
		const int32_t near = chunk_near[c];
		const int32_t far = chunk_far[c];
		chunk_near[c] = near_total;
		chunk_far[c] = far_total;
		near_total += near;
		far_total += far;
		seen_total += chunk_seen[c];
	}
	drawn_counts[p_side] = near_total + far_total;
	seen_alive[p_side] = seen_total;
	// run_parallel would reset the offsets: dispatch with the same chunk count.
	phase = PH_WRITE;
	if (chunk_thread.size() == 1) {
		run_chunk(0);
	} else {
		WorkerThreadPool *pool = WorkerThreadPool::get_singleton();
		const int64_t id = pool->add_native_group_task(&BattleSim::chunk_thunk, this,
				int32_t(chunk_thread.size()), -1, true, "legatus_fill");
		pool->wait_for_group_task_completion(id);
	}
	return near_total;
}

PackedFloat32Array BattleSim::fill_transforms(int32_t p_side, float p_alpha) {
	ERR_FAIL_INDEX_V(p_side, 2, PackedFloat32Array());
	// Full size: MultiMesh needs instance_count * stride; the drawn soldiers
	// are packed at the front and get_drawn_count() is the visible count.
	PackedFloat32Array &buf = buffers[p_side];
	buf.resize(int64_t(get_side_count(p_side)) * STRIDE);
	job_out[0] = buf.ptrw();
	job_out[1] = nullptr; // no far class: every visible soldier is "near"
	fill_side(p_side, p_alpha, FLT_MAX);
	return buf;
}

int32_t BattleSim::fill_lod(int32_t p_side, float p_alpha, const Vector3 &p_camera, float p_near) {
	ERR_FAIL_INDEX_V(p_side, 2, 0);
	const int32_t n = get_side_count(p_side);
	for (int lod = 0; lod < 2; lod++) {
		lod_buffers[p_side][lod].resize(int64_t(n) * STRIDE);
		job_out[lod] = lod_buffers[p_side][lod].ptrw();
	}
	job_camera = p_camera;
	const int32_t near = fill_side(p_side, p_alpha, p_near * p_near);
	lod_counts[p_side][0] = near;
	lod_counts[p_side][1] = drawn_counts[p_side] - near;
	return near;
}

PackedFloat32Array BattleSim::get_lod_buffer(int32_t p_side, int32_t p_far) const {
	ERR_FAIL_INDEX_V(p_side, 2, PackedFloat32Array());
	return lod_buffers[p_side][p_far ? 1 : 0];
}

int32_t BattleSim::get_lod_count(int32_t p_side, int32_t p_far) const {
	ERR_FAIL_INDEX_V(p_side, 2, 0);
	return lod_counts[p_side][p_far ? 1 : 0];
}

int32_t BattleSim::get_drawn_count(int32_t p_side) const {
	ERR_FAIL_INDEX_V(p_side, 2, 0);
	return drawn_counts[p_side];
}

int32_t BattleSim::get_visible_alive(int32_t p_side) const {
	ERR_FAIL_INDEX_V(p_side, 2, 0);
	return seen_alive[p_side];
}

PackedVector2Array BattleSim::get_positions(float p_alpha) const {
	PackedVector2Array out;
	out.resize(state.count);
	Vector2 *w = out.ptrw();
	for (int32_t i = 0; i < state.count; i++) {
		w[i] = Vector2(state.ox[i] + (state.px[i] - state.ox[i]) * p_alpha,
				state.oz[i] + (state.pz[i] - state.oz[i]) * p_alpha);
	}
	return out;
}

} // namespace godot
