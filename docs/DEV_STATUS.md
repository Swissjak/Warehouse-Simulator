# Warehouse Simulator — Development Status
Last updated: 2026-09-29

## Completed / prepared
- Initial warehouse blockout exists in Roblox Studio.
- `RackV1` template exists.
- `RackV2` template exists.
- Multiple RackZone parts are placed for testing (about 10 zones).
- Rack storage conventions are defined.
- Rojo is installed and `rojo serve` works.
- Partial-Rojo approach is used: code is synchronized; warehouse world geometry remains Studio-authored.

## Current milestone
**Stage 01 — Rack Generator**

Spec: `docs/stages/01-rack-generator.md`

## Not implemented yet
- Rack generator runtime code.
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
1. 01A Rack geometry generation.
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
