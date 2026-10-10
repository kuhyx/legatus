// Structure-of-arrays battle state plus the per-tick kernels. Kernels are pure
// C++ over std::vector (no Godot calls) so they can run on worker threads.
// Determinism: each kernel reads only the previous tick's buffers (o*) and
// writes only its own slot of the current ones; damage goes through integer
// atomics (order-independent sums); randomness is a stateless hash of
// (seed, tick, index). Chunking and thread count therefore never change
// the result.
#pragma once

#include <cstdint>
#include <vector>

#include "sim_formation.h"
#include "sim_grid.h"

namespace legatus {

enum SoldierState : uint8_t {
	ST_ADVANCE = 0,
	ST_FIGHT = 1,
	ST_ROUT = 2,
	ST_DEAD = 3,
	ST_FLED = 4, // a router who left the field: alive 0, never drawn, not dead
};

// Combat constants. Lethality is per landed blow (a rare outright kill on a
// Poisson clock, otherwise a light wound) so deaths trickle from the first
// second at ~1 %/min of a deep formation; pursuit multiplies it. The
// [design guess] rows for these live in DOCS-design.md.
struct SimParams {
	float body_radius = 0.42f; // shoulder half-width, m
	float reach = 1.7f; // sword arm + half step, m
	float walk_speed = 1.4f; // m/s, formed advance
	float charge_speed = 3.2f; // m/s, last metres before contact
	float charge_dist = 15.0f; // m
	float rout_speed = 3.0f; // m/s, mean; each man gets +-rout_spread of it
	float rout_spread = 0.35f;
	float pursuit_speed = 3.6f; // m/s, chasing a man of a routed formation
	float accel = 0.35f; // velocity blend per tick
	float max_push = 0.25f; // m per tick, separation correction cap
	float attack_interval = 1.4f; // s between blows, fresh
	float hit_chance = 0.3f; // a blow lands (most land on shield or armour)
	float kill_chance = 0.0015f; // a landed blow kills outright
	float pursuit_hit_chance = 0.6f; // against a man who has turned his back
	float pursuit_kill_chance = 0.08f;
	int32_t max_hp = 1000;
	int32_t dmg_min = 5; // light wound, hp
	int32_t dmg_max = 25;
	int32_t search_cells = 24; // nearest-enemy ring radius, cells (48 m: whole block depth)
	int32_t retarget_period = 5; // ticks; staggered by soldier index
	float rout_morale = 0.12f; // a man alone runs below this (and low cohesion)
	float wound_morale = 0.01f; // morale per light wound
	float fight_morale = 0.002f; // morale per second of fighting
	float rest_morale = 0.01f; // morale regained per second out of contact
};

struct SimState {
	SimParams params;
	SimGrid grid;
	FormationState forms;
	uint64_t seed = 1;
	uint32_t tick = 0;
	float dt = 0.05f;
	int32_t count = 0;
	int32_t side_begin[3] = { 0, 0, 0 }; // side s occupies [side_begin[s], side_begin[s+1])

	// Double-buffered kinematics: o* = previous tick, plain = current tick.
	std::vector<float> px, pz, ox, oz;
	std::vector<float> vx, vz, ovx, ovz;
	std::vector<float> facing, ofacing;
	// Single-buffered, written only by the owner (or in the damage phase).
	std::vector<int32_t> hp, dmg_in, target;
	std::vector<float> fatigue, morale, cooldown, phase, home_x;
	std::vector<float> anchor_x, anchor_z; // HOLD stands here; WITHDRAW walks here
	std::vector<uint8_t> side, state, alive;
	std::vector<int32_t> formation;

	void resize(int32_t p_count);
	void swap_buffers();
};

// Counter-based hash RNG in [0, 1): same inputs, same value, any thread.
float sim_rand(uint64_t p_seed, uint32_t p_tick, int32_t p_index, uint32_t p_salt);

// Phase A: perception, steering, separation, attacks for soldiers [p_begin, p_end).
void sim_kernel_move(SimState &s, int32_t p_begin, int32_t p_end);
// Phase B: apply accumulated damage; returns deaths in the range per side.
void sim_kernel_damage(SimState &s, int32_t p_begin, int32_t p_end, int32_t r_deaths[2]);
// Phase C (serial): fled men leave the field, formation tables, cohesion and
// routs. Adds the fled per side to r_fled. sim_formation.cpp.
void sim_formation_pass(SimState &s, int32_t r_fled[2]);
// Rebuild the formation tables from s.formation (setup / set_formation_ids).
bool sim_formation_setup(SimState &s);
// New order for formation f; ignored once it has routed. Returns false then.
// sim_orders.cpp, with the serial halt / rally step below.
bool sim_formation_order(SimState &s, int32_t p_f, uint8_t p_order);
// Serial, end of the formation pass: a withdrawal that reached its goal
// holds there; a routed formation unpursued long enough, with a friend near,
// rallies once and re-forms on the spot.
void sim_orders_pass(SimState &s);
// Desired velocity, state and facing for soldier i (sim_steer.cpp).
struct Steer {
	float vx = 0.0f;
	float vz = 0.0f;
	bool face_target = false; // face the target (else the direction of travel)
	bool face_front = false; // face the enemy's side of the field
};
Steer sim_steer(SimState &s, int32_t p_index, int32_t p_target, float p_tdx, float p_tdz,
		float p_dist);
// Nearest living enemy of soldier i within the search radius, or -1.
int32_t sim_find_enemy(const SimState &s, int32_t p_index);

} // namespace legatus
