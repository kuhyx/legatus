// BattleSim: the fixed tick and the chunk dispatcher shared with the
// per-frame fills (battle_sim_fill.cpp), chunked over Godot's
// WorkerThreadPool. Worker chunks run pure C++ only.
#include "battle_sim.h"

#include <godot_cpp/classes/worker_thread_pool.hpp>

#include <algorithm>
#include <chrono>
#include <functional>
#include <thread>

namespace godot {

namespace {
constexpr int32_t SERIAL_BELOW = 512; // tiny test battles skip the pool
} // namespace

void BattleSim::chunk_thunk(void *p_self, uint32_t p_chunk) {
	static_cast<BattleSim *>(p_self)->run_chunk(p_chunk);
}

void BattleSim::run_parallel(Phase p_phase, int32_t p_items) {
	phase = p_phase;
	const int32_t n = p_items < SERIAL_BELOW ? 1 : chunks;
	chunk_thread.assign(size_t(n), 0);
	chunk_deaths.assign(size_t(n) * 2, 0);
	chunk_near.assign(size_t(n), 0);
	chunk_far.assign(size_t(n), 0);
	chunk_seen.assign(size_t(n), 0);
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
	const bool per_side = phase == PH_CLASSIFY || phase == PH_WRITE;
	const int32_t lo = per_side ? state.side_begin[job_side] : 0;
	const int32_t hi = per_side ? state.side_begin[job_side + 1] : state.count;
	const int32_t b = lo + int32_t(int64_t(hi - lo) * p_chunk / n);
	const int32_t e = lo + int32_t(int64_t(hi - lo) * (p_chunk + 1) / n);
	chunk_thread[p_chunk] = std::hash<std::thread::id>()(std::this_thread::get_id());
	if (phase == PH_MOVE) {
		legatus::sim_kernel_move(state, b, e);
	} else if (phase == PH_DAMAGE) {
		legatus::sim_kernel_damage(state, b, e, &chunk_deaths[size_t(p_chunk) * 2]);
	} else if (phase == PH_CLASSIFY) {
		classify_chunk(p_chunk, b, e);
	} else {
		write_chunk(p_chunk, b, e);
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

} // namespace godot
