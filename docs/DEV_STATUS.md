# Warehouse Simulator — Development Status
Last updated: 2026-10-03

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
- Stage 05A pallet detection and single-box snap is complete and Studio-tested with the authored `Workspace.Warehouse.TestItems.TestPallet`.
- A valid packing pallet is resolved through `PackingEnabled`, its direct `LoadArea`, and positive `MaxHeight`; pallet names and `Base.Size` are not packing inputs.
- While aiming at a valid empty pallet, the existing placement ghost snaps one box to the center of `LoadArea`, preserves 90-degree rotation relative to `LoadArea.CFrame`, and validates the full rotated footprint and total pallet-plus-cargo height.
- `CarryService` independently rebuilds and validates pallet placement, including distance, empty-pallet state, footprint, `MaxHeight`, and collidable overlap, before moving the held item.
- Free-world placement and identical-item stacking continue to use the Stage 04 path when no packing pallet is targeted.
- Stage 05B first-layer pallet packing is complete and Studio-tested.
- The Stage 05B edge-based snap refinement is complete and Studio-tested with differently sized boxes.
- First-layer candidates are derived from the authored `LoadArea` edges and center plus the local-space edges of existing first-layer cargo; adjacent candidates use the shared 0.05-stud packing gap.
- Candidate coordinates use the held Model's actual rotated footprint, remain inside `LoadArea`, and are deduplicated without introducing a dense micro-grid.
- The placement ghost selects the nearest valid candidate to the player's aim point, skips occupied candidates, and rebuilds the set after each 90-degree rotation.
- A pallet remains targetable through already packed cargo by probing downward from the aimed box, so the player does not need to target exposed pallet geometry.
- Pallet placement requests send pallet, candidate-coordinate indices, and rotation intent; the server rebuilds the same candidate set and CFrame before validating footprint, `MaxHeight`, distance, and overlap.
- Stage 05B supports spatially compatible first-layer boxes without applying `ItemId`, ITEM, or FAST compatibility rules.
- Stage 05C multi-layer pallet packing is complete and Studio-tested.
- Aiming at packed cargo selects that exact box as a vertical support; invalid vertical placement remains red and does not silently fall back to a free first-layer cell.
- Vertical stacking requires matching non-empty `ItemId` values and full candidate-footprint containment within the selected support's actual bounding footprint.
- Vertical candidate position is rebuilt from actual support top, held-item pivot-to-bounds offset, pallet-relative rotation, and the existing pallet `MaxHeight` semantics.
- Each packed box receives a runtime `PackedPallet` ObjectValue pointing to the exact pallet Model; the association is cleared on pickup or non-pallet placement and is server-validated for every pallet stack request.
- Stable single-support columns are supported; bridge placement, partial support, and multi-support physics packing remain out of scope.
- Stage 05D server-authoritative pallet contents registry is complete and Studio-tested.
- `PalletRegistry` keeps runtime state per physical pallet Model plus a reverse item-to-pallet mapping; each physical box remains an individual world Model and no authoritative CFrame copy is stored.
- Successful pallet placement adds the item to registry state, while pickup removes it before carry; repeated adds are idempotent and one item cannot belong to multiple pallets.
- Registry totals, per-`ItemId` counts, distinct count, contents, and physical loaded height are queryable; `CargoCount`, `DistinctItemCount`, and `LoadedHeight` are informational pallet attributes only.
- Item and pallet destruction clean runtime references, and explicit `Recalculate` restores one pallet from physical Models and service-managed `PackedPallet` associations.
- `FormatContents` and `PrintContents` provide opt-in server-side diagnostics without automatic placement logging.
- Stage 06A product catalog and barcode labels are complete and Studio-tested across `TEST_BOX`, `TEST_BOX_B`, `TEST_BOX_W`, `TEST_BOX_G`, and `TEST_BOX_P`.
- Shared `ProductCatalog` maps each supported `ItemId` to immutable `DisplayName` and `Barcode` values, validates non-empty strings and unique barcodes, and provides `Get`, `GetByBarcode`, and `Exists` lookups.
- `ItemId` is the canonical product identifier used by persistence, pallet contents, ITEM/FAST, and other gameplay systems.
- `Barcode` is an immutable unique lookup/scanning identifier stored as a string and is never the primary persistence key; visual barcode rendering may change without changing its catalog value.
- `ProductService` applies catalog metadata and an idempotent deterministic label to each authored `BarcodeSurface` without changing the Part's transform, size, weld, or physics properties.
- Barcode labels use the authored outward `Enum.NormalId.Back` face, and repeated `ApplyToItem` calls update the existing `BarcodeGui` instead of creating duplicates.
- Stage 07A TSD / Scanner Core is complete and Studio-tested.
- `ScannerController` provides explicit enabled state, center-camera box targeting up to 12 studs, one scanner-specific runtime `Highlight`, temporary result UI, Q mode toggle, and LMB scan input without changing the existing E/R carry and placement controls.
- Scanner requests are server-authoritative: the client sends only the intended physical target Instance, while `ScannerService` independently resolves the Box Model and validates character state, Workspace membership, `ItemType`, `ItemId`, distance, line of sight, catalog membership, and a per-player request cooldown.
- Successful scans resolve product identity through `ItemId -> ProductCatalog` and return only serializable `ItemId`, `Barcode`, and `DisplayName` data; replicated barcode attributes and the visual barcode image are not trusted or read as scan input.
- Scanner Core contains no receiving, ITEM, or FAST workflow logic. `ScannerController.ScanCompleted` and `ScannerService.ScanSucceeded` provide clean event boundaries for future workflow systems without adding a third-party signal dependency.

## Current milestone
**Stage 07A — TSD / Scanner Core — Complete and Studio-tested**

Stages 01A Rack Geometry, 01B Slot Registry, 01C Slot Labels / Rack Numbers, 04A Basic Interaction / Carry, 04B Placement Preview, 04C Extended Placement / Identical Item Stacking, 05A Pallet Detection + Single Box Snap, 05B First-Layer Pallet Packing, 05C Multi-Layer Pallet Packing, 05D Pallet Contents Registry, 06A Product Catalog + Barcode Labels, and 07A TSD / Scanner Core are complete.

The next milestone is receiving.

## Not implemented yet
- Slot snapping, Slot occupancy, and horizontal multi-product packing.
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
7. 05A Pallet Detection + Single Box Snap. **Complete.**
8. 05B First-Layer Pallet Packing. **Complete.**
9. 05C Multi-Layer Pallet Packing. **Complete.**
10. 05D Pallet Contents Registry. **Complete.**
11. 06A Product Catalog + Barcode Labels. **Complete.**
12. TSD/scanning. **Complete.**
13. Receiving. **Next.**
14. ITEM/FAST workflows.
15. Putaway.
16. Co-op/persistence.

## Update rule
Only mark a milestone complete after successful Roblox Studio testing.
Record what works, key decisions, limitations, and next milestone.
