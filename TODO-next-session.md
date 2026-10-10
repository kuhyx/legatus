# TODO: session 3 — reports, officers, enemy plan, signals

REMOVE ME AFTER FINISH

State at hand-off (2026-10-10): Part 4a is committed on `main` and pushed.
`scripts/check.sh` all green (76/76 tests). Headless 100k: tick p50 4.6 ms,
p99 6.3 ms. Offscreen fps gate: bench 6.1 ms / battle 7.1 ms frame p99.

## Done in session 2 (Part 4a)

- Terrain colour (sRGB vertex colours, sky ambient 0.5, depth fog 200 m-3 km).
- Formations: cohesion, break at 4-10 % losses, contagion shock, routs,
  ST_FLED for routers leaving the clamp box (not drawn, not alive);
  orders advance / hold / withdraw; `src/sim/calibrate_morale.gd`.
- Couriers (`src/command/`): 40 km/h riders, 60-180 s handoff, loss rolls,
  pool of 8, keys 1/2/3 at the block in view, riders drawn only in sight.
  Engaged units ignore "advance". `--order=N` sends one at battle start.

## Calibration gaps (from calibrate_morale.gd, one seed, 15 min)

- Break losses 1.8-7.8 % (target <= 10 %): ok. But no unit yet routs with
  ZERO losses (contagion is a one-off 0.5 shock; continuous contagion made
  both armies collapse). Needs the fear-from-what-you-see model (approach
  speed / mass, flank and rear contact), DOCS-design-army §3.
- Losers 15.9 % killed (target 14-16 %): ok. Winners 6.8 % (target 4-5 %).
- Run several seeds before trusting any of it; make it a regression test
  (DOCS-design-army §4) once the numbers are stable.

## Session 3 scope

- Reports arriving late and sometimes wrong (DOCS-design-perception.md),
  including "no acknowledgement came back" for lost couriers.
- Officers with imperfect obedience / initiative (Part IIIb); order-ignored
  roll (10-25 %, numbers table) on courier delivery.
- Enemy AI following its own pre-battle plan (plan dominance, Part II).
- Signals (trumpets/standards) with limited reach (DOCS-design-command §2).
- Withdraw -> rally: routed units never rally yet; withdrawn units walk to
  the clamp edge forever. Add a halt/rally rule.

## Known gaps carried over

- Couriers ride straight lines (no pathing round woods/enemy) and are not
  killed physically; loss is a dispatch roll. Picker uses block centres only.
- Formations are ~60-file blocks (~2,000 men), not maniples.
- Vertex-animation textures (today: procedural bob/stride shader).
- Real impostors beyond 120 m (today: 24-tri box); crowd shadows off.
- Dead soldiers stay in the instance count (fled ones are skipped).
- Visibility is per 25 m tile centre; soldiers do not occlude each other.
- godot-cpp pin (`godot-4.5-stable`) is NOT checked by the dep-freshness gate
  (it has no submodule support); checked by hand against the tag list 2026-10-10.
