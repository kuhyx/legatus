// BattleSim: the Godot-facing handle on the CPU battle simulation. One fixed
// tick (20 Hz in the game) advances every soldier; rendering interpolates
// between the previous and current tick with `alpha` in [0, 1].
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <vector>

#include "sim_state.h"

namespace godot {

class BattleSim : public RefCounted {
	GDCLASS(BattleSim, RefCounted)

public:
	// Floats per MultiMesh instance: 12 (3x4 transform) + 4 (custom data).
	static constexpr int STRIDE = 16;

	// Two blocks of n_per_side, `frontage` metres wide, front ranks `gap` apart.
	void setup_lines(int32_t p_per_side, float p_frontage, float p_gap, int64_t p_seed);
	// Arbitrary soldiers for tests: one position and side (0/1) each.
	void setup_custom(const PackedVector2Array &p_pos, const PackedByteArray &p_sides,
			int64_t p_seed);
	void tick(float p_dt);

	PackedFloat32Array fill_transforms(int32_t p_side, float p_alpha);
	// Near/far split around the camera: writes both side buffers, returns near count.
	int32_t fill_lod(int32_t p_side, float p_alpha, const Vector3 &p_camera, float p_near);
	PackedFloat32Array get_lod_buffer(int32_t p_side, int32_t p_far) const;
	int32_t get_lod_count(int32_t p_side, int32_t p_far) const;
	PackedVector2Array get_positions(float p_alpha) const;

	void rebuild_grid();
	PackedInt32Array query_neighbors(int32_t p_index, float p_radius) const;
	int32_t find_enemy(int32_t p_index) const;

	int32_t get_count() const { return state.count; }
	int32_t get_side_count(int32_t p_side) const;
	int32_t get_alive(int32_t p_side) const;
	int32_t get_hp(int32_t p_index) const;
	int32_t get_max_hp() const { return state.params.max_hp; }
	int32_t get_tick_count() const { return int32_t(state.tick); }
	int64_t get_last_tick_usec() const { return last_tick_usec; }
	int32_t get_last_tick_threads() const { return last_tick_threads; }
	void set_chunk_count(int32_t p_chunks);
	// Nearest-enemy ring radius in 2 m cells (default 24 = 48 m).
	void set_search_cells(int32_t p_cells);
	int32_t get_search_cells() const { return state.params.search_cells; }
	int32_t get_chunk_count() const { return chunks; }

protected:
	static void _bind_methods();

private:
	enum Phase { PH_MOVE, PH_DAMAGE, PH_RENDER, PH_LOD_COUNT, PH_LOD };

	legatus::SimState state;
	int32_t chunks = 128;
	int64_t last_tick_usec = 0;
	int32_t last_tick_threads = 0;
	int32_t alive_count[2] = { 0, 0 };
	Phase phase = PH_MOVE;
	std::vector<size_t> chunk_thread;
	std::vector<int32_t> chunk_deaths;
	std::vector<int32_t> chunk_near; // LOD: near count per chunk, then near offset
	std::vector<int32_t> chunk_far; // LOD: far offset per chunk
	std::vector<uint8_t> lod_near; // LOD: per soldier of the job side, 1 = near
	PackedFloat32Array buffers[2];
	PackedFloat32Array lod_buffers[2][2];
	int32_t lod_counts[2][2] = { { 0, 0 }, { 0, 0 } };
	// Render job parameters, read by the worker chunks.
	int32_t job_side = 0;
	float job_alpha = 1.0f;
	Vector3 job_camera;
	float job_near2 = 0.0f;
	float *job_out[2] = { nullptr, nullptr };

	void finish_setup(float p_min_x, float p_min_z, float p_max_x, float p_max_z);
	void run_parallel(Phase p_phase, int32_t p_items);
	void run_chunk(uint32_t p_chunk);
	void write_instance(int32_t p_index, float *r_out) const;
	static void chunk_thunk(void *p_self, uint32_t p_chunk);
};

} // namespace godot
