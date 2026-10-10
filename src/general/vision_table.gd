class_name VisionTable
extends RefCounted
## Line-of-sight constants for the general.
##
## Source: DOCS-design.md numbers table ("See individual detail", "See
## distant wing", "Formations past 1 mile", "Dust visibility", "Horizon").

## Perception bands for later use (UI / report detail), metres.
const DETAIL_M: float = 200.0  # skin colour and kit identifiable
const OUTLINE_M: float = 300.0  # body outline only
const FORMATION_M: float = 1000.0  # formations distinguishable
const BLOB_M: float = 1600.0  # past 1 mile: "barely visible blobs"

## Beyond this nothing is visible at all, whatever the terrain [design guess]:
## past the blob band, well inside the 5.4 km geometric horizon.
const MAX_DISTANCE_M: float = 3000.0
## Full clarity up to DETAIL_M, then haze falls linearly to 0 at
## MAX_DISTANCE_M (factor ~0.5 at BLOB_M) [design guess].
const HAZE_START_M: float = DETAIL_M
## A visibility_factor below this counts as "not visible".
const VISIBLE_THRESHOLD: float = 0.1
## Woods: canopy top above ground, and the depth of forest that cuts light to
## 1/e. 30 m of trees between eye and target is already below the threshold.
const CANOPY_HEIGHT_M: float = 15.0
const WOODS_EXTINCTION_M: float = 12.0
## Woods numbers are [design guess]; not in the table.
## Dust: at density 1.0, this distance of dust cuts the view to 1/e. 120 m
## puts the VISIBLE_THRESHOLD cut-off at ln(10) * 120 = 276 m, the middle of
## the table's 150-400 m "Dust visibility inside a moving mass" [design guess].
const DUST_EXTINCTION_M: float = 120.0
## Terrain may poke this far above the sight line before it occludes, and the
## last END_CLEARANCE_M before the target are not sampled (its own ground).
const TERRAIN_TOLERANCE_M: float = 0.1
const END_CLEARANCE_M: float = 2.0
const EARTH_RADIUS_M: float = 6371000.0
