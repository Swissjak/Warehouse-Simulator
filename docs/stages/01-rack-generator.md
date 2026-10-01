# Stage 01 — Rack Generator

**Status: Complete and Studio-tested.**

## Goal
Generate rack geometry and deterministic storage addresses from manually placed RackZone parts and Studio-authored rack templates.

This stage does NOT implement products, TSD, receiving, putaway, inventory, economy, or persistence.

## Studio inputs

### Rack zones
Expected path:
`Workspace.Warehouse.RackZones`

Each RackZone is one `BasePart` representing one one-sided rack.

Required attributes:
- `RackId` Number
- `RackType` String: `V1` or `V2`
- `RackSide` String: `L` or `R`
- `StorageCategory` String

One zone uses one rack type only.

### Rack templates
Expected path:
`ServerStorage.RackTemplates`

Templates:
- `RackV1L`
- `RackV1R`
- `RackV2L`
- `RackV2R`

Each template is a complete authored physical section. The generator selects it from
`RackType + RackSide`, clones the whole Model, and does not modify its descendants.

Template mapping:
- `V1 + L` → `RackV1L`
- `V1 + R` → `RackV1R`
- `V2 + L` → `RackV2L`
- `V2 + R` → `RackV2R`

Authoritative section length: **20 studs**.

Each floor has 3 storage positions and 3 matching Sticker placement references.

## Address format
`Rack-Bay-Floor-Slot`

Example: `3-12-4-2`

IDs must be deterministic.

## Bay direction
Bay 1 begins at the end of RackZone closest to `Vector3.zero`.

RackZone `Size.X` and local X define the rack length and axis. Calculate both local-X endpoints with the RackZone CFrame and choose the endpoint with the smaller world-space distance to origin as the start.

Must work for X, Z, 180-degree, and arbitrary horizontal rotations.

## Section count
`SectionCount = floor(zoneLength / 20)`

Ignore leftover partial length.

Examples:
- 400 → 20
- 205 → 10
- 387 → 19

## RackV1L / RackV1R
Floors are discovered dynamically from direct `Floor<number>` children.
Each discovered floor contains 3 `PalletSlot` positions.
`SlotType="Pallet"`
`MaxHeight=8`

## RackV2L / RackV2R
Floors 1–2:
- 3 normal `Slot` positions;
- no pallet;
- `SlotType="Box"`
- `MaxHeight=3`

Floor 3 and higher:
- 3 `PalletSlot` positions;
- `SlotType="Pallet"`
- `MaxHeight=8`

The registry does not assume a fixed floor count. Floors and slots are sorted by their numeric suffixes rather than `GetChildren()` order.

## Sticker references
Template Sticker objects are positional references only.
Generated identity comes from RackId + Bay + Floor + Slot.
Visible sticker text eventually equals generated SlotId.
Barcode may be generic/shared.
Do not implement OCR/barcode recognition.

## RackNumberPlate
Stage 01A does not generate or place RackNumberPlate objects. Stage 01C.2 creates them from the authored `ServerStorage.RackAssets.NumberPlate` source without modifying rack prefab geometry.

# 01A — Geometry Generator

**Status: Complete and Studio-tested.**

Implement only:
1. Discover RackZones.
2. Validate required attributes.
3. Resolve the authored V1/V2 and L/R template variant.
4. Determine zone long axis and length.
5. Determine start endpoint by origin distance.
6. Compute section count.
7. Clone correct template.
8. Place consecutive sections every 20 studs.
9. Match RackZone horizontal orientation.
10. Parent generated geometry into a predictable generated container.

Do NOT implement downstream warehouse systems.

Generated hierarchy:
```text
Rack_<RackId>
├─ Bay_001
├─ Bay_002
└─ ...
```

Each Bay is an unchanged clone of its selected authored prefab. Stage 01A performs no runtime mirroring, auto-flip, TerminalFrame generation, terminal geometry assembly, or per-descendant geometry transforms.

### Important placement rule
Confirmed authored conventions:
- every prefab Model pivot is the bottom-center of one 20-stud section;
- template local `+Z` is the section axis;
- template local `+X` is the front side;
- one constant `+90°` yaw offset maps the template axes to RackZone local axes;
- RackZone rotation controls the orientation of the complete cloned prefab.

### 01A acceptance tests
With about 10 test RackZones:
- all valid zones generate;
- V1/V2 and L/R select the correct one of the four authored prefabs;
- count matches floor(length/20);
- sections align with no cumulative drift;
- rotated zones work;
- Bay direction begins at endpoint closer to world origin;
- invalid zones warn without crashing everything;
- repeated initialization does not create uncontrolled duplicates.

Only after this passes, start 01B.

# 01B — Slot Registry

**Status: Complete and Studio-tested.**

1. Traverse direct generated floors and slots by validated numeric names.
2. Generate SlotId `Rack-Bay-Floor-Slot`.
3. Preserve SlotType.
4. Preserve MaxHeight.
5. Inherit StorageCategory from RackZone.
6. Store metadata in the server-authoritative `SlotRegistry` runtime representation.
7. Apply `SlotId`, address components, storage semantics, and category attributes to each existing generated Slot instance.
8. Rebuild after rack generation so stale references are discarded.

Example:
- SlotId `1-7-2-3`
- RackId 1
- Bay 7
- Floor 2
- Slot 3
- RackType V2
- SlotType Box
- MaxHeight 3
- StorageCategory Tech

Do not implement occupancy/products yet.

Acceptance:
- correct count;
- unique IDs;
- stable IDs;
- V1 only Pallet;
- V2 floors 1–2 Box;
- V2 floor 3 and higher Pallet;
- category propagates.

# 01C — Labels and number plate

**Status: Complete and Studio-tested.**

## 01C.1 — Visible Slot Addresses

`RackLabelService.ApplyAll()` runs after `SlotRegistry.Rebuild()`.

1. Match each `Slot<number>` only to the direct sibling `Sticker<number>` with the same numeric suffix.
2. Add machine-readable `SlotId` metadata to the Sticker.
3. Create or reuse `SlotSurfaceGui/SlotText` and display only the SlotId.
4. Use the explicit authored L/R face mapping and rotate only the text for horizontal floor labels.
5. Do not use world distance, child order, OCR, or barcode recognition.

## 01C.2 — Rack Number Plates

`RackNumberService.ApplyAll()` runs after rack generation.

1. Clone the authored `ServerStorage.RackAssets.NumberPlate` Part as the only visual template.
2. Maintain exactly two service-managed plates under `Rack_<RackId>/NumberPlates/Start` and `End`.
3. Place them from the two physical local-X endpoints of the matching RackZone, centered laterally at a center height of 14.04 studs with the authored 0.24-stud inset.
4. Orient the two Parts outward in opposite directions without changing rack or prefab geometry.
5. Create or reuse `RackNumberSurfaceGui/RackNumberText` and display only RackId.
6. Apply `RackId` and `RackEnd` metadata and remain idempotent on repeated calls.

Acceptance:
- Sticker text matches the physical Slot on all four authored prefab variants;
- L/R face mapping and horizontal floor-label text rotation are readable from the aisle;
- exactly two outward-facing Rack Number Plates display the correct RackId on each generated rack;
- rotated racks keep readable and correctly placed labels;
- repeated application creates no duplicate UI or plates;
- no duplicate SlotIds.

## Error handling
Warn with useful context for:
- missing RackId;
- unsupported RackType;
- missing or unsupported RackSide;
- missing template;
- missing Floor;
- missing Slot/Sticker;
- duplicate RackId;
- invalid/zero-length RackZone.

One broken zone should not stop valid zones where reasonably possible.

## Codex workflow
Before coding 01A:
1. Read `AGENTS.md`.
2. Read `docs/GDD.md`.
3. Read `docs/DEV_STATUS.md`.
4. Read this file.
5. Inspect repository.
6. Give concise implementation plan.
7. Explicitly mention pivot/origin assumptions.
8. Do not write code until the plan is accepted.

After implementation, provide a Roblox Studio manual test checklist.
