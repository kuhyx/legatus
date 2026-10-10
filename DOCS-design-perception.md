# Legatus design — perception, reports, scouts

Index and numbers table: `DOCS-design.md`. Format for each entry: the
**historical claim**, then what it means **in the game**. **[design]** marks
my inference. Lines without that mark are sourced.

## 1. The general's eye ("Mk1 Eyeball")

- **Claim:** The general's one visibility advantage is height: being on a
  horse lifts him above the infantry. His view is still limited to where he
  is, and he moves only at horse speed (Part I, §Mark One).
  **Game:** The camera sits at rider eye height (2.3 m, numbers table). There
  is no free camera, no zoom and no overhead view. To see somewhere, the player
  rides there.
- **Claim:** Games cheat on height and distance. Third-person cameras sit
  higher than a rider's eye, and obstructions such as trees, fences and hills
  sit close to the ground (Part I, §Mark One).
  **Game:** First person only. Line of sight is checked against terrain and
  vegetation at true eye height. A low hill blocks the view of a wing: "hills
  don't need to be very big to be taller than a man on horseback at their foot"
  (Part I, §Mark One).
- **Claim:** No telescope existed. A battlefield-useful one "was at least 1500
  years away" (Part I, §Mark One). The headquarters on a hill is an early
  modern habit that depends on optics (Part I, §Mark One).
  **Game:** No zoom key. A hill gives longer sight lines but not more detail
  (Part I, §Mark One).
  **[design]:** The field of view is fixed at about 70-80°. Squinting
  (slight FOV narrowing) is the only concession.
- **Claim:** At Pydna, at ~550 m, Aemilius could see the gleam of the
  Macedonians' bronze-faced shields as they were readied. He only knew which
  unit was in front of him once his legion was already attacking. His right
  wing, ~1 km away over a crest, showed as at most the glint of helmets, and
  his left was hidden by a small hill (Part I, §Mark One).
  **Game:** Rendering is tiered by distance:
  - <300 m: individuals are visible.
  - 300-800 m: you see blocks, facing, whether a block is moving, and
    glints.
  - 0.8-1.6 km: you see dark masses and dust.
  - beyond 1.6 km: "barely visible blobs" (Part I, §Mark One).
  **[design]:** The tier boundaries are the numbers-table rows. Each tier
  removes information: unit type, then formation, then facing, then whether
  the mass is friend or foe.
- **Claim:** Without uniforms, telling one block of troops from the next is
  hard even at moderate range, and friends get mistaken for foes
  (Part I, §Seeing the Battle). The general may not know where specific units
  are "unless they are very distinctive" (Part I, §Mark One).
  **Game:** No friend/foe outline, no unit labels, no health bars.
  **[design]:** Identification relies on what the eye can actually see:
  - standards (the Roman signa and aquila; Part II, §Signals and Shouting);
  - shield colour and type;
  - bare-chested Gauls versus Spaniards in purple-bordered tunics, drawn up
    in alternating companies (Plb. 3.114);
  - elephants;
  - the general's red cloak or crest (Part II, §Being Seen).
- **Claim:** There are no tooltips or stat sheets. In games, information is
  binary (fully known or fully hidden) and exact. On a real field it is
  neither (Part I, §Total Tactics?; Part I, §Reports).
  **Game:** No numbers are shown for any unit, friendly or enemy. Friendly
  state reaches the player only through reports and through what they see.

## 2. Dust, sun and haze

- **Claim:** Thousands of feet moving at once can raise a lot of dust,
  depending on the terrain, and it obscures the field
  (Part I, §Seeing the Battle).
  **Game:** Dust volumes are emitted per cell of the spatial grid, scaled by
  the number of moving feet and hooves (cavalry raise more) and carried by the
  wind. They reduce visibility (numbers table: 150-400 m inside a cloud
  [design guess]). A cloud of dust is itself information: something large is
  moving there [design].
- **Claim (conflicting traditions):** At Cannae, Polybius has Rome facing
  south and says "neither of them [was] inconvenienced by the rising sun"
  (Plb. 3.114). The Wikipedia article (citing Dodge 1891 and Daly 2002, i.e.
  the later tradition) has Rome facing east, with sun and an east wind blowing
  dust into Roman faces (https://en.wikipedia.org/wiki/Battle_of_Cannae).
  **Game [design]:** Sun angle and wind are scenario parameters. The default
  follows Polybius (no sun penalty, light wind); the "Livy tradition" is an
  option. A sun-facing observer gets glare and less contrast.
- **[design guess]:** Morning haze reduces long-range contrast by 30-50%
  until mid-morning. No source; flag it as tunable.

## 3. Scale: the army is physically big

- **Claim:** A Total War stack holds a few hundred metres of front. Pydna was
  fought on a field ~2.5 km wide. Marathon, with only 10,000 hoplites, was
  1.5-3 km wide (Part I, §Mark One). The largest Mediterranean armies (Cannae,
  Magnesia, Philippi) numbered 80-100k (Part I, §Mark One).
  **Game:** 2 x 50k soldiers on a line of 1.5-3 km of heavy infantry plus the
  cavalry wings (numbers table). No single viewpoint shows the whole line.
  Riding from one wing to the other takes 2-4 minutes at a gallop and spends
  part of the horse's gallop budget [design, from the numbers table].
- **Claim:** One legion (4,800) at Pydna filled a whole street-view frame at
  ~550 m (Part I, §Mark One).
  **Game [design]:** This is the calibration test for the renderer at 550 m:
  one legion should fill a ~75° horizontal field of view.

## 4. Reports (before and during the battle)

- **Claim:** Information comes as "reports": from cavalry scouts, but just as
  often from civilians, traders and friendly factions in enemy territory.
  Your own scouts are the most reliable, but they stay close to the army
  (Part I, §Reports).
  **Game:** The pre-battle intelligence screen is a pile of text reports. Each
  has a source type (scout / trader / deserter / local partisan), an age and a
  hidden reliability. Scout reports cover only a bubble of a few km around the
  army [design radius].
- **Claim:** Reports are frequently wrong, and seeding false ones was a
  standard stratagem (Part I, §Reports; Part I, fn 5). The general does not
  know where his blind spots are: no report is not the same as no enemy
  (Part I, §Reports).
  **Game:** There is no fog-of-war overlay, because the player does not know
  where the fog is. Some reports are false: the enemy AI can plant
  disinformation, and campfires can be faked (Part I, §Reports).
  **[design]:** Base false-report rates: scout 10%, trader 30%,
  deserter 40% [design guess].
- **Claim:** Rumour and merchant reports travel at about the speed of an army.
  Generals know an enemy's region and objective ("in such-and-such town ten
  days ago") but not his current position (Part I, §Reports).
  **Game:** Every report carries the time it was observed, not the time it
  arrived. The player must extrapolate.
- **Claim:** Size and composition were the hardest things to hide: "the enemy
  has brought many war elephants", "their army is much larger than mine".
  Campfire counts give a size estimate, and they can be faked
  (Part I, §Reports; Part I, §So how was it done?).
  **Game:** Composition reports are coarse buckets ("many horse", "about as
  many foot as ours") with ±30% noise [design guess]. Exact orders of battle
  are never given.
- **Claim:** A small detachment appearing in the middle of a battle can be
  mistaken for a whole new army. At Delium (424) a detachment of Boeotian
  cavalry routed the victorious Athenian right; at Tifernum (297) a Roman
  detachment did the same to the Samnites (Part I, §Reports).
  **Game:** The morale model has a "new force appears on flank/rear" shock
  scaled by what the observing unit can see, not by the true size of the force
  [design, built on the claim]. The player can stage this deliberately.
- **Claim:** In a meeting engagement, both generals reinforce their scouts
  based on the scouts' own reports, and the clash escalates into a general
  battle (Cynoscephalae, 197; Part I, §Reports). Pydna began as a fight over
  water between parties from both sides (Part I, §Mark One; Part I, fn 12).
  **Game [design]:** Scenario variant: the battle starts by escalation from
  forager or picket clashes, not from a planned deployment.
- **During battle:**
  - **Claim:** Subordinates nearer the action see better and may ride back to
    report, as Scipio Nasica probably did at Pydna (Part I, §Mark One).
  - **Game:** Officers send riders back with short reports ("Legio II holding,
    hard pressed"). These are subject to the same courier delay and loss as
    orders (`DOCS-design-command.md`).
  - **[design]:** Officers' reports are biased by their morale. Shaken
    officers over-report danger.

## 5. What the general does NOT get [design, from Part I §Total Tactics?]

- **Numbers and time:**
  - no minimap or overhead camera;
  - no unit cards, counts, health or fatigue bars;
  - no pause-and-give-orders;
  - no instant orders.
- **Feedback:**
  - no "unit is fleeing" notification. The player sees the rout or hears it
    reported.
- **Position:**
  - no compass HUD beyond what a rider could know, i.e. the sun and landmarks
    [design];
  - an optional hand-drawn sketch map from the council of war showing the
    *planned* positions, never live ones [design].
