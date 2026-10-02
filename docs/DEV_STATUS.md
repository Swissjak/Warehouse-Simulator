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
- Pickup uses `E`; carry intent is sent through the runtime `WarehouseShared.Remotes.CarryRequest` RemoteEvent.
- `CarryService` owns authoritative player/item hold state, validates pickup distance and eligibility, and enforces one held item per player and one holder per item.
- Held Models resolve their root from `PrimaryPart` or a direct `Body` BasePart, attach through a runtime welded `CarryAnchor`, and restore every BasePart's prior collision/massless state on drop.
- Carry cleanup releases state when the player dies, the character is removed, the player leaves, or the held item is destroyed.
- Stage 04B placement preview is complete and Studio-tested.
- While carrying, the local client hides the real held Model and displays one non-physical client-only placement ghost; other players continue to see the real server-held item.
- The placement ghost uses a prominent green/red `Highlight`, supports discrete 90-degree rotation with `R`, and accounts for Model pivot/bounding-box offset when resting on a surface.
- `E` is the primary placement confirmation and `LMB` is an alias; invalid placement sends no request and leaves the item held.
- `CarryService` independently validates placement distance, upright rotation step, horizontal support, and collidable overlap before placing the real Model and restoring its carry states.
- Stage 04C extended placement and identical-item stacking is complete and Studio-tested.
- Pickup remains limited to 8 studs, while placement uses a separate 12-stud interaction distance.
- Boxes with the same non-empty `ItemId` align and stack directly on one another; boxes with different `ItemId` values cannot form a valid stack.
- Stack height is validated against a containing Slot's `MaxHeight` attribute when available, or the configured free-world maximum height otherwise.
- Client preview and server validation share placement rules for stack alignment and height, while the server remains authoritative for the final placement decision.

## Current milestone
**Stage 04 — Interaction / Carry / Place — Complete and Studio-tested**

Stages 01A Rack Geometry, 01B Slot Registry, 01C Slot Labels / Rack Numbers, 04A Basic Interaction / Carry, 04B Placement Preview, and 04C Extended Placement / Identical Item Stacking are complete.

The completed Stage 04 behavior and boundaries are documented in `docs/stages/04-interaction-carry-placement.md`.

## Not implemented yet
- Product/box systems.
- Slot snapping, Slot occupancy, and horizontal multi-product packing.
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
5. 04B Placement Preview. **Complete.**
6. 04C Extended Placement / Identical Item Stacking. **Complete.**
7. Pallet packing.
8. TSD/scanning.
9. Receiving.
10. ITEM/FAST workflows.
11. Putaway.
12. Co-op/persistence.

## Update rule
Only mark a milestone complete after successful Roblox Studio testing.
Record what works, key decisions, limitations, and next milestone.
