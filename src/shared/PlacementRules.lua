--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WarehouseShared = ReplicatedStorage:WaitForChild("WarehouseShared")
local CarryConfig = require(WarehouseShared:WaitForChild("CarryConfig"))
local CarryItem = require(WarehouseShared:WaitForChild("CarryItem"))
local PlacementGeometry = require(WarehouseShared:WaitForChild("PlacementGeometry"))

local PlacementRules = {}

local function getBounds(model: Model): (CFrame, Vector3)
	return model:GetBoundingBox()
end

function PlacementRules.GetItemId(item: Model): string?
	local itemId = item:GetAttribute("ItemId")
	if typeof(itemId) ~= "string" or itemId == "" then
		return nil
	end

	return itemId
end

function PlacementRules.HaveMatchingItemIds(left: Model, right: Model): boolean
	local leftItemId = PlacementRules.GetItemId(left)
	local rightItemId = PlacementRules.GetItemId(right)

	return leftItemId ~= nil and rightItemId ~= nil and leftItemId == rightItemId
end

function PlacementRules.CreateStackCandidateCFrame(
	support: Model,
	rotationStep: number,
	boundsInfo: PlacementGeometry.BoundsInfo
): CFrame
	local supportBoundsCFrame, supportBoundsSize = getBounds(support)
	local supportTopY = PlacementGeometry.GetBoundsTopY(supportBoundsCFrame, supportBoundsSize)
	local rotation = PlacementGeometry.GetYawRotation(rotationStep)
	local candidateBoundsAtOrigin = rotation * boundsInfo.pivotToBounds
	local candidateBottomAtOrigin = PlacementGeometry.GetBoundsBottomY(candidateBoundsAtOrigin, boundsInfo.size)

	local pivotPosition = Vector3.new(
		supportBoundsCFrame.Position.X - candidateBoundsAtOrigin.Position.X,
		supportTopY - candidateBottomAtOrigin,
		supportBoundsCFrame.Position.Z - candidateBoundsAtOrigin.Position.Z
	)

	return CFrame.new(pivotPosition) * rotation
end

function PlacementRules.IsPointInsideSlot(slot: BasePart, worldPosition: Vector3): boolean
	local localPosition = slot.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = slot.Size / 2
	local tolerance = CarryConfig.SlotContainmentTolerance

	return math.abs(localPosition.X) <= halfSize.X + tolerance
		and math.abs(localPosition.Y) <= halfSize.Y + tolerance
		and math.abs(localPosition.Z) <= halfSize.Z + tolerance
end

function PlacementRules.FindContainingSlot(slotParts: { BasePart }, worldPosition: Vector3): BasePart?
	local bestSlot: BasePart? = nil
	local bestVolume = math.huge

	for _, slot in slotParts do
		if slot.Parent ~= nil and PlacementRules.IsPointInsideSlot(slot, worldPosition) then
			local volume = slot.Size.X * slot.Size.Y * slot.Size.Z
			if
				volume < bestVolume
				or (volume == bestVolume and bestSlot ~= nil and slot:GetFullName() < bestSlot:GetFullName())
			then
				bestSlot = slot
				bestVolume = volume
			end
		end
	end

	return bestSlot
end

function PlacementRules.GetSlotMaxHeight(slot: BasePart): number?
	local maxHeight = slot:GetAttribute("MaxHeight")
	if typeof(maxHeight) ~= "number" then
		return nil
	end
	if maxHeight ~= maxHeight or math.abs(maxHeight) == math.huge or maxHeight <= 0 then
		return nil
	end

	return maxHeight
end

function PlacementRules.FindStackBottomY(support: Model, itemId: string, ignoredInstances: { Instance }): number
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = ignoredInstances
	overlapParams.MaxParts = 0

	local visited: { [Model]: boolean } = {}
	local current = support
	visited[current] = true

	while current.Parent ~= nil do
		local currentBoundsCFrame, currentBoundsSize = getBounds(current)
		local currentBottomY = PlacementGeometry.GetBoundsBottomY(currentBoundsCFrame, currentBoundsSize)
		local horizontalQuerySize = math.max(currentBoundsSize.X, currentBoundsSize.Z)
			+ CarryConfig.StackCenterTolerance * 2
		local contactTolerance = CarryConfig.StackContactTolerance
		local queryCFrame = CFrame.new(
			currentBoundsCFrame.Position.X,
			currentBottomY - contactTolerance / 2,
			currentBoundsCFrame.Position.Z
		)
		local querySize = Vector3.new(horizontalQuerySize, contactTolerance * 2, horizontalQuerySize)
		local parts = Workspace:GetPartBoundsInBox(queryCFrame, querySize, overlapParams)

		local nextModel: Model? = nil
		local nextDelta = math.huge
		local seenCandidates: { [Model]: boolean } = {}

		for _, part in parts do
			local candidate = CarryItem.FindCarryableModel(part)
			if
				candidate == nil
				or candidate == current
				or visited[candidate] == true
				or seenCandidates[candidate] == true
			then
				continue
			end
			seenCandidates[candidate] = true

			if PlacementRules.GetItemId(candidate) ~= itemId then
				continue
			end

			local candidateBoundsCFrame, candidateBoundsSize = getBounds(candidate)
			if
				math.abs(candidateBoundsCFrame.Position.X - currentBoundsCFrame.Position.X)
					> CarryConfig.StackCenterTolerance
				or math.abs(candidateBoundsCFrame.Position.Z - currentBoundsCFrame.Position.Z)
					> CarryConfig.StackCenterTolerance
			then
				continue
			end

			local candidateTopY = PlacementGeometry.GetBoundsTopY(candidateBoundsCFrame, candidateBoundsSize)
			local verticalDelta = math.abs(candidateTopY - currentBottomY)
			if verticalDelta <= contactTolerance and verticalDelta < nextDelta then
				nextModel = candidate
				nextDelta = verticalDelta
			end
		end

		if nextModel == nil then
			return currentBottomY
		end

		current = nextModel
		visited[current] = true
	end

	local finalBoundsCFrame, finalBoundsSize = getBounds(current)
	return PlacementGeometry.GetBoundsBottomY(finalBoundsCFrame, finalBoundsSize)
end

return PlacementRules
