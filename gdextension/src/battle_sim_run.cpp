// BattleSim: the fixed tick and the per-frame MultiMesh fills, both chunked
// over Godot's WorkerThreadPool. Worker chunks run pure C++ only.
#include "battle_sim.h"

#include <godot_cpp/classes/worker_thread_pool.hpp>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <functional>
#include <thread>

namespace godot {

namespace {
constexpr int32_t SERIAL_BELOW = 512; // tiny test battles skip the pool
constexpr float PI_F = 3.14159265359f;

float lerp_angle(float p_from, float p_to, float p_alpha) {
	float d = std::fmod(p_to - p_from, 2.0f * PI_F);
	d = std::fmod(2.0f * d, 2.0f * PI_F) - d; // shortest signed difference
	return p_from + d * p_alpha;
}
} // namespace

void BattleSim::chunk_thunk(void *p_self, uint32_t p_chunk) {
	static_cast<BattleSim *>(p_self)->run_chunk(p_chunk);
}

void BattleSim::run_parallel(Phase p_phase, int32_t p_items) {
	phase = p_phase;
	const int32_t n = p_items < SERIAL_BELOW ? 1 : chunks;
	chunk_thread.assign(size_t(n), 0);
	chunk_deaths.assign(size_t(n) * 2, 0);
	chunk_near.resize(size_t(n));
	chunk_far.resize(size_t(n));
	if (n == 1) {
		run_chunk(0);
		return;
	}
	WorkerThreadPool *pool = WorkerThreadPool::get_singleton();
	const int64_t id = pool->add_native_group_task(&BattleSim::chunk_thunk, this, n, -1, true,
			"legatus_sim");
	pool->wait_for_group_task_completion(id);
}

void BattleSim::run_chunk(uint32_t p_chunk) {
	const int32_t n = int32_t(chunk_thread.size());
	const bool per_side = phase == PH_RENDER || phase == PH_LOD_COUNT || phase == PH_LOD;
	const int32_t lo = per_side ? state.side_begin[job_side] : 0;
	const int32_t hi = per_side ? state.side_begin[job_side + 1] : state.count;
	const int32_t b = lo + int32_t(int64_t(hi - lo) * p_chunk / n);
	const int32_t e = lo + int32_t(int64_t(hi - lo) * (p_chunk + 1) / n);
	chunk_thread[p_chunk] = std::hash<std::thread::id>()(std::this_thread::get_id());
	if (phase == PH_MOVE) {
		legatus::sim_kernel_move(state, b, e);
	} else if (phase == PH_DAMAGE) {
		legatus::sim_kernel_damage(state, b, e, &chunk_deaths[size_t(p_chunk) * 2]);
	} else if (phase == PH_RENDER) {
		for (int32_t i = b; i < e; i++) {
			write_instance(i, job_out[0] + size_t(i - lo) * STRIDE);
		}
	} else if (phase == PH_LOD_COUNT) {
		int32_t near = 0;
		for (int32_t i = b; i < e; i++) {
			const float a = job_alpha;
			const float dx = state.ox[i] + (state.px[i] - state.ox[i]) * a - job_camera.x;
			const float dz = state.oz[i] + (state.pz[i] - state.oz[i]) * a - job_camera.z;
			const uint8_t is_near = dx * dx + dz * dz < job_near2 ? 1 : 0;
			lod_near[size_t(i - lo)] = is_near;
			near += is_near;
		}
		chunk_near[p_chunk] = near;
	} else {
		int32_t near_at = chunk_near[p_chunk];
		int32_t far_at = chunk_far[p_chunk];
		for (int32_t i = b; i < e; i++) {
			const bool is_near = lod_near[size_t(i - lo)] != 0;
			const int32_t slot = is_near ? near_at++ : far_at++;
			write_instance(i, job_out[is_near ? 0 : 1] + size_t(slot) * STRIDE);
		}
	}
}

void BattleSim::tick(float p_dt) {
	const auto t0 = std::chrono::steady_clock::now();
	legatus::SimState &s = state;
	s.dt = p_dt;
	s.swap_buffers(); // o* now hold the last tick; the kernels rewrite every current slot
	s.grid.build(s.ox.data(), s.oz.data(), s.side.data(), s.alive.data(), s.count);
	std::vector<size_t> threads;
	run_parallel(PH_MOVE, s.count);
	threads = chunk_thread;
	run_parallel(PH_DAMAGE, s.count);
	threads.insert(threads.end(), chunk_thread.begin(), chunk_thread.end());
	for (size_t c = 0; c < chunk_thread.size(); c++) {
		alive_count[0] -= chunk_deaths[c * 2];
		alive_count[1] -= chunk_deaths[c * 2 + 1];
	}
	s.tick++;
	std::sort(threads.begin(), threads.end());
	last_tick_threads = int32_t(std::unique(threads.begin(), threads.end()) - threads.begin());
	const auto t1 = std::chrono::steady_clock::now();
	last_tick_usec = std::chrono::duration_cast<std::chrono::microseconds>(t1 - t0).count();
}

void BattleSim::write_instance(int32_t p_index, float *r_out) const {
	const legatus::SimState &s = state;
	const float a = job_alpha;
	const float x = s.ox[p_index] + (s.px[p_index] - s.ox[p_index]) * a;
	const float z = s.oz[p_index] + (s.pz[p_index] - s.oz[p_index]) * a;
	const float f = lerp_angle(s.ofacing[p_index], s.facing[p_index], a);
	const float c = std::cos(f);
	const float sn = std::sin(f);
	// Row-major 3x4: basis rows with origin x/y/z in slots 3/7/11.
	if (s.alive[p_index]) { // upright, yawed: local +Z faces the enemy
		const float m[12] = { c, 0.0f, sn, x, 0.0f, 1.0f, 0.0f, 0.0f, -sn, 0.0f, c, z };
		std::copy(m, m + 12, r_out);
	} else { // fallen on his back: yaw * (-90 deg about X), lifted off the ground
		const float m[12] = { c, -sn, 0.0f, x, 0.0f, 0.0f, 1.0f, 0.22f, -sn, -c, 0.0f, z };
		std::copy(m, m + 12, r_out);
	}
	r_out[12] = s.phase[p_index];
	r_out[13] = float(s.state[p_index]);
	r_out[14] = s.fatigue[p_index];
	r_out[15] = float(s.side[p_index]);
}

PackedFloat32Array BattleSim::fill_transforms(int32_t p_side, float p_alpha) {
	ERR_FAIL_INDEX_V(p_side, 2, PackedFloat32Array());
	const int32_t n = get_side_count(p_side);
	PackedFloat32Array &buf = buffers[p_side];
	buf.resize(int64_t(n) * STRIDE);
	job_side = p_side;
	job_alpha = std::clamp(p_alpha, 0.0f, 1.0f);
	job_out[0] = buf.ptrw();
	run_parallel(PH_RENDER, n);
	return buf;
}

int32_t BattleSim::fill_lod(int32_t p_side, float p_alpha, const Vector3 &p_camera, float p_near) {
	ERR_FAIL_INDEX_V(p_side, 2, 0);
	const int32_t n = get_side_count(p_side);
	job_side = p_side;
	job_alpha = std::clamp(p_alpha, 0.0f, 1.0f);
	job_camera = p_camera;
	job_near2 = p_near * p_near;
	lod_near.resize(size_t(n));
	run_parallel(PH_LOD_COUNT, n);
	int32_t near_total = 0;
	int32_t far_total = 0;
	for (size_t c = 0; c < chunk_near.size(); c++) { // serial prefix sums over chunks
		const int32_t lo = int32_t(int64_t(n) * int64_t(c) / int64_t(chunk_near.size()));
		const int32_t hi = int32_t(int64_t(n) * int64_t(c + 1) / int64_t(chunk_near.size()));
		const int32_t near = chunk_near[c];
		chunk_near[c] = near_total;
		chunk_far[c] = far_total;
		near_total += near;
		far_total += (hi - lo) - near;
	}
	// Both buffers stay full size: MultiMesh needs instance_count * stride,
	// only visible_instance_count changes from frame to frame.
	for (int lod = 0; lod < 2; lod++) {
		lod_buffers[p_side][lod].resize(int64_t(n) * STRIDE);
		job_out[lod] = lod_buffers[p_side][lod].ptrw();
	}
	lod_counts[p_side][0] = near_total;
	lod_counts[p_side][1] = far_total;
	// run_parallel would reset chunk_near/far: dispatch with the same chunk count.
	phase = PH_LOD;
	if (chunk_thread.size() == 1) {
		run_chunk(0);
	} else {
		WorkerThreadPool *pool = WorkerThreadPool::get_singleton();
		const int64_t id = pool->add_native_group_task(&BattleSim::chunk_thunk, this,
				int32_t(chunk_thread.size()), -1, true, "legatus_lod");
		pool->wait_for_group_task_completion(id);
	}
	return near_total;
}

PackedFloat32Array BattleSim::get_lod_buffer(int32_t p_side, int32_t p_far) const {
	ERR_FAIL_INDEX_V(p_side, 2, PackedFloat32Array());
	return lod_buffers[p_side][p_far ? 1 : 0];
}

int32_t BattleSim::get_lod_count(int32_t p_side, int32_t p_far) const {
	ERR_FAIL_INDEX_V(p_side, 2, 0);
	return lod_counts[p_side][p_far ? 1 : 0];
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
