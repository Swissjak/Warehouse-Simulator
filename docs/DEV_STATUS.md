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
- RackZone attributes for generation are `RackId`, `RackType`, `RackSide`, and `StorageCategory`.
- Rack sections are 20 studs long; Bay numbering starts at the RackZone endpoint nearest `Vector3.zero`.
- The generator clones complete authored L/R prefabs without runtime mirroring or terminal-frame generation.

## Current milestone
**Stage 01 — Rack Generator**

Spec: `docs/stages/01-rack-generator.md`

Stage 01A is complete. The next milestone is Stage 01B — Slot/address registry.

## Not implemented yet
- Slot registry.
- Generated sticker/address text.
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
2. 01B Slot/address registry.
3. 01C Labels and RackNumberPlate.
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
