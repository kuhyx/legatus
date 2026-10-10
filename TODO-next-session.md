# TODO: Part 5b and later — reports, officers, enemy plan, signals

REMOVE ME AFTER FINISH

State at hand-off (2026-10-10): Part 5a is committed on `main`, not pushed
until kuhy confirms. `scripts/check.sh` all green (127/127 tests). Headless
100k: tick p50 4.56 ms, p99 6.09 ms. Offscreen fps gate: bench 5.85 ms /
battle 8.33 ms frame p99 (battle was 7.1: all 100k now in sight at start).
The battle gate's 30 s window now ends before contact (~159 s); 300 s live
runs with contact: frame p99 10.4 / 14.3 ms. Extend the window or add a
contact scenario.

## Done in Part 5a

- Battle deployment (`setup_array`, `BattleWorld`): fronts 150 m apart, all
  blocks on hold; Rome 3 lines 40/40/20, enemy 2 lines 60/40, 80 m rear rank
  to next front rank. `EnemyPlan` placeholder: enemy front line advances at
  60 s (contact ~159 s).
- Withdraw walks 150 m back, then holds; routed / withdrawing men pass
  through their own lines; routers rally once (no enemy within 60 m for 20 s,
  a friend within 150 m) at cohesion 0.3.
- Enemy search skipped when no enemy block is within reach (armies apart:
  ~200 ms -> ~2 ms a tick). Formation pass is two-sweep (order-independent);
  that was NOT the side-0 bias (below).
- `--order-to=F`, `--verbose` `formations:` log.

## Part 5b (agreed scope, needs its own question round first)

- Officer order-ignored roll (10-25 %, numbers table) on courier delivery:
  no seniority model yet, so how the probability is chosen is open.
- Reports back by courier (DOCS-design-perception.md §4): what an officer
  reports, how often, morale bias; "no acknowledgement came back" for lost
  couriers — when the absence counts as noticed.

## Later

- Enemy AI with its own pre-battle plan (plan dominance, Part II), its own
  couriers; replaces `EnemyPlan`.
- Signals (trumpets/standards) with limited reach (DOCS-design-command §2).
- Officer initiative (Part IIIb): in-extremis moves, pursuit impulse.
- Order picker picks by bearing only: from behind, all three Roman lines
  are "in view" at once; a reserve block is addressable only from the flank.
- Calibration, 5 seeds (`calibrate_morale.gd --minutes=15 --seed=1..5`),
  losers / winners killed %: main 13.5/10.2, 16.2/2.4, 16.9/2.8, 16.6/2.7,
  11.6/9.7; Part 5a 13.5/11.0, 16.8/2.4, 17.4/2.8, 17.4/2.7, 12.0/11.4
  (target 14-16 / 4-5). Seeds 1 and 5: both sides collapse. Seeds 2-4:
  side 0 loses 25 blocks to 4, unchanged by the two-sweep pass, so the
  cause is elsewhere (or seed luck): run seeds 6-20 before hunting it.
  Fear-from-what-you-see (approach speed / mass,
  flank and rear contact, DOCS-design-army §3); make the 5-seed run a
  regression test once stable.
- Without orders Rome loses the battle scene outright (deeper enemy front
  line; rout cascade through the reserve lines): 15-min headless run, Rome
  1,247 left at the end, the enemy lost ~1,250. Rallies work (119) but the
  rallied re-break in the cascade. Accepted for now (kuhy 2026-10-10);
  next calibration session runs seeds 6-20 to tell bias from seed luck.
- Start view: the whole army is in sight from the start hill (kept, kuhy
  2026-10-10; test_start_view_is_within_the_battle).
- Debug only: `CourierService.delivered_count` counts an "advance" that
  BattleCommand.deliver drops for an engaged block.

## Known gaps carried over

- Couriers ride straight lines (no pathing round woods/enemy) and are not
  killed physically; loss is a dispatch roll. Picker uses block centres only.
- Formations are ~60-file blocks (~400-1,200 men in the battle), not
  maniples; no quincunx gaps (passing through stands in for them).
- Vertex-animation textures (today: procedural bob/stride shader).
- Real impostors beyond 120 m (today: 24-tri box); crowd shadows off.
- Dead soldiers stay in the instance count (fled ones are skipped).
- Visibility is per 25 m tile centre; soldiers do not occlude each other.
- godot-cpp pin (`godot-4.5-stable`) is NOT checked by the dep-freshness gate
  (it has no submodule support); checked by hand against the tag list 2026-10-10.
