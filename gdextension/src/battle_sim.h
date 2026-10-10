// BattleSim: the Godot-facing handle on the CPU battle simulation. One fixed
// tick (20 Hz in the game) advances every soldier; rendering interpolates
// between the previous and current tick with `alpha` in [0, 1].
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <vector>

#include "sim_state.h"
#include "sim_view.h"

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

	// Every drawn soldier of a side, compacted; get_drawn_count() says how many.
	PackedFloat32Array fill_transforms(int32_t p_side, float p_alpha);
	// Near/far split around the camera: writes both side buffers, returns near count.
	// Both fills skip soldiers in hidden sight tiles and stand them on the ground.
	int32_t fill_lod(int32_t p_side, float p_alpha, const Vector3 &p_camera, float p_near);
	PackedFloat32Array get_lod_buffer(int32_t p_side, int32_t p_far) const;
	int32_t get_lod_count(int32_t p_side, int32_t p_far) const;
	PackedVector2Array get_positions(float p_alpha) const;
	// Drawn (near + far) / living-and-in-a-visible-tile counts of the last fill.
	int32_t get_drawn_count(int32_t p_side) const;
	int32_t get_visible_alive(int32_t p_side) const;

	// The general's view (battle_sim_view.cpp). Height field: HeightField's
	// heights / resolution / spacing, origin = world XZ of sample (0, 0).
	void set_height_field(const PackedFloat32Array &p_heights, int32_t p_resolution,
			float p_spacing, const Vector2 &p_origin);
	float get_ground_height(float p_x, float p_z) const;
	// Tile mask, row-major, x fastest; an empty array turns culling off.
	void set_visibility_tiles(const PackedByteArray &p_visible, const Vector2 &p_origin,
			float p_tile_size, int32_t p_cols, int32_t p_rows);
	PackedByteArray get_visibility_tiles() const;
	int32_t get_tile_count() const { return int32_t(tiles.visible.size()); }
	// VisionTable constants, woods and dust (keys: see battle_sim_view.cpp).
	void set_sight(const Dictionary &p_sight);
	float sight_factor(const Vector3 &p_eye, const Vector3 &p_point) const;
	// Recompute tiles [first, first + count) from the eye; returns how many are visible.
	int32_t compute_visibility_tiles(const Vector3 &p_eye, int32_t p_first, int32_t p_count);
	// The sim's clamp box (soldiers never leave it), as XZ.
	Rect2 get_bounds() const;

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

	// Formations (battle_sim_formation.cpp): order + morale groups, ids 0..F-1.
	static constexpr int ORDER_ADVANCE = legatus::ORDER_ADVANCE;
	static constexpr int ORDER_HOLD = legatus::ORDER_HOLD;
	static constexpr int ORDER_WITHDRAW = legatus::ORDER_WITHDRAW;
	int32_t get_formation_count() const { return state.forms.count; }
	int32_t get_formation_side(int32_t p_f) const;
	Vector2 get_formation_center(int32_t p_f) const;
	int32_t get_formation_order(int32_t p_f) const;
	// No-op on a routed formation. HOLD anchors each man where he stands now.
	void set_formation_order(int32_t p_f, int32_t p_order);
	float get_formation_cohesion(int32_t p_f) const;
	bool is_formation_routed(int32_t p_f) const;
	// (dead + fled) / start strength.
	float get_formation_losses(int32_t p_f) const;
	// Loss fraction at the tick it broke; -1 while it never has.
	float get_formation_break_losses(int32_t p_f) const;
	// Living men still on the field.
	int32_t get_formation_strength(int32_t p_f) const;
	bool is_formation_engaged(int32_t p_f) const;
	// Routers who left the sim's box: not alive, not dead, never drawn.
	int32_t get_fled(int32_t p_side) const;
	// Test hook: one id per soldier; before setup_* (applied by the next
	// setup with the same count) or after it (applied at once).
	void set_formation_ids(const PackedInt32Array &p_ids);
	// Tuning hook: combat / cohesion constants by name (see get_tuning() for
	// the keys). Break thresholds are sampled at setup, so set those first.
	void set_tuning(const Dictionary &p_values);
	Dictionary get_tuning() const;

protected:
	static void _bind_methods();

private:
	enum Phase { PH_MOVE, PH_DAMAGE, PH_CLASSIFY, PH_WRITE };
	enum Draw : uint8_t { DRAW_NEAR = 0, DRAW_FAR = 1, DRAW_HIDDEN = 2 };

	legatus::SimState state;
	int32_t chunks = 128;
	int64_t last_tick_usec = 0;
	int32_t last_tick_threads = 0;
	int32_t alive_count[2] = { 0, 0 };
	int32_t fled_count[2] = { 0, 0 };
	std::vector<int32_t> pending_formation; // set_formation_ids before setup
	Phase phase = PH_MOVE;
	std::vector<size_t> chunk_thread;
	std::vector<int32_t> chunk_deaths;
	std::vector<int32_t> chunk_near; // fill: near count per chunk, then near offset
	std::vector<int32_t> chunk_far; // fill: far count per chunk, then far offset
	std::vector<int32_t> chunk_seen; // fill: living soldiers in visible tiles
	std::vector<uint8_t> lod_class; // fill: Draw class per soldier of the job side
	legatus::GroundField ground;
	legatus::SightTiles tiles;
	legatus::SightParams sight;
	int32_t drawn_counts[2] = { 0, 0 };
	int32_t seen_alive[2] = { 0, 0 };
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
	void classify_chunk(uint32_t p_chunk, int32_t p_begin, int32_t p_end);
	void write_chunk(uint32_t p_chunk, int32_t p_begin, int32_t p_end);
	int32_t fill_side(int32_t p_side, float p_alpha, float p_near2);
	static void _bind_view_methods();
	static void _bind_formation_methods();
	void setup_formations();
	static void chunk_thunk(void *p_self, uint32_t p_chunk);
};

} // namespace godot
