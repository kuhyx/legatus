# Legatus design — commands, couriers, signals, the general's position

Index and numbers table: `DOCS-design.md`. Format for each entry: the
**historical claim**, then what it means **in the game**. **[design]** marks
my inference. Lines without that mark are sourced.

## 1. The plan dominates; the battle is mostly not steerable

- **Claim:** Battle plans were drawn up in a council of war the evening before
  (sometimes in the early morning). The consilium was more a consensus-building
  tool than a debate (Part I, §So how was it done?).
  **Game:** The council of war is the main planning screen. The player assigns
  each formation block:
  - its position and a short written intent ("hold the river flank", "push the
    centre");
  - pre-arranged conditional signals [design].
  Subordinates leave the council knowing only what was said there.
- **Claim:** Because forming up takes so long, the array has to be chosen
  blind to the enemy's. Armies therefore used standard, "safe" arrays: heavy
  infantry in the centre, lighter and more mobile troops on the wings, flanks
  anchored on rivers, marsh, hills or woods (Part I, §So how was it done?).
  **Game:** The array templates are the historical ones (Roman triplex acies;
  Hannibal's line). A free-form layout is allowed, but each departure from the
  template costs deployment time and increases the chance of confusion
  [design].
- **Claim:** Guessing the enemy's array is possible but it is a gamble. At
  Magnesia (190) Scipio guessed the river flank was safe and was wrong
  (Part I, §So how was it done?). Hannibal at Cannae and Epaminondas at Leuctra
  guessed right (Part I, §Seeing the Battle).
  **Game:** The enemy AI also deploys blind, from its own templates and from
  reports about the player.
- **Claim:** By the time Aemilius could see the enemy's array at Pydna, it was
  too late to change his own formation; "he is already committed to fight with
  the plan he has" (Part I, §Seeing the Battle).
  **Game:** After deployment begins, there is no way to reassign
  left-to-right order. "It would take far too long to shuffle the right-to-left
  order of the line" (Part II, §Signals and Shouting).
- **Claim:** The general has only a handful of decision points (Part II,
  §Towards a Model of Army Command):
  1. the plan;
  2. where to be;
  3. when and where to commit the reserve;
  4. whether and where to commit himself.
  "Beyond these basic decisions the general is mostly stuck hoping"
  (Part II, §Towards a Model of Army Command).
  **Game:** These four are the core verbs. Everything else goes through
  couriers to unengaged units, and engaged units are nearly unreachable (§3).

## 2. Signals: the limited vocabulary

- **Claim:** Waving hands or small flags behind the army does not work,
  because the soldiers face forward. Signal flags are operational
  (station-to-station) tools, not tactical ones (Part II, §Signals and
  Shouting).
  **Game:** No flag or hand-signal orders to the army.
- **Claim:** Unit standards (signa; vexilla for detachments) stand at the front
  centre of a unit. The men follow the standard they can see, and that lets
  the officer "drive" the unit (Part II, §Signals and Shouting). Wheeling is
  done by "turning the standards", conversa signa (Part IIIb, fn 8).
  **Game:** A unit's facing and movement are anchored to its standard-bearer
  entity. If the standard falls or is taken, the unit loses its steering and
  takes a cohesion hit [design].
- **Claim:** Roman horn calls (Vegetius 2.22, with caveats, Part II, fn 11)
  (Part II, §Signals and Shouting):
  - tubicen: charge and retreat;
  - cornicen: movement of the signa (advance, halt);
  - buccina: camp signals.
  The whole set is a few prearranged calls: advance, halt, charge, retreat,
  assemble, change watch.
  **Game:** Calls are local to each unit's own musicians. The general cannot
  sound "charge" for the whole army from his horse. An order reaches a unit by
  courier, and that unit's officer then has the call sounded. **[design]:**
  - Each call is a positional sound with ~300-500 m of audibility in battle
    noise [design guess].
  - Adjacent units can mistake a neighbour's call for their own
    [design guess: 5%].
- **Claim:** Shouting reaches a few thousand people at most, and only when
  they are compact and quiet. That works for a pre-battle speech, not for an
  army in motion (Part II, §Signals and Shouting; Part II, fn 10).
  **Game:** A pre-battle speech is a morale action limited to the units within
  earshot [design: ~2-4k men]. In battle the general's voice reaches only his
  escort and the nearest unit [design guess: ~30-50 m].

## 3. Couriers: "man on horse"

- **Claim:** An order travels by man on horse: a dedicated messenger, a
  subordinate officer, or the general himself (Part II, §Signals and
  Shouting).
  **Game:** The general keeps a pool of couriers (escort riders,
  contubernales, tribunes) [design: 6-10]. They are physically simulated riders
  who must path across the field.
- **Claim:** Sending a junior risks the unit commander not respecting or
  obeying him. Written orders help, if anyone can read them. Going in person
  removes the general from everywhere else (Part II, §Signals and Shouting).
  **Game:** Each order has a weight:
  - who carries it: a junior rider, a tribune, or the general in person;
  - whether it carries a token or a written tablet [design].
  The weight sets the chance it is ignored or diluted (numbers table,
  [design guess]).
- **Claim:** Couriers and generals in transit can be killed, and then the
  order simply never arrives (Part II, §Signals and Shouting). *Take Command*
  models this: when a messenger is shot, you send another (Part II, fn 12).
  **Game:** Couriers are real entities that can be hit by missiles and
  intercepted by cavalry. The player is not told that an order failed. They
  find out by watching, or when no acknowledgement comes back [design].
- **Claim:** At ~40 km/h an order takes several minutes to arrive. Then the
  messenger must find the centurion and explain, and the centurion must signal
  through instruments and standards with their few prearranged calls. Anything
  complex is shouted down the line (Part II, §Signals and Shouting).
  **Game:** Order latency is the sum of:
  - ride time (pathing, gallop budget);
  - finding and explaining [design guess: 60-180 s];
  - signal execution (unit reaction, §DOCS-design-army 1).
- **Claim:** A complex order to an engaged unit means first signalling retreat
  and then regrouping it. Regrouping a retreating unit "is rarely performed
  successfully in an unplanned fashion" (Part II, §Signals and Shouting). A
  unit taking sword strikes is beyond command "except for 'retreat!'"
  (Part II, §Different Sorts of Generals).
  **Game:** Engaged units accept only `hold` (implicit) and `retreat`. A
  retreat may turn into a rout (morale roll; `DOCS-design-army.md`).
- **Claim:** That is why reserves matter. Unengaged units can be re-tasked
  easily, and the Roman three lines are a reserve-heavy system built to
  retreat the hastati through the principes (Part II, §Signals and Shouting).
  Caesar can send only the reserves he has, and loses control of a cohort the
  moment it engages (Part II, §The Battle Manager).
  **Game:** Unengaged blocks are the only ones that take complex orders. Once
  a reserve is sent in, it leaves the player's control.

## 4. Where is the general? Leadership vs command

- **Claim:** Battles are won by making the enemy run, so morale is the
  critical factor. Soldiers cannot judge the plan, so they judge whether the
  general looks like their culture's idea of a good general, and that requires
  being conspicuous (Part II, §Performing Generalship).
  **Game:** The general is a morale source only where he can actually be
  seen: line of sight from soldiers' eyes, with distance falloff using the
  perception tiers. Proximity alone is not an aura, because "generals do not
  radiate a warm aura of comfort" (Part II, §Being Seen).
- **Claim:** Generals are marked to be recognisable:
  - crests;
  - archaic muscle cuirass and Attic helmet for Roman generals;
  - Caesar's red cloak.
  (Part II, §Being Seen; Part II, §The Battle Manager)
  **Game:** The player wears the paludamentum. Its visibility is what produces
  the morale effect, so the player can choose to stand out [design].
- **Claim:** There is a spectrum of styles (Part II, §Different Sorts of
  Generals; Part II, §The Battle Manager):
  - warrior-hero, at the front: seen, but unable to command once engaged;
  - pure commander, at the rear: commands, but is not seen; rare before
    gunpowder;
  - "battle manager" in between: the Alexander model rides with a striking
    force, the Caesar model moves around or watches from good ground.
  **Game:** No style is forced; it emerges from where the player rides.
  Roman culture expects a Caesar-like manager who commits himself only when
  things are critical (Part II, §The Battle Manager).
- **Claim:** The general's control over the unit he is with is much higher
  than anywhere else (Part II, §Towards a Model of Army Command). Aemilius
  "drove" Legio I at Pydna, and later released his centurions to fight
  independently (Part I, §Seeing the Battle; Part IIIb, §Independent Command).
  **Game:** The unit the general is attached to receives voice orders with no
  courier delay, and can take finer orders [design].
- **Claim:** Committing himself produces local morale effects but takes him
  out of the rest of the battle. Caesar engages only once all his reserves are
  gone (Part II, §Towards a Model of Army Command). Caesar went to the critical
  point at Alesia "so that he might get into the middle of the combat"
  (Part II, fn 14).
  **Game:** A "commit yourself" action gives a big local morale boost.
  - **[design]:** While committed, the courier pool cannot be used.
  - **[design]:** Risk of the general being wounded scales with time in
    contact.
- **Claim:** A general's death, or a rumour of it, can collapse an army.
  This happens when the general is "the cause", as with Cyrus at Cunaxa. At
  Hastings William rode bareheaded to show he was alive (Part IIIc, §Complex
  Outcomes). Paullus died fighting in the centre at Cannae (Plb. 3.116).
  **Game:**
  - A "general dead" rumour can spread through units that lose sight of him.
  - Showing your face cancels the rumour locally.
  - **[design]:** For a consul (not "the cause") death is a large morale shock
    but not a collapse.
  - **[design]:** The player's death ends player control: the army fights on
    from the plan, and the after-action report shows the outcome.
- **Claim:** Soldiers sometimes refuse to let a general expose himself. Lee's
  men at the Wilderness would not advance until he withdrew (Part II,
  §Different Sorts of Generals).
  **[design]:** Out of scope for Romans; noted for completeness.
