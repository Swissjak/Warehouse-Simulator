# Warehouse Simulator — MVP GDD for Development

## Product vision
Roblox warehouse-worker simulator inspired by real receiving/storage work.
Not a tycoon. Solo must work; multiplayer should help but not be required.
Worker career progression is the long-term foundation.

## MVP scope
Included later in MVP:
- receiving docks;
- rack storage zones;
- FAST/client zone;
- pallet supply;
- simple box models and 10–15 fictional products;
- manual pallet packing;
- TSD/scanner;
- physical ITEM/FAST labels;
- manual hand pallet jack;
- receiving, putaway and basic FAST delivery;
- solo + co-op;
- level, XP, money, stats, simple dock upgrades.

Not required in the first MVP slice:
- reach truck/electric pallet truck;
- damage, shortage, overage workflows;
- full outbound Picking → LDG → Shipping;
- deep career tree;
- global persistent warehouse stock;
- full anti-grief;
- mobile controls.

## Storage categories
`Tech`, `Dishware`, `Large`, `Valuable`, `Other`.

A RackZone has one StorageCategory.
Different product models may share horizontal space if compatible and physically possible.
Different models never stack vertically on each other.
Only identical models may stack vertically.
TV/long-TV-like goods use one layer only.

## Physical box identity
Boxes of the same product model are interchangeable to the player.
The product barcode identifies the model, not a unique physical serial.
Internally each box may still be a server entity with ProductId/state/container/location.

## ITEM
ITEM is a temporary receiving/putaway grouping, not a permanent stock ID and not a pallet ID.
One ITEM = one product model + one physically connected stack/group.
Split stacks/pallets use different unique ITEM IDs.
Groups can be closed early.
Closed groups become immutable in MVP, then AwaitingLabel.
Player physically applies the label.
Partially completed putaway keeps the same ITEM ID with reduced remaining quantity.

## FAST
FAST and ITEM never share a pallet.
A FAST pallet may contain mixed models.
One FAST label represents one FAST pallet.
FAST IDs are unique.
FAST has a real departure deadline and a destination client-zone slot.

## Receiving
Player accepts a receiving job, gets a dock, prints/scans receiving paperwork, unloads and scans every expected box.
First successful scan of a model assigns receiving responsibility for that model.
Groups are closed and physically labeled.
Documents can only be finalized after required scanning, closure and labeling are done.
MVP expected quantity always equals actual quantity.

## Pallet rules
Pallet is physical.
General maximum pallet + cargo height: **8 studs**.
Same model may stack vertically; different models may not.
TV-like goods: one layer.
ITEM and FAST never share the same pallet.
Exact overhang tolerance remains open.

## Rack address
Format: `Rack-Bay-Floor-Slot`
Example: `1-12-3-2`.

Bay numbering starts from the end of RackZone closest to world origin `(0,0,0)`.

## RackZone
One RackZone = one one-sided rack.
For first implementation, one zone uses one rack type only.

Required attributes:
- `RackId` Number
- `RackType` String (`V1` or `V2`)
- `StorageCategory` String

Section length: **20 studs**.
Section count: `floor(zoneLength / 20)`.
Ignore leftover partial length.

## RackV1
5 floors, 3 positions per floor.
All positions are `PalletSlot`.
Max pallet + goods height: **8 studs**.

## RackV2
5 floors, 3 positions per floor.

Floors 1–2:
- direct `Slot`;
- no pallet;
- max goods height **3 studs**.

Floors 3–5:
- `PalletSlot`;
- max pallet + goods height **8 studs**.

Recommended slot attributes:
- Box slot: `SlotType="Box"`, `MaxHeight=3`
- Pallet slot: `SlotType="Pallet"`, `MaxHeight=8`

## Rack stickers
Template Sticker objects are placement references.
Generator creates/updates human-readable location text from generated SlotId.
Barcode graphic may be identical everywhere.
Future TSD uses raycast/object identity, not OCR.

## Rack number plate
`RackNumberPlate` displays `RackId`.

## Putaway direction
Later algorithm:
1. correct category;
2. reject incompatible/impossible locations;
3. prefer occupied compatible slot;
4. highest fill first;
5. maximize one slot before splitting;
6. use suitable empty slot if needed;
7. best-fit empty space;
8. distance does not matter in MVP.

## Hand pallet jack
Manual only for MVP; arcade steering; separate lift/lower; slight alignment assist; cargo remains stable.

## Interaction direction
PC-first.
General controls later: E interact, LMB scan/place, R rotate.
One held physical item at a time.
TSD and label roll are physically collected from equipment stations.

## Progression
Foundation: Level, XP, Money, Stats, simple dock upgrades.
Exact economy is open.

## Open questions
Do not silently invent final answers for:
- world scale;
- pallet overhang tolerance;
- adaptive pallet grid;
- exact dock cooldown;
- pallet supply balance;
- economy values;
- anti-grief;
- mobile controls;
- deep career tree.
