class_name RiderMotionTable
extends RefCounted
## Constants for what the rider feels and sees of the horse's movement: the
## horse's head nod, the rider's torso rocking, the lean into turns and how
## fast all of it blends across a gait change. Every row here is [design
## guess] (DOCS-design.md numbers table, "Rider sway" / "Horse head nod" /
## "Lean into turns"). Arrays are indexed by gait (GaitTable.HALT..GALLOP);
## the rate of each motion comes from the shared stride clock
## (GaitTable.STRIDE_HZ x BOUNCES_PER_STRIDE), so it stays on the hoof beats.

## Horse head + neck nod, degrees (head down), per gait. Walk, canter and
## gallop swing the head with every forelimb stride; the trot carries it
## nearly still.
const NOD_DEG: Array[float] = [0.0, 4.0, 0.6, 6.0, 7.0]
## Where in each bounce the head is lowest, as a fraction of the bounce.
const NOD_PHASE: Array[float] = [0.0, 0.25, 0.25, 0.1, 0.1]

## Rider torso rocking about the seat, degrees. Pitch runs at the bounce
## rate (forward-back), roll at one cycle per stride (side to side).
const SWAY_PITCH_DEG: Array[float] = [0.0, 0.7, 0.5, 1.8, 1.4]
const SWAY_ROLL_DEG: Array[float] = [0.0, 0.9, 0.4, 0.6, 0.5]
## Seat (hip) to eye, metres: the torso rocks about a pivot this far below.
const TORSO_M: float = 0.8
## The spine (and the neck the head turns on) is this far behind the eyes,
## so turning the head swings the eyes about it.
const SPINE_BEHIND_EYES_M: float = 0.08
## Share of the head turn the torso takes (the rest is the neck), and share
## of the torso twist the rein hands follow.
const TORSO_TWIST_SHARE: float = 0.3
const HAND_TWIST_SHARE: float = 0.5

## Share of the bob the whole horse + rider rig takes; the rest is the rider
## bouncing in the saddle, so the horse's head moves a little in view.
const BODY_BOB_SHARE: float = 0.75

## Lean into a turn: this share of the bank angle atan(v * w / g) a horse
## really takes, capped, then smoothed with LEAN_TIME_S.
const LEAN_SHARE: float = 0.35
const LEAN_MAX_DEG: float = 8.0
const LEAN_TIME_S: float = 0.3

## Time constant (s) of the cross-fade between gaits' motion patterns: the
## trot -> canter change halves the bounces per stride, which would
## otherwise snap the camera.
const BLEND_TIME_S: float = 0.35

## Hands follow the bit: metres forward per radian of nod.
const HAND_FOLLOW_M_PER_RAD: float = 0.6
## Tail swing per stride (deg) and lift towards horizontal at a gallop (deg).
const TAIL_SWING_DEG: float = 9.0
const TAIL_LIFT_DEG: float = 35.0
## Mane flutter (deg) at full speed share, ear twitch (deg).
const MANE_SWAY_DEG: float = 12.0
const EAR_TWITCH_DEG: float = 12.0
