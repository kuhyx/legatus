# TODO: session 2 — Part 4, the command loop

REMOVE ME AFTER FINISH

State at hand-off (2026-10-10): Parts 1–3 + integration are committed on
`main`, pushed to github.com/kuhyx/legatus. `scripts/check.sh` is all green (43/43 tests).
Headless 100k worst case: tick p50 4.3 ms, p99 6.3 ms (under the 20 % cap).

## Status

- Gate 2 passed (2026-10-10). kuhy's real window: frame p99 3.22 ms (bench) /
  3.70 ms (battle). Offscreen (`scripts/bench.sh --offscreen`, 20 % CPU cap):
  5.85 / 7.09 ms, GPU ~2.5 ms. Agents rerun the offscreen gate themselves.
- Terrain is far too pale/washed out in Forward+ too (not just llvmpipe):
  fix ground material / exposure / fog before judging visuals.
- Design questions: answered, see `DOCS-design.md` "Decisions".

## Part 4 scope (from DOCS-design-command.md / -army.md)

- Formations as order + morale groups over individual soldiers (formation_id
  already in the sim's SoA state).
- Couriers: physical riders at 40 km/h, handoff latency, loss per km / near
  enemy / through melee (numbers table, [design guess] rows).
- Reports arriving late and sometimes wrong (DOCS-design-perception.md).
- Morale & cohesion: units break at or before ~10 % losses, casualties mostly
  in rout (Part IIIc); replace placeholder combat constants (18 % casualties
  in 20 s is too high).
- Officers with imperfect obedience / initiative (Part IIIb).
- Enemy AI following a pre-battle plan (plan dominance, Part II).
- Signals (trumpets/standards) with limited reach.

## Known gaps carried over

- Vertex-animation textures (today: procedural bob/stride shader).
- Real impostors beyond 120 m (today: 24-tri box); crowd shadows off.
- Dead soldiers stay in the instance count.
- Visibility is per 25 m tile centre; soldiers do not occlude each other.
- Culling treats soldiers OUTSIDE the tile grid as drawn: once routs exist,
  fugitives leaving the battle bounds are visible regardless of LOS. Fix then.
- godot-cpp pin (`godot-4.5-stable`) is NOT checked by the dep-freshness gate
  (it has no submodule support); checked by hand against the tag list 2026-10-10.
