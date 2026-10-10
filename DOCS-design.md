# Legatus — design index, core loop, numbers table

Realistic ancient battle simulator. The player is the general: first person on
horseback, sees only what a mounted rider sees, moves only at horse speed,
commands only through couriers and pre-arranged signals, no minimap.
Default setting: Mid-Republic Rome vs Carthage, Cannae-like, 2 x 50k soldiers
each simulated individually.

Every mechanic in these files carries a citation. Anything not backed by a
source is marked **[design]** (my inference) or **[design guess]** (a number
with no source behind it). Treat unmarked numbers as sourced.

## Files

| File | Covers |
|---|---|
| `DOCS-design.md` | this index, sources ledger, core loop, numbers table, open questions |
| `DOCS-design-perception.md` | what the general can see, dust, scale, reports and scouts |
| `DOCS-design-command.md` | couriers, signals, plan dominance, decision points, the general's position and risk |
| `DOCS-design-army.md` | drill ("menu" of orders), officers and initiative, morale, cohesion, routs, casualties |
| `DOCS-design-prebattle.md` | camps, offering battle, deploying from camp, the supply clock |

## Sources and citation keys

Citation form is `(Part II, §Signals and Shouting)`: the post, then the
section heading exactly as it appears. Footnotes are cited as `(Part II, fn 12)`.

| Key | Source | How it was read |
|---|---|---|
| Part I | ACOUP, *Total Generalship Part I: Reports* — https://acoup.blog/2022/05/27/collections-total-generalship-commanding-pre-modern-armies-part-i-reports/ | full text and footnotes (raw HTML via curl -> pandoc) |
| Part II | *Part II: Commands* — https://acoup.blog/2022/06/03/collections-total-generalship-commanding-pre-modern-armies-part-ii-commands/ | full |
| Part IIIa | *Part IIIa: Discipline* — https://acoup.blog/2022/06/17/collections-total-generalship-commanding-pre-modern-armies-part-iiia-discipline/ | full |
| Part IIIb | *Part IIIb: Officers* — https://acoup.blog/2022/06/24/collections-total-generalship-commanding-pre-modern-armies-part-iiib-officers/ | full |
| Part IIIc | *Part IIIc: Morale and Cohesion* — https://acoup.blog/2022/07/01/collections-total-generalship-commanding-pre-modern-armies-part-iiic-morale-and-cohesion/ | full |
| Logistics I | *Logistics, How Did They Do It, Part I: The Problem* — https://acoup.blog/2022/07/15/collections-logistics-how-did-they-do-it-part-i-the-problem/ | full |
| Logistics II | *... Part II: Foraging* — https://acoup.blog/2022/07/29/collections-logistics-how-did-they-do-it-part-ii-foraging/ | **partial**: first ~600 chars of every paragraph |
| Logistics III | *... Part III: On the Move* — https://acoup.blog/2022/08/12/collections-logistics-how-did-they-do-it-part-iii-on-the-move/ | **partial**: §Road Space to the end; §A Good Road and §Carrying Capacity unread |
| Plb. | Polybius, *Histories*, Loeb tr. on LacusCurtius — https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Polybius/3*.html and .../18*.html | 3.113-117 and 18.29-30 read |

**The "bonus Part IV" does not exist under that name.** Part I (§Total
Tactics?) promises "a fourth bonus part" on the general's other duties. Part
IIIc (§Conclusion) says that topic is mostly logistics and "I'll break it out
into its own series". The ACOUP category page "Total Generalship"
(https://acoup.blog/category/collections/total-generalship/) lists the five
Total Generalship posts plus *Logistics, How Did They Do It* I-III, so those
three posts are the spun-off Part IV.

**https://acoup.blog/author/aimedtact/** is the post archive of Bret Devereaux
himself (`aimedtact` is his WordPress username), not a second author. Page 1
holds the *Teaching Paradox: Hearts of Iron IV* series, Fireside Fridays,
*Collections: Global Trade and United States Navy* and *Pre-Modern Armies for
Worldbuilders* Va/Vb. None of it is about battlefield generalship. The
*Worldbuilders* series (on how army organisation mirrors society) may help with
faction design later. It is unread.

External figures are cited by URL in the numbers table. Where a figure only
came through a search-engine summary or a secondary source, the table row says
so.

## Core loop [design, derived from the sourced constraints]

1. **Campaign eve (camp).** Reports arrive as text from scouts, deserters and
   locals. They are late, incomplete and sometimes deliberately false
   (Part I, §Reports). The supply clock is ticking for both camps
   (Part I, §Offering Battle; Logistics III, §Now Add Hostile Armies).
2. **Council of war.** The player picks a standard battle array, an order of
   march out of camp, anchors for the flanks, a reserve and pre-arranged
   contingency signals. This is where most of the decisive choices are made
   (Part I, §So how was it done?; Part II, §Towards a Model of Army Command).
3. **Deployment.** Units file out of camp in the planned order and face into
   line. This takes hours and must be committed before the enemy's array is
   visible (Part I, §So how was it done?).
4. **Battle.** The player rides, looks and sends couriers. They have a handful
   of real decision points: where to be, when to commit the reserve, and
   whether to commit themselves (Part II, §Towards a Model of Army Command).
   Units only carry out orders that are on their drilled "menu"
   (Part IIIa, §Orders by the Menu). Officers may act on their own initiative
   (Part IIIb, §Independent Command).
5. **Break and pursuit.** Units break at or before ~10% losses. Most killing
   happens in the pursuit (Part IIIc, §When Does Morale and Cohesion Fail?).
6. **After-action.** The battle is reconstructed from reports, again with no
   omniscient map [design].

The player never sees unit stats, tooltips, an overhead camera or a minimap
(Part I, §Mark One; Part I, §Total Tactics?).

## Numbers table (game constants)

Conversions (km/h to m/s, miles to km) are mine. Rows labelled [design] or
[design guess] are not sourced.

| Constant | Value | Source |
|---|---|---|
| Horse withers height (Roman military) | 1.39-1.43 m (Bökönyi 1974 avg 142.9 cm; Tác-Gorsium 139.1 cm) | secondary: https://library.hungaricana.hu/en/view/ORSZ_BPTM_Mon_2003_Forschungen/?pg=215 (via search summary, original not checked) |
| Rider eye height above ground | **2.3 m** = withers 1.4 m + ~0.9 m seated eye height | [design] derivation from the row above |
| Infantry eye height | 1.6 m | [design guess] |
| Horizon at 2.3 m eye height | 5.4 km geometric (3.57·√h); ~5.8 km refracted (~3.85·√h) | https://en.wikipedia.org/wiki/Horizon (3.57 coefficient; radar 4.12 is "7% beyond the visual" -> ~3.85) |
| Horizon, ACOUP figure | "c. 3.8 miles" (6.1 km), and only on exceptionally flat ground | (Part I, §Mark One) |
| Horse walk | 7 km/h = 1.9 m/s | https://en.wikipedia.org/wiki/Horse_gait |
| Horse trot | ~13 km/h = 3.6 m/s | https://en.wikipedia.org/wiki/Horse_gait |
| Horse canter | 16-27 km/h = 4.4-7.5 m/s | https://en.wikipedia.org/wiki/Horse_gait |
| Horse gallop | 40-48 km/h = 11-13 m/s; ACOUP uses ~40 km/h | https://en.wikipedia.org/wiki/Horse_gait; (Part II, §Signals and Shouting) |
| Sustainable gallop | 2-2.5 mi (3.2-4 km), i.e. ~4-6 min, then a walk to recover | blog-grade, via search summary, not opened: https://horserookie.com/how-long-can-a-horse-run/, https://horseracingsense.com/how-far-can-horses-run-without-stopping/ |
| Sustainable canter / trot | ~7 mi (11 km) / ~20 mi (32 km) before a rest | blog-grade, via search summary, not opened: https://horserookie.com/how-long-can-a-horse-run/, https://horseracingsense.com/how-far-can-horses-run-without-stopping/ |
| Courier speed | gallop ~40 km/h (11 m/s), then find the officer, explain, and have him signal | (Part II, §Signals and Shouting) |
| Order latency | "several minutes", like a ~5-minute input delay in a 1-2 h battle | (Part II, §Signals and Shouting) |
| Courier handoff time | 60-180 s to find the centurion/tribune and explain | [design guess] |
| Courier loss probability | 1% per km behind own lines; 15% per pass within 200 m of enemy skirmishers or cavalry; 50% for a crossing through the melee zone | [design guess]; a messenger can be killed (Part II, §Signals and Shouting); a game that models it (Part II, fn 12) |
| Order ignored (junior courier, no token) | 10-25% depending on officer seniority gap | [design guess]; rank-respect problem (Part II, §Signals and Shouting) |
| Relay riders (operational, not tactical) | >100 miles/day (>160 km/day) on pre-set routes with fresh horses | (Part I, §Reports) |
| Reports through merchants / rumour | about the speed of an army on the march; often days to weeks old | (Part I, §Reports) |
| Voice reach of a speech | "a few thousand" listeners if compact and quiet; none once moving | (Part II, §Signals and Shouting; Part II, fn 10) |
| Weapon ranges | effective <100 m; maximum "a few hundred meters" | (Part I, §Mark One) |
| See individual detail | 100 m all detail; 200 m skin colour and kit identifiable; 300 m body outline only; 500 m body tapers, head indistinct | FM 21-75 (1984) ch. 4 and USMC 0300-M16-1008, **snippet-level only**: https://digital.jmpublishing.ie/i/426395/28, https://www.trngcmd.marines.mil/Portals/207/Docs/wtbn/MPMS/0300-M16-1008_DEMONSTRATE_UNKNOWN_DISTANCE_THREAT_ENGAGEMENT_SKILLS_DAY.pdf |
| See formation state | ~550 m: the gleam of shields being readied is visible, the unit's identity is not | (Part I, §Mark One) |
| See distant wing | ~1+ km over a crest: only the glint of helmets that "it is still there"; perhaps elephants | (Part I, §Mark One) |
| Formations past 1 mile | "barely visible blobs" | (Part I, §Mark One) |
| Dust visibility inside a moving mass | 150-400 m, scaling with the number of feet and hooves moving and with wind | [design guess]; dust as a factor (Part I, §Seeing the Battle) |
| Roman legionary frontage | reading A 0.9 m (3 ft); reading B 1.8 m (3 ft man + ≥3 ft clearance). **Default 1.8 m in open order, 0.9 m when closed up** | Plb. 18.30.6-8; the choice is [design] |
| Roman file depth (rank spacing) | ≥3 ft (0.9 m) front and back, i.e. 0.9-1.8 m per rank | Plb. 18.30.8 |
| Roman standard file | 6 men deep | (Part IIIb, §How Much Officer Do You Need?) |
| Cannae Roman depth | maniples closer than usual, "depth of each many times exceed its front" -> 6 deep x ~4-6 = 24-36 [design] | Plb. 3.113 |
| Phalangite / Libyan / hoplite frontage | 0.9 m (phalanx); hoplites ~1 m tight to ~2 m loose | Plb. 18.29.2; (Part I, §Mark One; Part I, fn 14 "very speculative") |
| Libyans at Cannae | armed in the Roman fashion -> use Roman spacing [design] | Plb. 3.114 |
| Gauls / Spaniards frontage | 1.5 m/man, 8-12 deep | [design guess]; alternating companies, the Gallic sword needs "a long sweep" (Plb. 3.114); "deployed in a thin line" (Plb. 3.115) |
| Cavalry frontage / depth per horse | ~1 yd (0.9 m) front x 3 yd (2.75 m) deep (column figure) | (Logistics III, §Road Space), citing Lockwood 1895 |
| Maniple / century / cohort / legion | 120 (triarii 60) / 60 / 480 / 4,200 foot + 300 horse; ACOUP Part I rounds a legion to 4,800 | (Part IIIa, §The Limits of the Possible with Synchronized Discipline; Part IIIb, §How Much Officer Do You Need?; Logistics I, fn 8; Part I, §Mark One) |
| Consular army | 2 legions + 2 allied alae ≈ 19,200 (16,800 foot, 2,400 horse) | (Logistics I, §Scale; Part I, §Mark One) |
| Cannae strengths (Polybius) | Rome ~80,000 foot + >6,000 horse; Carthage ~40,000 foot + ~10,000 horse | Plb. 3.113-114 |
| Battle line length, examples | Pydna ~2.5 km wide; Marathon (10k hoplites) 1.5-3 km; Punic line at Cannae ~1.5 km | (Part I, §Mark One); Lazenby 1998 via https://journals.pan.pl//Content/130738/PDF/04_Mahaney-1.pdf |
| Cannae-scale line, this game | frontage = heavy foot / depth x spacing; 40k / 24 deep x 0.9-1.8 m = **1.5-3.0 km** of heavy infantry plus the cavalry wings | [design] formula from the rows above |
| Casualties, hoplite battles (killed) | winners 5%, losers 14%; rarely >20% | Krentz 1985 via (Part IIIc, §When Does Morale and Cohesion Fail?) |
| Casualties, Roman battles 200-168 BC | winners 4.2%, losers 16% | Rosenstein 2004 via (Part IIIc, §When Does Morale and Cohesion Fail?) |
| Break threshold | "at or before 10% losses", sometimes far earlier; also before contact | (Part IIIc, §When Does Morale and Cohesion Fail?) |
| Cannae (outlier: no retreat) | Rome ~70,000 dead of ~86,000 (Polybius) / 48,200 (Livy); Carthage 5,700 (4,000 Celts, 1,500 Spaniards and Africans, 200 horse) | Plb. 3.117; https://en.wikipedia.org/wiki/Battle_of_Cannae |
| Battle duration | Pydna decided in ~1 hour; the shock phase is short | (Part II, §Signals and Shouting) |
| Two-on-one melee | "end in seconds and are very lopsided" | (Part IIIa, §All Together Now) |
| Officer : soldier ratio | Roman ~1:5.5; Macedonian syntagma 1:2.2; Spartan mora ~1:19 | (Part IIIb, §How Much Officer Do You Need?) |
| Smallest unit with initiative | Roman maniple (120) / century (60); Macedonian taxis (~1,500) | (Part IIIb, §Independent Command) |
| Infantry march pace | 88-110 steps/min, 2.5-3 mph (1.1-1.3 m/s); averages 2.25-2.5 mph with halts | (Logistics III, §Marching Speed) |
| Marching column | 6 abreast, 1.25 m road per rank; a 19,200-man army is ~10.65 km long and takes ~2.5 h to clear camp | (Logistics III, §Road Space; §Marching Speed) |
| Daily food for a 19,200-man army | 61,850 kg (people + animals) | (Logistics I, §Scale) |
| Camps before battle | "just a few miles" apart; days to a month | (Part I, §Offering Battle) |
| Infantry charge speed | 2.5-3.5 m/s for the last 20-40 m | [design guess] |

## Open questions for kuhy

1. **Symmetric or historical Cannae?** Polybius gives Rome ~86k (6k horse) and
   Carthage ~50k (10k horse) (Plb. 3.113-114). "2 x 50k" erases that asymmetry.
   Keep 50k vs 50k, use the real ratio scaled to 100k total, or make it a
   scenario option?
2. **Which side does the player command?** Hannibal's plan needed a correct
   guess about Rome's (Part I, §Seeing the Battle). As Varro the player loses
   by design. Pick Carthage, Rome, or either?
3. **How much campaign phase?** Scouting, camps and offering battle over
   several days (`DOCS-design-prebattle.md`), or start at dawn on battle day
   with a reports dossier?
4. **Time scale.** Real time (~1 h of contact plus hours of deployment), or
   time compression while riding and waiting? If compressed, do couriers
   compress too?
5. **Can the general die or be captured?** Paullus died at Cannae (Plb. 3.116).
   Is that a game-over, or does the army fight on from the plan?
6. **Roman frontage reading.** Default is 1.8 m open and 0.9 m closed
   (Plb. 18.30). It changes the line length by 2x. Confirm.
7. **Loss/disobedience rates** for couriers are pure guesses. Tune them by
   playtest, or keep them fixed for realism?
8. **Text reports or voiced couriers?** Arriving reports as text, or as spoken
   lines (cf. *Radio Commander*, Part I, §Reports)?
