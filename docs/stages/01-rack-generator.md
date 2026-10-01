# Stage 01 — Rack Generator

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
5 floors.
3 `PalletSlot` positions per floor.
`SlotType="Pallet"`
`MaxHeight=8`

## RackV2L / RackV2R
Floors 1–2:
- 3 normal `Slot` positions;
- no pallet;
- `SlotType="Box"`
- `MaxHeight=3`

Floors 3–5:
- 3 `PalletSlot` positions;
- `SlotType="Pallet"`
- `MaxHeight=8`

## Sticker references
Template Sticker objects are positional references only.
Generated identity comes from RackId + Bay + Floor + Slot.
Visible sticker text eventually equals generated SlotId.
Barcode may be generic/shared.
Do not implement OCR/barcode recognition.

## RackNumberPlate
Rack-number display is deferred to Stage 01C. Stage 01A does not generate or place RackNumberPlate objects.

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

1. Traverse generated floors and slots.
2. Generate SlotId `Rack-Bay-Floor-Slot`.
3. Preserve SlotType.
4. Preserve MaxHeight.
5. Inherit StorageCategory from RackZone.
6. Store metadata in a clean server-authoritative representation.

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
- V2 floors 3–5 Pallet;
- category propagates.

# 01C — Labels and number plate

1. Create/update visible location text at Sticker references.
2. Text equals SlotId.
3. Keep generic barcode if present.
4. Add machine-readable SlotId metadata to label/scan target.
5. Display RackId on RackNumberPlate.
6. Avoid duplicate rack-number plates from section cloning.

Acceptance:
- sticker text matches physical slot;
- RackNumberPlate is correct;
- rotated racks keep readable/correct labels;
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
