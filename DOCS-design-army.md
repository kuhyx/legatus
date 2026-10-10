# Legatus design — drill, officers, morale, cohesion, routs

Index and numbers table: `DOCS-design.md`. Each entry gives the historical
claim, then what it means in the game. **[design]** marks my inference. Lines
without the mark are sourced.

## 1. Synchronized discipline: orders by the menu

- **Claim:** An army is a very large crowd under extreme stress. Soldiers do
  not "snap" into formation the way game models do. Moving from column into
  line on the fly was hard enough that armies matched marching width to
  fighting depth and simply faced left or right (Part IIIa, §Plug-and-Play
  Armies; Part I, §So how was it done?).
  **Game:** Soldiers are individuals who keep a position relative to their
  file-leader and their standard. They are never teleported or slot-snapped
  [design].
  - Formation changes take real time and can fail. A failed change leaves the
    unit disordered.
  - Deployment from camp uses the march-to-line method
    (`DOCS-design-prebattle.md`).
- **Claim:** Nobody fights in a confused melee on purpose. The battle line
  makes each man responsible for a few feet of front. Depth replaces the
  fallen and steadies the line (Part IIIa, §All Together Now).
  - A gap lets enemies in.
  - "Two-on-one contests in melee combat typically end in seconds" (Part IIIa,
    §All Together Now).
  - The line "neither holds rigidly steady nor dissolves but ... flex[es] and
    bend[s]" (Part IIIa, §All Together Now).
  **Game:** Combat is resolved between front-rank individuals inside the
  line.
  - Flanked or isolated men die quickly. Being outnumbered locally is the
    main killer [design].
  - Rear ranks step up and the line bends rather than locking rigid. This is
    the core requirement for the C++ crowd sim.
- **Claim:** Moving together needs speed regulation: music or a beat (the
  Greek aulos). Self-regulated speed causes accordioning that turns a line
  into a crowd (Part IIIa, §All Together Now).
  **Game:** Each unit has a pace source (drum, horn or aulos). Units without
  one accumulate disorder while advancing. Disorder grows with distance
  marched and with rough ground [design].
- **Claim:** Turning, changing width, forming square, feigned retreat and
  wheeling all need drill. A right wheel means every man moves at a different
  speed. Discipline in this sense, "synchronized discipline" (W. Lee), is
  mostly produced by drill (Part IIIa, §All Together Now; Part IIIa, §Drill
  and Synchronized Discipline).
  **Game:** Each unit type has a drilled order menu. Orders not on the menu
  are not offered. "He cannot order anything not on the menu" (Part IIIa,
  §Orders by the Menu).
  - Roman legion: advance, halt, charge, throw pila, retreat behind the next
    line, close gaps, wheel or turn. Maniples or cohorts can be "driven" (Part
    IIIa, §The Limits of the Possible with Synchronized Discipline).
  - Gauls and Spaniards: advance, hold, charge, retreat [design].
  - Levies with poor cohesion: hold; possibly advance; possibly refuse
    [design] (Part IIIa, §Conclusion, Part IIIa; Part IIIa, fn 9).
- **Claim:** New menu items must be drilled well before the battle. Caesar
  drilled anti-elephant tactics before Thapsus. Alexander's phalanx was
  drilled against scythed chariots (Part IIIa, §Orders by the Menu).
  **Game [design]:** Pre-battle prep lets you add one or two drilled
  responses, for example "open lanes for elephants". This costs camp days
  (`DOCS-design-prebattle.md`).
- **Claim:** Even Romans mostly just pushed forward in the standard way, even
  when that was disastrous, as at Cannae (Part IIIa, §The Limits of the
  Possible with Synchronized Discipline).
  **Game:** The default AI behaviour for any unit with no fresh order is to
  execute its council-of-war intent, even into a trap [design].

## 2. Officers and initiative

- **Claim:** Officers have three jobs: administration, executing orders, and
  making their own tactical decisions. That last one is the important one
  (Part IIIb, §Independent Command).
  **Game:** Every unit has an officer agent with an initiative rating and a
  culture setting. The officer interprets intent, reacts to local threats,
  and can deviate from the plan [design].
- **Claim:** Ratios of officers to men (Part IIIb, §How Much Officer Do You
  Need?):
  - Roman ~1:5.5;
  - Macedonian syntagma 1:2.2;
  - Spartan ~1:19.
  The Roman army had fewer officers than the Macedonian one but was more
  flexible, because independence reached down to centurions. The Macedonian
  taxis, ~1,500 men, was the smallest independent unit there (Part IIIb,
  §Independent Command).
  **Game:** Command granularity per faction:
  - Romans: the maniple (120) can act on its own, and the century (60)
    sometimes can.
  - Carthaginian African infantry: I have no source for its granularity.
    [design guess] treat it as maniple-like, since it was "armed in the Roman
    fashion" (Plb. 3.114).
  - Gallic and Spanish allies: whole contingent blocks [design guess].
- **Claim:** Initiative mostly shows up in extremis.
  - At Cynoscephalae an unnamed tribune took 20 maniples into the Macedonian
    flank and won.
  - At Bibracte the third line about-faced, apparently on the centurions'
    initiative.
  - Pelignian officers threw standards into enemy lines to force a charge.
  (Part IIIb, §Independent Command; Part II, §The Battle Manager)
  **Game:** Officer AI can:
  - wheel unengaged units into an exposed enemy flank;
  - face the rear when attacked from behind;
  - start an unordered attack.
  The chance grows with initiative and with how desperate the situation is
  [design]. The player may see their plan improved or wrecked.
- **Claim:** This depends on command culture. The officer has to believe
  "the general will reward me for my initiative" (Part IIIb, §Independent
  Command). Disobedience happens: Sickles moved 1.1 km forward (Part II,
  fn 3). Plundering the enemy camp instead of turning on the centre was a
  constant problem (Part I, fn 10).
  **Game [design]:**
  - Officers have a loot/pursuit impulse. A victorious wing may chase or
    plunder instead of turning inward, unless the general or a tribune is
    present.
  - A rare chance of outright insubordination scales with officer temperament.

## 3. Morale and cohesion (two separate variables)

- **Claim:** Morale is commitment to the leaders and the cause. Cohesion is
  the bond to comrades and junior officers. Morale gets men to the battle;
  cohesion gets them through it (Part IIIc, §Morale and Cohesion, citing
  McPherson).
  - Both are emergent: individuals keep weighing risk.
  - Drill builds "synthetic" cohesion; kin, neighbours and shame build
    "organic" cohesion.
  (Part IIIc, §Morale and Cohesion; Part IIIa, §Conclusion, Part IIIa)
  **Game:** Each soldier has `fear` (individual). Each unit has `cohesion`
  (bond strength) and `morale` (faith in plan and leaders).
  - A soldier flees when his fear exceeds the hold that cohesion has on him,
    and cohesion is lowered by neighbours fleeing [design].
  - Breaking is contagious inside a unit and between adjacent units, but it
    is not unit-wide binary [design, built on the claim].
- **Claim:** Outcomes are not binary (Part IIIc, §Complex Outcomes):
  - high morale with low cohesion: the unit panics and dissolves, but
    reassembles later (Bull Run);
  - high cohesion with low morale: the unit stays together but refuses to
    attack (the 1917 French mutiny);
  - turning on its leaders: possible with a cohesive unit;
  - too aggressive: attacks without orders.
  **Game:** Unit states as a ladder modelled on Sierra *Civil War Generals*
  (Part IIIc, §Complex Outcomes; Part IIIa, fn 9):
  1. eager (may attack unordered);
  2. steady;
  3. won't charge;
  4. won't attack;
  5. won't advance (but holds);
  6. retreats in good order;
  7. routs.
  Plus a cohesive-but-refusing branch [design].
- **Claim:** Units often break before contact or at the moment of contact
  (Mantinea 418: "not even waiting to strike a blow"). Shock cavalry works
  because of this, and it is nearly useless against dense, steady infantry
  (Part IIIc, §When Does Morale and Cohesion Fail?).
  **Game:** Fear spikes as a charge approaches, scaled by the closing speed
  and mass the soldier can see and by his cohesion. Some units will rout with
  zero casualties.
  **[design]:** Cavalry against steady, formed infantry stalls and bounces.
- **Claim:** Ordering cheap troops into elite troops does not tie the elites
  down; the cheap troops run. Peasant mobs "will not ... stick around". A
  real anvil needs quality infantry (Part IIIc, §When Does Morale and Cohesion
  Fail?; Part II, fn 4).
  **Game:** No "tarpit" play. Low-cohesion units given suicidal orders refuse
  or break early.
- **Claim:** Many things can each rout a cohesive army on their own (Part
  IIIc, §Gaming Morale):
  - being charged from behind;
  - an enemy stronger than you;
  - neighbours routing;
  - the general's death.
  **Game:** Shock modifiers: rear or flank contact, a new force appearing
  (`DOCS-design-perception.md`), a rout seen next to you, a general-dead
  rumour. Each is large enough to break units on its own, with no damage
  prerequisite [design magnitudes].

## 4. Casualties and the rout

- **Claim:** Pre-modern armies "generally seem to have fallen apart at or
  before 10% losses". Hoplite losses were winners 5% / losers 14% (Krentz).
  Roman losses 200-168 BC were 4.2% / 16% (Rosenstein). "Most losses occur
  after an army breaks and runs" (Part IIIc, §When Does Morale and Cohesion
  Fail?).
  **Game:** These are calibration targets. Over many simulated battles the
  defaults must give a median break near ≤10% losses and median final losses
  near 4-5% for winners and 14-16% for losers. A regression test checks the
  numbers [design].
  **Sim, 2026-10-10** (`src/sim/calibrate_morale.gd`, 2 x 50k bench, seed
  42, one run capped at 15 min, constants in the `DOCS-design.md` table):
  breaks at 1.8-7.8 % losses (medians 2.4 % / 5.2 %), most 3.5-4 min into
  contact, a few pairs fought on to 11-15 min. The side that broke (24/25
  blocks) lost 15.9 % killed, 6.8 k of 7.9 k after its first break, and 77.5 %
  fled. The other broke 6/25 blocks: 4.5 % killed at 8 min, 6.8 % at the cap
  (one pair still in contact). No block has yet routed with zero losses.
- **Claim:** Extreme casualties come from special circumstances: the army
  cannot retreat. Romans pursued better than hoplites did (Part IIIc, §When
  Does Morale and Cohesion Fail?). At Cannae, ~70,000 of ~86,000 Romans died
  (Plb. 3.117); Livy gives 48,200.
  **Game:** Rout killing is driven by pursuit:
  - fleeing men do not defend themselves;
  - cavalry pursuit is deadly;
  - an encircled unit with no escape path cannot flee, so it fights and dies.
  A Cannae-level total therefore emerges only from encirclement [design].
- **Claim:** In a shock defeat, a broken formation tends not to reform,
  because it is being chased (Part II, §Different Sorts of Generals). Bull
  Run's army reformed later and only 1,216 of ~18,000 were missing (Part IIIc,
  §Complex Outcomes).
  **Game:**
  - Routed units can rally only if they are not pursued and can see a
    standard or officer rallying them [design].
  - Fugitives who leave the map count as "dispersed", not dead.
- **Claim:** Pressing a Total War peasant mob to ~1/3 losses or ~50% army
  losses before it breaks is ahistorical. Crusader Kings III's ~30% is still
  about triple the norm (Part IIIc, §Gaming Morale).
  **Game:** No hidden "army losses" backstop is needed if per-soldier fear
  is tuned right. Army-wide collapse comes from contagion and sight lines
  [design].
