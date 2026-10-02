--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WarehouseShared = ReplicatedStorage:WaitForChild("WarehouseShared")
local CarryConfig = require(WarehouseShared:WaitForChild("CarryConfig"))
local PalletPlacementRules = require(WarehouseShared:WaitForChild("PalletPlacementRules"))
local PlacementGeometry = require(WarehouseShared:WaitForChild("PlacementGeometry"))

local PalletRegistry = {}

export type ContentEntry = {
	Instance: Model,
	ItemId: string,
	ItemType: string,
}

type PalletState = {
	pallet: Model,
	items: { [Model]: ContentEntry },
	countByItemId: { [string]: number },
	total: number,
	distinctItemCount: number,
	destroyingConnection: RBXScriptConnection?,
}

local states: { [Model]: PalletState } = {}
local palletByItem: { [Model]: Model } = {}
local itemDestroyingConnections: { [Model]: RBXScriptConnection } = {}
local workspaceDescendantAddedConnection: RBXScriptConnection? = nil
local started = false

local function getItemId(item: Model): string?
	local itemId = item:GetAttribute("ItemId")
	if typeof(itemId) == "string" and itemId ~= "" then
		return itemId
	end

	return nil
end

local function getItemType(item: Model, itemId: string): string
	local itemType = item:GetAttribute("ItemType")
	if typeof(itemType) == "string" and itemType ~= "" then
		return itemType
	end

	return itemId
end

local function calculateLoadedHeight(pallet: Model, state: PalletState?): number
	local palletInfo = PalletPlacementRules.GetPalletInfo(pallet)
	if palletInfo == nil then
		return 0
	end

	local palletBottomY = PalletPlacementRules.GetPalletBottomY(pallet)
	local highestTopY = palletInfo.loadArea.Position.Y
	if state ~= nil then
		for item in state.items do
			if item.Parent ~= nil and item:IsDescendantOf(Workspace) then
				local boundsCFrame, boundsSize = item:GetBoundingBox()
				highestTopY = math.max(highestTopY, PlacementGeometry.GetBoundsTopY(boundsCFrame, boundsSize))
			end
		end
	end

	return math.max(highestTopY - palletBottomY, 0)
end

local function updateDebugAttributes(pallet: Model, state: PalletState)
	if pallet.Parent == nil then
		return
	end

	pallet:SetAttribute("CargoCount", state.total)
	pallet:SetAttribute("DistinctItemCount", state.distinctItemCount)
	pallet:SetAttribute("LoadedHeight", calculateLoadedHeight(pallet, state))
end

local function destroyAssociationObjects(item: Model)
	for _, child in item:GetChildren() do
		if child.Name == CarryConfig.PackedPalletObjectName then
			child:Destroy()
		end
	end
end

local function clearAssociation(item: Model, expectedPallet: Model?)
	local association = item:FindFirstChild(CarryConfig.PackedPalletObjectName)
	if
		expectedPallet ~= nil
		and association ~= nil
		and association:IsA("ObjectValue")
		and association.Value ~= nil
		and association.Value ~= expectedPallet
	then
		return
	end

	destroyAssociationObjects(item)
	item:SetAttribute("PackedOnPallet", false)
	item:SetAttribute("PalletId", nil)
end

local function setAssociation(item: Model, pallet: Model)
	destroyAssociationObjects(item)

	local association = Instance.new("ObjectValue")
	association.Name = CarryConfig.PackedPalletObjectName
	association.Value = pallet
	association.Parent = item

	item:SetAttribute("PackedOnPallet", true)
	item:SetAttribute("PalletId", nil)
end

local function disconnectItem(item: Model)
	local connection = itemDestroyingConnections[item]
	if connection ~= nil then
		connection:Disconnect()
		itemDestroyingConnections[item] = nil
	end
end

local function removeEntry(pallet: Model, item: Model, shouldClearAssociation: boolean): boolean
	local state = states[pallet]
	if state == nil then
		if palletByItem[item] == pallet then
			palletByItem[item] = nil
			disconnectItem(item)
		end
		if shouldClearAssociation then
			clearAssociation(item, pallet)
		end
		return false
	end

	local entry = state.items[item]
	if entry == nil then
		if palletByItem[item] == pallet then
			palletByItem[item] = nil
			disconnectItem(item)
		end
		if shouldClearAssociation then
			clearAssociation(item, pallet)
		end
		return false
	end

	state.items[item] = nil
	state.total = math.max(state.total - 1, 0)

	local itemIdCount = state.countByItemId[entry.ItemId]
	if itemIdCount ~= nil then
		if itemIdCount <= 1 then
			state.countByItemId[entry.ItemId] = nil
			state.distinctItemCount = math.max(state.distinctItemCount - 1, 0)
		else
			state.countByItemId[entry.ItemId] = itemIdCount - 1
		end
	end

	if palletByItem[item] == pallet then
		palletByItem[item] = nil
		disconnectItem(item)
	end
	if shouldClearAssociation then
		clearAssociation(item, pallet)
	end
	updateDebugAttributes(pallet, state)

	return true
end

local function clearPalletState(pallet: Model, shouldClearAssociations: boolean)
	local state = states[pallet]
	if state == nil then
		return
	end

	local items: { Model } = {}
	for item in state.items do
		table.insert(items, item)
	end
	for _, item in items do
		removeEntry(pallet, item, shouldClearAssociations)
	end
end

local function unregisterPallet(pallet: Model)
	local state = states[pallet]
	if state == nil then
		return
	end

	clearPalletState(pallet, true)
	if state.destroyingConnection ~= nil then
		state.destroyingConnection:Disconnect()
		state.destroyingConnection = nil
	end
	states[pallet] = nil
end

function PalletRegistry.RegisterPallet(pallet: Model): boolean
	if states[pallet] ~= nil then
		return true
	end
	if PalletPlacementRules.GetPalletInfo(pallet) == nil then
		return false
	end

	local state: PalletState = {
		pallet = pallet,
		items = {},
		countByItemId = {},
		total = 0,
		distinctItemCount = 0,
		destroyingConnection = nil,
	}
	states[pallet] = state
	state.destroyingConnection = pallet.Destroying:Connect(function()
		unregisterPallet(pallet)
	end)
	updateDebugAttributes(pallet, state)

	return true
end

function PalletRegistry.AddItem(palletValue: unknown, itemValue: unknown): boolean
	if
		typeof(palletValue) ~= "Instance"
		or not palletValue:IsA("Model")
		or typeof(itemValue) ~= "Instance"
		or not itemValue:IsA("Model")
	then
		return false
	end

	local pallet = palletValue :: Model
	local item = itemValue :: Model
	local itemId = getItemId(item)
	if
		itemId == nil
		or item.Parent == nil
		or not item:IsDescendantOf(Workspace)
		or item:GetAttribute("Carryable") ~= true
		or not PalletRegistry.RegisterPallet(pallet)
	then
		return false
	end

	local previousPallet = palletByItem[item]
	if previousPallet ~= nil and previousPallet ~= pallet then
		return false
	end

	local state = states[pallet] :: PalletState
	local previousEntry = state.items[item]
	if previousEntry ~= nil then
		if previousEntry.ItemId == itemId and previousEntry.ItemType == getItemType(item, itemId) then
			palletByItem[item] = pallet
			setAssociation(item, pallet)
			disconnectItem(item)
			itemDestroyingConnections[item] = item.Destroying:Connect(function()
				removeEntry(pallet, item, false)
			end)
			updateDebugAttributes(pallet, state)
			return true
		end
		removeEntry(pallet, item, false)
		state = states[pallet] :: PalletState
	end

	local entry: ContentEntry = {
		Instance = item,
		ItemId = itemId,
		ItemType = getItemType(item, itemId),
	}
	state.items[item] = entry
	state.total += 1
	local previousItemIdCount = state.countByItemId[itemId] or 0
	state.countByItemId[itemId] = previousItemIdCount + 1
	if previousItemIdCount == 0 then
		state.distinctItemCount += 1
	end
	palletByItem[item] = pallet
	setAssociation(item, pallet)

	disconnectItem(item)
	itemDestroyingConnections[item] = item.Destroying:Connect(function()
		removeEntry(pallet, item, false)
	end)
	updateDebugAttributes(pallet, state)

	return true
end

function PalletRegistry.RemoveItem(pallet: Model, item: Model): boolean
	return removeEntry(pallet, item, true)
end

function PalletRegistry.RemoveItemFromCurrentPallet(item: Model): boolean
	local pallet = palletByItem[item]
	if pallet == nil then
		local palletInfo = PalletPlacementRules.GetAssociatedPalletInfo(item)
		if palletInfo ~= nil then
			pallet = palletInfo.model
		end
	end

	if pallet ~= nil then
		return removeEntry(pallet, item, true)
	end

	clearAssociation(item, nil)
	return false
end

function PalletRegistry.GetPalletForItem(item: Model): Model?
	return palletByItem[item]
end

function PalletRegistry.GetContents(pallet: Model): { ContentEntry }
	local state = states[pallet]
	if state == nil then
		return {}
	end

	local contents: { ContentEntry } = {}
	for _, entry in state.items do
		table.insert(contents, {
			Instance = entry.Instance,
			ItemId = entry.ItemId,
			ItemType = entry.ItemType,
		})
	end
	table.sort(contents, function(left, right)
		if left.ItemId == right.ItemId then
			return left.Instance.Name < right.Instance.Name
		end
		return left.ItemId < right.ItemId
	end)

	return contents
end

function PalletRegistry.GetTotalCount(pallet: Model): number
	local state = states[pallet]
	return if state ~= nil then state.total else 0
end

function PalletRegistry.GetItemCount(pallet: Model): number
	return PalletRegistry.GetTotalCount(pallet)
end

function PalletRegistry.GetCountByItemId(pallet: Model, itemId: string): number
	local state = states[pallet]
	return if state ~= nil then state.countByItemId[itemId] or 0 else 0
end

function PalletRegistry.GetDistinctItemIds(pallet: Model): number
	local state = states[pallet]
	return if state ~= nil then state.distinctItemCount else 0
end

function PalletRegistry.Recalculate(pallet: Model): boolean
	if not PalletRegistry.RegisterPallet(pallet) then
		return false
	end

	clearPalletState(pallet, false)
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("Carryable") == true then
			local palletInfo = PalletPlacementRules.GetAssociatedPalletInfo(descendant)
			if palletInfo ~= nil and palletInfo.model == pallet then
				local previousPallet = palletByItem[descendant]
				if previousPallet ~= nil and previousPallet ~= pallet then
					removeEntry(previousPallet, descendant, false)
				end
				PalletRegistry.AddItem(pallet, descendant)
			end
		end
	end

	local state = states[pallet]
	if state ~= nil then
		updateDebugAttributes(pallet, state)
	end
	return true
end

function PalletRegistry.GetLoadedHeight(pallet: Model): number
	return calculateLoadedHeight(pallet, states[pallet])
end

function PalletRegistry.FormatContents(pallet: Model): string
	local state = states[pallet]
	local total = if state ~= nil then state.total else 0
	local distinct = if state ~= nil then state.distinctItemCount else 0
	local itemIds: { string } = {}
	if state ~= nil then
		for itemId in state.countByItemId do
			table.insert(itemIds, itemId)
		end
	end
	table.sort(itemIds)

	local lines = {
		string.format("Pallet: %s", pallet:GetFullName()),
		string.format("Total = %d", total),
		string.format("Distinct = %d", distinct),
		"",
	}
	if state ~= nil then
		for _, itemId in itemIds do
			table.insert(lines, string.format("%s = %d", itemId, state.countByItemId[itemId]))
		end
	end
	table.insert(lines, "")
	table.insert(lines, string.format("LoadedHeight = %.3f", PalletRegistry.GetLoadedHeight(pallet)))

	return table.concat(lines, "\n")
end

function PalletRegistry.PrintContents(pallet: Model)
	print(PalletRegistry.FormatContents(pallet))
end

function PalletRegistry.Start()
	if started then
		return
	end
	started = true

	local pallets: { Model } = {}
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("PackingEnabled") == true then
			if PalletRegistry.RegisterPallet(descendant) then
				table.insert(pallets, descendant)
			end
		end
	end
	for _, pallet in pallets do
		PalletRegistry.Recalculate(pallet)
	end

	workspaceDescendantAddedConnection = Workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Model") and descendant:GetAttribute("PackingEnabled") == true then
			PalletRegistry.Recalculate(descendant)
		end
	end)
end

return PalletRegistry
