# TODO: after Part 5b — enemy plan, signals, initiative, calibration

REMOVE ME AFTER FINISH

State at hand-off (2026-10-11): Parts 5a and 5b pushed; the contact fps
gate, the no-op order skip and the `handed_over_count` rename are committed
on `main`. `scripts/check.sh` all green (161/161 tests). Offscreen fps
gate (battle timed from sim 170 s, in contact on every tick): bench 5.95 ms
/ battle 9.09 ms frame p99.

## Next: the rout cascade (needs its own spec round)

Seeds 6-20 settled the side-0 question: seed luck, not bias (side 0 lost
8 of 15; at most 13 of 20 with seeds 1-5, rule set beforehand: >= 15/20 =
bias). The real defect: 11 of 15 seeds are all-or-nothing, the loser's 25
blocks all break (~17.5 % killed) while the winner loses ~2.6 % (seed 18:
all 25 side-0 blocks routed together near 240 s). Mean losers / winners
17.1 / 3.6 % vs target 14-16 / 4-5. Mixed outcomes only on seeds 10, 15,
20 (and 1, 5). Look at rout contagion first, then fear from what you see
(below). Per seed (s0 broken/killed % | s1): 6 25/17.5|3/2.6, 7 2/2.6|
25/17.5, 8 25/17.5|3/2.7, 9 25/17.1|3/2.6, 10 5/6.8|22/19.4, 11 25/17.6|
3/2.5, 12 2/2.6|25/17.8, 13 25/17.2|2/2.7, 14 1/2.4|25/18.2, 15 21/14.3|
11/7.2, 16 3/2.7|25/17.4, 17 3/2.7|25/17.3, 18 25/17.8|2/2.6, 19 2/2.6|
25/17.6, 20 19/14.8|10/9.2.

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
  side 0 loses 25 blocks to 4: seed luck (seeds 6-20, above).
  Fear-from-what-you-see (approach speed / mass,
  flank and rear contact, DOCS-design-army §3); make the 5-seed run a
  regression test once stable.
- Without orders Rome loses the battle scene outright (deeper enemy front
  line; rout cascade through the reserve lines): 15-min headless run, Rome
  1,247 left at the end, the enemy lost ~1,250. Rallies work (119) but the
  rallied re-break in the cascade. Accepted for now (kuhy 2026-10-10):
  same cascade as the calibration (Next, above).
- Start view: the whole army is in sight from the start hill (kept, kuhy
  2026-10-10; test_start_view_is_within_the_battle).

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

## Done in Part 5b (2026-10-10)

- Officers: per-officer ignore chance 10-25 % (seeded), each roll from its
  own stream (seed, formation, orders so far); an ignored order is still
  acknowledged. OrderLog on the HUD: sent / acknowledged hh:mm / found them
  broken hh:mm; a lost order stays "sent".
- Reports by rider (ReportService): on a change of the true level, max 1 per
  block per 60 s, leaving the block's rear (60 m standoff: ~15 % loss near the
  enemy instead of ~50 % from inside the melee), 16 riders, a report past
  the cap waits (re-read at dispatch, never dropped). Morale bias is a seeded
  roll per report, chance (0.5 - cohesion) / 0.5.
- `--order-at=S`, comma lists for `--order` / `--order-to` / `--order-at`.
- Agent runs are muted (`--audio-driver Dummy`); the CLAUDE.md screenshot
  command now uses the bench's tiny-window flags (the 640x360 window cost
  ~50 ms a frame in Xvfb copies).

## Part 5b follow-ups

- Report wording is levels only; DOCS-design-perception §4 also wants
  unit names ("Legio II") once formations have them.
