--!strict

local SlotRegistry = {}

export type SlotMetadata = {
	SlotId: string,
	Instance: BasePart,
	RackId: number,
	BayIndex: number,
	FloorIndex: number,
	SlotIndex: number,
	RackType: string,
	RackSide: string,
	SlotType: string,
	MaxHeight: number,
	StorageCategory: string,
}

type IndexedInstance = {
	index: number,
	instance: Instance,
}

type RackMetadata = {
	RackId: number,
	RackType: string,
	RackSide: string,
	StorageCategory: string,
}

local entriesById: { [string]: SlotMetadata } = {}
local orderedEntries: { SlotMetadata } = {}

local function warnForInstance(instance: Instance, message: string)
	warn(string.format("[SlotRegistry] %s: %s", instance:GetFullName(), message))
end

local function isPositiveInteger(value: unknown): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge and value > 0 and value % 1 == 0
end

local function collectIndexedChildren(
	parent: Instance,
	pattern: string,
	prefix: string,
	expectedName: string,
	warnForEveryChild: boolean
): { IndexedInstance }
	local indexedChildren: { IndexedInstance } = {}

	for _, child in parent:GetChildren() do
		local indexText = string.match(child.Name, pattern)
		if indexText ~= nil then
			local index = tonumber(indexText)
			if isPositiveInteger(index) then
				table.insert(indexedChildren, {
					index = index :: number,
					instance = child,
				})
			else
				warnForInstance(child, string.format("invalid name; expected %s", expectedName))
			end
		elseif warnForEveryChild or string.sub(child.Name, 1, #prefix) == prefix then
			warnForInstance(child, string.format("invalid name; expected %s", expectedName))
		end
	end

	table.sort(indexedChildren, function(left, right)
		if left.index == right.index then
			return left.instance:GetFullName() < right.instance:GetFullName()
		end

		return left.index < right.index
	end)

	return indexedChildren
end

local function readRackMetadata(rack: Instance, rackIdFromName: number): RackMetadata?
	local rackId = rack:GetAttribute("RackId")
	if not isPositiveInteger(rackId) then
		warnForInstance(rack, "missing or invalid RackId Number attribute")
		return nil
	end
	if rackId ~= rackIdFromName then
		warnForInstance(
			rack,
			string.format("RackId attribute %s does not match rack name Rack_%d", tostring(rackId), rackIdFromName)
		)
		return nil
	end

	local rackType = rack:GetAttribute("RackType")
	if rackType ~= "V1" and rackType ~= "V2" then
		warnForInstance(rack, "missing or invalid RackType String attribute")
		return nil
	end

	local rackSide = rack:GetAttribute("RackSide")
	if rackSide ~= "L" and rackSide ~= "R" then
		warnForInstance(rack, "missing or invalid RackSide String attribute")
		return nil
	end

	local storageCategory = rack:GetAttribute("StorageCategory")
	if typeof(storageCategory) ~= "string" or storageCategory == "" then
		warnForInstance(rack, "missing or invalid StorageCategory String attribute")
		return nil
	end

	return {
		RackId = rackId :: number,
		RackType = rackType :: string,
		RackSide = rackSide :: string,
		StorageCategory = storageCategory :: string,
	}
end

local function getSlotSemantics(rackType: string, floorIndex: number): (string, number)
	if rackType == "V2" and floorIndex <= 2 then
		return "Box", 3
	end

	return "Pallet", 8
end

local function registerSlot(
	newEntriesById: { [string]: SlotMetadata },
	newOrderedEntries: { SlotMetadata },
	registeredInstances: { [Instance]: string },
	slot: Instance,
	rackId: number,
	bayIndex: number,
	floorIndex: number,
	slotIndex: number,
	rackType: string,
	rackSide: string,
	storageCategory: string
)
	if not slot:IsA("BasePart") then
		warnForInstance(slot, "Slot<number> must be a BasePart")
		return
	end

	local slotId = string.format("%d-%d-%d-%d", rackId, bayIndex, floorIndex, slotIndex)
	local existing = newEntriesById[slotId]
	if existing ~= nil then
		warn(
			string.format(
				"[SlotRegistry] Duplicate SlotId %s: %s and %s",
				slotId,
				existing.Instance:GetFullName(),
				slot:GetFullName()
			)
		)
		return
	end

	local existingSlotId = registeredInstances[slot]
	if existingSlotId ~= nil then
		warn(
			string.format(
				"[SlotRegistry] Physical slot registered twice: %s as %s and %s",
				slot:GetFullName(),
				existingSlotId,
				slotId
			)
		)
		return
	end

	local slotType, maxHeight = getSlotSemantics(rackType, floorIndex)

	slot:SetAttribute("SlotId", slotId)
	slot:SetAttribute("RackId", rackId)
	slot:SetAttribute("BayIndex", bayIndex)
	slot:SetAttribute("FloorIndex", floorIndex)
	slot:SetAttribute("SlotIndex", slotIndex)
	slot:SetAttribute("SlotType", slotType)
	slot:SetAttribute("MaxHeight", maxHeight)
	slot:SetAttribute("StorageCategory", storageCategory)

	local entry: SlotMetadata = {
		SlotId = slotId,
		Instance = slot,
		RackId = rackId,
		BayIndex = bayIndex,
		FloorIndex = floorIndex,
		SlotIndex = slotIndex,
		RackType = rackType,
		RackSide = rackSide,
		SlotType = slotType,
		MaxHeight = maxHeight,
		StorageCategory = storageCategory,
	}

	newEntriesById[slotId] = entry
	registeredInstances[slot] = slotId
	table.insert(newOrderedEntries, entry)
end

local function registerRack(
	newEntriesById: { [string]: SlotMetadata },
	newOrderedEntries: { SlotMetadata },
	registeredInstances: { [Instance]: string },
	rack: Instance,
	rackIdFromName: number
): boolean
	local rackMetadata = readRackMetadata(rack, rackIdFromName)
	if rackMetadata == nil then
		return false
	end

	local bays = collectIndexedChildren(rack, "^Bay_(%d+)$", "Bay_", "Bay_<number>", true)
	for _, indexedBay in bays do
		local bayIndex = indexedBay.index
		local bay = indexedBay.instance
		local floors = collectIndexedChildren(bay, "^Floor(%d+)$", "Floor", "Floor<number>", false)

		for _, indexedFloor in floors do
			local floorIndex = indexedFloor.index
			local floor = indexedFloor.instance
			local slots = collectIndexedChildren(floor, "^Slot(%d+)$", "Slot", "Slot<number>", false)

			for _, indexedSlot in slots do
				registerSlot(
					newEntriesById,
					newOrderedEntries,
					registeredInstances,
					indexedSlot.instance,
					rackMetadata.RackId,
					bayIndex,
					floorIndex,
					indexedSlot.index,
					rackMetadata.RackType,
					rackMetadata.RackSide,
					rackMetadata.StorageCategory
				)
			end
		end
	end

	return true
end

function SlotRegistry.Rebuild(generatedRacks: Instance)
	local newEntriesById: { [string]: SlotMetadata } = {}
	local newOrderedEntries: { SlotMetadata } = {}
	local registeredInstances: { [Instance]: string } = {}
	local rackCount = 0

	local racks = collectIndexedChildren(generatedRacks, "^Rack_(%d+)$", "Rack_", "Rack_<number>", true)

	for _, indexedRack in racks do
		if
			registerRack(
				newEntriesById,
				newOrderedEntries,
				registeredInstances,
				indexedRack.instance,
				indexedRack.index
			)
		then
			rackCount += 1
		end
	end

	entriesById = newEntriesById
	orderedEntries = newOrderedEntries

	print(string.format("[SlotRegistry] Registered %d slots across %d racks", #orderedEntries, rackCount))
end

function SlotRegistry.Get(slotId: string): SlotMetadata?
	return entriesById[slotId]
end

function SlotRegistry.GetAll(): { SlotMetadata }
	return table.clone(orderedEntries)
end

function SlotRegistry.Count(): number
	return #orderedEntries
end

return SlotRegistry
