// BattleSim: formations as seen from GDScript. Orders go in between ticks;
// everything else reads the tables the serial formation pass keeps
// (sim_formation.cpp).
#include "battle_sim.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <vector>

namespace godot {

void BattleSim::_bind_formation_methods() {
	ClassDB::bind_method(D_METHOD("get_formation_count"), &BattleSim::get_formation_count);
	ClassDB::bind_method(D_METHOD("get_formation_side", "formation"),
			&BattleSim::get_formation_side);
	ClassDB::bind_method(D_METHOD("get_formation_center", "formation"),
			&BattleSim::get_formation_center);
	ClassDB::bind_method(D_METHOD("get_formation_order", "formation"),
			&BattleSim::get_formation_order);
	ClassDB::bind_method(D_METHOD("set_formation_order", "formation", "order"),
			&BattleSim::set_formation_order);
	ClassDB::bind_method(D_METHOD("get_formation_cohesion", "formation"),
			&BattleSim::get_formation_cohesion);
	ClassDB::bind_method(D_METHOD("is_formation_routed", "formation"),
			&BattleSim::is_formation_routed);
	ClassDB::bind_method(D_METHOD("get_formation_losses", "formation"),
			&BattleSim::get_formation_losses);
	ClassDB::bind_method(D_METHOD("get_formation_break_losses", "formation"),
			&BattleSim::get_formation_break_losses);
	ClassDB::bind_method(D_METHOD("get_formation_strength", "formation"),
			&BattleSim::get_formation_strength);
	ClassDB::bind_method(D_METHOD("is_formation_engaged", "formation"),
			&BattleSim::is_formation_engaged);
	ClassDB::bind_method(D_METHOD("get_fled", "side"), &BattleSim::get_fled);
	ClassDB::bind_method(D_METHOD("set_formation_ids", "ids"), &BattleSim::set_formation_ids);
	ClassDB::bind_method(D_METHOD("set_tuning", "values"), &BattleSim::set_tuning);
	ClassDB::bind_method(D_METHOD("get_tuning"), &BattleSim::get_tuning);
	BIND_CONSTANT(ORDER_ADVANCE);
	BIND_CONSTANT(ORDER_HOLD);
	BIND_CONSTANT(ORDER_WITHDRAW);
}

void BattleSim::setup_formations() {
	legatus::SimState &s = state;
	if (int32_t(pending_formation.size()) == s.count) {
		s.formation = pending_formation;
	}
	pending_formation.clear(); // ids apply to one setup only
	if (!legatus::sim_formation_setup(s)) {
		ERR_PRINT("formation ids must be >= 0 and one side each; using one per side");
		for (int32_t i = 0; i < s.count; i++) {
			s.formation[i] = s.side[i];
		}
		legatus::sim_formation_setup(s);
	}
}

void BattleSim::set_formation_ids(const PackedInt32Array &p_ids) {
	pending_formation.assign(p_ids.ptr(), p_ids.ptr() + p_ids.size());
	if (int32_t(p_ids.size()) == state.count && state.count > 0) {
		setup_formations();
	}
}

namespace {
struct Knob {
	const char *name;
	float *value;
};

std::vector<Knob> knobs(legatus::SimState &s) {
	legatus::SimParams &p = s.params;
	legatus::FormationParams &f = s.forms.params;
	return { { "rout_speed", &p.rout_speed }, { "rout_spread", &p.rout_spread },
		{ "pursuit_speed", &p.pursuit_speed }, { "attack_interval", &p.attack_interval },
		{ "hit_chance", &p.hit_chance }, { "kill_chance", &p.kill_chance },
		{ "pursuit_hit_chance", &p.pursuit_hit_chance },
		{ "pursuit_kill_chance", &p.pursuit_kill_chance }, { "break_min", &f.break_min },
		{ "break_max", &f.break_max }, { "engaged_stress", &f.engaged_stress },
		{ "recover", &f.recover }, { "contagion", &f.contagion },
		{ "contagion_radius", &f.contagion_radius }, { "enemy_relief", &f.enemy_relief },
		{ "rout_shock", &f.rout_shock }, { "rout_relief", &f.rout_relief },
		{ "withdraw_shock", &f.withdraw_shock }, { "wound_morale", &p.wound_morale },
		{ "fight_morale", &p.fight_morale }, { "rest_morale", &p.rest_morale },
		{ "soldier_rout_cohesion", &f.soldier_rout_cohesion } };
}
} // namespace

void BattleSim::set_tuning(const Dictionary &p_values) {
	for (const Knob &k : knobs(state)) {
		if (p_values.has(k.name)) {
			*k.value = float(p_values[k.name]);
		}
	}
	if (p_values.has("dmg_min")) {
		state.params.dmg_min = int32_t(p_values["dmg_min"]);
	}
	if (p_values.has("dmg_max")) {
		state.params.dmg_max = int32_t(p_values["dmg_max"]);
	}
}

Dictionary BattleSim::get_tuning() const {
	Dictionary out;
	for (const Knob &k : knobs(const_cast<legatus::SimState &>(state))) {
		out[k.name] = *k.value;
	}
	out["dmg_min"] = state.params.dmg_min;
	out["dmg_max"] = state.params.dmg_max;
	return out;
}

int32_t BattleSim::get_formation_side(int32_t p_f) const {
	ERR_FAIL_INDEX_V(p_f, state.forms.count, 0);
	return state.forms.side[p_f];
}

Vector2 BattleSim::get_formation_center(int32_t p_f) const {
	ERR_FAIL_INDEX_V(p_f, state.forms.count, Vector2());
	return Vector2(state.forms.cx[p_f], state.forms.cz[p_f]);
}

int32_t BattleSim::get_formation_order(int32_t p_f) const {
	ERR_FAIL_INDEX_V(p_f, state.forms.count, 0);
	return state.forms.order[p_f];
}

void BattleSim::set_formation_order(int32_t p_f, int32_t p_order) {
	ERR_FAIL_INDEX(p_f, state.forms.count);
	ERR_FAIL_COND_MSG(p_order < ORDER_ADVANCE || p_order > ORDER_WITHDRAW, "unknown order");
	legatus::sim_formation_order(state, p_f, uint8_t(p_order));
}

float BattleSim::get_formation_cohesion(int32_t p_f) const {
	ERR_FAIL_INDEX_V(p_f, state.forms.count, 0.0f);
	return state.forms.cohesion[p_f];
}

bool BattleSim::is_formation_routed(int32_t p_f) const {
	ERR_FAIL_INDEX_V(p_f, state.forms.count, false);
	return state.forms.routed[p_f] != 0;
}

float BattleSim::get_formation_losses(int32_t p_f) const {
	ERR_FAIL_INDEX_V(p_f, state.forms.count, 0.0f);
	return state.forms.losses(p_f);
}

float BattleSim::get_formation_break_losses(int32_t p_f) const {
	ERR_FAIL_INDEX_V(p_f, state.forms.count, -1.0f);
	return state.forms.break_losses[p_f];
}

int32_t BattleSim::get_formation_strength(int32_t p_f) const {
	ERR_FAIL_INDEX_V(p_f, state.forms.count, 0);
	return state.forms.living[p_f];
}

bool BattleSim::is_formation_engaged(int32_t p_f) const {
	ERR_FAIL_INDEX_V(p_f, state.forms.count, false);
	return state.forms.engaged[p_f] > 0;
}

int32_t BattleSim::get_fled(int32_t p_side) const {
	ERR_FAIL_INDEX_V(p_side, 2, 0);
	return fled_count[p_side];
}

} // namespace godot
