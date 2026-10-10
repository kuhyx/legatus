# TODO: session 2 — Part 4, the command loop

REMOVE ME AFTER FINISH

State at hand-off (2026-10-10): Parts 1–3 + integration are committed on
`main` (local only, no remote). `scripts/check.sh` is all green (43/43 tests).
Headless 100k worst case: tick p50 4.3 ms, p99 6.3 ms (under the 20 % cap).

## Blocking on kuhy first

- Windowed fps gate (gate 2) has never run: `! ~/src/legatus/scripts/bench.sh`
  (opens a window, 2 x 30 s: bench.tscn then battle.tscn; exits 1 if either
  frame p99 > 16.7 ms). First Forward+ render ever: all visual checks so far
  were Compatibility on llvmpipe. Headless+capped battle frame p99 was 35 ms
  (not representative, but hints at the sync-tick spike).
  If it misses: async/triple-buffered tick (sync tick costs ~3–5 ms every
  third frame), compact LOD uploads (~12.8 MB/frame today), then GPU path.
- Answer the 8 open questions in `DOCS-design.md` (symmetric 50k vs Polybius'
  86k/50k; which side; campaign phase; time compression; general's death;
  Roman frontage 0.9 vs 1.8 m; courier loss/disobedience tuning; reports as
  text or voice).
- GitHub remote: create public `kuhyx/legatus` + push? (not done; outward-facing).
  Also push `~/src/utils` commit 3f7af48 (file-length exemption) so CI agrees.

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
- Original note's "prehistorical blog post (?)" is still unidentified.
