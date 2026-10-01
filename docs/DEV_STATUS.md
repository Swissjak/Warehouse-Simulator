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
- Stage 04A basic interaction/carry is complete and Studio-tested with the authored `Workspace.Warehouse.TestItems.TestBox`.
- The client performs center-camera targeting up to 8 studs, ignores the local character, and shows one runtime-only `Highlight` for a valid carryable Model.
- Pickup and drop use `E`; the client sends only `Pickup(item)` or `Drop()` intent through the runtime `WarehouseShared.Remotes.CarryRequest` RemoteEvent.
- `CarryService` owns authoritative player/item hold state, validates pickup distance and eligibility, and enforces one held item per player and one holder per item.
- Held Models resolve their root from `PrimaryPart` or a direct `Body` BasePart, attach through a runtime welded `CarryAnchor`, and restore every BasePart's prior collision/massless state on drop.
- Carry cleanup releases state when the player dies, the character is removed, the player leaves, or the held item is destroyed.

## Current milestone
**Stage 04A — Basic Interaction / Carry — Complete and Studio-tested**

Stages 01A Rack Geometry, 01B Slot Registry, 01C Slot Labels / Rack Numbers, and 04A Basic Interaction / Carry are complete.

## Not implemented yet
- Product/box systems.
- Placement ghost, rotation, placement confirmation, snapping, and slot placement.
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
4. 04A Basic Interaction / Carry. **Complete.**
5. Interaction placement.
6. Pallet packing.
7. TSD/scanning.
8. Receiving.
9. ITEM/FAST workflows.
10. Putaway.
11. Co-op/persistence.

## Update rule
Only mark a milestone complete after successful Roblox Studio testing.
Record what works, key decisions, limitations, and next milestone.
