# Warehouse Simulator — Development Status
Last updated: 2026-10-01

## Completed / prepared
- Initial warehouse blockout exists in Roblox Studio.
- Authored rack section templates exist: `RackV1L`, `RackV1R`, `RackV2L`, `RackV2R`.
- Multiple RackZone parts are placed for testing (about 10 zones).
- Rack storage conventions are defined.
- Rojo is installed and `rojo serve` works.
- Partial-Rojo approach is used: code is synchronized; warehouse world geometry remains Studio-authored.
- Stage 01A rack geometry generation is complete and Studio-tested.
- Stage 01B slot/address registry is complete and Studio-tested.
- Stage 01C.1 visible slot address labels are complete and Studio-tested on `RackV1L`, `RackV1R`, `RackV2L`, and `RackV2R`.
- RackZone attributes for generation are `RackId`, `RackType`, `RackSide`, and `StorageCategory`.
- Rack sections are 20 studs long; Bay numbering starts at the RackZone endpoint nearest `Vector3.zero`.
- The generator clones complete authored L/R prefabs without runtime mirroring or terminal-frame generation.
- Generated Sticker parts receive machine-readable `SlotId` attributes and idempotent runtime `SurfaceGui`/`TextLabel` address displays.

## Current milestone
**Stage 01 — Rack Generator**

Spec: `docs/stages/01-rack-generator.md`

Stages 01A, 01B, and 01C.1 are complete. The next microstage is Stage 01C.2 — Rack Number Plates.

## Not implemented yet
- Rack Number Plates.
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
1. 01A Rack geometry generation. **Complete.**
2. 01B Slot/address registry. **Complete.**
3. 01C.1 Visible Slot Addresses. **Complete.**
4. 01C.2 Rack Number Plates.
5. Interaction / carry / place.
6. Pallet packing.
7. TSD/scanning.
8. Receiving.
9. ITEM/FAST workflows.
10. Putaway.
11. Co-op/persistence.

## Update rule
Only mark a milestone complete after successful Roblox Studio testing.
Record what works, key decisions, limitations, and next milestone.
