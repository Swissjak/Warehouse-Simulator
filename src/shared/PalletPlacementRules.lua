--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WarehouseShared = ReplicatedStorage:WaitForChild("WarehouseShared")
local CarryConfig = require(WarehouseShared:WaitForChild("CarryConfig"))
local CarryItem = require(WarehouseShared:WaitForChild("CarryItem"))
local PlacementGeometry = require(WarehouseShared:WaitForChild("PlacementGeometry"))

local PalletPlacementRules = {}

export type PalletInfo = {
	model: Model,
	loadArea: BasePart,
	maxHeight: number,
}

local function isPositiveFiniteNumber(value: unknown): boolean
	return typeof(value) == "number"
		and value == value
		and math.abs(value) < math.huge
		and value > 0
end

function PalletPlacementRules.GetPalletInfo(model: Model): PalletInfo?
	if model.Parent == nil or not model:IsDescendantOf(Workspace) then
		return nil
	end
	if model:GetAttribute("PackingEnabled") ~= true then
		return nil
	end

	local loadArea = model:FindFirstChild("LoadArea")
	if loadArea == nil or not loadArea:IsA("BasePart") then
		return nil
	end

	local maxHeight = model:GetAttribute("MaxHeight")
	if not isPositiveFiniteNumber(maxHeight) then
		return nil
	end

	return {
		model = model,
		loadArea = loadArea,
		maxHeight = maxHeight :: number,
	}
end

function PalletPlacementRules.FindPalletInfo(instance: Instance?): PalletInfo?
	if instance == nil or not instance:IsA("BasePart") then
		return nil
	end

	local current: Instance? = instance
	while current ~= nil do
		if current:IsA("Model") and current:GetAttribute("PackingEnabled") == true then
			return PalletPlacementRules.GetPalletInfo(current)
		end
		current = current.Parent
	end

	return nil
end

function PalletPlacementRules.GetCandidateOrientation(loadArea: BasePart, rotationStep: number): CFrame
	return loadArea.CFrame.Rotation * PlacementGeometry.GetYawRotation(rotationStep)
end

function PalletPlacementRules.CreateCandidateCFrame(
	loadArea: BasePart,
	rotationStep: number,
	boundsInfo: PlacementGeometry.BoundsInfo
): CFrame
	local orientation = PalletPlacementRules.GetCandidateOrientation(loadArea, rotationStep)
	local boundsAtOrigin = orientation * boundsInfo.pivotToBounds
	local bottomAtOrigin = PlacementGeometry.GetBoundsBottomY(boundsAtOrigin, boundsInfo.size)
	local boundsOffset = boundsAtOrigin.Position
	local planePosition = loadArea.Position
	local pivotPosition = Vector3.new(
		planePosition.X - boundsOffset.X,
		planePosition.Y - bottomAtOrigin,
		planePosition.Z - boundsOffset.Z
	)

	return CFrame.new(pivotPosition) * orientation
end

function PalletPlacementRules.DoesFootprintFit(
	loadArea: BasePart,
	boundsCFrame: CFrame,
	boundsSize: Vector3
): boolean
	local halfBounds = boundsSize / 2
	local minimumX = math.huge
	local maximumX = -math.huge
	local minimumZ = math.huge
	local maximumZ = -math.huge

	for xSign = -1, 1, 2 do
		for ySign = -1, 1, 2 do
			for zSign = -1, 1, 2 do
				local corner = Vector3.new(
					halfBounds.X * xSign,
					halfBounds.Y * ySign,
					halfBounds.Z * zSign
				)
				local worldCorner = boundsCFrame:PointToWorldSpace(corner)
				local localCorner = loadArea.CFrame:PointToObjectSpace(worldCorner)
				minimumX = math.min(minimumX, localCorner.X)
				maximumX = math.max(maximumX, localCorner.X)
				minimumZ = math.min(minimumZ, localCorner.Z)
				maximumZ = math.max(maximumZ, localCorner.Z)
			end
		end
	end

	local halfArea = loadArea.Size / 2
	local tolerance = CarryConfig.PalletFootprintTolerance
	return minimumX >= -halfArea.X - tolerance
		and maximumX <= halfArea.X + tolerance
		and minimumZ >= -halfArea.Z - tolerance
		and maximumZ <= halfArea.Z + tolerance
end

function PalletPlacementRules.GetPalletBottomY(pallet: Model): number
	local boundsCFrame, boundsSize = pallet:GetBoundingBox()
	return PlacementGeometry.GetBoundsBottomY(boundsCFrame, boundsSize)
end

function PalletPlacementRules.IsHeightValid(
	palletInfo: PalletInfo,
	candidateBoundsCFrame: CFrame,
	candidateBoundsSize: Vector3
): boolean
	local palletBottomY = PalletPlacementRules.GetPalletBottomY(palletInfo.model)
	local candidateTopY = PlacementGeometry.GetBoundsTopY(candidateBoundsCFrame, candidateBoundsSize)
	local totalLoadedHeight = candidateTopY - palletBottomY

	return totalLoadedHeight <= palletInfo.maxHeight + CarryConfig.StackHeightTolerance
end

function PalletPlacementRules.IsEmpty(palletInfo: PalletInfo, ignoredInstances: { Instance }): boolean
	local palletBottomY = PalletPlacementRules.GetPalletBottomY(palletInfo.model)
	local maximumTopY = palletBottomY + palletInfo.maxHeight
	local packingPlaneY = palletInfo.loadArea.Position.Y
	local availableHeight = maximumTopY - packingPlaneY
	if availableHeight <= 0 then
		return true
	end

	local inset = math.min(CarryConfig.PalletEmptyQueryInset, availableHeight / 4)
	local queryHeight = math.max(availableHeight - inset * 2, 0.01)
	local queryCenterY = packingPlaneY + inset + queryHeight / 2
	local queryCFrame = CFrame.new(
		palletInfo.loadArea.Position.X,
		queryCenterY,
		palletInfo.loadArea.Position.Z
	) * palletInfo.loadArea.CFrame.Rotation
	local querySize = Vector3.new(
		palletInfo.loadArea.Size.X,
		queryHeight,
		palletInfo.loadArea.Size.Z
	)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = ignoredInstances
	overlapParams.MaxParts = 0

	for _, part in Workspace:GetPartBoundsInBox(queryCFrame, querySize, overlapParams) do
		local cargo = CarryItem.FindCarryableModel(part)
		if cargo ~= nil then
			return false
		end
	end

	return true
end

return PalletPlacementRules
