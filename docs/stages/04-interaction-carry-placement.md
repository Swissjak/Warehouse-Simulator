# Stage 04 — Interaction / Carry / Place

Status: Complete and Studio-tested

## Scope

Stage 04 provides the complete MVP interaction loop for carrying and placing individual items:

- 04A: targeting, pickup, carried-item attachment, release cleanup, and physics-state restoration;
- 04B: local placement preview, valid/invalid feedback, rotation, and authoritative placement;
- 04C: separate placement distance, identical-item stacking, alignment, and stack-height validation.

The implementation remains server-authoritative. Client preview is advisory and the server independently validates every pickup and placement request.

## Item contract

A carryable item is a Model with:

- `Carryable = true`;
- a non-empty `ItemId` string;
- either a `PrimaryPart` or a direct child BasePart named `Body`.

The authored `Workspace.Warehouse.TestItems.TestBox` is the current Studio test item. Stage 04 does not require new Studio-authored objects.

## Controls

- `E` while not holding an item: pick up the targeted valid item.
- `E` while holding an item and the preview is valid: place at the current candidate.
- `E` while holding an item and the preview is invalid: do nothing and keep holding the item.
- `LMB`: optional placement confirmation alias.
- `R`: rotate the candidate by +90 degrees. Preview rotation does not rotate the server-held item.

## Distances

- Pickup distance: 8 studs.
- Placement distance: 12 studs.
- Placement ray length: 30 studs.

Pickup and placement distance are intentionally independent.

## Carry behavior

`CarryService` owns held state and enforces one held item per player and one holder per item. The held Model is attached to a runtime `CarryAnchor`; its original collision and massless values are restored when carry ends.

Carry state is released on successful placement, explicit cleanup, death, character removal, player removal, or item destruction.

## Placement preview

While placement is active, the local player sees one non-physical ghost and the real held item is hidden locally with `LocalTransparencyModifier`. Other players continue to see the real server-held item.

The ghost uses one `PlacementHighlight` with a prominent green valid state and red invalid state. The preview accounts for Model pivot and bounding-box offsets so the item rests on the candidate surface without a visual gap.

## Placement and stacking rules

A placement candidate must satisfy the shared geometry and rules used by the client preview and server validation:

- the candidate is within placement distance;
- rotation is upright and quantized to an allowed 90-degree step;
- the supporting surface is sufficiently horizontal;
- the item does not overlap disallowed collidable geometry;
- stacking is allowed only on an item with the same non-empty `ItemId`;
- a stacked item is centered and aligned on the supporting item;
- total stack height does not exceed the containing Slot's `MaxHeight`, when applicable;
- otherwise, total stack height does not exceed the configured free-world maximum.

The server recomputes and validates the candidate before moving the real Model. A rejected request leaves the item held and placement mode active.

## Stage boundaries

Stage 04 does not implement:

- Slot snapping or Slot occupancy;
- horizontal multi-product packing;
- pallet packing;
- product inventory, receiving, scanning, ITEM/FAST workflows, rewards, or persistence.
