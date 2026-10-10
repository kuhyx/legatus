# Legatus design — camps, offering battle, deployment, the supply clock

Index and numbers table: `DOCS-design.md`. Format for each entry: the
**historical claim**, then what it means **in the game**. **[design]** marks
my inference. Lines without that mark are sourced.

## 1. Encamped opposite the enemy

- **Claim:** True encounter battles were the exception. Armies forage, so
  the enemy's rough location is known, and scouts create a "bubble" of better
  information. Weapons reach far less far than the eye, so scouts see each
  other long before contact (Part I, §Offering Battle).
  **Game:** A scenario starts with both armies encamped "just a few miles"
  apart, often on hills with low ground between them (Part I, §Offering
  Battle; Part I, fn 8).
- **Claim:** Armies do not march in fighting formation. An army that went
  straight into battle from the march would be exhausted, and it would be
  attacking a fortified camp. So armies camp and offer battle the next day
  (Part I, §Offering Battle).
  **Game:** Battle day is preceded by at least one night in camp [design].
  The Roman camp is fortified every night (Logistics II, §Supplies). Attacking
  a fortified camp is a valid but terrible option [design].
- **Claim:** Both armies are on a timer: local supplies run out, so each side
  must eventually fight or withdraw. Philippi (42) involved a month of
  offering and refusing battle (Part I, §Offering Battle). An enemy army close
  by can cut the available foraging area roughly in half. Both sides then have
  "ticking clocks" (Logistics III, §Now Add Hostile Armies).
  **Game:** There is a daily supply counter per camp, based on consumption
  (Logistics I, §Scale: 61,850 kg/day per 19,200-man army including animals).
  - **[design]:** The foraging yield is reduced by enemy proximity and by
    foraging done on earlier days.
  - **[design]:** When the counter runs low, desertion and morale loss start
    (Logistics I, §The Backpack and the Belly: underfed armies "dissolve away
    as men desert rather than starve").
- **Claim:** Foraging, watering and firewood parties are sent out daily and
  are vulnerable. Pydna began as a skirmish between watering parties
  (Part I, §Mark One; Logistics III, §Now Add Hostile Armies). Foraging
  parties need a guard large enough to defend themselves. In medieval armies
  they could be up to a third of the army (Logistics II, §Foraging the Enemy,
  citing Rogers).
  **Game:** Pre-battle days have a "camp actions" layer: send foragers or
  pickets, choose escort size, and raid enemy foragers. These clashes can
  escalate into an unplanned battle (`DOCS-design-perception.md` §4) [design].
- **Claim:** Pickets and scouts are posted to warn of an attack on the camp
  (Part I, §Offering Battle).
  **Game:** Picket placement decides how early a dawn enemy deployment becomes
  a report [design].

## 2. Offering battle (the silent negotiation)

- **Claim:** One army, or both, forms up in front of its camp: "I'm up for a
  fight if you are." Each side forms on ground that favours it and refuses
  the other's ground (Mantinea 418, Pydna 168) (Part I, §Offering Battle).
  **Game:** Each day the player chooses one of:
  - offer on own ground near camp (cautious);
  - offer in the low ground between the camps (bold);
  - stay in camp.
  The enemy AI does the same. A battle happens only if someone accepts or
  attacks.
- **Claim:** Time of day matters. A general who thinks the fight risky offers
  late, so nightfall ends any pursuit. A confident one starts at dawn
  (Part I, §Offering Battle).
  **Game:** The time of day is chosen at the council. Sunset ends pursuit,
  so rout casualties drop sharply at dusk [design].
- **Claim:** A general can read his opponent's intent from how and where the
  enemy forms up (Part I, §Offering Battle).
  **Game:** The enemy's choice of ground and time is shown only as what the
  player can see from the camp rampart or a scouting ride [design].

## 3. Deploying from camp

- **Claim:** A camp has narrow, road-width exits. Units march out in column,
  turn right or left, march to their place and face into line. This works
  when the fighting depth equals the marching width or is a multiple of it.
  Line order is set by the order units leave camp, and that order is fixed at
  the council (Part I, §So how was it done?).
  **Game:** Deployment is simulated, not placed:
  1. the player sets the exit order and the target positions;
  2. units file out, march and face.
  Mistakes at the gate (a wrong order, a jam) cost time and can put units in
  the wrong place [design].
- **Claim:** Forming even half a file of students takes several minutes.
  Forming thousands of men takes "a reasonable amount of time" only because
  of this planned system (Part I, §So how was it done?). As a scale
  reference, a 19,200-man army's marching column is ~10.65 km long, and its
  tail leaves camp about 2.5 h after its head (Logistics III, §Road Space;
  Logistics III, §Marching Speed).
  **Game [design]:** Full deployment of a 50k army takes 2-3 h of game time.
  - Options: real time, or compressed at a fixed ratio
    (`DOCS-design.md`, open question 4).
  - A side caught half-deployed is extremely vulnerable (Part I, §So how was
    it done?).
- **Claim:** Pre-battle prep sets what the army can do. Drilled "menu"
  additions must be practised in advance (Part IIIa, §Orders by the Menu). A
  pre-battle speech reaches only a few thousand men (Part II, §Signals and
  Shouting).
  **Game [design]:** Spending a camp day on drill adds one menu item. Speeches
  are given per block, so the general has to ride to each audience.

## 4. Campaign-level context (scoped out unless kuhy wants it)

These are sourced but probably out of scope for a battle simulator [design]:

- **Marching:**
  - pace 2.5-3 mph; with halts and a 6-day rest cycle, about 12.5-14.5
    miles/day for a lean army;
  - every addition (baggage, more troops, non-combatants) slows the army
    (Logistics III, §Marching Speed).
- **Splitting the army:** marching divided risks defeat in detail. Above
  ~50,000 effectives, armies were forced to split (Logistics III, §Sink or
  Swim).
- **Foraging country:** the required population density rises sharply with
  army size; armies "must swim or they will sink" (Logistics III, §Sink or
  Swim).
- **Order of march** (Logistics III, §Now Add Hostile Armies):
  - screening scouts;
  - vanguard, where the general usually rides;
  - main body with baggage in the centre;
  - rearguard;
  - flankers.
- **Camp followers:** non-combatants ran at 1:4-1:5 for Rome (Roth,
  Erdkamp). Generals expelled them as a show of good generalship, at a
  morale cost (Logistics I, §Kick Them Out!; Logistics I, §Scale).
- **Victorious wings and the camp:** a victorious wing raiding the enemy camp
  instead of turning on the centre (Antiochus at Magnesia) is a battle-level
  risk worth keeping (Part I, §So how was it done?; Part I, fn 10).

## 5. Setting notes for Cannae (sourced only)

- **Arrays:**
  - Roman cavalry on the right by the river, allied cavalry on the left,
    light troops in front (Plb. 3.113).
  - Maniples closer together and much deeper than usual (Plb. 3.113).
  - Hannibal from left to right: Spanish and Celtic horse by the river, half
    the Africans, Spanish and Celtic foot in a forward crescent, the other
    half of the Africans, Numidian horse (Plb. 3.113).
- **Hannibal's plan:** the Africans are the reserve, and the battle opens
  with the Spaniards and Celts (Plb. 3.113).
- **The cavalry fight:** on the river flank there were "none of the normal
  wheeling evolutions"; the riders dismounted and fought man to man
  (Plb. 3.115).
- **The centre:** the Celts' crescent gave way. The Romans crowded into the
  centre and were taken in both flanks by the Africans, who turned inward
  "the situation itself indicating to them how to act" (Plb. 3.115). That is
  officer initiative inside a pre-set plan (`DOCS-design-army.md` §2).
- **Commanders:** Aemilius fought first in the cavalry action, then rode to
  the centre to fight and exhort. Hannibal was in the centre from the start
  (Plb. 3.116). Both generals chose "commit yourself"
  (`DOCS-design-command.md` §4).
