# Warehouse Simulator — Development Status
Last updated: 2026-10-02

## Completed / prepared
- Initial warehouse blockout exists in Roblox Studio.
- Authored rack section templates exist: `RackV1L`, `RackV1R`, `RackV2L`, `RackV2R`.
- Multiple RackZone parts are placed for testing (about 10 zones).
- Rack storage conventions are defined.
- Rojo is installed and `rojo serve` works.
- Partial-Rojo approach is used: code is synchronized; warehouse world geometry remains Studio-authored.
- Stage 01A rack geometry generation is complete and Studio-tested.
- Stage 01B slot/address registry is complete and Studio-tested.
- Stage 01C slot labels and rack numbers are complete and Studio-tested on `RackV1L`, `RackV1R`, `RackV2L`, and `RackV2R`.
- RackZone attributes for generation are `RackId`, `RackType`, `RackSide`, and `StorageCategory`.
- Rack sections are 20 studs long; Bay numbering starts at the RackZone endpoint nearest `Vector3.zero`.
- The generator clones complete authored L/R prefabs without runtime mirroring or terminal-frame generation.
- Generated Sticker parts receive machine-readable `SlotId` attributes and idempotent runtime `SurfaceGui`/`TextLabel` address displays.
- Every generated rack receives exactly two idempotent `NumberPlate` clones, sourced from `ServerStorage.RackAssets.NumberPlate`, positioned at the two `RackZone` endpoints and displaying only `RackId`.

## Current milestone
**Stage 01 — Rack Generator — Complete and Studio-tested**

Spec: `docs/stages/01-rack-generator.md`

Stages 01A Rack Geometry, 01B Slot Registry, and 01C Slot Labels / Rack Numbers are complete.

## Not implemented yet
- Product/box systems.
- Pallet packing.
- TSD/scanning.
- Receiving.
- ITEM/FAST runtime logic.
- Putaway.
- FAST delivery.
- Co-op ownership.
- Persistence/economy/progression.

## Intended order
1. 01A Rack Geometry. **Complete.**
2. 01B Slot Registry. **Complete.**
3. 01C Slot Labels / Rack Numbers. **Complete.**
4. Interaction / carry / place.
5. Pallet packing.
6. TSD/scanning.
7. Receiving.
8. ITEM/FAST workflows.
9. Putaway.
10. Co-op/persistence.

## Update rule
Only mark a milestone complete after successful Roblox Studio testing.
Record what works, key decisions, limitations, and next milestone.
